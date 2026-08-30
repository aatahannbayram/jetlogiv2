import { defineConfig } from 'drizzle-kit';

export default defineConfig({
  dialect: 'postgresql',
  schema: './src/schema/index.ts',
  out: './migrations',
  dbCredentials: {
    url: process.env['DATABASE_URL'] ?? 'postgres://dijigoo:dijigoo@localhost:5432/dijigoo',
  },
  verbose: true,
  strict: true,
  /**
   * PostGIS creates these in the public schema. Without the filter drizzle-kit
   * proposes dropping them on every generate.
   */
  tablesFilter: ['!spatial_ref_sys', '!geography_columns', '!geometry_columns'],
});
