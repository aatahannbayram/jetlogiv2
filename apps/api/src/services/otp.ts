import { randomBytes, randomInt, timingSafeEqual } from 'node:crypto';
import { createHash } from 'node:crypto';

import { AppError } from '@dijigoo/core';
import type { SmsProvider } from '@dijigoo/core';
import { otpChallenges } from '@dijigoo/db';
import type { Database } from '@dijigoo/db';
import { eq, sql } from 'drizzle-orm';

export type OtpPurpose = 'activation' | 'task_delivery' | 'phone_change';

export interface OtpPolicy {
  codeLength: number;
  ttlSeconds: number;
  maxAttempts: number;
  resendCooldownSeconds: number;
  /** Hard ceiling on sends per phone per hour, independent of cooldown. */
  maxSendsPerHour: number;
}

export const DEFAULT_OTP_POLICY: Record<OtpPurpose, OtpPolicy> = {
  activation: {
    codeLength: 6,
    ttlSeconds: 300,
    maxAttempts: 5,
    resendCooldownSeconds: 60,
    maxSendsPerHour: 5,
  },
  task_delivery: {
    codeLength: 6,
    ttlSeconds: 300,
    maxAttempts: 5,
    // Shorter: the courier is standing at the door and cannot wait a minute.
    resendCooldownSeconds: 30,
    maxSendsPerHour: 10,
  },
  phone_change: {
    codeLength: 6,
    ttlSeconds: 300,
    maxAttempts: 3,
    resendCooldownSeconds: 120,
    maxSendsPerHour: 3,
  },
};

function hashCode(code: string, salt: string): string {
  return createHash('sha256').update(`${salt}:${code}`).digest('hex');
}

export interface IssuedChallenge {
  challengeId: string;
  codeLength: number;
  expiresAt: Date;
  resendAvailableAt: Date;
  attemptsRemaining: number;
  integrityNonce: string;
}

export class OtpService {
  constructor(
    private readonly db: Database,
    private readonly sms: SmsProvider,
    private readonly policy = DEFAULT_OTP_POLICY,
  ) {}

  async issue(params: {
    purpose: OtpPurpose;
    phone: string;
    channel?: 'sms' | 'ivr';
    courierId?: string;
    taskId?: string;
    stepKey?: string;
  }): Promise<IssuedChallenge> {
    const policy = this.policy[params.purpose];
    await this.assertSendBudget(params.phone, params.purpose, policy);

    const code = String(randomInt(0, 10 ** policy.codeLength)).padStart(policy.codeLength, '0');
    const salt = randomBytes(16).toString('hex');
    const now = new Date();
    const expiresAt = new Date(now.getTime() + policy.ttlSeconds * 1000);
    const resendAvailableAt = new Date(now.getTime() + policy.resendCooldownSeconds * 1000);
    const integrityNonce = randomBytes(32).toString('base64url');

    const [row] = await this.db
      .insert(otpChallenges)
      .values({
        purpose: params.purpose,
        channel: params.channel ?? 'sms',
        phone: params.phone,
        codeHash: hashCode(code, salt),
        salt,
        courierId: params.courierId ?? null,
        taskId: params.taskId ?? null,
        stepKey: params.stepKey ?? null,
        integrityNonce,
        maxAttempts: policy.maxAttempts,
        expiresAt,
        resendAvailableAt,
      })
      .returning({ id: otpChallenges.id });

    const body = this.renderMessage(params.purpose, code, policy.ttlSeconds);
    if (params.channel === 'ivr' && this.sms.callWithCode) {
      await this.sms.callWithCode({ to: params.phone, code, language: 'tr' });
    } else {
      await this.sms.send({ to: params.phone, body });
    }

    return {
      challengeId: row!.id,
      codeLength: policy.codeLength,
      expiresAt,
      resendAvailableAt,
      attemptsRemaining: policy.maxAttempts,
      integrityNonce,
    };
  }

