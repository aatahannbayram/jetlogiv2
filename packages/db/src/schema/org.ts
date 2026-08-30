import { relations, sql } from 'drizzle-orm';
import {
  boolean,
  index,
  jsonb,
  pgTable,
  text,
  timestamp,
  uniqueIndex,
  uuid,
  varchar,
} from 'drizzle-orm/pg-core';

import { courierStatus } from './enums';
import { geoPoint } from './types';

export const tenants = pgTable('tenants', {
  id: uuid('id').primaryKey().defaultRandom(),
  name: varchar('name', { length: 160 }).notNull(),
  slug: varchar('slug', { length: 60 }).notNull().unique(),
  /** Per-tenant feature flags and operational limits. */
  settings: jsonb('settings').$type<Record<string, unknown>>().notNull().default({}),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export const branches = pgTable(
  'branches',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    tenantId: uuid('tenant_id')
      .notNull()
      .references(() => tenants.id, { onDelete: 'restrict' }),
    code: varchar('code', { length: 40 }).notNull(),
    name: varchar('name', { length: 160 }).notNull(),
    city: varchar('city', { length: 120 }).notNull(),
    location: geoPoint('location'),
    /** Fence used to auto-detect arrival at the branch for custody handover. */
    fenceRadiusMeters: varchar('fence_radius_meters', { length: 10 }).default('300'),
    isActive: boolean('is_active').notNull().default(true),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => ({
    tenantCode: uniqueIndex('branches_tenant_code_uq').on(t.tenantId, t.code),
    locationIdx: index('branches_location_idx').using('gist', t.location),
  }),
);

export const couriers = pgTable(
  'couriers',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    tenantId: uuid('tenant_id')
      .notNull()
      .references(() => tenants.id, { onDelete: 'restrict' }),
    branchId: uuid('branch_id').references(() => branches.id, { onDelete: 'set null' }),
    /** E.164. The natural login identifier, unique per tenant. */
    phone: varchar('phone', { length: 20 }).notNull(),
    fullName: varchar('full_name', { length: 160 }).notNull(),
    employeeCode: varchar('employee_code', { length: 40 }),
    nationalIdHash: varchar('national_id_hash', { length: 64 }),
    avatarMediaId: uuid('avatar_media_id'),
    status: courierStatus('status').notNull().default('active'),
    capabilities: jsonb('capabilities').$type<string[]>().notNull().default([]),
    /**
     * KVKK consent state. Nullable until the courier accepts; a null here
     * blocks shift start for the flows that need special-category data.
     */
    consents: jsonb('consents')
      .$type<Record<string, { grantedAt: string; version: string } | null>>()
      .notNull()
      .default({}),
    suspendedReason: text('suspended_reason'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
    deletedAt: timestamp('deleted_at', { withTimezone: true }),
  },
  (t) => ({
    tenantPhone: uniqueIndex('couriers_tenant_phone_uq')
      .on(t.tenantId, t.phone)
      .where(sql`deleted_at is null`),
    branchIdx: index('couriers_branch_idx').on(t.branchId),
    statusIdx: index('couriers_status_idx').on(t.tenantId, t.status),
  }),
);

export const tenantRelations = relations(tenants, ({ many }) => ({
  branches: many(branches),
  couriers: many(couriers),
}));

export const branchRelations = relations(branches, ({ one, many }) => ({
  tenant: one(tenants, { fields: [branches.tenantId], references: [tenants.id] }),
  couriers: many(couriers),
}));

export const courierRelations = relations(couriers, ({ one }) => ({
  tenant: one(tenants, { fields: [couriers.tenantId], references: [tenants.id] }),
  branch: one(branches, { fields: [couriers.branchId], references: [branches.id] }),
}));
