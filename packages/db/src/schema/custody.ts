import { sql } from 'drizzle-orm';
import {
  index,
  integer,
  jsonb,
  pgTable,
  smallint,
  text,
  timestamp,
  uniqueIndex,
  uuid,
  varchar,
} from 'drizzle-orm/pg-core';

import {
  counterpartyKind,
  custodyDirection,
  custodyItemType,
  productStatusCode,
  supportCategory,
  supportPriority,
  supportStatus,
} from './enums';
import { couriers, tenants } from './org';
import { tasks } from './task';
import { geoPoint, money } from './types';

/**
 * What a courier is currently accountable for. `holderCourierId` is null once
 * the item has been handed over, which is what makes "who has it right now"
 * a single indexed lookup instead of a walk through the handover history.
 */
export const custodyItems = pgTable(
  'custody_items',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    tenantId: uuid('tenant_id')
      .notNull()
      .references(() => tenants.id, { onDelete: 'restrict' }),
    holderCourierId: uuid('holder_courier_id').references(() => couriers.id, {
      onDelete: 'set null',
    }),
    type: custodyItemType('type').notNull(),
    barcode: varchar('barcode', { length: 80 }),
    description: varchar('description', { length: 300 }).notNull(),
    quantity: smallint('quantity').notNull().default(1),
    amount: money('amount'),
    taskId: uuid('task_id').references(() => tasks.id, { onDelete: 'set null' }),
    /**
     * Faz 2 (Nihai mimari): canonical PRD status, alongside the
     * `holderCourierId`/`releasedAt` pair that already answers "who has it
     * now" — `status` answers "where is it in the product lifecycle."
     * Defaults to PRD-100 (Kuryeye Zimmet) because every item that exists in
     * this table today arrives already courier-held; nothing in this
     * codebase populates PRD-010..070 (depot intake) yet.
     */
    status: productStatusCode('status').notNull().default('PRD-100'),
    acquiredAt: timestamp('acquired_at', { withTimezone: true }).notNull().defaultNow(),
    releasedAt: timestamp('released_at', { withTimezone: true }),
    rowVersion: integer('row_version').notNull().default(0),
  },
  (t) => ({
    holderIdx: index('custody_items_holder_idx')
      .on(t.holderCourierId)
      .where(sql`released_at is null`),
    barcodeUq: uniqueIndex('custody_items_barcode_uq')
      .on(t.tenantId, t.barcode)
      .where(sql`barcode is not null and released_at is null`),
    taskIdx: index('custody_items_task_idx').on(t.taskId),
  }),
);

export const custodyHandovers = pgTable(
  'custody_handovers',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    tenantId: uuid('tenant_id')
      .notNull()
      .references(() => tenants.id, { onDelete: 'restrict' }),
    courierId: uuid('courier_id')
      .notNull()
      .references(() => couriers.id, { onDelete: 'cascade' }),
    direction: custodyDirection('direction').notNull(),
    counterpartyKind: counterpartyKind('counterparty_kind').notNull(),
    counterpartyId: uuid('counterparty_id'),
    counterpartyName: varchar('counterparty_name', { length: 160 }).notNull(),
    signatureMediaId: uuid('signature_media_id'),
    photoMediaIds: jsonb('photo_media_ids').$type<string[]>().notNull().default([]),
    /** Server-generated PDF receipt, produced by the worker after commit. */
    receiptMediaId: uuid('receipt_media_id'),
    position: geoPoint('position'),
    note: text('note'),
    occurredAt: timestamp('occurred_at', { withTimezone: true }).notNull(),
    recordedAt: timestamp('recorded_at', { withTimezone: true }).notNull().defaultNow(),
    clientEventId: uuid('client_event_id').notNull(),
  },
  (t) => ({
    clientEventUq: uniqueIndex('custody_handovers_client_event_uq').on(t.clientEventId),
    courierIdx: index('custody_handovers_courier_idx').on(t.courierId, t.recordedAt),
  }),
);

