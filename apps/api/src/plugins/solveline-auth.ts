import { timingSafeEqual } from 'node:crypto';

import { AppError } from '@dijigoo/core';
import type { FastifyInstance, FastifyRequest } from 'fastify';
import fp from 'fastify-plugin';

import type { AppContext } from '../context.js';
import { ipAllowed, parseCidrList } from '../services/cidr.js';

declare module 'fastify' {
  interface FastifyInstance {
    authenticateSolvelineInbound: (request: FastifyRequest) => Promise<void>;
    authenticateSolvelineWebhook: (request: FastifyRequest) => Promise<void>;
  }
}

export const solvelineAuth = fp(async (app: FastifyInstance, opts: { ctx: AppContext }) => {
  const { ctx } = opts;

  app.decorate('authenticateSolvelineInbound', async (request: FastifyRequest): Promise<void> => {
    const expectedRaw = ctx.env.SOLVELINE_INBOUND_TOKEN;
    if (!expectedRaw) throw new AppError('UNAUTHENTICATED');
    const header = request.headers.authorization;
    if (!header?.startsWith('Bearer ')) throw new AppError('UNAUTHENTICATED');
    assertSecret(header.slice(7), expectedRaw);
    const allow = parseCidrList(ctx.env.SOLVELINE_INBOUND_CIDRS);
    if (!ipAllowed(request.ip, allow)) throw new AppError('UNAUTHENTICATED');
  });

  app.decorate('authenticateSolvelineWebhook', async (request: FastifyRequest): Promise<void> => {
    const expectedRaw = ctx.env.SOLVELINE_WEBHOOK_SECRET;
    if (!expectedRaw) throw new AppError('UNAUTHENTICATED');
    const provided =
      typeof request.query === 'object' && request.query && 'token' in request.query
        ? String((request.query as { token?: unknown }).token ?? '')
        : '';
    if (!provided) throw new AppError('UNAUTHENTICATED');
    assertSecret(provided, expectedRaw);
  });
});

function assertSecret(provided: string, expected: string): void {
  const a = Buffer.from(provided);
  const b = Buffer.from(expected);
  const ok = a.length === b.length && timingSafeEqual(a, b);
  if (!ok) throw new AppError('UNAUTHENTICATED');
}
