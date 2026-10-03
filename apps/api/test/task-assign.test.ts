import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';

import { AppError } from '@dijigoo/core';
import { couriers, createDatabase, outboxEvents, tasks, tenants } from '@dijigoo/db';
import type { Database } from '@dijigoo/db';
import { eq } from 'drizzle-orm';

import { assignTask } from '../src/services/task-assign.js';

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
      `[task-assign.test] Postgres at ${url} not reachable, skipping — run \`docker compose up -d postgres\` + \`pnpm --filter @dijigoo/db migrate\`.`,
    );
    return;
  }
  try {
    await run(db);
  } finally {
    await (db as unknown as { $client: { end: () => Promise<void> } }).$client.end();
  }
}

async function seed(db: Database) {
  const [tenant] = await db
    .insert(tenants)
    .values({ name: 'assign.test tenant', slug: `assign-test-${randomUUID()}` })
    .returning({ id: tenants.id });
  const [a] = await db
    .insert(couriers)
    .values({
      tenantId: tenant!.id,
      phone: `+9053211${Math.floor(Math.random() * 90000 + 10000)}`,
      fullName: 'Assign A',
      employeeCode: `AA-${randomUUID().slice(0, 8)}`,
    })
    .returning({ id: couriers.id });
  const [b] = await db
    .insert(couriers)
    .values({
      tenantId: tenant!.id,
      phone: `+9053212${Math.floor(Math.random() * 90000 + 10000)}`,
      fullName: 'Assign B',
      employeeCode: `AB-${randomUUID().slice(0, 8)}`,
    })
    .returning({ id: couriers.id });
  const [task] = await db
    .insert(tasks)
    .values({
      tenantId: tenant!.id,
      courierId: a!.id,
      reference: `AS-${randomUUID().slice(0, 8)}`,
      type: 'DELIVERY',
      addressLine1: 'assign.test',
      city: 'Test',
    })
    .returning();
  return { tenantId: tenant!.id, a: a!.id, b: b!.id, task: task! };
}

test('assignTask: ayni kurye tekrarinda yazmaz', async () => {
  await withDatabase(async (db) => {
    const { a, task } = await seed(db);
    const once = await assignTask(db, { correlationId: randomUUID() }, {
      taskId: task.id,
      courierId: a,
      occurredAt: new Date(),
    });
    assert.equal(once.alreadyAssigned, true);
    assert.equal(once.courierId, a);
  });
});

test('assignTask: cekerken previousCourierId dolar ve task.assigned yazar', async () => {
  await withDatabase(async (db) => {
    const { a, b, task } = await seed(db);
    const moved = await assignTask(db, { correlationId: randomUUID() }, {
      taskId: task.id,
      courierId: b,
      occurredAt: new Date(),
    });
    assert.equal(moved.alreadyAssigned, false);
    assert.equal(moved.previousCourierId, a);
    assert.equal(moved.courierId, b);

    const [row] = await db.select().from(tasks).where(eq(tasks.id, task.id));
    assert.equal(row?.courierId, b);
    assert.equal(row?.previousCourierId, a);

    const events = await db.select().from(outboxEvents).where(eq(outboxEvents.subjectId, task.id));
    assert.ok(events.some((e) => e.key === 'task.assigned'));
  });
});

test('assignTask: bitmis gorev 409', async () => {
  await withDatabase(async (db) => {
    const { b, task } = await seed(db);
    await db.update(tasks).set({ status: 'COMPLETED' }).where(eq(tasks.id, task.id));
    await assert.rejects(
      () =>
        assignTask(db, { correlationId: randomUUID() }, {
          taskId: task.id,
          courierId: b,
          occurredAt: new Date(),
        }),
      (err: unknown) => err instanceof AppError && err.code === 'TASK_ALREADY_FINALIZED',
    );
  });
});
