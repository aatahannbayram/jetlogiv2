import {
  Address,
  CursorPageQuery,
  GeoPoint,
  PhoneNumber,
  RowVersion,
  Timestamp,
  Uuid,
  cursorPage,
  z,
} from './common.js';
import { MediaRef } from './media.js';
import { WorkflowRef } from './workflow.js';

export const TaskType = z.enum(['DELIVERY', 'PICKUP', 'RETURN', 'SERVICE', 'DOCUMENT']);

export const TaskStatus = z.enum([
  'ASSIGNED',
  'ACCEPTED',
  'EN_ROUTE',
  'ARRIVED',
  'IN_PROGRESS',
  'COMPLETED',
  'FAILED',
  'CANCELLED',
]);
export type TaskStatus = z.infer<typeof TaskStatus>;

/**
 * Transitions the mobile app is allowed to perform. Anything else is a
 * server-side move (CANCELLED comes from the panel). Enforced in
 * `@dijigoo/core` so client and API agree.
 */
export const ALLOWED_TASK_TRANSITIONS: Record<z.infer<typeof TaskStatus>, readonly z.infer<typeof TaskStatus>[]> = {
  ASSIGNED: ['ACCEPTED', 'FAILED'],
  ACCEPTED: ['EN_ROUTE', 'FAILED'],
  EN_ROUTE: ['ARRIVED', 'FAILED'],
  ARRIVED: ['IN_PROGRESS', 'FAILED'],
  IN_PROGRESS: ['COMPLETED', 'FAILED'],
  COMPLETED: [],
  FAILED: [],
  CANCELLED: [],
};

export const Contact = z
  .object({
    name: z.string().max(160),
    /**
     * Never the raw MSISDN once masked calling is live: the app receives a
     * proxy number and the real one stays server-side.
     */
    maskedPhone: z.string().max(40).nullish(),
    hasReachablePhone: z.boolean().default(true),
    note: z.string().max(500).nullish(),
  })
  .openapi('Contact');

export const TaskSummary = z
  .object({
    id: Uuid,
    reference: z.string().max(60).openapi({ example: 'DJG-2026-004512' }),
    type: TaskType,
    status: TaskStatus,
    sequence: z.number().int().nonnegative().describe('Rota icindeki sira'),
    address: Address,
    contact: Contact,
    /** Null in Faz 1 when no paid traffic provider is wired. */
    etaAt: Timestamp.nullish(),
    slotStartAt: Timestamp.nullish(),
    slotEndAt: Timestamp.nullish(),
    priority: z.enum(['normal', 'high', 'urgent']).default('normal'),
    itemCount: z.number().int().nonnegative().default(1),
    codAmount: z.number().nonnegative().nullish().describe('Kapida odeme, TRY'),
    updatedAt: Timestamp,
    rowVersion: RowVersion,
  })
  .openapi('TaskSummary');
export type TaskSummary = z.infer<typeof TaskSummary>;

export const TaskItem = z
  .object({
    id: Uuid,
    barcode: z.string().max(80).nullish(),
    description: z.string().max(300),
    quantity: z.number().int().positive().default(1),
    weightGrams: z.number().int().nonnegative().nullish(),
  })
  .openapi('TaskItem');

export const StepAnswer = z
  .object({
    stepKey: z.string(),
    status: z.enum(['completed', 'skipped']),
    /** Shape depends on the step type; validated against the step config. */
    value: z.unknown().nullish(),
    media: z.array(MediaRef).default([]),
    skipReasonCode: z.string().max(60).nullish(),
    capturedAt: Timestamp,
    location: GeoPoint.nullish(),
  })
  .openapi('StepAnswer');
export type StepAnswer = z.infer<typeof StepAnswer>;

export const TaskDetail = TaskSummary.extend({
  workflow: WorkflowRef,
  items: z.array(TaskItem).default([]),
  attributes: z.record(z.unknown()).default({}).describe('Kaynak sistemden gelen serbest alanlar'),
  answers: z.array(StepAnswer).default([]),
  notes: z.string().max(2000).nullish(),
  attemptNumber: z.number().int().positive().default(1),
  previousFailureReason: z.string().max(160).nullish(),
}).openapi('TaskDetail');
export type TaskDetail = z.infer<typeof TaskDetail>;

