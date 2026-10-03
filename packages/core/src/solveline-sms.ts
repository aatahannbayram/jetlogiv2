import type { IvrCall, SmsMessage, SmsProvider, SmsResult } from './sms.js';
import {
  buildIvrVariable,
  type SolvelineCallClient,
  type SolvelineCallEnv,
} from './solveline-call.js';
import { toSolvelineMsisdn } from './msisdn.js';

export interface SolvelineSmsEnv extends SolvelineCallEnv {
  SOLVELINE_SMS_BASE_URL?: string;
  SOLVELINE_SMS_USER?: string;
  SOLVELINE_SMS_PASSWORD?: string;
  SMS_SENDER_ID?: string;
}

const DEFAULT_SMS_BASE = 'https://smslogin.nac.com.tr:9588';

/**
 * Solveline SMS `/sms/create`. Basic auth. Sender is the registered header
 * (live: JETLOGI). Secrets stay in env; this file never hard-codes them.
 */
export class SolvelineSmsProvider implements SmsProvider {
  readonly name = 'solveline';

  constructor(
    private readonly env: SolvelineSmsEnv,
    private readonly log: (msg: string) => void = console.log,
    private readonly fetchImpl: typeof fetch = fetch,
    private readonly callClient: SolvelineCallClient | null = null,
  ) {}

  async send(message: SmsMessage): Promise<SmsResult> {
    const user = this.env.SOLVELINE_SMS_USER ?? '';
    const password = this.env.SOLVELINE_SMS_PASSWORD ?? '';
    if (!user || !password) {
      throw new Error('SOLVELINE_SMS_USER / SOLVELINE_SMS_PASSWORD tanimli degil.');
    }
    const number = toSolvelineMsisdn(message.to);
    if (!number) {
      throw new Error('SMS alici numarasi gecersiz.');
    }

    const sender = message.sender ?? this.env.SMS_SENDER_ID ?? 'JETLOGI';
    const nonAscii = /[^\x00-\x7F]/.test(message.body);
    const url = `${(this.env.SOLVELINE_SMS_BASE_URL ?? DEFAULT_SMS_BASE).replace(/\/$/, '')}/sms/create`;
    const auth = Buffer.from(`${user}:${password}`).toString('base64');

    const res = await this.fetchImpl(url, {
      method: 'POST',
      headers: {
        Authorization: `Basic ${auth}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        type: 1,
        sendingType: 0,
        title: 'smsapi',
        content: message.body,
        number,
        encoding: nonAscii ? 1 : 0,
        sender,
      }),
    });

    const text = await res.text();
    if (!res.ok) {
      this.log(`[sms:solveline] fail ${res.status}`);
      throw new Error(`Solveline SMS gonderilemedi: ${res.status}`);
    }

    let providerMessageId = `solveline-${Date.now()}`;
    try {
      const parsed = JSON.parse(text) as Record<string, unknown>;
      if (parsed.error || parsed.success === false || parsed.status === false) {
        this.log('[sms:solveline] fail body');
        throw new Error('Solveline SMS gonderilemedi.');
      }
      const id =
        parsed.pkgID ?? parsed.pkgId ?? parsed.id ?? (parsed.data as Record<string, unknown> | undefined)?.pkgID;
      if (id != null) providerMessageId = String(id);
    } catch (err) {
      if (err instanceof Error && err.message === 'Solveline SMS gonderilemedi.') throw err;
    }

    return { providerMessageId, acceptedAt: new Date() };
  }

  async callWithCode(call: IvrCall): Promise<SmsResult> {
    if (!this.callClient?.canIvr()) {
      throw new Error('Solveline IVR kapali: SOLVELINE_FIRMA_ID yok.');
    }
    const to = toSolvelineMsisdn(call.to);
    if (!to) throw new Error('IVR alici numarasi gecersiz.');

    const kind = call.kind ?? 'otp';
    const destination =
      kind === 'appointment'
        ? this.env.SOLVELINE_IVR_APPOINTMENT_DEST ?? '993'
        : this.env.SOLVELINE_IVR_OTP_DEST ?? '994';
    const variable = buildIvrVariable({
      firmaId: this.env.SOLVELINE_FIRMA_ID!,
      language: call.language,
      kind,
      dateLabel: kind === 'appointment' ? call.dateLabel : undefined,
      placeLabel: kind === 'appointment' ? call.placeLabel : undefined,
      code: kind === 'otp' ? call.code : undefined,
    });

    const originated = await this.callClient.originateIvr({
      destination,
      caller1: to,
      variable,
    });

    return { providerMessageId: originated.uniqueId, acceptedAt: new Date() };
  }
}
