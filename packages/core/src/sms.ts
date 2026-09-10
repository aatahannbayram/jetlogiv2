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
 * Shared between apps/api (OTP) and apps/worker (customer notifications) so
 * both send through the same provider configuration.
 */
export interface SmsProvider {
  readonly name: string;
  send(message: SmsMessage): Promise<SmsResult>;
  /** Voice fallback for recipients who never receive the SMS. */
  callWithCode?(call: IvrCall): Promise<SmsResult>;
}

/**
 * Development provider. Logs instead of sending and always reports success,
 * so callers are testable without a signed operator contract.
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

export interface SmsProviderEnv {
  SMS_PROVIDER: 'mock' | 'netgsm' | 'verimor' | 'iletimerkezi';
}

export interface NetgsmSmsEnv {
  SMS_API_KEY?: string;
  SMS_SENDER_ID?: string;
}

/** Netgsm GET SMS. `SMS_API_KEY` = `usercode:password`. */
export class NetgsmSmsProvider implements SmsProvider {
  readonly name = 'netgsm';

  constructor(
    private readonly env: NetgsmSmsEnv,
    private readonly log: (msg: string) => void = console.log,
    private readonly fetchImpl: typeof fetch = fetch,
  ) {}

  async send(message: SmsMessage): Promise<SmsResult> {
    const key = this.env.SMS_API_KEY ?? '';
    const colon = key.indexOf(':');
    if (colon < 1) {
      throw new Error('SMS_API_KEY usercode:password biciminde olmali.');
    }
    const usercode = key.slice(0, colon);
    const password = key.slice(colon + 1);
    const gsmno = message.to.replace(/\D/g, '');
    const url = new URL('https://api.netgsm.com.tr/sms/send/get');
    url.searchParams.set('usercode', usercode);
    url.searchParams.set('password', password);
    url.searchParams.set('gsmno', gsmno);
    url.searchParams.set('message', message.body);
    url.searchParams.set('msgheader', message.sender ?? this.env.SMS_SENDER_ID ?? 'DIJIGOO');

    const res = await this.fetchImpl(url);
    const text = (await res.text()).trim();
    if (!res.ok || text.startsWith('20') || text.startsWith('30') || text.startsWith('40') || text.startsWith('50') || text.startsWith('70')) {
      this.log(`[sms:netgsm] fail ${text}`);
      throw new Error(`Netgsm SMS gonderilemedi: ${text || res.status}`);
    }
    return { providerMessageId: text || `netgsm-${Date.now()}`, acceptedAt: new Date() };
  }
}

export function createSmsProvider(
  env: SmsProviderEnv & NetgsmSmsEnv,
  log: (msg: string) => void,
): SmsProvider {
  switch (env.SMS_PROVIDER) {
    case 'mock':
      return new MockSmsProvider(log);
    case 'netgsm':
      return new NetgsmSmsProvider(env, log);
    default:
      throw new Error(
        `SMS saglayicisi "${env.SMS_PROVIDER}" henuz uygulanmadi. ` +
          'Bkz. docs/02-saglayici-degerlendirme.md',
      );
  }
}
