import { GeoPoint, Timestamp, Uuid, z } from './common.js';
import { MediaRef } from './media.js';

export const ShiftStatus = z.enum(['active', 'paused', 'closed']);

export const Shift = z
  .object({
    id: Uuid,
    courierId: Uuid,
    status: ShiftStatus,
    startedAt: Timestamp,
    endedAt: Timestamp.nullish(),
    startLocation: GeoPoint.nullish(),
    endLocation: GeoPoint.nullish(),
    vehiclePlate: z.string().max(20).nullish(),
    /**
     * Shift-open selfie. Treated as special-category data under KVKK art. 6
     * until legal signs off; see docs/04-kvkk.md. The client uploads it like
     * any other media, the server stores it in a separate retention bucket.
     */
    startPhoto: MediaRef.nullish(),
    taskCount: z.number().int().nonnegative().default(0),
    completedCount: z.number().int().nonnegative().default(0),
  })
  .openapi('Shift');
export type Shift = z.infer<typeof Shift>;

export const ShiftStartRequest = z
  .object({
    clientEventId: Uuid,
    occurredAt: Timestamp,
    location: GeoPoint,
    vehiclePlate: z.string().max(20).nullish(),
    startPhotoMediaId: Uuid.nullish(),
    /**
     * Client self-report so dispatch can see why a courier's pings will be
     * sparse before the gaps show up in the data.
     */
    permissions: z.object({
      locationAlways: z.boolean(),
      notifications: z.boolean(),
      camera: z.boolean(),
      batteryOptimizationExempt: z.boolean().nullish(),
    }),
  })
  .openapi('ShiftStartRequest');

export const ShiftEndRequest = z
  .object({
    clientEventId: Uuid,
    occurredAt: Timestamp,
    location: GeoPoint.nullish(),
    note: z.string().max(1000).nullish(),
  })
  .openapi('ShiftEndRequest');

/* ------------------------------------------------------------------ *
 * Location pings
 * ------------------------------------------------------------------ */

/**
 * Batched on purpose. The background service buffers fixes and flushes every
 * 30-60 s or 250 m, whichever comes first, so a dropped connection costs one
 * batch rather than one fix.
 */
export const LocationBatchRequest = z
  .object({
    shiftId: Uuid,
    points: z.array(GeoPoint).min(1).max(500),
    /** Device battery at flush time; correlates gaps with OEM power saving. */
    batteryLevel: z.number().min(0).max(1).nullish(),
    isCharging: z.boolean().nullish(),
    networkType: z.enum(['wifi', 'cellular', 'none']).nullish(),
  })
  .openapi('LocationBatchRequest');

export const LocationBatchResponse = z
  .object({
    accepted: z.number().int().nonnegative(),
    /** Fixes dropped for bad accuracy or being older than the retention window. */
    rejected: z.number().int().nonnegative(),
    /** Server may ask the client to change cadence, e.g. to save battery. */
    nextIntervalSeconds: z.number().int().min(10).max(900).nullish(),
  })
  .openapi('LocationBatchResponse');

/* ------------------------------------------------------------------ *
 * Route
 * ------------------------------------------------------------------ */

export const RouteStop = z
  .object({
    taskId: Uuid,
    sequence: z.number().int().nonnegative(),
    etaAt: Timestamp.nullish(),
    distanceMeters: z.number().int().nonnegative().nullish(),
    durationSeconds: z.number().int().nonnegative().nullish(),
  })
  .openapi('RouteStop');

export const Route = z
  .object({
    id: Uuid,
    shiftId: Uuid,
    stops: z.array(RouteStop),
    /**
     * `sequence_only` is the Faz 1 default: ordering without live traffic.
     * `traffic_aware` requires a paid routing provider (see docs/02).
     */
    mode: z.enum(['sequence_only', 'distance_optimized', 'traffic_aware']),
    computedAt: Timestamp,
    /** Encoded polyline for map display; absent in sequence_only mode. */
    geometry: z.string().nullish(),
  })
  .openapi('Route');
