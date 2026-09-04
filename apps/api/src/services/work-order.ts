import type { DeliveryResultCode, WorkOrderStatusCode } from '@dijigoo/contracts';
import { emitEvent } from '@dijigoo/core';
import { deliveryResults, workOrderTransitions, workOrders } from '@dijigoo/db';
import type { Database } from '@dijigoo/db';
import { and, eq } from 'drizzle-orm';

/**
 * Faz 1 of the Nihai mimari plan (~/.claude/plans/toasty-mixing-adleman.md):
 * WO (İş Emri) and DLV (Teslimat Sonucu) as their own canonical-coded state,
 * added alongside `tasks` rather than replacing it. See
 * `packages/db/src/schema/work-order.ts` for the table shapes.
 *
 * Nothing in this codebase exposes a customer/integration intake endpoint
 * yet — tasks arrive already dispatched — so there is no real WO-010..060
 * (kayıt/doğrulama/kural-seti/planlama) producer. A work order is created
 * lazily here, the first time a task needs one, starting straight at WO-070
 * (Aktif). WO only moves again at the two genuine terminal moments this
 * codebase can observe: a task finalizing successfully (→ WO-110 Tamamlandı)
 * or a task being cancelled (→ WO-120 İptal Edildi). A failed *attempt*
 * (task FAILED) does not end the WO — the work order can still be retried
 * or reassigned, matching DLV being a per-attempt append-only record while
 * WO tracks the request as a whole.
 */

/**
 * Maps a workflow's free-form outcome code (defined per workflow version,
 * e.g. `packages/contracts/schemas/examples/standart-teslimat.v3.json`) to
 * the fixed canonical DLV catalog. Unrecognized codes fall back to DLV-190
 * (Diğer / Merkez Desteği) rather than throwing — a workflow author adding a
 * new outcome code should not be able to break delivery finalization.
 */
const OUTCOME_TO_DLV: Record<string, DeliveryResultCode> = {
  DELIVERED: 'DLV-010',
  RECIPIENT_ABSENT: 'DLV-080',
  ADDRESS_NOT_FOUND: 'DLV-090',
  REFUSED: 'DLV-110',
  POSTPONED: 'DLV-140',
};

export function canonicalDeliveryResultCode(outcomeCode: string): DeliveryResultCode {
  return OUTCOME_TO_DLV[outcomeCode] ?? 'DLV-190';
}

/** Idempotent: returns the task's existing work order if it already has one. */
export async function ensureWorkOrder(
  tx: Database,
  task: { id: string; tenantId: string; reference: string; workOrderId: string | null },
): Promise<string> {
  if (task.workOrderId) return task.workOrderId;

  const [created] = await tx
    .insert(workOrders)
    .values({ tenantId: task.tenantId, reference: task.reference })
    .onConflictDoNothing({ target: [workOrders.tenantId, workOrders.reference] })
    .returning({ id: workOrders.id });

  // Conflict means a concurrent call already created it — read it back.
  const workOrderId =
    created?.id ??
    (
      await tx
        .select({ id: workOrders.id })
        .from(workOrders)
        .where(and(eq(workOrders.tenantId, task.tenantId), eq(workOrders.reference, task.reference)))
        .limit(1)
    )[0]?.id;

  if (!workOrderId) throw new Error(`work order provisioning failed for task ${task.id}`);

  return workOrderId;
}

export async function transitionWorkOrder(
  tx: Database,
  ctx: { tenantId: string; correlationId: string },
  workOrderId: string,
  toStatus: WorkOrderStatusCode,
  reason: string,
  occurredAt: Date,
): Promise<void> {
  const [current] = await tx
    .select({ status: workOrders.status })
    .from(workOrders)
    .where(eq(workOrders.id, workOrderId))
    .limit(1);
  if (!current || current.status === toStatus) return;

  await tx.update(workOrders).set({ status: toStatus, updatedAt: occurredAt }).where(eq(workOrders.id, workOrderId));

  await tx.insert(workOrderTransitions).values({
    workOrderId,
    fromStatus: current.status,
    toStatus,
    reason,
    occurredAt,
  });

  await emitEvent(tx, {
    key: 'work_order.transitioned',
    tenantId: ctx.tenantId,
    subjectType: 'work_order',
    subjectId: workOrderId,
    actorType: 'system',
    actorId: null,
    correlationId: ctx.correlationId,
    occurredAt,
    data: { from: current.status, to: toStatus, reason },
  });
}

export async function recordDeliveryResult(
  tx: Database,
  ctx: { tenantId: string; correlationId: string },
  input: {
    taskId: string;
    workOrderId: string;
    attemptNumber: number;
    outcomeCode: string;
    note: string | null;
    position: { lat: number; lng: number } | null;
    occurredAt: Date;
  },
): Promise<{ id: string }> {
  const code = canonicalDeliveryResultCode(input.outcomeCode);

  const [created] = await tx
    .insert(deliveryResults)
    .values({
      taskId: input.taskId,
      workOrderId: input.workOrderId,
      attemptNumber: input.attemptNumber,
      code,
      sourceOutcomeCode: input.outcomeCode,
      note: input.note,
      position: input.position,
      occurredAt: input.occurredAt,
    })
    .returning({ id: deliveryResults.id });

  await emitEvent(tx, {
    key: 'delivery_result.recorded',
    tenantId: ctx.tenantId,
    subjectType: 'delivery_result',
    subjectId: input.taskId,
    actorType: 'courier',
    actorId: null,
    correlationId: ctx.correlationId,
    occurredAt: input.occurredAt,
    data: { taskId: input.taskId, workOrderId: input.workOrderId, code, sourceOutcomeCode: input.outcomeCode },
  });

  return created!;
}
