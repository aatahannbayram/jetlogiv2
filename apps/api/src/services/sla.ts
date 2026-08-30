import { slaInstances } from '@dijigoo/db';
import type { Database } from '@dijigoo/db';
import { and, eq, isNull } from 'drizzle-orm';

import { emitEvent } from './outbox.js';

/**
 * Faz 4: a deliberately minimal SLA counter — see the comment on
 * `slaStatusCode` in enums.ts for why SLA-030 (Riskte) is never reached
 * (this API has no background worker to notice a deadline approaching
 * between requests). Only two things happen: a target is recorded
 * (SLA-010), and it is later resolved against that target (SLA-050 met /
 * SLA-060 violated) — both synchronous, request-driven moments.
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
