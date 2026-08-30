import { Timestamp, Uuid, z } from './common.js';

/**
 * Domain event keys (Bolum 18). Naming is `<aggregate>.<past tense verb>`,
 * dot separated, lower snake case. These strings are a public contract: they
 * appear in webhooks, the outbox table and the panel timeline, so they are
 * append-only. Renaming one is a breaking change.
 */
export const EventKey = z.enum([
  // courier lifecycle
  'courier.activated',
  'courier.device_bound',
  'courier.device_integrity_flagged',
  'courier.suspended',
  // shift
  'shift.started',
  'shift.ended',
  'shift.location_gap_detected',
  // task lifecycle
  'task.assigned',
  'task.accepted',
  'task.en_route',
  'task.arrived',
  'task.started',
  'task.step_completed',
  'task.step_skipped',
  'task.completed',
  'task.failed',
  'task.cancelled',
  'task.rescheduled',
  // verification
  'otp.sent',
  'otp.verified',
  'otp.failed',
  'otp.manually_overridden',
  // evidence
  'evidence.uploaded',
  'evidence.rejected',
  // custody
  'custody.item_taken',
  'custody.item_handed_over',
  'custody.discrepancy_reported',
  'custody.item_damaged',
  'custody.item_lost',
  // communication
  'call.masked_session_started',
  'sms.notification_sent',
  // support
  'support.ticket_created',
  'support.ticket_resolved',
  // workflow
  'workflow.published',
  'workflow.archived',
  // work order / delivery result (Nihai mimari Faz 1)
  'work_order.transitioned',
  'delivery_result.recorded',
  // document / quality review (Nihai mimari Faz 3)
  'document.transitioned',
  'quality_review.recorded',
  // return / SLA (Nihai mimari Faz 4)
  'return.transitioned',
  'sla.started',
  'sla.resolved',
]);
export type EventKey = z.infer<typeof EventKey>;

/**
 * Envelope every event shares. Written to the outbox in the same transaction
 * as the state change, then relayed by the worker. That is what makes
 * "state changed but webhook never fired" impossible.
 */
export const EventEnvelope = z
  .object({
    /** Unique per event. Consumers use it to deduplicate. */
    id: Uuid,
    key: EventKey,
    /** Schema version of `data`, bumped independently per key. */
    version: z.number().int().positive().default(1),
    /** Aggregate the event is about. */
    subject: z.object({
      type: z.enum([
        'courier',
        'shift',
        'task',
        'custody',
        'workflow',
        'ticket',
        'work_order',
        'delivery_result',
        'document',
        'quality_review',
        'return',
        'sla',
      ]),
      id: Uuid,
    }),
    /** When the thing actually happened, from the device or the server. */
    occurredAt: Timestamp,
    /** When the server durably recorded it. Always >= occurredAt after skew correction. */
    recordedAt: Timestamp,
    actor: z.object({
      type: z.enum(['courier', 'operator', 'system', 'integration']),
      id: Uuid.nullish(),
    }),
    /** Ties every event produced while handling one request together. */
    correlationId: z.string(),
    /** The event that caused this one, if any. */
    causationId: Uuid.nullish(),
    tenantId: Uuid.nullish(),
    data: z.record(z.unknown()),
  })
  .openapi('EventEnvelope');
export type EventEnvelope = z.infer<typeof EventEnvelope>;

/* ------------------------------------------------------------------ *
 * Webhook delivery
 * ------------------------------------------------------------------ */

/**
 * Outbound webhook body. Signed with HMAC-SHA256 over `${timestamp}.${body}`
 * and sent in the `X-Dijigoo-Signature` header, so a replayed body with an old
 * timestamp fails verification.
 */
export const WebhookPayload = z
  .object({
    events: z.array(EventEnvelope).min(1).max(50),
    deliveryId: Uuid,
    attempt: z.number().int().positive(),
  })
  .openapi('WebhookPayload');

/** Retry schedule for failed deliveries, in seconds. Then the DLQ. */
export const WEBHOOK_BACKOFF_SECONDS = [10, 30, 120, 600, 1800, 7200, 21600] as const;

export const PushNotificationKind = z.enum([
  'TASK_ASSIGNED',
  'TASK_UPDATED',
  'TASK_CANCELLED',
  'ROUTE_RECALCULATED',
  'SHIFT_REMINDER',
  'SUPPORT_REPLY',
  'ANNOUNCEMENT',
  /** Silent push that tells the app to run a delta pull. */
  'SYNC_HINT',
]);

export const PushNotification = z
  .object({
    kind: PushNotificationKind,
    title: z.string().max(120).nullish(),
    body: z.string().max(300).nullish(),
    /** Deep link target inside the app. */
    route: z.string().max(200).nullish(),
    subjectId: Uuid.nullish(),
    /** FCM collapse key so a burst of updates shows one notification. */
    collapseKey: z.string().max(60).nullish(),
    sentAt: Timestamp,
  })
  .openapi('PushNotification');
