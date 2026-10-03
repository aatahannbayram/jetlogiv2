import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';

import { couriers, tenants, trainingCompletions, trainingModules } from '@dijigoo/db';
import type { Database } from '@dijigoo/db';
import { createDatabase } from '@dijigoo/db';
import { eq } from 'drizzle-orm';

import { completeTrainingModule, listTrainingModulesFor } from '../src/services/training.js';

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
    console.warn(`[training.test] Postgres at ${url} not reachable, skipping — run \`docker compose up -d postgres\` + \`pnpm --filter @dijigoo/db migrate\`.`);
    return;
  }
  try {
    await run(db);
  } finally {
    await (db as unknown as { $client: { end: () => Promise<void> } }).$client.end();
  }
}

test('listTrainingModulesFor + completeTrainingModule: real Postgres round trip', async () => {
  await withDatabase(async (db) => {
    const [tenant] = await db
      .insert(tenants)
      .values({ name: 'training.test tenant', slug: `training-test-${randomUUID()}` })
      .returning({ id: tenants.id });
    assert.ok(tenant);

    const [courier] = await db
      .insert(couriers)
      .values({
        tenantId: tenant!.id,
        phone: `+9053201${Math.floor(Math.random() * 90000 + 10000)}`,
        fullName: 'Training Test Kurye',
        employeeCode: `TRN-${randomUUID().slice(0, 8)}`,
        status: 'active',
      })
      .returning({ id: couriers.id });
    assert.ok(courier);

    const [moduleA, moduleB] = await db
      .insert(trainingModules)
      .values([
        { tenantId: tenant!.id, title: 'Trafik güvenliği', body: 'İçerik A', sortOrder: 1 },
        { tenantId: tenant!.id, title: 'KVKK', body: 'İçerik B', sortOrder: 2 },
      ])
      .returning({ id: trainingModules.id });
    assert.ok(moduleA);
    assert.ok(moduleB);

    const before = await listTrainingModulesFor(db, tenant!.id, courier!.id);
    assert.equal(before.length, 2);
    assert.equal(before[0]!.title, 'Trafik güvenliği');
    assert.equal(before.every((m) => !m.completed), true);

    await completeTrainingModule(db, courier!.id, moduleA!.id);

    const after = await listTrainingModulesFor(db, tenant!.id, courier!.id);
    const completedOne = after.find((m) => m.id === moduleA!.id);
    const stillOpen = after.find((m) => m.id === moduleB!.id);
    assert.equal(completedOne?.completed, true);
    assert.ok(completedOne?.completedAt);
    assert.equal(stillOpen?.completed, false);

    // İkinci "tamamla" çağrısı ikinci bir satır oluşturmaz.
    await completeTrainingModule(db, courier!.id, moduleA!.id);
    const rows = await db
      .select()
      .from(trainingCompletions)
      .where(eq(trainingCompletions.courierId, courier!.id));
    assert.equal(rows.length, 1);
  });
});
