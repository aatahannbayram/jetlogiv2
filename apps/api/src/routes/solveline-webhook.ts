import { parseOriginateResult, shouldCopyRecording } from '@dijigoo/core';
import { maskedCallSessions } from '@dijigoo/db';
import { eq, or } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import type { AppContext } from '../context.js';
import { serviceRouteRateLimit } from '../rate-limits.js';
import { storeSolvelineRecording } from '../services/solveline-recording.js';

const Query = z.object({ token: z.string().optional() });

export async function solvelineWebhookRoutes(app: FastifyInstance, { ctx }: { ctx: AppContext }) {
  app.addContentTypeParser('application/x-www-form-urlencoded', { parseAs: 'string' }, (_req, body, done) => {
    try {
      const params = new URLSearchParams(body as string);
      done(null, Object.fromEntries(params.entries()));
    } catch (err) {
      done(err as Error);
    }
  });

  app.post(
    '/v1/webhooks/solveline/call',
    {
      config: { rateLimit: serviceRouteRateLimit },
      schema: { tags: ['Ivr'], querystring: Query },
    },
    async (request, reply) => {
      await app.authenticateSolvelineWebhook(request);
      const parsed = parseOriginateResult(request.body) ?? parseOriginateResult(request.query);
      if (!parsed?.uniqueId && !parsed?.variable) {
        return reply.code(200).send({ ok: true, ignored: true });
      }

      const conditions = [];
      if (parsed.uniqueId) conditions.push(eq(maskedCallSessions.providerSessionId, parsed.uniqueId));
      if (parsed.variable && isUuid(parsed.variable)) {
        conditions.push(eq(maskedCallSessions.id, parsed.variable));
      }
      if (conditions.length === 0) {
        return reply.code(200).send({ ok: true, ignored: true });
      }

      const [session] = await ctx.db
        .select()
        .from(maskedCallSessions)
        .where(or(...conditions)!)
        .limit(1);

      if (!session) {
        request.log.warn({ uniqueid: parsed.uniqueId }, 'solveline webhook: session yok');
        return reply.code(200).send({ ok: true, unknown: true });
      }

      const duration = Number.parseInt(parsed.callDuration ?? '', 10);
      const patch: Partial<typeof maskedCallSessions.$inferInsert> = {
        connectedAt: session.connectedAt ?? new Date(),
        durationSeconds: Number.isFinite(duration) ? duration : session.durationSeconds,
      };
      if (parsed.uniqueId && !session.providerSessionId) {
        patch.providerSessionId = parsed.uniqueId;
      }
      await ctx.db.update(maskedCallSessions).set(patch).where(eq(maskedCallSessions.id, session.id));

      const answered = (parsed.status ?? '').toUpperCase() === 'ANSWER';
      const uniqueId = parsed.uniqueId ?? session.providerSessionId;
      if (
        answered &&
        uniqueId &&
        ctx.solvelineCall &&
        !session.hasRecording &&
        shouldCopyRecording(parsed.application)
      ) {
        try {
          await storeSolvelineRecording(ctx, ctx.solvelineCall, { ...session, ...patch }, uniqueId, new Date());
        } catch (err) {
          request.log.warn({ err }, 'solveline recording copy failed');
        }
      }

      return { ok: true };
    },
  );
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}
