import { Timestamp, Uuid, z } from './common.js';

/* ------------------------------------------------------------------ *
 * Conditions
 *
 * Deliberately not a general expression language. The mobile app has to
 * evaluate these offline and deterministically, so the grammar is a closed
 * set of comparisons over answers already collected in the same task.
 * ------------------------------------------------------------------ */

export const ConditionOperator = z.enum([
  'eq',
  'neq',
  'in',
  'notIn',
  'gt',
  'gte',
  'lt',
  'lte',
  'isTrue',
  'isFalse',
  'isEmpty',
  'isNotEmpty',
]);

export const ConditionLeaf = z
  .object({
    /**
     * Dotted path into the task answer bag, e.g. `steps.recipient_check.value`
     * or `task.attributes.paymentType`.
     */
    path: z.string().min(1).max(200),
    op: ConditionOperator,
    value: z.union([z.string(), z.number(), z.boolean(), z.array(z.union([z.string(), z.number()]))]).nullish(),
  })
  .openapi('ConditionLeaf');
export type ConditionLeaf = z.infer<typeof ConditionLeaf>;

export type Condition =
  | z.infer<typeof ConditionLeaf>
  | { all: Condition[] }
  | { any: Condition[] }
  | { not: Condition };

/**
 * OpenAPI 3.1 cannot express this recursion through the Zod converter, so the
 * generated component is an opaque object. The authoritative structure lives
 * in `schemas/workflow-definition.schema.json`, which uses a proper `$ref`
 * self-reference. Runtime validation still uses the Zod version below.
 */
export const Condition: z.ZodType<Condition> = z.lazy(() =>
  z.union([
    ConditionLeaf,
    z.object({ all: z.array(Condition).min(1) }),
    z.object({ any: z.array(Condition).min(1) }),
    z.object({ not: Condition }),
  ]),
).openapi('Condition', {
  type: 'object',
  description:
    'Ozyinelemeli kosul agaci. Yaprak: {path, op, value}. Dugum: {all:[...]}, ' +
    '{any:[...]} veya {not:{...}}. Tam sema: schemas/workflow-definition.schema.json',
});

/* ------------------------------------------------------------------ *
 * Step configuration, one shape per step type
 * ------------------------------------------------------------------ */

export const PhotoEvidenceConfig = z.object({
  minCount: z.number().int().min(1).max(10).default(1),
  maxCount: z.number().int().min(1).max(10).default(3),
  /** Overlay guide drawn on the camera preview. */
  overlay: z.enum(['none', 'document', 'parcel', 'doorstep', 'plate']).default('none'),
  allowGallery: z.boolean().default(false).describe('Saha kaniti icin varsayilan kapali'),
  requireGeoTag: z.boolean().default(true),
  maxLongEdgePx: z.number().int().min(640).max(4096).default(1920),
  jpegQuality: z.number().int().min(40).max(100).default(80),
});

export const DocumentScanConfig = z.object({
  documentType: z.string().max(60).openapi({ example: 'teslim_tutanagi' }),
  minPages: z.number().int().min(1).max(30).default(1),
  maxPages: z.number().int().min(1).max(30).default(10),
  output: z.enum(['pdf', 'images']).default('pdf'),
  /** Runs on-device edge detection + perspective correction before upload. */
  autoCrop: z.boolean().default(true),
});

export const SignatureConfig = z.object({
  signerRole: z.enum(['recipient', 'courier', 'witness']).default('recipient'),
  requireSignerName: z.boolean().default(true),
  requireSignerIdLast4: z.boolean().default(false),
  disclaimerText: z.string().max(2000).nullish(),
});

export const OtpVerifyConfig = z.object({
  /** Whose phone receives the code. */
  target: z.enum(['recipient', 'sender', 'custom']).default('recipient'),
  channel: z.enum(['sms', 'ivr', 'sms_then_ivr']).default('sms'),
  codeLength: z.number().int().min(4).max(8).default(6),
  ttlSeconds: z.number().int().min(60).max(900).default(300),
  maxAttempts: z.number().int().min(1).max(10).default(5),
  /**
   * Escape hatch when the recipient has no reachable phone. Requires a reason
   * code and is flagged in the panel for audit.
   */
  allowManualOverride: z.boolean().default(false),
});

