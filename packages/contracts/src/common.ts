import { extendZodWithOpenApi } from '@asteasolutions/zod-to-openapi';
import { z } from 'zod';

extendZodWithOpenApi(z);

export { z };

/* ------------------------------------------------------------------ *
 * Primitives
 * ------------------------------------------------------------------ */

export const Uuid = z.string().uuid().openapi({ example: '9f1c2f8a-7d1e-4f6b-9a3c-2b5d4e6f7a81' });

/** RFC 3339 / ISO 8601, always UTC with explicit offset. */
export const Timestamp = z
  .string()
  .datetime({ offset: true })
  .openapi({ example: '2026-08-25T09:15:00.000Z' });

/** E.164. Panel and mobile always exchange the normalised form. */
export const PhoneNumber = z
  .string()
  .regex(/^\+[1-9]\d{7,14}$/, 'E.164 formatinda olmali')
  .openapi({ example: '+905321234567' });

/**
 * Monotonic version counter used for optimistic concurrency on tasks and
 * custody records. Bumped server-side on every mutation.
 */
export const RowVersion = z.number().int().nonnegative();

export const Coordinates = z
  .object({
    lat: z.number().min(-90).max(90),
    lng: z.number().min(-180).max(180),
  })
  .openapi('Coordinates');
export type Coordinates = z.infer<typeof Coordinates>;

/**
 * A single positional fix. `capturedAt` is device clock, `accuracy` is the
 * horizontal radius in metres. The server rejects fixes whose accuracy is
 * worse than the geofence radius they are meant to satisfy.
 */
export const GeoPoint = Coordinates.extend({
  accuracy: z.number().nonnegative().describe('Yatay dogruluk yaricapi, metre'),
  altitude: z.number().nullish(),
  heading: z.number().min(0).max(360).nullish(),
  speed: z.number().nonnegative().nullish().describe('m/s'),
  capturedAt: Timestamp,
  /** True when the OS reported the fix as mocked. Never blocks, always logged. */
  isMocked: z.boolean().default(false),
}).openapi('GeoPoint');
export type GeoPoint = z.infer<typeof GeoPoint>;

export const Address = z
  .object({
    line1: z.string().min(1).max(255),
    line2: z.string().max(255).nullish(),
    district: z.string().max(120).nullish(),
    city: z.string().max(120),
    postalCode: z.string().max(20).nullish(),
    countryCode: z.string().length(2).default('TR'),
    coordinates: Coordinates.nullish(),
    /** Set when coordinates came from geocoding rather than the source system. */
    geocodeConfidence: z.enum(['exact', 'interpolated', 'approximate', 'failed']).nullish(),
  })
  .openapi('Address');
export type Address = z.infer<typeof Address>;

/* ------------------------------------------------------------------ *
 * Error model  (Bolum 17 - standart hata modeli)
 * ------------------------------------------------------------------ */

/**
 * Closed set of machine-readable error codes. The mobile client branches on
 * `code` only; `message` is for logs and support, never for control flow.
 */
export const ErrorCode = z.enum([
  // 400
  'VALIDATION_FAILED',
  'MALFORMED_REQUEST',
  'UNSUPPORTED_CLIENT_VERSION',
  // 401
  'UNAUTHENTICATED',
  'TOKEN_EXPIRED',
  'TOKEN_REVOKED',
  'OTP_INVALID',
  'OTP_EXPIRED',
  // 403
  'FORBIDDEN',
  'DEVICE_NOT_BOUND',
  'DEVICE_INTEGRITY_FAILED',
  'SHIFT_NOT_ACTIVE',
  'GEOFENCE_VIOLATION',
  'WORKFLOW_STEP_OUT_OF_ORDER',
  // 404
  'NOT_FOUND',
  // 409
  'CONFLICT',
  'VERSION_MISMATCH',
  'IDEMPOTENCY_KEY_REUSED',
  'TASK_ALREADY_FINALIZED',
  'WORKFLOW_VERSION_SUPERSEDED',
  /**
   * The evidence a step refers to has not finished uploading yet. Only the
   * offline queue ever sees this: it defers the event instead of dropping it,
   * because the media will arrive on its own.
   */
  'MEDIA_NOT_READY',
  // 413 / 415
  'PAYLOAD_TOO_LARGE',
  'UNSUPPORTED_MEDIA_TYPE',
  // 422
  'BUSINESS_RULE_VIOLATION',
  'EVIDENCE_INCOMPLETE',
  // 429
  'RATE_LIMITED',
  // 5xx
  'INTERNAL_ERROR',
  'UPSTREAM_UNAVAILABLE',
  'UPSTREAM_TIMEOUT',
]);
export type ErrorCode = z.infer<typeof ErrorCode>;

