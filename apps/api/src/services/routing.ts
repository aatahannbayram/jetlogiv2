import type { Env } from '../env.js';

export interface RouteWaypoint {
  taskId: string;
  lat: number;
  lng: number;
}

export interface RouteLeg {
  taskId: string;
  distanceMeters: number | null;
  durationSeconds: number | null;
}

export interface ComputedRoute {
  mode: 'sequence_only' | 'distance_optimized' | 'traffic_aware';
  /** Encoded polyline (Google algorithm, precision 5). Null when the provider gave no geometry. */
  geometry: string | null;
  totalDistanceMeters: number | null;
  totalDurationSeconds: number | null;
  legs: RouteLeg[];
  /** Straight-line guess rather than a real road-network result — mirrors `route_stops.is_estimate_only`. */
  isEstimateOnly: boolean;
  provider: string;
}

/**
 * Provider boundary, same shape as {@link import('@dijigoo/core').SmsProvider}:
 * swapping OSRM for a paid traffic-aware provider later touches this file
 * and `createRoutingProvider` only.
 */
export interface RoutingProvider {
  readonly name: string;
  computeRoute(stops: RouteWaypoint[]): Promise<ComputedRoute>;
  /**
   * Full pairwise duration matrix (seconds), for reordering stops (Faz 2,
   * see `services/optimizer.ts`). Providers with no real engine behind them
   * return null — there's nothing to reorder against.
   */
  computeMatrix?(stops: RouteWaypoint[]): Promise<number[][] | null>;
}

/** ~30 km/h — a flat saha-ici teslimat guess, not a claim about real traffic. */
const AVERAGE_URBAN_SPEED_MPS = 8.3;

/**
 * Straight-line distance and a flat-speed guess. Used both as its own
 * provider (`ROUTING_PROVIDER=mock`, no external dependency at all) and as
 * the fallback path inside {@link OsrmRoutingProvider} when the self-hosted
 * engine cannot be reached, so a courier's route list degrades to an
 * estimate instead of failing outright.
 */
export function haversineRoute(stops: RouteWaypoint[], provider: string): ComputedRoute {
  const legs: RouteLeg[] = [];
  let totalDistance = 0;

  for (let i = 1; i < stops.length; i++) {
    const distance = haversineMeters(stops[i - 1]!, stops[i]!);
    totalDistance += distance;
    legs.push({
      taskId: stops[i]!.taskId,
      distanceMeters: Math.round(distance),
      durationSeconds: Math.round(distance / AVERAGE_URBAN_SPEED_MPS),
    });
  }

  return {
    mode: 'sequence_only',
    geometry: null,
    totalDistanceMeters: stops.length > 1 ? Math.round(totalDistance) : 0,
    totalDurationSeconds: stops.length > 1 ? Math.round(totalDistance / AVERAGE_URBAN_SPEED_MPS) : 0,
    legs,
    isEstimateOnly: true,
    provider,
  };
}

function haversineMeters(a: RouteWaypoint, b: RouteWaypoint): number {
  const earthRadiusMeters = 6_371_000;
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const sinLat = Math.sin(dLat / 2);
  const sinLng = Math.sin(dLng / 2);
  const h = sinLat * sinLat + Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * sinLng * sinLng;
  return 2 * earthRadiusMeters * Math.asin(Math.sqrt(h));
}

interface OsrmRouteResponse {
  code: string;
  routes?: Array<{
    distance: number;
    duration: number;
    geometry: string;
    legs: Array<{ distance: number; duration: number }>;
  }>;
}

interface OsrmTableResponse {
  code: string;
  durations?: Array<Array<number | null>>;
}

/**
 * Self-hosted OSRM (see `infra/osrm/`) — real road-network distance,
 * duration and driving-route geometry, no live traffic. This is Faz 1 per
 * `docs/00-hande-yanit.md`: "trafiksiz ETA + genis tolerans bandi";
 * traffic-aware routing is Faz 1.5 and needs a paid provider.
 */
export class OsrmRoutingProvider implements RoutingProvider {
  readonly name = 'osrm';
  private readonly cache = new Map<string, { at: number; value: ComputedRoute }>();

  constructor(
    private readonly baseUrl: string,
    private readonly log: (msg: string) => void,
    private readonly fallbackUrl?: string,
    private readonly cacheTtlMs = 10 * 60_000,
  ) {}

