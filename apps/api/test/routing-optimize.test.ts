import assert from 'node:assert/strict';
import { test } from 'node:test';

import { buildOptimizedRoute } from '../src/services/routing-optimize.js';
import { MockRoutingProvider } from '../src/services/routing.js';
import type { ComputedRoute, RouteWaypoint, RoutingProvider } from '../src/services/routing.js';

// Same four points as apps/mobile's onboarding "4 durak" demo (see
// test/routing.test.ts) reused here for continuity, plus a distinct id
// scheme (`shp-*`) to make clear these aren't our `tasks` rows — this is
// the shape jetlogi-panel's shipment ids would actually take.
const PANEL_STOPS = [
  { id: 'shp-a', lat: 38.1512, lng: 29.0614 },
  { id: 'shp-b', lat: 38.1481, lng: 29.0558 },
  { id: 'shp-c', lat: 38.1554, lng: 29.0692 },
  { id: 'shp-d', lat: 38.146, lng: 29.0488 },
];

/** Deterministic fake so the reordering behaviour is asserted, not just "some order". */
class ReversingRoutingProvider implements RoutingProvider {
  readonly name = 'reversing-fake';

  async computeRoute(stops: RouteWaypoint[]): Promise<ComputedRoute> {
    return {
      mode: 'distance_optimized',
      geometry: 'fake-geometry',
      totalDistanceMeters: 1000,
      totalDurationSeconds: 100 * (stops.length - 1),
      legs: stops.slice(1).map((s) => ({ taskId: s.taskId, distanceMeters: 250, durationSeconds: 100 })),
      isEstimateOnly: false,
      provider: this.name,
    };
  }

  async computeMatrix(stops: RouteWaypoint[]): Promise<number[][]> {
    // Reward visiting stops in reverse order (after the fixed start) by
    // making "distance to the last stop" artificially cheap.
    const n = stops.length;
    return Array.from({ length: n }, (_, i) => Array.from({ length: n }, (_, j) => (i === j ? 0 : n - Math.abs(i - j))));
  }
}

test('buildOptimizedRoute: MockRoutingProvider — sequence_only, ids echoed back unchanged', async () => {
  const result = await buildOptimizedRoute(new MockRoutingProvider(), PANEL_STOPS);
  assert.equal(result.mode, 'sequence_only');
  assert.equal(result.provider, 'mock');
  assert.equal(result.stops.length, 4);
  assert.deepEqual(
    result.stops.map((s) => s.id),
    ['shp-a', 'shp-b', 'shp-c', 'shp-d'],
  );
  assert.equal(result.stops[0]!.sequence, 0);
  assert.equal(result.stops[0]!.distanceMeters, null, 'first stop has no incoming leg');
  assert.ok(result.stops[1]!.distanceMeters! > 0);
});

test('buildOptimizedRoute: stop 0 stays fixed, 1..n-1 reordered when a real matrix is available', async () => {
  const result = await buildOptimizedRoute(new ReversingRoutingProvider(), PANEL_STOPS);
  assert.equal(result.stops[0]!.id, 'shp-a', 'fixed start never moves');
  // Full 4-stop input plus the optimizer's own bias — assert the set, not a
  // brittle exact permutation, but confirm it actually changed from input order.
  const order = result.stops.map((s) => s.id);
  assert.deepEqual([...order].sort(), ['shp-a', 'shp-b', 'shp-c', 'shp-d']);
  assert.notDeepEqual(order, ['shp-a', 'shp-b', 'shp-c', 'shp-d'], 'expected the fake matrix to change the visiting order');
});

test('buildOptimizedRoute: 2 stops or fewer skip the matrix/optimizer entirely', async () => {
  let matrixCalled = false;
  const provider: RoutingProvider = {
    name: 'spy',
    async computeRoute(stops) {
      return { mode: 'distance_optimized', geometry: null, totalDistanceMeters: 0, totalDurationSeconds: 0, legs: [], isEstimateOnly: false, provider: 'spy' };
    },
    async computeMatrix() {
      matrixCalled = true;
      return null;
    },
  };
  await buildOptimizedRoute(provider, PANEL_STOPS.slice(0, 2));
  assert.equal(matrixCalled, false);
});

test('buildOptimizedRoute: etaAt accumulates from startAt using each leg duration', async () => {
  const startAt = new Date('2026-09-06T09:00:00.000Z');
  const result = await buildOptimizedRoute(new MockRoutingProvider(), PANEL_STOPS, startAt);
  assert.equal(result.stops[0]!.etaAt, startAt.toISOString(), 'first stop eta is the start time itself');
  const second = new Date(result.stops[1]!.etaAt);
  assert.ok(second.getTime() > startAt.getTime(), 'later stops accumulate leg duration');
});

test('buildOptimizedRoute: single stop — no legs, echoes the one id', async () => {
  const result = await buildOptimizedRoute(new MockRoutingProvider(), [PANEL_STOPS[0]!]);
  assert.equal(result.stops.length, 1);
  assert.equal(result.stops[0]!.id, 'shp-a');
  assert.equal(result.stops[0]!.distanceMeters, null);
});
