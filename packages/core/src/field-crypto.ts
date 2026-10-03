import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';

const PREFIX = 'v1:';
const IV_LEN = 12;
const TAG_LEN = 16;

export function fieldKeyFromEnv(raw: string): Buffer {
  const buf = Buffer.from(raw, 'base64');
  if (buf.length === 32) return buf;
  const utf = Buffer.from(raw, 'utf8');
  if (utf.length >= 32) return utf.subarray(0, 32);
  throw new Error('FIELD_ENCRYPTION_KEY 32 bayt (base64) olmali.');
}

export function encryptField(plaintext: string, key: Buffer): string {
  const iv = randomBytes(IV_LEN);
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  const body = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return PREFIX + Buffer.concat([iv, body, tag]).toString('base64');
}

/** Encrypted blob or legacy plaintext (E.164 / digits). */
export function decryptField(stored: string | null | undefined, key: Buffer): string | null {
  if (!stored) return null;
  if (!stored.startsWith(PREFIX)) return stored;
  try {
    const raw = Buffer.from(stored.slice(PREFIX.length), 'base64');
    if (raw.length < IV_LEN + TAG_LEN + 1) return null;
    const iv = raw.subarray(0, IV_LEN);
    const tag = raw.subarray(raw.length - TAG_LEN);
    const data = raw.subarray(IV_LEN, raw.length - TAG_LEN);
    const decipher = createDecipheriv('aes-256-gcm', key, iv);
    decipher.setAuthTag(tag);
    return Buffer.concat([decipher.update(data), decipher.final()]).toString('utf8');
  } catch {
    return null;
  }
}
