import {
  type Condition,
  type StepType,
  WorkflowDefinition,
  type WorkflowStep,
} from '@dijigoo/contracts';

/* ------------------------------------------------------------------ *
 * Condition evaluation
 * ------------------------------------------------------------------ */

export interface ConditionContext {
  steps: Record<string, { value?: unknown; status: 'completed' | 'skipped' }>;
  task: Record<string, unknown> & { attributes?: Record<string, unknown> };
  courier?: Record<string, unknown>;
}

/**
 * Resolves a dotted path against the answer bag. Returns `undefined` for any
 * missing segment rather than throwing, because a condition referring to a
 * step the courier has not reached yet must simply evaluate to "not there".
 */
export function resolvePath(path: string, ctx: ConditionContext): unknown {
  const segments = path.split('.');
  let current: unknown = ctx;

  for (const segment of segments) {
    if (current === null || current === undefined) return undefined;
    if (typeof current !== 'object') return undefined;
    current = (current as Record<string, unknown>)[segment];
  }

  return current;
}

function isEmpty(value: unknown): boolean {
  if (value === null || value === undefined) return true;
  if (typeof value === 'string') return value.trim().length === 0;
  if (Array.isArray(value)) return value.length === 0;
  if (typeof value === 'object') return Object.keys(value as object).length === 0;
  return false;
}

/**
 * Must produce the same answer on the server and inside the Flutter app while
 * offline. That is why there is no date arithmetic, no string coercion of
 * numbers and no locale-sensitive comparison here.
 */
export function evaluateCondition(condition: Condition, ctx: ConditionContext): boolean {
  if ('all' in condition) return condition.all.every((c) => evaluateCondition(c, ctx));
  if ('any' in condition) return condition.any.some((c) => evaluateCondition(c, ctx));
  if ('not' in condition) return !evaluateCondition(condition.not, ctx);

  const actual = resolvePath(condition.path, ctx);
  const expected = condition.value;

  switch (condition.op) {
    case 'eq':
      return actual === expected;
    case 'neq':
      return actual !== expected;
    case 'in':
      return Array.isArray(expected) && (expected as unknown[]).includes(actual as never);
    case 'notIn':
      return Array.isArray(expected) && !(expected as unknown[]).includes(actual as never);
    case 'gt':
      return typeof actual === 'number' && typeof expected === 'number' && actual > expected;
    case 'gte':
      return typeof actual === 'number' && typeof expected === 'number' && actual >= expected;
    case 'lt':
      return typeof actual === 'number' && typeof expected === 'number' && actual < expected;
    case 'lte':
      return typeof actual === 'number' && typeof expected === 'number' && actual <= expected;
    case 'isTrue':
      return actual === true;
    case 'isFalse':
      return actual === false;
    case 'isEmpty':
      return isEmpty(actual);
    case 'isNotEmpty':
      return !isEmpty(actual);
    default:
      return false;
  }
}

/* ------------------------------------------------------------------ *
 * Publish-time validation
 * ------------------------------------------------------------------ */

export type WorkflowIssueCode =
  | 'SCHEMA_INVALID'
  | 'DUPLICATE_STEP_KEY'
  | 'UNKNOWN_CONDITION_PATH'
  | 'FORWARD_REFERENCE'
  | 'NO_SUCCESS_OUTCOME'
  | 'DUPLICATE_OUTCOME_CODE'
  | 'UNRESOLVED_MATCH_PATH'
  | 'SELECT_WITHOUT_OPTIONS'
  | 'MIN_APP_BUILD_TOO_LOW'
  | 'INVALID_COUNT_RANGE';

export interface WorkflowIssue {
  code: WorkflowIssueCode;
  /** Dotted location inside the definition, e.g. `steps[3].config.fields[1]`. */
  at: string;
  message: string;
}

/**
 * Lower bound on `minAppBuild` per step type. Bumped whenever the Flutter app
 * gains the ability to render a new type. Without this a definition can be
 * published that an older build silently skips, producing a delivery with
 * missing evidence.
 */
