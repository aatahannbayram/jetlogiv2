import type { Env } from '../env.js';

export interface SmsMessage {
  to: string;
  body: string;
  /** Turkish operators require a registered alphanumeric header. */
  sender?: string;
}

export interface SmsResult {
  providerMessageId: string;
  acceptedAt: Date;
}

export interface IvrCall {
  to: string;
  /** Digits are read one by one, with a pause between each. */
  code: string;
  language: 'tr' | 'en';
}

/**
 * Provider boundary. Concrete Turkish operators (Netgsm, Verimor,
 * Iletimerkezi) are evaluated in docs/02-saglayici-degerlendirme.md; the
 * point of this interface is that swapping one for another touches one file.
 */
export interface SmsProvider {
  readonly name: string;
  send(message: SmsMessage): Promise<SmsResult>;
  /** Voice fallback for recipients who never receive the SMS. */
  callWithCode?(call: IvrCall): Promise<SmsResult>;
}

/**
 * Development provider. Logs instead of sending and always reports success,
 * so the activation flow is testable without a signed operator contract.
 */
export class MockSmsProvider implements SmsProvider {
  readonly name = 'mock';
  readonly sent: SmsMessage[] = [];

  constructor(private readonly log: (msg: string) => void = console.log) {}

  async send(message: SmsMessage): Promise<SmsResult> {
    this.sent.push(message);
    this.log(`[sms:mock] ${message.to} <- ${message.body}`);
    return { providerMessageId: `mock-${this.sent.length}`, acceptedAt: new Date() };
  }

  async callWithCode(call: IvrCall): Promise<SmsResult> {
    this.log(`[ivr:mock] ${call.to} <- ${call.code.split('').join(' ')}`);
    return { providerMessageId: `mock-ivr-${Date.now()}`, acceptedAt: new Date() };
  }
}

export function createSmsProvider(env: Env, log: (msg: string) => void): SmsProvider {
  switch (env.SMS_PROVIDER) {
    case 'mock':
      return new MockSmsProvider(log);
    default:
      // Real adapters land once the operator contract is signed; failing loudly
      // is better than silently falling back to mock in production.
      throw new Error(
        `SMS saglayicisi "${env.SMS_PROVIDER}" henuz uygulanmadi. ` +
          'Bkz. docs/02-saglayici-degerlendirme.md',
      );
  }
}
