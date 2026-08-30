import {
  type ErrorCode,
  ErrorResponse,
  NON_RETRYABLE_ERRORS,
  SyncBatchRequest,
  SyncBatchResponse,
  SyncChanges,
  SyncPullQuery,
  type SyncOperation,
} from '@dijigoo/contracts';
import { custodyItems, shifts, tasks, workflows } from '@dijigoo/db';
import { and, asc, eq, gt, inArray, isNull, or, sql } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { z } from 'zod';

import type { AppContext } from '../context.js';
import { toCustodyItem } from './custody.js';
import { decodeCursor, encodeCursor, toSummary } from './task.js';

/**
 * Where each queued operation is replayed. The sync endpoint does not
 * reimplement any business rule: it re-dispatches the event into the same
 * handler the online client would have hit, so geofence, workflow and
 * transition checks exist in exactly one place.
 */
const ROUTES: Record<SyncOperation, (subjectId: string | null) => { method: 'POST'; url: string }> = {
  SHIFT_START: () => ({ method: 'POST', url: '/v1/shifts/start' }),
  SHIFT_END: () => ({ method: 'POST', url: '/v1/shifts/end' }),
  TASK_TRANSITION: (id) => ({ method: 'POST', url: `/v1/tasks/${id}/transition` }),
  STEP_SUBMIT: (id) => ({ method: 'POST', url: `/v1/tasks/${id}/steps` }),
  TASK_FINALIZE: (id) => ({ method: 'POST', url: `/v1/tasks/${id}/finalize` }),
  CUSTODY_HANDOVER: () => ({ method: 'POST', url: '/v1/custody/handover' }),
  SUPPORT_TICKET_CREATE: () => ({ method: 'POST', url: '/v1/support/tickets' }),
};

const NEEDS_SUBJECT: SyncOperation[] = ['TASK_TRANSITION', 'STEP_SUBMIT', 'TASK_FINALIZE'];

/** Errors replaying cannot fix. Mirrors the shared list in the contracts. */
const TERMINAL_ERRORS = new Set<ErrorCode>([
  ...NON_RETRYABLE_ERRORS,
  'WORKFLOW_STEP_OUT_OF_ORDER',
  'DEVICE_NOT_BOUND',
]);

