-- Runs before every drizzle migration. Must be idempotent.

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
-- Trigram index support for barcode / reference "contains" search in the panel.
CREATE EXTENSION IF NOT EXISTS pg_trgm;
