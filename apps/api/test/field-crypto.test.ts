import assert from 'node:assert/strict';
import { test } from 'node:test';

import { decryptField, encryptField, fieldKeyFromEnv } from '@dijigoo/core';

import { plaintextPhone, proxyDialNumber } from '../src/services/masked-call.js';
import { signOtpProof, verifyOtpProof } from '../src/services/otp-token.js';

test('alan sifreleme yuvarlak trip ve eski duz metin', () => {
  const key = fieldKeyFromEnv('eWVyZWwtZ2VsaXN0aXJtZS1hbmFodGFyaS0zMmJ5dGUh');
  const enc = encryptField('+905321110026', key);
  assert.equal(enc.startsWith('v1:'), true);
  assert.equal(decryptField(enc, key), '+905321110026');
  assert.equal(decryptField('+905321110026', key), '+905321110026');
  assert.equal(plaintextPhone(enc, key), '+905321110026');
  assert.notEqual(proxyDialNumber('+905321110026'), '+905321110026');
});

test('OTP kanit tokeni dogrular ve suresi dolani reddeder', () => {
  const token = signOtpProof('secret-secret-secret-secret-secret', 'task-1', 'otp_dogrula', 'ch-1');
  assert.equal(verifyOtpProof('secret-secret-secret-secret-secret', token, 'task-1', 'otp_dogrula'), true);
  assert.equal(verifyOtpProof('secret-secret-secret-secret-secret', token, 'task-2', 'otp_dogrula'), false);
  assert.equal(verifyOtpProof('wrong', token, 'task-1', 'otp_dogrula'), false);
});
