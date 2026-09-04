import { Timestamp, Uuid, z } from './common.js';

/**
 * Faz 5: called by the operations panel's backend, not the mobile app — a
 * task flagged `sla.at_risk` needs a human decision this API's courier-only
 * auth cannot make on its own. Authenticated with a shared service token,
 * not a courier bearer token (see apps/api/src/plugins/service-auth.ts).
 */
export const DelayDecisionRequest = z.object({
  decision: z.enum(['cancel', 'extend']),
  /** Required when decision is "extend"; ignored otherwise. */
  newSlaTargetAt: Timestamp.optional(),
  /** Stored in `task_transitions.reason` (varchar(160)). */
  reason: z.string().max(160).optional(),
  /**
   * Id of the operator who made the call, if the caller has one — must be a
   * uuid, since it is stored in the same `actor_id` column a courier's id
   * goes into. Omit rather than send a non-uuid identifier.
   */
  operatorId: Uuid.optional(),
});
export type DelayDecisionRequest = z.infer<typeof DelayDecisionRequest>;

export const DelayDecisionResponse = z.object({
  taskId: Uuid,
  decision: z.enum(['cancel', 'extend']),
  appliedAt: Timestamp,
});
export type DelayDecisionResponse = z.infer<typeof DelayDecisionResponse>;
