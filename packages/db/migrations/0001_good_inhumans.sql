ALTER TABLE "tasks" ADD COLUMN "previous_courier_id" uuid;--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "tasks" ADD CONSTRAINT "tasks_previous_courier_id_couriers_id_fk" FOREIGN KEY ("previous_courier_id") REFERENCES "public"."couriers"("id") ON DELETE set null ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "tasks_previous_courier_idx" ON "tasks" USING btree ("previous_courier_id","updated_at") WHERE previous_courier_id is not null;