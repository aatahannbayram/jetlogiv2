import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  IvrResultRequest,
  IvrShipmentDetail,
  IvrShipmentListResponse,
  IvrShipmentSummary,
  IvrTicketCreateRequest,
} from '../src/ivr.js';

const FORBIDDEN = /iban|tckn|cvv|nationalid|msisdn|courierphone|^phone$/i;

const summaryInput = {
  reference: 'DGO-1',
  company: 'JetLogi',
  status: 'IN_PROGRESS' as const,
  custodyAt: null,
  etaConfirmed: false,
  slotEndAt: null,
  deliveredAt: null,
  courierName: 'Ruken',
  agencyName: 'Guney',
};

test('T04 T11: IVR semasinda courier.phone, IBAN, TCKN yok', () => {
  const detail = IvrShipmentDetail.parse({
    ...summaryInput,
    customerPhone: '905321110026',
  });
  for (const key of Object.keys(detail)) {
    assert.equal(FORBIDDEN.test(key), false, `yasak alan: ${key}`);
  }
  const json = JSON.stringify(detail);
  assert.equal(/iban/i.test(json), false);
  assert.equal(/tckn/i.test(json), false);
  assert.equal(/"phone"\s*:/.test(json), false);
  assert.equal('customerPhone' in detail, true);
  assert.equal('courierName' in detail, true);
  assert.equal(
    IvrShipmentDetail.safeParse({
      ...summaryInput,
      customerPhone: '905321110026',
      courierPhone: '905321110027',
    }).success,
    false,
  );
});

test('T02: fazla saat alani yok; slotEndAt pencere, etaConfirmed soz', () => {
  const parsed = IvrShipmentSummary.parse(summaryInput);
  assert.equal(parsed.etaConfirmed, false);
  assert.equal(parsed.slotEndAt, null);
  assert.equal(
    IvrShipmentSummary.safeParse({ ...summaryInput, extraPromise: 'yarin 14:00' }).success,
    false,
  );
  assert.equal(
    IvrShipmentSummary.safeParse({
      ...summaryInput,
      etaConfirmed: false,
      slotEndAt: '2026-09-14T18:00:00+03:00',
    }).success,
    true,
  );
});

test('T02 slotEndAt ve etaConfirmed birlikte gecerli', () => {
  const ok = IvrShipmentSummary.safeParse({
    ...summaryInput,
    etaConfirmed: true,
    slotEndAt: '2026-09-14T18:00:00+03:00',
  });
  assert.equal(ok.success, true);
});

test('T03: eslesmeyen telefon bos shipments, uydurma satir yok', () => {
  const parsed = IvrShipmentListResponse.parse({ shipments: [] });
  assert.equal(parsed.shipments.length, 0);
  assert.equal(
    IvrShipmentListResponse.safeParse({
      shipments: [{ reference: 'DGO-FAKE' }],
    }).success,
    false,
  );
});

test('IVR result uniqueId zorunlu; gecersiz selection yok', () => {
  const body = IvrResultRequest.parse({
    uniqueId: '111-55849811574444.1',
    selection: 'confirm',
    dtmf: '1',
  });
  assert.equal(body.selection, 'confirm');
  assert.equal(IvrResultRequest.safeParse({ uniqueId: '1', selection: 'maybe' }).success, false);
  assert.equal(IvrResultRequest.safeParse({ selection: 'confirm' }).success, false);
});

test('Ivr ticket kind support ve expedite; baska kind yok', () => {
  assert.equal(IvrTicketCreateRequest.parse({ kind: 'support' }).kind, 'support');
  assert.equal(IvrTicketCreateRequest.parse({ kind: 'expedite' }).kind, 'expedite');
  assert.equal(IvrTicketCreateRequest.safeParse({ kind: 'finance' }).success, false);
});
