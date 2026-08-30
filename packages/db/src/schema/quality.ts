import { index, pgTable, timestamp, uuid, varchar } from 'drizzle-orm/pg-core';

import { qualityReviewStatusCode } from './enums';
import { tenants } from './org';

/**
 * Kalite/Kontrol (QUA) — deliberately generic over `subjectType`/`subjectId`
 * rather than a `delivery_result_id` FK: this codebase only ever writes the
 * "Otomatik" resolution today (see the comment on `qualityReviewStatusCode`
 * in enums.ts), so there is exactly one row per reviewed subject and no
 * intermediate states worth a transitions table — the automatic check
 * happens synchronously, so `status` is written already-resolved.
 */
export const qualityReviews = pgTable(
  'quality_reviews',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    tenantId: uuid('tenant_id')
      .notNull()
      .references(() => tenants.id, { onDelete: 'restrict' }),
    subjectType: varchar('subject_type', { length: 20 }).notNull(),
    subjectId: uuid('subject_id').notNull(),
    status: qualityReviewStatusCode('status').notNull(),
    reason: varchar('reason', { length: 160 }),
    occurredAt: timestamp('occurred_at', { withTimezone: true }).notNull(),
    recordedAt: timestamp('recorded_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => ({
    subjectIdx: index('quality_reviews_subject_idx').on(t.subjectType, t.subjectId),
  }),
);
