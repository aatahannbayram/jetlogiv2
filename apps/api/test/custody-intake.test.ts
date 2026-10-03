import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';

import { custodyItems, outboxEvents, tenants } from '@dijigoo/db';
import type { Database } from '@dijigoo/db';
import { createDatabase } from '@dijigoo/db';
import { eq } from 'drizzle-orm';

import { intakeCustodyItem } from '../src/services/custody-status.js';

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
    console.warn(`[custody-intake.test] Postgres at ${url} not reachable, skipping — run \`docker compose up -d postgres\` + \`pnpm --filter @dijigoo/db migrate\`.`);
    return;
  }
  try {
    await run(db);
  } finally {
    await (db as unknown as { $client: { end: () => Promise<void> } }).$client.end();
  }
}

test('intakeCustodyItem: creates an unheld PRD-010 row and emits custody.item_intake', async () => {
  await withDatabase(async (db) => {
    const [tenant] = await db
      .insert(tenants)
      .values({ name: 'custody-intake.test tenant', slug: `custody-intake-${randomUUID()}` })
      .returning({ id: tenants.id });
    assert.ok(tenant);

    const barcode = `INTAKE-${randomUUID().slice(0, 8)}`;
    const occurredAt = new Date();
    const clientEventId = randomUUID();

    const result = await db.transaction((tx) =>
      intakeCustodyItem(
        tx,
        { tenantId: tenant!.id, correlationId: clientEventId },
        {
          barcode,
          type: 'parcel',
          description: 'custody-intake.test parcel',
          quantity: 1,
          amount: null,
          taskId: null,
          occurredAt,
        },
      ),
    );

    assert.equal(result.created, true);
    assert.equal(result.item.status, 'PRD-010', 'a fresh intake starts at Urun Bekleniyor');
    assert.equal(result.item.holderCourierId, null, 'nobody holds it yet — that is takeover\'s job');
    assert.equal(result.item.releasedAt, null);

    const [event] = await db
      .select()
      .from(outboxEvents)
      .where(eq(outboxEvents.subjectId, result.item.id))
      .limit(1);
    assert.ok(event, 'expected a custody.item_intake event in the outbox');
    assert.equal(event!.key, 'custody.item_intake');
  });
});

test('intakeCustodyItem: re-scanning the same barcode is idempotent, not a duplicate row', async () => {
  await withDatabase(async (db) => {
    const [tenant] = await db
      .insert(tenants)
      .values({ name: 'custody-intake.test tenant', slug: `custody-intake-${randomUUID()}` })
      .returning({ id: tenants.id });
    assert.ok(tenant);

    const barcode = `INTAKE-${randomUUID().slice(0, 8)}`;
    const occurredAt = new Date();

    const params = {
      barcode,
      type: 'parcel' as const,
      description: 'custody-intake.test parcel',
      quantity: 1,
      amount: null,
      taskId: null,
      occurredAt,
    };

    const first = await db.transaction((tx) =>
      intakeCustodyItem(tx, { tenantId: tenant!.id, correlationId: randomUUID() }, params),
    );
    const second = await db.transaction((tx) =>
      intakeCustodyItem(tx, { tenantId: tenant!.id, correlationId: randomUUID() }, params),
    );

    assert.equal(first.created, true);
    assert.equal(second.created, false);
    assert.equal(second.item.id, first.item.id);

    const rows = await db.select().from(custodyItems).where(eq(custodyItems.barcode, barcode));
    assert.equal(rows.length, 1, 'the second scan must not insert a second row');
  });
});
