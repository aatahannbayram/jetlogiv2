import { jsonb, pgTable, timestamp, uniqueIndex, uuid, varchar } from 'drizzle-orm/pg-core';

/**
 * Solveline DYNAMIC IVR DTMF / secim sonucu. uniqueId Asterisk id'si;
 * ayni POST iki kez gelirse yeni satir acilmaz.
 */
export const ivrResults = pgTable(
  'ivr_results',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    uniqueId: varchar('unique_id', { length: 160 }).notNull(),
    variable: varchar('variable', { length: 500 }),
    selection: varchar('selection', { length: 40 }).notNull(),
    dtmf: varchar('dtmf', { length: 16 }),
    calledAt: timestamp('called_at', { withTimezone: true }),
    payload: jsonb('payload').$type<Record<string, unknown>>().notNull().default({}),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => ({
    uniqueIdUq: uniqueIndex('ivr_results_unique_id_uq').on(t.uniqueId),
  }),
);
