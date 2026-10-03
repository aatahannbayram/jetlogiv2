import assert from 'node:assert/strict';
import { test } from 'node:test';

import Fastify from 'fastify';
import {
  IvrShipmentListResponse,
  IvrTicketCreateRequest,
  MaskedCallResponse,
} from '@dijigoo/contracts';
import { parseOriginateResult, shouldCopyRecording } from '@dijigoo/core';

import { solvelineAuth } from '../src/plugins/solveline-auth.js';
import { errorHandler } from '../src/plugins/error-handler.js';
import { ipAllowed, parseCidrList } from '../src/services/cidr.js';
import { SOLVELINE_DID_E164 } from '../src/services/masked-call.js';
import type { AppContext } from '../src/context.js';

test('MaskedCallResponse originated tel numarasi zorunlu degil', () => {
  const parsed = MaskedCallResponse.parse({
    mode: 'originated',
    sessionId: '00000000-0000-4000-a000-000000000001',
    expiresAt: '2026-09-14T12:00:00.000Z',
    message: 'Sizi ve aliciyi ariyoruz',
  });
  assert.equal(parsed.mode, 'originated');
  assert.equal(parsed.dialNumber, undefined);
});

test('T03 inbound bos liste gecerli', () => {
  const parsed = IvrShipmentListResponse.parse({ shipments: [] });
  assert.equal(parsed.shipments.length, 0);
});

test('Ivr ticket kind expedite', () => {
  const body = IvrTicketCreateRequest.parse({ kind: 'expedite', note: 'IVR' });
  assert.equal(body.kind, 'expedite');
});

test('T04 MaskedCallResponse alici/kurye GSM alani tasimaz', () => {
  const parsed = MaskedCallResponse.parse({
    mode: 'originated',
    sessionId: '00000000-0000-4000-a000-000000000001',
    expiresAt: '2026-09-14T12:00:00.000Z',
    message: 'Sizi ve aliciyi ariyoruz',
  });
  const keys = Object.keys(parsed);
  assert.equal(keys.includes('phone'), false);
  assert.equal(JSON.stringify(parsed).includes('iban'), false);
});

test('inbound CIDR: bos liste gecer, yabanci IP hayir', () => {
  assert.equal(ipAllowed('203.0.113.4', []), true);
  assert.equal(ipAllowed('203.0.113.4', parseCidrList('203.0.113.0/24')), true);
  assert.equal(ipAllowed('198.51.100.9', parseCidrList('203.0.113.0/24')), false);
  assert.equal(ipAllowed('::ffff:203.0.113.4', parseCidrList('203.0.113.4')), true);
  assert.equal(ipAllowed('not-an-ip', parseCidrList('203.0.113.0/24')), false);
  assert.equal(ipAllowed('203.0.113.4', parseCidrList('0.0.0.0/0')), true);
});

test('DYNAMIC IVR ses kaydi kopyalanmaz', () => {
  assert.equal(shouldCopyRecording('DYNAMIC'), false);
  assert.equal(shouldCopyRecording('OUTBOUND'), true);
});

test('850 DID alici GSM degil', () => {
  assert.equal(SOLVELINE_DID_E164.startsWith('+90850'), true);
  assert.notEqual(SOLVELINE_DID_E164, '+905321110026');
});

test('inbound CIDR disi IP 401', async () => {
  const app = Fastify({ logger: false });
  await app.register(errorHandler);
  await app.register(solvelineAuth, {
    ctx: {
      env: {
        SOLVELINE_INBOUND_TOKEN: 'inbound-token-16ch',
        SOLVELINE_WEBHOOK_SECRET: 'webhook-secret-16ch',
        SOLVELINE_INBOUND_CIDRS: '203.0.113.0/24',
      },
    } as AppContext,
  });
  app.get('/v1/ivr/shipments', async (request) => {
    await app.authenticateSolvelineInbound(request);
    return { shipments: [] };
  });
  await app.ready();
  assert.equal(
    (
      await app.inject({
        method: 'GET',
        url: '/v1/ivr/shipments?phone=905321110026',
        headers: { authorization: 'Bearer inbound-token-16ch' },
      })
    ).statusCode,
    401,
  );
  await app.close();
});

