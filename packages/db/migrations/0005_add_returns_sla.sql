CREATE TYPE "public"."return_status_code" AS ENUM('RET-010', 'RET-020', 'RET-030', 'RET-040', 'RET-050', 'RET-060', 'RET-070', 'RET-080', 'RET-090', 'RET-100', 'RET-110');--> statement-breakpoint
CREATE TYPE "public"."sla_status_code" AS ENUM('SLA-010', 'SLA-020', 'SLA-030', 'SLA-040', 'SLA-050', 'SLA-060', 'SLA-070', 'SLA-080', 'SLA-090', 'SLA-100');--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "returns" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"tenant_id" uuid NOT NULL,
	"task_id" uuid NOT NULL,
	"custody_item_id" uuid NOT NULL,
	"status" "return_status_code" DEFAULT 'RET-010' NOT NULL,
	"reason" varchar(160),
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "return_transitions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"return_id" uuid NOT NULL,
	"from_status" "return_status_code",
	"to_status" "return_status_code" NOT NULL,
	"reason" varchar(160),
	"occurred_at" timestamp with time zone NOT NULL,
	"recorded_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "sla_instances" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"tenant_id" uuid NOT NULL,
	"subject_type" varchar(20) NOT NULL,
	"subject_id" uuid NOT NULL,
	"target_at" timestamp with time zone NOT NULL,
	"status" "sla_status_code" DEFAULT 'SLA-010' NOT NULL,
	"started_at" timestamp with time zone NOT NULL,
	"resolved_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "returns" ADD CONSTRAINT "returns_tenant_id_tenants_id_fk" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE restrict ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "returns" ADD CONSTRAINT "returns_custody_item_id_custody_items_id_fk" FOREIGN KEY ("custody_item_id") REFERENCES "public"."custody_items"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "return_transitions" ADD CONSTRAINT "return_transitions_return_id_returns_id_fk" FOREIGN KEY ("return_id") REFERENCES "public"."returns"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "sla_instances" ADD CONSTRAINT "sla_instances_tenant_id_tenants_id_fk" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE restrict ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "returns_custody_item_uq" ON "returns" USING btree ("custody_item_id");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "returns_task_idx" ON "returns" USING btree ("task_id");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "return_transitions_return_idx" ON "return_transitions" USING btree ("return_id","recorded_at");--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "sla_instances_subject_uq" ON "sla_instances" USING btree ("subject_type","subject_id");
