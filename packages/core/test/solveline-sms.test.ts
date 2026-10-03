import assert from 'node:assert/strict';
import { test } from 'node:test';

import { fieldKeyFromEnv } from '../src/field-crypto.js';
import { normalizeE164, phoneLookupHmac, toSolvelineMsisdn } from '../src/msisdn.js';
import { createSmsProvider } from '../src/sms.js';
import { SolvelineSmsProvider } from '../src/solveline-sms.js';

const key = fieldKeyFromEnv('eWVyZWwtZ2VsaXN0aXJtZS1hbmFodGFyaS0zMmJ5dGUh');

test('toSolvelineMsisdn: arti ve sifir on eklerini atar', () => {
  assert.equal(toSolvelineMsisdn('+905321110026'), '905321110026');
  assert.equal(toSolvelineMsisdn('0532 111 00 26'), '905321110026');
  assert.equal(toSolvelineMsisdn('5321110026'), '905321110026');
  assert.equal(normalizeE164('905321110026'), '+905321110026');
  assert.equal(toSolvelineMsisdn('dev-placeholder'), null);
});

test('phoneLookupHmac ayni numarayi ayni ozetler', () => {
  const a = phoneLookupHmac('+905321110026', key);
  const b = phoneLookupHmac('05321110026', key);
  assert.ok(a);
  assert.equal(a, b);
  assert.notEqual(a, phoneLookupHmac('+905321110027', key));
});

test('Solveline SMS create: Basic auth, 90 MSISDN, secret govdede yok', async () => {
  const calls: { url: string; headers: Record<string, string>; body: unknown }[] = [];
  const fetchImpl: typeof fetch = async (input, init) => {
    calls.push({
      url: String(input),
      headers: Object.fromEntries(new Headers(init?.headers).entries()),
      body: JSON.parse(String(init?.body)),
    });
    return new Response(JSON.stringify({ pkgID: 42 }), { status: 200 });
  };

  const provider = new SolvelineSmsProvider(
    {
      SOLVELINE_SMS_BASE_URL: 'https://sms.example.test',
      SOLVELINE_SMS_USER: 'demo-user',
      SOLVELINE_SMS_PASSWORD: 'demo-pass',
      SMS_SENDER_ID: 'JETLOGI',
    },
    () => {},
    fetchImpl,
  );

  const result = await provider.send({ to: '+905321110026', body: 'Kod: 123456' });
  assert.equal(result.providerMessageId, '42');
  assert.equal(calls.length, 1);
  assert.equal(calls[0]?.url, 'https://sms.example.test/sms/create');
  assert.equal(calls[0]?.headers.authorization, `Basic ${Buffer.from('demo-user:demo-pass').toString('base64')}`);
  const body = calls[0]?.body as Record<string, unknown>;
  assert.equal(body.number, '905321110026');
  assert.equal(body.sender, 'JETLOGI');
  assert.equal(body.type, 1);
  assert.equal(JSON.stringify(body).includes('demo-pass'), false);
});

test('T03: gecersiz telefon HMAC yok (bos eslesme)', () => {
  assert.equal(phoneLookupHmac('abc', key), null);
  assert.equal(phoneLookupHmac('12', key), null);
});

test('callWithCode 994: dest 994, variable 1@tr@kod, caller.1 alici', async () => {
  const seen: unknown[] = [];
  const fetchImpl: typeof fetch = async (_input, init) => {
    seen.push(JSON.parse(String(init?.body)));
    return new Response(JSON.stringify({ callinfo: [{ uniqueid: 'ivr-otp', status: '1' }] }), { status: 200 });
  };
  const sms = createSmsProvider(
    {
      SMS_PROVIDER: 'solveline',
      SOLVELINE_SMS_USER: 'u',
      SOLVELINE_SMS_PASSWORD: 'p',
      SOLVELINE_CALL_TOKEN: 't',
      SOLVELINE_FIRMA_ID: '1',
      SOLVELINE_CALL_BASE_URL: 'https://capi.example.test',
    },
    () => {},
    fetchImpl,
  );
  const result = await sms.callWithCode!({
    to: '905321110026',
    code: '123456',
    language: 'tr',
    kind: 'otp',
  });
  assert.equal(result.providerMessageId, 'ivr-otp');
  const body = seen[0] as Record<string, unknown>;
  assert.equal(body.application, 'DYNAMIC');
  assert.equal(body.destination, '994');
  assert.equal(body.variable, '1@tr@123456');
  assert.equal((body.caller as { '1': string })['1'], '905321110026');
  assert.equal(body.callerid, '908504808538');
});

test('callWithCode 993: dest 993, Edip variable, caller.1 alici', async () => {
  const seen: unknown[] = [];
  const fetchImpl: typeof fetch = async (_input, init) => {
    seen.push(JSON.parse(String(init?.body)));
    return new Response(JSON.stringify({ callinfo: [{ uniqueid: 'ivr-apt', status: '1' }] }), { status: 200 });
  };
  const sms = createSmsProvider(
    {
      SMS_PROVIDER: 'solveline',
      SOLVELINE_SMS_USER: 'u',
      SOLVELINE_SMS_PASSWORD: 'p',
      SOLVELINE_CALL_TOKEN: 't',
      SOLVELINE_FIRMA_ID: '1',
      SOLVELINE_CALL_BASE_URL: 'https://capi.example.test',
    },
    () => {},
    fetchImpl,
  );
  const result = await sms.callWithCode!({
    to: '905074084007',
    code: '-',
    language: 'tr',
    kind: 'appointment',
    dateLabel: '22 Nisan 2026 Pazartesi',
    placeLabel: 'MALATYA / YESILYURT',
  });
  assert.equal(result.providerMessageId, 'ivr-apt');
  const body = seen[0] as Record<string, unknown>;
  assert.equal(body.destination, '993');
  assert.equal(body.variable, '1@tr@22 Nisan 2026 Pazartesi@MALATYA / YESILYURT');
  assert.equal((body.caller as { '1': string })['1'], '905074084007');
});

test('callWithCode firma id yoksa IVR acilmaz', async () => {
  const sms = createSmsProvider(
    {
      SMS_PROVIDER: 'solveline',
      SOLVELINE_SMS_USER: 'u',
      SOLVELINE_SMS_PASSWORD: 'p',
      SOLVELINE_CALL_TOKEN: 't',
    },
    () => {},
    (async () => new Response('{}', { status: 200 })) as typeof fetch,
  );
  await assert.rejects(
    () => sms.callWithCode!({ to: '905321110026', code: '123456', language: 'tr' }),
    /SOLVELINE_FIRMA_ID/,
  );
});

test('createSmsProvider(solveline) SMS_PROVIDER=solveline secer', () => {
  const sms = createSmsProvider(
    {
      SMS_PROVIDER: 'solveline',
      SOLVELINE_SMS_USER: 'u',
      SOLVELINE_SMS_PASSWORD: 'p',
    },
    () => {},
    (async () => new Response('{}', { status: 200 })) as typeof fetch,
  );
  assert.equal(sms.name, 'solveline');
});
