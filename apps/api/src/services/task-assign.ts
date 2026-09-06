import type { TaskStatus } from '@dijigoo/contracts';
import { AppError, emitEvent } from '@dijigoo/core';
import { couriers, tasks } from '@dijigoo/db';
import type { Database } from '@dijigoo/db';
import { and, eq, isNull } from 'drizzle-orm';

const TERMINAL: readonly TaskStatus[] = ['COMPLETED', 'FAILED', 'CANCELLED'];

export interface AssignTaskResult {
  taskId: string;
  courierId: string;
  previousCourierId: string | null;
  alreadyAssigned: boolean;
  reference: string;
}

export async function assignTask(
  tx: Database,
  ctx: { tenantId?: string; correlationId: string },
  input: {
    taskId: string;
    courierId: string;
    operatorId?: string | null;
    reason?: string | null;
    occurredAt: Date;
  },
): Promise<AssignTaskResult> {
  const [task] = await tx.select().from(tasks).where(eq(tasks.id, input.taskId)).limit(1);
  if (!task) throw new AppError('NOT_FOUND');

  if (TERMINAL.includes(task.status)) {
    throw new AppError('TASK_ALREADY_FINALIZED', {
      details: [{ field: 'status', issue: `already_${task.status.toLowerCase()}` }],
    });
  }

  const [courier] = await tx
    .select({ id: couriers.id, tenantId: couriers.tenantId })
    .from(couriers)
    .where(and(eq(couriers.id, input.courierId), isNull(couriers.deletedAt)))
    .limit(1);
  if (!courier || courier.tenantId !== task.tenantId) {
    throw new AppError('NOT_FOUND', {
      details: [{ field: 'courierId', issue: 'unknown_or_foreign' }],
    });
  }

  if (task.courierId === input.courierId) {
    return {
      taskId: task.id,
      courierId: input.courierId,
      previousCourierId: task.previousCourierId,
      alreadyAssigned: true,
      reference: task.reference,
    };
  }

  const previousCourierId = task.courierId;
  await tx
    .update(tasks)
    .set({
      courierId: input.courierId,
      previousCourierId,
      assignedAt: input.occurredAt,
      updatedAt: input.occurredAt,
    })
    .where(eq(tasks.id, task.id));

  await emitEvent(tx, {
    key: 'task.assigned',
    tenantId: ctx.tenantId ?? task.tenantId,
    subjectType: 'task',
    subjectId: task.id,
    actorType: 'operator',
    actorId: input.operatorId ?? null,
    correlationId: ctx.correlationId,
    occurredAt: input.occurredAt,
    data: {
      reference: task.reference,
      fromCourierId: previousCourierId,
      toCourierId: input.courierId,
      reason: input.reason ?? null,
    },
  });

  return {
    taskId: task.id,
    courierId: input.courierId,
    previousCourierId,
    alreadyAssigned: false,
    reference: task.reference,
  };
}
