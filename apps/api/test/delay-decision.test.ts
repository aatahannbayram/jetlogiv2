import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';

import { AppError } from '@dijigoo/core';
import {
  couriers,
  createDatabase,
  outboxEvents,
  slaInstances,
  taskTransitions,
  tasks,
  tenants,
  workOrders,
} from '@dijigoo/db';
import type { Database } from '@dijigoo/db';
import { and, eq } from 'drizzle-orm';

import { extendSlaInstance, startSlaInstance } from '../src/services/sla.js';
import { cancelTask } from '../src/services/task-cancellation.js';

function hasErrorCode(code: string) {
  return (err: unknown) => err instanceof AppError && err.code === code;
}

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
    console.warn(`[delay-decision.test] Postgres at ${url} not reachable, skipping — run \`docker compose up -d postgres\` + \`pnpm --filter @dijigoo/db migrate\`.`);
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
    .values({ name: 'delay-decision.test tenant', slug: `delay-test-${randomUUID()}` })
    .returning({ id: tenants.id });
  const [courier] = await db
    .insert(couriers)
    .values({
      tenantId: tenant!.id,
      phone: `+9053202${Math.floor(Math.random() * 90000 + 10000)}`,
      fullName: 'Delay Decision Test Kurye',
      employeeCode: `DD-${randomUUID().slice(0, 8)}`,
    })
    .returning({ id: couriers.id });
  return { tenantId: tenant!.id, courierId: courier!.id };
}

async function seedTask(db: Database, tenantId: string, courierId: string) {
  const [task] = await db
    .insert(tasks)
    .values({
      tenantId,
      courierId,
      reference: `DD-TEST-${randomUUID().slice(0, 8)}`,
      type: 'DELIVERY',
      addressLine1: 'delay-decision.test address',
      city: 'Test',
    })
    .returning();
  return task!;
}

test('extendSlaInstance: pushes the deadline back, stays SLA-010', async () => {
  await withDatabase(async (db) => {
    const { tenantId } = await seedTenantAndCourier(db);
    const subjectId = randomUUID();
    const startedAt = new Date('2026-09-03T09:00:00Z');
    const originalTarget = new Date('2026-09-03T10:00:00Z');

    await startSlaInstance(db, { tenantId, correlationId: randomUUID() }, { subjectType: 'task', subjectId, targetAt: originalTarget, startedAt });

    const newTarget = new Date('2026-09-03T14:00:00Z');
    await extendSlaInstance(db, { tenantId, correlationId: randomUUID() }, { subjectType: 'task', subjectId, newTargetAt: newTarget, extendedAt: startedAt });

    const [extended] = await db.select().from(slaInstances).where(eq(slaInstances.subjectId, subjectId)).limit(1);
    assert.equal(extended!.status, 'SLA-010');
    assert.equal(extended!.targetAt.toISOString(), newTarget.toISOString());

    const [event] = await db
      .select()
      .from(outboxEvents)
      .where(and(eq(outboxEvents.subjectId, extended!.id), eq(outboxEvents.key, 'sla.extended')))
      .limit(1);
    assert.ok(event, 'expected an sla.extended event');
  });
});

test('extendSlaInstance: throws when there is no open SLA instance to extend', async () => {
  await withDatabase(async (db) => {
    const { tenantId } = await seedTenantAndCourier(db);
    await assert.rejects(
      () =>
        extendSlaInstance(
          db,
          { tenantId, correlationId: randomUUID() },
          { subjectType: 'task', subjectId: randomUUID(), newTargetAt: new Date(), extendedAt: new Date() },
        ),
      hasErrorCode('NOT_FOUND'),
    );
  });
});

test('cancelTask: real Postgres round trip — status, transition, WO close, SLA resolve, outbox', async () => {
  await withDatabase(async (db) => {
    const { tenantId, courierId } = await seedTenantAndCourier(db);
    const task = await seedTask(db, tenantId, courierId);

    const startedAt = new Date('2026-09-03T09:00:00Z');
    const targetAt = new Date('2026-09-03T10:00:00Z');
    await startSlaInstance(db, { tenantId, correlationId: randomUUID() }, { subjectType: 'task', subjectId: task.id, targetAt, startedAt });

    const occurredAt = new Date('2026-09-03T09:30:00Z');
    await db.transaction(async (tx) => {
      await cancelTask(
        tx,
        { tenantId, correlationId: randomUUID() },
        { id: task.id, tenantId, reference: task.reference, status: task.status, workOrderId: task.workOrderId },
        { actorType: 'operator', actorId: null },
        'operasyon iptal etti',
        occurredAt,
      );
    });

    const [updated] = await db.select().from(tasks).where(eq(tasks.id, task.id)).limit(1);
    assert.equal(updated!.status, 'CANCELLED');

    const [transition] = await db.select().from(taskTransitions).where(eq(taskTransitions.taskId, task.id)).limit(1);
    assert.equal(transition!.fromStatus, 'ASSIGNED');
    assert.equal(transition!.toStatus, 'CANCELLED');
    assert.equal(transition!.actorType, 'operator');
    assert.equal(transition!.reason, 'operasyon iptal etti');

    // tasks.workOrderId itself is never written back (pre-existing gap, same
    // as the courier-initiated cancel path in task.ts) — look the work order
    // up the same way ensureWorkOrder does, by (tenantId, reference).
    const [wo] = await db.select().from(workOrders).where(and(eq(workOrders.tenantId, tenantId), eq(workOrders.reference, task.reference))).limit(1);
    assert.equal(wo!.status, 'WO-120');

    const [sla] = await db.select().from(slaInstances).where(eq(slaInstances.subjectId, task.id)).limit(1);
    assert.ok(sla!.resolvedAt, 'cancelling must resolve the open SLA instance, not leave it dangling');

    const events = await db.select().from(outboxEvents).where(eq(outboxEvents.subjectId, task.id));
    assert.ok(events.some((e) => e.key === 'task.cancelled'));
  });
});

test('cancelTask: refuses to cancel an already-finalized task', async () => {
  await withDatabase(async (db) => {
    const { tenantId, courierId } = await seedTenantAndCourier(db);
    const task = await seedTask(db, tenantId, courierId);
    await db.update(tasks).set({ status: 'COMPLETED' }).where(eq(tasks.id, task.id));

    await assert.rejects(
      () =>
        db.transaction((tx) =>
          cancelTask(
            tx,
            { tenantId, correlationId: randomUUID() },
            { id: task.id, tenantId, reference: task.reference, status: 'COMPLETED', workOrderId: null },
            { actorType: 'operator', actorId: null },
            null,
            new Date(),
          ),
        ),
      hasErrorCode('TASK_ALREADY_FINALIZED'),
    );
  });
});
