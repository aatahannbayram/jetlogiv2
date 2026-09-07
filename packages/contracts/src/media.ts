import { GeoPoint, Timestamp, Uuid, z } from './common.js';

export const MediaKind = z.enum(['photo', 'document_page', 'document_pdf', 'signature', 'audio']);
export type MediaKind = z.infer<typeof MediaKind>;

/**
 * Media never travels through the API. The client asks for a presigned PUT,
 * uploads straight to object storage, then references the mediaId in the step
 * submission. This keeps large uploads out of the request path and lets the
 * offline queue retry the upload independently of the submission.
 */
export const PresignRequest = z
  .object({
    /** Client-generated so the upload is idempotent across retries. */
    mediaId: Uuid,
    kind: MediaKind,
    contentType: z.enum([
      'image/jpeg',
      'image/png',
      'image/webp',
      'application/pdf',
      'audio/mp4',
    ]),
    byteSize: z.number().int().positive().max(25 * 1024 * 1024),
    /** SHA-256 of the exact bytes, lower-case hex. Verified after upload. */
    sha256: z.string().regex(/^[a-f0-9]{64}$/),
    taskId: Uuid.nullish(),
    stepKey: z.string().max(60).nullish(),
    capturedAt: Timestamp,
    capturedAt_location: GeoPoint.nullish(),
  })
  .openapi('PresignRequest');

export const PresignResponse = z
  .object({
    mediaId: Uuid,
    uploadUrl: z.string().url(),
    method: z.literal('PUT'),
    headers: z.record(z.string()),
    expiresAt: Timestamp,
    /** True when this exact sha256 was already stored; client can skip upload. */
    alreadyUploaded: z.boolean().default(false),
  })
  .openapi('PresignResponse');

export const MediaRef = z
  .object({
    mediaId: Uuid,
    kind: MediaKind,
    sha256: z.string(),
    byteSize: z.number().int().positive(),
    capturedAt: Timestamp,
    /** Short-lived read URL, issued only to panel and support users. */
    url: z.string().url().nullish(),
  })
  .openapi('MediaRef');
export type MediaRef = z.infer<typeof MediaRef>;

export const ConfirmMediaResponse = z
  .object({
    mediaId: Uuid,
    state: z.enum(['uploaded', 'verified']),
  })
  .openapi('ConfirmMediaResponse');
export type ConfirmMediaResponse = z.infer<typeof ConfirmMediaResponse>;
