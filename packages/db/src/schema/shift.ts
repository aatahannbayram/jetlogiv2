import { sql } from 'drizzle-orm';
import {
  boolean,
  doublePrecision,
  index,
  integer,
  jsonb,
  pgTable,
  real,
  smallint,
  text,
  timestamp,
  uniqueIndex,
  uuid,
  varchar,
} from 'drizzle-orm/pg-core';

import { devices } from './auth';
import { routeMode, shiftStatus } from './enums';
import { couriers } from './org';
import { geoPoint } from './types';

export const shifts = pgTable(
  'shifts',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    courierId: uuid('courier_id')
      .notNull()
      .references(() => couriers.id, { onDelete: 'cascade' }),
    deviceId: uuid('device_id').references(() => devices.id, { onDelete: 'set null' }),
    status: shiftStatus('status').notNull().default('active'),
    startedAt: timestamp('started_at', { withTimezone: true }).notNull(),
    endedAt: timestamp('ended_at', { withTimezone: true }),
    startLocation: geoPoint('start_location'),
    endLocation: geoPoint('end_location'),
    vehiclePlate: varchar('vehicle_plate', { length: 20 }),
    /**
     * Shift-open selfie. Stored in a separate retention bucket because it is
     * treated as special-category data until legal signs off (docs/04-kvkk.md).
     */
    startPhotoMediaId: uuid('start_photo_media_id'),
    /** Self-reported OS permission state at shift start. Explains ping gaps. */
    permissions: jsonb('permissions').$type<Record<string, boolean | null>>().notNull().default({}),
    taskCount: integer('task_count').notNull().default(0),
    completedCount: integer('completed_count').notNull().default(0),
    distanceMeters: integer('distance_meters').notNull().default(0),
    note: text('note'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => ({
    /** A courier can only have one shift open at a time. */
    oneOpenPerCourier: uniqueIndex('shifts_open_courier_uq')
      .on(t.courierId)
      .where(sql`ended_at is null`),
    courierStartedIdx: index('shifts_courier_started_idx').on(t.courierId, t.startedAt),
  }),
);

/**
 * High-volume append-only table. Declared as a native partitioned table in
 * `migrations/0001_partitions.sql`, one partition per month, so retention is
 * a `DROP TABLE` rather than a `DELETE` that would bloat the heap.
 *
 * Drizzle models it as a plain table; the partitioning lives in raw SQL.
 */
export const locationPings = pgTable(
  'location_pings',
  {
    id: uuid('id').notNull().defaultRandom(),
    shiftId: uuid('shift_id').notNull(),
    courierId: uuid('courier_id').notNull(),
    position: geoPoint('position').notNull(),
    accuracy: real('accuracy').notNull(),
    altitude: real('altitude'),
    heading: real('heading'),
    speed: real('speed'),
    /** Device clock. Kept raw for the audit trail even when it is wrong. */
    capturedAt: timestamp('captured_at', { withTimezone: true }).notNull(),
    /** Server clock at ingest. Authoritative for ordering. */
    recordedAt: timestamp('recorded_at', { withTimezone: true }).notNull().defaultNow(),
    isMocked: boolean('is_mocked').notNull().default(false),
    batteryLevel: real('battery_level'),
    isCharging: boolean('is_charging'),
    networkType: varchar('network_type', { length: 10 }),
  },
  (t) => ({
    /** Partition key must be part of every unique index. */
    pk: uniqueIndex('location_pings_pk').on(t.id, t.capturedAt),
    shiftTimeIdx: index('location_pings_shift_time_idx').on(t.shiftId, t.capturedAt),
    positionIdx: index('location_pings_position_idx').using('gist', t.position),
  }),
);

export const routes = pgTable(
  'routes',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    shiftId: uuid('shift_id')
      .notNull()
      .references(() => shifts.id, { onDelete: 'cascade' }),
    courierId: uuid('courier_id')
      .notNull()
      .references(() => couriers.id, { onDelete: 'cascade' }),
    mode: routeMode('mode').notNull().default('sequence_only'),
    /** Encoded polyline. Null in sequence_only mode, which is the Faz 1 default. */
    geometry: text('geometry'),
    totalDistanceMeters: integer('total_distance_meters'),
    totalDurationSeconds: integer('total_duration_seconds'),
    /** Which provider produced this, for cost attribution and debugging. */
    provider: varchar('provider', { length: 40 }),
    computedAt: timestamp('computed_at', { withTimezone: true }).notNull().defaultNow(),
    supersededAt: timestamp('superseded_at', { withTimezone: true }),
  },
  (t) => ({
    activePerShift: uniqueIndex('routes_active_shift_uq')
      .on(t.shiftId)
      .where(sql`superseded_at is null`),
  }),
);

export const routeStops = pgTable(
  'route_stops',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    routeId: uuid('route_id')
      .notNull()
      .references(() => routes.id, { onDelete: 'cascade' }),
    taskId: uuid('task_id').notNull(),
    sequence: smallint('sequence').notNull(),
    etaAt: timestamp('eta_at', { withTimezone: true }),
    distanceMeters: integer('distance_meters'),
    durationSeconds: integer('duration_seconds'),
    /** Straight-line fallback used when no routing provider answered. */
    isEstimateOnly: boolean('is_estimate_only').notNull().default(true),
  },
  (t) => ({
    routeSeqUq: uniqueIndex('route_stops_route_seq_uq').on(t.routeId, t.sequence),
    taskIdx: index('route_stops_task_idx').on(t.taskId),
  }),
);

/**
 * Geocoding is billed per call and addresses repeat constantly, so results are
 * cached on a normalised address hash. `hitCount` shows how much the cache is
 * actually saving before anyone signs a bigger contract.
 */
export const geocodeCache = pgTable(
  'geocode_cache',
  {
    addressHash: varchar('address_hash', { length: 64 }).primaryKey(),
    normalizedAddress: text('normalized_address').notNull(),
    position: geoPoint('position'),
    confidence: varchar('confidence', { length: 20 }).notNull(),
    provider: varchar('provider', { length: 40 }).notNull(),
    latitude: doublePrecision('latitude'),
    longitude: doublePrecision('longitude'),
    hitCount: integer('hit_count').notNull().default(0),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    refreshedAt: timestamp('refreshed_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => ({
    positionIdx: index('geocode_cache_position_idx').using('gist', t.position),
  }),
);
