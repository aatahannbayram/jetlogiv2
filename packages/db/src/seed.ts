/**
 * Local development data. Idempotent: safe to re-run against a database that
 * already has the fixture, so it can be part of `pnpm dev` without wiping the
 * work someone did by hand.
 */
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { eq, sql } from 'drizzle-orm';

import { createDatabase } from './index';
import { branches, couriers, taskItems, tasks, tenants, workflows } from './schema/index';

const url = process.env['DATABASE_URL'];
if (!url) {
  console.error('DATABASE_URL tanimli degil.');
  process.exit(1);
}

const packageRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const db = createDatabase({ url, max: 1 });

// The example lives with the contracts, which own the workflow schema.
const definition = JSON.parse(
  readFileSync(
    resolve(packageRoot, '../contracts/schemas/examples/standart-teslimat.v3.json'),
    'utf8',
  ),
) as {
  key: string;
  version: number;
  name: string;
  description: string | null;
  appliesTo: Record<string, unknown>;
  steps: unknown[];
  outcomes: unknown[];
  minAppBuild: number;
};

const [tenant] = await db
  .insert(tenants)
  .values({ name: 'Dijigoo Lojistik', slug: 'dijigoo' })
  .onConflictDoUpdate({ target: tenants.slug, set: { name: 'Dijigoo Lojistik' } })
  .returning();

const [branch] = await db
  .insert(branches)
  .values({
    tenantId: tenant!.id,
    code: 'IST-KADIKOY',
    name: 'Kadikoy Aktarma',
    city: 'Istanbul',
    location: { lat: 40.9903, lng: 29.0273 },
  })
  .onConflictDoUpdate({
    target: [branches.tenantId, branches.code],
    set: { name: 'Kadikoy Aktarma' },
  })
  .returning();

/**
 * The phone is what the OTP flow keys on. In development the mock SMS provider
 * prints the code to the API log, so no real number is involved.
 */
const [courier] = await db
  .insert(couriers)
  .values({
    tenantId: tenant!.id,
    branchId: branch!.id,
    phone: '+905321234567',
    fullName: 'Test Kurye',
    employeeCode: 'K-0001',
    status: 'active',
    capabilities: ['DELIVER', 'PICKUP', 'CASH_COLLECT', 'DOCUMENT_SCAN', 'CUSTODY_HANDOVER'],
    consents: {
      location: { grantedAt: new Date().toISOString(), version: '1.0' },
      shiftPhoto: null,
    },
  })
  .onConflictDoUpdate({
    target: [couriers.tenantId, couriers.phone],
    // The unique index is partial, so the predicate has to be repeated here or
    // Postgres cannot infer which index the conflict refers to.
    targetWhere: sql`deleted_at is null`,
    set: { fullName: 'Test Kurye', status: 'active' },
  })
  .returning();

const existingWorkflow = await db.query.workflows.findFirst({
  where: (w, { and, eq: equals }) =>
    and(equals(w.tenantId, tenant!.id), equals(w.key, definition.key), equals(w.version, definition.version)),
});

// A published workflow is immutable by trigger, so re-seeding must not try to
// update it: insert only when this exact version is absent.
const workflow =
  existingWorkflow ??
  (
    await db
      .insert(workflows)
      .values({
        tenantId: tenant!.id,
        key: definition.key,
        version: definition.version,
        name: definition.name,
        description: definition.description,
        status: 'published',
        appliesTo: definition.appliesTo,
        steps: definition.steps,
        outcomes: definition.outcomes,
        minAppBuild: definition.minAppBuild,
        publishedAt: new Date(),
      })
      .returning()
  )[0]!;

const fixtures = [
  {
    reference: 'DJ-2026-0001',
    addressLine1: 'Bagdat Caddesi No:120 D:4',
    district: 'Kadikoy',
    position: { lat: 40.9829, lng: 29.0575 },
    contactName: 'Ayse Yilmaz',
    codAmount: null,
    sequence: 1,
  },
  {
    reference: 'DJ-2026-0002',
    addressLine1: 'Halitaga Caddesi No:8',
    district: 'Kadikoy',
    position: { lat: 40.9915, lng: 29.0256 },
    contactName: 'Mehmet Demir',
    codAmount: '450.00',
    sequence: 2,
  },
  {
    reference: 'DJ-2026-0003',
    addressLine1: 'Cafearaga Mah. Sair Nefi Sk. No:3',
    district: 'Kadikoy',
    position: { lat: 40.9887, lng: 29.0281 },
    contactName: 'Zeynep Kaya',
    codAmount: null,
    sequence: 3,
  },
];

for (const fixture of fixtures) {
  const [task] = await db
    .insert(tasks)
    .values({
      tenantId: tenant!.id,
      branchId: branch!.id,
      courierId: courier!.id,
      reference: fixture.reference,
      type: 'DELIVERY',
      status: 'ASSIGNED',
      sequence: fixture.sequence,
      workflowId: workflow.id,
      workflowKey: workflow.key,
      workflowVersion: workflow.version,
      addressLine1: fixture.addressLine1,
      district: fixture.district,
      city: 'Istanbul',
      position: fixture.position,
      geocodeConfidence: 'exact',
      contactName: fixture.contactName,
      contactPhoneEncrypted: 'dev-placeholder',
      codAmount: fixture.codAmount,
      itemCount: 1,
      assignedAt: new Date(),
      attributes: { codAmount: fixture.codAmount ? Number(fixture.codAmount) : 0 },
    })
    .onConflictDoUpdate({
      target: [tasks.tenantId, tasks.reference],
      set: { courierId: courier!.id, status: 'ASSIGNED', sequence: fixture.sequence },
    })
    .returning();

  const items = await db.select().from(taskItems).where(eq(taskItems.taskId, task!.id)).limit(1);
  if (items.length === 0) {
    await db.insert(taskItems).values({
      taskId: task!.id,
      barcode: `BC${fixture.reference.replace(/\D/g, '')}`,
      description: 'Standart koli',
      quantity: 1,
      weightGrams: 1500,
    });
  }
}

console.log('Seed tamam.');
console.log(`  tenant   : ${tenant!.slug} (${tenant!.id})`);
console.log(`  kurye    : ${courier!.phone} (${courier!.id})`);
console.log(`  workflow : ${workflow.key} v${workflow.version}`);
console.log(`  gorev    : ${fixtures.length} adet`);

process.exit(0);
