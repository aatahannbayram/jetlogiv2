import {
  ErrorResponse,
  LocationBatchRequest,
  LocationBatchResponse,
  Shift,
  ShiftEndRequest,
  ShiftStartRequest,
} from '@dijigoo/contracts';
import { AppError, clampOccurredAt } from '@dijigoo/core';
import { locationPings, media, shifts } from '@dijigoo/db';
import { and, eq, isNull, sql } from 'drizzle-orm';
import type { FastifyInstance, FastifyRequest } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { z } from 'zod';

import type { AppContext } from '../context.js';
import type { AuthenticatedCourier } from '../plugins/authenticate.js';
import { emitEvent } from '../services/outbox.js';
import { PostgresIdempotencyStore } from '../services/idempotency-store.js';
import { runIdempotent } from '@dijigoo/core';

/** Fixes worse than this are noise; storing them would poison the trail. */
const MAX_ACCURACY_METERS = 200;
/** Anything older than this at ingest is dropped: the trail is already closed. */
const MAX_PING_AGE_HOURS = 24;

export async function shiftRoutes(app: FastifyInstance, { ctx }: { ctx: AppContext }) {
  const route = app.withTypeProvider<ZodTypeProvider>();

  route.get(
    '/v1/shifts/current',
    {
      schema: {
        tags: ['Shift'],
        response: { 200: Shift.nullable(), 401: ErrorResponse },
      },
    },
    async (request) => {
      const courier = await app.authenticate(request);
      const shift = await loadOpenShift(ctx, courier.courierId);
      return shift ? toShift(shift) : null;
    },
  );

  route.post(
    '/v1/shifts/start',
    {
      schema: {
        tags: ['Shift'],
        body: ShiftStartRequest,
        response: { 200: Shift, 400: ErrorResponse, 401: ErrorResponse, 409: ErrorResponse },
      },
    },
    async (request) => {
      const courier = await app.authenticate(request);
      const body = request.body;

      return withIdempotency(ctx, courier, request, body, async () => {
        const open = await loadOpenShift(ctx, courier.courierId);
        if (open) {
          // Not an error the courier can act on: the app crashed mid-shift and
          // the retry is harmless. Hand back the shift it already has.
          return { status: 200, value: toShift(open) };
        }

        if (body.startPhotoMediaId) {
          await assertMediaOwned(ctx, courier, body.startPhotoMediaId);
        }

        const occurredAt = clampOccurredAt(new Date(body.occurredAt), new Date());

        const shift = await ctx.db.transaction(async (tx) => {
          const [created] = await tx
            .insert(shifts)
            .values({
              courierId: courier.courierId,
              deviceId: courier.deviceId,
              status: 'active',
              startedAt: occurredAt,
              startLocation: { lat: body.location.lat, lng: body.location.lng },
              vehiclePlate: body.vehiclePlate ?? null,
              startPhotoMediaId: body.startPhotoMediaId ?? null,
              permissions: {
                locationAlways: body.permissions.locationAlways,
                notifications: body.permissions.notifications,
                camera: body.permissions.camera,
                batteryOptimizationExempt: body.permissions.batteryOptimizationExempt ?? null,
              },
            })
            .returning();

          await emitEvent(tx, {
            key: 'shift.started',
            tenantId: courier.tenantId,
            subjectType: 'shift',
            subjectId: created!.id,
            actorType: 'courier',
            actorId: courier.courierId,
            correlationId: body.clientEventId,
            occurredAt,
            data: {
              courierId: courier.courierId,
              vehiclePlate: created!.vehiclePlate,
              // Dispatch needs to know up front that this courier will produce
              // a sparse trail, rather than discovering it from the gaps.
              permissions: created!.permissions,
            },
          });

          return created!;
        });

        return { status: 201, value: toShift(shift) };
      });
    },
  );

  route.post(
    '/v1/shifts/end',
    {
      schema: {
        tags: ['Shift'],
        body: ShiftEndRequest,
        response: { 200: Shift, 400: ErrorResponse, 401: ErrorResponse, 404: ErrorResponse, 409: ErrorResponse },
      },
    },
    async (request) => {
      const courier = await app.authenticate(request);
      const body = request.body;

      return withIdempotency(ctx, courier, request, body, async () => {
        const open = await loadOpenShift(ctx, courier.courierId);
        if (!open) throw new AppError('NOT_FOUND', { message: 'Acik vardiya bulunamadi.', userVisible: true });

        const occurredAt = clampOccurredAt(new Date(body.occurredAt), new Date());
        if (occurredAt < open.startedAt) {
          throw new AppError('VALIDATION_FAILED', {
            details: [{ field: 'occurredAt', issue: 'before_shift_start' }],
          });
        }

        const shift = await ctx.db.transaction(async (tx) => {
          const [updated] = await tx
            .update(shifts)
            .set({
              status: 'closed',
              endedAt: occurredAt,
              endLocation: body.location ? { lat: body.location.lat, lng: body.location.lng } : null,
              note: body.note ?? null,
            })
            .where(and(eq(shifts.id, open.id), isNull(shifts.endedAt)))
            .returning();

          if (!updated) throw new AppError('CONFLICT');

          await emitEvent(tx, {
            key: 'shift.ended',
            tenantId: courier.tenantId,
            subjectType: 'shift',
            subjectId: updated.id,
            actorType: 'courier',
            actorId: courier.courierId,
            correlationId: body.clientEventId,
            occurredAt,
            data: {
              courierId: courier.courierId,
              durationSeconds: Math.round((occurredAt.getTime() - updated.startedAt.getTime()) / 1000),
              taskCount: updated.taskCount,
              completedCount: updated.completedCount,
            },
          });

          return updated;
        });

        return { status: 200, value: toShift(shift) };
      });
    },
  );

  route.post(
    '/v1/shifts/locations',
    {
      schema: {
        tags: ['Shift'],
        body: LocationBatchRequest,
        response: { 200: LocationBatchResponse, 401: ErrorResponse, 404: ErrorResponse },
      },
    },
    async (request) => {
      const courier = await app.authenticate(request);
      const body = request.body;

      const [shift] = await ctx.db
        .select({ id: shifts.id, endedAt: shifts.endedAt })
        .from(shifts)
        .where(and(eq(shifts.id, body.shiftId), eq(shifts.courierId, courier.courierId)))
        .limit(1);

      if (!shift) throw new AppError('NOT_FOUND');

      const now = Date.now();
      const cutoff = now - MAX_PING_AGE_HOURS * 3_600_000;

      // Filtering here rather than at the client means an old app version
      // cannot flood the table, and the courier still gets a clean 200 so the
      // buffer drains instead of retrying forever.
      const rows = body.points
        .filter((point) => {
          const capturedAt = new Date(point.capturedAt).getTime();
          return point.accuracy <= MAX_ACCURACY_METERS && capturedAt > cutoff && capturedAt < now + 60_000;
        })
        .map((point) => ({
          shiftId: shift.id,
          courierId: courier.courierId,
          position: { lat: point.lat, lng: point.lng },
          accuracy: point.accuracy,
          altitude: point.altitude ?? null,
          heading: point.heading ?? null,
          speed: point.speed ?? null,
          capturedAt: new Date(point.capturedAt),
          isMocked: point.isMocked ?? false,
          batteryLevel: body.batteryLevel ?? null,
          isCharging: body.isCharging ?? null,
          networkType: body.networkType ?? null,
        }));

      if (rows.length > 0) {
        await ctx.db.insert(locationPings).values(rows).onConflictDoNothing();
      }

      return {
        accepted: rows.length,
        rejected: body.points.length - rows.length,
        // Ask a nearly-flat handset to slow down; a dead phone reports nothing
        // at all, which is far worse than a coarse trail.
        nextIntervalSeconds: pingInterval(body.batteryLevel, body.isCharging, shift.endedAt !== null),
      };
    },
  );
}

