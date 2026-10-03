import { toSolvelineMsisdn } from './msisdn.js';

export interface SolvelineCallEnv {
  SOLVELINE_CALL_BASE_URL?: string;
  SOLVELINE_CALL_TOKEN?: string;
  SOLVELINE_CALLER_ID?: string;
  SOLVELINE_CALL_WEBHOOK_URL?: string;
  SOLVELINE_WEBHOOK_SECRET?: string;
  SOLVELINE_FIRMA_ID?: string;
  SOLVELINE_IVR_APPOINTMENT_DEST?: string;
  SOLVELINE_IVR_OTP_DEST?: string;
}

export interface OriginateCallInput {
  /** First ring. Click-to-call: courier GSM. IVR: recipient only. */
  caller1: string;
  /**
   * After the first leg answers: recipient GSM (OUTBOUND), or 993/994
   * (DYNAMIC IVR). 991/992/911 dokunulmaz.
   */
  destination: string;
  application: 'OUTBOUND' | 'DYNAMIC';
  variable: string;
  responseUrl?: string;
  callerId?: string;
}

export interface OriginateCallResult {
  uniqueId: string;
  status: string;
  caller: string | null;
  raw: unknown;
}

export interface OriginateWebhook {
  company: string | null;
  application: string | null;
  status: string | null;
  caller: string | null;
  callee: string | null;
  uniqueId: string | null;
  variable: string | null;
  callDuration: string | null;
  result: string | null;
}

export interface RecordingLookup {
  uniqueId: string;
  /** YYYY-MM-DD, Europe/Istanbul calendar day of the call. */
  startDate: string;
  endDate: string;
}

const DEFAULT_CALL_BASE = 'https://capi.ncvav.com';
const DEFAULT_CALLER_ID = '908504808538';

/** Empty IVR slots are ASCII hyphen, never U+2014. */
export const IVR_EMPTY = '-';

/**
 * JetLogi 993/994 (991/992 sablonuna karisma). Ayraç `@`.
 * 993 randevu: `{firmaId}@tr@{tarih}@{il / ilce}`
 * 994 OTP: `{firmaId}@tr@{kod}`
 * Bos slot ASCII tire; U+2014 yok.
 */
export function buildIvrVariable(input: {
  firmaId: string;
  language?: 'tr' | 'en';
  kind?: 'otp' | 'appointment';
  dateLabel?: string | null;
  placeLabel?: string | null;
  code?: string | null;
}): string {
  const lang = input.language ?? 'tr';
  const kind = input.kind ?? (nonempty(input.code) ? 'otp' : 'appointment');
  if (kind === 'otp') {
    return `${input.firmaId}@${lang}@${nonempty(input.code) ?? IVR_EMPTY}`;
  }
  const date = nonempty(input.dateLabel) ?? IVR_EMPTY;
  const place = nonempty(input.placeLabel) ?? IVR_EMPTY;
  return `${input.firmaId}@${lang}@${date}@${place}`;
}

/** DYNAMIC IVR (993/994) ses kaydi yok. OUTBOUND / AI kayit + bildirim. */
export function shouldCopyRecording(application: string | null | undefined): boolean {
  const app = (application ?? '').trim().toUpperCase();
  return app !== 'DYNAMIC';
}

function nonempty(value: string | null | undefined): string | null {
  const trimmed = value?.trim();
  if (!trimmed || trimmed === IVR_EMPTY) return null;
  return trimmed;
}

/**
 * Calendar day in Europe/Istanbul as YYYY-MM-DD. getrecording requires both
 * startdate and enddate; max range is one month. Webhook uses the call day
 * for both.
 */
export function istanbulYmd(at: Date = new Date()): string {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Istanbul',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(at);
  const year = parts.find((p) => p.type === 'year')?.value;
  const month = parts.find((p) => p.type === 'month')?.value;
  const day = parts.find((p) => p.type === 'day')?.value;
  return `${year}-${month}-${day}`;
}

export function parseOriginateResult(body: unknown): OriginateWebhook | null {
  if (body == null) return null;
  let root: unknown = body;
  if (typeof root === 'string') {
    const trimmed = root.trim();
    if (!trimmed) return null;
    try {
      root = JSON.parse(trimmed) as unknown;
    } catch {
      return null;
    }
  }
  if (typeof root !== 'object' || root === null) return null;
  const obj = root as Record<string, unknown>;
  const inner = isRecord(obj.originateresult)
    ? obj.originateresult
    : isRecord(obj.originateResult)
      ? obj.originateResult
      : obj;
  const uniqueId = stringish(inner.uniqueid ?? inner.uniqueId);
  const variable = stringish(inner.variable);
  if (!uniqueId && !variable) return null;
  return {
    company: stringish(inner.company),
    application: stringish(inner.application),
    status: stringish(inner.status),
    caller: stringish(inner.caller),
    callee: stringish(inner.callee),
    uniqueId,
    variable,
    callDuration: stringish(inner.callduration ?? inner.callDuration),
    result: stringish(inner.result),
  };
}

