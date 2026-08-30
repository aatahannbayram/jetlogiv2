import {
  CourierAvailability,
  CourierDocumentList,
  type CourierAvailability as Availability,
  type CourierDocumentList as DocumentList,
} from '@dijigoo/contracts';

const WEEKDAYS = ['', 'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'] as const;

function asRecord(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  return value as Record<string, unknown>;
}

function pickString(obj: Record<string, unknown>, keys: string[]): string | undefined {
  for (const key of keys) {
    const value = obj[key];
    if (typeof value === 'string' && value.trim()) return value.trim();
  }
  return undefined;
}

function pickEnum<T extends string>(value: unknown, allowed: readonly T[], fallback: T): T {
  if (typeof value === 'string' && (allowed as readonly string[]).includes(value)) {
    return value as T;
  }
  return fallback;
}

function toWeekday(value: unknown): number | null {
  if (typeof value === 'number' && value >= 1 && value <= 7) return value;
  if (typeof value === 'string') {
    const n = Number(value);
    if (n >= 1 && n <= 7) return n;
    const map: Record<string, number> = {
      monday: 1,
      pazartesi: 1,
      tuesday: 2,
      sali: 2,
      wednesday: 3,
      carsamba: 3,
      thursday: 4,
      persembe: 4,
      friday: 5,
      cuma: 5,
      saturday: 6,
      cumartesi: 6,
      sunday: 7,
      pazar: 7,
    };
    return map[value.toLowerCase()] ?? null;
  }
  return null;
}

function mapWindows(raw: unknown): Availability['weekly'] {
  if (!Array.isArray(raw)) return fallbackAvailability().weekly;
  const out: Availability['weekly'] = [];
  for (const item of raw) {
    const row = asRecord(item);
    if (!row) continue;
    const weekday = toWeekday(row['weekday'] ?? row['day'] ?? row['dayOfWeek'] ?? row['isoWeekday']);
    const start = pickString(row, ['start', 'from', 'begin', 'opensAt']) ?? '09:00';
    const end = pickString(row, ['end', 'to', 'until', 'closesAt']) ?? '18:00';
    if (!weekday) continue;
    if (!/^\d{2}:\d{2}$/.test(start) || !/^\d{2}:\d{2}$/.test(end)) continue;
    out.push({ weekday, start, end });
  }
  return out.length > 0 ? out : fallbackAvailability().weekly;
}

export function fallbackAvailability(now = new Date()): Availability {
  return CourierAvailability.parse({
    status: 'AVAILABLE',
    vehicle: 'CAR',
    employmentType: 'PART_TIME',
    city: 'Denizli',
    district: 'Güney',
    weekly: [1, 2, 3, 4, 5].map((weekday) => ({ weekday, start: '09:00', end: '18:00' })),
    updatedAt: now.toISOString(),
  });
}

export function fallbackDocuments(): DocumentList {
  return CourierDocumentList.parse({
    items: [
      {
        id: '00000000-0000-4000-a000-000000000101',
        type: 'IDENTITY',
        label: 'Kimlik',
        status: 'COMPLETED',
        expiresAt: null,
      },
      {
        id: '00000000-0000-4000-a000-000000000102',
        type: 'DRIVING_LICENSE',
        label: 'Ehliyet',
        status: 'COMPLETED',
        expiresAt: null,
      },
    ],
    completedCount: 2,
    requiredCount: 2,
  });
}

/**
 * Panel JSON → mobil sözleşme. Alan adları canlı Next.js yanıtına göre esnek;
 * cookie header'ı burada yok ve olmamalı.
 */
export function mapPanelAvailability(raw: unknown): Availability {
  const root = asRecord(raw);
  const inner = asRecord(root?.['availability'] ?? root?.['data'] ?? raw) ?? {};
  const weekly = mapWindows(inner['weekly'] ?? inner['windows'] ?? inner['weeklyHours'] ?? inner['days']);
  const candidate = {
    status: pickEnum(
      inner['status'] ?? inner['availabilityStatus'] ?? inner['availability'],
      ['AVAILABLE', 'UNAVAILABLE', 'ON_SHIFT', 'ON_BREAK'] as const,
      'AVAILABLE',
    ),
    vehicle: pickEnum(
      inner['vehicle'] ?? inner['vehicleType'] ?? inner['workVehicle'],
      ['CAR', 'MOTORCYCLE', 'BICYCLE', 'ON_FOOT', 'VAN'] as const,
      'CAR',
    ),
    employmentType: pickEnum(
      inner['employmentType'] ?? inner['employment'] ?? inner['workType'],
      ['FULL_TIME', 'PART_TIME', 'SEASONAL'] as const,
      'PART_TIME',
    ),
    city: pickString(inner, ['city', 'il']) ?? 'Denizli',
    district: pickString(inner, ['district', 'ilce', 'town']) ?? 'Güney',
    weekly,
    updatedAt: pickString(inner, ['updatedAt', 'updated_at']) ?? new Date().toISOString(),
  };
  const parsed = CourierAvailability.safeParse(candidate);
  return parsed.success ? parsed.data : fallbackAvailability();
}

