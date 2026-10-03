import { Timestamp, Uuid, z } from './common.js';

/**
 * Panel backend → this API. Moves a task onto a courier and (on change)
 * writes TASK_ASSIGNED / TASK_PULLED inbox rows. Same service token as
 * delay-decision — there is no operator identity in this codebase.
 */
export const TaskAssignRequest = z.object({
  courierId: Uuid,
  reason: z.string().max(160).optional(),
  operatorId: Uuid.optional(),
});
export type TaskAssignRequest = z.infer<typeof TaskAssignRequest>;

export const TaskAssignResponse = z.object({
  taskId: Uuid,
  courierId: Uuid,
  previousCourierId: Uuid.nullable(),
  alreadyAssigned: z.boolean(),
  appliedAt: Timestamp,
});
export type TaskAssignResponse = z.infer<typeof TaskAssignResponse>;
