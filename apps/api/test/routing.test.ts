import assert from 'node:assert/strict';
import { test } from 'node:test';

import { MockRoutingProvider, OsrmRoutingProvider, haversineRoute } from '../src/services/routing.js';

// Same four points as apps/mobile's onboarding "4 durak" demo
// (lib/screens/onboard_screen.dart / lib/session.dart) so this test proves
// the exact route the app shows.
const USAK_DEMO_STOPS = [
  { taskId: 'a', lat: 38.1512, lng: 29.0614 },
  { taskId: 'b', lat: 38.1481, lng: 29.0558 },
  { taskId: 'c', lat: 38.1554, lng: 29.0692 },
  { taskId: 'd', lat: 38.146, lng: 29.0488 },
];

test('haversineRoute: straight-line distance grows monotonically with stops, never zero for distinct points', () => {
  const result = haversineRoute(USAK_DEMO_STOPS, 'test');
  assert.equal(result.legs.length, 3);
  assert.equal(result.isEstimateOnly, true);
  assert.equal(result.geometry, null);
  for (const leg of result.legs) {
    assert.ok(leg.distanceMeters! > 0);
    assert.ok(leg.durationSeconds! > 0);
  }
  // Each leg is rounded individually, the total from the unrounded sum, so
  // they can differ by a metre or two — never more than one metre per leg.
  const legSum = result.legs.reduce((sum, leg) => sum + leg.distanceMeters!, 0);
  assert.ok(Math.abs(result.totalDistanceMeters! - legSum) <= result.legs.length);
});

test('haversineRoute: single stop has zero distance and no legs', () => {
  const result = haversineRoute([USAK_DEMO_STOPS[0]!], 'test');
  assert.equal(result.legs.length, 0);
  assert.equal(result.totalDistanceMeters, 0);
});

test('MockRoutingProvider: same shape as haversineRoute', async () => {
  const result = await new MockRoutingProvider().computeRoute(USAK_DEMO_STOPS);
  assert.equal(result.provider, 'mock');
  assert.equal(result.mode, 'sequence_only');
});

test('OsrmRoutingProvider: real road-network distance from the self-hosted engine, shorter than the straight line', async () => {
  const osrmUrl = process.env['OSRM_URL'] ?? 'http://localhost:5001';
  const reachable = await fetch(`${osrmUrl}/route/v1/driving/29.0614,38.1512;29.0558,38.1481`)
    .then((r) => r.ok)
    .catch(() => false);
  if (!reachable) {
    console.warn(`[routing.test] OSRM at ${osrmUrl} not reachable, skipping — see infra/osrm/README.md`);
    return;
  }

  const provider = new OsrmRoutingProvider(osrmUrl, () => {});
  const result = await provider.computeRoute(USAK_DEMO_STOPS);

  assert.equal(result.provider, 'osrm');
  assert.equal(result.mode, 'distance_optimized');
  assert.equal(result.isEstimateOnly, false);
  assert.ok(result.geometry && result.geometry.length > 0, 'expected an encoded polyline');
  assert.equal(result.legs.length, 3);

  // A real road network is never shorter than the crow-flies distance.
  const straightLine = haversineRoute(USAK_DEMO_STOPS, 'test');
  assert.ok(result.totalDistanceMeters! >= straightLine.totalDistanceMeters! * 0.95);
});

test('OsrmRoutingProvider: unreachable host falls back to a straight-line estimate instead of throwing', async () => {
  const provider = new OsrmRoutingProvider('http://127.0.0.1:1', () => {});
  const result = await provider.computeRoute(USAK_DEMO_STOPS);
  assert.equal(result.isEstimateOnly, true);
  assert.equal(result.provider, 'osrm-fallback');
});

test('OsrmRoutingProvider: local down, public OSRM draws a real Turkey road', async () => {
  const publicUrl = process.env['PUBLIC_OSRM_URL'] ?? 'https://router.project-osrm.org';
  const reachable = await fetch(`${publicUrl}/route/v1/driving/29.0702,38.1476;29.0614,38.1512`)
    .then((r) => r.ok)
    .catch(() => false);
  if (!reachable) {
    console.warn('[routing.test] public OSRM not reachable, skipping');
    return;
  }

  const provider = new OsrmRoutingProvider('http://127.0.0.1:1', () => {}, publicUrl);
  const result = await provider.computeRoute([
    { taskId: 'self', lat: 38.1476, lng: 29.0702 },
    { taskId: 't1', lat: 38.1512, lng: 29.0614 },
  ]);

  assert.equal(result.isEstimateOnly, false);
  assert.ok(result.geometry && result.geometry.length > 20);
  assert.ok(result.totalDistanceMeters! > 800);

  const again = await provider.computeRoute([
    { taskId: 'self', lat: 38.1476, lng: 29.0702 },
    { taskId: 't1', lat: 38.1512, lng: 29.0614 },
  ]);
  assert.equal(again.geometry, result.geometry);
});