export const MIN_APP_BUILD_BY_STEP_TYPE: Record<StepType, number> = {
  INSTRUCTION: 1,
  GEOFENCE_CHECK: 1,
  BARCODE_SCAN: 1,
  PHOTO_EVIDENCE: 1,
  DOCUMENT_SCAN: 1,
  FORM: 1,
  CHECKLIST: 1,
  OTP_VERIFY: 1,
  SIGNATURE: 1,
  CASH_COLLECT: 1,
  IDENTITY_CAPTURE: 500,
};

function collectConditionPaths(condition: Condition, out: string[]): void {
  if ('all' in condition) {
    condition.all.forEach((c) => collectConditionPaths(c, out));
    return;
  }
  if ('any' in condition) {
    condition.any.forEach((c) => collectConditionPaths(c, out));
    return;
  }
  if ('not' in condition) {
    collectConditionPaths(condition.not, out);
    return;
  }
  out.push(condition.path);
}

function stepConditionPaths(step: WorkflowStep): string[] {
  const paths: string[] = [];
  if (step.visibleWhen) collectConditionPaths(step.visibleWhen, paths);
  if (step.type === 'FORM') {
    for (const field of step.config.fields) {
      if (field.visibleWhen) collectConditionPaths(field.visibleWhen, paths);
    }
  }
  return paths;
}

/**
 * Runs at publish time in the panel and again in the API before a definition
 * is written. Returns every problem at once rather than failing on the first,
 * so an operator fixes one round of errors instead of five.
 */
