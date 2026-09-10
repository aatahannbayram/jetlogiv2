import { createHmac, timingSafeEqual } from 'node:crypto';

const TTL_MS = 10 * 60 * 1000;

export function signOtpProof(secret: string, taskId: string, stepKey: string, challengeId: string): string {
  const exp = Date.now() + TTL_MS;
  const mac = createHmac('sha256', secret)
    .update(`${taskId}.${stepKey}.${challengeId}.${exp}`)
    .digest('base64url');
  return `${exp}.${challengeId}.${mac}`;
}

export function verifyOtpProof(secret: string, token: unknown, taskId: string, stepKey: string): boolean {
  if (typeof token !== 'string') return false;
  const parts = token.split('.');
  if (parts.length < 3) return false;
  const exp = Number(parts[0]);
  const challengeId = parts[1] ?? '';
  const mac = parts.slice(2).join('.');
  if (!Number.isFinite(exp) || exp < Date.now()) return false;
  const expected = createHmac('sha256', secret)
    .update(`${taskId}.${stepKey}.${challengeId}.${exp}`)
    .digest('base64url');
  const a = Buffer.from(mac);
  const b = Buffer.from(expected);
  return a.length === b.length && timingSafeEqual(a, b);
}
