CREATE TYPE "public"."actor_type" AS ENUM('courier', 'operator', 'system', 'integration');--> statement-breakpoint
CREATE TYPE "public"."counterparty_kind" AS ENUM('courier', 'branch', 'customer', 'warehouse');--> statement-breakpoint
CREATE TYPE "public"."courier_status" AS ENUM('active', 'suspended', 'terminated');--> statement-breakpoint
CREATE TYPE "public"."custody_direction" AS ENUM('handover', 'takeover');--> statement-breakpoint
CREATE TYPE "public"."custody_item_type" AS ENUM('parcel', 'document', 'cash', 'equipment');--> statement-breakpoint
CREATE TYPE "public"."device_platform" AS ENUM('android', 'ios');--> statement-breakpoint
CREATE TYPE "public"."integrity_action" AS ENUM('allow', 'restrict', 'review');--> statement-breakpoint
CREATE TYPE "public"."media_kind" AS ENUM('photo', 'document_page', 'document_pdf', 'signature', 'audio');--> statement-breakpoint
CREATE TYPE "public"."media_state" AS ENUM('pending', 'uploaded', 'verified', 'rejected', 'purged');--> statement-breakpoint
CREATE TYPE "public"."otp_channel" AS ENUM('sms', 'ivr');--> statement-breakpoint
CREATE TYPE "public"."otp_purpose" AS ENUM('activation', 'task_delivery', 'phone_change');--> statement-breakpoint
CREATE TYPE "public"."outbox_state" AS ENUM('pending', 'dispatched', 'failed', 'dead');--> statement-breakpoint
CREATE TYPE "public"."route_mode" AS ENUM('sequence_only', 'distance_optimized', 'traffic_aware');--> statement-breakpoint
CREATE TYPE "public"."shift_status" AS ENUM('active', 'paused', 'closed');--> statement-breakpoint
CREATE TYPE "public"."step_status" AS ENUM('completed', 'skipped');--> statement-breakpoint
CREATE TYPE "public"."step_type" AS ENUM('INSTRUCTION', 'GEOFENCE_CHECK', 'BARCODE_SCAN', 'PHOTO_EVIDENCE', 'DOCUMENT_SCAN', 'FORM', 'CHECKLIST', 'OTP_VERIFY', 'SIGNATURE', 'CASH_COLLECT', 'IDENTITY_CAPTURE');--> statement-breakpoint
CREATE TYPE "public"."support_category" AS ENUM('APP_ISSUE', 'ADDRESS_PROBLEM', 'RECIPIENT_UNREACHABLE', 'VEHICLE', 'ACCIDENT', 'SECURITY', 'PAYMENT', 'OTHER');--> statement-breakpoint
CREATE TYPE "public"."support_priority" AS ENUM('low', 'normal', 'high', 'critical');--> statement-breakpoint
CREATE TYPE "public"."support_status" AS ENUM('open', 'in_progress', 'resolved', 'closed');--> statement-breakpoint
CREATE TYPE "public"."task_priority" AS ENUM('normal', 'high', 'urgent');--> statement-breakpoint
CREATE TYPE "public"."task_status" AS ENUM('ASSIGNED', 'ACCEPTED', 'EN_ROUTE', 'ARRIVED', 'IN_PROGRESS', 'COMPLETED', 'FAILED', 'CANCELLED');--> statement-breakpoint
CREATE TYPE "public"."task_type" AS ENUM('DELIVERY', 'PICKUP', 'RETURN', 'SERVICE', 'DOCUMENT');--> statement-breakpoint
CREATE TYPE "public"."workflow_status" AS ENUM('draft', 'published', 'archived');--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "branches" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"tenant_id" uuid NOT NULL,
	"code" varchar(40) NOT NULL,
	"name" varchar(160) NOT NULL,
	"city" varchar(120) NOT NULL,
	"location" geometry(point,4326),
	"fence_radius_meters" varchar(10) DEFAULT '300',
	"is_active" boolean DEFAULT true NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "couriers" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"tenant_id" uuid NOT NULL,
	"branch_id" uuid,
	"phone" varchar(20) NOT NULL,
	"full_name" varchar(160) NOT NULL,
	"employee_code" varchar(40),
	"national_id_hash" varchar(64),
	"avatar_media_id" uuid,
	"status" "courier_status" DEFAULT 'active' NOT NULL,
	"capabilities" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"consents" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"suspended_reason" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "tenants" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" varchar(160) NOT NULL,
	"slug" varchar(60) NOT NULL,
	"settings" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "tenants_slug_unique" UNIQUE("slug")
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "devices" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"courier_id" uuid NOT NULL,
	"installation_id" uuid NOT NULL,
	"platform" "device_platform" NOT NULL,
	"os_version" varchar(40) NOT NULL,
	"model" varchar(80) NOT NULL,
	"manufacturer" varchar(80) NOT NULL,
	"app_version" varchar(20) NOT NULL,
	"app_build" integer NOT NULL,
	"push_token" varchar(512),
	"battery_optimization_exempt" boolean,
	"integrity_score" smallint,
	"integrity_action" "integrity_action" DEFAULT 'allow',
	"integrity_signals" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"integrity_checked_at" timestamp with time zone,
	"last_seen_at" timestamp with time zone,
	"bound_at" timestamp with time zone DEFAULT now() NOT NULL,
	"revoked_at" timestamp with time zone,
	"revoked_reason" varchar(120)
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "otp_challenges" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"purpose" "otp_purpose" NOT NULL,
	"channel" "otp_channel" DEFAULT 'sms' NOT NULL,
	"phone" varchar(20) NOT NULL,
	"code_hash" varchar(64) NOT NULL,
	"salt" varchar(32) NOT NULL,
	"courier_id" uuid,
	"task_id" uuid,
	"step_key" varchar(60),
	"integrity_nonce" varchar(128),
	"attempts" smallint DEFAULT 0 NOT NULL,
	"max_attempts" smallint DEFAULT 5 NOT NULL,
	"send_count" smallint DEFAULT 1 NOT NULL,
	"verified_at" timestamp with time zone,
	"consumed_at" timestamp with time zone,
	"expires_at" timestamp with time zone NOT NULL,
	"resend_available_at" timestamp with time zone NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "sessions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"courier_id" uuid NOT NULL,
	"device_id" uuid NOT NULL,
	"family_id" uuid NOT NULL,
	"refresh_token_hash" varchar(64) NOT NULL,
	"parent_id" uuid,
	"issued_at" timestamp with time zone DEFAULT now() NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"used_at" timestamp with time zone,
	"revoked_at" timestamp with time zone,
	"revoked_reason" varchar(120),
	"ip" varchar(45),
	"user_agent" varchar(255)
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "workflow_step_keys" (
	"tenant_id" uuid NOT NULL,
	"workflow_key" varchar(60) NOT NULL,
	"step_key" varchar(60) NOT NULL,
	"step_type" varchar(40) NOT NULL,
	"first_seen_version" integer NOT NULL,
	"last_seen_version" integer NOT NULL,
	"retired_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "workflows" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"tenant_id" uuid NOT NULL,
	"key" varchar(60) NOT NULL,
	"version" integer NOT NULL,
	"name" varchar(160) NOT NULL,
	"description" text,
	"status" "workflow_status" DEFAULT 'draft' NOT NULL,
	"applies_to" jsonb NOT NULL,
	"steps" jsonb NOT NULL,
	"outcomes" jsonb NOT NULL,
	"min_app_build" integer DEFAULT 1 NOT NULL,
	"published_at" timestamp with time zone,
	"published_by" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "geocode_cache" (
	"address_hash" varchar(64) PRIMARY KEY NOT NULL,
	"normalized_address" text NOT NULL,
	"position" geometry(point,4326),
	"confidence" varchar(20) NOT NULL,
	"provider" varchar(40) NOT NULL,
	"latitude" double precision,
	"longitude" double precision,
	"hit_count" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"refreshed_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "location_pings" (
	"id" uuid DEFAULT gen_random_uuid() NOT NULL,
	"shift_id" uuid NOT NULL,
	"courier_id" uuid NOT NULL,
	"position" geometry(point,4326) NOT NULL,
	"accuracy" real NOT NULL,
	"altitude" real,
	"heading" real,
	"speed" real,
	"captured_at" timestamp with time zone NOT NULL,
	"recorded_at" timestamp with time zone DEFAULT now() NOT NULL,
	"is_mocked" boolean DEFAULT false NOT NULL,
	"battery_level" real,
	"is_charging" boolean,
	"network_type" varchar(10)
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "route_stops" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"route_id" uuid NOT NULL,
	"task_id" uuid NOT NULL,
	"sequence" smallint NOT NULL,
	"eta_at" timestamp with time zone,
	"distance_meters" integer,
	"duration_seconds" integer,
	"is_estimate_only" boolean DEFAULT true NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "routes" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"shift_id" uuid NOT NULL,
	"courier_id" uuid NOT NULL,
	"mode" "route_mode" DEFAULT 'sequence_only' NOT NULL,
	"geometry" text,
	"total_distance_meters" integer,
	"total_duration_seconds" integer,
	"provider" varchar(40),
	"computed_at" timestamp with time zone DEFAULT now() NOT NULL,
	"superseded_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "shifts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"courier_id" uuid NOT NULL,
	"device_id" uuid,
	"status" "shift_status" DEFAULT 'active' NOT NULL,
	"started_at" timestamp with time zone NOT NULL,
	"ended_at" timestamp with time zone,
	"start_location" geometry(point,4326),
	"end_location" geometry(point,4326),
	"vehicle_plate" varchar(20),
	"start_photo_media_id" uuid,
	"permissions" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"task_count" integer DEFAULT 0 NOT NULL,
	"completed_count" integer DEFAULT 0 NOT NULL,
	"distance_meters" integer DEFAULT 0 NOT NULL,
	"note" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "document_pages" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"document_media_id" uuid NOT NULL,
	"page_media_id" uuid NOT NULL,
	"page_number" integer NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "media" (
	"id" uuid PRIMARY KEY NOT NULL,
	"tenant_id" uuid NOT NULL,
	"courier_id" uuid,
	"kind" "media_kind" NOT NULL,
	"state" "media_state" DEFAULT 'pending' NOT NULL,
	"content_type" varchar(80) NOT NULL,
	"byte_size" bigint NOT NULL,
	"sha256" varchar(64) NOT NULL,
	"storage_key" varchar(512) NOT NULL,
	"storage_bucket" varchar(120) NOT NULL,
	"task_id" uuid,
	"step_key" varchar(60),
	"captured_at" timestamp with time zone NOT NULL,
	"captured_location" geometry(point,4326),
	"metadata" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"uploaded_at" timestamp with time zone,
	"verified_at" timestamp with time zone,
	"rejected_reason" varchar(160),
	"retain_until" timestamp with time zone,
	"purged_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "masked_call_sessions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"task_id" uuid,
	"courier_id" uuid NOT NULL,
	"target" varchar(20) NOT NULL,
	"provider" varchar(40) NOT NULL,
	"provider_session_id" varchar(120),
	"proxy_number" varchar(20) NOT NULL,
	"started_at" timestamp with time zone DEFAULT now() NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"connected_at" timestamp with time zone,
	"duration_seconds" integer,
	"recording_media_id" uuid,
	"has_recording" boolean DEFAULT false NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "task_items" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"task_id" uuid NOT NULL,
	"barcode" varchar(80),
	"description" varchar(300) NOT NULL,
	"quantity" smallint DEFAULT 1 NOT NULL,
	"weight_grams" integer
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "task_steps" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"task_id" uuid NOT NULL,
	"step_key" varchar(60) NOT NULL,
	"workflow_version" integer NOT NULL,
	"revision" smallint DEFAULT 1 NOT NULL,
	"status" "step_status" NOT NULL,
	"value" jsonb,
	"media_ids" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"skip_reason_code" varchar(60),
	"override_reason_code" varchar(60),
	"position" geometry(point,4326),
	"accuracy" integer,
	"occurred_at" timestamp with time zone NOT NULL,
	"recorded_at" timestamp with time zone DEFAULT now() NOT NULL,
	"client_event_id" uuid NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "task_transitions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"task_id" uuid NOT NULL,
	"from_status" "task_status",
	"to_status" "task_status" NOT NULL,
	"actor_type" varchar(20) NOT NULL,
	"actor_id" uuid,
	"position" geometry(point,4326),
	"occurred_at" timestamp with time zone NOT NULL,
	"recorded_at" timestamp with time zone DEFAULT now() NOT NULL,
	"client_event_id" uuid,
	"reason" varchar(160)
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "tasks" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"tenant_id" uuid NOT NULL,
	"branch_id" uuid,
	"courier_id" uuid,
	"shift_id" uuid,
	"reference" varchar(60) NOT NULL,
	"external_id" varchar(120),
	"type" "task_type" NOT NULL,
	"status" "task_status" DEFAULT 'ASSIGNED' NOT NULL,
	"priority" "task_priority" DEFAULT 'normal' NOT NULL,
	"sequence" smallint DEFAULT 0 NOT NULL,
	"workflow_id" uuid,
	"workflow_key" varchar(60),
	"workflow_version" integer,
	"address_line1" varchar(255) NOT NULL,
	"address_line2" varchar(255),
	"district" varchar(120),
	"city" varchar(120) NOT NULL,
	"postal_code" varchar(20),
	"country_code" varchar(2) DEFAULT 'TR' NOT NULL,
	"position" geometry(point,4326),
	"geocode_confidence" varchar(20),
	"contact_name" varchar(160),
	"contact_phone_encrypted" text,
	"contact_note" varchar(500),
	"slot_start_at" timestamp with time zone,
	"slot_end_at" timestamp with time zone,
	"eta_at" timestamp with time zone,
	"cod_amount" numeric(12, 2),
	"item_count" smallint DEFAULT 1 NOT NULL,
	"attempt_number" smallint DEFAULT 1 NOT NULL,
	"max_attempts" smallint DEFAULT 3 NOT NULL,
	"previous_task_id" uuid,
	"outcome_code" varchar(50),
	"outcome_note" text,
	"finalized_at" timestamp with time zone,
	"attributes" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"row_version" integer DEFAULT 0 NOT NULL,
	"assigned_at" timestamp with time zone,
	"started_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "custody_handover_items" (
	"handover_id" uuid NOT NULL,
	"item_id" uuid NOT NULL,
	"discrepancy" varchar(120)
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "custody_handovers" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"tenant_id" uuid NOT NULL,
	"courier_id" uuid NOT NULL,
	"direction" "custody_direction" NOT NULL,
	"counterparty_kind" "counterparty_kind" NOT NULL,
	"counterparty_id" uuid,
	"counterparty_name" varchar(160) NOT NULL,
	"signature_media_id" uuid,
	"photo_media_ids" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"receipt_media_id" uuid,
	"position" geometry(point,4326),
	"note" text,
	"occurred_at" timestamp with time zone NOT NULL,
	"recorded_at" timestamp with time zone DEFAULT now() NOT NULL,
	"client_event_id" uuid NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "custody_items" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"tenant_id" uuid NOT NULL,
	"holder_courier_id" uuid,
	"type" "custody_item_type" NOT NULL,
	"barcode" varchar(80),
	"description" varchar(300) NOT NULL,
	"quantity" smallint DEFAULT 1 NOT NULL,
	"amount" numeric(12, 2),
	"task_id" uuid,
	"acquired_at" timestamp with time zone DEFAULT now() NOT NULL,
	"released_at" timestamp with time zone,
	"row_version" integer DEFAULT 0 NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "support_messages" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"ticket_id" uuid NOT NULL,
	"author_type" varchar(20) NOT NULL,
	"author_id" uuid,
	"body" text NOT NULL,
	"media_ids" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"is_internal" varchar(5) DEFAULT 'false' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "support_tickets" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"tenant_id" uuid NOT NULL,
	"courier_id" uuid NOT NULL,
	"reference" varchar(40) NOT NULL,
	"category" "support_category" NOT NULL,
	"status" "support_status" DEFAULT 'open' NOT NULL,
	"priority" "support_priority" DEFAULT 'normal' NOT NULL,
	"subject" varchar(160) NOT NULL,
	"body" text NOT NULL,
	"task_id" uuid,
	"media_ids" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"position" geometry(point,4326),
	"diagnostics" jsonb,
	"assigned_operator_id" uuid,
	"resolved_at" timestamp with time zone,
	"client_event_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "audit_log" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"tenant_id" uuid,
	"actor_type" "actor_type" NOT NULL,
	"actor_id" uuid,
	"action" varchar(80) NOT NULL,
	"subject_type" varchar(40) NOT NULL,
	"subject_id" uuid,
	"detail" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"ip" varchar(45),
	"correlation_id" varchar(64),
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "idempotency_keys" (
	"key" uuid NOT NULL,
	"courier_id" uuid NOT NULL,
	"request_hash" varchar(64) NOT NULL,
	"state" varchar(20) DEFAULT 'in_progress' NOT NULL,
	"response_status" smallint,
	"response_body" jsonb,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"completed_at" timestamp with time zone,
	"expires_at" timestamp with time zone NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "notifications" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"courier_id" uuid NOT NULL,
	"kind" varchar(40) NOT NULL,
	"title" varchar(120),
	"body" varchar(300),
	"route" varchar(200),
	"subject_id" uuid,
	"collapse_key" varchar(60),
	"sent_at" timestamp with time zone,
	"delivered_at" timestamp with time zone,
	"read_at" timestamp with time zone,
	"failure_reason" varchar(160),
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "outbox_events" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"tenant_id" uuid,
	"key" varchar(60) NOT NULL,
	"schema_version" smallint DEFAULT 1 NOT NULL,
	"subject_type" varchar(20) NOT NULL,
	"subject_id" uuid NOT NULL,
	"actor_type" "actor_type" NOT NULL,
	"actor_id" uuid,
	"correlation_id" varchar(64) NOT NULL,
	"causation_id" uuid,
	"data" jsonb NOT NULL,
	"occurred_at" timestamp with time zone NOT NULL,
	"recorded_at" timestamp with time zone DEFAULT now() NOT NULL,
	"state" "outbox_state" DEFAULT 'pending' NOT NULL,
	"dispatched_at" timestamp with time zone,
	"attempts" smallint DEFAULT 0 NOT NULL,
	"last_error" text,
	"next_attempt_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "webhook_deliveries" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"endpoint_id" uuid NOT NULL,
	"event_ids" jsonb NOT NULL,
	"attempt" smallint DEFAULT 1 NOT NULL,
	"response_status" smallint,
	"response_body" text,
	"duration_ms" integer,
	"error" text,
	"dead_lettered_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "webhook_endpoints" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"tenant_id" uuid NOT NULL,
	"url" varchar(512) NOT NULL,
	"secret" varchar(128) NOT NULL,
	"secret_previous" varchar(128),
	"subscribed_keys" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"is_active" varchar(5) DEFAULT 'true' NOT NULL,
	"consecutive_failures" smallint DEFAULT 0 NOT NULL,
	"disabled_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "branches" ADD CONSTRAINT "branches_tenant_id_tenants_id_fk" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE restrict ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "couriers" ADD CONSTRAINT "couriers_tenant_id_tenants_id_fk" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE restrict ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "couriers" ADD CONSTRAINT "couriers_branch_id_branches_id_fk" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE set null ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "devices" ADD CONSTRAINT "devices_courier_id_couriers_id_fk" FOREIGN KEY ("courier_id") REFERENCES "public"."couriers"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "otp_challenges" ADD CONSTRAINT "otp_challenges_courier_id_couriers_id_fk" FOREIGN KEY ("courier_id") REFERENCES "public"."couriers"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "sessions" ADD CONSTRAINT "sessions_courier_id_couriers_id_fk" FOREIGN KEY ("courier_id") REFERENCES "public"."couriers"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "sessions" ADD CONSTRAINT "sessions_device_id_devices_id_fk" FOREIGN KEY ("device_id") REFERENCES "public"."devices"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "workflow_step_keys" ADD CONSTRAINT "workflow_step_keys_tenant_id_tenants_id_fk" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "workflows" ADD CONSTRAINT "workflows_tenant_id_tenants_id_fk" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE restrict ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "route_stops" ADD CONSTRAINT "route_stops_route_id_routes_id_fk" FOREIGN KEY ("route_id") REFERENCES "public"."routes"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "routes" ADD CONSTRAINT "routes_shift_id_shifts_id_fk" FOREIGN KEY ("shift_id") REFERENCES "public"."shifts"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "routes" ADD CONSTRAINT "routes_courier_id_couriers_id_fk" FOREIGN KEY ("courier_id") REFERENCES "public"."couriers"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "shifts" ADD CONSTRAINT "shifts_courier_id_couriers_id_fk" FOREIGN KEY ("courier_id") REFERENCES "public"."couriers"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "shifts" ADD CONSTRAINT "shifts_device_id_devices_id_fk" FOREIGN KEY ("device_id") REFERENCES "public"."devices"("id") ON DELETE set null ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "document_pages" ADD CONSTRAINT "document_pages_document_media_id_media_id_fk" FOREIGN KEY ("document_media_id") REFERENCES "public"."media"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "document_pages" ADD CONSTRAINT "document_pages_page_media_id_media_id_fk" FOREIGN KEY ("page_media_id") REFERENCES "public"."media"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "media" ADD CONSTRAINT "media_tenant_id_tenants_id_fk" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE restrict ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "media" ADD CONSTRAINT "media_courier_id_couriers_id_fk" FOREIGN KEY ("courier_id") REFERENCES "public"."couriers"("id") ON DELETE set null ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "masked_call_sessions" ADD CONSTRAINT "masked_call_sessions_task_id_tasks_id_fk" FOREIGN KEY ("task_id") REFERENCES "public"."tasks"("id") ON DELETE set null ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "masked_call_sessions" ADD CONSTRAINT "masked_call_sessions_courier_id_couriers_id_fk" FOREIGN KEY ("courier_id") REFERENCES "public"."couriers"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "task_items" ADD CONSTRAINT "task_items_task_id_tasks_id_fk" FOREIGN KEY ("task_id") REFERENCES "public"."tasks"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "task_steps" ADD CONSTRAINT "task_steps_task_id_tasks_id_fk" FOREIGN KEY ("task_id") REFERENCES "public"."tasks"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "task_transitions" ADD CONSTRAINT "task_transitions_task_id_tasks_id_fk" FOREIGN KEY ("task_id") REFERENCES "public"."tasks"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "tasks" ADD CONSTRAINT "tasks_tenant_id_tenants_id_fk" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE restrict ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "tasks" ADD CONSTRAINT "tasks_branch_id_branches_id_fk" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE set null ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "tasks" ADD CONSTRAINT "tasks_courier_id_couriers_id_fk" FOREIGN KEY ("courier_id") REFERENCES "public"."couriers"("id") ON DELETE set null ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "tasks" ADD CONSTRAINT "tasks_shift_id_shifts_id_fk" FOREIGN KEY ("shift_id") REFERENCES "public"."shifts"("id") ON DELETE set null ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "tasks" ADD CONSTRAINT "tasks_workflow_id_workflows_id_fk" FOREIGN KEY ("workflow_id") REFERENCES "public"."workflows"("id") ON DELETE restrict ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "custody_handover_items" ADD CONSTRAINT "custody_handover_items_handover_id_custody_handovers_id_fk" FOREIGN KEY ("handover_id") REFERENCES "public"."custody_handovers"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "custody_handover_items" ADD CONSTRAINT "custody_handover_items_item_id_custody_items_id_fk" FOREIGN KEY ("item_id") REFERENCES "public"."custody_items"("id") ON DELETE restrict ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "custody_handovers" ADD CONSTRAINT "custody_handovers_tenant_id_tenants_id_fk" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE restrict ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "custody_handovers" ADD CONSTRAINT "custody_handovers_courier_id_couriers_id_fk" FOREIGN KEY ("courier_id") REFERENCES "public"."couriers"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "custody_items" ADD CONSTRAINT "custody_items_tenant_id_tenants_id_fk" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE restrict ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "custody_items" ADD CONSTRAINT "custody_items_holder_courier_id_couriers_id_fk" FOREIGN KEY ("holder_courier_id") REFERENCES "public"."couriers"("id") ON DELETE set null ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "custody_items" ADD CONSTRAINT "custody_items_task_id_tasks_id_fk" FOREIGN KEY ("task_id") REFERENCES "public"."tasks"("id") ON DELETE set null ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "support_messages" ADD CONSTRAINT "support_messages_ticket_id_support_tickets_id_fk" FOREIGN KEY ("ticket_id") REFERENCES "public"."support_tickets"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "support_tickets" ADD CONSTRAINT "support_tickets_tenant_id_tenants_id_fk" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE restrict ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "support_tickets" ADD CONSTRAINT "support_tickets_courier_id_couriers_id_fk" FOREIGN KEY ("courier_id") REFERENCES "public"."couriers"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "support_tickets" ADD CONSTRAINT "support_tickets_task_id_tasks_id_fk" FOREIGN KEY ("task_id") REFERENCES "public"."tasks"("id") ON DELETE set null ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "audit_log" ADD CONSTRAINT "audit_log_tenant_id_tenants_id_fk" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE set null ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "idempotency_keys" ADD CONSTRAINT "idempotency_keys_courier_id_couriers_id_fk" FOREIGN KEY ("courier_id") REFERENCES "public"."couriers"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "notifications" ADD CONSTRAINT "notifications_courier_id_couriers_id_fk" FOREIGN KEY ("courier_id") REFERENCES "public"."couriers"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "outbox_events" ADD CONSTRAINT "outbox_events_tenant_id_tenants_id_fk" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "webhook_deliveries" ADD CONSTRAINT "webhook_deliveries_endpoint_id_webhook_endpoints_id_fk" FOREIGN KEY ("endpoint_id") REFERENCES "public"."webhook_endpoints"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "webhook_endpoints" ADD CONSTRAINT "webhook_endpoints_tenant_id_tenants_id_fk" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "branches_tenant_code_uq" ON "branches" USING btree ("tenant_id","code");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "branches_location_idx" ON "branches" USING gist ("location");--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "couriers_tenant_phone_uq" ON "couriers" USING btree ("tenant_id","phone") WHERE deleted_at is null;--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "couriers_branch_idx" ON "couriers" USING btree ("branch_id");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "couriers_status_idx" ON "couriers" USING btree ("tenant_id","status");--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "devices_installation_uq" ON "devices" USING btree ("installation_id");--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "devices_active_courier_uq" ON "devices" USING btree ("courier_id") WHERE revoked_at is null;--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "otp_phone_purpose_idx" ON "otp_challenges" USING btree ("phone","purpose","created_at");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "otp_task_idx" ON "otp_challenges" USING btree ("task_id");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "otp_live_idx" ON "otp_challenges" USING btree ("expires_at") WHERE consumed_at is null;--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "sessions_refresh_hash_uq" ON "sessions" USING btree ("refresh_token_hash");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "sessions_family_idx" ON "sessions" USING btree ("family_id");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "sessions_live_idx" ON "sessions" USING btree ("courier_id","expires_at") WHERE revoked_at is null and used_at is null;--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "workflow_step_keys_pk" ON "workflow_step_keys" USING btree ("tenant_id","workflow_key","step_key");--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "workflows_key_version_uq" ON "workflows" USING btree ("tenant_id","key","version");--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "workflows_single_draft_uq" ON "workflows" USING btree ("tenant_id","key") WHERE status = 'draft';--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "workflows_published_idx" ON "workflows" USING btree ("tenant_id","key","version") WHERE status = 'published';--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "geocode_cache_position_idx" ON "geocode_cache" USING gist ("position");--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "location_pings_pk" ON "location_pings" USING btree ("id","captured_at");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "location_pings_shift_time_idx" ON "location_pings" USING btree ("shift_id","captured_at");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "location_pings_position_idx" ON "location_pings" USING gist ("position");--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "route_stops_route_seq_uq" ON "route_stops" USING btree ("route_id","sequence");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "route_stops_task_idx" ON "route_stops" USING btree ("task_id");--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "routes_active_shift_uq" ON "routes" USING btree ("shift_id") WHERE superseded_at is null;--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "shifts_open_courier_uq" ON "shifts" USING btree ("courier_id") WHERE ended_at is null;--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "shifts_courier_started_idx" ON "shifts" USING btree ("courier_id","started_at");--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "document_pages_uq" ON "document_pages" USING btree ("document_media_id","page_number");--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "media_tenant_digest_uq" ON "media" USING btree ("tenant_id","sha256");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "media_task_idx" ON "media" USING btree ("task_id","step_key");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "media_state_idx" ON "media" USING btree ("state","created_at");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "media_retention_idx" ON "media" USING btree ("retain_until");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "masked_calls_task_idx" ON "masked_call_sessions" USING btree ("task_id");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "masked_calls_live_idx" ON "masked_call_sessions" USING btree ("expires_at") WHERE connected_at is null;--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "task_items_task_idx" ON "task_items" USING btree ("task_id");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "task_items_barcode_idx" ON "task_items" USING btree ("barcode");--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "task_steps_latest_uq" ON "task_steps" USING btree ("task_id","step_key","revision");--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "task_steps_client_event_uq" ON "task_steps" USING btree ("client_event_id");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "task_steps_task_idx" ON "task_steps" USING btree ("task_id");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "task_transitions_task_idx" ON "task_transitions" USING btree ("task_id","recorded_at");--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "task_transitions_client_event_uq" ON "task_transitions" USING btree ("client_event_id") WHERE client_event_id is not null;--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "tasks_tenant_reference_uq" ON "tasks" USING btree ("tenant_id","reference");--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "tasks_external_uq" ON "tasks" USING btree ("tenant_id","external_id") WHERE external_id is not null;--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "tasks_courier_feed_idx" ON "tasks" USING btree ("courier_id","updated_at");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "tasks_open_courier_idx" ON "tasks" USING btree ("courier_id","sequence") WHERE status not in ('COMPLETED', 'FAILED', 'CANCELLED');--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "tasks_position_idx" ON "tasks" USING gist ("position");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "tasks_status_idx" ON "tasks" USING btree ("tenant_id","status","created_at");--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "custody_handover_items_pk" ON "custody_handover_items" USING btree ("handover_id","item_id");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "custody_handover_items_item_idx" ON "custody_handover_items" USING btree ("item_id");--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "custody_handovers_client_event_uq" ON "custody_handovers" USING btree ("client_event_id");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "custody_handovers_courier_idx" ON "custody_handovers" USING btree ("courier_id","recorded_at");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "custody_items_holder_idx" ON "custody_items" USING btree ("holder_courier_id") WHERE released_at is null;--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "custody_items_barcode_uq" ON "custody_items" USING btree ("tenant_id","barcode") WHERE barcode is not null and released_at is null;--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "custody_items_task_idx" ON "custody_items" USING btree ("task_id");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "support_messages_ticket_idx" ON "support_messages" USING btree ("ticket_id","created_at");--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "support_tickets_reference_uq" ON "support_tickets" USING btree ("tenant_id","reference");--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "support_tickets_client_event_uq" ON "support_tickets" USING btree ("client_event_id") WHERE client_event_id is not null;--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "support_tickets_courier_idx" ON "support_tickets" USING btree ("courier_id","created_at");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "support_tickets_open_idx" ON "support_tickets" USING btree ("tenant_id","priority","created_at") WHERE status in ('open', 'in_progress');--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "audit_log_subject_idx" ON "audit_log" USING btree ("subject_type","subject_id","created_at");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "audit_log_actor_idx" ON "audit_log" USING btree ("actor_type","actor_id","created_at");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "audit_log_action_idx" ON "audit_log" USING btree ("action","created_at");--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "idempotency_keys_pk" ON "idempotency_keys" USING btree ("key","courier_id");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "idempotency_keys_expiry_idx" ON "idempotency_keys" USING btree ("expires_at");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "notifications_courier_idx" ON "notifications" USING btree ("courier_id","created_at");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "notifications_unread_idx" ON "notifications" USING btree ("courier_id") WHERE read_at is null;--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "outbox_pending_idx" ON "outbox_events" USING btree ("next_attempt_at","recorded_at") WHERE state = 'pending';--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "outbox_subject_idx" ON "outbox_events" USING btree ("subject_type","subject_id","recorded_at");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "outbox_key_idx" ON "outbox_events" USING btree ("key","recorded_at");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "webhook_deliveries_endpoint_idx" ON "webhook_deliveries" USING btree ("endpoint_id","created_at");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "webhook_deliveries_dlq_idx" ON "webhook_deliveries" USING btree ("created_at") WHERE dead_lettered_at is not null;--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "webhook_endpoints_tenant_idx" ON "webhook_endpoints" USING btree ("tenant_id");