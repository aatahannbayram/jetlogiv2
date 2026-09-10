'use server';

import {
  type InquiryKind,
  INQUIRY_LIMITS,
  isSafeOutboundUrl,
  readInquiry,
  validateInquiry,
  validateTrackQuery,
} from './inquiry';

export type { InquiryKind };

export type InquiryResult =
  | { ok: true; queued: boolean }
  | { ok: false; error: string };

export async function submitInquiry(
  kind: InquiryKind,
  form: FormData,
): Promise<InquiryResult> {
  const fields = readInquiry(form);
  const error = validateInquiry(kind, fields);
  if (error) return { ok: false, error };

  const payload = {
    kind,
    firstName: fields.firstName,
    lastName: fields.lastName,
    phone: fields.phone,
    message: fields.message,
    role: fields.role || undefined,
    partnerType: fields.partnerType || undefined,
    transport: fields.transport || undefined,
    city: fields.city || undefined,
    at: new Date().toISOString(),
  };

  const hook = process.env.INQUIRY_WEBHOOK_URL;
  if (hook && !isSafeOutboundUrl(hook)) {
    return { ok: false, error: 'Gönderilemedi, biraz sonra yeniden deneyin.' };
  }
  if (hook) {
    const res = await fetch(hook, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(payload),
    });
    if (!res.ok) {
      return { ok: false, error: 'Gönderilemedi, biraz sonra yeniden deneyin.' };
    }
    return { ok: true, queued: true };
  }

  return { ok: true, queued: false };
}

export type TrackLookup =
  | { state: 'empty' }
  | { state: 'unconfigured'; query: string }
  | { state: 'error'; query: string; message: string }
  | { state: 'ok'; query: string; headline: string; detail: string };

export async function lookupShipment(query: string): Promise<TrackLookup> {
  const q = query.trim();
  const invalid = validateTrackQuery(q);
  if (invalid === 'empty') return { state: 'empty' };
  if (invalid) {
    return { state: 'error', query: q.slice(0, INQUIRY_LIMITS.query), message: invalid };
  }

  const base = process.env.TRACKING_API_URL;
  if (!base) {
    return { state: 'unconfigured', query: q };
  }
  if (!isSafeOutboundUrl(base)) {
    return { state: 'error', query: q, message: 'Takip servisi yanıt vermedi.' };
  }

  try {
    const url = new URL(base);
    url.searchParams.set('q', q);
    const res = await fetch(url, { cache: 'no-store' });
    if (!res.ok) {
      return {
        state: 'error',
        query: q,
        message: 'Takip servisi yanıt vermedi.',
      };
    }
    const data = (await res.json()) as {
      headline?: string;
      detail?: string;
    };
    return {
      state: 'ok',
      query: q,
      headline: data.headline ?? 'Kayıt bulundu',
      detail: data.detail ?? '',
    };
  } catch {
    return { state: 'error', query: q, message: 'Takip servisine ulaşılamadı.' };
  }
}
