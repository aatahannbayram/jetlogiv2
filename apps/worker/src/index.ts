import { createDatabase } from '@dijigoo/db';

import { loadEnv } from './env.js';
import { flagAtRiskSlaInstances } from './sla-watcher.js';

const env = loadEnv();
const db = createDatabase({ url: env.DATABASE_URL, max: env.DATABASE_POOL_MAX });

function log(level: 'info' | 'error', msg: string, extra?: Record<string, unknown>) {
  // eslint-disable-next-line no-console
  console[level](JSON.stringify({ level, msg, time: new Date().toISOString(), ...extra }));
}

async function tick(): Promise<void> {
  try {
    const flagged = await flagAtRiskSlaInstances(db, { riskWindowMinutes: env.SLA_RISK_WINDOW_MINUTES });
    if (flagged.length > 0) {
      log('info', 'sla.at_risk flagged', { count: flagged.length });
    }
  } catch (error) {
    // A single bad tick must not kill the process — the next interval retries.
    log('error', 'sla-watcher tick failed', { error: error instanceof Error ? error.message : String(error) });
  }
}

log('info', 'apps/worker starting', {
  pollIntervalMs: env.WORKER_POLL_INTERVAL_MS,
  slaRiskWindowMinutes: env.SLA_RISK_WINDOW_MINUTES,
});

await tick();
setInterval(tick, env.WORKER_POLL_INTERVAL_MS);

for (const signal of ['SIGINT', 'SIGTERM'] as const) {
  process.on(signal, () => {
    log('info', `${signal} received, shutting down`);
    process.exit(0);
  });
}
