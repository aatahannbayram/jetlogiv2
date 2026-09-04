import type { DocumentStatusCode, QualityReviewStatusCode } from '@dijigoo/contracts';
import { emitEvent } from '@dijigoo/core';
import { documentTransitions, documents, qualityReviews } from '@dijigoo/db';
import type { Database } from '@dijigoo/db';
import { and, eq } from 'drizzle-orm';

/**
 * Faz 3 of the Nihai mimari plan (~/.claude/plans/toasty-mixing-adleman.md):
 * DOC (Evrak/Arşiv) and a narrow, honest slice of QUA (Kalite/Kontrol).
 *
 * DOC: only reachable from a courier completing a SIGNATURE or
 * DOCUMENT_SCAN workflow step (`/v1/tasks/:taskId/steps`) — everything
 * upstream (basım, kuryeye zimmet) and downstream (merkez sevk, müşteri
 * onayı, arşiv) needs an actor this codebase's courier-only auth does not
 * have, same gap as WO-010..060 in Faz 1.
 *
 * QUA: only the "Otomatik" control policy — docx §2.1 lists Otomatik /
 * operasyon kalite kontrolü / müşteri onayı as the three project-level
 * options a contract can pick. This codebase already runs the automatic
 * check today (`missingRequiredSteps` in `@dijigoo/core`, required before a
 * task can finalize) — `recordAutomaticQualityReview` just gives that
 * existing, already-enforced check a canonical audit row. Manual/uzman
 * review needs an operator actor this codebase does not have either.
 */

/** Which workflow step types produce a document, and what status they land it at. */
export function documentStatusForStepType(stepType: string): DocumentStatusCode | null {
  switch (stepType) {
    case 'SIGNATURE':
      return 'DOC-070'; // İmzalandı
    case 'DOCUMENT_SCAN':
      return 'DOC-080'; // Sahada İmzalandı
    default:
      return null;
  }
}

/** Idempotent on (taskId, stepKey) — a resubmitted step reuses its document row. */
export async function ensureDocument(
  tx: Database,
  input: { tenantId: string; taskId: string; sourceStepKey: string; mediaId: string | null },
): Promise<{ id: string; status: DocumentStatusCode }> {
  const [existing] = await tx
    .select({ id: documents.id, status: documents.status })
    .from(documents)
    .where(and(eq(documents.taskId, input.taskId), eq(documents.sourceStepKey, input.sourceStepKey)))
    .limit(1);
  if (existing) return existing;

  const [created] = await tx
    .insert(documents)
    .values({
      tenantId: input.tenantId,
      taskId: input.taskId,
      sourceStepKey: input.sourceStepKey,
      mediaId: input.mediaId,
    })
    .onConflictDoNothing({ target: [documents.taskId, documents.sourceStepKey] })
    .returning({ id: documents.id, status: documents.status });

  if (created) return created;

  // Conflict means a concurrent submission already created it.
  const [row] = await tx
    .select({ id: documents.id, status: documents.status })
    .from(documents)
    .where(and(eq(documents.taskId, input.taskId), eq(documents.sourceStepKey, input.sourceStepKey)))
    .limit(1);
  if (!row) throw new Error(`document provisioning failed for task ${input.taskId} / ${input.sourceStepKey}`);
  return row;
}

export async function transitionDocument(
  tx: Database,
  ctx: { tenantId: string; correlationId: string },
  documentId: string,
  fromStatus: DocumentStatusCode,
  toStatus: DocumentStatusCode,
  reason: string,
  occurredAt: Date,
): Promise<void> {
  if (fromStatus === toStatus) return;

  await tx.update(documents).set({ status: toStatus, updatedAt: occurredAt }).where(eq(documents.id, documentId));

  await tx.insert(documentTransitions).values({ documentId, fromStatus, toStatus, reason, occurredAt });

  await emitEvent(tx, {
    key: 'document.transitioned',
    tenantId: ctx.tenantId,
    subjectType: 'document',
    subjectId: documentId,
    actorType: 'courier',
    actorId: null,
    correlationId: ctx.correlationId,
    occurredAt,
    data: { from: fromStatus, to: toStatus, reason },
  });
}

const AUTOMATIC_QUALITY_STATUS: QualityReviewStatusCode = 'QUA-070'; // Onaylandı

export async function recordAutomaticQualityReview(
  tx: Database,
  ctx: { tenantId: string; correlationId: string },
  input: { subjectType: string; subjectId: string; occurredAt: Date },
): Promise<void> {
  await tx.insert(qualityReviews).values({
    tenantId: ctx.tenantId,
    subjectType: input.subjectType,
    subjectId: input.subjectId,
    status: AUTOMATIC_QUALITY_STATUS,
    reason: 'otomatik_kontrol',
    occurredAt: input.occurredAt,
  });

  await emitEvent(tx, {
    key: 'quality_review.recorded',
    tenantId: ctx.tenantId,
    subjectType: 'quality_review',
    subjectId: input.subjectId,
    actorType: 'system',
    actorId: null,
    correlationId: ctx.correlationId,
    occurredAt: input.occurredAt,
    data: { subjectType: input.subjectType, subjectId: input.subjectId, status: AUTOMATIC_QUALITY_STATUS },
  });
}
