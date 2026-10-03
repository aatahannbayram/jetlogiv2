import { AppError, istanbulYmd, type SolvelineCallClient } from '@dijigoo/core';
import { couriers, maskedCallSessions, media, tasks } from '@dijigoo/db';
import { eq } from 'drizzle-orm';

import type { AppContext } from '../context.js';

/**
 * After ANSWER, copy the time-limited recording URL into S3. Audio never
 * reaches the courier app.
 */
export async function storeSolvelineRecording(
  ctx: AppContext,
  client: SolvelineCallClient,
  session: typeof maskedCallSessions.$inferSelect,
  uniqueId: string,
  occurredAt: Date,
): Promise<void> {
  if (session.hasRecording && session.recordingMediaId) return;

  const day = istanbulYmd(occurredAt);
  const url = await client.getRecording({ uniqueId, startDate: day, endDate: day });
  if (!url) {
    throw new AppError('UPSTREAM_UNAVAILABLE', { message: 'Cagri kaydi URL yok.' });
  }

  const res = await fetch(url);
  if (!res.ok) {
    throw new AppError('UPSTREAM_UNAVAILABLE', { message: 'Cagri kaydi indirilemedi.' });
  }
  const buf = Buffer.from(await res.arrayBuffer());
  if (buf.byteLength < 32) {
    throw new AppError('UPSTREAM_UNAVAILABLE', { message: 'Cagri kaydi bos.' });
  }

  const contentType = res.headers.get('content-type')?.split(';')[0]?.trim() || 'audio/mpeg';
  const mediaId = crypto.randomUUID();
  const tenantId = await tenantIdForSession(ctx, session);
  const stored = await ctx.storage.putBytes({
    mediaId,
    tenantId,
    courierId: session.courierId,
    kind: 'audio',
    contentType,
    body: buf,
    capturedAt: occurredAt,
  });

  await ctx.db.insert(media).values({
    id: mediaId,
    tenantId,
    courierId: session.courierId,
    kind: 'audio',
    state: 'uploaded',
    contentType,
    byteSize: stored.byteSize,
    sha256: stored.sha256,
    storageKey: stored.storageKey,
    storageBucket: stored.bucket,
    taskId: session.taskId,
    stepKey: 'masked_call',
    capturedAt: occurredAt,
    metadata: { uniqueid: uniqueId, source: 'solveline' },
    uploadedAt: new Date(),
    verifiedAt: new Date(),
  });

  await ctx.db
    .update(maskedCallSessions)
    .set({
      recordingMediaId: mediaId,
      hasRecording: true,
    })
    .where(eq(maskedCallSessions.id, session.id));
}

async function tenantIdForSession(
  ctx: AppContext,
  session: typeof maskedCallSessions.$inferSelect,
): Promise<string> {
  if (session.taskId) {
    const [task] = await ctx.db
      .select({ tenantId: tasks.tenantId })
      .from(tasks)
      .where(eq(tasks.id, session.taskId))
      .limit(1);
    if (task) return task.tenantId;
  }
  const [row] = await ctx.db
    .select({ tenantId: couriers.tenantId })
    .from(couriers)
    .where(eq(couriers.id, session.courierId))
    .limit(1);
  if (!row) throw new AppError('NOT_FOUND');
  return row.tenantId;
}
