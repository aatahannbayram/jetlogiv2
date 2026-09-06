import { optimizeStopOrder } from './optimizer.js';
import type { RoutingProvider } from './routing.js';

export interface OptimizeStop {
  id: string;
  lat: number;
  lng: number;
}

export interface OptimizedStopResult {
  id: string;
  sequence: number;
  etaAt: string;
  distanceMeters: number | null;
  durationSeconds: number | null;
}

export interface OptimizedRouteResult {
  mode: 'sequence_only' | 'distance_optimized' | 'traffic_aware';
  geometry: string | null;
  totalDistanceMeters: number | null;
  totalDurationSeconds: number | null;
  isEstimateOnly: boolean;
  provider: string;
  stops: OptimizedStopResult[];
}

/**
 * Same nearest-neighbour/2-opt + OSRM pipeline as `GET /v1/routes/current`
 * (`routes/routing.ts`), pulled out so it can run against a caller-supplied
 * stop list with no `tasks`/`shifts` row involved — see
 * `routes/routing-service.ts` and `docs/05-panel-entegrasyonu.md` Faz 4.
 * Index 0 of [input] is treated as the fixed start, same convention as the
 * courier endpoint.
 */
export async function buildOptimizedRoute(
  routing: RoutingProvider,
  input: OptimizeStop[],
  startAt: Date = new Date(),
): Promise<OptimizedRouteResult> {
  let stops = input;
  if (input.length > 2 && routing.computeMatrix) {
    const matrix = await routing.computeMatrix(input.map((s) => ({ taskId: s.id, lat: s.lat, lng: s.lng })));
    if (matrix) {
      const order = optimizeStopOrder(matrix);
      stops = order.map((i) => input[i]!);
    }
  }

  const computed = await routing.computeRoute(stops.map((s) => ({ taskId: s.id, lat: s.lat, lng: s.lng })));

  let eta = startAt;
  const stopResults: OptimizedStopResult[] = stops.map((stop, i) => {
    const leg = i === 0 ? null : computed.legs[i - 1];
    if (leg) eta = new Date(eta.getTime() + (leg.durationSeconds ?? 0) * 1000);
    return {
      id: stop.id,
      sequence: i,
      etaAt: eta.toISOString(),
      distanceMeters: leg?.distanceMeters ?? null,
      durationSeconds: leg?.durationSeconds ?? null,
    };
  });

  return {
    mode: computed.mode,
    geometry: computed.geometry,
    totalDistanceMeters: computed.totalDistanceMeters,
    totalDurationSeconds: computed.totalDurationSeconds,
    isEstimateOnly: computed.isEstimateOnly,
    provider: computed.provider,
    stops: stopResults,
  };
}
