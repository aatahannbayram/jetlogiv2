import { ConfirmMediaResponse, ErrorResponse, PresignRequest, PresignResponse, Uuid } from '@dijigoo/contracts';
import { AppError } from '@dijigoo/core';
import { media } from '@dijigoo/db';
import { and, eq } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { z } from 'zod';

import type { AppContext } from '../context.js';

/** Per-kind ceilings. A 25 MB doorstep photo is a bug, not a requirement. */
const MAX_BYTES: Record<string, number> = {
  photo: 8 * 1024 * 1024,
  document_page: 8 * 1024 * 1024,
  document_pdf: 25 * 1024 * 1024,
  signature: 1 * 1024 * 1024,
  audio: 10 * 1024 * 1024,
};

const ALLOWED_TYPES: Record<string, string[]> = {
  photo: ['image/jpeg', 'image/webp'],
  document_page: ['image/jpeg', 'image/png', 'image/webp'],
  document_pdf: ['application/pdf'],
  signature: ['image/png', 'image/webp'],
  audio: ['audio/mp4'],
};

export async function mediaRoutes(app: FastifyInstance, { ctx }: { ctx: AppContext }) {
  const route = app.withTypeProvider<ZodTypeProvider>();

  route.post(
    '/v1/media/presign',
    {
      schema: {
        tags: ['Media'],
        body: PresignRequest,
        response: {
          200: PresignResponse,
          400: ErrorResponse,
          401: ErrorResponse,
          413: ErrorResponse,
          415: ErrorResponse,
        },
      },
    },
    async (request) => {
      const courier = await app.authenticate(request);
      const body = request.body;

      if (!ALLOWED_TYPES[body.kind]?.includes(body.contentType)) {
        throw new AppError('UNSUPPORTED_MEDIA_TYPE', {
          details: [
            {
              field: 'contentType',
              issue: 'not_allowed_for_kind',
              meta: { kind: body.kind, allowed: ALLOWED_TYPES[body.kind] },
            },
          ],
        });
      }

      const limit = MAX_BYTES[body.kind] ?? 8 * 1024 * 1024;
      if (body.byteSize > limit) {
        throw new AppError('PAYLOAD_TOO_LARGE', {
          details: [{ field: 'byteSize', issue: 'over_limit', meta: { limit, provided: body.byteSize } }],
        });
      }

      // Content-addressed dedupe. A courier who retries an upload after losing
      // signal, or photographs the same barcode twice, does not pay for it
      // twice and the client can skip the PUT entirely.
      const [existing] = await ctx.db
        .select({ id: media.id, state: media.state })
        .from(media)
        .where(and(eq(media.tenantId, courier.tenantId), eq(media.sha256, body.sha256)))
        .limit(1);

      if (existing && existing.state !== 'pending' && existing.state !== 'purged') {
        return {
          mediaId: existing.id,
          uploadUrl: 'about:blank',
          method: 'PUT' as const,
          headers: {},
          expiresAt: new Date(Date.now() + 60_000).toISOString(),
          alreadyUploaded: true,
        };
      }

      const capturedAt = new Date(body.capturedAt);
      const presigned = await ctx.storage.presignUpload(
        {
          mediaId: body.mediaId,
          tenantId: courier.tenantId,
          courierId: courier.courierId,
          kind: body.kind,
          contentType: body.contentType,
          byteSize: body.byteSize,
          sha256: body.sha256,
          capturedAt,
        },
        body.stepKey ?? undefined,
      );

      await ctx.db
        .insert(media)
        .values({
          id: body.mediaId,
          tenantId: courier.tenantId,
          courierId: courier.courierId,
          kind: body.kind,
          state: 'pending',
          contentType: body.contentType,
          byteSize: body.byteSize,
          sha256: body.sha256,
          storageKey: presigned.storageKey,
          storageBucket: presigned.bucket,
          taskId: body.taskId ?? null,
          stepKey: body.stepKey ?? null,
          capturedAt,
          capturedLocation: body.capturedAt_location
            ? { lat: body.capturedAt_location.lat, lng: body.capturedAt_location.lng }
            : null,
          metadata: body.capturedAt_location
            ? { accuracy: body.capturedAt_location.accuracy, isMocked: body.capturedAt_location.isMocked }
            : {},
        })
        .onConflictDoNothing();

      return {
        mediaId: body.mediaId,
        uploadUrl: presigned.uploadUrl,
        method: 'PUT' as const,
        headers: presigned.headers,
        expiresAt: presigned.expiresAt.toISOString(),
        alreadyUploaded: false,
      };
    },
  );

  route.post(
    '/v1/media/:mediaId/confirm',
    {
      schema: {
        tags: ['Media'],
        params: z.object({ mediaId: Uuid }),
        response: {
          200: ConfirmMediaResponse,
          401: ErrorResponse,
          404: ErrorResponse,
          409: ErrorResponse,
        },
      },
    },
    async (request) => {
      const courier = await app.authenticate(request);
      const [row] = await ctx.db
        .select()
        .from(media)
        .where(and(eq(media.id, request.params.mediaId), eq(media.courierId, courier.courierId)))
        .limit(1);

      if (!row) throw new AppError('NOT_FOUND');
      if (row.state === 'uploaded' || row.state === 'verified') {
        return { mediaId: row.id, state: row.state };
      }
      if (row.state !== 'pending') {
        throw new AppError('CONFLICT', {
          message: 'Bu medya onaylanamaz.',
          userVisible: true,
        });
      }

      const exists = await ctx.storage.objectExists(row.storageBucket, row.storageKey);
      if (!exists) {
        throw new AppError('CONFLICT', {
          message: 'Yukleme henuz depolamada gorunmuyor.',
          userVisible: true,
        });
      }

      await ctx.db
        .update(media)
        .set({ state: 'uploaded', uploadedAt: new Date() })
        .where(eq(media.id, row.id));

      return { mediaId: row.id, state: 'uploaded' as const };
    },
  );
}
