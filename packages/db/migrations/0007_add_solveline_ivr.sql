ALTER TABLE "tasks" ADD COLUMN IF NOT EXISTS "contact_phone_hmac" varchar(64);
--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "tasks_contact_phone_hmac_idx" ON "tasks" USING btree ("contact_phone_hmac") WHERE contact_phone_hmac is not null;
--> statement-breakpoint
ALTER TABLE "support_tickets" ALTER COLUMN "courier_id" DROP NOT NULL;
--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "masked_calls_provider_session_uq" ON "masked_call_sessions" USING btree ("provider_session_id") WHERE provider_session_id is not null;
--> statement-breakpoint
ALTER TYPE "public"."support_category" ADD VALUE IF NOT EXISTS 'EXPEDITE';