  /**
   * Consumes the challenge on success so a code can never be used twice.
   * Attempts are counted even on wrong codes, which is what makes brute force
   * expensive: six digits with five attempts is a 1-in-200000 chance.
   */
  async verify(params: {
    challengeId: string;
    code: string;
  }): Promise<{ attemptsRemaining: number; courierId: string | null; taskId: string | null }> {
    const [challenge] = await this.db
      .select()
      .from(otpChallenges)
      .where(eq(otpChallenges.id, params.challengeId))
      .limit(1);

    if (!challenge) throw new AppError('OTP_INVALID');
    if (challenge.consumedAt) throw new AppError('OTP_EXPIRED');
    if (challenge.expiresAt.getTime() < Date.now()) throw new AppError('OTP_EXPIRED');
    if (challenge.attempts >= challenge.maxAttempts) {
      throw new AppError('OTP_EXPIRED', {
        message: 'Deneme hakkiniz doldu, yeni kod isteyin.',
        userVisible: true,
      });
    }

    const expected = Buffer.from(challenge.codeHash, 'hex');
    const actual = Buffer.from(hashCode(params.code, challenge.salt), 'hex');
    const matches = expected.length === actual.length && timingSafeEqual(expected, actual);

    if (!matches) {
      const [updated] = await this.db
        .update(otpChallenges)
        .set({ attempts: sql`${otpChallenges.attempts} + 1` })
        .where(eq(otpChallenges.id, challenge.id))
        .returning({ attempts: otpChallenges.attempts, maxAttempts: otpChallenges.maxAttempts });

      const remaining = (updated?.maxAttempts ?? 0) - (updated?.attempts ?? 0);
      throw new AppError('OTP_INVALID', {
        details: [{ field: 'code', issue: 'mismatch', meta: { attemptsRemaining: remaining } }],
      });
    }

    await this.db
      .update(otpChallenges)
      .set({ verifiedAt: new Date(), consumedAt: new Date() })
      .where(eq(otpChallenges.id, challenge.id));

    return {
      attemptsRemaining: challenge.maxAttempts - challenge.attempts,
      courierId: challenge.courierId,
      taskId: challenge.taskId,
    };
  }

  private async assertSendBudget(phone: string, purpose: OtpPurpose, policy: OtpPolicy) {
    const [recent] = await this.db
      .select({ count: sql<number>`count(*)::int` })
      .from(otpChallenges)
      .where(
        sql`${otpChallenges.phone} = ${phone}
            and ${otpChallenges.purpose} = ${purpose}
            and ${otpChallenges.createdAt} > now() - interval '1 hour'`,
      );

    if ((recent?.count ?? 0) >= policy.maxSendsPerHour) {
      throw new AppError('RATE_LIMITED', {
        message: 'Cok fazla kod istediniz. Bir saat sonra tekrar deneyin.',
        userVisible: true,
        retryAfter: 3600,
      });
    }

    const [live] = await this.db
      .select({ resendAvailableAt: otpChallenges.resendAvailableAt })
      .from(otpChallenges)
      .where(
        sql`${otpChallenges.phone} = ${phone}
            and ${otpChallenges.purpose} = ${purpose}
            and ${otpChallenges.consumedAt} is null
            and ${otpChallenges.expiresAt} > now()`,
      )
      .orderBy(sql`${otpChallenges.createdAt} desc`)
      .limit(1);

    if (live && live.resendAvailableAt.getTime() > Date.now()) {
      const wait = Math.ceil((live.resendAvailableAt.getTime() - Date.now()) / 1000);
      throw new AppError('RATE_LIMITED', {
        message: `Yeni kod icin ${wait} saniye bekleyin.`,
        userVisible: true,
        retryAfter: wait,
      });
    }
  }

  private renderMessage(purpose: OtpPurpose, code: string, ttlSeconds: number): string {
    const minutes = Math.round(ttlSeconds / 60);
    switch (purpose) {
      case 'task_delivery':
        return `Dijigoo teslimat dogrulama kodunuz: ${code}. Kuryeye bu kodu soyleyin. ${minutes} dakika gecerlidir.`;
      case 'phone_change':
        return `Dijigoo telefon degisiklik kodunuz: ${code}. ${minutes} dakika gecerlidir.`;
      default:
        return `Dijigoo giris kodunuz: ${code}. ${minutes} dakika gecerlidir. Kodu kimseyle paylasmayin.`;
    }
  }
}
