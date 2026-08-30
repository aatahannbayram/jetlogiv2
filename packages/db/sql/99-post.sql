-- Runs after every drizzle migration. Must be idempotent.
-- Holds the constraints drizzle-kit cannot express: triggers, partitions and
-- the immutability rules that must not depend on application code.

/* ------------------------------------------------------------------ *
 * updated_at maintenance
 * ------------------------------------------------------------------ */

CREATE OR REPLACE FUNCTION touch_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'tenants', 'branches', 'couriers', 'workflows', 'shifts', 'tasks', 'support_tickets'
  ] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %I_touch_updated_at ON %I', t, t);
    EXECUTE format(
      'CREATE TRIGGER %I_touch_updated_at BEFORE UPDATE ON %I
         FOR EACH ROW EXECUTE FUNCTION touch_updated_at()', t, t);
  END LOOP;
END;
$$;

/* ------------------------------------------------------------------ *
 * Optimistic concurrency
 *
 * row_version is bumped by the database, not by the application. If it were
 * application-managed, one forgotten increment would silently disable the
 * conflict detection that the offline queue depends on.
 * ------------------------------------------------------------------ */

CREATE OR REPLACE FUNCTION bump_row_version() RETURNS trigger AS $$
BEGIN
  NEW.row_version := OLD.row_version + 1;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tasks_bump_row_version ON tasks;
CREATE TRIGGER tasks_bump_row_version BEFORE UPDATE ON tasks
  FOR EACH ROW EXECUTE FUNCTION bump_row_version();

DROP TRIGGER IF EXISTS custody_items_bump_row_version ON custody_items;
CREATE TRIGGER custody_items_bump_row_version BEFORE UPDATE ON custody_items
  FOR EACH ROW EXECUTE FUNCTION bump_row_version();

/* ------------------------------------------------------------------ *
 * Workflow immutability (rule K2)
 *
 * A published definition may only ever move to 'archived'. Everything else is
 * rejected here so no code path, migration or manual UPDATE can rewrite the
 * rules a completed delivery was carried out under.
 * ------------------------------------------------------------------ */

CREATE OR REPLACE FUNCTION guard_published_workflow() RETURNS trigger AS $$
BEGIN
  IF OLD.status = 'published' THEN
    IF NEW.status = 'archived'
       AND NEW.steps IS NOT DISTINCT FROM OLD.steps
       AND NEW.outcomes IS NOT DISTINCT FROM OLD.outcomes
       AND NEW.version = OLD.version
       AND NEW.key = OLD.key
       AND NEW.min_app_build = OLD.min_app_build THEN
      RETURN NEW;
    END IF;

    RAISE EXCEPTION
      'Yayinlanmis workflow degistirilemez (key=%, version=%). Yeni surum olusturun.',
      OLD.key, OLD.version
      USING ERRCODE = 'restrict_violation';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS workflows_guard_published ON workflows;
CREATE TRIGGER workflows_guard_published BEFORE UPDATE ON workflows
  FOR EACH ROW EXECUTE FUNCTION guard_published_workflow();

CREATE OR REPLACE FUNCTION guard_workflow_delete() RETURNS trigger AS $$
BEGIN
  IF OLD.status = 'published' THEN
    RAISE EXCEPTION 'Yayinlanmis workflow silinemez, arsivleyin.'
      USING ERRCODE = 'restrict_violation';
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS workflows_guard_delete ON workflows;
CREATE TRIGGER workflows_guard_delete BEFORE DELETE ON workflows
  FOR EACH ROW EXECUTE FUNCTION guard_workflow_delete();

/* ------------------------------------------------------------------ *
 * Task pinning (rule K3)
 *
 * Once a task has started, its workflow version cannot move. Otherwise a
 * courier's wizard would change shape halfway through.
 * ------------------------------------------------------------------ */

CREATE OR REPLACE FUNCTION guard_task_workflow_pin() RETURNS trigger AS $$
BEGIN
  IF OLD.started_at IS NOT NULL
     AND (NEW.workflow_id IS DISTINCT FROM OLD.workflow_id
          OR NEW.workflow_version IS DISTINCT FROM OLD.workflow_version) THEN
    RAISE EXCEPTION
      'Baslamis gorevin workflow surumu degistirilemez (task=%).', OLD.id
      USING ERRCODE = 'restrict_violation';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tasks_guard_workflow_pin ON tasks;
CREATE TRIGGER tasks_guard_workflow_pin BEFORE UPDATE ON tasks
  FOR EACH ROW EXECUTE FUNCTION guard_task_workflow_pin();

/* ------------------------------------------------------------------ *
 * location_pings partitioning
 *
 * Native range partitioning by captured_at, one partition per month.
 * Retention then becomes DROP TABLE instead of a DELETE that would leave the
 * heap bloated and the autovacuum permanently behind.
 * ------------------------------------------------------------------ */

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_partitioned_table pt
    JOIN pg_class c ON c.oid = pt.partrelid
    WHERE c.relname = 'location_pings'
  ) THEN
    -- drizzle-kit created a plain table; convert it once, while it is empty.
    ALTER TABLE location_pings RENAME TO location_pings_unpartitioned;

    CREATE TABLE location_pings (LIKE location_pings_unpartitioned INCLUDING ALL)
      PARTITION BY RANGE (captured_at);

    DROP TABLE location_pings_unpartitioned;
  END IF;
END;
$$;

-- Creates the partition covering a given month, plus the next one, so an
-- insert at 23:59 on the last day of the month never fails.
CREATE OR REPLACE FUNCTION ensure_location_partition(target date) RETURNS void AS $$
DECLARE
  start_at date := date_trunc('month', target)::date;
  end_at   date := (date_trunc('month', target) + interval '1 month')::date;
  part     text := format('location_pings_%s', to_char(start_at, 'YYYY_MM'));
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname = part) THEN
    EXECUTE format(
      'CREATE TABLE %I PARTITION OF location_pings FOR VALUES FROM (%L) TO (%L)',
      part, start_at, end_at);
  END IF;
END;
$$ LANGUAGE plpgsql;

SELECT ensure_location_partition(current_date);
SELECT ensure_location_partition((current_date + interval '1 month')::date);

/* ------------------------------------------------------------------ *
 * Geography expression indexes
 *
 * Columns are geometry, but every proximity query asks for metres and so
 * casts to geography. Without these the cast would defeat the plain geometry
 * index and fall back to a sequential scan.
 * ------------------------------------------------------------------ */

CREATE INDEX IF NOT EXISTS tasks_position_geog_idx
  ON tasks USING gist ((position::geography));

CREATE INDEX IF NOT EXISTS branches_location_geog_idx
  ON branches USING gist ((location::geography));

CREATE INDEX IF NOT EXISTS geocode_cache_position_geog_idx
  ON geocode_cache USING gist ((position::geography));

/* ------------------------------------------------------------------ *
 * Panel search
 * ------------------------------------------------------------------ */

CREATE INDEX IF NOT EXISTS tasks_reference_trgm_idx
  ON tasks USING gin (reference gin_trgm_ops);

CREATE INDEX IF NOT EXISTS task_items_barcode_trgm_idx
  ON task_items USING gin (barcode gin_trgm_ops);
