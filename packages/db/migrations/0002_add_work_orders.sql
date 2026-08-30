CREATE TYPE "public"."work_order_status_code" AS ENUM('WO-010', 'WO-020', 'WO-030', 'WO-040', 'WO-050', 'WO-060', 'WO-070', 'WO-080', 'WO-090', 'WO-100', 'WO-110', 'WO-120', 'WO-130', 'WO-140');--> statement-breakpoint
CREATE TYPE "public"."delivery_result_code" AS ENUM('DLV-010', 'DLV-020', 'DLV-030', 'DLV-040', 'DLV-050', 'DLV-060', 'DLV-070', 'DLV-080', 'DLV-090', 'DLV-100', 'DLV-110', 'DLV-120', 'DLV-130', 'DLV-140', 'DLV-150', 'DLV-160', 'DLV-170', 'DLV-180', 'DLV-190', 'DLV-200', 'DLV-210', 'DLV-220');--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "work_orders" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"tenant_id" uuid NOT NULL,
	"reference" varchar(60) NOT NULL,
	"external_id" varchar(120),
	"status" "work_order_status_code" DEFAULT 'WO-070' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "work_order_transitions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"work_order_id" uuid NOT NULL,
	"from_status" "work_order_status_code",
	"to_status" "work_order_status_code" NOT NULL,
	"reason" varchar(160),
	"occurred_at" timestamp with time zone NOT NULL,
	"recorded_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "delivery_results" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"task_id" uuid NOT NULL,
	"work_order_id" uuid,
	"attempt_number" smallint NOT NULL,
	"code" "delivery_result_code" NOT NULL,
	"source_outcome_code" varchar(60),
	"note" text,
	"position" geometry(point,4326),
	"occurred_at" timestamp with time zone NOT NULL,
	"recorded_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "tasks" ADD COLUMN "work_order_id" uuid;--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "work_orders" ADD CONSTRAINT "work_orders_tenant_id_tenants_id_fk" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE restrict ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "work_order_transitions" ADD CONSTRAINT "work_order_transitions_work_order_id_work_orders_id_fk" FOREIGN KEY ("work_order_id") REFERENCES "public"."work_orders"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "delivery_results" ADD CONSTRAINT "delivery_results_work_order_id_work_orders_id_fk" FOREIGN KEY ("work_order_id") REFERENCES "public"."work_orders"("id") ON DELETE set null ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "tasks" ADD CONSTRAINT "tasks_work_order_id_work_orders_id_fk" FOREIGN KEY ("work_order_id") REFERENCES "public"."work_orders"("id") ON DELETE set null ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "work_orders_tenant_reference_uq" ON "work_orders" USING btree ("tenant_id","reference");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "work_orders_status_idx" ON "work_orders" USING btree ("tenant_id","status");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "work_order_transitions_wo_idx" ON "work_order_transitions" USING btree ("work_order_id","recorded_at");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "delivery_results_task_idx" ON "delivery_results" USING btree ("task_id","recorded_at");
