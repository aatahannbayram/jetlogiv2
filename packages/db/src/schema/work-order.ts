import { index, pgTable, smallint, text, timestamp, uniqueIndex, uuid, varchar } from 'drizzle-orm/pg-core';

import { deliveryResultCode, workOrderStatusCode } from './enums';
import { tenants } from './org';
import { geoPoint } from './types';

/**
 * İş Emri (WO) — the customer-facing request, kept as its own durum makinesi
 * per DIJIGOO_NIHAI_BACKEND_SISTEM_MIMARISI_V2.docx rather than folded into
 * `tasks.status` (the "tek satır sorunu" the doc argues against). Faz 1 adds
 * this *alongside* `tasks` — see ~/.claude/plans/toasty-mixing-adleman.md —
 * rather than replacing it; `tasks.workOrderId` links back here.
 *
 * Nothing in this codebase exposes a customer/integration intake endpoint
 * yet (tasks arrive already dispatched), so a WO here is created lazily the
 * first time a task needs one, starting straight at WO-070 (Aktif) — the
 * intake states WO-010..060 have no real producer yet.
 */
export const workOrders = pgTable(
  'work_orders',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    tenantId: uuid('tenant_id')
      .notNull()
      .references(() => tenants.id, { onDelete: 'restrict' }),
    /** Mirrors the originating task's reference; kept independent so a future multi-task WO does not collide. */
    reference: varchar('reference', { length: 60 }).notNull(),
    externalId: varchar('external_id', { length: 120 }),
    status: workOrderStatusCode('status').notNull().default('WO-070'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => ({
    tenantRefUq: uniqueIndex('work_orders_tenant_reference_uq').on(t.tenantId, t.reference),
    statusIdx: index('work_orders_status_idx').on(t.tenantId, t.status),
  }),
);

/** Immutable transition log, same shape as `task_transitions`. */
export const workOrderTransitions = pgTable(
  'work_order_transitions',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    workOrderId: uuid('work_order_id')
      .notNull()
      .references(() => workOrders.id, { onDelete: 'cascade' }),
    fromStatus: workOrderStatusCode('from_status'),
    toStatus: workOrderStatusCode('to_status').notNull(),
    reason: varchar('reason', { length: 160 }),
    occurredAt: timestamp('occurred_at', { withTimezone: true }).notNull(),
    recordedAt: timestamp('recorded_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => ({
    woIdx: index('work_order_transitions_wo_idx').on(t.workOrderId, t.recordedAt),
  }),
);

/**
 * Teslimat Sonucu (DLV) — one append-only row per delivery attempt/result,
 * coded from the fixed catalog rather than free text. `tasks.outcomeCode`
 * stays as-is for the quick "latest outcome" read the mobile app already
 * uses; this table is the canonical, code-cataloged audit trail alongside
 * it (see `apps/api/src/services/work-order.ts#canonicalDeliveryResultCode`
 * for the mapping from a workflow's free-form outcome code to this catalog).
 *
 * `taskId` intentionally has no `.references()` — same pattern as
 * `route_stops.task_id` in shift.ts — to avoid a circular schema import
 * between task.ts and this file.
 */
export const deliveryResults = pgTable(
  'delivery_results',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    taskId: uuid('task_id').notNull(),
    workOrderId: uuid('work_order_id').references(() => workOrders.id, { onDelete: 'set null' }),
    attemptNumber: smallint('attempt_number').notNull(),
    code: deliveryResultCode('code').notNull(),
    /** The workflow outcome code (e.g. `RECIPIENT_ABSENT`) this canonical result was derived from. */
    sourceOutcomeCode: varchar('source_outcome_code', { length: 60 }),
    note: text('note'),
    position: geoPoint('position'),
    occurredAt: timestamp('occurred_at', { withTimezone: true }).notNull(),
    recordedAt: timestamp('recorded_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => ({
    taskIdx: index('delivery_results_task_idx').on(t.taskId, t.recordedAt),
  }),
);
