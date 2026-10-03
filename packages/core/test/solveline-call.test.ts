import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  buildIvrVariable,
  createSolvelineCallClient,
  extractRecordingUrl,
  istanbulYmd,
  IVR_EMPTY,
  parseOriginateResult,
  shouldCopyRecording,
} from '../src/solveline-call.js';

test('buildIvrVariable: 994 OTP ve 993 randevu, ayri sablon', () => {
  assert.equal(IVR_EMPTY, '-');
  assert.equal(buildIvrVariable({ firmaId: '9', kind: 'otp', code: '123456' }), '9@tr@123456');
  assert.equal(
    buildIvrVariable({
      firmaId: '9',
      kind: 'appointment',
      dateLabel: '22 Nisan 2026',
      placeLabel: 'MALATYA / YESILYURT',
    }),
    '9@tr@22 Nisan 2026@MALATYA / YESILYURT',
  );
  assert.equal(buildIvrVariable({ firmaId: '9', dateLabel: '  ', code: '' }).includes('\u2014'), false);
  assert.equal(
    buildIvrVariable({
      firmaId: '1',
      kind: 'appointment',
      dateLabel: '22 Nisan 2026 Pazartesi',
      placeLabel: 'MALATYA / YESILYURT',
    }),
    '1@tr@22 Nisan 2026 Pazartesi@MALATYA / YESILYURT',
  );
  assert.equal(buildIvrVariable({ firmaId: '1', kind: 'otp', code: '123456' }), '1@tr@123456');
});

test('IVR DYNAMIC kayit kopyalanmaz, OUTBOUND kopyalanir', () => {
  assert.equal(shouldCopyRecording('DYNAMIC'), false);
  assert.equal(shouldCopyRecording('OUTBOUND'), true);
  assert.equal(shouldCopyRecording(null), true);
});

test('parseOriginateResult uniqueid ve variable okur', () => {
  const parsed = parseOriginateResult({
    originateresult: {
      company: 'TEKLIFBILSM',
      application: 'TRUNK',
      status: 'ANSWER',
      caller: '908504808538',
      callee: '905301230544',
      uniqueid: '111-55849811574444.1',
      variable: 'sess-1',
      callduration: '12',
      result: '0',
    },
  });
  assert.equal(parsed?.status, 'ANSWER');
  assert.equal(parsed?.uniqueId, '111-55849811574444.1');
  assert.equal(parsed?.variable, 'sess-1');
  assert.equal(parsed?.callDuration, '12');
});

test('click-to-call: caller.1 kurye, destination alici, uniqueid status 1', async () => {
  const seen: unknown[] = [];
  const fetchImpl: typeof fetch = async (input, init) => {
    seen.push({ url: String(input), body: JSON.parse(String(init?.body)) });
    return new Response(
      JSON.stringify({
        callinfo: [
          {
            id: '1',
            caller: '905074084007',
            uniqueid: '111-55849811574444.1',
            status: '1',
            message: 'no error',
          },
        ],
      }),
      { status: 200 },
    );
  };

  const client = createSolvelineCallClient(
    {
      SOLVELINE_CALL_BASE_URL: 'https://capi.example.test',
      SOLVELINE_CALL_TOKEN: 'test-token',
      SOLVELINE_CALLER_ID: '908504808538',
      SOLVELINE_CALL_WEBHOOK_URL: 'https://api.example.test/v1/webhooks/solveline/call',
      SOLVELINE_WEBHOOK_SECRET: 'webhook-secret-16ch',
    },
    () => {},
    fetchImpl,
  );
  assert.ok(client);
  const result = await client.originateClickToCall({
    courierMsisdn: '+905074084007',
    recipientMsisdn: '+905321110026',
    variable: 'sess-1',
  });
  assert.equal(result.uniqueId, '111-55849811574444.1');
  const req = seen[0] as { url: string; body: Record<string, unknown> };
  assert.equal(req.url, 'https://capi.example.test/call/call');
  assert.equal(req.body.application, 'OUTBOUND');
  assert.equal(req.body.destination, '905321110026');
  assert.equal((req.body.caller as { '1': string })['1'], '905074084007');
  assert.equal(req.body.callerid, '908504808538');
  assert.match(String(req.body.responseurl), /token=webhook-secret-16ch/);
});

test('IVR DYNAMIC: destination 994, caller.1 yalniz alici', async () => {
  const seen: unknown[] = [];
  const fetchImpl: typeof fetch = async (_input, init) => {
    seen.push(JSON.parse(String(init?.body)));
    return new Response(
      JSON.stringify({
        callinfo: [{ uniqueid: 'ivr-1', status: '1' }],
      }),
      { status: 200 },
    );
  };
  const client = createSolvelineCallClient(
    {
      SOLVELINE_CALL_TOKEN: 't',
      SOLVELINE_FIRMA_ID: '9',
      SOLVELINE_CALL_BASE_URL: 'https://capi.example.test',
    },
    () => {},
    fetchImpl,
  );
  assert.equal(client?.canIvr(), true);
  await client!.originateIvr({
    destination: '994',
    caller1: '905321110026',
    variable: buildIvrVariable({ firmaId: '9', kind: 'otp', code: '445566' }),
  });
  const body = seen[0] as Record<string, unknown>;
  assert.equal(body.application, 'DYNAMIC');
  assert.equal(body.destination, '994');
  assert.equal((body.caller as { '1': string })['1'], '905321110026');
  assert.equal(body.variable, '9@tr@445566');
});

