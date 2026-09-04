import type { ProductStatusCode } from '@dijigoo/contracts';
import { emitEvent } from '@dijigoo/core';
import { custodyItemTransitions, custodyItems } from '@dijigoo/db';
import type { Database } from '@dijigoo/db';
import { eq } from 'drizzle-orm';

/**
 * Faz 2 of the Nihai mimari plan (~/.claude/plans/toasty-mixing-adleman.md):
 * `custody_items.status` as its own canonical PRD state, alongside the
 * `holderCourierId`/`releasedAt` pair the handover endpoint already
 * maintained. See `packages/db/src/schema/custody.ts` for the column and
 * `custody_item_transitions` audit table.
 *
 * PRD-010..070 (depot intake — ürün bekleniyor → stoğa alındı → rezerve →
 * eşlendi) has no wiring here: it needs a depot/warehouse actor this
 * codebase's auth does not have (courier-only), same gap as WO-010..060 in
 * Faz 1. PRD-200/210 (tazmin mutabakatı) is financial resolution, out of
 * scope per the 2026-08-28 scope decision — `reportCustodyIssue` stops at
 * PRD-180/190 (the report itself), not the settlement.
 */

/**
 * What a `POST /v1/custody/handover` call means for the item's PRD status.
 * `null` = no status change — a courier-to-courier handover only moves
 * `holderCourierId`, the item is still "Kuryeye Zimmet" either way.
 */
export function productStatusForHandover(
  direction: 'handover' | 'takeover',
  counterpartyKind: 'courier' | 'branch' | 'customer' | 'warehouse',
): ProductStatusCode | null {
  if (direction === 'handover') {
    if (counterpartyKind === 'customer') return 'PRD-120'; // Teslim Edildi
    if (counterpartyKind === 'branch' || counterpartyKind === 'warehouse') return 'PRD-130'; // Şubeye Döndü
    return null; // courier -> courier
  }
  // takeover
  if (counterpartyKind === 'branch' || counterpartyKind === 'warehouse') return 'PRD-100'; // Kuryeye Zimmet
  if (counterpartyKind === 'customer') return 'PRD-020'; // Teslim Alındı (e.g. a pickup/return)
  return 'PRD-100'; // courier -> courier, still held by a courier
}

export async function transitionCustodyItem(
  tx: Database,
  ctx: { tenantId: string; correlationId: string },
  itemId: string,
  fromStatus: ProductStatusCode,
  toStatus: ProductStatusCode,
  reason: string,
  occurredAt: Date,
): Promise<void> {
  if (fromStatus === toStatus) return;

  await tx.update(custodyItems).set({ status: toStatus }).where(eq(custodyItems.id, itemId));

  await tx.insert(custodyItemTransitions).values({
    itemId,
    fromStatus,
    toStatus,
    reason,
    occurredAt,
  });

  await emitEvent(tx, {
    key: 'custody.item_handed_over',
    tenantId: ctx.tenantId,
    subjectType: 'custody',
    subjectId: itemId,
    actorType: 'system',
    actorId: null,
    correlationId: ctx.correlationId,
    occurredAt,
    data: { from: fromStatus, to: toStatus, reason },
  });
}
