import assert from 'node:assert/strict';
import { test } from 'node:test';

import { parseFcmAccount, tryDispatchInboxPush } from '../src/services/fcm.js';

test('parseFcmAccount: bos veya bozuk JSON yok sayilir', () => {
  assert.equal(parseFcmAccount(undefined), null);
  assert.equal(parseFcmAccount(''), null);
  assert.equal(parseFcmAccount('{'), null);
  assert.equal(parseFcmAccount('{"project_id":"x"}'), null);
});

test('parseFcmAccount: servis hesabi ve kacisli private_key', () => {
  const account = parseFcmAccount(
    '{"project_id":"dijigoo","client_email":"fcm@dijigoo.iam.gserviceaccount.com","private_key":"-----BEGIN PRIVATE KEY-----\\nABC\\n-----END PRIVATE KEY-----\\n"}',
  );
  assert.ok(account);
  assert.equal(account!.projectId, 'dijigoo');
  assert.equal(account!.clientEmail, 'fcm@dijigoo.iam.gserviceaccount.com');
  assert.ok(account!.privateKey.includes('\nABC\n'));
});

test('tryDispatchInboxPush: hesap yoksa gondermez', async () => {
  const sent = await tryDispatchInboxPush(
    {} as never,
    null,
    { courierId: 'x', id: 'y', kind: 'SLA_AT_RISK', title: 't', body: 'b' },
  );
  assert.equal(sent, false);
});
