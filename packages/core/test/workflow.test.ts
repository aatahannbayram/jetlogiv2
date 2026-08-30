import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  type ConditionContext,
  checkGeofence,
  classifyChanges,
  evaluateCondition,
  hashRequest,
  missingRequiredSteps,
  nextStep,
  validateWorkflow,
  visibleSteps,
} from '../src/index.js';

const here = dirname(fileURLToPath(import.meta.url));
const examplePath = resolve(
  here,
  '../../contracts/schemas/examples/standart-teslimat.v3.json',
);
const example = JSON.parse(readFileSync(examplePath, 'utf8')) as Record<string, unknown>;

const steps = example['steps'] as never[];

function ctx(partial: Partial<ConditionContext> = {}): ConditionContext {
  return {
    steps: {},
    task: { attributes: {} },
    ...partial,
  };
}

test('ornek workflow tanimi gecerli', () => {
  assert.deepEqual(validateWorkflow(example), []);
});

test('yinelenen adim anahtari yakalanir', () => {
  const broken = structuredClone(example) as { steps: { key: string }[] };
  broken.steps.push({ ...broken.steps[0]! });

  const issues = validateWorkflow(broken);
  assert.ok(issues.some((i) => i.code === 'DUPLICATE_STEP_KEY'));
});

test('ileriye referans yakalanir', () => {
  const broken = structuredClone(example) as {
    steps: { key: string; visibleWhen?: unknown }[];
  };
  // First step reads an answer that only exists later in the flow.
  broken.steps[0]!.visibleWhen = {
    path: 'steps.alici_imza.value',
    op: 'isNotEmpty',
  };

  const issues = validateWorkflow(broken);
  assert.ok(issues.some((i) => i.code === 'FORWARD_REFERENCE'));
});

test('success sonucu olmayan tanim reddedilir', () => {
  const broken = structuredClone(example) as { outcomes: { kind: string }[] };
  broken.outcomes = broken.outcomes.filter((o) => o.kind !== 'success');

  const issues = validateWorkflow(broken);
  assert.ok(issues.some((i) => i.code === 'NO_SUCCESS_OUTCOME'));
});

test('IDENTITY_CAPTURE minAppBuild tabanini yukseltir', () => {
  const broken = structuredClone(example) as {
    minAppBuild: number;
    steps: unknown[];
  };
  broken.steps.push({
    key: 'kimlik_yakala',
    type: 'IDENTITY_CAPTURE',
    title: 'Kimlik oku',
    required: true,
    config: { provider: 'sodec', captureNfc: true, captureSelfie: true, allowManualIdCapture: true },
  });

  const issues = validateWorkflow(broken);
  assert.ok(issues.some((i) => i.code === 'MIN_APP_BUILD_TOO_LOW'));
});

test('adim tipi degisimi yasak sinifinda', () => {
  const next = structuredClone(example) as { version: number; steps: { type: string }[] };
  next.version = 4;
  next.steps[1]!.type = 'PHOTO_EVIDENCE';

  const { highest } = classifyChanges(example, next);
  assert.equal(highest, 'forbidden');
});

test('zorunlu adim eklemek kirici, istege bagli eklemek uyumlu', () => {
  const withOptional = structuredClone(example) as { version: number; steps: unknown[] };
  withOptional.version = 4;
  withOptional.steps.push({
    key: 'ek_not',
    type: 'INSTRUCTION',
    title: 'Bilgilendirme',
    required: false,
    config: { body: 'Teslim sonrasi aracinizi kilitleyin.' },
  });
  assert.equal(classifyChanges(example, withOptional).highest, 'compatible');

  const withRequired = structuredClone(withOptional) as { steps: { required: boolean }[] };
  withRequired.steps[withRequired.steps.length - 1]!.required = true;
  assert.equal(classifyChanges(example, withRequired).highest, 'breaking');
});

test('kosullu adimlar cevaplara gore gorunur olur', () => {
  // No COD, delivered to a neighbour: cash step hidden, OTP step hidden.
  const neighbour = ctx({
    steps: {
      varis_kontrolu: { status: 'completed' },
      barkod_okut: { status: 'completed' },
      alici_kim: { status: 'completed', value: { teslim_alan: 'neighbor' } },
    },
    task: { attributes: { codAmount: 0, otpRequired: true } },
  });

  const keys = visibleSteps(steps, neighbour).map((s) => s.key);
  assert.ok(!keys.includes('otp_dogrula'), 'komsuya teslimde OTP istenmez');
  assert.ok(!keys.includes('tahsilat'), 'COD yoksa tahsilat gorunmez');
  assert.equal(nextStep(steps, neighbour)?.key, 'alici_imza');
});