export const ErrorDetail = z
  .object({
    /** JSON Pointer into the request body, or a dotted field path. */
    field: z.string().nullish(),
    issue: z.string(),
    meta: z.record(z.unknown()).nullish(),
  })
  .openapi('ErrorDetail');

export const ErrorResponse = z
  .object({
    error: z.object({
      code: ErrorCode,
      /** Turkish, safe to surface to the courier when `userVisible` is true. */
      message: z.string(),
      userVisible: z.boolean().default(false),
      traceId: z.string().openapi({ example: '0af7651916cd43dd8448eb211c80319c' }),
      details: z.array(ErrorDetail).nullish(),
      /** Present on 429 and on retryable 5xx. Seconds. */
      retryAfter: z.number().int().positive().nullish(),
    }),
  })
  .openapi('ErrorResponse');
export type ErrorResponse = z.infer<typeof ErrorResponse>;

/** Maps every error code onto the HTTP status the API must return. */
export const ERROR_STATUS: Record<ErrorCode, number> = {
  VALIDATION_FAILED: 400,
  MALFORMED_REQUEST: 400,
  UNSUPPORTED_CLIENT_VERSION: 400,
  UNAUTHENTICATED: 401,
  TOKEN_EXPIRED: 401,
  TOKEN_REVOKED: 401,
  OTP_INVALID: 401,
  OTP_EXPIRED: 401,
  FORBIDDEN: 403,
  DEVICE_NOT_BOUND: 403,
  DEVICE_INTEGRITY_FAILED: 403,
  SHIFT_NOT_ACTIVE: 403,
  GEOFENCE_VIOLATION: 403,
  WORKFLOW_STEP_OUT_OF_ORDER: 403,
  NOT_FOUND: 404,
  CONFLICT: 409,
  VERSION_MISMATCH: 409,
  IDEMPOTENCY_KEY_REUSED: 409,
  TASK_ALREADY_FINALIZED: 409,
  WORKFLOW_VERSION_SUPERSEDED: 409,
  MEDIA_NOT_READY: 409,
  PAYLOAD_TOO_LARGE: 413,
  UNSUPPORTED_MEDIA_TYPE: 415,
  BUSINESS_RULE_VIOLATION: 422,
  EVIDENCE_INCOMPLETE: 422,
  RATE_LIMITED: 429,
  INTERNAL_ERROR: 500,
  UPSTREAM_UNAVAILABLE: 503,
  UPSTREAM_TIMEOUT: 504,
};

/**
 * Codes the offline queue must not retry: replaying them can only fail again
 * or, worse, duplicate work. Everything else is retried with backoff.
 */
export const NON_RETRYABLE_ERRORS: readonly ErrorCode[] = [
  'VALIDATION_FAILED',
  'MALFORMED_REQUEST',
  'UNSUPPORTED_CLIENT_VERSION',
  'FORBIDDEN',
  'NOT_FOUND',
  'TASK_ALREADY_FINALIZED',
  'WORKFLOW_VERSION_SUPERSEDED',
  'BUSINESS_RULE_VIOLATION',
  'EVIDENCE_INCOMPLETE',
  'UNSUPPORTED_MEDIA_TYPE',
];

/* ------------------------------------------------------------------ *
 * Pagination
 * ------------------------------------------------------------------ */

export const CursorPageQuery = z.object({
  cursor: z.string().nullish().describe('Onceki yanittaki nextCursor'),
  limit: z.coerce.number().int().min(1).max(200).default(50),
});

export function cursorPage<T extends z.ZodTypeAny>(item: T, name: string) {
  return z
    .object({
      items: z.array(item),
      nextCursor: z.string().nullable().describe('null ise son sayfa'),
      /** Server clock at read time; clients use it as the next `since` watermark. */
      syncedAt: Timestamp,
    })
    .openapi(name);
}

/* ------------------------------------------------------------------ *
 * Shared headers
 * ------------------------------------------------------------------ */

export const IdempotencyKeyHeader = z
  .string()
  .uuid()
  .describe(
    'Her mutasyon istegi icin istemcinin urettigi UUID. Ayni anahtarla gelen tekrar ' +
      'istekleri ilk yanitin aynisini doner. Offline kuyrukta zorunlu.',
  );

/** Sent by the mobile app on every request so the API can gate old builds. */
export const ClientInfoHeader = z
  .string()
  .regex(/^dijigoo-courier\/\d+\.\d+\.\d+ \((android|ios); build \d+\)$/)
  .openapi({ example: 'dijigoo-courier/1.0.0 (android; build 42)' });
