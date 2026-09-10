import { decryptField } from '@dijigoo/core';

/** Placeholder DID the handset dials. Never the recipient MSISDN. */
export const MOCK_PROXY_MSISDN = '+908500000026';

/** Proxy the courier dials — must not equal the stored recipient number. */
export function proxyDialNumber(recipientMsisdn: string): string {
  const recipient = dialableFromStored(recipientMsisdn) ?? recipientMsisdn;
  if (recipient === MOCK_PROXY_MSISDN) {
    return '+908500000027';
  }
  return MOCK_PROXY_MSISDN;
}

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
