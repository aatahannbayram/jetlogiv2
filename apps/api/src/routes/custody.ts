import {
  CustodyHandoverRequest,
  CustodyHandoverResponse,
  CustodyIssueReportRequest,
  CustodyIssueReportResponse,
  CustodyItem,
  CustodyListQuery,
  CustodyListResponse,
  ErrorResponse,
  SupportTicket,
  SupportTicketCreateRequest,
  SupportTicketListResponse,
  Uuid,
} from '@dijigoo/contracts';
import type { ProductStatusCode } from '@dijigoo/contracts';
import { AppError, clampOccurredAt, runIdempotent } from '@dijigoo/core';
import { custodyHandoverItems, custodyHandovers, custodyItems, supportTickets } from '@dijigoo/db';
import { and, desc, eq, inArray, isNull } from 'drizzle-orm';
import type { FastifyInstance, FastifyRequest } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { z } from 'zod';

import type { AppContext } from '../context.js';
import type { AuthenticatedCourier } from '../plugins/authenticate.js';
import { productStatusForHandover, transitionCustodyItem } from '../services/custody-status.js';
import { PostgresIdempotencyStore } from '../services/idempotency-store.js';
import { emitEvent } from '../services/outbox.js';
import { closeReturnOnBranchHandover } from '../services/return-status.js';

