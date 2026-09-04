import type { TaskStatus } from '@dijigoo/contracts';
import { AppError, emitEvent } from '@dijigoo/core';
import { tasks, taskTransitions } from '@dijigoo/db';
import type { Database } from '@dijigoo/db';
import { eq } from 'drizzle-orm';

import { resolveSlaInstance } from './sla.js';
import { ensureWorkOrder, transitionWorkOrder } from './work-order.js';

const TERMINAL_STATUSES: readonly TaskStatus[] = ['COMPLETED', 'FAILED', 'CANCELLED'];

/**
 * Faz 5: `ALLOWED_TASK_TRANSITIONS` deliberately keeps CANCELLED unreachable
 * from the courier-facing /transition endpoint (see the comment there —
 * "CANCELLED comes from the panel"). This is that other entry point,
 * called from the delay-decision endpoint (service-token authenticated,
 * not a courier's own request) rather than duplicated inline there.
 */
export async function cancelTask(
  tx: Database,
  ctx: { tenantId: string; correlationId: string },
  task: { id: string; tenantId: string; reference: string; status: TaskStatus; workOrderId: string | null },
  actor: { actorType: 'operator' | 'system'; actorId: string | null },
  reason: string | null,
  occurredAt: Date,
): Promise<void> {
  if (TERMINAL_STATUSES.includes(task.status)) {
    throw new AppError('TASK_ALREADY_FINALIZED', {
      details: [{ field: 'status', issue: `already_${task.status.toLowerCase()}` }],
    });
  }

  await tx.update(tasks).set({ status: 'CANCELLED' }).where(eq(tasks.id, task.id));

  await tx.insert(taskTransitions).values({
    taskId: task.id,
    fromStatus: task.status,
    toStatus: 'CANCELLED',
    actorType: actor.actorType,
    actorId: actor.actorId,
    occurredAt,
    clientEventId: crypto.randomUUID(),
    reason: reason ?? undefined,
  });

  await emitEvent(tx, {
    key: 'task.cancelled',
    tenantId: ctx.tenantId,
    subjectType: 'task',
    subjectId: task.id,
    actorType: actor.actorType,
    actorId: actor.actorId,
    correlationId: ctx.correlationId,
    occurredAt,
    data: { from: task.status, to: 'CANCELLED', reference: task.reference, reason },
  });

  // Same terminal-close sequence a courier-initiated cancellation runs in
  // task.ts's /transition handler — kept identical so WO/SLA state never
  // depends on which door the cancellation came through.
  const workOrderId = await ensureWorkOrder(tx, task);
  await transitionWorkOrder(tx, ctx, workOrderId, 'WO-120', 'task.cancelled', occurredAt);
  await resolveSlaInstance(tx, ctx, { subjectType: 'task', subjectId: task.id, resolvedAt: occurredAt });
}
