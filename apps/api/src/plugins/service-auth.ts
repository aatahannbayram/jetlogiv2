import { timingSafeEqual } from 'node:crypto';

import { AppError } from '@dijigoo/core';
import type { FastifyInstance, FastifyRequest } from 'fastify';
import fp from 'fastify-plugin';

import type { AppContext } from '../context.js';

declare module 'fastify' {
  interface FastifyInstance {
    /** Faz 5: verifies the shared service token, not a courier bearer token. */
    authenticateService: (request: FastifyRequest) => Promise<void>;
  }
}

/**
 * Separate from `authenticate.ts` on purpose — this guards endpoints called
 * by another team's backend (the operations panel), which has no courier
 * identity and no place in `couriers`/`devices`. See project-nihai-mimari-plan:
 * no operator actor was added to this codebase, so this is deliberately the
 * thinnest possible boundary rather than a second identity system.
 */
export const serviceAuth = fp(async (app: FastifyInstance, opts: { ctx: AppContext }) => {
  const { ctx } = opts;
  const expected = Buffer.from(ctx.env.DELAY_DECISION_SERVICE_TOKEN);

  app.decorate('authenticateService', async (request: FastifyRequest): Promise<void> => {
    const header = request.headers['x-service-token'];
    if (typeof header !== 'string') throw new AppError('UNAUTHENTICATED');

    const provided = Buffer.from(header);
    // Length check first: timingSafeEqual throws on mismatched buffer
    // lengths rather than returning false.
    const isValid = provided.length === expected.length && timingSafeEqual(provided, expected);
    if (!isValid) throw new AppError('UNAUTHENTICATED');
  });
});