export function mapPanelDocuments(raw: unknown): DocumentList {
  const root = asRecord(raw);
  const list = root?.['items'] ?? root?.['documents'] ?? root?.['data'];
  if (!Array.isArray(list)) return fallbackDocuments();

  const typeMap: Record<string, DocumentList['items'][number]['type']> = {
    IDENTITY: 'IDENTITY',
    ID: 'IDENTITY',
    KIMLIK: 'IDENTITY',
    DRIVING_LICENSE: 'DRIVING_LICENSE',
    EHLIYET: 'DRIVING_LICENSE',
    SRC: 'SRC',
    CRIMINAL_RECORD: 'CRIMINAL_RECORD',
    RESIDENCE: 'RESIDENCE',
    IBAN: 'IBAN',
    CONTRACT: 'CONTRACT',
    OTHER: 'OTHER',
  };

  const statusMap: Record<string, DocumentList['items'][number]['status']> = {
    MISSING: 'MISSING',
    PENDING: 'PENDING',
    COMPLETED: 'COMPLETED',
    APPROVED: 'COMPLETED',
    REJECTED: 'REJECTED',
    EXPIRED: 'EXPIRED',
  };

  const items = list.flatMap((entry, index) => {
    const row = asRecord(entry);
    if (!row) return [];
    const typeKey = String(row['type'] ?? row['documentType'] ?? 'OTHER').toUpperCase();
    const statusKey = String(row['status'] ?? row['reviewStatus'] ?? 'PENDING').toUpperCase();
    const id = typeof row['id'] === 'string' && row['id'].length === 36
      ? row['id']
      : `00000000-0000-4000-a000-${String(index + 1).padStart(12, '0')}`;
    return [
      {
        id,
        type: typeMap[typeKey] ?? 'OTHER',
        label: pickString(row, ['label', 'name', 'title']) ?? typeKey,
        status: statusMap[statusKey] ?? 'PENDING',
        expiresAt: typeof row['expiresAt'] === 'string' ? row['expiresAt'] : null,
      },
    ];
  });

  const parsed = CourierDocumentList.safeParse({
    items,
    completedCount: items.filter((i) => i.status === 'COMPLETED').length,
    requiredCount: items.length,
  });
  return parsed.success ? parsed.data : fallbackDocuments();
}

export function hoursFromWeekly(weekly: Availability['weekly']): string {
  if (weekly.length === 0) return '—';
  const first = weekly[0]!;
  const sameHours = weekly.every((w) => w.start === first.start && w.end === first.end);
  const labels = weekly.map((w) => WEEKDAYS[w.weekday] ?? '');
  if (sameHours && weekly.length >= 5) {
    return `${labels[0]}–${labels[labels.length - 1]} ${first.start}–${first.end}`;
  }
  return weekly.map((w) => `${WEEKDAYS[w.weekday]} ${w.start}–${w.end}`).join(' · ');
}

/**
 * Server-to-server pull. Courier cookie is never sent — the phone JWT is
 * translated to an internal header the panel can honour later.
 */
export async function pullPanelJson(params: {
  origin: string;
  path: string;
  courierId?: string;
  token?: string;
  fetchImpl?: typeof fetch;
}): Promise<unknown | null> {
  const url = `${params.origin.replace(/\/$/, '')}${params.path}`;
  const headers: Record<string, string> = { accept: 'application/json' };
  if (params.token) headers['authorization'] = `Bearer ${params.token}`;
  if (params.courierId) headers['x-courier-id'] = params.courierId;
  try {
    const res = await (params.fetchImpl ?? fetch)(url, { headers });
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null;
  }
}
