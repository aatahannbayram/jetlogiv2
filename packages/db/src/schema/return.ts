import { index, pgTable, timestamp, uniqueIndex, uuid, varchar } from 'drizzle-orm/pg-core';

import { custodyItems } from './custody';
import { returnStatusCode } from './enums';
import { tenants } from './org';

/**
 * İade/Ters Lojistik (RET) — Faz 4. `taskId` is intentionally not a FK (same
 * pattern as `delivery_results.task_id`, `documents.task_id`); `custodyItemId`
 * is a real FK since `custody.ts` is a safe one-directional import here.
 * One open return per item — a second failed delivery of the same item
 * reuses the row rather than opening a duplicate return process.
 */
export const returns = pgTable(
  'returns',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    tenantId: uuid('tenant_id')
      .notNull()
      .references(() => tenants.id, { onDelete: 'restrict' }),
    taskId: uuid('task_id').notNull(),
    custodyItemId: uuid('custody_item_id')
      .notNull()
      .references(() => custodyItems.id, { onDelete: 'cascade' }),
    status: returnStatusCode('status').notNull().default('RET-010'),
    reason: varchar('reason', { length: 160 }),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => ({
    itemUq: uniqueIndex('returns_custody_item_uq').on(t.custodyItemId),
    taskIdx: index('returns_task_idx').on(t.taskId),
  }),
);

/** Immutable transition log, same shape as `custody_item_transitions`. */
export const returnTransitions = pgTable(
  'return_transitions',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    returnId: uuid('return_id')
      .notNull()
      .references(() => returns.id, { onDelete: 'cascade' }),
    fromStatus: returnStatusCode('from_status'),
    toStatus: returnStatusCode('to_status').notNull(),
    reason: varchar('reason', { length: 160 }),
    occurredAt: timestamp('occurred_at', { withTimezone: true }).notNull(),
    recordedAt: timestamp('recorded_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => ({
    returnIdx: index('return_transitions_return_idx').on(t.returnId, t.recordedAt),
  }),
);
