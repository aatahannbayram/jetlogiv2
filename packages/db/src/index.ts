import { drizzle } from 'drizzle-orm/postgres-js';
import type { PostgresJsDatabase } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';

import * as schema from './schema/index';

export * from './schema/index';
export { schema };

/**
 * Deliberately excludes the driver handle drizzle attaches, so a transaction
 * handle satisfies this type too. Every helper that writes to the database
 * takes a `Database` and can therefore be called inside or outside a
 * transaction without a second overload.
 */
export type Database = PostgresJsDatabase<typeof schema>;

export interface DatabaseOptions {
  url: string;
  /** Pool ceiling. Keep low on the worker, higher on the API. */
  max?: number;
  /** Logs every statement. Never enable in production: bodies contain PII. */
  debug?: boolean;
}

export function createDatabase({ url, max = 10, debug = false }: DatabaseOptions): Database {
  const client = postgres(url, {
    max,
    // Prepared statements break behind transaction-mode poolers such as
    // PgBouncer, which is how this will be deployed.
    prepare: false,
    types: {
      // Return numeric as string so money never round-trips through a float.
      bigint: postgres.BigInt,
    },
  });

  return drizzle(client, { schema, logger: debug });
}
