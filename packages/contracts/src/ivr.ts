import { Timestamp, z } from './common.js';
import { TaskStatus } from './task.js';

export const IvrShipmentKind = z.enum(['expedite', 'support']);

const IvrShipmentFields = z.object({
  reference: z.string().max(60),
  company: z.string().max(160).nullable(),
  status: TaskStatus,
  custodyAt: Timestamp.nullable(),
  /**
   * T02: sesli asistan saati ancak true iken soyler. false iken slotEndAt
   * operasyon penceresi olabilir, musteri taahhudu degildir.
   */
  etaConfirmed: z.boolean(),
  slotEndAt: Timestamp.nullable(),
  deliveredAt: Timestamp.nullable(),
  courierName: z.string().max(160).nullable(),
  agencyName: z.string().max(160).nullable(),
});

export const IvrShipmentSummary = IvrShipmentFields.strict().openapi('IvrShipmentSummary');

export const IvrShipmentListResponse = z
  .object({
    shipments: z.array(IvrShipmentSummary),
  })
  .openapi('IvrShipmentListResponse');

export const IvrShipmentDetail = IvrShipmentFields.extend({
  /** Solveline token'ina; kurye MSISDN bu semada yok (T04). */
  customerPhone: z.string().max(20).nullable(),
})
  .strict()
  .openapi('IvrShipmentDetail');

export const IvrResultSelection = z.enum([
  'confirm',
  'reschedule',
  'cancel',
  'no_input',
  'invalid',
]);

export const IvrResultRequest = z
  .object({
    uniqueId: z.string().min(1).max(160),
    variable: z.string().max(500).optional(),
    selection: IvrResultSelection,
    dtmf: z.string().max(16).optional(),
    calledAt: Timestamp.optional(),
  })
  .openapi('IvrResultRequest');

export const IvrResultResponse = z
  .object({
    uniqueId: z.string().max(160),
    selection: IvrResultSelection,
    duplicate: z.boolean(),
  })
  .openapi('IvrResultResponse');

export const IvrTicketCreateRequest = z
  .object({
    kind: IvrShipmentKind,
    note: z.string().max(2000).optional(),
  })
  .openapi('IvrTicketCreateRequest');

export const IvrTicketCreateResponse = z
  .object({
    ticketReference: z.string().max(40),
    status: z.enum(['open', 'in_progress', 'resolved', 'closed']),
  })
  .openapi('IvrTicketCreateResponse');
