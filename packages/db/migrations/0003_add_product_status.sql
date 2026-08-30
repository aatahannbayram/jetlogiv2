CREATE TYPE "public"."product_status_code" AS ENUM('PRD-010', 'PRD-020', 'PRD-030', 'PRD-040', 'PRD-050', 'PRD-060', 'PRD-070', 'PRD-080', 'PRD-090', 'PRD-100', 'PRD-110', 'PRD-120', 'PRD-130', 'PRD-140', 'PRD-150', 'PRD-160', 'PRD-170', 'PRD-180', 'PRD-190', 'PRD-200', 'PRD-210');--> statement-breakpoint
ALTER TABLE "custody_items" ADD COLUMN "status" "product_status_code" DEFAULT 'PRD-100' NOT NULL;--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "custody_item_transitions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"item_id" uuid NOT NULL,
	"from_status" "product_status_code",
	"to_status" "product_status_code" NOT NULL,
	"reason" varchar(160),
	"occurred_at" timestamp with time zone NOT NULL,
	"recorded_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "custody_item_transitions" ADD CONSTRAINT "custody_item_transitions_item_id_custody_items_id_fk" FOREIGN KEY ("item_id") REFERENCES "public"."custody_items"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "custody_item_transitions_item_idx" ON "custody_item_transitions" USING btree ("item_id","recorded_at");
