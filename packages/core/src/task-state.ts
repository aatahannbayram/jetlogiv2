import { ALLOWED_TASK_TRANSITIONS, type TaskStatus } from '@dijigoo/contracts';

import { AppError } from './errors.js';

export function canTransition(from: TaskStatus, to: TaskStatus): boolean {
  return ALLOWED_TASK_TRANSITIONS[from].includes(to);
}

export function assertTransition(from: TaskStatus, to: TaskStatus): void {
  if (from === to) return;

  if (from === 'COMPLETED' || from === 'FAILED' || from === 'CANCELLED') {
    throw new AppError('TASK_ALREADY_FINALIZED', {
      details: [{ field: 'status', issue: `already_${from.toLowerCase()}` }],
    });
  }

  if (!canTransition(from, to)) {
    throw new AppError('BUSINESS_RULE_VIOLATION', {
      message: `Gorev ${from} durumundan ${to} durumuna gecemez.`,
      details: [{ field: 'to', issue: 'invalid_transition', meta: { from, to } }],
    });
  }
}

/**
 * Optimistic concurrency. The panel can reassign or cancel a task while the
 * courier is mid-wizard; letting a stale write land would silently undo it.
 */
export function assertRowVersion(current: number, provided: number): void {
  if (current !== provided) {
    throw new AppError('VERSION_MISMATCH', {
      details: [{ field: 'rowVersion', issue: 'stale', meta: { current, provided } }],
    });
  }
}

/**
 * Device clocks drift and couriers change them. We keep the device timestamp
 * for the audit trail but clamp it into a sane window around server time so
 * a wrong clock cannot reorder the event stream.
 */
export function clampOccurredAt(occurredAt: Date, serverNow: Date, maxSkewMinutes = 60): Date {
  const skewMs = maxSkewMinutes * 60_000;
  const delta = occurredAt.getTime() - serverNow.getTime();

  if (delta > skewMs) return serverNow;
  if (delta < -skewMs) return new Date(serverNow.getTime() - skewMs);
  return occurredAt;
}
