import { decryptField, normalizeE164 } from '@dijigoo/core';

/** Placeholder DID the handset dials. Never the recipient MSISDN. */
export const MOCK_PROXY_MSISDN = '+908500000026';

/** Live 850 DID shown to the customer; never a personal GSM. */
export const SOLVELINE_DID_E164 = '+908504808538';

/** Proxy the courier dials. Must not equal the stored recipient number. */
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
  return normalizeE164(raw);
}
