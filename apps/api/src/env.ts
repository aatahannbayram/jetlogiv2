import { z } from 'zod';

/**
 * Parsed once at boot. A missing secret should crash the process on start,
 * not surface as a 500 the first time a courier tries to log in.
 */
const EnvSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  API_PORT: z.coerce.number().int().positive().default(3001),
  API_HOST: z.string().default('0.0.0.0'),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace']).default('info'),

  DATABASE_URL: z.string().url(),
  DATABASE_POOL_MAX: z.coerce.number().int().positive().default(20),
  REDIS_URL: z.string().url(),

  JWT_ACCESS_SECRET: z.string().min(32, 'en az 32 karakter olmali'),
  JWT_REFRESH_SECRET: z.string().min(32, 'en az 32 karakter olmali'),
  JWT_ACCESS_TTL: z.coerce.number().int().positive().default(900),
  JWT_REFRESH_TTL: z.coerce.number().int().positive().default(2_592_000),
  JWT_ISSUER: z.string().default('dijigoo-api'),

  /** AES-256-GCM key, base64, exactly 32 bytes decoded. */
  FIELD_ENCRYPTION_KEY: z.string().min(32),

  S3_ENDPOINT: z.string().url(),
  S3_REGION: z.string().default('auto'),
  S3_BUCKET: z.string(),
  S3_SHIFT_PHOTO_BUCKET: z.string(),
  S3_ACCESS_KEY_ID: z.string(),
  S3_SECRET_ACCESS_KEY: z.string(),
  S3_FORCE_PATH_STYLE: z
    .string()
    .default('false')
    .transform((v) => v === 'true'),

  SMS_PROVIDER: z.enum(['mock', 'netgsm', 'verimor', 'iletimerkezi']).default('mock'),
  SMS_API_KEY: z.string().optional(),
  SMS_SENDER_ID: z.string().default('DIJIGOO'),

  MASKED_CALL_PROVIDER: z.enum(['mock', 'netgsm', 'verimor']).default('mock'),
  MASKED_CALL_API_KEY: z.string().optional(),

  /**
   * `osrm` is a self-hosted engine (see `infra/osrm/`) — real distance,
   * duration and geometry, no traffic. Faz 1 default is `mock` (straight-line)
   * so the API boots with zero external dependencies; docker-compose sets
   * this to `osrm` once the routing container is up.
   */
  ROUTING_PROVIDER: z.enum(['mock', 'osrm', 'openrouteservice']).default('mock'),
  ROUTING_API_KEY: z.string().optional(),
  OSRM_URL: z.string().url().default('http://localhost:5001'),
  /** Self-host yokken Türkiye dahil planet OSRM (project-osrm demo). */
  PUBLIC_OSRM_URL: z.string().url().default('https://router.project-osrm.org'),

  /**
   * Minimum app build the API will serve. Raised when a release ships a
   * mandatory client-side fix; older builds get UNSUPPORTED_CLIENT_VERSION.
   */
  MIN_SUPPORTED_APP_BUILD: z.coerce.number().int().positive().default(1),

  /**
   * Identity is owned by kurye.dijigoo.com. When set, availability/documents
   * are pulled server-to-server. Courier cookies are never forwarded.
   */
  IDENTITY_UPSTREAM: z.preprocess(
    (v) => (typeof v === 'string' && v.trim() === '' ? undefined : v),
    z.string().url().optional(),
  ),
  IDENTITY_INTERNAL_TOKEN: z.preprocess(
    (v) => (typeof v === 'string' && v.trim() === '' ? undefined : v),
    z.string().min(8).optional(),
  ),

  /**
   * Integrity enforcement. `off` in dev, `log` in staging, `restrict` in
   * production. Never `block`: a false positive would strand a courier.
   */
  DEVICE_INTEGRITY_MODE: z.enum(['off', 'log', 'restrict']).default('log'),

  /**
   * Shared secret for the operations panel's *backend* (jetlogi-panel, a
   * different team's codebase) to call our service-to-service endpoints —
   * originally just delay-decision (Faz 5), now also `/v1/routing/optimize`
   * (docs/05-panel-entegrasyonu.md Faz 4). Not a courier bearer token —
   * there is no operator identity in this codebase, see
   * project-nihai-mimari-plan. Rotate by issuing a new value to that team.
   */
  DELAY_DECISION_SERVICE_TOKEN: z.string().min(16),

  /**
   * FCM HTTP v1. Bos ise kutu yine yazilir, uzak push gitmez.
   * `FCM_SERVICE_ACCOUNT_JSON` servis hesabinin ham JSON'u.
   */
  FCM_PROJECT_ID: z.preprocess(
    (v) => (typeof v === 'string' && v.trim() === '' ? undefined : v),
    z.string().min(1).optional(),
  ),
  FCM_SERVICE_ACCOUNT_JSON: z.preprocess(
    (v) => (typeof v === 'string' && v.trim() === '' ? undefined : v),
    z.string().min(8).optional(),
  ),
});

export type Env = z.infer<typeof EnvSchema>;

export function loadEnv(source: NodeJS.ProcessEnv = process.env): Env {
  const result = EnvSchema.safeParse(source);
  if (!result.success) {
    const lines = result.error.issues.map((i) => `  ${i.path.join('.')}: ${i.message}`);
    throw new Error(`Ortam degiskenleri gecersiz:\n${lines.join('\n')}`);
  }
  return result.data;
}
