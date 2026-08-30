import { Timestamp, Uuid, z } from './common.js';

/**
 * Canonical İade/Ters Lojistik (RET) codes. Permanent — see
 * `packages/db/src/schema/enums.ts` for which segments Faz 4 wires.
 */
export const ReturnStatusCode = z.enum([
  'RET-010',
  'RET-020',
  'RET-030',
  'RET-040',
  'RET-050',
  'RET-060',
  'RET-070',
  'RET-080',
  'RET-090',
  'RET-100',
  'RET-110',
]);
export type ReturnStatusCode = z.infer<typeof ReturnStatusCode>;

/** Canonical SLA/İstisna codes. Only SLA-010/050/060 are ever written — see enums.ts. */
export const SlaStatusCode = z.enum([
  'SLA-010',
  'SLA-020',
  'SLA-030',
  'SLA-040',
  'SLA-050',
  'SLA-060',
  'SLA-070',
  'SLA-080',
  'SLA-090',
  'SLA-100',
]);
export type SlaStatusCode = z.infer<typeof SlaStatusCode>;

export const ReturnRecord = z
  .object({
    id: Uuid,
    taskId: Uuid,
    custodyItemId: Uuid,
    status: ReturnStatusCode,
    reason: z.string().max(160).nullish(),
    createdAt: Timestamp,
  })
  .openapi('ReturnRecord');
export type ReturnRecord = z.infer<typeof ReturnRecord>;

export const SlaInstance = z
  .object({
    id: Uuid,
    subjectType: z.string().max(20),
    subjectId: Uuid,
    targetAt: Timestamp,
    status: SlaStatusCode,
    startedAt: Timestamp,
    resolvedAt: Timestamp.nullish(),
  })
  .openapi('SlaInstance');
export type SlaInstance = z.infer<typeof SlaInstance>;
