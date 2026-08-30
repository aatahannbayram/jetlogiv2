import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import Fastify from 'fastify';
import type { FastifyInstance } from 'fastify';
import { serializerCompiler, validatorCompiler } from 'fastify-type-provider-zod';

import type { AppContext } from './context.js';
import { authenticate } from './plugins/authenticate.js';
import { errorHandler } from './plugins/error-handler.js';
import { authRoutes } from './routes/auth.js';
import { configRoutes } from './routes/config.js';
import { custodyRoutes } from './routes/custody.js';
import { healthRoutes } from './routes/health.js';
import { identityRoutes } from './routes/identity.js';
import { mediaRoutes } from './routes/media.js';
import { routingRoutes } from './routes/routing.js';
import { shiftRoutes } from './routes/shift.js';
import { syncRoutes } from './routes/sync.js';
import { taskRoutes } from './routes/task.js';
import { workflowRoutes } from './routes/workflow.js';

export async function buildApp(ctx: AppContext): Promise<FastifyInstance> {
  const app = Fastify({
    logger: {
      level: ctx.env.LOG_LEVEL,
      ...(ctx.env.NODE_ENV === 'development'
        ? { transport: { target: 'pino-pretty', options: { translateTime: 'HH:MM:ss', ignore: 'pid,hostname' } } }
        : {}),
      redact: {
        // Tokens, codes and recipient phone numbers must never reach the log
        // aggregator. Redaction happens here rather than at each call site so
        // one forgotten log line cannot leak them.
        paths: [
          'req.headers.authorization',
          'req.headers["idempotency-key"]',
          'req.body.code',
          'req.body.refreshToken',
          'req.body.phone',
          'res.body.tokens',
        ],
        censor: '[redacted]',
      },
    },
    // Trust the ingress for client IP; rate limiting is per courier, not per
    // proxy socket.
    trustProxy: true,
    bodyLimit: 1 * 1024 * 1024,
    requestIdHeader: 'x-request-id',
    genReqId: () => crypto.randomUUID(),
  });

  app.setValidatorCompiler(validatorCompiler);
  app.setSerializerCompiler(serializerCompiler);

  await app.register(helmet, { contentSecurityPolicy: false });
  await app.register(cors, {
    // Only the panel calls this API from a browser; the mobile app is not
    // subject to CORS at all.
    origin: ctx.env.NODE_ENV === 'production' ? [/\.dijigoo\.example$/] : true,
    credentials: true,
  });

  await app.register(rateLimit, {
    global: true,
    max: 300,
    timeWindow: '1 minute',
    redis: ctx.redis,
    // Key on the courier when authenticated so a shared NAT at a depot does
    // not rate-limit an entire branch as one client.
    keyGenerator: (request) => request.courier?.courierId ?? request.ip,
  });

  await app.register(errorHandler);
  await app.register(authenticate, { ctx });

  await app.register(healthRoutes, { ctx });
  await app.register(configRoutes, { ctx });
  await app.register(authRoutes, { ctx });
  await app.register(identityRoutes, { ctx });
  await app.register(workflowRoutes, { ctx });
  await app.register(taskRoutes, { ctx });
  await app.register(shiftRoutes, { ctx });
  await app.register(routingRoutes, { ctx });
  await app.register(custodyRoutes, { ctx });
  await app.register(mediaRoutes, { ctx });
  // Registered last on purpose: it re-dispatches into the routes above via
  // app.inject, so they must already exist.
  await app.register(syncRoutes, { ctx });

  return app;
}