test('inbound Bearer yoksa 401', async () => {
  const app = Fastify({ logger: false });
  await app.register(errorHandler);
  await app.register(solvelineAuth, {
    ctx: {
      env: {
        SOLVELINE_INBOUND_TOKEN: 'inbound-token-16ch',
        SOLVELINE_WEBHOOK_SECRET: 'webhook-secret-16ch',
      },
    } as AppContext,
  });
  app.get('/v1/ivr/shipments', async (request) => {
    await app.authenticateSolvelineInbound(request);
    return { shipments: [] };
  });
  await app.ready();
  assert.equal((await app.inject({ method: 'GET', url: '/v1/ivr/shipments?phone=905321110026' })).statusCode, 401);
  assert.equal(
    (
      await app.inject({
        method: 'GET',
        url: '/v1/ivr/shipments?phone=905321110026',
        headers: { authorization: 'Bearer inbound-token-16ch' },
      })
    ).statusCode,
    200,
  );
  await app.close();
});

test('IVR results Bearer yoksa 401', async () => {
  const app = Fastify({ logger: false });
  await app.register(errorHandler);
  await app.register(solvelineAuth, {
    ctx: {
      env: {
        SOLVELINE_INBOUND_TOKEN: 'inbound-token-16ch',
        SOLVELINE_WEBHOOK_SECRET: 'webhook-secret-16ch',
      },
    } as AppContext,
  });
  app.post('/v1/ivr/results', async (request) => {
    await app.authenticateSolvelineInbound(request);
    return { uniqueId: 'x', selection: 'confirm', duplicate: false };
  });
  await app.ready();
  assert.equal((await app.inject({ method: 'POST', url: '/v1/ivr/results', payload: { uniqueId: '1', selection: 'confirm' } })).statusCode, 401);
  assert.equal(
    (
      await app.inject({
        method: 'POST',
        url: '/v1/ivr/results',
        headers: { authorization: 'Bearer inbound-token-16ch' },
        payload: { uniqueId: '1', selection: 'confirm' },
      })
    ).statusCode,
    200,
  );
  await app.close();
});

test('webhook token yoksa 401, originateresult parse edilir', async () => {
  const app = Fastify({ logger: false });
  await app.register(errorHandler);
  await app.register(solvelineAuth, {
    ctx: {
      env: {
        SOLVELINE_INBOUND_TOKEN: 'inbound-token-16ch',
        SOLVELINE_WEBHOOK_SECRET: 'webhook-secret-16ch',
      },
    } as AppContext,
  });
  app.post('/v1/webhooks/solveline/call', async (request) => {
    await app.authenticateSolvelineWebhook(request);
    return { ok: true, parsed: parseOriginateResult(request.body) };
  });
  await app.ready();
  assert.equal((await app.inject({ method: 'POST', url: '/v1/webhooks/solveline/call' })).statusCode, 401);
  const ok = await app.inject({
    method: 'POST',
    url: '/v1/webhooks/solveline/call?token=webhook-secret-16ch',
    payload: {
      originateresult: {
        status: 'ANSWER',
        uniqueid: '111-1',
        variable: '00000000-0000-4000-a000-000000000001',
        callduration: '3',
      },
    },
  });
  assert.equal(ok.statusCode, 200);
  const body = ok.json() as { parsed: { uniqueId: string; status: string } };
  assert.equal(body.parsed.uniqueId, '111-1');
  assert.equal(body.parsed.status, 'ANSWER');
  const ignored = await app.inject({
    method: 'POST',
    url: '/v1/webhooks/solveline/call?token=webhook-secret-16ch',
    payload: { foo: 'bar' },
  });
  assert.equal(ignored.statusCode, 200);
  const ignoredBody = ignored.json() as { parsed: null };
  assert.equal(ignoredBody.parsed, null);
  await app.close();
});
