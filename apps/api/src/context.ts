import { createDatabase } from '@dijigoo/db';
import type { Database } from '@dijigoo/db';
import Redis from 'ioredis';

import type { Env } from './env.js';
import { IntegrityService } from './services/integrity.js';
import { OtpService } from './services/otp.js';
import { createRoutingProvider } from './services/routing.js';
import type { RoutingProvider } from './services/routing.js';
import { createSmsProvider } from './services/sms.js';
import type { SmsProvider } from './services/sms.js';
import { StorageService } from './services/storage.js';
import { TokenService } from './services/tokens.js';

/**
 * Everything a route handler might need, wired once at boot. Passed explicitly
 * rather than reached for through a module-level singleton so tests can build
 * a context against a scratch database without touching globals.
 */
export interface AppContext {
  env: Env;
  db: Database;
  redis: Redis;
  tokens: TokenService;
  otp: OtpService;
  sms: SmsProvider;
  routing: RoutingProvider;
  storage: StorageService;
  integrity: IntegrityService;
  close(): Promise<void>;
}

export function createContext(env: Env, log: (msg: string) => void = console.log): AppContext {
  const db = createDatabase({
    url: env.DATABASE_URL,
    max: env.DATABASE_POOL_MAX,
    debug: env.NODE_ENV === 'development' && env.LOG_LEVEL === 'trace',
  });

  const redis = new Redis(env.REDIS_URL, {
    maxRetriesPerRequest: null,
    // Never let a Redis hiccup take down request handling: rate limiting and
    // caching degrade, they do not block deliveries.
    enableOfflineQueue: false,
  });

  const sms = createSmsProvider(env, log);
  const routing = createRoutingProvider(env, log);

  return {
    env,
    db,
    redis,
    sms,
    routing,
    tokens: new TokenService(db, env),
    otp: new OtpService(db, sms),
    storage: new StorageService(env),
    integrity: new IntegrityService(env),
    async close() {
      redis.disconnect();
    },
  };
}
