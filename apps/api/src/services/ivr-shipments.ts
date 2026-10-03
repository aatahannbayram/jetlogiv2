import { AppError, emitEvent, phoneLookupHmac, toSolvelineMsisdn } from '@dijigoo/core';
import { branches, couriers, custodyItems, ivrResults, supportTickets, tasks, tenants } from '@dijigoo/db';
import type { Database } from '@dijigoo/db';
import { desc, eq, inArray, sql } from 'drizzle-orm';
import type { z } from 'zod';

import type { IvrResultRequest, IvrShipmentDetail, IvrShipmentSummary } from '@dijigoo/contracts';

import { plaintextPhone } from './masked-call.js';

export type IvrShipmentRow = {
  task: typeof tasks.$inferSelect;
  courierName: string | null;
  agencyName: string | null;
  company: string | null;
};

export async function findIvrShipmentsByPhone(
  db: Database,
  fieldKey: Buffer,
  phone: string,
): Promise<z.infer<typeof IvrShipmentSummary>[]> {
  const hmac = phoneLookupHmac(phone, fieldKey);
  if (!hmac) return [];

  const rows = await db
    .select({
      task: tasks,
      courierName: couriers.fullName,
      agencyName: branches.name,
      company: tenants.name,
    })
    .from(tasks)
    .innerJoin(tenants, eq(tenants.id, tasks.tenantId))
    .leftJoin(couriers, eq(couriers.id, tasks.courierId))
    .leftJoin(branches, eq(branches.id, tasks.branchId))
    .where(eq(tasks.contactPhoneHmac, hmac))
    .orderBy(
      sql`case when ${tasks.status} not in ('COMPLETED', 'FAILED', 'CANCELLED') then 0 else 1 end`,
      desc(tasks.createdAt),
    )
    .limit(20);

  const custody = await custodyByTaskIds(
    db,
    rows.map((r) => r.task.id),
  );
  return rows.map((row) => toIvrShipmentSummary(row, custody.get(row.task.id) ?? null));
}

export async function findIvrShipmentByReference(
  db: Database,
  fieldKey: Buffer,
  reference: string,
): Promise<z.infer<typeof IvrShipmentDetail> | null> {
  const rows = await db
    .select({
      task: tasks,
      courierName: couriers.fullName,
      agencyName: branches.name,
      company: tenants.name,
    })
    .from(tasks)
    .innerJoin(tenants, eq(tenants.id, tasks.tenantId))
    .leftJoin(couriers, eq(couriers.id, tasks.courierId))
    .leftJoin(branches, eq(branches.id, tasks.branchId))
    .where(eq(tasks.reference, reference))
    .orderBy(
      sql`case when ${tasks.status} not in ('COMPLETED', 'FAILED', 'CANCELLED') then 0 else 1 end`,
      desc(tasks.createdAt),
    )
    .limit(5);

  const row = rows[0];
  if (!row) return null;
  const custody = await custodyByTaskIds(db, [row.task.id]);
  const summary = toIvrShipmentSummary(row, custody.get(row.task.id) ?? null);
  const e164 = plaintextPhone(row.task.contactPhoneEncrypted, fieldKey);
  return {
    ...summary,
    customerPhone: e164 ? toSolvelineMsisdn(e164) : null,
  };
}

