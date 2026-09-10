import { emitEvent, insertCourierNotification, type InboxPushInput } from '@dijigoo/core';
import { slaInstances, tasks } from '@dijigoo/db';
import type { Database } from '@dijigoo/db';
import { and, eq, isNull, lte } from 'drizzle-orm';

export interface SlaFlag {
  subjectType: string;
  subjectId: string;
  push?: InboxPushInput;
}

/**
 * The clock-watcher this codebase never had before Faz 5 — see the comment
 * on `slaStatusCode` in packages/db/src/schema/enums.ts for why SLA-030
 * (Riskte) used to be unreachable: nothing ran between requests to notice a
 * deadline approaching. This is that "something", called on a poll tick
 * from index.ts. Row-locks candidates first (same pattern as custody
 * handover in apps/api) so two worker instances polling at once cannot
 * both flag, and therefore both emit an event for, the same instance.
 */
export async function flagAtRiskSlaInstances(
  db: Database,
  input: { riskWindowMinutes: number; now?: Date },
): Promise<SlaFlag[]> {
  const now = input.now ?? new Date();
  const riskBefore = new Date(now.getTime() + input.riskWindowMinutes * 60_000);

  return db.transaction(async (tx) => {
    const candidates = await tx
      .select()
      .from(slaInstances)
      .where(
        and(eq(slaInstances.status, 'SLA-010'), isNull(slaInstances.resolvedAt), lte(slaInstances.targetAt, riskBefore)),
      )
      .for('update');

    const flagged: SlaFlag[] = [];
    for (const instance of candidates) {
      await tx.update(slaInstances).set({ status: 'SLA-030' }).where(eq(slaInstances.id, instance.id));

      await emitEvent(tx, {
        key: 'sla.at_risk',
        tenantId: instance.tenantId,
        subjectType: 'sla',
        subjectId: instance.id,
        actorType: 'system',
        actorId: null,
        correlationId: crypto.randomUUID(),
        occurredAt: now,
        data: {
          subjectType: instance.subjectType,
          subjectId: instance.subjectId,
          targetAt: instance.targetAt.toISOString(),
        },
      });

      if (instance.subjectType === 'task') {
        const [task] = await tx
          .select({ id: tasks.id, courierId: tasks.courierId, reference: tasks.reference })
          .from(tasks)
          .where(eq(tasks.id, instance.subjectId))
          .limit(1);
        if (task?.courierId) {
          const row = await insertCourierNotification(tx, {
            courierId: task.courierId,
            kind: 'SLA_AT_RISK',
            title: 'SLA riskte',
            body: `${task.reference} · teslim penceresi yaklaşıyor.`,
            subjectId: task.id,
            collapseKey: `sla:${task.id}`,
            route: `task:${task.id}`,
          });
          flagged.push({
            subjectType: instance.subjectType,
            subjectId: instance.subjectId,
            push: {
              courierId: task.courierId,
              id: row.id,
              kind: row.kind,
              title: row.title,
              body: row.body,
              subjectId: row.subjectId,
              route: row.route,
              collapseKey: row.collapseKey,
            },
          });
          continue;
        }
      }

      flagged.push({ subjectType: instance.subjectType, subjectId: instance.subjectId });
    }
    return flagged;
  });
}
