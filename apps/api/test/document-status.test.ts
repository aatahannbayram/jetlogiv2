import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';

import {
  createDatabase,
  documentTransitions,
  documents,
  outboxEvents,
  qualityReviews,
  tenants,
} from '@dijigoo/db';
import type { Database } from '@dijigoo/db';
import { eq } from 'drizzle-orm';

import {
  documentStatusForStepType,
  ensureDocument,
  recordAutomaticQualityReview,
  transitionDocument,
} from '../src/services/document-status.js';

test('documentStatusForStepType: SIGNATURE and DOCUMENT_SCAN map to their canonical DOC codes', () => {
  assert.equal(documentStatusForStepType('SIGNATURE'), 'DOC-070');
  assert.equal(documentStatusForStepType('DOCUMENT_SCAN'), 'DOC-080');
});

test('documentStatusForStepType: non-document step types produce no document', () => {
  assert.equal(documentStatusForStepType('PHOTO_EVIDENCE'), null);
  assert.equal(documentStatusForStepType('OTP_VERIFY'), null);
  assert.equal(documentStatusForStepType('GEOFENCE_CHECK'), null);
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
    console.warn(`[document-status.test] Postgres at ${url} not reachable, skipping — run \`docker compose up -d postgres\` + \`pnpm --filter @dijigoo/db migrate\`.`);
    return;
  }
  try {
    await run(db);
  } finally {
    await (db as unknown as { $client: { end: () => Promise<void> } }).$client.end();
  }
}

test('ensureDocument + transitionDocument: real Postgres round trip, idempotent on (taskId, stepKey)', async () => {
  await withDatabase(async (db) => {
    const [tenant] = await db
      .insert(tenants)
      .values({ name: 'document-status.test tenant', slug: `doc-test-${randomUUID()}` })
      .returning({ id: tenants.id });
    assert.ok(tenant);

    const taskId = randomUUID();
    const occurredAt = new Date();

    const doc = await ensureDocument(db, { tenantId: tenant!.id, taskId, sourceStepKey: 'imza', mediaId: null });
    assert.equal(doc.status, 'DOC-010', 'a freshly provisioned document starts at Evrak Bekleniyor');

    // Same (taskId, stepKey) a second time reuses the row rather than duplicating it.
    const again = await ensureDocument(db, { tenantId: tenant!.id, taskId, sourceStepKey: 'imza', mediaId: null });
    assert.equal(again.id, doc.id);

    await transitionDocument(
      db,
      { tenantId: tenant!.id, correlationId: randomUUID() },
      doc.id,
      doc.status,
      'DOC-070',
      'step.SIGNATURE',
      occurredAt,
    );

    const [updated] = await db.select().from(documents).where(eq(documents.id, doc.id)).limit(1);
    assert.equal(updated!.status, 'DOC-070');

    const [transition] = await db
      .select()
      .from(documentTransitions)
      .where(eq(documentTransitions.documentId, doc.id))
      .limit(1);
    assert.equal(transition!.fromStatus, 'DOC-010');
    assert.equal(transition!.toStatus, 'DOC-070');

    const [event] = await db.select().from(outboxEvents).where(eq(outboxEvents.subjectId, doc.id)).limit(1);
    assert.ok(event, 'expected document.transitioned to reach the outbox');
  });
});

test('recordAutomaticQualityReview: real Postgres round trip — writes an already-resolved QUA-070 row', async () => {
  await withDatabase(async (db) => {
    const [tenant] = await db
      .insert(tenants)
      .values({ name: 'document-status.test tenant 2', slug: `doc-test2-${randomUUID()}` })
      .returning({ id: tenants.id });
    assert.ok(tenant);

    const subjectId = randomUUID();
    const occurredAt = new Date();

    await recordAutomaticQualityReview(
      db,
      { tenantId: tenant!.id, correlationId: randomUUID() },
      { subjectType: 'delivery_result', subjectId, occurredAt },
    );

    const [review] = await db.select().from(qualityReviews).where(eq(qualityReviews.subjectId, subjectId)).limit(1);
    assert.equal(review!.status, 'QUA-070');
    assert.equal(review!.subjectType, 'delivery_result');
    assert.equal(review!.reason, 'otomatik_kontrol');

    const [event] = await db.select().from(outboxEvents).where(eq(outboxEvents.subjectId, subjectId)).limit(1);
    assert.ok(event, 'expected quality_review.recorded to reach the outbox');
  });
});
