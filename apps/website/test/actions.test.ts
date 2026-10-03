import assert from 'node:assert/strict';
import { afterEach, test } from 'node:test';

import { lookupShipment, submitInquiry } from '../lib/actions.ts';
import {
  INQUIRY_LIMITS,
  isSafeOutboundUrl,
  readInquiry,
  validateInquiry,
  validateTrackQuery,
} from '../lib/inquiry.ts';

function form(fields: Record<string, string>): FormData {
  const f = new FormData();
  for (const [k, v] of Object.entries(fields)) f.set(k, v);
  return f;
}

const valid = {
  firstName: 'Ada',
  lastName: 'Yılmaz',
  phone: '05320000000',
  message: 'Merhaba',
};

afterEach(() => {
  delete process.env.INQUIRY_WEBHOOK_URL;
  delete process.env.TRACKING_API_URL;
});

test('validateInquiry zorunlu alanlar', () => {
  const empty = readInquiry(form({}));
  assert.equal(validateInquiry('contact', empty), 'Ad, soyad, telefon ve mesaj zorunlu.');
  assert.equal(validateInquiry('contact', readInquiry(form(valid))), null);
  assert.equal(
    validateInquiry('career', readInquiry(form(valid))),
    'Pozisyon seçin.',
  );
  assert.equal(
    validateInquiry('partner', readInquiry(form({ ...valid, partnerType: 'acente' }))),
    'Başvuru tipi ve şehir zorunlu.',
  );
});

test('validateInquiry uzun girdiyi reddeder', () => {
  const long = readInquiry(form({ ...valid, message: 'x'.repeat(INQUIRY_LIMITS.message + 1) }));
  assert.equal(validateInquiry('contact', long), 'Mesaj çok uzun.');
});

test('validateTrackQuery boş ve tavan', () => {
  assert.equal(validateTrackQuery(''), 'empty');
  assert.equal(validateTrackQuery('   '), 'empty');
  assert.equal(validateTrackQuery('ABC123'), null);
  assert.equal(validateTrackQuery('q'.repeat(INQUIRY_LIMITS.query + 1)), 'Sorgu çok uzun.');
});

test('submitInquiry webhook yoksa queued false', async () => {
  const result = await submitInquiry('contact', form(valid));
  assert.deepEqual(result, { ok: true, queued: false });
});

test('submitInquiry eksik alan', async () => {
  const result = await submitInquiry('contact', form({ firstName: 'Ada' }));
  assert.equal(result.ok, false);
});

test('submitInquiry webhook 200 queued true', async () => {
  process.env.INQUIRY_WEBHOOK_URL = 'https://hooks.test/inq';
  const original = globalThis.fetch;
  globalThis.fetch = (async () => new Response('ok', { status: 200 })) as typeof fetch;
  try {
    const result = await submitInquiry('contact', form(valid));
    assert.deepEqual(result, { ok: true, queued: true });
  } finally {
    globalThis.fetch = original;
  }
});

test('submitInquiry webhook fail', async () => {
  process.env.INQUIRY_WEBHOOK_URL = 'https://hooks.test/inq';
  const original = globalThis.fetch;
  globalThis.fetch = (async () => new Response('no', { status: 500 })) as typeof fetch;
  try {
    const result = await submitInquiry('contact', form(valid));
    assert.equal(result.ok, false);
  } finally {
    globalThis.fetch = original;
  }
});

test('isSafeOutboundUrl localhost ve özel ağı reddeder', () => {
  assert.equal(isSafeOutboundUrl('https://track.dijigoo.com/lookup'), true);
  assert.equal(isSafeOutboundUrl('https://hooks.test/inq'), true);
  assert.equal(isSafeOutboundUrl('http://track.dijigoo.com/lookup'), false);
  assert.equal(isSafeOutboundUrl('https://localhost/lookup'), false);
  assert.equal(isSafeOutboundUrl('https://127.0.0.1/lookup'), false);
  assert.equal(isSafeOutboundUrl('https://10.0.0.8/lookup'), false);
  assert.equal(isSafeOutboundUrl('https://192.168.1.4/meta'), false);
  assert.equal(isSafeOutboundUrl('https://169.254.169.254/latest'), false);
  assert.equal(isSafeOutboundUrl('not-a-url'), false);
});

test('lookupShipment özel ağ URL’sini çağırmaz', async () => {
  process.env.TRACKING_API_URL = 'https://127.0.0.1/lookup';
  let called = false;
  const original = globalThis.fetch;
  globalThis.fetch = (async () => {
    called = true;
    return new Response('{}', { status: 200 });
  }) as typeof fetch;
  try {
    const result = await lookupShipment('JLG-1');
    assert.equal(result.state, 'error');
    assert.equal(called, false);
  } finally {
    globalThis.fetch = original;
  }
});

test('submitInquiry özel ağ webhook’unu çağırmaz', async () => {
  process.env.INQUIRY_WEBHOOK_URL = 'http://169.254.169.254/latest';
  let called = false;
  const original = globalThis.fetch;
  globalThis.fetch = (async () => {
    called = true;
    return new Response('ok', { status: 200 });
  }) as typeof fetch;
  try {
    const result = await submitInquiry('contact', form(valid));
    assert.equal(result.ok, false);
    assert.equal(called, false);
  } finally {
    globalThis.fetch = original;
  }
});

test('lookupShipment empty / unconfigured / ok / error', async () => {
  assert.equal((await lookupShipment('')).state, 'empty');
  assert.equal((await lookupShipment('JLG-1')).state, 'unconfigured');

  process.env.TRACKING_API_URL = 'https://track.test/lookup';
  const original = globalThis.fetch;
  globalThis.fetch = (async () =>
    new Response(JSON.stringify({ headline: 'Yolda', detail: 'İzmir' }), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    })) as typeof fetch;
  try {
    const ok = await lookupShipment('JLG-1');
    assert.equal(ok.state, 'ok');
    if (ok.state === 'ok') {
      assert.equal(ok.headline, 'Yolda');
      assert.equal(ok.detail, 'İzmir');
    }
  } finally {
    globalThis.fetch = original;
  }

  globalThis.fetch = (async () => new Response('no', { status: 503 })) as typeof fetch;
  try {
    const err = await lookupShipment('JLG-1');
    assert.equal(err.state, 'error');
  } finally {
    globalThis.fetch = original;
  }
});
