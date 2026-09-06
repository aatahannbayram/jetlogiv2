import { AppConfig, ErrorResponse } from '@dijigoo/contracts';
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';

import type { AppContext } from '../context.js';

/**
 * Unauthenticated. Splash blocks until this returns. Cookie session is not
 * involved; the same payload is served to every build.
 */
export async function configRoutes(app: FastifyInstance, { ctx }: { ctx: AppContext }) {
  const route = app.withTypeProvider<ZodTypeProvider>();

  route.get(
    '/v1/config',
    {
      schema: {
        tags: ['Config'],
        response: { 200: AppConfig, 400: ErrorResponse },
      },
      config: { rateLimit: { max: 60, timeWindow: '1 minute' } },
    },
    async () => {
      const min = ctx.env.MIN_SUPPORTED_APP_BUILD;
      return {
        environment: ctx.env.NODE_ENV === 'production' ? ('production' as const) : ('demo' as const),
        minAndroidBuild: min,
        minIosBuild: min,
        forceUpdate: false,
        storeUrlAndroid: null,
        storeUrlIos: null,
        supportPhone: '+902124440026',
        opsPhone: '+902124440026',
        geofenceDefaultRadiusMeters: 200,
        geofenceMaxAccuracyMeters: 100,
        featureFlags: {
          maskedCall: true,
          cashCollect: true,
          documentScan: false,
          custody: false,
          shiftFaceMatch: false,
          offlineSync: true,
        },
        publishedAt: new Date().toISOString(),
      };
    },
  );
}
