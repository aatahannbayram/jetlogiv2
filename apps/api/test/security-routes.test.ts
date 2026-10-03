import assert from 'node:assert/strict';
import { test } from 'node:test';

import Fastify from 'fastify';
import rateLimit from '@fastify/rate-limit';

import {
  REMOVED_TASK_IDS_LIMIT,
  activationStartRateLimit,
  activationVerifyRateLimit,
  taskOtpRateLimit,
} from '../src/rate-limits.js';
import {
  decoyChallenge,
  shouldIssueActivation,
} from '../src/services/activation.js';
import { MOCK_PROXY_MSISDN, proxyDialNumber } from '../src/services/masked-call.js';

test('proxyDialNumber alıcı MSISDN dönmez', () => {
  const recipient = '+905321110026';
  const dial = proxyDialNumber(recipient);
  assert.equal(dial, MOCK_PROXY_MSISDN);
  assert.notEqual(dial, recipient);
  assert.notEqual(proxyDialNumber(MOCK_PROXY_MSISDN), MOCK_PROXY_MSISDN);
});

test('task OTP rate limit inject ile 429 döner', async () => {
  const app = Fastify({ logger: false });
  await app.register(rateLimit, { global: false });
  app.post('/otp', { config: { rateLimit: { max: 2, timeWindow: '1 minute' } } }, async () => ({
    ok: true,
  }));
  await app.ready();
  assert.equal((await app.inject({ method: 'POST', url: '/otp' })).statusCode, 200);
  assert.equal((await app.inject({ method: 'POST', url: '/otp' })).statusCode, 200);
  assert.equal((await app.inject({ method: 'POST', url: '/otp' })).statusCode, 429);
  await app.close();
});

test('taskOtpRateLimit send/verify ile aynı sıkı pencerede', () => {
  assert.equal(taskOtpRateLimit.max, 10);
  assert.equal(taskOtpRateLimit.timeWindow, '10 minutes');
});

test('shouldIssueActivation yalnız aktif kuryeye SMS isteği açar', () => {
  assert.equal(shouldIssueActivation(null), false);
  assert.equal(shouldIssueActivation({ status: 'inactive' }), false);
  assert.equal(shouldIssueActivation({ status: 'suspended' }), false);
  assert.equal(shouldIssueActivation({ status: 'active' }), true);
});

test('decoyChallenge gerçek cevap şeklindedir ve numarayı sızdırmaz', () => {
  const a = decoyChallenge();
  const b = decoyChallenge();
  assert.equal(a.codeLength, 6);
  assert.equal(a.attemptsRemaining, 5);
  assert.match(a.challengeId, /^[0-9a-f-]{36}$/);
  assert.notEqual(a.challengeId, b.challengeId);
  assert.ok(Date.parse(a.expiresAt) > Date.now());
  assert.equal(JSON.stringify(a).includes('+90'), false);
});

test('aktivasyon start/verify rate limit inject ile 429 döner', async () => {
  const app = Fastify({ logger: false });
  await app.register(rateLimit, { global: false });
  app.post('/start', { config: { rateLimit: { max: 2, timeWindow: '1 minute' } } }, async () =>
    decoyChallenge(),
  );
  app.post('/verify', { config: { rateLimit: { max: 2, timeWindow: '1 minute' } } }, async () => ({
    ok: false,
  }));
  await app.ready();
  assert.equal((await app.inject({ method: 'POST', url: '/start' })).statusCode, 200);
  assert.equal((await app.inject({ method: 'POST', url: '/start' })).statusCode, 200);
  assert.equal((await app.inject({ method: 'POST', url: '/start' })).statusCode, 429);
  assert.equal((await app.inject({ method: 'POST', url: '/verify' })).statusCode, 200);
  assert.equal((await app.inject({ method: 'POST', url: '/verify' })).statusCode, 200);
  assert.equal((await app.inject({ method: 'POST', url: '/verify' })).statusCode, 429);
  await app.close();
});

test('aktivasyon ve senkron tavanları sıkı', () => {
  assert.equal(activationStartRateLimit.max, 5);
  assert.equal(activationStartRateLimit.timeWindow, '10 minutes');
  assert.equal(activationVerifyRateLimit.max, 10);
  assert.equal(REMOVED_TASK_IDS_LIMIT, 200);
});