export function validateWorkflow(input: unknown): WorkflowIssue[] {
  const parsed = WorkflowDefinition.safeParse(input);
  if (!parsed.success) {
    return parsed.error.issues.map((issue) => ({
      code: 'SCHEMA_INVALID' as const,
      at: issue.path.join('.') || '(root)',
      message: issue.message,
    }));
  }

  const wf = parsed.data;
  const issues: WorkflowIssue[] = [];

  // Every step, main flow first, then outcome-specific ones. Order matters for
  // the forward-reference check: an outcome step may read any main step.
  const allSteps: { step: WorkflowStep; at: string }[] = [
    ...wf.steps.map((step, i) => ({ step, at: `steps[${i}]` })),
    ...wf.outcomes.flatMap((outcome, oi) =>
      outcome.steps.map((step, si) => ({ step, at: `outcomes[${oi}].steps[${si}]` })),
    ),
  ];

  const seenKeys = new Map<string, string>();
  for (const { step, at } of allSteps) {
    const previous = seenKeys.get(step.key);
    if (previous) {
      issues.push({
        code: 'DUPLICATE_STEP_KEY',
        at,
        message: `"${step.key}" anahtari ${previous} icinde zaten kullanilmis.`,
      });
    } else {
      seenKeys.set(step.key, at);
    }
  }

  // Forward references: a step may only read keys declared before it.
  const declaredSoFar = new Set<string>();
  for (const { step, at } of allSteps) {
    for (const path of stepConditionPaths(step)) {
      if (!path.startsWith('steps.')) {
        const validRoot =
          path.startsWith('task.') || path.startsWith('courier.');
        if (!validRoot) {
          issues.push({
            code: 'UNKNOWN_CONDITION_PATH',
            at,
            message: `"${path}" gecerli bir kok ile baslamiyor (steps. / task. / courier.).`,
          });
        }
        continue;
      }

      const referenced = path.split('.')[1];
      if (!referenced) continue;

      if (!seenKeys.has(referenced)) {
        issues.push({
          code: 'UNKNOWN_CONDITION_PATH',
          at,
          message: `"${path}" tanimsiz bir adima isaret ediyor.`,
        });
      } else if (referenced !== step.key && !declaredSoFar.has(referenced)) {
        issues.push({
          code: 'FORWARD_REFERENCE',
          at,
          message: `"${step.key}" kendisinden sonra gelen "${referenced}" adimina bakiyor.`,
        });
      }
    }
    declaredSoFar.add(step.key);
  }

  // Step-level config sanity that Zod cannot express on its own.
  for (const { step, at } of allSteps) {
    if (step.type === 'PHOTO_EVIDENCE' && step.config.minCount > step.config.maxCount) {
      issues.push({
        code: 'INVALID_COUNT_RANGE',
        at: `${at}.config`,
        message: `minCount (${step.config.minCount}) maxCount'tan (${step.config.maxCount}) buyuk olamaz.`,
      });
    }

    if (step.type === 'DOCUMENT_SCAN' && step.config.minPages > step.config.maxPages) {
      issues.push({
        code: 'INVALID_COUNT_RANGE',
        at: `${at}.config`,
        message: `minPages (${step.config.minPages}) maxPages'ten (${step.config.maxPages}) buyuk olamaz.`,
      });
    }

    if (step.type === 'FORM') {
      step.config.fields.forEach((field, fi) => {
        const needsOptions = field.type === 'select' || field.type === 'multiselect';
        if (needsOptions && (!field.options || field.options.length === 0)) {
          issues.push({
            code: 'SELECT_WITHOUT_OPTIONS',
            at: `${at}.config.fields[${fi}]`,
            message: `"${field.key}" alani ${field.type} tipinde ama secenek tasimiyor.`,
          });
        }
      });
    }

    if (step.type === 'BARCODE_SCAN' && step.config.mustMatchPath) {
      const path = step.config.mustMatchPath;
      if (!path.startsWith('task.') && !path.startsWith('steps.')) {
        issues.push({
          code: 'UNRESOLVED_MATCH_PATH',
          at: `${at}.config.mustMatchPath`,
          message: `"${path}" cozulemeyen bir yol.`,
        });
      }
    }

    if (step.type === 'CASH_COLLECT' && step.config.expectedAmountPath) {
      const path = step.config.expectedAmountPath;
      if (!path.startsWith('task.')) {
        issues.push({
          code: 'UNRESOLVED_MATCH_PATH',
          at: `${at}.config.expectedAmountPath`,
          message: `"${path}" gorev alanina isaret etmeli.`,
        });
      }
    }
  }

  // Outcomes
  if (!wf.outcomes.some((o) => o.kind === 'success')) {
    issues.push({
      code: 'NO_SUCCESS_OUTCOME',
      at: 'outcomes',
      message: 'En az bir success sonucu tanimlanmali.',
    });
  }

  const outcomeCodes = new Set<string>();
  wf.outcomes.forEach((outcome, i) => {
    if (outcomeCodes.has(outcome.code)) {
      issues.push({
        code: 'DUPLICATE_OUTCOME_CODE',
        at: `outcomes[${i}]`,
        message: `"${outcome.code}" birden fazla kez tanimlanmis.`,
      });
    }
    outcomeCodes.add(outcome.code);
  });

  // minAppBuild floor
  const requiredBuild = Math.max(
    1,
    ...allSteps.map(({ step }) => MIN_APP_BUILD_BY_STEP_TYPE[step.type] ?? 1),
  );
  if (wf.minAppBuild < requiredBuild) {
    issues.push({
      code: 'MIN_APP_BUILD_TOO_LOW',
      at: 'minAppBuild',
      message: `Kullanilan adim tipleri en az build ${requiredBuild} gerektiriyor, tanimda ${wf.minAppBuild} yaziyor.`,
    });
  }

  return issues;
}

/* ------------------------------------------------------------------ *
 * Breaking-change classification (rule K7)
 * ------------------------------------------------------------------ */

export type ChangeClass = 'compatible' | 'breaking' | 'forbidden';

export interface WorkflowChange {
  class: ChangeClass;
  kind:
    | 'STEP_ADDED_OPTIONAL'
    | 'STEP_ADDED_REQUIRED'
    | 'STEP_REMOVED'
    | 'STEP_TYPE_CHANGED'
    | 'STEP_REORDERED'
    | 'OUTCOME_REMOVED'
    | 'MIN_APP_BUILD_RAISED';
  key: string;
  message: string;
}

/**
 * Diffs a draft against the previously published version so the panel can show
 * an operator exactly what they are about to change before they hit publish.
 */
