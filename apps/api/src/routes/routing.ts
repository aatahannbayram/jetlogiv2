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
        querystring: z.object({
          lat: z.coerce.number().min(-90).max(90).optional(),
          lng: z.coerce.number().min(-180).max(180).optional(),
        }),
        response: { 200: Route, 204: z.null(), 401: ErrorResponse },
      },
    },
    async (request, reply) => {
      const courier = await app.authenticate(request);
      const originLat = request.query.lat;
      const originLng = request.query.lng;

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

      // Courier GPS is the fixed start when the client sends it — otherwise
      // the first *task* is pinned (legacy). Reordering a day from the
      // first parcel instead of the rider is what produced the town-wide
      // scribble on the map.
      const hasOrigin = originLat != null && originLng != null;
      const engineInput = [
        ...(hasOrigin ? [{ id: '__origin', position: { lat: originLat, lng: originLng } }] : []),
        ...dispatchOrder,
      ];

      let stops = engineInput;
      if (engineInput.length > 2 && ctx.routing.computeMatrix) {
        const matrix = await ctx.routing.computeMatrix(
          engineInput.map((t) => ({ taskId: t.id, lat: t.position.lat, lng: t.position.lng })),
        );
        if (matrix) {
          const order = optimizeStopOrder(matrix);
          stops = order.map((i) => engineInput[i]!);
        }
      }

      const computed = await ctx.routing.computeRoute(
        stops.map((t) => ({ taskId: t.id, lat: t.position.lat, lng: t.position.lng })),
      );

      const now = new Date();
      let eta = now;
      const taskStops = hasOrigin ? stops.filter((s) => s.id !== '__origin') : stops;
      const stopRows = taskStops.map((stop, i) => {
        // With an origin, legs[0] is rider→first task (useful on the sheet).
        // Without, sequence 0 has no incoming leg — same as before.
        const incoming = hasOrigin ? computed.legs[i] : i === 0 ? null : computed.legs[i - 1];
        if (incoming) eta = new Date(eta.getTime() + (incoming.durationSeconds ?? 0) * 1000);
        return {
          taskId: stop.id,
          sequence: i,
          etaAt: eta,
          distanceMeters: incoming?.distanceMeters ?? null,
          durationSeconds: incoming?.durationSeconds ?? null,
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
