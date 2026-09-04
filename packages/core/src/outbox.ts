import type { EventKey } from '@dijigoo/contracts';
import { outboxEvents } from '@dijigoo/db';
import type { Database } from '@dijigoo/db';

export interface EmitInput {
  key: EventKey;
  tenantId: string;
  subjectType:
    | 'courier'
    | 'shift'
    | 'task'
    | 'custody'
    | 'workflow'
    | 'ticket'
    | 'work_order'
    | 'delivery_result'
    | 'document'
    | 'quality_review'
    | 'return'
    | 'sla';
  subjectId: string;
  actorType: 'courier' | 'operator' | 'system' | 'integration';
  actorId?: string | null;
  correlationId: string;
  causationId?: string | null;
  occurredAt: Date;
  data: Record<string, unknown>;
}

/**
 * Transactional outbox writer. Shared between apps/api (every state change
 * that needs an audit/webhook trail) and apps/worker (the sla.at_risk
 * watcher) — moved here rather than kept app-local once a second process
 * needed to write the same table the same way.
 *
 * Always called with the same transaction handle as the state change it
 * describes. That is the whole point: a task cannot be marked delivered
 * without the corresponding event being durably queued, and the event cannot
 * be queued for a change that rolled back.
 */
export async function emitEvent(tx: Database, input: EmitInput): Promise<void> {
  await tx.insert(outboxEvents).values({
    key: input.key,
    tenantId: input.tenantId,
    subjectType: input.subjectType,
    subjectId: input.subjectId,
    actorType: input.actorType,
    actorId: input.actorId ?? null,
    correlationId: input.correlationId,
    causationId: input.causationId ?? null,
    occurredAt: input.occurredAt,
    data: input.data,
    state: 'pending',
    nextAttemptAt: new Date(),
  });
}

export async function emitEvents(tx: Database, inputs: EmitInput[]): Promise<void> {
  if (inputs.length === 0) return;
  await tx.insert(outboxEvents).values(
    inputs.map((input) => ({
      key: input.key,
      tenantId: input.tenantId,
      subjectType: input.subjectType,
      subjectId: input.subjectId,
      actorType: input.actorType,
      actorId: input.actorId ?? null,
      correlationId: input.correlationId,
      causationId: input.causationId ?? null,
      occurredAt: input.occurredAt,
      data: input.data,
      state: 'pending' as const,
      nextAttemptAt: new Date(),
    })),
  );
}
