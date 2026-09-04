import { z } from 'zod';

const EnvSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace']).default('info'),

  DATABASE_URL: z.string().url(),
  /** Kept low — the worker runs a handful of poll queries, not request traffic. */
  DATABASE_POOL_MAX: z.coerce.number().int().positive().default(5),

  WORKER_POLL_INTERVAL_MS: z.coerce.number().int().positive().default(60_000),
  /** How close to its deadline an SLA instance must be to flip to SLA-030 (Riskte). */
  SLA_RISK_WINDOW_MINUTES: z.coerce.number().int().positive().default(30),
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
