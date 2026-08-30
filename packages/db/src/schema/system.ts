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

import { actorType, outboxState } from './enums.js';
import { couriers, tenants } from './org.js';

/**
 * Transactional outbox. Domain events are written here in the same
 * transaction as the state change they describe, then relayed by the worker.
 * This is what makes "task was marked delivered but the webhook never fired"
 * impossible: either both rows commit or neither does.
 */
export const outboxEvents = pgTable(
  'outbox_events',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    tenantId: uuid('tenant_id').references(() => tenants.id, { onDelete: 'cascade' }),
    key: varchar('key', { length: 60 }).notNull(),
    schemaVersion: smallint('schema_version').notNull().default(1),
    subjectType: varchar('subject_type', { length: 20 }).notNull(),
    subjectId: uuid('subject_id').notNull(),
    actorType: actorType('actor_type').notNull(),
    actorId: uuid('actor_id'),
    correlationId: varchar('correlation_id', { length: 64 }).notNull(),
    causationId: uuid('causation_id'),
    data: jsonb('data').$type<Record<string, unknown>>().notNull(),
    occurredAt: timestamp('occurred_at', { withTimezone: true }).notNull(),
    recordedAt: timestamp('recorded_at', { withTimezone: true }).notNull().defaultNow(),
    state: outboxState('state').notNull().default('pending'),
    dispatchedAt: timestamp('dispatched_at', { withTimezone: true }),
    attempts: smallint('attempts').notNull().default(0),
    lastError: text('last_error'),
    nextAttemptAt: timestamp('next_attempt_at', { withTimezone: true }),
  },
  (t) => ({
    /** The relay's hot path: oldest pending events first. */
    pendingIdx: index('outbox_pending_idx')
      .on(t.nextAttemptAt, t.recordedAt)
      .where(sql`state = 'pending'`),
    subjectIdx: index('outbox_subject_idx').on(t.subjectType, t.subjectId, t.recordedAt),
    keyIdx: index('outbox_key_idx').on(t.key, t.recordedAt),
  }),
);

export const webhookEndpoints = pgTable(
  'webhook_endpoints',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    tenantId: uuid('tenant_id')
      .notNull()
      .references(() => tenants.id, { onDelete: 'cascade' }),
    url: varchar('url', { length: 512 }).notNull(),
    /** HMAC-SHA256 signing secret, rotated without downtime via `secretPrevious`. */
    secret: varchar('secret', { length: 128 }).notNull(),
    secretPrevious: varchar('secret_previous', { length: 128 }),
    subscribedKeys: jsonb('subscribed_keys').$type<string[]>().notNull().default([]),
    isActive: varchar('is_active', { length: 5 }).notNull().default('true'),
    /** Endpoint is muted after this many consecutive failures. */
    consecutiveFailures: smallint('consecutive_failures').notNull().default(0),
    disabledAt: timestamp('disabled_at', { withTimezone: true }),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => ({
    tenantIdx: index('webhook_endpoints_tenant_idx').on(t.tenantId),
  }),
);

export const webhookDeliveries = pgTable(
  'webhook_deliveries',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    endpointId: uuid('endpoint_id')
      .notNull()
      .references(() => webhookEndpoints.id, { onDelete: 'cascade' }),
    eventIds: jsonb('event_ids').$type<string[]>().notNull(),
    attempt: smallint('attempt').notNull().default(1),
    responseStatus: smallint('response_status'),
    responseBody: text('response_body'),
    durationMs: integer('duration_ms'),
    error: text('error'),
    /** Set when the delivery exhausted its retry schedule. */
    deadLetteredAt: timestamp('dead_lettered_at', { withTimezone: true }),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => ({
    endpointIdx: index('webhook_deliveries_endpoint_idx').on(t.endpointId, t.createdAt),
    dlqIdx: index('webhook_deliveries_dlq_idx')
      .on(t.createdAt)
      .where(sql`dead_lettered_at is not null`),
  }),
);

/**
 * Idempotency ledger. Keyed by the client-supplied UUID, scoped to the courier
 * so one courier cannot replay another's key. `requestHash` catches the client
 * bug where a key is reused with a different body.
 */
export const idempotencyKeys = pgTable(
  'idempotency_keys',
  {
    key: uuid('key').notNull(),
    courierId: uuid('courier_id')
      .notNull()
      .references(() => couriers.id, { onDelete: 'cascade' }),
    requestHash: varchar('request_hash', { length: 64 }).notNull(),
    state: varchar('state', { length: 20 }).notNull().default('in_progress'),
    responseStatus: smallint('response_status'),
    responseBody: jsonb('response_body').$type<unknown>(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    completedAt: timestamp('completed_at', { withTimezone: true }),
    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
  },
  (t) => ({
    pk: uniqueIndex('idempotency_keys_pk').on(t.key, t.courierId),
    expiryIdx: index('idempotency_keys_expiry_idx').on(t.expiresAt),
  }),
);

export const notifications = pgTable(
  'notifications',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    courierId: uuid('courier_id')
      .notNull()
      .references(() => couriers.id, { onDelete: 'cascade' }),
    kind: varchar('kind', { length: 40 }).notNull(),
    title: varchar('title', { length: 120 }),
    body: varchar('body', { length: 300 }),
    route: varchar('route', { length: 200 }),
    subjectId: uuid('subject_id'),
    collapseKey: varchar('collapse_key', { length: 60 }),
    sentAt: timestamp('sent_at', { withTimezone: true }),
    deliveredAt: timestamp('delivered_at', { withTimezone: true }),
    readAt: timestamp('read_at', { withTimezone: true }),
    failureReason: varchar('failure_reason', { length: 160 }),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => ({
    courierIdx: index('notifications_courier_idx').on(t.courierId, t.createdAt),
    unreadIdx: index('notifications_unread_idx')
      .on(t.courierId)
      .where(sql`read_at is null`),
  }),
);

/**
 * Append-only audit trail for anything a KVKK or customer dispute might ask
 * about: who read a phone number, who overrode a geofence, who purged media.
 */
export const auditLog = pgTable(
  'audit_log',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    tenantId: uuid('tenant_id').references(() => tenants.id, { onDelete: 'set null' }),
    actorType: actorType('actor_type').notNull(),
    actorId: uuid('actor_id'),
    action: varchar('action', { length: 80 }).notNull(),
    subjectType: varchar('subject_type', { length: 40 }).notNull(),
    subjectId: uuid('subject_id'),
    /** Before/after for mutations, query shape for reads. Never raw PII. */
    detail: jsonb('detail').$type<Record<string, unknown>>().notNull().default({}),
    ip: varchar('ip', { length: 45 }),
    correlationId: varchar('correlation_id', { length: 64 }),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => ({
    subjectIdx: index('audit_log_subject_idx').on(t.subjectType, t.subjectId, t.createdAt),
    actorIdx: index('audit_log_actor_idx').on(t.actorType, t.actorId, t.createdAt),
    actionIdx: index('audit_log_action_idx').on(t.action, t.createdAt),
  }),
);
