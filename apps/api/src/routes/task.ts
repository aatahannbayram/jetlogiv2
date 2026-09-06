import {
  ErrorResponse,
  MaskedCallRequest,
  MaskedCallResponse,
  StepSubmitRequest,
  TaskDetail,
  TaskOtpSendRequest,
  TaskOtpSendResponse,
  TaskOtpVerifyRequest,
  TaskOtpVerifyResponse,
  TaskFinalizeRequest,
  TaskListQuery,
  TaskListResponse,
  TaskMutationResponse,
  TaskTransitionRequest,
  Uuid,
} from '@dijigoo/contracts';
import {
  AppError,
  assertRowVersion,
  assertTransition,
  checkGeofence,
  clampOccurredAt,
  emitEvent,
  fieldKeyFromEnv,
  missingRequiredSteps,
  runIdempotent,
  visibleSteps,
} from '@dijigoo/core';
import type { ConditionContext } from '@dijigoo/core';
import { maskedCallSessions, media, taskItems, taskSteps, taskTransitions, tasks, workflows } from '@dijigoo/db';
import { and, asc, eq, gte, inArray, lt, or, sql } from 'drizzle-orm';
import type { FastifyInstance, FastifyRequest } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { z } from 'zod';

import type { AppContext } from '../context.js';
import type { AuthenticatedCourier } from '../plugins/authenticate.js';
import {
  documentStatusForStepType,
  ensureDocument,
  recordAutomaticQualityReview,
  transitionDocument,
} from '../services/document-status.js';
import { PostgresIdempotencyStore } from '../services/idempotency-store.js';
import { plaintextPhone } from '../services/masked-call.js';
import { signOtpProof, verifyOtpProof } from '../services/otp-token.js';
import { openReturnsForFailedTask } from '../services/return-status.js';
import { resolveSlaInstance, startSlaInstance } from '../services/sla.js';
import { ensureWorkOrder, recordDeliveryResult, transitionWorkOrder } from '../services/work-order.js';

const problem = {
  400: ErrorResponse,
  401: ErrorResponse,
  403: ErrorResponse,
  404: ErrorResponse,
  409: ErrorResponse,
  422: ErrorResponse,
  503: ErrorResponse,
};

