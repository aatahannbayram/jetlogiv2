/**
 * Unknown / inactive numbers get the same shaped payload as a real
 * challenge so this endpoint cannot be used as a roster oracle.
 */
export function shouldIssueActivation(
  courier: { status: string } | null | undefined,
): boolean {
  return courier?.status === 'active';
}

export function decoyChallenge(): {
  challengeId: string;
  codeLength: number;
  expiresAt: string;
  resendAvailableAt: string;
  attemptsRemaining: number;
  integrityNonce: string;
} {
  const now = Date.now();
  return {
    challengeId: crypto.randomUUID(),
    codeLength: 6,
    expiresAt: new Date(now + 300_000).toISOString(),
    resendAvailableAt: new Date(now + 60_000).toISOString(),
    attemptsRemaining: 5,
    integrityNonce: Buffer.from(crypto.randomUUID()).toString('base64url'),
  };
}
