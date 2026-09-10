import { ErrorResponse, RoutingOptimizeRequest, RoutingOptimizeResponse } from '@dijigoo/contracts';
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';

import type { AppContext } from '../context.js';
import { serviceRouteRateLimit } from '../rate-limits.js';
import { buildOptimizedRoute } from '../services/routing-optimize.js';

/**
 * Stateless routing-as-a-service for another team's backend (jetlogi-panel)
 * to call — see `docs/05-panel-entegrasyonu.md` Faz 4. Unlike
 * `GET /v1/routes/current`, this reads no `tasks`/`shifts` row and writes
 * nothing: the caller owns its own stops and whatever it does with the
 * result. Same engine (`services/routing-optimize.ts`) as the courier
 * endpoint, so the two never drift apart.
 */
export async function routingServiceRoutes(app: FastifyInstance, { ctx }: { ctx: AppContext }) {
  const route = app.withTypeProvider<ZodTypeProvider>();

  route.post(
    '/v1/routing/optimize',
    {
      config: { rateLimit: serviceRouteRateLimit },
      schema: {
        tags: ['Routing'],
        summary: 'Verilen duraklar icin en iyi sirayi hesapla (servisler-arasi)',
        body: RoutingOptimizeRequest,
        response: { 200: RoutingOptimizeResponse, 401: ErrorResponse },
      },
    },
    async (request) => {
      await app.authenticateService(request);
      const { stops, startAt } = request.body;
      return buildOptimizedRoute(ctx.routing, stops, startAt ? new Date(startAt) : undefined);
    },
  );
}
