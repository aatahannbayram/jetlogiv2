import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';

import { createDatabase, deliveryResults, outboxEvents, tenants, workOrderTransitions, workOrders } from '@dijigoo/db';
import type { Database } from '@dijigoo/db';
import { eq } from 'drizzle-orm';

import {
  canonicalDeliveryResultCode,
  ensureWorkOrder,
  recordDeliveryResult,
  transitionWorkOrder,
} from '../src/services/work-order.js';

test('canonicalDeliveryResultCode: maps known workflow outcomes to the canonical DLV catalog', () => {
  assert.equal(canonicalDeliveryResultCode('DELIVERED'), 'DLV-010');
  assert.equal(canonicalDeliveryResultCode('RECIPIENT_ABSENT'), 'DLV-080');
  assert.equal(canonicalDeliveryResultCode('ADDRESS_NOT_FOUND'), 'DLV-090');
  assert.equal(canonicalDeliveryResultCode('REFUSED'), 'DLV-110');
  assert.equal(canonicalDeliveryResultCode('POSTPONED'), 'DLV-140');
});

test('canonicalDeliveryResultCode: unrecognized outcome falls back to DLV-190 instead of throwing', () => {
  assert.equal(canonicalDeliveryResultCode('SOME_FUTURE_OUTCOME_NOT_YET_MAPPED'), 'DLV-190');
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
    console.warn(`[work-order.test] Postgres at ${url} not reachable, skipping — run \`docker compose up -d postgres\` + \`pnpm --filter @dijigoo/db migrate\`.`);
    return;
  }
  try {
    await run(db);
  } finally {
    // `Database` deliberately hides the driver handle (see packages/db/src/index.ts)
    // so a transaction satisfies the same type; reach past that here only to
    // close the socket this test opened, so `node --test` can exit cleanly.
    await (db as unknown as { $client: { end: () => Promise<void> } }).$client.end();
  }
}

test('ensureWorkOrder + transitionWorkOrder + recordDeliveryResult: real Postgres round trip', async () => {
  await withDatabase(async (db) => {
    const [tenant] = await db
      .insert(tenants)
      .values({ name: 'work-order.test tenant', slug: `wo-test-${randomUUID()}` })
      .returning({ id: tenants.id });
    assert.ok(tenant);

    const task = { id: randomUUID(), tenantId: tenant!.id, reference: `WOTEST-${randomUUID()}`, workOrderId: null };
    const occurredAt = new Date();

    // First call provisions a fresh WO at WO-070 (Aktif); nothing upstream creates one yet.
    const workOrderId = await ensureWorkOrder(db, task);
    const [created] = await db.select().from(workOrders).where(eq(workOrders.id, workOrderId)).limit(1);
    assert.equal(created!.status, 'WO-070');
    assert.equal(created!.reference, task.reference);

    // Idempotent: a second call with the same (still-null) workOrderId must not create a duplicate row.
    const again = await ensureWorkOrder(db, task);
    assert.equal(again, workOrderId);

    // A successful delivery attempt is recorded against the canonical catalog...
    await recordDeliveryResult(
      db,
      { tenantId: tenant!.id, correlationId: randomUUID() },
      {
        taskId: task.id,
        workOrderId,
        attemptNumber: 1,
        outcomeCode: 'DELIVERED',
        note: null,
        position: { lat: 38.1512, lng: 29.0614 },
        occurredAt,
      },
    );
    const [dlv] = await db.select().from(deliveryResults).where(eq(deliveryResults.taskId, task.id)).limit(1);
    assert.equal(dlv!.code, 'DLV-010');
    assert.equal(dlv!.sourceOutcomeCode, 'DELIVERED');

    // ...and the outbox actually queued the event (not just an in-memory call).
    const [dlvEvent] = await db
      .select()
      .from(outboxEvents)
      .where(eq(outboxEvents.key, 'delivery_result.recorded'))
      .limit(1);
    assert.ok(dlvEvent, 'expected delivery_result.recorded to reach the outbox');

    // A successful finalize ends the work order.
    await transitionWorkOrder(
      db,
      { tenantId: tenant!.id, correlationId: randomUUID() },
      workOrderId,
      'WO-110',
      'task.completed',
      occurredAt,
    );
    const [completed] = await db.select().from(workOrders).where(eq(workOrders.id, workOrderId)).limit(1);
    assert.equal(completed!.status, 'WO-110');

    const [transition] = await db
      .select()
      .from(workOrderTransitions)
      .where(eq(workOrderTransitions.workOrderId, workOrderId))
      .limit(1);
    assert.equal(transition!.fromStatus, 'WO-070');
    assert.equal(transition!.toStatus, 'WO-110');

    // Transitioning to the status it's already at is a no-op, not a second row.
    await transitionWorkOrder(
      db,
      { tenantId: tenant!.id, correlationId: randomUUID() },
      workOrderId,
      'WO-110',
      'task.completed',
      occurredAt,
    );
    const allTransitions = await db
      .select()
      .from(workOrderTransitions)
      .where(eq(workOrderTransitions.workOrderId, workOrderId));
    assert.equal(allTransitions.length, 1);
  });
});
