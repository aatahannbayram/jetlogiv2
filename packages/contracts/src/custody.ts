import { CursorPageQuery, GeoPoint, RowVersion, Timestamp, Uuid, cursorPage, z } from './common.js';
import { MediaRef } from './media.js';

/* ------------------------------------------------------------------ *
 * Zimmet / custody
 * ------------------------------------------------------------------ */

export const CustodyItemType = z.enum(['parcel', 'document', 'cash', 'equipment']);

/**
 * Canonical Ürün/Stok/Zimmet (PRD) codes — permanent, see
 * `packages/db/src/schema/enums.ts` for the Turkish label mapped to each.
 * PRD-010..070 (depot intake) and PRD-200/210 (tazmin mutabakatı) are in the
 * catalog but have no producer/resolver in this codebase yet — see the
 * comment on `custodyItems.status` in the db schema.
 */
export const ProductStatusCode = z.enum([
  'PRD-010',
  'PRD-020',
  'PRD-030',
  'PRD-040',
  'PRD-050',
  'PRD-060',
  'PRD-070',
  'PRD-080',
  'PRD-090',
  'PRD-100',
  'PRD-110',
  'PRD-120',
  'PRD-130',
  'PRD-140',
  'PRD-150',
  'PRD-160',
  'PRD-170',
  'PRD-180',
  'PRD-190',
  'PRD-200',
  'PRD-210',
]);
export type ProductStatusCode = z.infer<typeof ProductStatusCode>;

export const CustodyItem = z
  .object({
    id: Uuid,
    type: CustodyItemType,
    barcode: z.string().max(80).nullish(),
    description: z.string().max(300),
    quantity: z.number().int().positive().default(1),
    amount: z.number().nonnegative().nullish().describe('type=cash icin TRY'),
    taskId: Uuid.nullish(),
    status: ProductStatusCode,
    acquiredAt: Timestamp,
    rowVersion: RowVersion,
  })
  .openapi('CustodyItem');

export const CustodyListQuery = CursorPageQuery.extend({
  type: z.array(CustodyItemType).nullish(),
});

export const CustodyListResponse = cursorPage(CustodyItem, 'CustodyListResponse');

/**
 * A handover moves items between two accountable parties. Both directions use
 * the same shape; `direction` says whether the courier is giving or receiving.
 */
export const CustodyHandoverRequest = z
  .object({
    clientEventId: Uuid,
    occurredAt: Timestamp,
    location: GeoPoint.nullish(),
    direction: z.enum(['handover', 'takeover']),
    counterparty: z.object({
      kind: z.enum(['courier', 'branch', 'customer', 'warehouse']),
      id: Uuid.nullish(),
      name: z.string().max(160),
    }),
    itemIds: z.array(Uuid).min(1),
    signatureMediaId: Uuid.nullish(),
    photoMediaIds: z.array(Uuid).default([]),
    note: z.string().max(1000).nullish(),
  })
  .openapi('CustodyHandoverRequest');

export const CustodyHandoverResponse = z
  .object({
    handoverId: Uuid,
    remaining: z.array(CustodyItem),
    receipt: MediaRef.nullish().describe('Sunucu tarafinda uretilen zimmet tutanagi PDF'),
    appliedAt: Timestamp,
  })
  .openapi('CustodyHandoverResponse');

/**
 * A courier reporting damage or loss on an item they currently hold —
 * PRD-180/190. Compensation resolution (PRD-200/210, Tazmin Sürecinde/
 * Kapandı) is financial follow-up outside this codebase's scope; this only
 * records the report.
 */
export const CustodyIssueReportRequest = z
  .object({
    clientEventId: Uuid,
    occurredAt: Timestamp,
    location: GeoPoint.nullish(),
    kind: z.enum(['damaged', 'lost']),
    note: z.string().max(1000).nullish(),
    photoMediaIds: z.array(Uuid).default([]),
  })
  .openapi('CustodyIssueReportRequest');

export const CustodyIssueReportResponse = z
  .object({
    item: CustodyItem,
    appliedAt: Timestamp,
  })
  .openapi('CustodyIssueReportResponse');

/* ------------------------------------------------------------------ *
 * Support
 * ------------------------------------------------------------------ */

export const SupportCategory = z.enum([
  'APP_ISSUE',
  'ADDRESS_PROBLEM',
  'RECIPIENT_UNREACHABLE',
  'VEHICLE',
  'ACCIDENT',
  'SECURITY',
  'PAYMENT',
  'OTHER',
]);

export const SupportTicket = z
  .object({
    id: Uuid,
    reference: z.string().max(40),
    category: SupportCategory,
    subject: z.string().max(160),
    body: z.string().max(4000),
    status: z.enum(['open', 'in_progress', 'resolved', 'closed']),
    priority: z.enum(['low', 'normal', 'high', 'critical']),
    taskId: Uuid.nullish(),
    media: z.array(MediaRef).default([]),
    createdAt: Timestamp,
    updatedAt: Timestamp,
  })
  .openapi('SupportTicket');

export const SupportTicketCreateRequest = z
  .object({
    clientEventId: Uuid,
    category: SupportCategory,
    subject: z.string().min(1).max(160),
    body: z.string().min(1).max(4000),
    taskId: Uuid.nullish(),
    mediaIds: z.array(Uuid).default([]),
    location: GeoPoint.nullish(),
    /**
     * Attaches the last N lines of the on-device log. Opt-in, because the log
     * can contain addresses and phone numbers.
     */
    attachDiagnostics: z.boolean().default(false),
  })
  .openapi('SupportTicketCreateRequest');

export const SupportTicketListResponse = cursorPage(SupportTicket, 'SupportTicketListResponse');
