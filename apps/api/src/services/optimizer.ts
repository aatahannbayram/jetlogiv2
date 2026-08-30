/**
 * Single-vehicle stop ordering: nearest-neighbour construction + 2-opt local
 * search on a real distance/duration matrix. This is Faz 2 — deliberately
 * not a full VRP solver (OR-Tools/VROOM), because a courier's daily stop
 * count (single digits to a few dozen) does not need one; nearest-neighbour
 * + 2-opt is the standard, well-understood approach for exactly this size of
 * single-vehicle TSP and runs in-process with no extra infrastructure.
 *
 * VROOM was tried first (it is the natural OSRM companion for this) but its
 * published Docker image would not execute on this arm64/Colima setup
 * (binary format mismatch) — noted here so a future attempt does not repeat
 * the same dead end without knowing it was already tried.
 */

/** Index 0 is fixed as the start (the courier's current or first stop); only indices 1..n-1 are reordered. */
export function optimizeStopOrder(matrix: number[][]): number[] {
  const n = matrix.length;
  if (n <= 2) return [...Array(n).keys()];
  return twoOpt(nearestNeighborOrder(matrix), matrix);
}

function nearestNeighborOrder(matrix: number[][]): number[] {
  const n = matrix.length;
  const visited = new Array(n).fill(false) as boolean[];
  const order = [0];
  visited[0] = true;
  let current = 0;

  for (let step = 1; step < n; step++) {
    let best = -1;
    let bestCost = Infinity;
    for (let j = 0; j < n; j++) {
      if (!visited[j] && matrix[current]![j]! < bestCost) {
        bestCost = matrix[current]![j]!;
        best = j;
      }
    }
    order.push(best);
    visited[best] = true;
    current = best;
  }
  return order;
}

/** Classic 2-opt: repeatedly reverses a segment when doing so shortens the tour, until no reversal helps. */
function twoOpt(initial: number[], matrix: number[][]): number[] {
  let tour = initial;
  let tourLength = pathLength(tour, matrix);
  let improved = true;

  while (improved) {
    improved = false;
    for (let i = 1; i < tour.length - 1; i++) {
      for (let k = i + 1; k < tour.length; k++) {
        const candidate = [...tour.slice(0, i), ...tour.slice(i, k + 1).reverse(), ...tour.slice(k + 1)];
        const candidateLength = pathLength(candidate, matrix);
        if (candidateLength + 1e-6 < tourLength) {
          tour = candidate;
          tourLength = candidateLength;
          improved = true;
        }
      }
    }
  }
  return tour;
}

function pathLength(order: number[], matrix: number[][]): number {
  let total = 0;
  for (let i = 0; i < order.length - 1; i++) total += matrix[order[i]!]![order[i + 1]!]!;
  return total;
}