  async computeRoute(stops: RouteWaypoint[]): Promise<ComputedRoute> {
    if (stops.length < 2) {
      return {
        mode: 'distance_optimized',
        geometry: null,
        totalDistanceMeters: 0,
        totalDurationSeconds: 0,
        legs: [],
        isEstimateOnly: false,
        provider: this.name,
      };
    }

    const cacheKey = stops.map((s) => `${s.lng.toFixed(4)},${s.lat.toFixed(4)}`).join(';');
    const hit = this.cache.get(cacheKey);
    if (hit && Date.now() - hit.at < this.cacheTtlMs) return hit.value;

    for (const host of this.hosts()) {
      try {
        const computed = await this.fetchRoute(host, stops);
        this.cache.set(cacheKey, { at: Date.now(), value: computed });
        if (this.cache.size > 64) {
          const oldest = this.cache.keys().next().value;
          if (oldest) this.cache.delete(oldest);
        }
        return computed;
      } catch (error) {
        this.log(`OSRM ${host} yanit vermedi: ${error instanceof Error ? error.message : String(error)}`);
      }
    }

    return haversineRoute(stops, `${this.name}-fallback`);
  }

  private hosts(): string[] {
    const hosts = [this.baseUrl];
    if (this.fallbackUrl && this.fallbackUrl !== this.baseUrl) hosts.push(this.fallbackUrl);
    return hosts;
  }

  private async fetchRoute(baseUrl: string, stops: RouteWaypoint[]): Promise<ComputedRoute> {
    const coords = stops.map((s) => `${s.lng},${s.lat}`).join(';');
    const radiuses = ['1000', ...Array(Math.max(0, stops.length - 1)).fill('250')].join(';');
    const qs = [
      `overview=full&geometries=polyline&steps=false&continue_straight=true&radiuses=${radiuses}`,
      'overview=full&geometries=polyline&steps=false',
    ];
    let lastError: Error | undefined;
    for (const query of qs) {
      try {
        const res = await fetch(`${baseUrl}/route/v1/driving/${coords}?${query}`, {
          signal: AbortSignal.timeout(8000),
        });
        if (!res.ok) throw new Error(`osrm http ${res.status}`);
        const body = (await res.json()) as OsrmRouteResponse;
        const route = body.routes?.[0];
        if (body.code !== 'Ok' || !route) throw new Error(`osrm code ${body.code}`);

        const legs: RouteLeg[] = route.legs.map((leg, i) => ({
          taskId: stops[i + 1]!.taskId,
          distanceMeters: Math.round(leg.distance),
          durationSeconds: Math.round(leg.duration),
        }));

        return {
          mode: 'distance_optimized',
          geometry: route.geometry,
          totalDistanceMeters: Math.round(route.distance),
          totalDurationSeconds: Math.round(route.duration),
          legs,
          isEstimateOnly: false,
          provider: this.name,
        };
      } catch (error) {
        lastError = error instanceof Error ? error : new Error(String(error));
      }
    }
    throw lastError ?? new Error('osrm unreachable');
  }

  /**
   * Duration matrix from OSRM's `/table` service, used by
   * `optimizeStopOrder` to reorder stops before the final `/route` call
   * builds the geometry for the chosen order. Duration rather than distance:
   * what a courier's day actually costs is time, not metres.
   */
  async computeMatrix(stops: RouteWaypoint[]): Promise<number[][] | null> {
    if (stops.length < 2) return null;
    const coords = stops.map((s) => `${s.lng},${s.lat}`).join(';');
    for (const host of this.hosts()) {
      try {
        const url = `${host}/table/v1/driving/${coords}?annotations=duration`;
        const res = await fetch(url, { signal: AbortSignal.timeout(6000) });
        if (!res.ok) throw new Error(`osrm http ${res.status}`);

        const body = (await res.json()) as OsrmTableResponse;
        if (body.code !== 'Ok' || !body.durations) throw new Error(`osrm code ${body.code}`);

        // A pair OSRM could not connect on the graph comes back `null`;
        // treat it as unreachable rather than crashing the optimizer on it.
        return body.durations.map((row) => row.map((v) => v ?? Number.POSITIVE_INFINITY));
      } catch (error) {
        this.log(`OSRM matrisine ulasilamadi (${host}): ${error instanceof Error ? error.message : String(error)}`);
      }
    }
    return null;
  }
}

/** No external dependency at all — the default until OSRM (or a paid provider) is configured. */
export class MockRoutingProvider implements RoutingProvider {
  readonly name = 'mock';

  async computeRoute(stops: RouteWaypoint[]): Promise<ComputedRoute> {
    return haversineRoute(stops, this.name);
  }
}

export function createRoutingProvider(env: Env, log: (msg: string) => void): RoutingProvider {
  switch (env.ROUTING_PROVIDER) {
    case 'osrm':
      return new OsrmRoutingProvider(env.OSRM_URL, log, env.PUBLIC_OSRM_URL);
    case 'mock':
      return new MockRoutingProvider();
    default:
      // Real adapters land once a contract is signed; failing loudly is
      // better than silently falling back to mock in production.
      throw new Error(
        `Rota saglayicisi "${env.ROUTING_PROVIDER}" henuz uygulanmadi. Bkz. docs/00-hande-yanit.md`,
      );
  }
}
