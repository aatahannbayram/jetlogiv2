CREATE TYPE "public"."document_status_code" AS ENUM('DOC-010', 'DOC-020', 'DOC-030', 'DOC-040', 'DOC-050', 'DOC-060', 'DOC-070', 'DOC-080', 'DOC-090', 'DOC-100', 'DOC-110', 'DOC-120', 'DOC-130', 'DOC-140', 'DOC-150', 'DOC-160', 'DOC-170', 'DOC-180', 'DOC-190', 'DOC-200', 'DOC-210', 'DOC-220');--> statement-breakpoint
CREATE TYPE "public"."quality_review_status_code" AS ENUM('QUA-010', 'QUA-020', 'QUA-030', 'QUA-040', 'QUA-050', 'QUA-060', 'QUA-070', 'QUA-080', 'QUA-090', 'QUA-100');--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "documents" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"tenant_id" uuid NOT NULL,
	"task_id" uuid NOT NULL,
	"source_step_key" varchar(60) NOT NULL,
	"media_id" uuid,
	"status" "document_status_code" DEFAULT 'DOC-010' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "document_transitions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"document_id" uuid NOT NULL,
	"from_status" "document_status_code",
	"to_status" "document_status_code" NOT NULL,
	"reason" varchar(160),
	"occurred_at" timestamp with time zone NOT NULL,
	"recorded_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "quality_reviews" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"tenant_id" uuid NOT NULL,
	"subject_type" varchar(20) NOT NULL,
	"subject_id" uuid NOT NULL,
	"status" "quality_review_status_code" NOT NULL,
	"reason" varchar(160),
	"occurred_at" timestamp with time zone NOT NULL,
	"recorded_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "documents" ADD CONSTRAINT "documents_tenant_id_tenants_id_fk" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE restrict ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "documents" ADD CONSTRAINT "documents_media_id_media_id_fk" FOREIGN KEY ("media_id") REFERENCES "public"."media"("id") ON DELETE set null ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "document_transitions" ADD CONSTRAINT "document_transitions_document_id_documents_id_fk" FOREIGN KEY ("document_id") REFERENCES "public"."documents"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "quality_reviews" ADD CONSTRAINT "quality_reviews_tenant_id_tenants_id_fk" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE restrict ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "documents_task_step_uq" ON "documents" USING btree ("task_id","source_step_key");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "documents_task_idx" ON "documents" USING btree ("task_id");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "document_transitions_doc_idx" ON "document_transitions" USING btree ("document_id","recorded_at");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "quality_reviews_subject_idx" ON "quality_reviews" USING btree ("subject_type","subject_id");
