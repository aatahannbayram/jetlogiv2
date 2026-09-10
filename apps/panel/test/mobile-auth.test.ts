import assert from 'node:assert/strict';
import { afterEach, test } from 'node:test';

import { SignJWT } from 'jose';

import { readMobileAuth } from '../lib/mobile-auth.js';

const original = process.env.JWT_ACCESS_SECRET;

afterEach(() => {
  if (original === undefined) delete process.env.JWT_ACCESS_SECRET;
  else process.env.JWT_ACCESS_SECRET = original;
});

function req(headers: Record<string, string>): Request {
  return new Request('http://panel.test/api', { headers });
}

test('secret yoksa Bearer olsa bile 401', async () => {
  delete process.env.JWT_ACCESS_SECRET;
  const result = await readMobileAuth(
    req({ authorization: 'Bearer anything' }),
  );
  assert.equal(result.ok, false);
  if (!result.ok) assert.equal(result.response.status, 401);
});

test('Bearer yoksa 401', async () => {
  process.env.JWT_ACCESS_SECRET = 'a'.repeat(32);
  const result = await readMobileAuth(req({}));
  assert.equal(result.ok, false);
  if (!result.ok) assert.equal(result.response.status, 401);
});

test('geçersiz JWT 401', async () => {
  process.env.JWT_ACCESS_SECRET = 'a'.repeat(32);
  const result = await readMobileAuth(req({ authorization: 'Bearer not-a-jwt' }));
  assert.equal(result.ok, false);
  if (!result.ok) assert.equal(result.response.status, 401);
});

test('geçerli JWT courierId döner', async () => {
  const secret = 'a'.repeat(32);
  process.env.JWT_ACCESS_SECRET = secret;
  process.env.JWT_ISSUER = 'dijigoo-api';
  const token = await new SignJWT({})
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject('courier-1')
    .setIssuer('dijigoo-api')
    .setIssuedAt()
    .setExpirationTime('5m')
    .sign(new TextEncoder().encode(secret));
  const result = await readMobileAuth(req({ authorization: `Bearer ${token}` }));
  assert.equal(result.ok, true);
  if (result.ok) assert.equal(result.courierId, 'courier-1');
});
