import type { IntegrityAssertion, IntegrityVerdict, Platform } from '@dijigoo/contracts';

import type { Env } from '../env.js';

type Signal = IntegrityVerdict['signals'][number];

/**
 * Weight per signal. Nothing here is fatal on its own; the score is a risk
 * indicator the panel can act on, not a gate. A courier whose phone reports
 * `ATTESTATION_UNAVAILABLE` on a rural network must still be able to deliver.
 */
const SIGNAL_WEIGHTS: Record<Signal, number> = {
  ROOTED_OR_JAILBROKEN: 45,
  EMULATOR: 60,
  UNRECOGNIZED_APP_SIGNATURE: 70,
  UNLICENSED_INSTALL: 30,
  MOCK_LOCATION_ENABLED: 50,
  HOOKING_FRAMEWORK: 65,
  ATTESTATION_UNAVAILABLE: 10,
};

export interface IntegrityCheckInput {
  assertion: IntegrityAssertion | null | undefined;
  /** Nonce the server issued with the activation challenge. */
  expectedNonce: string | null;
  platform: Platform;
}

/**
 * Verifies a Play Integrity / App Attest assertion and turns it into a score.
 *
 * The real verification is two separate protocols: Google's Play Integrity API
 * decodes a JWS against a Google-held key, Apple's App Attest verifies an
 * attestation object against Apple's root CA. Both need production credentials
 * that do not exist yet, so this class is structured around the decision it
 * has to make and leaves the transport as the only thing to fill in.
 */
export class IntegrityService {
  constructor(private readonly env: Env) {}

  async evaluate(input: IntegrityCheckInput): Promise<IntegrityVerdict> {
    if (this.env.DEVICE_INTEGRITY_MODE === 'off') {
      return this.verdict([], 'allow');
    }

    if (!input.assertion) {
      return this.verdict(['ATTESTATION_UNAVAILABLE'], 'allow');
    }

    // A replayed assertion is worthless: without a fresh, server-issued nonce
    // an attacker can capture one good attestation and reuse it forever.
    if (!input.expectedNonce || input.assertion.nonce !== input.expectedNonce) {
      return this.verdict(['UNRECOGNIZED_APP_SIGNATURE'], this.actionFor(70));
    }

    const signals =
      input.platform === 'android'
        ? await this.verifyPlayIntegrity(input.assertion.token)
        : await this.verifyAppAttest(input.assertion.token);

    const score = this.scoreOf(signals);
    return this.verdict(signals, this.actionFor(score));
  }

  private scoreOf(signals: Signal[]): number {
    // Saturating sum: three medium signals should not read as "impossible".
    const total = signals.reduce((acc, s) => acc + (SIGNAL_WEIGHTS[s] ?? 0), 0);
    return Math.min(100, total);
  }

  private actionFor(score: number): IntegrityVerdict['action'] {
    if (this.env.DEVICE_INTEGRITY_MODE === 'log') return 'allow';
    if (score >= 60) return 'review';
    if (score >= 30) return 'restrict';
    return 'allow';
  }

  private verdict(signals: Signal[], action: IntegrityVerdict['action']): IntegrityVerdict {
    return {
      score: this.scoreOf(signals),
      signals,
      action,
      evaluatedAt: new Date().toISOString(),
    };
  }

  /**
   * Play Integrity: POST the token to
   * `playintegrity.googleapis.com/v1/{packageName}:decodeIntegrityToken` with a
   * service-account credential, then map the verdict fields:
   *   appIntegrity.appRecognitionVerdict !== PLAY_RECOGNIZED -> UNRECOGNIZED_APP_SIGNATURE
   *   deviceIntegrity.deviceRecognitionVerdict missing MEETS_DEVICE_INTEGRITY -> ROOTED_OR_JAILBROKEN
   *   accountDetails.appLicensingVerdict !== LICENSED -> UNLICENSED_INSTALL
   */
  private async verifyPlayIntegrity(_token: string): Promise<Signal[]> {
    if (!this.env.SMS_API_KEY && this.env.NODE_ENV !== 'production') {
      return ['ATTESTATION_UNAVAILABLE'];
    }
    throw new Error('Play Integrity dogrulamasi icin servis hesabi tanimlanmadi.');
  }

  /**
   * App Attest: verify the CBOR attestation object's certificate chain against
   * Apple's App Attest root, check the nonce in the authenticator data, then
   * persist the public key and counter so subsequent assertions can be checked
   * against a monotonically increasing counter.
   */
  private async verifyAppAttest(_token: string): Promise<Signal[]> {
    if (this.env.NODE_ENV !== 'production') {
      return ['ATTESTATION_UNAVAILABLE'];
    }
    throw new Error('App Attest dogrulamasi icin Apple anahtar yapilandirmasi eksik.');
  }
}