export const FormField = z.object({
  key: z
    .string()
    .regex(/^[a-z][a-z0-9_]{0,49}$/, 'snake_case olmali'),
  label: z.string().min(1).max(160),
  type: z.enum(['text', 'number', 'select', 'multiselect', 'boolean', 'date', 'phone']),
  required: z.boolean().default(false),
  options: z
    .array(z.object({ value: z.string().max(80), label: z.string().max(160) }))
    .nullish()
    .describe('select ve multiselect icin zorunlu'),
  min: z.number().nullish(),
  max: z.number().nullish(),
  pattern: z.string().max(200).nullish(),
  placeholder: z.string().max(160).nullish(),
  visibleWhen: Condition.nullish(),
});

export const FormConfig = z.object({
  fields: z.array(FormField).min(1).max(40),
});

export const BarcodeScanConfig = z.object({
  formats: z
    .array(z.enum(['qr', 'code128', 'code39', 'ean13', 'pdf417', 'datamatrix']))
    .min(1)
    .default(['qr', 'code128']),
  /** When set, the scanned value must equal this task attribute. */
  mustMatchPath: z.string().max(200).nullish(),
  allowManualEntry: z.boolean().default(true),
});

export const CashCollectConfig = z.object({
  currency: z.literal('TRY').default('TRY'),
  /** Path to the expected amount on the task; null means courier enters it. */
  expectedAmountPath: z.string().max(200).nullish(),
  allowPartial: z.boolean().default(false),
  methods: z.array(z.enum(['cash', 'card_on_delivery', 'prepaid'])).min(1),
});

export const GeofenceCheckConfig = z.object({
  radiusMeters: z.number().int().min(20).max(2000).default(150),
  /** Fixes worse than this accuracy are rejected outright. */
  maxAccuracyMeters: z.number().int().min(10).max(500).default(100),
  /**
   * When true a courier outside the fence can proceed by picking a reason.
   * Recommended on: dense city blocks routinely give 300 m GPS error.
   */
  allowOverrideWithReason: z.boolean().default(true),
  waitForFixSeconds: z.number().int().min(0).max(120).default(20),
});

export const ChecklistConfig = z.object({
  items: z
    .array(
      z.object({
        key: z.string().regex(/^[a-z][a-z0-9_]{0,49}$/),
        label: z.string().min(1).max(200),
        required: z.boolean().default(true),
      }),
    )
    .min(1)
    .max(30),
});

export const InstructionConfig = z.object({
  body: z.string().min(1).max(4000),
  mediaUrl: z.string().url().nullish(),
  requireAcknowledge: z.boolean().default(false),
});

export const IdentityCaptureConfig = z.object({
  /** Faz 2. Delegates to the existing Sodec SAMobileCapture bridge. */
  provider: z.literal('sodec').default('sodec'),
  captureNfc: z.boolean().default(true),
  captureSelfie: z.boolean().default(true),
  allowManualIdCapture: z.boolean().default(true),
});

/* ------------------------------------------------------------------ *
 * Step
 * ------------------------------------------------------------------ */

export const StepType = z.enum([
  'INSTRUCTION',
  'GEOFENCE_CHECK',
  'BARCODE_SCAN',
  'PHOTO_EVIDENCE',
  'DOCUMENT_SCAN',
  'FORM',
  'CHECKLIST',
  'OTP_VERIFY',
  'SIGNATURE',
  'CASH_COLLECT',
  'IDENTITY_CAPTURE',
]);
export type StepType = z.infer<typeof StepType>;

const stepBase = {
  /** Stable across versions. Answers are keyed by this, so it must not be reused. */
  key: z.string().regex(/^[a-z][a-z0-9_]{0,59}$/, 'snake_case olmali'),
  title: z.string().min(1).max(160),
  hint: z.string().max(600).nullish(),
  required: z.boolean().default(true),
  /** Step is shown only when this evaluates true against answers so far. */
  visibleWhen: Condition.nullish(),
  /** Courier may skip; requires picking one of these reasons. */
  skipReasons: z.array(z.object({ code: z.string().max(60), label: z.string().max(160) })).nullish(),
};

