import { Coordinates, Timestamp, z } from './common.js';

/**
 * Service-to-service routing: a caller with its own stops (not our
 * `tasks`/`shifts` tables — see jetlogi-panel's `Shipment`) gets back an
 * optimized order using our self-hosted OSRM + nearest-neighbour/2-opt
 * engine (`services/routing.ts`, `services/optimizer.ts`), same as
 * `GET /v1/routes/current` but stateless: no DB read/write, no courier
 * identity, generic `id` rather than `taskId`. Guarded by
 * `authenticateService` (see `plugins/service-auth.ts`), not the courier
 * bearer token. Faz 4 of docs/05-panel-entegrasyonu.md.
 */
export const RoutingOptimizeStop = Coordinates.extend({
  /** Caller's own identifier for this stop (e.g. a shipment id) — opaque to us, echoed back unchanged. */
  id: z.string().min(1).max(191),
}).openapi('RoutingOptimizeStop');
export type RoutingOptimizeStop = z.infer<typeof RoutingOptimizeStop>;

export const RoutingOptimizeRequest = z
  .object({
    /** Index 0 is fixed as the start (courier's current/first stop) — only indices 1..n-1 get reordered. */
    stops: z.array(RoutingOptimizeStop).min(1).max(200),
    /** Basis for each stop's `etaAt`. Defaults to server time when omitted. */
    startAt: Timestamp.nullish(),
  })
  .openapi('RoutingOptimizeRequest');
export type RoutingOptimizeRequest = z.infer<typeof RoutingOptimizeRequest>;

export const RoutingOptimizeStopResult = z
  .object({
    id: z.string(),
    sequence: z.number().int().nonnegative(),
    etaAt: Timestamp.nullish(),
    /** Leg from the previous stop; null for sequence 0 (nothing precedes it). */
    distanceMeters: z.number().int().nonnegative().nullish(),
    durationSeconds: z.number().int().nonnegative().nullish(),
  })
  .openapi('RoutingOptimizeStopResult');

export const RoutingOptimizeResponse = z
  .object({
    mode: z.enum(['sequence_only', 'distance_optimized', 'traffic_aware']),
    /** Encoded polyline (Google algorithm, precision 5); null when the provider gave no geometry. */
    geometry: z.string().nullish(),
    totalDistanceMeters: z.number().int().nonnegative().nullish(),
    totalDurationSeconds: z.number().int().nonnegative().nullish(),
    /** Straight-line guess rather than a real road-network result (OSRM unreachable or not configured). */
    isEstimateOnly: z.boolean(),
    provider: z.string(),
    stops: z.array(RoutingOptimizeStopResult),
  })
  .openapi('RoutingOptimizeResponse');
export type RoutingOptimizeResponse = z.infer<typeof RoutingOptimizeResponse>;
