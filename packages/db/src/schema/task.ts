import { sql } from 'drizzle-orm';
import {
  boolean,
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

import { stepStatus, taskPriority, taskStatus, taskType } from './enums';
import { branches, couriers, tenants } from './org';
import { shifts } from './shift';
import { geoPoint, money } from './types';
import { workflows } from './workflow';
import { workOrders } from './work-order';

export const tasks = pgTable(
  'tasks',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    tenantId: uuid('tenant_id')
      .notNull()
      .references(() => tenants.id, { onDelete: 'restrict' }),
    branchId: uuid('branch_id').references(() => branches.id, { onDelete: 'set null' }),
    courierId: uuid('courier_id').references(() => couriers.id, { onDelete: 'set null' }),
    /**
     * Who held the task before the last reassignment. Delta sync reads this to
     * tell the previous courier the job is no longer theirs; without it their
     * app would keep showing a delivery dispatch already moved.
     */
    previousCourierId: uuid('previous_courier_id').references(() => couriers.id, {
      onDelete: 'set null',
    }),
    shiftId: uuid('shift_id').references(() => shifts.id, { onDelete: 'set null' }),
    /**
     * Faz 1 (Nihai mimari): the parallel İş Emri record. Nullable and
     * lazily backfilled — see `services/work-order.ts#ensureWorkOrder` —
     * because nothing creates a work order ahead of the task yet.
     */
    workOrderId: uuid('work_order_id').references(() => workOrders.id, { onDelete: 'set null' }),
    /** Human-facing id shared with the customer and the source system. */
    reference: varchar('reference', { length: 60 }).notNull(),
    /** Id in the upstream ERP/OMS, so a re-import updates rather than duplicates. */
    externalId: varchar('external_id', { length: 120 }),
    type: taskType('type').notNull(),
    status: taskStatus('status').notNull().default('ASSIGNED'),
    priority: taskPriority('priority').notNull().default('normal'),
    sequence: smallint('sequence').notNull().default(0),

    /**
     * Workflow is pinned at assignment and never changes for a running task
     * (rule K3). Storing the version alongside the id is redundant on purpose:
     * it makes the constraint visible in every query that reads a task.
     */
    workflowId: uuid('workflow_id').references(() => workflows.id, { onDelete: 'restrict' }),
    workflowKey: varchar('workflow_key', { length: 60 }),
    workflowVersion: integer('workflow_version'),

    addressLine1: varchar('address_line1', { length: 255 }).notNull(),
    addressLine2: varchar('address_line2', { length: 255 }),
    district: varchar('district', { length: 120 }),
    city: varchar('city', { length: 120 }).notNull(),
    postalCode: varchar('postal_code', { length: 20 }),
    countryCode: varchar('country_code', { length: 2 }).notNull().default('TR'),
    position: geoPoint('position'),
    geocodeConfidence: varchar('geocode_confidence', { length: 20 }),

    contactName: varchar('contact_name', { length: 160 }),
    /** Encrypted at rest; the app only ever receives the masked proxy number. */
    contactPhoneEncrypted: text('contact_phone_encrypted'),
    contactNote: varchar('contact_note', { length: 500 }),

    slotStartAt: timestamp('slot_start_at', { withTimezone: true }),
    slotEndAt: timestamp('slot_end_at', { withTimezone: true }),
    etaAt: timestamp('eta_at', { withTimezone: true }),
    codAmount: money('cod_amount'),
    itemCount: smallint('item_count').notNull().default(1),

    attemptNumber: smallint('attempt_number').notNull().default(1),
    maxAttempts: smallint('max_attempts').notNull().default(3),
    previousTaskId: uuid('previous_task_id'),

    outcomeCode: varchar('outcome_code', { length: 50 }),
    outcomeNote: text('outcome_note'),
    finalizedAt: timestamp('finalized_at', { withTimezone: true }),

    /** Free-form fields from the source system, addressable in conditions. */
    attributes: jsonb('attributes').$type<Record<string, unknown>>().notNull().default({}),

    /** Optimistic concurrency guard, bumped by trigger on every update. */
    rowVersion: integer('row_version').notNull().default(0),

    assignedAt: timestamp('assigned_at', { withTimezone: true }),
    startedAt: timestamp('started_at', { withTimezone: true }),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => ({
    tenantRefUq: uniqueIndex('tasks_tenant_reference_uq').on(t.tenantId, t.reference),
    externalUq: uniqueIndex('tasks_external_uq')
      .on(t.tenantId, t.externalId)
      .where(sql`external_id is not null`),
    /** Drives the courier's task list and the delta pull watermark. */
    courierFeedIdx: index('tasks_courier_feed_idx').on(t.courierId, t.updatedAt),
    /** Only reassigned rows, so the tombstone lookup stays cheap. */
    reassignedIdx: index('tasks_previous_courier_idx')
      .on(t.previousCourierId, t.updatedAt)
      .where(sql`previous_courier_id is not null`),
    openByCourierIdx: index('tasks_open_courier_idx')
      .on(t.courierId, t.sequence)
      .where(sql`status not in ('COMPLETED', 'FAILED', 'CANCELLED')`),
    positionIdx: index('tasks_position_idx').using('gist', t.position),
    statusIdx: index('tasks_status_idx').on(t.tenantId, t.status, t.createdAt),
  }),
);

export const taskItems = pgTable(
  'task_items',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    taskId: uuid('task_id')
      .notNull()
      .references(() => tasks.id, { onDelete: 'cascade' }),
    barcode: varchar('barcode', { length: 80 }),
    description: varchar('description', { length: 300 }).notNull(),
    quantity: smallint('quantity').notNull().default(1),
    weightGrams: integer('weight_grams'),
  },
  (t) => ({
    taskIdx: index('task_items_task_idx').on(t.taskId),
    barcodeIdx: index('task_items_barcode_idx').on(t.barcode),
  }),
);

