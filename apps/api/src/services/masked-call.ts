import { decryptField } from '@dijigoo/core';

/** Decrypt if needed, then normalise to E.164. Legacy plaintext still works. */
export function plaintextPhone(
  stored: string | null | undefined,
  key: Buffer,
): string | null {
  return dialableFromStored(decryptField(stored, key));
}

/** Mock / live-prep: stored value is treated as MSISDN until field encryption lands. */
export function dialableFromStored(raw: string | null | undefined): string | null {
  if (!raw) return null;
  const digits = raw.replace(/\D/g, '');
  if (digits.length < 10) return null;
  if (digits.startsWith('90') && digits.length >= 12) return `+${digits}`;
  if (digits.startsWith('0') && digits.length >= 11) return `+90${digits.slice(1)}`;
  if (digits.length === 10) return `+90${digits}`;
  return `+${digits}`;
}