export async function custodyRoutes(app: FastifyInstance, { ctx }: { ctx: AppContext }) {
  const route = app.withTypeProvider<ZodTypeProvider>();

  route.get(
    '/v1/custody',
    {
      schema: {
        tags: ['Custody'],
        querystring: CustodyListQuery,
        response: { 200: CustodyListResponse, 401: ErrorResponse },
      },
    },
    async (request) => {
      const courier = await app.authenticate(request);
      const { type, limit } = request.query;

      const rows = await ctx.db
        .select()
        .from(custodyItems)
        .where(
          and(
            eq(custodyItems.holderCourierId, courier.courierId),
            isNull(custodyItems.releasedAt),
            type?.length ? inArray(custodyItems.type, type) : undefined,
          ),
        )
        .orderBy(desc(custodyItems.acquiredAt))
        .limit(limit);

      return { items: rows.map(toCustodyItem), nextCursor: null, syncedAt: new Date().toISOString() };
    },
  );

  route.post(
    '/v1/custody/handover',
    {
      schema: {
        tags: ['Custody'],
        body: CustodyHandoverRequest,
        response: {
          200: CustodyHandoverResponse,
          400: ErrorResponse,
          401: ErrorResponse,
          409: ErrorResponse,
        },
      },
    },
    async (request) => {
      const courier = await app.authenticate(request);
      const body = request.body;

      return withIdempotency(ctx, courier, request, body, async () => {
        const occurredAt = clampOccurredAt(new Date(body.occurredAt), new Date());

        const result = await ctx.db.transaction(async (tx) => {
          // Lock the rows first. Two couriers scanning the same parcel at a
          // depot handover would otherwise both succeed and the item would end
          // up counted twice.
          const held = await tx
            .select()
            .from(custodyItems)
            .where(and(inArray(custodyItems.id, body.itemIds), isNull(custodyItems.releasedAt)))
            .for('update');

          const heldIds = new Set(held.map((item) => item.id));
          const missing = body.itemIds.filter((id) => !heldIds.has(id));
          if (missing.length > 0) {
            throw new AppError('CONFLICT', {
              message: 'Bazi zimmet kalemleri artik sizde degil.',
              userVisible: true,
              details: missing.map((id) => ({ field: 'itemIds', issue: 'not_held', meta: { id } })),
            });
          }

          if (body.direction === 'handover') {
            const foreign = held.filter((item) => item.holderCourierId !== courier.courierId);
            if (foreign.length > 0) {
              throw new AppError('FORBIDDEN', {
                message: 'Size ait olmayan bir kalem devredilemez.',
                userVisible: true,
              });
            }
          }

          const [handover] = await tx
            .insert(custodyHandovers)
            .values({
              tenantId: courier.tenantId,
              courierId: courier.courierId,
              direction: body.direction,
              counterpartyKind: body.counterparty.kind,
              counterpartyId: body.counterparty.id ?? null,
              counterpartyName: body.counterparty.name,
              signatureMediaId: body.signatureMediaId ?? null,
              photoMediaIds: body.photoMediaIds,
              position: body.location ? { lat: body.location.lat, lng: body.location.lng } : null,
              note: body.note ?? null,
              occurredAt,
              clientEventId: body.clientEventId,
            })
            .returning();

          await tx
            .insert(custodyHandoverItems)
            .values(body.itemIds.map((itemId) => ({ handoverId: handover!.id, itemId })));

          if (body.direction === 'handover') {
            await tx
              .update(custodyItems)
              .set({
                releasedAt: occurredAt,
                holderCourierId:
                  body.counterparty.kind === 'courier' ? (body.counterparty.id ?? null) : null,
              })
              .where(inArray(custodyItems.id, body.itemIds));
          } else {
            await tx
              .update(custodyItems)
              .set({ holderCourierId: courier.courierId, acquiredAt: occurredAt, releasedAt: null })
              .where(inArray(custodyItems.id, body.itemIds));
          }

          // Faz 2 (Nihai mimari): the handover already moved holderCourierId;
          // this is the parallel PRD status move (e.g. handover-to-customer
          // is a real delivery, PRD-120). `held` still has each item's
          // pre-handover status from the row lock above.
          const targetStatus = productStatusForHandover(body.direction, body.counterparty.kind);
          if (targetStatus) {
            for (const item of held) {
              await transitionCustodyItem(
                tx,
                { tenantId: courier.tenantId, correlationId: request.id },
                item.id,
                item.status,
                targetStatus,
                `custody.${body.direction}`,
                occurredAt,
              );

              // Faz 4 (Nihai mimari): handing a held item back to a branch/
              // warehouse (PRD-130) is, from the courier's side, a return
              // actually completing — close any open return record for it.
              if (targetStatus === 'PRD-130') {
                await closeReturnOnBranchHandover(
                  tx,
                  { tenantId: courier.tenantId, correlationId: request.id },
                  item.id,
                  occurredAt,
                );
              }
            }
          }

          await emitEvent(tx, {
            key: body.direction === 'handover' ? 'custody.item_handed_over' : 'custody.item_taken',
            tenantId: courier.tenantId,
            subjectType: 'custody',
            subjectId: handover!.id,
            actorType: 'courier',
            actorId: courier.courierId,
            correlationId: body.clientEventId,
            occurredAt,
            data: {
              direction: body.direction,
              itemIds: body.itemIds,
              counterparty: body.counterparty,
              // The worker renders the PDF receipt off this event; it is not
              // on the request path because the courier must not wait for it.
              needsReceipt: true,
            },
          });

          const remaining = await tx
            .select()
            .from(custodyItems)
            .where(
              and(eq(custodyItems.holderCourierId, courier.courierId), isNull(custodyItems.releasedAt)),
            );

          return { handoverId: handover!.id, remaining };
        });

        return {
          status: 201,
          value: {
            handoverId: result.handoverId,
            remaining: result.remaining.map(toCustodyItem),
            receipt: null,
            appliedAt: new Date().toISOString(),
          },
        };
      });
    },
  );

  /**
   * Faz 2 (Nihai mimari): a courier reports damage or loss on an item they
   * currently hold — PRD-180/190. Compensation resolution (PRD-200/210) is
   * financial follow-up, out of this codebase's scope; this only records
   * the report and moves the item out of active custody circulation.
   */
  route.post(
    '/v1/custody/:itemId/report-issue',
    {
      schema: {
        tags: ['Custody'],
        params: z.object({ itemId: Uuid }),
        body: CustodyIssueReportRequest,
        response: {
          200: CustodyIssueReportResponse,
          400: ErrorResponse,
          401: ErrorResponse,
          403: ErrorResponse,
          404: ErrorResponse,
          409: ErrorResponse,
        },
      },
    },
    async (request) => {
      const courier = await app.authenticate(request);
      const body = request.body;

      return withIdempotency(ctx, courier, request, body, async () => {
        const occurredAt = clampOccurredAt(new Date(body.occurredAt), new Date());

        const item = await ctx.db.transaction(async (tx) => {
          const [held] = await tx
            .select()
            .from(custodyItems)
            .where(and(eq(custodyItems.id, request.params.itemId), isNull(custodyItems.releasedAt)))
            .for('update');

          if (!held) throw new AppError('NOT_FOUND');
          if (held.holderCourierId !== courier.courierId) {
            throw new AppError('FORBIDDEN', {
              message: 'Elinizde olmayan bir kalem icin hasar/kayip bildiremezsiniz.',
              userVisible: true,
            });
          }

          const toStatus: ProductStatusCode = body.kind === 'damaged' ? 'PRD-180' : 'PRD-190';

          await transitionCustodyItem(
            tx,
            { tenantId: courier.tenantId, correlationId: request.id },
            held.id,
            held.status,
            toStatus,
            body.note ?? `custody.${body.kind}`,
            occurredAt,
          );

          await emitEvent(tx, {
            key: body.kind === 'damaged' ? 'custody.item_damaged' : 'custody.item_lost',
            tenantId: courier.tenantId,
            subjectType: 'custody',
            subjectId: held.id,
            actorType: 'courier',
            actorId: courier.courierId,
            correlationId: body.clientEventId,
            occurredAt,
            data: {
              itemId: held.id,
              note: body.note ?? null,
              photoMediaIds: body.photoMediaIds,
              position: body.location ? { lat: body.location.lat, lng: body.location.lng } : null,
            },
          });

          return { ...held, status: toStatus };
        });

        return {
          status: 200,
          value: { item: toCustodyItem(item), appliedAt: new Date().toISOString() },
        };
      });
    },
  );

  /* ---------------------------------------------------------------- *
   * Support
   * ---------------------------------------------------------------- */

  route.post(
    '/v1/support/tickets',
    {
      schema: {
        tags: ['Support'],
        body: SupportTicketCreateRequest,
        response: { 200: SupportTicket, 400: ErrorResponse, 401: ErrorResponse },
      },
    },
    async (request) => {
      const courier = await app.authenticate(request);
      const body = request.body;

      return withIdempotency(ctx, courier, request, body, async () => {
        // The queue can replay the same ticket after a lost response; the
        // unique index on client_event_id is what stops a duplicate, not the
        // idempotency store alone, because the two can be drained separately.
        const [existing] = await ctx.db
          .select()
          .from(supportTickets)
          .where(eq(supportTickets.clientEventId, body.clientEventId))
          .limit(1);

        if (existing) return { status: 200, value: toTicket(existing) };

        const priority = priorityFor(body.category);

        const ticket = await ctx.db.transaction(async (tx) => {
          const [created] = await tx
            .insert(supportTickets)
            .values({
              tenantId: courier.tenantId,
              courierId: courier.courierId,
              reference: buildReference(),
              category: body.category,
              status: 'open',
              priority,
              subject: body.subject,
              body: body.body,
              taskId: body.taskId ?? null,
              mediaIds: body.mediaIds,
              position: body.location ? { lat: body.location.lat, lng: body.location.lng } : null,
              diagnostics: body.attachDiagnostics ? {} : null,
              clientEventId: body.clientEventId,
            })
            .returning();

          await emitEvent(tx, {
            key: 'support.ticket_created',
            tenantId: courier.tenantId,
            subjectType: 'ticket',
            subjectId: created!.id,
            actorType: 'courier',
            actorId: courier.courierId,
            correlationId: body.clientEventId,
            occurredAt: created!.createdAt,
            data: {
              category: created!.category,
              priority: created!.priority,
              taskId: created!.taskId,
              // ACCIDENT and SECURITY page a human immediately; the worker
              // decides how, but the urgency has to travel with the event.
              escalate: priority === 'critical',
            },
          });

          return created!;
        });

        return { status: 201, value: toTicket(ticket) };
      });
    },
  );

  route.get(
    '/v1/support/tickets',
    {
      schema: {
        tags: ['Support'],
        querystring: z.object({ limit: z.coerce.number().int().min(1).max(50).default(20) }),
        response: { 200: SupportTicketListResponse, 401: ErrorResponse },
      },
    },
    async (request) => {
      const courier = await app.authenticate(request);
      const rows = await ctx.db
        .select()
        .from(supportTickets)
        .where(eq(supportTickets.courierId, courier.courierId))
        .orderBy(desc(supportTickets.createdAt))
        .limit(request.query.limit);

      return { items: rows.map(toTicket), nextCursor: null, syncedAt: new Date().toISOString() };
    },
  );
}

