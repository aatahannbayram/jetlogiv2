import { CourierAvailability, CourierDocumentList, ErrorResponse } from '@dijigoo/contracts';
import {
  fallbackAvailability,
  fallbackDocuments,
  mapPanelAvailability,
  mapPanelDocuments,
  pullPanelJson,
} from '@dijigoo/core';
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';

import type { AppContext } from '../context.js';

/**
 * Token-auth facade over the onboarding identity. The phone never sees
 * `dijigoo_courier_session`.
 */
export async function identityRoutes(app: FastifyInstance, { ctx }: { ctx: AppContext }) {
  const route = app.withTypeProvider<ZodTypeProvider>();

  route.get(
    '/v1/me/availability',
    {
      schema: {
        tags: ['Identity'],
        response: { 200: CourierAvailability, 401: ErrorResponse },
      },
    },
    async (request) => {
      const auth = await app.authenticate(request);
      if (!ctx.env.IDENTITY_UPSTREAM) return fallbackAvailability();
      const raw = await pullPanelJson({
        origin: ctx.env.IDENTITY_UPSTREAM,
        path: '/api/public/v1/courier-availability',
        courierId: auth.courierId,
        token: ctx.env.IDENTITY_INTERNAL_TOKEN,
      });
      return raw ? mapPanelAvailability(raw) : fallbackAvailability();
    },
  );

  route.get(
    '/v1/me/documents',
    {
      schema: {
        tags: ['Identity'],
        response: { 200: CourierDocumentList, 401: ErrorResponse },
      },
    },
    async (request) => {
      const auth = await app.authenticate(request);
      if (!ctx.env.IDENTITY_UPSTREAM) return fallbackDocuments();
      const raw = await pullPanelJson({
        origin: ctx.env.IDENTITY_UPSTREAM,
        path: '/api/public/v1/courier-my-documents',
        courierId: auth.courierId,
        token: ctx.env.IDENTITY_INTERNAL_TOKEN,
      });
      return raw ? mapPanelDocuments(raw) : fallbackDocuments();
    },
  );
}
