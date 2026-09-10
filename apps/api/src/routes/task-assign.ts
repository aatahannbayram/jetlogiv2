import { ErrorResponse, TaskAssignRequest, TaskAssignResponse, Uuid } from '@dijigoo/contracts';
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { z } from 'zod';

import type { AppContext } from '../context.js';
import { serviceRouteRateLimit } from '../rate-limits.js';
import { enqueueCourierNotification } from '../services/notify.js';
import { assignTask } from '../services/task-assign.js';

const problem = {
  400: ErrorResponse,
  401: ErrorResponse,
  404: ErrorResponse,
  409: ErrorResponse,
};

export async function taskAssignRoutes(app: FastifyInstance, { ctx }: { ctx: AppContext }) {
  const route = app.withTypeProvider<ZodTypeProvider>();

  route.post(
    '/v1/tasks/:taskId/assign',
    {
      config: { rateLimit: serviceRouteRateLimit },
      schema: {
        tags: ['Task'],
        summary: 'Gorevi kuryeye ata / baska kuryeye cek',
        params: z.object({ taskId: Uuid }),
        body: TaskAssignRequest,
        response: { 200: TaskAssignResponse, ...problem },
      },
    },
    async (request) => {
      await app.authenticateService(request);
      const now = new Date();
      const body = request.body;

      const result = await ctx.db.transaction((tx) =>
        assignTask(tx, { correlationId: request.id }, {
          taskId: request.params.taskId,
          courierId: body.courierId,
          operatorId: body.operatorId ?? null,
          reason: body.reason ?? null,
          occurredAt: now,
        }),
      );

      if (!result.alreadyAssigned) {
        await enqueueCourierNotification(ctx.db, ctx.env, {
          courierId: result.courierId,
          kind: 'TASK_ASSIGNED',
          title: 'Yeni durak atandı',
          body: `${result.reference} · dağıtım listesine eklendi.`,
          subjectId: result.taskId,
          collapseKey: `task-assign:${result.taskId}`,
          route: `task:${result.taskId}`,
        });
        if (result.previousCourierId) {
          await enqueueCourierNotification(ctx.db, ctx.env, {
            courierId: result.previousCourierId,
            kind: 'TASK_PULLED',
            title: 'Durak çekildi',
            body: `${result.reference} · başka kuryeye verildi.`,
            subjectId: result.taskId,
            collapseKey: `task-pull:${result.taskId}`,
            route: `task:${result.taskId}`,
          });
        }
      }

      return {
        taskId: result.taskId,
        courierId: result.courierId,
        previousCourierId: result.previousCourierId,
        alreadyAssigned: result.alreadyAssigned,
        appliedAt: now.toISOString(),
      };
    },
  );
}
