import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';

import { couriers, createDatabase, outboxEvents, slaInstances, tenants } from '@dijigoo/db';
import type { Database } from '@dijigoo/db';
import { and, eq } from 'drizzle-orm';

import { flagAtRiskSlaInstances } from '../src/sla-watcher.js';

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
    console.warn(`[sla-watcher.test] Postgres at ${url} not reachable, skipping — run \`docker compose up -d postgres\` + \`pnpm --filter @dijigoo/db migrate\`.`);
    return;
  }
  try {
    await run(db);
  } finally {
    await (db as unknown as { $client: { end: () => Promise<void> } }).$client.end();
  }
}

async function seedSlaInstance(db: Database, targetAt: Date) {
  const [tenant] = await db
    .insert(tenants)
    .values({ name: 'sla-watcher.test tenant', slug: `sla-watch-test-${randomUUID()}` })
    .returning({ id: tenants.id });
  await db.insert(couriers).values({
    tenantId: tenant!.id,
    phone: `+9053203${Math.floor(Math.random() * 90000 + 10000)}`,
    fullName: 'SLA Watcher Test Kurye',
    employeeCode: `SW-${randomUUID().slice(0, 8)}`,
  });

  const subjectId = randomUUID();
  const [instance] = await db
    .insert(slaInstances)
    .values({ tenantId: tenant!.id, subjectType: 'task', subjectId, targetAt, startedAt: new Date() })
    .returning();
  return { tenantId: tenant!.id, subjectId, instance: instance! };
}

test('flagAtRiskSlaInstances: flags a target inside the risk window, leaves a distant one alone', async () => {
  await withDatabase(async (db) => {
    const now = new Date('2026-09-03T12:00:00Z');

    const soon = await seedSlaInstance(db, new Date('2026-09-03T12:20:00Z'));
    const later = await seedSlaInstance(db, new Date('2026-09-03T18:00:00Z'));

    const flagged = await flagAtRiskSlaInstances(db, { riskWindowMinutes: 30, now });

    assert.ok(flagged.some((f) => f.subjectId === soon.subjectId));
    assert.ok(!flagged.some((f) => f.subjectId === later.subjectId));

    const [soonRow] = await db.select().from(slaInstances).where(eq(slaInstances.id, soon.instance.id)).limit(1);
    assert.equal(soonRow!.status, 'SLA-030');
    const [laterRow] = await db.select().from(slaInstances).where(eq(slaInstances.id, later.instance.id)).limit(1);
    assert.equal(laterRow!.status, 'SLA-010');

    const [event] = await db
      .select()
      .from(outboxEvents)
      .where(and(eq(outboxEvents.subjectId, soonRow!.id), eq(outboxEvents.key, 'sla.at_risk')))
      .limit(1);
    assert.ok(event, 'expected an sla.at_risk event in the outbox');
    assert.equal(event!.state, 'pending', 'must be pickable up by whatever relays the outbox next');

    // Idempotent: a second tick must not re-flag (already SLA-030, not SLA-010).
    const secondPass = await flagAtRiskSlaInstances(db, { riskWindowMinutes: 30, now });
    assert.ok(!secondPass.some((f) => f.subjectId === soon.subjectId));
  });
});

test('flagAtRiskSlaInstances: an already-resolved instance is never re-flagged', async () => {
  await withDatabase(async (db) => {
    const now = new Date('2026-09-03T12:00:00Z');
    const { instance } = await seedSlaInstance(db, new Date('2026-09-03T12:10:00Z'));

    await db
      .update(slaInstances)
      .set({ status: 'SLA-050', resolvedAt: now })
      .where(eq(slaInstances.id, instance.id));

    const flagged = await flagAtRiskSlaInstances(db, { riskWindowMinutes: 30, now });
    assert.ok(!flagged.some((f) => f.subjectId === instance.subjectId));

    const [row] = await db.select().from(slaInstances).where(eq(slaInstances.id, instance.id)).limit(1);
    assert.equal(row!.status, 'SLA-050', 'a resolved instance must stay resolved, not flip back to at-risk');
  });
});
