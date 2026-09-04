import type { ReturnStatusCode } from '@dijigoo/contracts';
import { emitEvent } from '@dijigoo/core';
import { custodyItems, returnTransitions, returns } from '@dijigoo/db';
import type { Database } from '@dijigoo/db';
import { and, eq, isNull } from 'drizzle-orm';

/**
 * Faz 4 of the Nihai mimari plan (~/.claude/plans/toasty-mixing-adleman.md):
 * RET (İade/Ters Lojistik), tied to two real courier-reachable moments —
 * see the comment on `returnStatusCode` in enums.ts for the full reasoning.
 */

/** One open return record per item — repeated failures reuse it. */
export async function ensureReturn(
  tx: Database,
  input: { tenantId: string; taskId: string; custodyItemId: string; reason: string },
): Promise<{ id: string; status: ReturnStatusCode }> {
  const [existing] = await tx
    .select({ id: returns.id, status: returns.status })
    .from(returns)
    .where(eq(returns.custodyItemId, input.custodyItemId))
    .limit(1);
  if (existing) return existing;

  const [created] = await tx
    .insert(returns)
    .values({
      tenantId: input.tenantId,
      taskId: input.taskId,
      custodyItemId: input.custodyItemId,
      reason: input.reason,
    })
    .onConflictDoNothing({ target: [returns.custodyItemId] })
    .returning({ id: returns.id, status: returns.status });

  if (created) return created;

  const [row] = await tx
    .select({ id: returns.id, status: returns.status })
    .from(returns)
    .where(eq(returns.custodyItemId, input.custodyItemId))
    .limit(1);
  if (!row) throw new Error(`return provisioning failed for custody item ${input.custodyItemId}`);
  return row;
}

export async function transitionReturn(
  tx: Database,
  ctx: { tenantId: string; correlationId: string },
  returnId: string,
  fromStatus: ReturnStatusCode,
  toStatus: ReturnStatusCode,
  reason: string,
  occurredAt: Date,
): Promise<void> {
  if (fromStatus === toStatus) return;

  await tx.update(returns).set({ status: toStatus, updatedAt: occurredAt }).where(eq(returns.id, returnId));

  await tx.insert(returnTransitions).values({ returnId, fromStatus, toStatus, reason, occurredAt });

  await emitEvent(tx, {
    key: 'return.transitioned',
    tenantId: ctx.tenantId,
    subjectType: 'return',
    subjectId: returnId,
    actorType: 'courier',
    actorId: null,
    correlationId: ctx.correlationId,
    occurredAt,
    data: { from: fromStatus, to: toStatus, reason },
  });
}

/**
 * A failed delivery only needs a return record if the courier still
 * physically has something to send back — an item the task's custody rows
 * show as held and not yet released. Digital-only tasks (no custody item)
 * correctly produce no return record at all.
 */
export async function openReturnsForFailedTask(
  tx: Database,
  ctx: { tenantId: string; correlationId: string; courierId: string },
  input: { taskId: string; reason: string; occurredAt: Date },
): Promise<void> {
  const held = await tx
    .select({ id: custodyItems.id })
    .from(custodyItems)
    .where(
      and(
        eq(custodyItems.taskId, input.taskId),
        eq(custodyItems.holderCourierId, ctx.courierId),
        isNull(custodyItems.releasedAt),
      ),
    );

  // Silent on creation, same as `ensureWorkOrder`/`ensureDocument` — the
  // outbox only records real transitions, not a record simply existing.
  for (const item of held) {
    await ensureReturn(tx, {
      tenantId: ctx.tenantId,
      taskId: input.taskId,
      custodyItemId: item.id,
      reason: input.reason,
    });
  }
}

/**
 * The courier handing a held item to a branch/warehouse (Faz 2's custody
 * handover) is, from the courier's side, the return actually happening —
 * close any open return record for it.
 */
export async function closeReturnOnBranchHandover(
  tx: Database,
  ctx: { tenantId: string; correlationId: string },
  custodyItemId: string,
  occurredAt: Date,
): Promise<void> {
  const [record] = await tx
    .select({ id: returns.id, status: returns.status })
    .from(returns)
    .where(eq(returns.custodyItemId, custodyItemId))
    .limit(1);
  if (!record) return;

  await transitionReturn(tx, ctx, record.id, record.status, 'RET-070', 'custody.handover', occurredAt);
}