test('COD tutari varsa tahsilat adimi gorunur', () => {
  const cod = ctx({
    steps: {
      varis_kontrolu: { status: 'completed' },
      barkod_okut: { status: 'completed' },
      alici_kim: { status: 'completed', value: { teslim_alan: 'recipient' } },
      otp_dogrula: { status: 'completed', value: true },
    },
    task: { attributes: { codAmount: 250, otpRequired: true } },
  });

  assert.equal(nextStep(steps, cod)?.key, 'tahsilat');
});

test('eksik zorunlu adimlar listelenir', () => {
  const partial = ctx({
    steps: { varis_kontrolu: { status: 'completed' } },
    task: { attributes: { codAmount: 0, otpRequired: false } },
  });

  const missing = missingRequiredSteps(steps, partial);
  assert.ok(missing.includes('barkod_okut'));
  assert.ok(missing.includes('teslim_fotografi'));
  assert.ok(!missing.includes('varis_kontrolu'));
});

test('atlanan adim tamamlanmis sayilmaz', () => {
  const skipped = ctx({
    steps: {
      varis_kontrolu: { status: 'skipped' },
    },
    task: { attributes: { codAmount: 0, otpRequired: false } },
  });

  assert.ok(missingRequiredSteps(steps, skipped).includes('varis_kontrolu'));
});

test('kosul operatorleri', () => {
  const c = ctx({ task: { attributes: { codAmount: 100, tag: 'vip', flag: false } } });

  assert.equal(evaluateCondition({ path: 'task.attributes.codAmount', op: 'gt', value: 50 }, c), true);
  assert.equal(evaluateCondition({ path: 'task.attributes.codAmount', op: 'gt', value: 500 }, c), false);
  assert.equal(
    evaluateCondition({ path: 'task.attributes.tag', op: 'in', value: ['vip', 'gold'] }, c),
    true,
  );
  assert.equal(evaluateCondition({ path: 'task.attributes.flag', op: 'isFalse' }, c), true);
  assert.equal(evaluateCondition({ path: 'task.attributes.missing', op: 'isEmpty' }, c), true);
  assert.equal(
    evaluateCondition(
      { not: { path: 'task.attributes.tag', op: 'eq', value: 'vip' } },
      c,
    ),
    false,
  );
});

test('geofence dogruluk yaricapini hesaba katar', () => {
  const target = { lat: 41.0082, lng: 28.9784 };
  const at = (lat: number, lng: number, accuracy: number) => ({
    lat,
    lng,
    accuracy,
    capturedAt: new Date().toISOString(),
    isMocked: false,
  });

  // Standing on the spot with a poor but usable fix: must pass.
  assert.equal(
    checkGeofence({ target, fix: at(41.0082, 28.9784, 90), radiusMeters: 150, maxAccuracyMeters: 120 })
      .result,
    'inside',
  );

  // Roughly 2 km away with a good fix: must fail.
  assert.equal(
    checkGeofence({ target, fix: at(41.0262, 28.9784, 15), radiusMeters: 150, maxAccuracyMeters: 120 })
      .result,
    'outside',
  );

  // Fix too imprecise to judge: inconclusive, not a violation.
  const poor = checkGeofence({
    target,
    fix: at(41.0082, 28.9784, 400),
    radiusMeters: 150,
    maxAccuracyMeters: 120,
  });
  assert.equal(poor.result, 'inconclusive');

  // No fix at all.
  assert.equal(
    checkGeofence({ target, fix: null, radiusMeters: 150, maxAccuracyMeters: 120 }).result,
    'inconclusive',
  );
});

test('idempotency hash anahtar sirasindan bagimsiz', () => {
  assert.equal(hashRequest({ a: 1, b: [1, 2] }), hashRequest({ b: [1, 2], a: 1 }));
  assert.notEqual(hashRequest({ a: 1 }), hashRequest({ a: 2 }));
});
