import { createHash } from 'node:crypto';

import { AppError } from './errors.js';

export interface IdempotencyRecord {
  key: string;
  /** Hash of the original request body. Guards against key reuse with new data. */
  requestHash: string;
  status: 'in_progress' | 'completed';
  responseStatus?: number;
  responseBody?: unknown;
  createdAt: Date;
}

export interface IdempotencyStore {
  /**
   * Atomically claims the key. Returns the existing record when the key was
   * seen before, or null when this caller won the claim and must do the work.
   */
  claim(key: string, requestHash: string, ttlSeconds: number): Promise<IdempotencyRecord | null>;
  complete(key: string, responseStatus: number, responseBody: unknown): Promise<void>;
  release(key: string): Promise<void>;
}

export function hashRequest(body: unknown): string {
  return createHash('sha256').update(stableStringify(body)).digest('hex');
}

/** Key order must not change the hash, or a re-serialised retry looks like a new body. */
function stableStringify(value: unknown): string {
  if (value === null || typeof value !== 'object') return JSON.stringify(value) ?? 'null';
  if (Array.isArray(value)) return `[${value.map(stableStringify).join(',')}]`;

  const entries = Object.entries(value as Record<string, unknown>)
    .filter(([, v]) => v !== undefined)
    .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
    .map(([k, v]) => `${JSON.stringify(k)}:${stableStringify(v)}`);

  return `{${entries.join(',')}}`;
}

export interface IdempotentResult<T> {
  value: T;
  status: number;
  replayed: boolean;
}

/**
 * Wraps a mutation so the offline queue can retry it safely.
 *
 * Three cases:
 *  - key unseen        -> run the handler, store the response
 *  - key completed     -> return the stored response verbatim, `replayed: true`
 *  - key in progress   -> 409, because two identical requests are racing and
 *                         the second must not run the handler concurrently
 *
 * A key presented with a different body is always a bug on the client, so it
 * gets IDEMPOTENCY_KEY_REUSED rather than being silently treated as new.
 */
export async function runIdempotent<T>(
  store: IdempotencyStore,
  key: string,
  body: unknown,
  handler: () => Promise<{ status: number; value: T }>,
  ttlSeconds = 24 * 60 * 60,
): Promise<IdempotentResult<T>> {
  const requestHash = hashRequest(body);
  const existing = await store.claim(key, requestHash, ttlSeconds);

  if (existing) {
    if (existing.requestHash !== requestHash) {
      throw new AppError('IDEMPOTENCY_KEY_REUSED', {
        details: [{ field: 'idempotency-key', issue: 'same_key_different_body' }],
      });
    }
    if (existing.status === 'in_progress') {
      throw new AppError('CONFLICT', {
        message: 'Ayni istek halen isleniyor.',
        retryAfter: 2,
      });
    }
    return {
      value: existing.responseBody as T,
      status: existing.responseStatus ?? 200,
      replayed: true,
    };
  }

  try {
    const { status, value } = await handler();
    await store.complete(key, status, value);
    return { value, status, replayed: false };
  } catch (error) {
    // Release so a retry can run: a failed attempt must not poison the key.
    await store.release(key);
    throw error;
  }
}