export function extractRecordingUrl(payload: unknown): string | null {
  if (typeof payload === 'string') {
    const trimmed = payload.trim();
    if (/^https?:\/\//i.test(trimmed)) return trimmed;
    try {
      return extractRecordingUrl(JSON.parse(trimmed) as unknown);
    } catch {
      return null;
    }
  }
  if (Array.isArray(payload)) {
    for (const item of payload) {
      const found = extractRecordingUrl(item);
      if (found) return found;
    }
    return null;
  }
  if (!isRecord(payload)) return null;
  for (const key of ['url', 'recordingurl', 'recordingUrl', 'recordingfile', 'recordingFile', 'file']) {
    const value = payload[key];
    if (typeof value === 'string' && /^https?:\/\//i.test(value.trim())) return value.trim();
  }
  if (payload.data !== undefined) {
    const nested = extractRecordingUrl(payload.data);
    if (nested) return nested;
  }
  if (payload.recordings !== undefined) {
    const nested = extractRecordingUrl(payload.recordings);
    if (nested) return nested;
  }
  return null;
}

export function createSolvelineCallClient(
  env: SolvelineCallEnv,
  log: (msg: string) => void = console.log,
  fetchImpl: typeof fetch = fetch,
): SolvelineCallClient | null {
  const token = env.SOLVELINE_CALL_TOKEN?.trim();
  if (!token) return null;
  return new SolvelineCallClient(env, token, log, fetchImpl);
}

export class SolvelineCallClient {
  constructor(
    private readonly env: SolvelineCallEnv,
    private readonly token: string,
    private readonly log: (msg: string) => void = console.log,
    private readonly fetchImpl: typeof fetch = fetch,
  ) {}

  canIvr(): boolean {
    return Boolean(this.env.SOLVELINE_FIRMA_ID?.trim());
  }

  webhookUrl(): string {
    const base = this.env.SOLVELINE_CALL_WEBHOOK_URL?.trim();
    if (!base) return '';
    const secret = this.env.SOLVELINE_WEBHOOK_SECRET?.trim();
    if (!secret) return base;
    try {
      const url = new URL(base);
      if (!url.searchParams.get('token')) url.searchParams.set('token', secret);
      return url.toString();
    } catch {
      return base;
    }
  }

  async originateClickToCall(input: {
    courierMsisdn: string;
    recipientMsisdn: string;
    variable: string;
  }): Promise<OriginateCallResult> {
    const caller1 = toSolvelineMsisdn(input.courierMsisdn);
    const destination = toSolvelineMsisdn(input.recipientMsisdn);
    if (!caller1 || !destination) {
      throw new Error('Click-to-call numaralari gecersiz.');
    }
    return this.originate({
      application: 'OUTBOUND',
      caller1,
      destination,
      variable: input.variable,
      responseUrl: this.webhookUrl(),
    });
  }

  async originateIvr(input: {
    destination: string;
    caller1: string;
    variable: string;
  }): Promise<OriginateCallResult> {
    const caller1 = toSolvelineMsisdn(input.caller1);
    if (!caller1) throw new Error('IVR alici numarasi gecersiz.');
    return this.originate({
      application: 'DYNAMIC',
      caller1,
      destination: input.destination,
      variable: input.variable,
      responseUrl: this.webhookUrl(),
    });
  }

  async originate(input: OriginateCallInput): Promise<OriginateCallResult> {
    const callerId = input.callerId ?? this.env.SOLVELINE_CALLER_ID ?? DEFAULT_CALLER_ID;
    const body: Record<string, unknown> = {
      application: input.application,
      destination: input.destination,
      callerid: callerId,
      responseurl: input.responseUrl ?? '',
      variable: input.variable,
      priority: '0',
      vmdetect: '0',
      caller: { '1': input.caller1 },
    };

    const parsed = await this.postJson('/call/call', body);
    const info = firstCallInfo(parsed);
    if (!info) {
      this.log('[call:solveline] originate: callinfo yok');
      throw new Error('Solveline originate yaniti okunamadi.');
    }
    if (info.status !== '1') {
      this.log(`[call:solveline] originate status ${info.status}`);
      throw new Error('Solveline cagri kuyruga alinamadi.');
    }
    if (!info.uniqueId) {
      throw new Error('Solveline uniqueid donmedi.');
    }
    return {
      uniqueId: info.uniqueId,
      status: info.status,
      caller: info.caller,
      raw: parsed,
    };
  }

  /**
   * Time-limited playable URL. Caller must download immediately and copy to
   * durable storage; the URL expires.
   */
  async getRecording(lookup: RecordingLookup): Promise<string | null> {
    const parsed = await this.postJson('/reports/getrecording', {
      startdate: lookup.startDate,
      enddate: lookup.endDate,
      uniqueid: lookup.uniqueId,
      recordingfile: '',
    });
    return extractRecordingUrl(parsed);
  }

  private async postJson(path: string, body: Record<string, unknown>): Promise<unknown> {
    const base = (this.env.SOLVELINE_CALL_BASE_URL ?? DEFAULT_CALL_BASE).replace(/\/$/, '');
    const res = await this.fetchImpl(`${base}${path}`, {
      method: 'POST',
      headers: {
        token: this.token,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });
    const text = await res.text();
    if (!res.ok) {
      this.log(`[call:solveline] ${path} fail ${res.status}`);
      throw new Error(`Solveline ${path} ${res.status}`);
    }
    if (!text.trim()) return {};
    try {
      return JSON.parse(text) as unknown;
    } catch {
      return text;
    }
  }
}

function firstCallInfo(payload: unknown): {
  uniqueId: string | null;
  status: string;
  caller: string | null;
} | null {
  if (!isRecord(payload)) return null;
  const list = payload.callinfo ?? payload.callInfo;
  const row = Array.isArray(list) ? list[0] : list;
  if (!isRecord(row)) return null;
  return {
    uniqueId: stringish(row.uniqueid ?? row.uniqueId),
    status: stringish(row.status) ?? '',
    caller: stringish(row.caller),
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

function stringish(value: unknown): string | null {
  if (typeof value === 'string' && value.trim()) return value.trim();
  if (typeof value === 'number') return String(value);
  return null;
}
