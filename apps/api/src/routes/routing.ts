import { ErrorResponse, Route } from '@dijigoo/contracts';
import { routeStops, routes as routesTable, shifts, tasks } from '@dijigoo/db';
import { and, asc, eq, isNull, notInArray } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { z } from 'zod';

import type { AppContext } from '../context.js';
import { optimizeStopOrder } from '../services/optimizer.js';

/** Mirrors `tasks_open_courier_idx` in packages/db/src/schema/task.ts. */
const CLOSED_TASK_STATUSES: Array<'COMPLETED' | 'FAILED' | 'CANCELLED'> = ['COMPLETED', 'FAILED', 'CANCELLED'];

export async function routingRoutes(app: FastifyInstance, { ctx }: { ctx: AppContext }) {
  const route = app.withTypeProvider<ZodTypeProvider>();

  /**
   * Today's route order for the courier's currently open shift. Recomputes
   * and supersedes the active row on every call rather than serving a stale
   * cache — the self-hosted OSRM call is local and cheap (see infra/osrm/),
   * so there is no reason to skip a fresh distance/duration read.
   */
  route.get(
    '/v1/routes/current',
    {
      schema: {
        tags: ['Shift'],
        summary: "Gunun rota sirasi",
        response: { 200: Route, 204: z.null(), 401: ErrorResponse },
      },
    },
    async (request, reply) => {
      const courier = await app.authenticate(request);

      const [openShift] = await ctx.db
        .select({ id: shifts.id })
        .from(shifts)
        .where(and(eq(shifts.courierId, courier.courierId), isNull(shifts.endedAt)))
        .limit(1);
      if (!openShift) return reply.status(204).send(null);

      const openTasks = await ctx.db
        .select({ id: tasks.id, sequence: tasks.sequence, position: tasks.position })
        .from(tasks)
        .where(and(eq(tasks.courierId, courier.courierId), notInArray(tasks.status, CLOSED_TASK_STATUSES)))
        .orderBy(asc(tasks.sequence), asc(tasks.createdAt));

      // A task without a geocoded position cannot be routed; it simply drops
      // out of the sequence rather than failing the whole computation.
      const dispatchOrder = openTasks.filter(
        (t): t is typeof t & { position: NonNullable<(typeof t)['position']> } => t.position != null,
      );
      if (dispatchOrder.length === 0) return reply.status(204).send(null);

      // Faz 2: reorder the dispatch list to minimise total travel time,
      // keeping stop 0 fixed (the courier's next stop is not renegotiable
      // mid-route). Providers without a real engine (`computeMatrix` unset)
      // skip straight to the dispatch order as-is.
      let stops = dispatchOrder;
      if (dispatchOrder.length > 2 && ctx.routing.computeMatrix) {
        const matrix = await ctx.routing.computeMatrix(
          dispatchOrder.map((t) => ({ taskId: t.id, lat: t.position.lat, lng: t.position.lng })),
        );
        if (matrix) {
          const order = optimizeStopOrder(matrix);
          stops = order.map((i) => dispatchOrder[i]!);
        }
      }

      const computed = await ctx.routing.computeRoute(
        stops.map((t) => ({ taskId: t.id, lat: t.position.lat, lng: t.position.lng })),
      );

      const now = new Date();
      let eta = now;
      const stopRows = stops.map((stop, i) => {
        const leg = i === 0 ? null : computed.legs[i - 1];
        if (leg) eta = new Date(eta.getTime() + (leg.durationSeconds ?? 0) * 1000);
        return {
          taskId: stop.id,
          sequence: i,
          etaAt: eta,
          distanceMeters: leg?.distanceMeters ?? null,
          durationSeconds: leg?.durationSeconds ?? null,
          isEstimateOnly: computed.isEstimateOnly,
        };
      });

      const persisted = await ctx.db.transaction(async (tx) => {
        // One active route per shift (`routes_active_shift_uq`); supersede
        // rather than update so the previous computation stays auditable.
        await tx
          .update(routesTable)
          .set({ supersededAt: now })
          .where(and(eq(routesTable.shiftId, openShift.id), isNull(routesTable.supersededAt)));

        const [created] = await tx
          .insert(routesTable)
          .values({
            shiftId: openShift.id,
            courierId: courier.courierId,
            mode: computed.mode,
            geometry: computed.geometry,
            totalDistanceMeters: computed.totalDistanceMeters,
            totalDurationSeconds: computed.totalDurationSeconds,
            provider: computed.provider,
            computedAt: now,
          })
          .returning();

        await tx.insert(routeStops).values(stopRows.map((row) => ({ ...row, routeId: created!.id })));

        return created!;
      });

      return {
        id: persisted.id,
        shiftId: persisted.shiftId,
        mode: persisted.mode,
        geometry: persisted.geometry,
        computedAt: persisted.computedAt.toISOString(),
        stops: stopRows.map((row) => ({
          taskId: row.taskId,
          sequence: row.sequence,
          etaAt: row.etaAt.toISOString(),
          distanceMeters: row.distanceMeters,
          durationSeconds: row.durationSeconds,
        })),
      };
    },
  );
}
