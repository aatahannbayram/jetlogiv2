import { index, pgTable, timestamp, uniqueIndex, uuid, varchar } from 'drizzle-orm/pg-core';

import { documentStatusCode } from './enums';
import { media } from './media';
import { tenants } from './org';

/**
 * Evrak (DOC) — Faz 2'deki `custody_items`/Faz 1'deki `work_orders` ile aynı
 * şekil: kanonik kod, kendi audit tablosu. `taskId` kasıtlı olarak
 * `.references()` almıyor — `media.task_id` ile aynı desen, task.ts ile
 * dairesel import'tan kaçınmak için (bkz. packages/db/src/schema/media.ts).
 *
 * `(task_id, source_step_key)` başına bir kayıt — aynı görevde hem bir
 * DOCUMENT_SCAN hem bir SIGNATURE adımı varsa iki ayrı evrak kaydı olur.
 */
export const documents = pgTable(
  'documents',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    tenantId: uuid('tenant_id')
      .notNull()
      .references(() => tenants.id, { onDelete: 'restrict' }),
    taskId: uuid('task_id').notNull(),
    /** The workflow step (SIGNATURE, DOCUMENT_SCAN, ...) that produced this. */
    sourceStepKey: varchar('source_step_key', { length: 60 }).notNull(),
    /** First media item attached to that step submission, if any. */
    mediaId: uuid('media_id').references(() => media.id, { onDelete: 'set null' }),
    status: documentStatusCode('status').notNull().default('DOC-010'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => ({
    taskStepUq: uniqueIndex('documents_task_step_uq').on(t.taskId, t.sourceStepKey),
    taskIdx: index('documents_task_idx').on(t.taskId),
  }),
);

/** Immutable transition log, same shape as `work_order_transitions`. */
export const documentTransitions = pgTable(
  'document_transitions',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    documentId: uuid('document_id')
      .notNull()
      .references(() => documents.id, { onDelete: 'cascade' }),
    fromStatus: documentStatusCode('from_status'),
    toStatus: documentStatusCode('to_status').notNull(),
    reason: varchar('reason', { length: 160 }),
    occurredAt: timestamp('occurred_at', { withTimezone: true }).notNull(),
    recordedAt: timestamp('recorded_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => ({
    docIdx: index('document_transitions_doc_idx').on(t.documentId, t.recordedAt),
  }),
);
