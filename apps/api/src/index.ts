import { buildApp } from './app.js';
import { createContext } from './context.js';
import { loadEnv } from './env.js';

const env = loadEnv();
const ctx = createContext(env);
const app = await buildApp(ctx);

/**
 * A courier mid-wizard when a deploy lands must be able to finish the request.
 * Fastify stops accepting new connections, drains in-flight ones, then the
 * pool and Redis are released.
 */
async function shutdown(signal: string) {
  app.log.info({ signal }, 'kapaniyor');
  const timer = setTimeout(() => {
    app.log.error('drain zaman asimina ugradi, zorla cikiliyor');
    process.exit(1);
  }, 15_000);
  timer.unref();

  try {
    await app.close();
    await ctx.close();
    process.exit(0);
  } catch (error) {
    app.log.error({ err: error }, 'kapanis hatasi');
    process.exit(1);
  }
}

for (const signal of ['SIGTERM', 'SIGINT'] as const) {
  process.on(signal, () => void shutdown(signal));
}

process.on('unhandledRejection', (reason) => {
  app.log.error({ err: reason }, 'islenmemis reddetme');
});

try {
  await app.listen({ port: env.API_PORT, host: env.API_HOST });
} catch (error) {
  app.log.error({ err: error }, 'sunucu baslatilamadi');
  process.exit(1);
}
