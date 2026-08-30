import type { IdempotencyRecord, IdempotencyStore } from '@dijigoo/core';
import { idempotencyKeys } from '@dijigoo/db';
import type { Database } from '@dijigoo/db';
import { and, eq, sql } from 'drizzle-orm';

/**
 * Postgres-backed idempotency ledger.
 *
 * Deliberately not Redis: the stored response must survive a cache eviction,
 * because a courier's offline queue can retry a submission hours later and
 * losing the record would re-run a delivery.
 *
 * The claim is an `INSERT ... ON CONFLICT DO NOTHING`, which is atomic across
 * concurrent API instances without any application-level locking.
 */
export class PostgresIdempotencyStore implements IdempotencyStore {
  constructor(
    private readonly db: Database,
    private readonly courierId: string,
  ) {}

  async claim(key: string, requestHash: string, ttlSeconds: number): Promise<IdempotencyRecord | null> {
    const expiresAt = new Date(Date.now() + ttlSeconds * 1000);

    const inserted = await this.db
      .insert(idempotencyKeys)
      .values({
        key,
        courierId: this.courierId,
        requestHash,
        state: 'in_progress',
        expiresAt,
      })
      .onConflictDoNothing()
      .returning({ key: idempotencyKeys.key });

    if (inserted.length > 0) return null;

    const [existing] = await this.db
      .select()
      .from(idempotencyKeys)
      .where(and(eq(idempotencyKeys.key, key), eq(idempotencyKeys.courierId, this.courierId)))
      .limit(1);

    if (!existing) return null;

    // An expired record is as good as absent: reclaim it rather than making the
    // courier's queue fail forever on a stale row.
    if (existing.expiresAt.getTime() < Date.now()) {
      await this.db
        .update(idempotencyKeys)
        .set({ requestHash, state: 'in_progress', responseBody: null, responseStatus: null, expiresAt })
        .where(and(eq(idempotencyKeys.key, key), eq(idempotencyKeys.courierId, this.courierId)));
      return null;
    }

    return {
      key: existing.key,
      requestHash: existing.requestHash,
      status: existing.state === 'completed' ? 'completed' : 'in_progress',
      responseStatus: existing.responseStatus ?? undefined,
      responseBody: existing.responseBody,
      createdAt: existing.createdAt,
    };
  }

  async complete(key: string, responseStatus: number, responseBody: unknown): Promise<void> {
    await this.db
      .update(idempotencyKeys)
      .set({
        state: 'completed',
        responseStatus,
        responseBody,
        completedAt: new Date(),
      })
      .where(and(eq(idempotencyKeys.key, key), eq(idempotencyKeys.courierId, this.courierId)));
  }

  async release(key: string): Promise<void> {
    await this.db
      .delete(idempotencyKeys)
      .where(
        and(
          eq(idempotencyKeys.key, key),
          eq(idempotencyKeys.courierId, this.courierId),
          eq(idempotencyKeys.state, 'in_progress'),
        ),
      );
  }

  /** Called by the worker's nightly sweep. */
  static async purgeExpired(db: Database): Promise<number> {
    const deleted = await db
      .delete(idempotencyKeys)
      .where(sql`${idempotencyKeys.expiresAt} < now()`)
      .returning({ key: idempotencyKeys.key });
    return deleted.length;
  }
}
