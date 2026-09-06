import { DelayDecisionRequest, DelayDecisionResponse, ErrorResponse, Uuid } from '@dijigoo/contracts';
import { AppError } from '@dijigoo/core';
import { tasks } from '@dijigoo/db';
import { eq } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { z } from 'zod';

import type { AppContext } from '../context.js';
import { enqueueCourierNotification } from '../services/notify.js';
import { extendSlaInstance } from '../services/sla.js';
import { cancelTask } from '../services/task-cancellation.js';

const problem = {
  400: ErrorResponse,
  401: ErrorResponse,
  404: ErrorResponse,
  409: ErrorResponse,
};

/**
 * Faz 5: the API side of task delay/cancel. Not called by the mobile app —
 * `apps/worker` flags a task `sla.at_risk`, the operations panel's backend
 * (another team's codebase) decides what happens, and calls this. See
 * plugins/service-auth.ts for why this isn't the courier `app.authenticate`.
 */
export async function delayDecisionRoutes(app: FastifyInstance, { ctx }: { ctx: AppContext }) {
  const route = app.withTypeProvider<ZodTypeProvider>();

  route.post(
    '/v1/tasks/:taskId/delay-decision',
    {
      schema: {
        tags: ['Task'],
        params: z.object({ taskId: Uuid }),
        body: DelayDecisionRequest,
        response: { 200: DelayDecisionResponse, ...problem },
      },
    },
    async (request) => {
      await app.authenticateService(request);
      const body = request.body;

      if (body.decision === 'extend' && !body.newSlaTargetAt) {
        throw new AppError('VALIDATION_FAILED', {
          details: [{ field: 'newSlaTargetAt', issue: 'required_for_extend' }],
        });
      }

      const [task] = await ctx.db.select().from(tasks).where(eq(tasks.id, request.params.taskId)).limit(1);
      if (!task) throw new AppError('NOT_FOUND');

      const now = new Date();
      const eventCtx = { tenantId: task.tenantId, correlationId: request.id };
      const actor = { actorType: 'operator' as const, actorId: body.operatorId ?? null };

      await ctx.db.transaction(async (tx) => {
        if (body.decision === 'cancel') {
          await cancelTask(tx, eventCtx, task, actor, body.reason ?? null, now);
        } else {
          await extendSlaInstance(tx, eventCtx, {
            subjectType: 'task',
            subjectId: task.id,
            // Validated non-null above; body.decision === 'extend' here.
            newTargetAt: new Date(body.newSlaTargetAt as string),
            extendedAt: now,
          });
        }
      });

      if (body.decision === 'cancel' && task.courierId) {
        await enqueueCourierNotification(ctx.db, ctx.env, {
          courierId: task.courierId,
          kind: 'TASK_CANCELLED',
          title: 'Durak iptal',
          body: `${task.reference} · ${body.reason ?? 'operasyon iptal etti.'}`,
          subjectId: task.id,
          collapseKey: `task-cancel:${task.id}`,
          route: `task:${task.id}`,
        });
      }

      return {
        taskId: task.id,
        decision: body.decision,
        appliedAt: now.toISOString(),
      };
    },
  );
}
