import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';

import { insertCourierNotification } from '@dijigoo/core';
import { couriers, createDatabase, notifications, tenants } from '@dijigoo/db';
import type { Database } from '@dijigoo/db';
import { eq } from 'drizzle-orm';

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
    console.warn(
      `[notify.test] Postgres at ${url} not reachable, skipping — run \`docker compose up -d postgres\` + \`pnpm --filter @dijigoo/db migrate\`.`,
    );
    return;
  }
  try {
    await run(db);
  } finally {
    await (db as unknown as { $client: { end: () => Promise<void> } }).$client.end();
  }
}

test('ayni collapseKey okunmamissa ikinci yazim satiri ezmez', async () => {
  await withDatabase(async (db) => {
    const [tenant] = await db
      .insert(tenants)
      .values({ name: 'notify.test tenant', slug: `notify-test-${randomUUID()}` })
      .returning({ id: tenants.id });
    const [courier] = await db
      .insert(couriers)
      .values({
        tenantId: tenant!.id,
        phone: `+9053204${Math.floor(Math.random() * 90000 + 10000)}`,
        fullName: 'Notify Test Kurye',
        employeeCode: `NT-${randomUUID().slice(0, 8)}`,
      })
      .returning({ id: couriers.id });

    const first = await insertCourierNotification(db, {
      courierId: courier!.id,
      kind: 'TASK_CANCELLED',
      title: 'Durak iptal',
      body: 'ilk',
      collapseKey: `task-cancel:${randomUUID()}`,
    });
    const second = await insertCourierNotification(db, {
      courierId: courier!.id,
      kind: 'TASK_CANCELLED',
      title: 'Durak iptal',
      body: 'guncel',
      collapseKey: first.collapseKey,
    });
    assert.equal(second.id, first.id);
    assert.equal(second.body, 'guncel');

    const rows = await db.select().from(notifications).where(eq(notifications.courierId, courier!.id));
    assert.equal(rows.length, 1);
  });
});
