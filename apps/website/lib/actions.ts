'use server';

export type InquiryKind = 'contact' | 'career' | 'partner';

export type InquiryResult =
  | { ok: true; queued: boolean }
  | { ok: false; error: string };

function str(form: FormData, key: string): string {
  const v = form.get(key);
  return typeof v === 'string' ? v.trim() : '';
}

export async function submitInquiry(
  kind: InquiryKind,
  form: FormData,
): Promise<InquiryResult> {
  const firstName = str(form, 'firstName');
  const lastName = str(form, 'lastName');
  const phone = str(form, 'phone');
  const message = str(form, 'message');
  if (!firstName || !lastName || !phone || !message) {
    return { ok: false, error: 'Ad, soyad, telefon ve mesaj zorunlu.' };
  }
  if (kind === 'career' && !str(form, 'role')) {
    return { ok: false, error: 'Pozisyon seçin.' };
  }
  if (kind === 'partner' && (!str(form, 'partnerType') || !str(form, 'city'))) {
    return { ok: false, error: 'Başvuru tipi ve şehir zorunlu.' };
  }

  const payload = {
    kind,
    firstName,
    lastName,
    phone,
    message,
    role: str(form, 'role') || undefined,
    partnerType: str(form, 'partnerType') || undefined,
    transport: str(form, 'transport') || undefined,
    city: str(form, 'city') || undefined,
    at: new Date().toISOString(),
  };

  const hook = process.env.INQUIRY_WEBHOOK_URL;
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
  if (!q) return { state: 'empty' };

  const base = process.env.TRACKING_API_URL;
  if (!base) {
    return { state: 'unconfigured', query: q };
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