export async function taskRoutes(app: FastifyInstance, { ctx }: { ctx: AppContext }) {
  const route = app.withTypeProvider<ZodTypeProvider>();

  route.get(
    '/v1/tasks',
    { schema: { tags: ['Task'], querystring: TaskListQuery, response: { 200: TaskListResponse, ...problem } } },
    async (request) => {
      const courier = await app.authenticate(request);
      const { cursor, limit, status, updatedSince } = request.query;

      const conditions = [eq(tasks.courierId, courier.courierId)];
      if (status?.length) conditions.push(inArray(tasks.status, status));
      if (updatedSince) conditions.push(gte(tasks.updatedAt, new Date(updatedSince)));

      const decoded = decodeCursor(cursor);
      if (decoded) {
        // Keyset pagination on (updatedAt, id). Offset pagination would skip or
        // repeat rows whenever dispatch touches a task mid-scroll.
        conditions.push(
          or(
            lt(tasks.updatedAt, decoded.updatedAt),
            and(eq(tasks.updatedAt, decoded.updatedAt), lt(tasks.id, decoded.id)),
          )!,
        );
      }

      const rows = await ctx.db
        .select()
        .from(tasks)
        .where(and(...conditions))
        .orderBy(sql`${tasks.updatedAt} desc`, sql`${tasks.id} desc`)
        .limit(limit + 1);

      const page = rows.slice(0, limit);
      const last = page.at(-1);

      return {
        items: page.map(toSummary),
        nextCursor: rows.length > limit && last ? encodeCursor(last.updatedAt, last.id) : null,
        syncedAt: new Date().toISOString(),
      };
    },
  );

  route.get(
    '/v1/tasks/:taskId',
    {
      schema: {
        tags: ['Task'],
        params: z.object({ taskId: Uuid }),
        response: { 200: TaskDetail, ...problem },
      },
    },
    async (request) => {
      const courier = await app.authenticate(request);
      return toDetail(await loadTask(ctx, courier, request.params.taskId));
    },
  );

  route.post(
    '/v1/tasks/:taskId/call',
    {
      schema: {
        tags: ['Task'],
        params: z.object({ taskId: Uuid }),
        body: MaskedCallRequest,
        response: { 200: MaskedCallResponse, ...problem },
      },
    },
    async (request) => {
      const courier = await app.authenticate(request);
      const task = await loadTask(ctx, courier, request.params.taskId);
      const { target } = request.body;

      if (ctx.env.MASKED_CALL_PROVIDER !== 'mock' && !ctx.env.MASKED_CALL_API_KEY) {
        throw new AppError('UPSTREAM_UNAVAILABLE', {
          message: 'Arama servisi su anda kullanilamiyor.',
          userVisible: true,
        });
      }

      let stored: string | null = null;
      if (target === 'recipient') {
        stored = task.contactPhoneEncrypted;
      } else if (target === 'dispatcher') {
        stored = '+902124440026';
      } else {
        throw new AppError('BUSINESS_RULE_VIOLATION', {
          message: 'Bu hedef icin arama yok.',
          userVisible: true,
        });
      }

      const dialNumber = plaintextPhone(stored, fieldKeyFromEnv(ctx.env.FIELD_ENCRYPTION_KEY));
      if (!dialNumber) {
        throw new AppError('BUSINESS_RULE_VIOLATION', {
          message: 'Alici telefonu kayitli degil.',
          userVisible: true,
        });
      }

      const expiresAt = new Date(Date.now() + 10 * 60 * 1000);
      const [session] = await ctx.db
        .insert(maskedCallSessions)
        .values({
          taskId: task.id,
          courierId: courier.courierId,
          target,
          provider: ctx.env.MASKED_CALL_PROVIDER,
          proxyNumber: dialNumber,
          expiresAt,
        })
        .returning();

      return {
        dialNumber,
        sessionId: session!.id,
        expiresAt: expiresAt.toISOString(),
      };
    },
  );

  route.post(
    '/v1/tasks/:taskId/otp/send',
    {
      schema: {
        tags: ['Task'],
        params: z.object({ taskId: Uuid }),
        body: TaskOtpSendRequest,
        response: { 200: TaskOtpSendResponse, ...problem },
      },
    },
    async (request) => {
      const courier = await app.authenticate(request);
      const task = await loadTask(ctx, courier, request.params.taskId);
      const workflow = await loadWorkflow(ctx, task);
      const answers = await loadAnswers(ctx, task.id);
      const context = buildConditionContext(task, answers);
      const step = visibleSteps(workflow.steps, context).find((s) => s.key === request.body.stepKey);
      if (!step || step.type !== 'OTP_VERIFY') {
        throw new AppError('WORKFLOW_STEP_OUT_OF_ORDER', {
          details: [{ field: 'stepKey', issue: 'not_otp', meta: { stepKey: request.body.stepKey } }],
        });
      }

      const key = fieldKeyFromEnv(ctx.env.FIELD_ENCRYPTION_KEY);
      const target = (step.config as { target?: string }).target ?? 'recipient';
      let phone: string | null = null;
      if (target === 'custom') {
        phone = plaintextPhone(request.body.phone, key);
      } else {
        phone = plaintextPhone(task.contactPhoneEncrypted, key);
      }
      if (!phone) {
        throw new AppError('BUSINESS_RULE_VIOLATION', {
          message: 'Alici telefonu kayitli degil.',
          userVisible: true,
        });
      }

      const issued = await ctx.otp.issue({
        purpose: 'task_delivery',
        phone,
        channel: request.body.channel,
        courierId: courier.courierId,
        taskId: task.id,
        stepKey: step.key,
      });

      return {
        challengeId: issued.challengeId,
        maskedPhone: maskMsisdn(phone),
        expiresAt: issued.expiresAt.toISOString(),
        resendAvailableAt: issued.resendAvailableAt.toISOString(),
        attemptsRemaining: issued.attemptsRemaining,
      };
    },
  );

  route.post(
    '/v1/tasks/:taskId/otp/verify',
    {
      schema: {
        tags: ['Task'],
        params: z.object({ taskId: Uuid }),
        body: TaskOtpVerifyRequest,
        response: { 200: TaskOtpVerifyResponse, ...problem },
      },
    },
    async (request) => {
      const courier = await app.authenticate(request);
      const task = await loadTask(ctx, courier, request.params.taskId);
      const result = await ctx.otp.verify({
        challengeId: request.body.challengeId,
        code: request.body.code,
      });
      if (result.taskId && result.taskId !== task.id) {
        throw new AppError('OTP_INVALID');
      }
      const stepKey = result.stepKey ?? 'otp_dogrula';
      return {
        verified: true,
        verificationToken: signOtpProof(
          ctx.env.JWT_ACCESS_SECRET,
          task.id,
          stepKey,
          request.body.challengeId,
        ),
        attemptsRemaining: result.attemptsRemaining,
      };
    },
  );

  route.post(
    '/v1/tasks/:taskId/transition',
    {
      schema: {
        tags: ['Task'],
        params: z.object({ taskId: Uuid }),
        body: TaskTransitionRequest,
        response: { 200: TaskMutationResponse, ...problem },
      },
    },
    async (request) => {
      const courier = await app.authenticate(request);
      const body = request.body;

      return withIdempotency(ctx, courier, request, body, async () => {
        const task = await loadTask(ctx, courier, request.params.taskId);
        assertRowVersion(task.rowVersion, body.rowVersion);
        assertTransition(task.status, body.to);

        const now = new Date();
        const occurredAt = clampOccurredAt(new Date(body.occurredAt), now);

        await ctx.db.transaction(async (tx) => {
          await tx
            .update(tasks)
            .set({
              status: body.to,
              ...(body.to === 'IN_PROGRESS' && !task.startedAt ? { startedAt: occurredAt } : {}),
            })
            .where(eq(tasks.id, task.id));

          await tx.insert(taskTransitions).values({
            taskId: task.id,
            fromStatus: task.status,
            toStatus: body.to,
            actorType: 'courier',
            actorId: courier.courierId,
            position: body.location ? { lat: body.location.lat, lng: body.location.lng } : null,
            occurredAt,
            clientEventId: body.clientEventId,
          });

          await emitEvent(tx, {
            key: EVENT_BY_STATUS[body.to],
            tenantId: courier.tenantId,
            subjectType: 'task',
            subjectId: task.id,
            actorType: 'courier',
            actorId: courier.courierId,
            correlationId: request.id,
            occurredAt,
            data: { from: task.status, to: body.to, reference: task.reference },
          });

          const eventCtx = { tenantId: courier.tenantId, correlationId: request.id };

          // Faz 4 (Nihai mimari): starts the moment we first know the
          // delivery window (slotEndAt) — a no-op after the first call, and
          // a no-op entirely when the task has no window to miss.
          await startSlaInstance(tx, eventCtx, {
            subjectType: 'task',
            subjectId: task.id,
            targetAt: task.slotEndAt,
            startedAt: task.createdAt,
          });

          // Faz 1 (Nihai mimari): a courier-initiated cancellation is the
          // one genuine WO-terminal moment reachable from this endpoint.
          if (body.to === 'CANCELLED') {
            const workOrderId = await ensureWorkOrder(tx, task);
            await transitionWorkOrder(tx, eventCtx, workOrderId, 'WO-120', 'task.cancelled', occurredAt);
            // A cancelled task's SLA is over — resolve it too rather than
            // leaving it open forever with no further event to close it.
            await resolveSlaInstance(tx, eventCtx, { subjectType: 'task', subjectId: task.id, resolvedAt: occurredAt });
          }
        });

        return {
          status: 200,
          value: {
            task: toDetail(await loadTask(ctx, courier, task.id)),
            appliedAt: now.toISOString(),
            replayed: false,
          },
        };
      });
    },
  );

  route.post(
    '/v1/tasks/:taskId/steps',
    {
      schema: {
        tags: ['Task'],
        params: z.object({ taskId: Uuid }),
        body: StepSubmitRequest,
        response: { 200: TaskMutationResponse, ...problem },
      },
    },
    async (request) => {
      const courier = await app.authenticate(request);
      const body = request.body;

      return withIdempotency(ctx, courier, request, body, async () => {
        const task = await loadTask(ctx, courier, request.params.taskId);
        assertRowVersion(task.rowVersion, body.rowVersion);

        if (task.finalizedAt) throw new AppError('TASK_ALREADY_FINALIZED');

        const workflow = await loadWorkflow(ctx, task);
        assertWorkflowVersion(task, body.workflowVersion);

        const answers = await loadAnswers(ctx, task.id);
        const context = buildConditionContext(task, answers);

        const step = visibleSteps(workflow.steps, context).find((s) => s.key === body.stepKey);
        if (!step) {
          // Either the key does not exist in this version, or its condition is
          // false right now. Both mean the client is out of step with the
          // server's view of the wizard.
          throw new AppError('WORKFLOW_STEP_OUT_OF_ORDER', {
            details: [{ field: 'stepKey', issue: 'not_visible', meta: { stepKey: body.stepKey } }],
          });
        }

        if (body.status === 'skipped' && step.required && !step.skipReasons?.length) {
          throw new AppError('BUSINESS_RULE_VIOLATION', {
            message: 'Bu adim atlanamaz.',
            userVisible: true,
          });
        }

        if (step.type === 'GEOFENCE_CHECK' && body.status === 'completed') {
          assertWithinFence(step.config, task, body.location);
        }

        if (body.status === 'completed') {
          await assertStepEvidence(ctx, courier, task.id, step.key, step, body);
        }

        const now = new Date();
        const occurredAt = clampOccurredAt(new Date(body.occurredAt), now);
        const previous = answers.find((a) => a.stepKey === body.stepKey);

        await ctx.db.transaction(async (tx) => {
          await tx.insert(taskSteps).values({
            taskId: task.id,
            stepKey: body.stepKey,
            workflowVersion: body.workflowVersion,
            revision: (previous?.revision ?? 0) + 1,
            status: body.status,
            value: body.value ?? null,
            mediaIds: body.mediaIds,
            skipReasonCode: body.skipReasonCode ?? null,
            overrideReasonCode: body.skipReasonCode ?? null,
            position: body.location ? { lat: body.location.lat, lng: body.location.lng } : null,
            accuracy: body.location ? Math.round(body.location.accuracy) : null,
            occurredAt,
            clientEventId: body.clientEventId,
          });

          // Touch the task so its rowVersion moves and the delta pull sees it.
          await tx.update(tasks).set({ updatedAt: now }).where(eq(tasks.id, task.id));

          await emitEvent(tx, {
            key: body.status === 'completed' ? 'task.step_completed' : 'task.step_skipped',
            tenantId: courier.tenantId,
            subjectType: 'task',
            subjectId: task.id,
            actorType: 'courier',
            actorId: courier.courierId,
            correlationId: request.id,
            occurredAt,
            data: {
              stepKey: body.stepKey,
              stepType: step.type,
              mediaCount: body.mediaIds.length,
              skipReasonCode: body.skipReasonCode ?? null,
            },
          });

          // Faz 3 (Nihai mimari): a completed SIGNATURE/DOCUMENT_SCAN step is
          // the one DOC-producing event this codebase's courier-only auth can
          // actually reach.
          const docStatus = body.status === 'completed' ? documentStatusForStepType(step.type) : null;
          if (docStatus) {
            const doc = await ensureDocument(tx, {
              tenantId: courier.tenantId,
              taskId: task.id,
              sourceStepKey: body.stepKey,
              mediaId: body.mediaIds[0] ?? null,
            });
            await transitionDocument(
              tx,
              { tenantId: courier.tenantId, correlationId: request.id },
              doc.id,
              doc.status,
              docStatus,
              `step.${step.type}`,
              occurredAt,
            );
          }
        });

        return {
          status: 200,
          value: {
            task: toDetail(await loadTask(ctx, courier, task.id)),
            appliedAt: now.toISOString(),
            replayed: false,
          },
        };
      });
    },
  );

  route.post(
    '/v1/tasks/:taskId/finalize',
    {
      schema: {
        tags: ['Task'],
        params: z.object({ taskId: Uuid }),
        body: TaskFinalizeRequest,
        response: { 200: TaskMutationResponse, ...problem },
      },
    },
    async (request) => {
      const courier = await app.authenticate(request);
      const body = request.body;

      return withIdempotency(ctx, courier, request, body, async () => {
        const task = await loadTask(ctx, courier, request.params.taskId);
        assertRowVersion(task.rowVersion, body.rowVersion);
        if (task.finalizedAt) throw new AppError('TASK_ALREADY_FINALIZED');

        const workflow = await loadWorkflow(ctx, task);
        assertWorkflowVersion(task, body.workflowVersion);

        const outcome = workflow.outcomes.find((o) => o.code === body.outcomeCode);
        if (!outcome) {
          throw new AppError('VALIDATION_FAILED', {
            details: [{ field: 'outcomeCode', issue: 'unknown', meta: { code: body.outcomeCode } }],
          });
        }

        const now = new Date();
        const occurredAt = clampOccurredAt(new Date(body.occurredAt), now);

        // Outcome-specific answers land in the same transaction as the outcome
        // itself, so a delivery is never recorded without its evidence.
        const submitted = new Map(body.answers.map((a) => [a.stepKey, a]));
        const answers = await loadAnswers(ctx, task.id);
        const context = buildConditionContext(task, answers);

        for (const [key, answer] of submitted) {
          context.steps[key] = { status: answer.status, value: answer.value };
        }

        const missingMain = missingRequiredSteps(workflow.steps, context);
        const missingOutcome = missingRequiredSteps(outcome.steps, context);
        const missing = [...missingMain, ...missingOutcome];

        if (missing.length > 0) {
          throw new AppError('EVIDENCE_INCOMPLETE', {
            message: 'Zorunlu adimlar tamamlanmadan gorev kapatilamaz.',
            userVisible: true,
            details: missing.map((stepKey) => ({ field: 'answers', issue: 'missing', meta: { stepKey } })),
          });
        }

        const nextStatus = outcome.kind === 'success' ? 'COMPLETED' : 'FAILED';
        assertTransition(task.status, nextStatus);

        await ctx.db.transaction(async (tx) => {
          for (const answer of body.answers) {
            await tx.insert(taskSteps).values({
              taskId: task.id,
              stepKey: answer.stepKey,
              workflowVersion: body.workflowVersion,
              revision: 1,
              status: answer.status,
              value: answer.value ?? null,
              mediaIds: answer.mediaIds,
              skipReasonCode: answer.skipReasonCode ?? null,
              occurredAt,
              clientEventId: crypto.randomUUID(),
            });
          }

          await tx
            .update(tasks)
            .set({
              status: nextStatus,
              outcomeCode: outcome.code,
              outcomeNote: body.note ?? null,
              finalizedAt: occurredAt,
            })
            .where(eq(tasks.id, task.id));

          await tx.insert(taskTransitions).values({
            taskId: task.id,
            fromStatus: task.status,
            toStatus: nextStatus,
            actorType: 'courier',
            actorId: courier.courierId,
            position: body.location ? { lat: body.location.lat, lng: body.location.lng } : null,
            occurredAt,
            clientEventId: body.clientEventId,
            reason: outcome.code,
          });

          await emitEvent(tx, {
            key: outcome.kind === 'success' ? 'task.completed' : 'task.failed',
            tenantId: courier.tenantId,
            subjectType: 'task',
            subjectId: task.id,
            actorType: 'courier',
            actorId: courier.courierId,
            correlationId: request.id,
            occurredAt,
            data: {
              outcomeCode: outcome.code,
              outcomeKind: outcome.kind,
              reference: task.reference,
              attemptNumber: task.attemptNumber,
              rescheduleAllowed: outcome.reschedule?.allowed ?? false,
            },
          });

          // Faz 1 (Nihai mimari): every finalize is a delivery attempt/result,
          // recorded against the canonical DLV catalog regardless of outcome.
          // Only a *successful* finalize ends the work order — a failed
          // attempt can still be retried, so WO stays Aktif (WO-070).
          const workOrderId = await ensureWorkOrder(tx, task);
          const eventCtx = { tenantId: courier.tenantId, correlationId: request.id };

          const deliveryResult = await recordDeliveryResult(tx, eventCtx, {
            taskId: task.id,
            workOrderId,
            attemptNumber: task.attemptNumber,
            outcomeCode: outcome.code,
            note: body.note ?? null,
            position: body.location ? { lat: body.location.lat, lng: body.location.lng } : null,
            occurredAt,
          });

          if (outcome.kind === 'success') {
            await transitionWorkOrder(tx, eventCtx, workOrderId, 'WO-110', 'task.completed', occurredAt);

            // Faz 3 (Nihai mimari): reaching here means missingRequiredSteps
            // (checked above, before this transaction opened) already passed
            // — that check *is* today's "Otomatik" control policy. This just
            // gives it a canonical QUA-070 audit row.
            await recordAutomaticQualityReview(tx, eventCtx, {
              subjectType: 'delivery_result',
              subjectId: deliveryResult.id,
              occurredAt,
            });
          } else {
            // Faz 4 (Nihai mimari): a failed delivery only opens a return
            // when the courier actually still has something physical to
            // send back — a digital-only task correctly opens nothing.
            await openReturnsForFailedTask(tx, { ...eventCtx, courierId: courier.courierId }, {
              taskId: task.id,
              reason: outcome.code,
              occurredAt,
            });
          }

          // Faz 4: this attempt is over either way — a retry (if any) is a
          // separate task row (see `tasks.previousTaskId`) with its own SLA.
          await resolveSlaInstance(tx, eventCtx, { subjectType: 'task', subjectId: task.id, resolvedAt: occurredAt });
        });

        return {
          status: 200,
          value: {
            task: toDetail(await loadTask(ctx, courier, task.id)),
            appliedAt: now.toISOString(),
            replayed: false,
          },
        };
      });
    },
  );
}

