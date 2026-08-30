import { Timestamp, Uuid, z } from './common.js';

/**
 * Canonical Evrak/Arşiv (DOC) codes. Permanent — see
 * `packages/db/src/schema/enums.ts` for the Turkish label mapped to each and
 * which segments this codebase actually wires (DOC-070/080 only, Faz 3).
 */
export const DocumentStatusCode = z.enum([
  'DOC-010',
  'DOC-020',
  'DOC-030',
  'DOC-040',
  'DOC-050',
  'DOC-060',
  'DOC-070',
  'DOC-080',
  'DOC-090',
  'DOC-100',
  'DOC-110',
  'DOC-120',
  'DOC-130',
  'DOC-140',
  'DOC-150',
  'DOC-160',
  'DOC-170',
  'DOC-180',
  'DOC-190',
  'DOC-200',
  'DOC-210',
  'DOC-220',
]);
export type DocumentStatusCode = z.infer<typeof DocumentStatusCode>;

/** Canonical Kalite/Kontrol (QUA) codes. Only the "Otomatik" path is wired — see enums.ts. */
export const QualityReviewStatusCode = z.enum([
  'QUA-010',
  'QUA-020',
  'QUA-030',
  'QUA-040',
  'QUA-050',
  'QUA-060',
  'QUA-070',
  'QUA-080',
  'QUA-090',
  'QUA-100',
]);
export type QualityReviewStatusCode = z.infer<typeof QualityReviewStatusCode>;

export const Document = z
  .object({
    id: Uuid,
    taskId: Uuid,
    sourceStepKey: z.string().max(60),
    mediaId: Uuid.nullish(),
    status: DocumentStatusCode,
    createdAt: Timestamp,
  })
  .openapi('Document');
export type Document = z.infer<typeof Document>;

export const QualityReview = z
  .object({
    id: Uuid,
    subjectType: z.string().max(20),
    subjectId: Uuid,
    status: QualityReviewStatusCode,
    reason: z.string().max(160).nullish(),
    occurredAt: Timestamp,
  })
  .openapi('QualityReview');
export type QualityReview = z.infer<typeof QualityReview>;
