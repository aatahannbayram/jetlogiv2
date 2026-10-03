import { createHmac } from 'node:crypto';

/**
 * Normalise a stored or typed phone to E.164 (+90…). Returns null when the
 * value is too short or a non-number placeholder.
 */
export function normalizeE164(raw: string | null | undefined): string | null {
  if (!raw) return null;
  const digits = raw.replace(/\D/g, '');
  if (digits.length < 10) return null;
  if (digits.startsWith('90') && digits.length >= 12) return `+${digits}`;
  if (digits.startsWith('0') && digits.length >= 11) return `+90${digits.slice(1)}`;
  if (digits.length === 10) return `+90${digits}`;
  return `+${digits}`;
}

/**
 * Solveline MSISDN: digits only, country code, no plus (90532…).
 */
export function toSolvelineMsisdn(raw: string | null | undefined): string | null {
  const e164 = normalizeE164(raw);
  if (!e164) return null;
  return e164.replace(/\D/g, '');
}

/**
 * HMAC of the normalised digit string. Used as a lookup index so we never
 * store a plaintext phone column next to the encrypted blob.
 */
export function phoneLookupHmac(raw: string, key: Buffer): string | null {
  const digits = toSolvelineMsisdn(raw);
  if (!digits) return null;
  return createHmac('sha256', key).update(digits).digest('hex');
}
