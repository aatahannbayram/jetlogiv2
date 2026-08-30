import { index, pgTable, timestamp, uniqueIndex, uuid, varchar } from 'drizzle-orm/pg-core';

import { slaStatusCode } from './enums';
import { tenants } from './org';

/**
 * SLA/İstisna — Faz 4, deliberately minimal (see the comment on
 * `slaStatusCode` in enums.ts for why SLA-030 Riskte is never reached).
 * Generic over `subjectType`/`subjectId` like `quality_reviews` rather than
 * a `task_id` FK — the doc's SLA model tracks many kinds of subjects
 * (work order, delivery, evrak dönüşü...), this codebase only ever
 * instantiates it for a task's delivery window today.
 */
export const slaInstances = pgTable(
  'sla_instances',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    tenantId: uuid('tenant_id')
      .notNull()
      .references(() => tenants.id, { onDelete: 'restrict' }),
    subjectType: varchar('subject_type', { length: 20 }).notNull(),
    subjectId: uuid('subject_id').notNull(),
    targetAt: timestamp('target_at', { withTimezone: true }).notNull(),
    status: slaStatusCode('status').notNull().default('SLA-010'),
    startedAt: timestamp('started_at', { withTimezone: true }).notNull(),
    resolvedAt: timestamp('resolved_at', { withTimezone: true }),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => ({
    subjectUq: uniqueIndex('sla_instances_subject_uq').on(t.subjectType, t.subjectId),
  }),
);