/** A courier reporting an accident cannot wait behind an app-crash report. */
function priorityFor(category: z.infer<typeof SupportTicketCreateRequest>['category']) {
  switch (category) {
    case 'ACCIDENT':
    case 'SECURITY':
      return 'critical' as const;
    case 'RECIPIENT_UNREACHABLE':
    case 'ADDRESS_PROBLEM':
    case 'PAYMENT':
      return 'high' as const;
    default:
      return 'normal' as const;
  }
}

function buildReference(): string {
  const now = new Date();
  const stamp = `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, '0')}${String(now.getDate()).padStart(2, '0')}`;
  return `DST-${stamp}-${Math.random().toString(36).slice(2, 7).toUpperCase()}`;
}

export function toCustodyItem(item: typeof custodyItems.$inferSelect): z.infer<typeof CustodyItem> {
  return {
    id: item.id,
    type: item.type,
    barcode: item.barcode,
    description: item.description,
    quantity: item.quantity,
    amount: item.amount ? Number(item.amount) : null,
    taskId: item.taskId,
    status: item.status,
    acquiredAt: item.acquiredAt.toISOString(),
    rowVersion: item.rowVersion,
  };
}

function toTicket(ticket: typeof supportTickets.$inferSelect): z.infer<typeof SupportTicket> {
  return {
    id: ticket.id,
    reference: ticket.reference,
    category: ticket.category,
    subject: ticket.subject,
    body: ticket.body,
    status: ticket.status,
    priority: ticket.priority,
    taskId: ticket.taskId,
    media: [],
    createdAt: ticket.createdAt.toISOString(),
    updatedAt: ticket.updatedAt.toISOString(),
  };
}

async function withIdempotency<T>(
  ctx: AppContext,
  courier: AuthenticatedCourier,
  request: FastifyRequest,
  body: unknown,
  handler: () => Promise<{ status: number; value: T }>,
): Promise<T> {
  const key = request.headers['idempotency-key'];
  if (typeof key !== 'string') {
    throw new AppError('VALIDATION_FAILED', { details: [{ field: 'idempotency-key', issue: 'required' }] });
  }
  const store = new PostgresIdempotencyStore(ctx.db, courier.courierId);
  const result = await runIdempotent(store, key, body, handler);
  return result.value;
}
