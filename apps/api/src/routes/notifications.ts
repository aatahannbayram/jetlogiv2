import {
  CourierInboxItem,
  ErrorResponse,
  NotificationDispatchRequest,
  NotificationListResponse,
  NotificationReadRequest,
} from '@dijigoo/contracts';
import { notifications } from '@dijigoo/db';
import { and, desc, eq, inArray, isNull } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { z } from 'zod';

import type { AppContext } from '../context.js';
import { enqueueCourierNotification, toInboxItem } from '../services/notify.js';

const problem = {
  400: ErrorResponse,
  401: ErrorResponse,
  404: ErrorResponse,
};

export async function notificationRoutes(app: FastifyInstance, { ctx }: { ctx: AppContext }) {
  const route = app.withTypeProvider<ZodTypeProvider>();

  route.get(
    '/v1/notifications',
    {
      schema: {
        tags: ['Notifications'],
        response: { 200: NotificationListResponse, ...problem },
      },
    },
    async (request) => {
      const courier = await app.authenticate(request);
      const rows = await ctx.db
        .select()
        .from(notifications)
        .where(eq(notifications.courierId, courier.courierId))
        .orderBy(desc(notifications.createdAt))
        .limit(40);
      return {
        items: rows.map((row) =>
          toInboxItem({
            id: row.id,
            kind: row.kind,
            title: row.title ?? '',
            body: row.body ?? '',
            route: row.route ?? null,
            subjectId: row.subjectId ?? null,
            collapseKey: row.collapseKey ?? null,
            readAt: row.readAt ?? null,
            createdAt: row.createdAt,
          }),
        ),
        nextCursor: null,
      };
    },
  );

  route.post(
    '/v1/notifications/read',
    {
      schema: {
        tags: ['Notifications'],
        body: NotificationReadRequest,
        response: { 204: z.null(), ...problem },
      },
    },
    async (request, reply) => {
      const courier = await app.authenticate(request);
      const now = new Date();
      if (request.body.all) {
        await ctx.db
          .update(notifications)
          .set({ readAt: now })
          .where(and(eq(notifications.courierId, courier.courierId), isNull(notifications.readAt)));
      } else if (request.body.ids?.length) {
        await ctx.db
          .update(notifications)
          .set({ readAt: now })
          .where(
            and(
              eq(notifications.courierId, courier.courierId),
              inArray(notifications.id, request.body.ids),
              isNull(notifications.readAt),
            ),
          );
      }
      return reply.status(204).send();
    },
  );

  route.post(
    '/v1/notifications/dispatch',
    {
      schema: {
        tags: ['Notifications'],
        body: NotificationDispatchRequest,
        response: { 201: CourierInboxItem, ...problem },
      },
    },
    async (request, reply) => {
      await app.authenticateService(request);
      const item = await enqueueCourierNotification(ctx.db, ctx.env, request.body);
      return reply.status(201).send(item);
    },
  );
}
