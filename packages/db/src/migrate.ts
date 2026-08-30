import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { drizzle } from 'drizzle-orm/postgres-js';
import { migrate } from 'drizzle-orm/postgres-js/migrator';
import postgres from 'postgres';

const packageRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');

const url = process.env['DATABASE_URL'];
if (!url) {
  console.error('DATABASE_URL tanimli degil.');
  process.exit(1);
}

// One connection, no pooling: migrations must run serially and some statements
// (CREATE EXTENSION, ALTER TABLE) cannot share a session with anything else.
// `IF NOT EXISTS` guards make the scripts re-runnable, and every guard that
// fires emits a NOTICE. Keep the ones that matter, drop the rest.
const client = postgres(url, {
  max: 1,
  prepare: false,
  onnotice: (notice) => {
    const message = notice.message ?? '';
    if (notice.severity === 'NOTICE' && /already exists|does not exist, skipping/.test(message)) return;
    console.log(`  ${notice.severity}: ${message}`);
  },
});

async function runSqlFile(relativePath: string) {
  const sql = readFileSync(resolve(packageRoot, relativePath), 'utf8');
  await client.unsafe(sql);
  console.log(`  uygulandi: ${relativePath}`);
}

try {
  console.log('Eklentiler...');
  await runSqlFile('sql/00-extensions.sql');

  console.log('Drizzle migrasyonlari...');
  await migrate(drizzle(client), { migrationsFolder: resolve(packageRoot, 'migrations') });

  console.log('Tetikleyiciler ve bolumleme...');
  await runSqlFile('sql/99-post.sql');

  console.log('Tamam.');
} catch (error) {
  console.error('Migrasyon basarisiz:', error);
  process.exitCode = 1;
} finally {
  await client.end();
}
