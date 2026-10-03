import assert from 'node:assert/strict';
import { test } from 'node:test';

import { IvrShipmentSummary } from '@dijigoo/contracts';
import type { tasks } from '@dijigoo/db';

import { toIvrShipmentSummary, type IvrShipmentRow } from '../src/services/ivr-shipments.js';

function row(overrides: Partial<IvrShipmentRow['task']> & { attributes?: Record<string, unknown> }): IvrShipmentRow {
  const task = {
    id: '00000000-0000-4000-a000-000000000001',
    tenantId: '00000000-0000-4000-a000-000000000002',
    reference: 'DGO-8841',
    status: 'IN_PROGRESS',
    attributes: {},
    slotEndAt: null,
    finalizedAt: null,
    ...overrides,
  } as typeof tasks.$inferSelect;
  return {
    task,
    courierName: 'Ruken Turhan',
    agencyName: 'Guney / Denizli',
    company: 'JetLogi',
  };
}

test('toIvrShipmentSummary: T02 etaConfirmed false, kurye tel yok', () => {
  const parsed = IvrShipmentSummary.parse(toIvrShipmentSummary(row({}), null));
  assert.equal(parsed.etaConfirmed, false);
  assert.equal(parsed.slotEndAt, null);
  assert.equal(parsed.deliveredAt, null);
  assert.equal(parsed.reference, 'DGO-8841');
  assert.equal(parsed.company, 'JetLogi');
  assert.equal(JSON.stringify(parsed).includes('90532'), false);
  assert.equal('courierPhone' in parsed, false);
});

test('toIvrShipmentSummary: slotEndAt görevden, COMPLETED teslim ani', () => {
  const slot = new Date('2026-09-14T15:00:00.000Z');
  const done = new Date('2026-09-14T16:00:00.000Z');
  const parsed = toIvrShipmentSummary(
    row({ status: 'COMPLETED', slotEndAt: slot, finalizedAt: done }),
    new Date('2026-09-14T08:12:00.000Z'),
  );
  assert.equal(parsed.slotEndAt, slot.toISOString());
  assert.equal(parsed.deliveredAt, done.toISOString());
  assert.equal(parsed.custodyAt, '2026-09-14T08:12:00.000Z');
  assert.equal(parsed.etaConfirmed, false);
});

test('toIvrShipmentSummary: company attributes ezer, IN_PROGRESS deliveredAt yok', () => {
  const parsed = toIvrShipmentSummary(
    row({ attributes: { company: 'Acme' }, status: 'IN_PROGRESS', finalizedAt: new Date() }),
    null,
  );
  assert.equal(parsed.company, 'Acme');
  assert.equal(parsed.deliveredAt, null);
});