/* ------------------------------------------------------------------ *
 * Shared helpers
 * ------------------------------------------------------------------ */

const EVENT_BY_STATUS = {
  ASSIGNED: 'task.assigned',
  ACCEPTED: 'task.accepted',
  EN_ROUTE: 'task.en_route',
  ARRIVED: 'task.arrived',
  IN_PROGRESS: 'task.started',
  COMPLETED: 'task.completed',
  FAILED: 'task.failed',
  CANCELLED: 'task.cancelled',
} as const;

type TaskRow = typeof tasks.$inferSelect & { items?: (typeof taskItems.$inferSelect)[]; answers?: AnswerRow[] };
type AnswerRow = typeof taskSteps.$inferSelect;

async function loadTask(ctx: AppContext, courier: AuthenticatedCourier, taskId: string): Promise<TaskRow> {
  const [task] = await ctx.db
    .select()
    .from(tasks)
    .where(and(eq(tasks.id, taskId), eq(tasks.courierId, courier.courierId)))
    .limit(1);

  if (!task) throw new AppError('NOT_FOUND');

  const items = await ctx.db.select().from(taskItems).where(eq(taskItems.taskId, taskId));
  const answers = await loadAnswers(ctx, taskId);

  return { ...task, items, answers };
}

/** Latest revision per step key. Earlier revisions stay for the audit trail. */
async function loadAnswers(ctx: AppContext, taskId: string): Promise<AnswerRow[]> {
  const rows = await ctx.db
    .select()
    .from(taskSteps)
    .where(eq(taskSteps.taskId, taskId))
    .orderBy(asc(taskSteps.stepKey), asc(taskSteps.revision));

  const latest = new Map<string, AnswerRow>();
  for (const row of rows) latest.set(row.stepKey, row);
  return [...latest.values()];
}

