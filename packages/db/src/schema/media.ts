import {
  bigint,
  index,
  integer,
  jsonb,
  pgTable,
  timestamp,
  uniqueIndex,
  uuid,
  varchar,
} from 'drizzle-orm/pg-core';

import { mediaKind, mediaState } from './enums.js';
import { couriers, tenants } from './org.js';
import { geoPoint } from './types.js';

/**
 * Metadata only. Bytes live in object storage and are written by the client
 * through a presigned PUT, so this row exists before the upload completes and
 * moves `pending -> uploaded -> verified` as the worker checks the digest.
 */
export const media = pgTable(
  'media',
  {
    /** Client-generated, which is what makes the upload retry-safe. */
    id: uuid('id').primaryKey(),
    tenantId: uuid('tenant_id')
      .notNull()
      .references(() => tenants.id, { onDelete: 'restrict' }),
    courierId: uuid('courier_id').references(() => couriers.id, { onDelete: 'set null' }),
    kind: mediaKind('kind').notNull(),
    state: mediaState('state').notNull().default('pending'),
    contentType: varchar('content_type', { length: 80 }).notNull(),
    byteSize: bigint('byte_size', { mode: 'number' }).notNull(),
    /** Lower-case hex SHA-256 of the exact bytes, verified after upload. */
    sha256: varchar('sha256', { length: 64 }).notNull(),
    storageKey: varchar('storage_key', { length: 512 }).notNull(),
    storageBucket: varchar('storage_bucket', { length: 120 }).notNull(),
    taskId: uuid('task_id'),
    stepKey: varchar('step_key', { length: 60 }),
    capturedAt: timestamp('captured_at', { withTimezone: true }).notNull(),
    capturedLocation: geoPoint('captured_location'),
    /** EXIF-derived and app-supplied context kept for evidence disputes. */
    metadata: jsonb('metadata').$type<Record<string, unknown>>().notNull().default({}),
    uploadedAt: timestamp('uploaded_at', { withTimezone: true }),
    verifiedAt: timestamp('verified_at', { withTimezone: true }),
    rejectedReason: varchar('rejected_reason', { length: 160 }),
    /**
     * Retention deadline. The purge job deletes the object and blanks the row
     * rather than dropping it, so the evidence trail still shows something
     * existed and when it was removed.
     */
    retainUntil: timestamp('retain_until', { withTimezone: true }),
    purgedAt: timestamp('purged_at', { withTimezone: true }),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => ({
    /** Deduplicates identical uploads per tenant; the client can skip the PUT. */
    tenantDigestUq: uniqueIndex('media_tenant_digest_uq').on(t.tenantId, t.sha256),
    taskIdx: index('media_task_idx').on(t.taskId, t.stepKey),
    stateIdx: index('media_state_idx').on(t.state, t.createdAt),
    retentionIdx: index('media_retention_idx').on(t.retainUntil),
  }),
);

/** Pages that make up a scanned document, in order, plus the merged PDF. */
export const documentPages = pgTable(
  'document_pages',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    documentMediaId: uuid('document_media_id')
      .notNull()
      .references(() => media.id, { onDelete: 'cascade' }),
    pageMediaId: uuid('page_media_id')
      .notNull()
      .references(() => media.id, { onDelete: 'cascade' }),
    pageNumber: integer('page_number').notNull(),
  },
  (t) => ({
    docPageUq: uniqueIndex('document_pages_uq').on(t.documentMediaId, t.pageNumber),
  }),
);