export const WorkflowStep = z
  .discriminatedUnion('type', [
    z.object({ ...stepBase, type: z.literal('INSTRUCTION'), config: InstructionConfig }),
    z.object({ ...stepBase, type: z.literal('GEOFENCE_CHECK'), config: GeofenceCheckConfig }),
    z.object({ ...stepBase, type: z.literal('BARCODE_SCAN'), config: BarcodeScanConfig }),
    z.object({ ...stepBase, type: z.literal('PHOTO_EVIDENCE'), config: PhotoEvidenceConfig }),
    z.object({ ...stepBase, type: z.literal('DOCUMENT_SCAN'), config: DocumentScanConfig }),
    z.object({ ...stepBase, type: z.literal('FORM'), config: FormConfig }),
    z.object({ ...stepBase, type: z.literal('CHECKLIST'), config: ChecklistConfig }),
    z.object({ ...stepBase, type: z.literal('OTP_VERIFY'), config: OtpVerifyConfig }),
    z.object({ ...stepBase, type: z.literal('SIGNATURE'), config: SignatureConfig }),
    z.object({ ...stepBase, type: z.literal('CASH_COLLECT'), config: CashCollectConfig }),
    z.object({ ...stepBase, type: z.literal('IDENTITY_CAPTURE'), config: IdentityCaptureConfig }),
  ])
  .openapi('WorkflowStep');
export type WorkflowStep = z.infer<typeof WorkflowStep>;

/* ------------------------------------------------------------------ *
 * Outcomes
 * ------------------------------------------------------------------ */

/**
 * A workflow always ends in exactly one outcome. "Teslim edilemedi" is not a
 * failure of the workflow, it is a first-class outcome with its own required
 * evidence, which is why reasons carry their own step list.
 */
export const WorkflowOutcome = z
  .object({
    code: z.string().regex(/^[A-Z][A-Z0-9_]{1,49}$/).openapi({ example: 'DELIVERED' }),
    label: z.string().min(1).max(160),
    kind: z.enum(['success', 'failure', 'deferred']),
    /** Extra steps required before this outcome can be committed. */
    steps: z.array(WorkflowStep).default([]),
    /** Failure outcomes usually schedule a retry attempt. */
    reschedule: z
      .object({
        allowed: z.boolean().default(false),
        maxAttempts: z.number().int().min(1).max(10).default(3),
      })
      .nullish(),
  })
  .openapi('WorkflowOutcome');
export type WorkflowOutcome = z.infer<typeof WorkflowOutcome>;

/* ------------------------------------------------------------------ *
 * Definition
 * ------------------------------------------------------------------ */

export const WorkflowStatus = z.enum(['draft', 'published', 'archived']);

export const WorkflowDefinition = z
  .object({
    id: Uuid,
    /** Stable slug shared by every version of this workflow. */
    key: z.string().regex(/^[a-z][a-z0-9_]{2,59}$/).openapi({ example: 'standart_teslimat' }),
    /**
     * Monotonic integer, bumped on every publish. Never reset, never reused.
     * A running task keeps the version it started with.
     */
    version: z.number().int().positive(),
    name: z.string().min(1).max(160),
    description: z.string().max(2000).nullish(),
    status: WorkflowStatus,
    /** Task types this workflow can be attached to. */
    appliesTo: z.array(z.enum(['DELIVERY', 'PICKUP', 'RETURN', 'SERVICE', 'DOCUMENT'])).min(1),
    steps: z.array(WorkflowStep).min(1).max(60),
    outcomes: z.array(WorkflowOutcome).min(1).max(30),
    /**
     * Minimum app build that can execute this definition. The server refuses
     * to hand a definition to an older client and tells it to update, rather
     * than letting it silently skip a step type it cannot render.
     */
    minAppBuild: z.number().int().positive().default(1),
    publishedAt: Timestamp.nullish(),
    publishedBy: Uuid.nullish(),
    createdAt: Timestamp,
    updatedAt: Timestamp,
  })
  .openapi('WorkflowDefinition');
export type WorkflowDefinition = z.infer<typeof WorkflowDefinition>;

/** Compact pointer stored on a task so the client knows what to fetch. */
export const WorkflowRef = z
  .object({
    workflowId: Uuid,
    key: z.string(),
    version: z.number().int().positive(),
    minAppBuild: z.number().int().positive(),
  })
  .openapi('WorkflowRef');
export type WorkflowRef = z.infer<typeof WorkflowRef>;
