import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  fallbackAvailability,
  hoursFromWeekly,
  mapPanelAvailability,
  mapPanelDocuments,
  pullPanelJson,
} from '../src/identity-map.js';

test('panel alan adlarini sozlesmeye cevirir', () => {
  const mapped = mapPanelAvailability({
    status: 'AVAILABLE',
    vehicleType: 'CAR',
    employmentType: 'PART_TIME',
    city: 'Denizli',
    district: 'Güney',
    weeklyHours: [
      { day: 1, from: '09:00', to: '18:00' },
      { day: 5, from: '09:00', to: '18:00' },
    ],
    updatedAt: '2026-08-25T09:00:00.000Z',
  });
  assert.equal(mapped.city, 'Denizli');
  assert.equal(mapped.district, 'Güney');
  assert.equal(mapped.vehicle, 'CAR');
  assert.equal(mapped.weekly.length, 2);
  assert.equal(mapped.weekly[0]?.weekday, 1);
});

test('bozuk govde yedek Guney kaydina duser', () => {
  const mapped = mapPanelAvailability(null);
  assert.deepEqual(mapped.city, fallbackAvailability().city);
  assert.equal(mapped.employmentType, 'PART_TIME');
});

test('belge listesi APPROVED -> COMPLETED', () => {
  const docs = mapPanelDocuments({
    documents: [{ id: '00000000-0000-4000-a000-000000000201', documentType: 'EHLIYET', reviewStatus: 'APPROVED', name: 'B sınıfı' }],
  });
  assert.equal(docs.items[0]?.type, 'DRIVING_LICENSE');
  assert.equal(docs.items[0]?.status, 'COMPLETED');
  assert.equal(docs.completedCount, 1);
});

test('haftalik saat ozeti', () => {
  const hours = hoursFromWeekly(fallbackAvailability().weekly);
  assert.match(hours, /Pzt/);
  assert.match(hours, /09:00/);
});

test('panel cekimi cookie gondermez', async () => {
  const seen: { url: string; headers: Record<string, string> }[] = [];
  await pullPanelJson({
    origin: 'https://kurye.dijigoo.com',
    path: '/api/public/v1/courier-availability',
    courierId: '00000000-0000-4000-a000-000000000026',
    token: 'internal-token-value',
    fetchImpl: async (input, init) => {
      seen.push({
        url: String(input),
        headers: { ...(init?.headers as Record<string, string>) },
      });
      return new Response(JSON.stringify({ city: 'Denizli' }), { status: 200 });
    },
  });
  assert.equal(seen.length, 1);
  assert.equal(seen[0]?.headers['cookie'], undefined);
  assert.equal(seen[0]?.headers['authorization'], 'Bearer internal-token-value');
  assert.equal(seen[0]?.headers['x-courier-id'], '00000000-0000-4000-a000-000000000026');
});