test('IVR DYNAMIC: destination 993 randevu, caller.1 yalniz alici', async () => {
  const seen: unknown[] = [];
  const fetchImpl: typeof fetch = async (_input, init) => {
    seen.push(JSON.parse(String(init?.body)));
    return new Response(JSON.stringify({ callinfo: [{ uniqueid: 'ivr-993', status: '1' }] }), { status: 200 });
  };
  const client = createSolvelineCallClient(
    {
      SOLVELINE_CALL_TOKEN: 't',
      SOLVELINE_FIRMA_ID: '1',
      SOLVELINE_CALL_BASE_URL: 'https://capi.example.test',
    },
    () => {},
    fetchImpl,
  );
  await client!.originateIvr({
    destination: '993',
    caller1: '905074084007',
    variable: buildIvrVariable({
      firmaId: '1',
      kind: 'appointment',
      dateLabel: '22 Nisan 2026 Pazartesi',
      placeLabel: 'MALATYA / YESILYURT',
    }),
  });
  const body = seen[0] as Record<string, unknown>;
  assert.equal(body.application, 'DYNAMIC');
  assert.equal(body.destination, '993');
  assert.equal((body.caller as { '1': string })['1'], '905074084007');
  assert.equal(body.variable, '1@tr@22 Nisan 2026 Pazartesi@MALATYA / YESILYURT');
});

test('firma id yoksa IVR kapali', () => {
  const client = createSolvelineCallClient({ SOLVELINE_CALL_TOKEN: 't' });
  assert.equal(client?.canIvr(), false);
});

test('token yoksa client olusmaz', () => {
  assert.equal(createSolvelineCallClient({}), null);
});

test('getrecording uniqueid + ayni gun startdate/enddate, URL cikarir', async () => {
  const seen: unknown[] = [];
  const fetchImpl: typeof fetch = async (input, init) => {
    seen.push({ url: String(input), body: JSON.parse(String(init?.body)) });
    return new Response(JSON.stringify({ url: 'https://rec.example.test/a.wav?exp=1' }), { status: 200 });
  };
  const client = createSolvelineCallClient(
    { SOLVELINE_CALL_TOKEN: 't', SOLVELINE_CALL_BASE_URL: 'https://capi.example.test' },
    () => {},
    fetchImpl,
  );
  const day = istanbulYmd(new Date('2026-09-14T10:00:00+03:00'));
  const url = await client!.getRecording({ uniqueId: '111-1', startDate: day, endDate: day });
  assert.equal(url, 'https://rec.example.test/a.wav?exp=1');
  const req = seen[0] as { url: string; body: Record<string, unknown> };
  assert.equal(req.url, 'https://capi.example.test/reports/getrecording');
  assert.equal(req.body.uniqueid, '111-1');
  assert.equal(req.body.startdate, day);
  assert.equal(req.body.enddate, day);
  assert.equal(req.body.startdate, req.body.enddate);
});

test('extractRecordingUrl nested ve duz URL', () => {
  assert.equal(extractRecordingUrl('https://x.test/r'), 'https://x.test/r');
  assert.equal(extractRecordingUrl({ recordingfile: 'https://x.test/f' }), 'https://x.test/f');
  assert.equal(extractRecordingUrl({ data: { url: 'https://x.test/d' } }), 'https://x.test/d');
});

test('istanbulYmd Europe/Istanbul takvim gunu', () => {
  assert.equal(istanbulYmd(new Date('2026-09-13T22:30:00.000Z')), '2026-09-14');
});

test('parseOriginateResult DYNAMIC application; kayit kopyalanmaz', () => {
  const parsed = parseOriginateResult({
    originateresult: {
      application: 'DYNAMIC',
      status: 'ANSWER',
      uniqueid: 'ivr-dyn',
      variable: '1@tr@123456',
    },
  });
  assert.equal(parsed?.application, 'DYNAMIC');
  assert.equal(shouldCopyRecording(parsed?.application), false);
});

test('parseOriginateResult string JSON ve bos govde', () => {
  const parsed = parseOriginateResult(
    JSON.stringify({ originateResult: { uniqueid: 'u-1', variable: 'v', status: 'NOANSWER' } }),
  );
  assert.equal(parsed?.uniqueId, 'u-1');
  assert.equal(parsed?.status, 'NOANSWER');
  assert.equal(parseOriginateResult(null), null);
  assert.equal(parseOriginateResult(''), null);
  assert.equal(parseOriginateResult({ foo: 1 }), null);
});

test('originate status 1 degilse hata', async () => {
  const fetchImpl: typeof fetch = async () =>
    new Response(JSON.stringify({ callinfo: [{ uniqueid: 'x', status: '0' }] }), { status: 200 });
  const client = createSolvelineCallClient(
    { SOLVELINE_CALL_TOKEN: 't', SOLVELINE_CALL_BASE_URL: 'https://capi.example.test' },
    () => {},
    fetchImpl,
  );
  await assert.rejects(
    () =>
      client!.originateClickToCall({
        courierMsisdn: '+905074084007',
        recipientMsisdn: '+905321110026',
        variable: 'sess',
      }),
    /kuyruga alinamadi/,
  );
});

test('click-to-call gecersiz MSISDN', async () => {
  const client = createSolvelineCallClient({ SOLVELINE_CALL_TOKEN: 't' });
  await assert.rejects(
    () =>
      client!.originateClickToCall({
        courierMsisdn: 'dev-placeholder',
        recipientMsisdn: '+905321110026',
        variable: 's',
      }),
    /gecersiz/,
  );
});

test('shouldCopyRecording buyuk/kucuk harf', () => {
  assert.equal(shouldCopyRecording('dynamic'), false);
  assert.equal(shouldCopyRecording(' Dynamic '), false);
  assert.equal(shouldCopyRecording('TRUNK'), true);
});