export const custodyHandoverItems = pgTable(
  'custody_handover_items',
  {
    handoverId: uuid('handover_id')
      .notNull()
      .references(() => custodyHandovers.id, { onDelete: 'cascade' }),
    itemId: uuid('item_id')
      .notNull()
      .references(() => custodyItems.id, { onDelete: 'restrict' }),
    /** Set when the counted quantity did not match what was on record. */
    discrepancy: varchar('discrepancy', { length: 120 }),
  },
  (t) => ({
    pk: uniqueIndex('custody_handover_items_pk').on(t.handoverId, t.itemId),
    itemIdx: index('custody_handover_items_item_idx').on(t.itemId),
  }),
);

/** Immutable transition log for `custody_items.status`, same shape as `task_transitions`. */
export const custodyItemTransitions = pgTable(
  'custody_item_transitions',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    itemId: uuid('item_id')
      .notNull()
      .references(() => custodyItems.id, { onDelete: 'cascade' }),
    fromStatus: productStatusCode('from_status'),
    toStatus: productStatusCode('to_status').notNull(),
    reason: varchar('reason', { length: 160 }),
    occurredAt: timestamp('occurred_at', { withTimezone: true }).notNull(),
    recordedAt: timestamp('recorded_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => ({
    itemIdx: index('custody_item_transitions_item_idx').on(t.itemId, t.recordedAt),
  }),
);

/* ------------------------------------------------------------------ *
 * Support
 * ------------------------------------------------------------------ */

export const supportTickets = pgTable(
  'support_tickets',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    tenantId: uuid('tenant_id')
      .notNull()
      .references(() => tenants.id, { onDelete: 'restrict' }),
    courierId: uuid('courier_id')
      .notNull()
      .references(() => couriers.id, { onDelete: 'cascade' }),
    reference: varchar('reference', { length: 40 }).notNull(),
    category: supportCategory('category').notNull(),
    status: supportStatus('status').notNull().default('open'),
    priority: supportPriority('priority').notNull().default('normal'),
    subject: varchar('subject', { length: 160 }).notNull(),
    body: text('body').notNull(),
    taskId: uuid('task_id').references(() => tasks.id, { onDelete: 'set null' }),
    mediaIds: jsonb('media_ids').$type<string[]>().notNull().default([]),
    position: geoPoint('position'),
    /** Opt-in on-device log excerpt; can contain addresses, so it is opt-in. */
    diagnostics: jsonb('diagnostics').$type<Record<string, unknown>>(),
    assignedOperatorId: uuid('assigned_operator_id'),
    resolvedAt: timestamp('resolved_at', { withTimezone: true }),
    clientEventId: uuid('client_event_id'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => ({
    referenceUq: uniqueIndex('support_tickets_reference_uq').on(t.tenantId, t.reference),
    clientEventUq: uniqueIndex('support_tickets_client_event_uq')
      .on(t.clientEventId)
      .where(sql`client_event_id is not null`),
    courierIdx: index('support_tickets_courier_idx').on(t.courierId, t.createdAt),
    openIdx: index('support_tickets_open_idx')
      .on(t.tenantId, t.priority, t.createdAt)
      .where(sql`status in ('open', 'in_progress')`),
  }),
);

export const supportMessages = pgTable(
  'support_messages',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    ticketId: uuid('ticket_id')
      .notNull()
      .references(() => supportTickets.id, { onDelete: 'cascade' }),
    authorType: varchar('author_type', { length: 20 }).notNull(),
    authorId: uuid('author_id'),
    body: text('body').notNull(),
    mediaIds: jsonb('media_ids').$type<string[]>().notNull().default([]),
    /** Internal notes are never returned to the mobile client. */
    isInternal: varchar('is_internal', { length: 5 }).notNull().default('false'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => ({
    ticketIdx: index('support_messages_ticket_idx').on(t.ticketId, t.createdAt),
  }),
);
