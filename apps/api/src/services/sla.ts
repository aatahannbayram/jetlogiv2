import { AppError, emitEvent } from '@dijigoo/core';
import { slaInstances } from '@dijigoo/db';
import type { Database } from '@dijigoo/db';
import { and, eq, isNull } from 'drizzle-orm';

/**
 * Faz 4: a deliberately minimal SLA counter — see the comment on
 * `slaStatusCode` in enums.ts for why SLA-030 (Riskte) used to be
 * unreachable (this API had no background worker to notice a deadline
 * approaching between requests). Faz 5 (apps/worker) added that watcher —
 * it flags SLA-030 directly (see apps/worker/src/sla-watcher.ts), since a
 * poll-loop process reaching back into this app's services isn't a real
 * dependency this workspace supports. `extendSlaInstance` below is this
 * app's side of the resulting decision, reached only via the
 * delay-decision endpoint. Requests otherwise only see two synchronous
 * moments: a target recorded (SLA-010), and its resolution (SLA-050 met /
 * SLA-060 violated).
 */

/** No-op when the subject has no real deadline — this codebase does not fabricate SLA targets. */
export async function startSlaInstance(
  tx: Database,
  ctx: { tenantId: string; correlationId: string },
  input: { subjectType: string; subjectId: string; targetAt: Date | null; startedAt: Date },
): Promise<void> {
  if (!input.targetAt) return;

  const [existing] = await tx
    .select({ id: slaInstances.id })
    .from(slaInstances)
    .where(and(eq(slaInstances.subjectType, input.subjectType), eq(slaInstances.subjectId, input.subjectId)))
    .limit(1);
  if (existing) return;

  const [created] = await tx
    .insert(slaInstances)
    .values({
      tenantId: ctx.tenantId,
      subjectType: input.subjectType,
      subjectId: input.subjectId,
      targetAt: input.targetAt,
      startedAt: input.startedAt,
    })
    .onConflictDoNothing({ target: [slaInstances.subjectType, slaInstances.subjectId] })
    .returning({ id: slaInstances.id });
  if (!created) return; // lost a concurrent-create race; the other call already started it

  await emitEvent(tx, {
    key: 'sla.started',
    tenantId: ctx.tenantId,
    subjectType: 'sla',
    subjectId: created.id,
    actorType: 'system',
    actorId: null,
    correlationId: ctx.correlationId,
    occurredAt: input.startedAt,
    data: { subjectType: input.subjectType, subjectId: input.subjectId, targetAt: input.targetAt.toISOString() },
  });
}

/** No-op when no instance was ever started (no deadline existed). */
export async function resolveSlaInstance(
  tx: Database,
  ctx: { tenantId: string; correlationId: string },
  input: { subjectType: string; subjectId: string; resolvedAt: Date },
): Promise<void> {
  const [instance] = await tx
    .select()
    .from(slaInstances)
    .where(
      and(
        eq(slaInstances.subjectType, input.subjectType),
        eq(slaInstances.subjectId, input.subjectId),
        isNull(slaInstances.resolvedAt),
      ),
    )
    .limit(1);
  if (!instance) return;

  const status = input.resolvedAt.getTime() <= instance.targetAt.getTime() ? 'SLA-050' : 'SLA-060';

  await tx
    .update(slaInstances)
    .set({ status, resolvedAt: input.resolvedAt })
    .where(eq(slaInstances.id, instance.id));

  await emitEvent(tx, {
    key: 'sla.resolved',
    tenantId: ctx.tenantId,
    subjectType: 'sla',
    subjectId: instance.id,
    actorType: 'system',
    actorId: null,
    correlationId: ctx.correlationId,
    occurredAt: input.resolvedAt,
    data: {
      subjectType: input.subjectType,
      subjectId: input.subjectId,
      status,
      targetAt: instance.targetAt.toISOString(),
    },
  });
}

/**
 * Faz 5: applied by the delay-decision endpoint when the panel's operator
 * chooses "extend" instead of "cancel" for an at-risk task. Throws if there
 * is no open SLA instance to extend — the caller should not be able to
 * conjure a deadline out of nothing.
 */
export async function extendSlaInstance(
  tx: Database,
  ctx: { tenantId: string; correlationId: string },
  input: { subjectType: string; subjectId: string; newTargetAt: Date; extendedAt: Date },
): Promise<void> {
  const [instance] = await tx
    .select()
    .from(slaInstances)
    .where(
      and(
        eq(slaInstances.subjectType, input.subjectType),
        eq(slaInstances.subjectId, input.subjectId),
        isNull(slaInstances.resolvedAt),
      ),
    )
    .limit(1);

  if (!instance) {
    throw new AppError('NOT_FOUND', { message: 'Uzatilacak acik bir SLA kaydi yok.' });
  }

  await tx
    .update(slaInstances)
    .set({ targetAt: input.newTargetAt, status: 'SLA-010' })
    .where(eq(slaInstances.id, instance.id));

  await emitEvent(tx, {
    key: 'sla.extended',
    tenantId: ctx.tenantId,
    subjectType: 'sla',
    subjectId: instance.id,
    actorType: 'operator',
    actorId: null,
    correlationId: ctx.correlationId,
    occurredAt: input.extendedAt,
    data: {
      subjectType: input.subjectType,
      subjectId: input.subjectId,
      previousTargetAt: instance.targetAt.toISOString(),
      newTargetAt: input.newTargetAt.toISOString(),
    },
  });
}
