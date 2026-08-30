import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { sql } from 'drizzle-orm';
import { z } from 'zod';

import type { AppContext } from '../context.js';

const Health = z.object({
  status: z.enum(['ok', 'degraded']),
  version: z.string(),
  checks: z.record(z.object({ ok: z.boolean(), latencyMs: z.number().nullable(), error: z.string().nullable() })),
});

export async function healthRoutes(app: FastifyInstance, { ctx }: { ctx: AppContext }) {
  const route = app.withTypeProvider<ZodTypeProvider>();

  /** Liveness: is the process up. Never touches a dependency. */
  route.get('/health', { schema: { response: { 200: z.object({ status: z.literal('ok') }) } } }, async () => ({
    status: 'ok' as const,
  }));

  /**
   * Readiness. Reports `degraded` rather than failing when Redis is down,
   * because rate limiting can fall back to in-process counters but deliveries
   * must keep flowing.
   */
  route.get('/ready', { schema: { response: { 200: Health, 503: Health } } }, async (_request, reply) => {
    const checks: z.infer<typeof Health>['checks'] = {};

    checks['database'] = await timed(async () => {
      await ctx.db.execute(sql`select 1`);
    });

    checks['redis'] = await timed(async () => {
      await ctx.redis.ping();
    });

    const databaseOk = checks['database']!.ok;
    const status = databaseOk ? ('ok' as const) : ('degraded' as const);

    return reply.status(databaseOk ? 200 : 503).send({
      status,
      version: process.env['npm_package_version'] ?? '0.0.0',
      checks,
    });
  });
}

async function timed(run: () => Promise<void>) {
  const started = performance.now();
  try {
    await run();
    return { ok: true, latencyMs: Math.round(performance.now() - started), error: null };
  } catch (error) {
    return {
      ok: false,
      latencyMs: Math.round(performance.now() - started),
      error: error instanceof Error ? error.message : String(error),
    };
  }
}
