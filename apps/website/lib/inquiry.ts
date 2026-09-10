export type InquiryKind = 'contact' | 'career' | 'partner';

export const INQUIRY_LIMITS = {
  firstName: 80,
  lastName: 80,
  phone: 32,
  message: 2000,
  role: 80,
  partnerType: 80,
  transport: 80,
  city: 80,
  query: 64,
} as const;

export type InquiryFields = {
  firstName: string;
  lastName: string;
  phone: string;
  message: string;
  role: string;
  partnerType: string;
  transport: string;
  city: string;
};

export function str(form: FormData, key: string): string {
  const v = form.get(key);
  return typeof v === 'string' ? v.trim() : '';
}

export function readInquiry(form: FormData): InquiryFields {
  return {
    firstName: str(form, 'firstName'),
    lastName: str(form, 'lastName'),
    phone: str(form, 'phone'),
    message: str(form, 'message'),
    role: str(form, 'role'),
    partnerType: str(form, 'partnerType'),
    transport: str(form, 'transport'),
    city: str(form, 'city'),
  };
}

export function validateInquiry(
  kind: InquiryKind,
  fields: InquiryFields,
): string | null {
  if (!fields.firstName || !fields.lastName || !fields.phone || !fields.message) {
    return 'Ad, soyad, telefon ve mesaj zorunlu.';
  }
  if (kind === 'career' && !fields.role) return 'Pozisyon seçin.';
  if (kind === 'partner' && (!fields.partnerType || !fields.city)) {
    return 'Başvuru tipi ve şehir zorunlu.';
  }
  if (fields.firstName.length > INQUIRY_LIMITS.firstName) return 'Ad çok uzun.';
  if (fields.lastName.length > INQUIRY_LIMITS.lastName) return 'Soyad çok uzun.';
  if (fields.phone.length > INQUIRY_LIMITS.phone) return 'Telefon çok uzun.';
  if (fields.message.length > INQUIRY_LIMITS.message) return 'Mesaj çok uzun.';
  if (fields.role.length > INQUIRY_LIMITS.role) return 'Pozisyon çok uzun.';
  if (fields.city.length > INQUIRY_LIMITS.city) return 'Şehir çok uzun.';
  return null;
}

export function validateTrackQuery(query: string): string | null {
  const q = query.trim();
  if (!q) return 'empty';
  if (q.length > INQUIRY_LIMITS.query) return 'Sorgu çok uzun.';
  return null;
}

/** SSRF: yalnız genel HTTPS uçları. localhost / RFC1918 / link-local yok. */
export function isSafeOutboundUrl(raw: string): boolean {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    return false;
  }
  if (url.protocol !== 'https:') return false;
  const host = url.hostname.toLowerCase().replace(/^\[|\]$/g, '');
  if (host === 'localhost' || host.endsWith('.localhost') || host === '::1') {
    return false;
  }
  const ipv4 = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/.exec(host);
  if (ipv4) {
    const a = Number(ipv4[1]);
    const b = Number(ipv4[2]);
    if (a === 0 || a === 10 || a === 127) return false;
    if (a === 169 && b === 254) return false;
    if (a === 192 && b === 168) return false;
    if (a === 172 && b >= 16 && b <= 31) return false;
  }
  if (host.includes(':')) return false;
  return true;
}
