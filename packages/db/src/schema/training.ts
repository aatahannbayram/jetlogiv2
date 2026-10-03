import { sql } from 'drizzle-orm';
import {
  boolean,
  index,
  pgTable,
  smallint,
  text,
  timestamp,
  uniqueIndex,
  uuid,
  varchar,
} from 'drizzle-orm/pg-core';

import { couriers, tenants } from './org';

/**
 * Eğitim modülü — toplantı maddesi 5 (madde 5: "Eğitim modülü eklenecek").
 * MVP kapsamı metin/checklist içerik; video/dış barındırma yok, `body`
 * düz metin (markdown-benzeri) olarak saklanıyor. `sortOrder` ile kurye
 * uygulamasındaki liste sırası yönetiliyor.
 */
export const trainingModules = pgTable(
  'training_modules',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    tenantId: uuid('tenant_id')
      .notNull()
      .references(() => tenants.id, { onDelete: 'restrict' }),
    title: varchar('title', { length: 200 }).notNull(),
    summary: varchar('summary', { length: 500 }),
    body: text('body').notNull(),
    sortOrder: smallint('sort_order').notNull().default(0),
    isActive: boolean('is_active').notNull().default(true),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => ({
    tenantOrderIdx: index('training_modules_tenant_order_idx')
      .on(t.tenantId, t.sortOrder)
      .where(sql`is_active`),
  }),
);

/** Bir kuryenin bir modülü tamamladığı an — modül başına en fazla bir satır. */
export const trainingCompletions = pgTable(
  'training_completions',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    courierId: uuid('courier_id')
      .notNull()
      .references(() => couriers.id, { onDelete: 'cascade' }),
    moduleId: uuid('module_id')
      .notNull()
      .references(() => trainingModules.id, { onDelete: 'cascade' }),
    completedAt: timestamp('completed_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => ({
    courierModuleUq: uniqueIndex('training_completions_courier_module_uq').on(
      t.courierId,
      t.moduleId,
    ),
    courierIdx: index('training_completions_courier_idx').on(t.courierId),
  }),
);