async function loadWorkflow(ctx: AppContext, task: TaskRow) {
  if (!task.workflowId) {
    throw new AppError('BUSINESS_RULE_VIOLATION', { message: 'Goreve workflow atanmamis.' });
  }
  const [workflow] = await ctx.db.select().from(workflows).where(eq(workflows.id, task.workflowId)).limit(1);
  if (!workflow) throw new AppError('NOT_FOUND');
  return workflow;
}

/** Rule K3: a running task finishes on the version it started with. */
function assertWorkflowVersion(task: TaskRow, provided: number): void {
  if (task.workflowVersion !== provided) {
    throw new AppError('WORKFLOW_VERSION_SUPERSEDED', {
      details: [
        { field: 'workflowVersion', issue: 'mismatch', meta: { expected: task.workflowVersion, provided } },
      ],
    });
  }
}

function assertWithinFence(
  config: { radiusMeters: number; maxAccuracyMeters: number; allowOverrideWithReason: boolean },
  task: TaskRow,
  location: { lat: number; lng: number; accuracy: number; capturedAt: string } | null | undefined,
): void {
  if (!task.position) return;

  const outcome = checkGeofence({
    target: task.position,
    fix: location ? { ...location, isMocked: false } : null,
    radiusMeters: config.radiusMeters,
    maxAccuracyMeters: config.maxAccuracyMeters,
  });

  // An imprecise fix is not proof of absence. Only a confident "outside"
  // blocks, and only when the workflow forbids an override.
  if (outcome.result === 'outside' && !config.allowOverrideWithReason) {
    throw new AppError('GEOFENCE_VIOLATION', {
      details: [
        {
          field: 'location',
          issue: 'outside_fence',
          meta: { distance: Math.round(outcome.distance), radius: config.radiusMeters },
        },
      ],
    });
  }
}