function pingInterval(
  batteryLevel: number | null | undefined,
  isCharging: boolean | null | undefined,
  shiftClosed: boolean,
): number {
  if (shiftClosed) return 900;
  if (isCharging) return 30;
  if (typeof batteryLevel === 'number' && batteryLevel < 0.15) return 180;
  if (typeof batteryLevel === 'number' && batteryLevel < 0.3) return 90;
  return 45;
}

async function loadOpenShift(ctx: AppContext, courierId: string) {
  const [shift] = await ctx.db
    .select()
    .from(shifts)
    .where(and(eq(shifts.courierId, courierId), isNull(shifts.endedAt)))
    .limit(1);
  return shift ?? null;
}

async function assertMediaOwned(ctx: AppContext, courier: AuthenticatedCourier, mediaId: string) {
  const [row] = await ctx.db
    .select({ id: media.id })
    .from(media)
    .where(and(eq(media.id, mediaId), eq(media.courierId, courier.courierId)))
    .limit(1);
  if (!row) {
    throw new AppError('VALIDATION_FAILED', {
      details: [{ field: 'startPhotoMediaId', issue: 'unknown_media' }],
    });
  }
}

function toShift(shift: typeof shifts.$inferSelect): z.infer<typeof Shift> {
  return {
    id: shift.id,
    courierId: shift.courierId,
    status: shift.status,
    startedAt: shift.startedAt.toISOString(),
    endedAt: shift.endedAt?.toISOString() ?? null,
    startLocation: null,
    endLocation: null,
    vehiclePlate: shift.vehiclePlate,
    startPhoto: null,
    taskCount: shift.taskCount,
    completedCount: shift.completedCount,
  };
}

async function withIdempotency<T>(
  ctx: AppContext,
  courier: AuthenticatedCourier,
  request: FastifyRequest,
  body: unknown,
  handler: () => Promise<{ status: number; value: T }>,
): Promise<T> {
  const key = request.headers['idempotency-key'];
  if (typeof key !== 'string') {
    throw new AppError('VALIDATION_FAILED', { details: [{ field: 'idempotency-key', issue: 'required' }] });
  }
  const store = new PostgresIdempotencyStore(ctx.db, courier.courierId);
  const result = await runIdempotent(store, key, body, handler);
  return result.value;
}

/** Kept for the worker: total metres walked, computed from the ping trail. */
export const SHIFT_DISTANCE_SQL = sql`
  select sum(st_distance(prev::geography, position::geography))::int as meters
  from (
    select position, lag(position) over (order by captured_at) as prev
    from location_pings where shift_id = $1
  ) t where prev is not null
`;
