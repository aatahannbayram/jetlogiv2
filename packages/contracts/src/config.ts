import { PhoneNumber, Timestamp, z } from './common.js';

/**
 * GET /v1/config — kimlik gerekmez. Zorunlu güncelleme, feature flag ve
 * destek hattı tek kaynaktan gelir. Splash bu yanıtı beklemeden ilerleyemez.
 */
export const AppConfig = z
  .object({
    environment: z.enum(['production', 'staging', 'demo']),
    minAndroidBuild: z.number().int().positive(),
    minIosBuild: z.number().int().positive(),
    forceUpdate: z.boolean(),
    storeUrlAndroid: z.string().url().nullish(),
    storeUrlIos: z.string().url().nullish(),
    supportPhone: PhoneNumber.nullish(),
    /** Paneldeki açık zimmet uyarısı için arama numarası. */
    opsPhone: PhoneNumber.nullish(),
    geofenceDefaultRadiusMeters: z.number().int().min(150).max(250).default(200),
    geofenceMaxAccuracyMeters: z.number().int().min(50).max(150).default(100),
    featureFlags: z.object({
      maskedCall: z.boolean(),
      cashCollect: z.boolean(),
      documentScan: z.boolean(),
      custody: z.boolean(),
      shiftFaceMatch: z.boolean().default(false),
      offlineSync: z.boolean(),
    }),
    publishedAt: Timestamp,
  })
  .openapi('AppConfig');
export type AppConfig = z.infer<typeof AppConfig>;