function buildConditionContext(task: TaskRow, answers: AnswerRow[]): ConditionContext {
  return {
    steps: Object.fromEntries(
      answers.map((a) => [a.stepKey, { status: a.status, value: a.value }]),
    ),
    task: {
      type: task.type,
      priority: task.priority,
      attemptNumber: task.attemptNumber,
      codAmount: task.codAmount ? Number(task.codAmount) : 0,
      attributes: task.attributes,
    },
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
    throw new AppError('VALIDATION_FAILED', {
      details: [{ field: 'idempotency-key', issue: 'required' }],
    });
  }

  const store = new PostgresIdempotencyStore(ctx.db, courier.courierId);
  const result = await runIdempotent(store, key, body, handler);

  if (result.replayed && result.value && typeof result.value === 'object') {
    return { ...(result.value as object), replayed: true } as T;
  }
  return result.value;
}

export function toSummary(task: typeof tasks.$inferSelect) {
  return {
    id: task.id,
    reference: task.reference,
    type: task.type,
    status: task.status,
    sequence: task.sequence,
    address: {
      line1: task.addressLine1,
      line2: task.addressLine2,
      district: task.district,
      city: task.city,
      postalCode: task.postalCode,
      countryCode: task.countryCode,
      coordinates: task.position,
      geocodeConfidence: task.geocodeConfidence as 'exact' | null,
    },
    contact: {
      name: task.contactName ?? '',
      // The raw number is encrypted at rest and never leaves the server; the
      // app calls through the masked-call endpoint instead.
      maskedPhone: null,
      hasReachablePhone: Boolean(task.contactPhoneEncrypted),
      note: task.contactNote,
    },
    etaAt: task.etaAt?.toISOString() ?? null,
    slotStartAt: task.slotStartAt?.toISOString() ?? null,
    slotEndAt: task.slotEndAt?.toISOString() ?? null,
    priority: task.priority,
    itemCount: task.itemCount,
    codAmount: task.codAmount ? Number(task.codAmount) : null,
    updatedAt: task.updatedAt.toISOString(),
    rowVersion: task.rowVersion,
  };
}