export async function createIvrTicket(
  db: Database,
  input: {
    reference: string;
    kind: 'expedite' | 'support';
    note?: string;
    correlationId: string;
  },
): Promise<{ ticketReference: string; status: 'open' }> {
  const [row] = await db
    .select()
    .from(tasks)
    .where(eq(tasks.reference, input.reference))
    .orderBy(
      sql`case when ${tasks.status} not in ('COMPLETED', 'FAILED', 'CANCELLED') then 0 else 1 end`,
      desc(tasks.createdAt),
    )
    .limit(1);
  if (!row) throw new AppError('NOT_FOUND');

  const category = input.kind === 'expedite' ? ('EXPEDITE' as const) : ('OTHER' as const);
  const subject = input.kind === 'expedite' ? 'IVR hizlandirma' : 'IVR destek';
  const body = input.note?.trim() || subject;
  const ticketReference = buildTicketReference();

  await db.transaction(async (tx) => {
    const [created] = await tx
      .insert(supportTickets)
      .values({
        tenantId: row.tenantId,
        courierId: row.courierId,
        reference: ticketReference,
        category,
        status: 'open',
        priority: input.kind === 'expedite' ? 'high' : 'normal',
        subject,
        body,
        taskId: row.id,
        clientEventId: input.correlationId,
      })
      .returning();

    await emitEvent(tx, {
      key: 'support.ticket_created',
      tenantId: row.tenantId,
      subjectType: 'ticket',
      subjectId: created!.id,
      actorType: 'integration',
      actorId: null,
      correlationId: input.correlationId,
      occurredAt: created!.createdAt,
      data: {
        category,
        source: 'solveline-ivr',
        kind: input.kind,
        taskId: row.id,
        taskReference: row.reference,
      },
    });
  });

  return { ticketReference, status: 'open' };
}

export async function recordIvrResult(
  db: Database,
  input: z.infer<typeof IvrResultRequest>,
): Promise<{ uniqueId: string; selection: z.infer<typeof IvrResultRequest>['selection']; duplicate: boolean }> {
  const [existing] = await db
    .select()
    .from(ivrResults)
    .where(eq(ivrResults.uniqueId, input.uniqueId))
    .limit(1);
  if (existing) {
    return {
      uniqueId: existing.uniqueId,
      selection: existing.selection as z.infer<typeof IvrResultRequest>['selection'],
      duplicate: true,
    };
  }

  try {
    await db.insert(ivrResults).values({
      uniqueId: input.uniqueId,
      variable: input.variable ?? null,
      selection: input.selection,
      dtmf: input.dtmf ?? null,
      calledAt: input.calledAt ? new Date(input.calledAt) : null,
      payload: input as unknown as Record<string, unknown>,
    });
  } catch {
    const [again] = await db
      .select()
      .from(ivrResults)
      .where(eq(ivrResults.uniqueId, input.uniqueId))
      .limit(1);
    if (again) {
      return {
        uniqueId: again.uniqueId,
        selection: again.selection as z.infer<typeof IvrResultRequest>['selection'],
        duplicate: true,
      };
    }
    throw new AppError('CONFLICT');
  }

  return { uniqueId: input.uniqueId, selection: input.selection, duplicate: false };
}

export function toIvrShipmentSummary(
  row: IvrShipmentRow,
  custodyAt: Date | null,
): z.infer<typeof IvrShipmentSummary> {
  const companyFromAttr =
    typeof row.task.attributes?.company === 'string' ? row.task.attributes.company : null;
  const deliveredAt =
    row.task.status === 'COMPLETED' && row.task.finalizedAt ? row.task.finalizedAt : null;
  return {
    reference: row.task.reference,
    company: companyFromAttr || row.company,
    status: row.task.status,
    custodyAt: custodyAt?.toISOString() ?? null,
    etaConfirmed: false,
    slotEndAt: row.task.slotEndAt?.toISOString() ?? null,
    deliveredAt: deliveredAt?.toISOString() ?? null,
    courierName: row.courierName,
    agencyName: row.agencyName,
  };
}

async function custodyByTaskIds(db: Database, taskIds: string[]): Promise<Map<string, Date>> {
  const map = new Map<string, Date>();
  if (taskIds.length === 0) return map;
  const rows = await db
    .select({
      taskId: custodyItems.taskId,
      acquiredAt: custodyItems.acquiredAt,
    })
    .from(custodyItems)
    .where(inArray(custodyItems.taskId, taskIds));
  for (const row of rows) {
    if (!row.taskId) continue;
    const prev = map.get(row.taskId);
    if (!prev || row.acquiredAt < prev) map.set(row.taskId, row.acquiredAt);
  }
  return map;
}

function buildTicketReference(): string {
  const now = new Date();
  const stamp = `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, '0')}${String(now.getDate()).padStart(2, '0')}`;
  return `TCK-${stamp}-${Math.random().toString(36).slice(2, 7).toUpperCase()}`;
}
