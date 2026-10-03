CREATE TABLE IF NOT EXISTS "ivr_results" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"unique_id" varchar(160) NOT NULL,
	"variable" varchar(500),
	"selection" varchar(40) NOT NULL,
	"dtmf" varchar(16),
	"called_at" timestamp with time zone,
	"payload" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "ivr_results_unique_id_uq" ON "ivr_results" USING btree ("unique_id");
