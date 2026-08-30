import { Timestamp, Uuid, z } from './common.js';

/**
 * Canonical İş Emri (WO) codes. Permanent — see `packages/db/src/schema/enums.ts`
 * for the source comment mapping each code to its Turkish label
 * (DIJIGOO_NIHAI_BACKEND_SISTEM_MIMARISI_V2.docx §37, sheet "03 İŞ EMRİ").
 */
export const WorkOrderStatusCode = z.enum([
  'WO-010',
  'WO-020',
  'WO-030',
  'WO-040',
  'WO-050',
  'WO-060',
  'WO-070',
  'WO-080',
  'WO-090',
  'WO-100',
  'WO-110',
  'WO-120',
  'WO-130',
  'WO-140',
]);
export type WorkOrderStatusCode = z.infer<typeof WorkOrderStatusCode>;

/** Canonical Teslimat Sonucu (DLV) codes — sheet "05 TESLİMAT SONUCU". */
export const DeliveryResultCode = z.enum([
  'DLV-010',
  'DLV-020',
  'DLV-030',
  'DLV-040',
  'DLV-050',
  'DLV-060',
  'DLV-070',
  'DLV-080',
  'DLV-090',
  'DLV-100',
  'DLV-110',
  'DLV-120',
  'DLV-130',
  'DLV-140',
  'DLV-150',
  'DLV-160',
  'DLV-170',
  'DLV-180',
  'DLV-190',
  'DLV-200',
  'DLV-210',
  'DLV-220',
]);
export type DeliveryResultCode = z.infer<typeof DeliveryResultCode>;

export const WorkOrder = z
  .object({
    id: Uuid,
    reference: z.string().max(60),
    externalId: z.string().max(120).nullish(),
    status: WorkOrderStatusCode,
    createdAt: Timestamp,
    updatedAt: Timestamp,
  })
  .openapi('WorkOrder');
export type WorkOrder = z.infer<typeof WorkOrder>;

export const DeliveryResult = z
  .object({
    id: Uuid,
    taskId: Uuid,
    workOrderId: Uuid.nullish(),
    attemptNumber: z.number().int().positive(),
    code: DeliveryResultCode,
    /** The workflow's free-form outcome code this canonical result was derived from. */
    sourceOutcomeCode: z.string().max(60).nullish(),
    note: z.string().nullish(),
    occurredAt: Timestamp,
  })
  .openapi('DeliveryResult');
export type DeliveryResult = z.infer<typeof DeliveryResult>;
