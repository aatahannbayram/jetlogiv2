import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';

import {
  couriers,
  createDatabase,
  custodyItems,
  outboxEvents,
  returnTransitions,
  returns,
  slaInstances,
  tasks,
  tenants,
} from '@dijigoo/db';
import type { Database } from '@dijigoo/db';
import { eq } from 'drizzle-orm';

import { closeReturnOnBranchHandover, openReturnsForFailedTask } from '../src/services/return-status.js';
import { resolveSlaInstance, startSlaInstance } from '../src/services/sla.js';

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
    console.warn(`[return-sla.test] Postgres at ${url} not reachable, skipping — run \`docker compose up -d postgres\` + \`pnpm --filter @dijigoo/db migrate\`.`);
    return;
  }
  try {
    await run(db);
  } finally {
    await (db as unknown as { $client: { end: () => Promise<void> } }).$client.end();
  }
}

async function seedTenantAndCourier(db: Database) {
  const [tenant] = await db
    .insert(tenants)
    .values({ name: 'return-sla.test tenant', slug: `ret-sla-test-${randomUUID()}` })
    .returning({ id: tenants.id });
  const [courier] = await db
    .insert(couriers)
    .values({
      tenantId: tenant!.id,
      phone: `+9053201${Math.floor(Math.random() * 90000 + 10000)}`,
      fullName: 'Return/SLA Test Kurye',
      employeeCode: `RS-${randomUUID().slice(0, 8)}`,
    })
    .returning({ id: couriers.id });
  return { tenantId: tenant!.id, courierId: courier!.id };
}

test('openReturnsForFailedTask + closeReturnOnBranchHandover: full RET-010 → RET-070 round trip', async () => {
  await withDatabase(async (db) => {
    const { tenantId, courierId } = await seedTenantAndCourier(db);
    const [task] = await db
      .insert(tasks)
      .values({
        tenantId,
        courierId,
        reference: `RET-TEST-${randomUUID().slice(0, 8)}`,
        type: 'DELIVERY',
        addressLine1: 'return-sla.test address',
        city: 'Test',
      })
      .returning({ id: tasks.id });
    const taskId = task!.id;

    const [item] = await db
      .insert(custodyItems)
      .values({ tenantId, holderCourierId: courierId, taskId, type: 'parcel', description: 'return-sla.test parcel' })
      .returning({ id: custodyItems.id });
    assert.ok(item);

    const occurredAt = new Date();
    await openReturnsForFailedTask(
      db,
      { tenantId, correlationId: randomUUID(), courierId },
      { taskId, reason: 'RECIPIENT_ABSENT', occurredAt },
    );

    const [opened] = await db.select().from(returns).where(eq(returns.custodyItemId, item!.id)).limit(1);
    assert.equal(opened!.status, 'RET-010');
    assert.equal(opened!.taskId, taskId);

    // A second failed attempt on the same held item reuses the row, not a duplicate.
    await openReturnsForFailedTask(
      db,
      { tenantId, correlationId: randomUUID(), courierId },
      { taskId, reason: 'RECIPIENT_ABSENT', occurredAt },
    );
    const stillOne = await db.select().from(returns).where(eq(returns.custodyItemId, item!.id));
    assert.equal(stillOne.length, 1);

    // Courier hands it to a branch — the return actually completes.
    await closeReturnOnBranchHandover(db, { tenantId, correlationId: randomUUID() }, item!.id, occurredAt);

    const [closed] = await db.select().from(returns).where(eq(returns.custodyItemId, item!.id)).limit(1);
    assert.equal(closed!.status, 'RET-070');

    const [transition] = await db
      .select()
      .from(returnTransitions)
      .where(eq(returnTransitions.returnId, opened!.id))
      .limit(1);
    assert.equal(transition!.fromStatus, 'RET-010');
    assert.equal(transition!.toStatus, 'RET-070');

    const [event] = await db.select().from(outboxEvents).where(eq(outboxEvents.subjectId, opened!.id)).limit(1);
    assert.ok(event, 'expected return.transitioned to reach the outbox');
  });
});

test('openReturnsForFailedTask: a task with no held custody item opens no return', async () => {
  await withDatabase(async (db) => {
    const { tenantId, courierId } = await seedTenantAndCourier(db);
    const taskId = randomUUID();

    await openReturnsForFailedTask(
      db,
      { tenantId, correlationId: randomUUID(), courierId },
      { taskId, reason: 'ADDRESS_NOT_FOUND', occurredAt: new Date() },
    );

    const rows = await db.select().from(returns).where(eq(returns.taskId, taskId));
    assert.equal(rows.length, 0, 'a digital-only task must not fabricate a return record');
  });
});

test('startSlaInstance: no-op when the subject has no real deadline', async () => {
  await withDatabase(async (db) => {
    const { tenantId } = await seedTenantAndCourier(db);
    const subjectId = randomUUID();

    await startSlaInstance(
      db,
      { tenantId, correlationId: randomUUID() },
      { subjectType: 'task', subjectId, targetAt: null, startedAt: new Date() },
    );

    const rows = await db.select().from(slaInstances).where(eq(slaInstances.subjectId, subjectId));
    assert.equal(rows.length, 0, 'must not fabricate an SLA target that does not exist');
  });
});

test('startSlaInstance + resolveSlaInstance: met vs violated against the real target', async () => {
  await withDatabase(async (db) => {
    const { tenantId } = await seedTenantAndCourier(db);

    const startedAt = new Date('2026-08-28T09:00:00Z');
    const targetAt = new Date('2026-08-28T10:00:00Z');

    // Met: resolved before the target.
    const metSubjectId = randomUUID();
    await startSlaInstance(db, { tenantId, correlationId: randomUUID() }, { subjectType: 'task', subjectId: metSubjectId, targetAt, startedAt });
    await resolveSlaInstance(db, { tenantId, correlationId: randomUUID() }, { subjectType: 'task', subjectId: metSubjectId, resolvedAt: new Date('2026-08-28T09:45:00Z') });
    const [met] = await db.select().from(slaInstances).where(eq(slaInstances.subjectId, metSubjectId)).limit(1);
    assert.equal(met!.status, 'SLA-050');

    // Violated: resolved after the target.
    const violatedSubjectId = randomUUID();
    await startSlaInstance(db, { tenantId, correlationId: randomUUID() }, { subjectType: 'task', subjectId: violatedSubjectId, targetAt, startedAt });
    await resolveSlaInstance(db, { tenantId, correlationId: randomUUID() }, { subjectType: 'task', subjectId: violatedSubjectId, resolvedAt: new Date('2026-08-28T10:30:00Z') });
    const [violated] = await db.select().from(slaInstances).where(eq(slaInstances.subjectId, violatedSubjectId)).limit(1);
    assert.equal(violated!.status, 'SLA-060');

    // Idempotent start: calling it again after resolution must not reopen it.
    await startSlaInstance(db, { tenantId, correlationId: randomUUID() }, { subjectType: 'task', subjectId: metSubjectId, targetAt, startedAt });
    const [stillMet] = await db.select().from(slaInstances).where(eq(slaInstances.subjectId, metSubjectId)).limit(1);
    assert.equal(stillMet!.status, 'SLA-050');
    const allForMet = await db.select().from(slaInstances).where(eq(slaInstances.subjectId, metSubjectId));
    assert.equal(allForMet.length, 1);
  });
});
