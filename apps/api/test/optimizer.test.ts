import assert from 'node:assert/strict';
import { test } from 'node:test';

import { optimizeStopOrder } from '../src/services/optimizer.js';
import { OsrmRoutingProvider } from '../src/services/routing.js';

test('optimizeStopOrder: fixes the start, visits every stop exactly once', () => {
  // 5 points on a line at x = 0, 10, 20, 30, 40, given in a shuffled order.
  // Optimal from a fixed start at index 0 (x=20) is a straight walk out.
  const matrix = [
    [0, 20, 10, 30, 40],
    [20, 0, 30, 10, 60],
    [10, 30, 0, 40, 30],
    [30, 10, 40, 0, 70],
    [40, 60, 30, 70, 0],
  ];
  const order = optimizeStopOrder(matrix);

  assert.equal(order[0], 0, 'start must stay fixed');
  assert.deepEqual([...order].sort(), [0, 1, 2, 3, 4], 'every index visited exactly once');

  const length = (o: number[]) => {
    let total = 0;
    for (let i = 0; i < o.length - 1; i++) total += matrix[o[i]!]![o[i + 1]!]!;
    return total;
  };
  assert.ok(length(order) <= length([0, 1, 2, 3, 4]), 'must not be worse than the naive given order');
});

test('optimizeStopOrder: 2 or fewer stops pass through unchanged', () => {
  assert.deepEqual(optimizeStopOrder([[0]]), [0]);
  assert.deepEqual(optimizeStopOrder([[0, 5], [5, 0]]), [0, 1]);
});

test('optimizeStopOrder: improves a deliberately bad hand-ordered tour', () => {
  // Zig-zag input order across 6 roughly-collinear points — a textbook case
  // where 2-opt should uncross the path.
  const coords = [0, 50, 10, 40, 20, 30];
  const matrix = coords.map((a) => coords.map((b) => Math.abs(a - b)));
  const naive = [0, 1, 2, 3, 4, 5];
  const optimized = optimizeStopOrder(matrix);

  const length = (o: number[]) => {
    let total = 0;
    for (let i = 0; i < o.length - 1; i++) total += matrix[o[i]!]![o[i + 1]!]!;
    return total;
  };
  assert.ok(length(optimized) < length(naive), `expected improvement: naive=${length(naive)} optimized=${length(optimized)}`);
});

// Same points as apps/mobile's onboarding "4 durak" demo, given in dispatch
// order (a-b-c-d), which is not the shortest way to visit them.
const USAK_DEMO_STOPS = [
  { taskId: 'a', lat: 38.1512, lng: 29.0614 },
  { taskId: 'b', lat: 38.1481, lng: 29.0558 },
  { taskId: 'c', lat: 38.1554, lng: 29.0692 },
  { taskId: 'd', lat: 38.146, lng: 29.0488 },
];

test('OsrmRoutingProvider.computeMatrix + optimizeStopOrder: real road network, optimized order is not slower than dispatch order', async () => {
  const osrmUrl = process.env['OSRM_URL'] ?? 'http://localhost:5001';
  const reachable = await fetch(`${osrmUrl}/route/v1/driving/29.0614,38.1512;29.0558,38.1481`)
    .then((r) => r.ok)
    .catch(() => false);
  if (!reachable) {
    console.warn(`[optimizer.test] OSRM at ${osrmUrl} not reachable, skipping — see infra/osrm/README.md`);
    return;
  }

  const provider = new OsrmRoutingProvider(osrmUrl, () => {});
  const matrix = await provider.computeMatrix(USAK_DEMO_STOPS);
  assert.ok(matrix, 'expected a real duration matrix');

  const dispatchOrderRoute = await provider.computeRoute(USAK_DEMO_STOPS);
  const optimized = optimizeStopOrder(matrix!);
  const optimizedStops = optimized.map((i) => USAK_DEMO_STOPS[i]!);
  const optimizedRoute = await provider.computeRoute(optimizedStops);

  assert.equal(optimizedStops[0]!.taskId, 'a', 'first stop stays fixed');
  assert.ok(
    optimizedRoute.totalDurationSeconds! <= dispatchOrderRoute.totalDurationSeconds! + 1,
    `optimized (${optimizedRoute.totalDurationSeconds}s) should not be slower than dispatch order (${dispatchOrderRoute.totalDurationSeconds}s)`,
  );
});