export async function syncRoutes(app: FastifyInstance, { ctx }: { ctx: AppContext }) {
  const route = app.withTypeProvider<ZodTypeProvider>();

  route.post(
    '/v1/sync/batch',
    {
      schema: {
        tags: ['Sync'],
        body: SyncBatchRequest,
        response: { 200: SyncBatchResponse, 401: ErrorResponse },
      },
      // The batch is already bounded to 100 events; a courier draining a full
      // day offline should not be throttled into a longer outage.
      config: { rateLimit: { max: 60, timeWindow: '1 minute' } },
    },
    async (request) => {
      const courier = await app.authenticate(request);
      const { events } = request.body;

      // Ordering matters: a STEP_SUBMIT queued before its TASK_FINALIZE must be
      // applied first, and only the device sequence can tell us that, because
      // two events can share a wall-clock millisecond.
      const ordered = [...events].sort((a, b) => a.sequence - b.sequence);

      const results: z.infer<typeof SyncBatchResponse>['results'] = [];
      let pullRequired = false;

      for (const event of ordered) {
        if (NEEDS_SUBJECT.includes(event.operation) && !event.subjectId) {
          results.push({
            clientEventId: event.clientEventId,
            status: 'rejected',
            error: {
              code: 'VALIDATION_FAILED',
              message: 'subjectId zorunlu',
              details: [],
              userVisible: false,
              traceId: request.id,
            },
            refetch: null,
            appliedAt: null,
            retryAfter: null,
          });
          continue;
        }

        const target = ROUTES[event.operation](event.subjectId ?? null);

        const response = await app.inject({
          method: target.method,
          url: target.url,
          headers: {
            authorization: request.headers.authorization!,
            'x-client-info': request.headers['x-client-info'] as string,
            // The client event id is the idempotency key. Replaying the whole
            // batch after a dropped response is therefore free.
            'idempotency-key': event.clientEventId,
            'x-request-id': request.id,
            'content-type': 'application/json',
          },
          payload: event.payload as object,
        });

        if (response.statusCode < 300) {
          const body = response.json<{ replayed?: boolean }>();
          results.push({
            clientEventId: event.clientEventId,
            status: body.replayed ? 'replayed' : 'applied',
            error: null,
            refetch: null,
            appliedAt: new Date().toISOString(),
            retryAfter: null,
          });
          continue;
        }

        const error = safeError(response.body, request.id);
        const code: ErrorCode = error?.code ?? 'INTERNAL_ERROR';

        if (code === 'VERSION_MISMATCH' || code === 'CONFLICT') {
          pullRequired = true;
          results.push({
            clientEventId: event.clientEventId,
            status: 'conflict',
            error,
            refetch: event.subjectId ? { resource: resourceOf(event.operation), id: event.subjectId } : null,
            appliedAt: null,
            retryAfter: null,
          });
          continue;
        }

        if (code === 'MEDIA_NOT_READY') {
          results.push({
            clientEventId: event.clientEventId,
            status: 'deferred',
            error,
            refetch: null,
            appliedAt: null,
            retryAfter: 30,
          });
          continue;
        }

        // Anything the courier cannot fix stays rejected so the queue drains;
        // transient failures are deferred so the event survives.
        results.push({
          clientEventId: event.clientEventId,
          status: TERMINAL_ERRORS.has(code) ? 'rejected' : 'deferred',
          error,
          refetch: null,
          appliedAt: null,
          retryAfter: TERMINAL_ERRORS.has(code) ? null : 60,
        });
      }

      request.log.info(
        {
          courierId: courier.courierId,
          batch: ordered.length,
          applied: results.filter((r) => r.status === 'applied').length,
          rejected: results.filter((r) => r.status === 'rejected').length,
        },
        'sync batch islendi',
      );

      return { results, serverTime: new Date().toISOString(), pullRequired };
    },
  );

  route.get(
    '/v1/sync/changes',
    {
      schema: {
        tags: ['Sync'],
        querystring: SyncPullQuery,
        response: { 200: SyncChanges, 401: ErrorResponse },
      },
    },
    async (request) => {
      const courier = await app.authenticate(request);
      const { since, cursor, limit } = request.query;

      const watermark = since ? new Date(since) : null;

      // Beyond the retention window a delta cannot be reconstructed, because
      // rows removed from the courier's scope have already been pruned. Say so
      // rather than handing back a silently incomplete set.
      if (watermark && Date.now() - watermark.getTime() > 14 * 24 * 3_600_000) {
        return {
          tasks: [],
          removedTaskIds: [],
          custody: [],
          removedCustodyIds: [],
          shift: null,
          workflows: [],
          nextCursor: null,
          syncedAt: new Date().toISOString(),
          resyncRequired: true,
        };
      }

      const keyset = decodeCursor(cursor);
      const changed = await ctx.db
        .select()
        .from(tasks)
        .where(
          and(
            eq(tasks.assignedCourierId, courier.courierId),
            eq(tasks.tenantId, courier.tenantId),
            watermark ? gt(tasks.updatedAt, watermark) : undefined,
            keyset
              ? or(
                  gt(tasks.updatedAt, keyset.updatedAt),
                  and(eq(tasks.updatedAt, keyset.updatedAt), gt(tasks.id, keyset.id)),
                )
              : undefined,
          ),
        )
        .orderBy(asc(tasks.updatedAt), asc(tasks.id))
        .limit(limit + 1);

      const page = changed.slice(0, limit);
      const nextCursor =
        changed.length > limit && page.length > 0
          ? encodeCursor(page[page.length - 1]!.updatedAt, page[page.length - 1]!.id)
          : null;

      // Reassignments: rows that still reference this courier historically but
      // are no longer theirs. Without this the app keeps showing a delivery
      // dispatch already gave to someone else.
      const removed = watermark
        ? await ctx.db
            .select({ id: tasks.id })
            .from(tasks)
            .where(
              and(
                eq(tasks.tenantId, courier.tenantId),
                eq(tasks.previousCourierId, courier.courierId),
                gt(tasks.updatedAt, watermark),
                sql`${tasks.assignedCourierId} is distinct from ${courier.courierId}`,
              ),
            )
        : [];

      const workflowRefs = await loadWorkflowRefs(ctx, courier.tenantId, page);

      const [openShift] = await ctx.db
        .select()
        .from(shifts)
        .where(and(eq(shifts.courierId, courier.courierId), isNull(shifts.endedAt)))
        .limit(1);

      // Custody has no updated_at: an item is either held or released, so the
      // full open set is small enough to send every time and always correct.
      const custody = await ctx.db
        .select()
        .from(custodyItems)
        .where(and(eq(custodyItems.holderCourierId, courier.courierId), isNull(custodyItems.releasedAt)))
        .limit(500);

      return {
        tasks: page.map(toSummary),
        removedTaskIds: removed.map((r) => r.id),
        custody: custody.map(toCustodyItem),
        removedCustodyIds: [],
        shift: openShift
          ? {
              id: openShift.id,
              courierId: openShift.courierId,
              status: openShift.status,
              startedAt: openShift.startedAt.toISOString(),
              endedAt: null,
              startLocation: null,
              endLocation: null,
              vehiclePlate: openShift.vehiclePlate,
              startPhoto: null,
              taskCount: openShift.taskCount,
              completedCount: openShift.completedCount,
            }
          : null,
        workflows: workflowRefs,
        nextCursor,
        syncedAt: new Date().toISOString(),
        resyncRequired: false,
      };
    },
  );
}

/**
 * Ships the workflow versions the delta references. Without this the client
 * would receive a task it cannot render and have to make a second round trip
 * per unseen version, on the worst possible connection.
 */
async function loadWorkflowRefs(ctx: AppContext, tenantId: string, page: (typeof tasks.$inferSelect)[]) {
  const ids = [...new Set(page.map((t) => t.workflowId).filter((id): id is string => Boolean(id)))];
  if (ids.length === 0) return [];

  const rows = await ctx.db
    .select({
      workflowId: workflows.id,
      key: workflows.key,
      version: workflows.version,
      minAppBuild: workflows.minAppBuild,
    })
    .from(workflows)
    .where(and(eq(workflows.tenantId, tenantId), inArray(workflows.id, ids)));

  return rows;
}

function resourceOf(operation: SyncOperation): 'task' | 'shift' | 'custody' {
  if (operation.startsWith('TASK_') || operation === 'STEP_SUBMIT') return 'task';
  if (operation.startsWith('SHIFT_')) return 'shift';
  return 'custody';
}

function safeError(body: string, traceId: string) {
  try {
    const parsed = JSON.parse(body) as { error?: { code: string; message: string; userVisible?: boolean } };
    if (!parsed.error) return null;
    return {
      code: parsed.error.code as ErrorCode,
      message: parsed.error.message,
      details: [],
      userVisible: parsed.error.userVisible ?? false,
      traceId,
    };
  } catch {
    // A non-JSON body means the failure happened before the error handler ran.
    // Treat it as retryable rather than losing the courier's event.
    return null;
  }
}
