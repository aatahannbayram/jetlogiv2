import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';

import { couriers, custodyItemTransitions, custodyItems, outboxEvents, tenants } from '@dijigoo/db';
import type { Database } from '@dijigoo/db';
import { createDatabase } from '@dijigoo/db';
import { eq } from 'drizzle-orm';

import { productStatusForHandover, transitionCustodyItem } from '../src/services/custody-status.js';

test('productStatusForHandover: handover to customer is a real delivery (PRD-120)', () => {
  assert.equal(productStatusForHandover('handover', 'customer'), 'PRD-120');
});

test('productStatusForHandover: handover to branch/warehouse returns it to the operation point (PRD-130)', () => {
  assert.equal(productStatusForHandover('handover', 'branch'), 'PRD-130');
  assert.equal(productStatusForHandover('handover', 'warehouse'), 'PRD-130');
});

test('productStatusForHandover: courier-to-courier handover is not a PRD status change', () => {
  assert.equal(productStatusForHandover('handover', 'courier'), null);
});

test('productStatusForHandover: takeover from branch/warehouse means the courier now holds it (PRD-100)', () => {
  assert.equal(productStatusForHandover('takeover', 'branch'), 'PRD-100');
  assert.equal(productStatusForHandover('takeover', 'warehouse'), 'PRD-100');
  assert.equal(productStatusForHandover('takeover', 'courier'), 'PRD-100');
});

test('productStatusForHandover: takeover from a customer reads as a receipt (PRD-020)', () => {
  assert.equal(productStatusForHandover('takeover', 'customer'), 'PRD-020');
});

async function withDatabase(run: (db: Database) => Promise<void>) {
  const url = process.env['DATABASE_URL'] ?? 'postgres://dijigoo:dijigoo@127.0.0.1:5434/dijigoo';
  const db = createDatabase({ url, max: 1 });
  const reachable = await db
    .select({ id: tenants.id })
    .from(tenants)
    .limit(1)
    .then(() => true)
    .catch(() => false);
  if (!reachable) {
    console.warn(`[custody-status.test] Postgres at ${url} not reachable, skipping — run \`docker compose up -d postgres\` + \`pnpm --filter @dijigoo/db migrate\`.`);
    return;
  }
  try {
    await run(db);
  } finally {
    await (db as unknown as { $client: { end: () => Promise<void> } }).$client.end();
  }
}

test('transitionCustodyItem: real Postgres round trip — status, audit row, and outbox event', async () => {
  await withDatabase(async (db) => {
    const [tenant] = await db
      .insert(tenants)
      .values({ name: 'custody-status.test tenant', slug: `custody-test-${randomUUID()}` })
      .returning({ id: tenants.id });
    assert.ok(tenant);

    const [courier] = await db
      .insert(couriers)
      .values({
        tenantId: tenant!.id,
        phone: `+9053200${Math.floor(Math.random() * 90000 + 10000)}`,
        fullName: 'Custody Status Test Kurye',
        employeeCode: `CST-${randomUUID().slice(0, 8)}`,
        status: 'active',
      })
      .returning({ id: couriers.id });
    assert.ok(courier);

    const [item] = await db
      .insert(custodyItems)
      .values({
        tenantId: tenant!.id,
        holderCourierId: courier!.id,
        type: 'parcel',
        description: 'custody-status.test parcel',
      })
      .returning();
    assert.ok(item);
    assert.equal(item!.status, 'PRD-100', 'new items default to Kuryeye Zimmet');

    const occurredAt = new Date();
    await transitionCustodyItem(
      db,
      { tenantId: tenant!.id, correlationId: randomUUID() },
      item!.id,
      item!.status,
      'PRD-180',
      'custody.damaged',
      occurredAt,
    );

    const [updated] = await db.select().from(custodyItems).where(eq(custodyItems.id, item!.id)).limit(1);
    assert.equal(updated!.status, 'PRD-180');

    const [transition] = await db
      .select()
      .from(custodyItemTransitions)
      .where(eq(custodyItemTransitions.itemId, item!.id))
      .limit(1);
    assert.equal(transition!.fromStatus, 'PRD-100');
    assert.equal(transition!.toStatus, 'PRD-180');

    const [event] = await db
      .select()
      .from(outboxEvents)
      .where(eq(outboxEvents.subjectId, item!.id))
      .limit(1);
    assert.ok(event, 'expected a custody event to reach the outbox');

    // Same-status transition is a no-op: no second audit row.
    await transitionCustodyItem(
      db,
      { tenantId: tenant!.id, correlationId: randomUUID() },
      item!.id,
      'PRD-180',
      'PRD-180',
      'custody.damaged',
      occurredAt,
    );
    const allTransitions = await db
      .select()
      .from(custodyItemTransitions)
      .where(eq(custodyItemTransitions.itemId, item!.id));
    assert.equal(allTransitions.length, 1);
  });
});
