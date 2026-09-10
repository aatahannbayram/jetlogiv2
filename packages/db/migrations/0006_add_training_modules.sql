CREATE TABLE IF NOT EXISTS "training_modules" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"tenant_id" uuid NOT NULL,
	"title" varchar(200) NOT NULL,
	"summary" varchar(500),
	"body" text NOT NULL,
	"sort_order" smallint DEFAULT 0 NOT NULL,
	"is_active" boolean DEFAULT true NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "training_completions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"courier_id" uuid NOT NULL,
	"module_id" uuid NOT NULL,
	"completed_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "training_modules" ADD CONSTRAINT "training_modules_tenant_id_tenants_id_fk" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE restrict ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "training_completions" ADD CONSTRAINT "training_completions_courier_id_couriers_id_fk" FOREIGN KEY ("courier_id") REFERENCES "public"."couriers"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "training_completions" ADD CONSTRAINT "training_completions_module_id_training_modules_id_fk" FOREIGN KEY ("module_id") REFERENCES "public"."training_modules"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "training_modules_tenant_order_idx" ON "training_modules" USING btree ("tenant_id","sort_order") WHERE is_active;--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "training_completions_courier_module_uq" ON "training_completions" USING btree ("courier_id","module_id");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "training_completions_courier_idx" ON "training_completions" USING btree ("courier_id");
