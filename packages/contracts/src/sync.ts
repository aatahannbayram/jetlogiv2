import { ErrorResponse, Timestamp, Uuid, z } from './common.js';
import { CustodyItem } from './custody.js';
import { Shift } from './shift.js';
import { TaskSummary } from './task.js';
import { WorkflowRef } from './workflow.js';

/* ------------------------------------------------------------------ *
 * Outbound: the courier's offline queue
 * ------------------------------------------------------------------ */

/**
 * One queued mutation. The client stores these in Drift and drains them in
 * order. `operation` selects the handler; `payload` is the same body the
 * online endpoint would have received, so there is exactly one server-side
 * implementation per operation.
 */
export const SyncOperation = z.enum([
  'SHIFT_START',
  'SHIFT_END',
  'TASK_TRANSITION',
  'STEP_SUBMIT',
  'TASK_FINALIZE',
  'CUSTODY_HANDOVER',
  'SUPPORT_TICKET_CREATE',
]);
export type SyncOperation = z.infer<typeof SyncOperation>;

export const SyncEnvelope = z
  .object({
    /** Client-generated, stable across retries. Doubles as the idempotency key. */
    clientEventId: Uuid,
    operation: SyncOperation,
    /** Target aggregate, e.g. the task id. Null for shift-level operations. */
    subjectId: Uuid.nullish(),
    /** Device clock when the courier performed the action. */
    occurredAt: Timestamp,
    /**
     * Monotonic per-device counter. Guarantees the server can order two events
     * that share a wall-clock timestamp, which happens on fast wizards.
     */
    sequence: z.number().int().nonnegative(),
    payload: z.unknown(),
  })
  .openapi('SyncEnvelope');
export type SyncEnvelope = z.infer<typeof SyncEnvelope>;

export const SyncBatchRequest = z
  .object({
    installationId: Uuid,
    events: z.array(SyncEnvelope).min(1).max(100),
  })
  .openapi('SyncBatchRequest');

export const SyncResultStatus = z.enum([
  'applied',
  'replayed',
  'rejected',
  'conflict',
  'deferred',
]);

/**
 * Per-event outcome. The batch itself always returns 200 unless the whole
 * request was malformed: a single bad event must not block the queue behind
 * it. `deferred` means the server accepted the event but could not apply it
 * yet, typically because referenced media is still uploading.
 */
export const SyncResult = z
  .object({
    clientEventId: Uuid,
    status: SyncResultStatus,
    error: ErrorResponse.shape.error.nullish(),
    /** Present on `conflict`; the client refetches this aggregate. */
    refetch: z.object({ resource: z.enum(['task', 'shift', 'custody']), id: Uuid }).nullish(),
    appliedAt: Timestamp.nullish(),
    /** Seconds to wait before re-sending a `deferred` event. */
    retryAfter: z.number().int().positive().nullish(),
  })
  .openapi('SyncResult');

export const SyncBatchResponse = z
  .object({
    results: z.array(SyncResult),
    serverTime: Timestamp,
    /** Client should stop draining and pull changes first when true. */
    pullRequired: z.boolean().default(false),
  })
  .openapi('SyncBatchResponse');

/* ------------------------------------------------------------------ *
 * Inbound: delta pull
 * ------------------------------------------------------------------ */

export const SyncPullQuery = z.object({
  /** Watermark from the previous pull. Omit for a full bootstrap. */
  since: Timestamp.nullish(),
  cursor: z.string().nullish(),
  limit: z.coerce.number().int().min(1).max(500).default(200),
});

export const SyncChanges = z
  .object({
    tasks: z.array(TaskSummary).default([]),
    /** Ids removed from the courier's scope, e.g. reassigned by dispatch. */
    removedTaskIds: z.array(Uuid).default([]),
    custody: z.array(CustodyItem).default([]),
    removedCustodyIds: z.array(Uuid).default([]),
    shift: Shift.nullish(),
    /** Workflow versions referenced by the tasks above that the client may not have cached. */
    workflows: z.array(WorkflowRef).default([]),
    nextCursor: z.string().nullable(),
    /** Use as `since` on the next pull. Server clock, not device clock. */
    syncedAt: Timestamp,
    /**
     * Set when the client's watermark is older than the retention window, so a
     * delta is impossible. The client wipes local state and bootstraps.
     */
    resyncRequired: z.boolean().default(false),
  })
  .openapi('SyncChanges');
export type SyncChanges = z.infer<typeof SyncChanges>;
