import type { WorkflowOutcome, WorkflowStep } from '@dijigoo/contracts';
import { sql } from 'drizzle-orm';
import {
  index,
  integer,
  jsonb,
  pgTable,
  text,
  timestamp,
  uniqueIndex,
  uuid,
  varchar,
} from 'drizzle-orm/pg-core';

import { workflowStatus } from './enums.js';
import { tenants } from './org.js';

/**
 * One row per (key, version). A published row is immutable: the update trigger
 * in `migrations/0002_workflow_immutability.sql` rejects any change once
 * `status = 'published'`, so rule K2 is enforced by the database rather than
 * by whoever remembers it.
 */
export const workflows = pgTable(
  'workflows',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    tenantId: uuid('tenant_id')
      .notNull()
      .references(() => tenants.id, { onDelete: 'restrict' }),
    key: varchar('key', { length: 60 }).notNull(),
    version: integer('version').notNull(),
    name: varchar('name', { length: 160 }).notNull(),
    description: text('description'),
    status: workflowStatus('status').notNull().default('draft'),
    appliesTo: jsonb('applies_to').$type<string[]>().notNull(),
    steps: jsonb('steps').$type<WorkflowStep[]>().notNull(),
    outcomes: jsonb('outcomes').$type<WorkflowOutcome[]>().notNull(),
    minAppBuild: integer('min_app_build').notNull().default(1),
    publishedAt: timestamp('published_at', { withTimezone: true }),
    publishedBy: uuid('published_by'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => ({
    keyVersionUq: uniqueIndex('workflows_key_version_uq').on(t.tenantId, t.key, t.version),
    /** At most one draft per key; operators edit in place until they publish. */
    singleDraft: uniqueIndex('workflows_single_draft_uq')
      .on(t.tenantId, t.key)
      .where(sql`status = 'draft'`),
    publishedIdx: index('workflows_published_idx')
      .on(t.tenantId, t.key, t.version)
      .where(sql`status = 'published'`),
  }),
);

/**
 * Reserved step keys. A key that ever appeared in a published version can
 * never be reused with a different meaning (rule K5), even after the step is
 * deleted, so the reservation outlives the definition that created it.
 */
export const workflowStepKeys = pgTable(
  'workflow_step_keys',
  {
    tenantId: uuid('tenant_id')
      .notNull()
      .references(() => tenants.id, { onDelete: 'cascade' }),
    workflowKey: varchar('workflow_key', { length: 60 }).notNull(),
    stepKey: varchar('step_key', { length: 60 }).notNull(),
    stepType: varchar('step_type', { length: 40 }).notNull(),
    firstSeenVersion: integer('first_seen_version').notNull(),
    lastSeenVersion: integer('last_seen_version').notNull(),
    retiredAt: timestamp('retired_at', { withTimezone: true }),
  },
  (t) => ({
    pk: uniqueIndex('workflow_step_keys_pk').on(t.tenantId, t.workflowKey, t.stepKey),
  }),
);