function toDetail(task: TaskRow) {
  return {
    ...toSummary(task),
    workflow: {
      workflowId: task.workflowId!,
      key: task.workflowKey!,
      version: task.workflowVersion!,
      minAppBuild: 1,
    },
    items: (task.items ?? []).map((item) => ({
      id: item.id,
      barcode: item.barcode,
      description: item.description,
      quantity: item.quantity,
      weightGrams: item.weightGrams,
    })),
    attributes: task.attributes,
    answers: (task.answers ?? []).map((a) => ({
      stepKey: a.stepKey,
      status: a.status,
      value: a.value,
      media: [],
      skipReasonCode: a.skipReasonCode,
      capturedAt: a.occurredAt.toISOString(),
      location: null,
    })),
    notes: task.outcomeNote,
    attemptNumber: task.attemptNumber,
    previousFailureReason: null,
  };
}

function maskMsisdn(phone: string): string {
  const digits = phone.replace(/\D/g, '');
  if (digits.length < 7) return '+90 ***';
  return `+${digits.slice(0, 2)} ${digits.slice(2, 5)} *** ** ${digits.slice(-2)}`;
}

async function assertStepEvidence(
  ctx: AppContext,
  courier: AuthenticatedCourier,
  taskId: string,
  stepKey: string,
  step: { type: string; config: Record<string, unknown> },
  body: { value?: unknown; mediaIds: string[] },
) {
  if (body.mediaIds.length > 0) {
    const rows = await ctx.db
      .select({ id: media.id, state: media.state, courierId: media.courierId })
      .from(media)
      .where(inArray(media.id, body.mediaIds));
    if (rows.length !== body.mediaIds.length) {
      throw new AppError('MEDIA_NOT_READY', { message: 'Kanit dosyasi bulunamadi.', userVisible: true });
    }
    for (const row of rows) {
      if (row.courierId !== courier.courierId) throw new AppError('FORBIDDEN');
      if (row.state === 'purged') {
        throw new AppError('MEDIA_NOT_READY', { message: 'Kanit dosyasi silinmis.', userVisible: true });
      }
      if (row.state === 'pending') {
        await ctx.db.update(media).set({ state: 'uploaded' }).where(eq(media.id, row.id));
      }
    }
  }

  if (step.type === 'OTP_VERIFY') {
    const token =
      body.value && typeof body.value === 'object'
        ? (body.value as { verificationToken?: unknown }).verificationToken
        : undefined;
    if (!verifyOtpProof(ctx.env.JWT_ACCESS_SECRET, token, taskId, stepKey)) {
      throw new AppError('OTP_INVALID', { message: 'Teslim kodu dogrulanmadi.', userVisible: true });
    }
  }

  if ((step.type === 'PHOTO_EVIDENCE' || step.type === 'SIGNATURE') && body.mediaIds.length < 1) {
    throw new AppError('EVIDENCE_INCOMPLETE', {
      message: 'Bu adim icin fotograf veya imza gerekir.',
      userVisible: true,
    });
  }
}

/** Opaque to the client, but just a base64 keyset tuple underneath. */
export function encodeCursor(updatedAt: Date, id: string): string {
  return Buffer.from(`${updatedAt.toISOString()}|${id}`).toString('base64url');
}

export function decodeCursor(cursor: string | null | undefined): { updatedAt: Date; id: string } | null {
  if (!cursor) return null;
  const [timestamp, id] = Buffer.from(cursor, 'base64url').toString('utf8').split('|');
  if (!timestamp || !id) return null;
  return { updatedAt: new Date(timestamp), id };
}