/* ------------------------------------------------------------------ *
 * Listing
 * ------------------------------------------------------------------ */

export const TaskListQuery = CursorPageQuery.extend({
  status: z.array(TaskStatus).nullish(),
  /** Watermark for delta sync; returns everything changed at or after it. */
  updatedSince: Timestamp.nullish(),
  routeId: Uuid.nullish(),
});

export const TaskListResponse = cursorPage(TaskSummary, 'TaskListResponse');

/* ------------------------------------------------------------------ *
 * Mutations
 * ------------------------------------------------------------------ */

/**
 * Every task mutation carries the rowVersion the client believed it had.
 * A mismatch means the panel changed the task underneath the courier, and the
 * client must refetch rather than blindly overwrite.
 */
const mutationBase = {
  rowVersion: RowVersion,
  clientEventId: Uuid.describe('Offline kuyrukta uretilen olay kimligi'),
  occurredAt: Timestamp.describe('Cihaz saati, sunucu saatiyle birlikte saklanir'),
  location: GeoPoint.nullish(),
};

export const TaskTransitionRequest = z
  .object({
    ...mutationBase,
    to: TaskStatus,
  })
  .openapi('TaskTransitionRequest');

export const StepSubmitRequest = z
  .object({
    ...mutationBase,
    stepKey: z.string().min(1).max(60),
    workflowVersion: z.number().int().positive(),
    status: z.enum(['completed', 'skipped']),
    value: z.unknown().nullish(),
    mediaIds: z.array(Uuid).default([]),
    skipReasonCode: z.string().max(60).nullish(),
  })
  .openapi('StepSubmitRequest');

export const TaskFinalizeRequest = z
  .object({
    ...mutationBase,
    workflowVersion: z.number().int().positive(),
    outcomeCode: z.string().max(50),
    /** Answers for outcome-specific steps, submitted atomically with the outcome. */
    answers: z.array(StepSubmitRequest.omit({ rowVersion: true, clientEventId: true, occurredAt: true })).default([]),
    note: z.string().max(2000).nullish(),
  })
  .openapi('TaskFinalizeRequest');

export const TaskMutationResponse = z
  .object({
    task: TaskDetail,
    /** Server clock, authoritative for ordering. */
    appliedAt: Timestamp,
    /** True when this request was a replay of an already-applied idempotency key. */
    replayed: z.boolean().default(false),
  })
  .openapi('TaskMutationResponse');

/* ------------------------------------------------------------------ *
 * Recipient OTP
 * ------------------------------------------------------------------ */

export const TaskOtpSendRequest = z
  .object({
    stepKey: z.string().max(60),
    channel: z.enum(['sms', 'ivr']).default('sms'),
    /** Only when the step config sets `target: custom`. */
    phone: PhoneNumber.nullish(),
  })
  .openapi('TaskOtpSendRequest');

export const TaskOtpSendResponse = z
  .object({
    challengeId: Uuid,
    maskedPhone: z.string().openapi({ example: '+90 532 *** ** 67' }),
    expiresAt: Timestamp,
    resendAvailableAt: Timestamp,
    attemptsRemaining: z.number().int().nonnegative(),
  })
  .openapi('TaskOtpSendResponse');

export const TaskOtpVerifyRequest = z
  .object({
    challengeId: Uuid,
    code: z.string().regex(/^\d{4,8}$/),
  })
  .openapi('TaskOtpVerifyRequest');

export const TaskOtpVerifyResponse = z
  .object({
    verified: z.boolean(),
    /** Opaque proof the client attaches to the OTP_VERIFY step submission. */
    verificationToken: z.string().nullish(),
    attemptsRemaining: z.number().int().nonnegative(),
  })
  .openapi('TaskOtpVerifyResponse');

/* ------------------------------------------------------------------ *
 * Masked call
 * ------------------------------------------------------------------ */

export const MaskedCallRequest = z
  .object({
    target: z.enum(['recipient', 'sender', 'dispatcher']),
  })
  .openapi('MaskedCallRequest');

export const MaskedCallResponse = z
  .object({
    /** Proxy number the app dials. Real MSISDN never reaches the handset. */
    dialNumber: z.string(),
    sessionId: Uuid,
    expiresAt: Timestamp,
  })
  .openapi('MaskedCallResponse');