/**
 * One row per answered workflow step. Append-only in spirit: a correction
 * writes a new row with a higher `revision` and the read model takes the
 * latest, so the original answer stays available for evidence disputes.
 */
export const taskSteps = pgTable(
  'task_steps',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    taskId: uuid('task_id')
      .notNull()
      .references(() => tasks.id, { onDelete: 'cascade' }),
    stepKey: varchar('step_key', { length: 60 }).notNull(),
    /** Version the answer was produced against; must equal the task's. */
    workflowVersion: integer('workflow_version').notNull(),
    revision: smallint('revision').notNull().default(1),
    status: stepStatus('status').notNull(),
    value: jsonb('value').$type<unknown>(),
    mediaIds: jsonb('media_ids').$type<string[]>().notNull().default([]),
    skipReasonCode: varchar('skip_reason_code', { length: 60 }),
    /** Set when a geofence check was overridden; surfaced in the panel for audit. */
    overrideReasonCode: varchar('override_reason_code', { length: 60 }),
    position: geoPoint('position'),
    accuracy: integer('accuracy'),
    /** Device clock, clamped into a sane window around server time. */
    occurredAt: timestamp('occurred_at', { withTimezone: true }).notNull(),
    recordedAt: timestamp('recorded_at', { withTimezone: true }).notNull().defaultNow(),
    clientEventId: uuid('client_event_id').notNull(),
  },
  (t) => ({
    latestUq: uniqueIndex('task_steps_latest_uq').on(t.taskId, t.stepKey, t.revision),
    clientEventUq: uniqueIndex('task_steps_client_event_uq').on(t.clientEventId),
    taskIdx: index('task_steps_task_idx').on(t.taskId),
  }),
);

/**
 * Immutable transition log. Every status change of every task, including the
 * ones the panel makes, so "who moved this and when" is always answerable.
 */
export const taskTransitions = pgTable(
  'task_transitions',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    taskId: uuid('task_id')
      .notNull()
      .references(() => tasks.id, { onDelete: 'cascade' }),
    fromStatus: taskStatus('from_status'),
    toStatus: taskStatus('to_status').notNull(),
    actorType: varchar('actor_type', { length: 20 }).notNull(),
    actorId: uuid('actor_id'),
    position: geoPoint('position'),
    occurredAt: timestamp('occurred_at', { withTimezone: true }).notNull(),
    recordedAt: timestamp('recorded_at', { withTimezone: true }).notNull().defaultNow(),
    clientEventId: uuid('client_event_id'),
    reason: varchar('reason', { length: 160 }),
  },
  (t) => ({
    taskIdx: index('task_transitions_task_idx').on(t.taskId, t.recordedAt),
    clientEventUq: uniqueIndex('task_transitions_client_event_uq')
      .on(t.clientEventId)
      .where(sql`client_event_id is not null`),
  }),
);

/** Proxy call sessions. The real MSISDN never leaves the server. */
export const maskedCallSessions = pgTable(
  'masked_call_sessions',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    taskId: uuid('task_id').references(() => tasks.id, { onDelete: 'set null' }),
    courierId: uuid('courier_id')
      .notNull()
      .references(() => couriers.id, { onDelete: 'cascade' }),
    target: varchar('target', { length: 20 }).notNull(),
    provider: varchar('provider', { length: 40 }).notNull(),
    providerSessionId: varchar('provider_session_id', { length: 120 }),
    proxyNumber: varchar('proxy_number', { length: 20 }).notNull(),
    startedAt: timestamp('started_at', { withTimezone: true }).notNull().defaultNow(),
    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
    connectedAt: timestamp('connected_at', { withTimezone: true }),
    durationSeconds: integer('duration_seconds'),
    /** Only stored when the tenant enabled recording and consent was captured. */
    recordingMediaId: uuid('recording_media_id'),
    hasRecording: boolean('has_recording').notNull().default(false),
  },
  (t) => ({
    taskIdx: index('masked_calls_task_idx').on(t.taskId),
    liveIdx: index('masked_calls_live_idx')
      .on(t.expiresAt)
      .where(sql`connected_at is null`),
  }),
);