export function classifyChanges(
  previous: unknown,
  next: unknown,
): { changes: WorkflowChange[]; highest: ChangeClass } {
  const prev = WorkflowDefinition.safeParse(previous);
  const draft = WorkflowDefinition.safeParse(next);
  if (!prev.success || !draft.success) {
    return { changes: [], highest: 'forbidden' };
  }

  const flat = (wf: typeof prev.data) => [
    ...wf.steps,
    ...wf.outcomes.flatMap((o) => o.steps),
  ];

  const prevSteps = new Map(flat(prev.data).map((s) => [s.key, s]));
  const nextSteps = new Map(flat(draft.data).map((s) => [s.key, s]));
  const changes: WorkflowChange[] = [];

  for (const [key, step] of nextSteps) {
    const before = prevSteps.get(key);
    if (!before) {
      changes.push(
        step.required
          ? {
              class: 'breaking',
              kind: 'STEP_ADDED_REQUIRED',
              key,
              message: `Zorunlu adim eklendi: ${step.title}`,
            }
          : {
              class: 'compatible',
              kind: 'STEP_ADDED_OPTIONAL',
              key,
              message: `Istege bagli adim eklendi: ${step.title}`,
            },
      );
      continue;
    }
    if (before.type !== step.type) {
      changes.push({
        class: 'forbidden',
        kind: 'STEP_TYPE_CHANGED',
        key,
        message: `"${key}" adiminin tipi ${before.type} -> ${step.type} degistirilemez (K5).`,
      });
    }
  }

  for (const key of prevSteps.keys()) {
    if (!nextSteps.has(key)) {
      changes.push({
        class: 'breaking',
        kind: 'STEP_REMOVED',
        key,
        message: `"${key}" adimi kaldirildi. Anahtar rezerve kalir, yeniden kullanilamaz.`,
      });
    }
  }

  const prevOutcomes = new Set(prev.data.outcomes.map((o) => o.code));
  for (const code of prevOutcomes) {
    if (!draft.data.outcomes.some((o) => o.code === code)) {
      changes.push({
        class: 'breaking',
        kind: 'OUTCOME_REMOVED',
        key: code,
        message: `"${code}" sonucu kaldirildi. Gecmis raporlar etkilenir.`,
      });
    }
  }

  if (draft.data.minAppBuild > prev.data.minAppBuild) {
    changes.push({
      class: 'breaking',
      kind: 'MIN_APP_BUILD_RAISED',
      key: 'minAppBuild',
      message: `Asgari uygulama surumu ${prev.data.minAppBuild} -> ${draft.data.minAppBuild}. Eski build'ler bu akisi alamaz.`,
    });
  }

  const order: ChangeClass[] = ['compatible', 'breaking', 'forbidden'];
  const highest = changes.reduce<ChangeClass>(
    (acc, c) => (order.indexOf(c.class) > order.indexOf(acc) ? c.class : acc),
    'compatible',
  );

  return { changes, highest };
}

/* ------------------------------------------------------------------ *
 * Runtime: which step is next
 * ------------------------------------------------------------------ */

/**
 * Returns the steps a courier must actually see, given the answers collected
 * so far. Used identically by the API (to reject out-of-order submissions) and
 * by the app (to drive the wizard), so the two can never disagree.
 */
export function visibleSteps(steps: WorkflowStep[], ctx: ConditionContext): WorkflowStep[] {
  return steps.filter((step) => !step.visibleWhen || evaluateCondition(step.visibleWhen, ctx));
}

export function nextStep(steps: WorkflowStep[], ctx: ConditionContext): WorkflowStep | null {
  for (const step of visibleSteps(steps, ctx)) {
    if (!ctx.steps[step.key]) return step;
  }
  return null;
}

/** Required, visible steps that have no answer yet. Empty means ready to finalize. */
export function missingRequiredSteps(steps: WorkflowStep[], ctx: ConditionContext): string[] {
  return visibleSteps(steps, ctx)
    .filter((step) => step.required)
    .filter((step) => {
      const answer = ctx.steps[step.key];
      return !answer || answer.status === 'skipped';
    })
    .map((step) => step.key);
}
