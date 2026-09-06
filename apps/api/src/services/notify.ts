import type { CourierInboxItem, PushNotificationKind } from '@dijigoo/contracts';
import { insertCourierNotification, latestPushToken } from '@dijigoo/core';
import type { Database } from '@dijigoo/db';

import type { Env } from '../env.js';
import { parseFcmAccount, sendFcm } from './fcm.js';

export function toInboxItem(row: {
  id: string;
  kind: string;
  title: string;
  body: string;
  route: string | null;
  subjectId: string | null;
  collapseKey: string | null;
  readAt: Date | null;
  createdAt: Date;
}): CourierInboxItem {
  return {
    id: row.id,
    kind: row.kind as PushNotificationKind,
    title: row.title,
    body: row.body,
    route: row.route,
    subjectId: row.subjectId,
    collapseKey: row.collapseKey,
    readAt: row.readAt?.toISOString() ?? null,
    createdAt: row.createdAt.toISOString(),
  };
}

export async function enqueueCourierNotification(
  db: Database,
  env: Env,
  input: {
    courierId: string;
    kind: PushNotificationKind;
    title: string;
    body: string;
    route?: string | null;
    subjectId?: string | null;
    collapseKey?: string | null;
  },
): Promise<CourierInboxItem> {
  const row = await insertCourierNotification(db, input);
  const account = parseFcmAccount(env.FCM_SERVICE_ACCOUNT_JSON, env.FCM_PROJECT_ID);
  if (account) {
    const token = await latestPushToken(db, input.courierId);
    if (token) {
      try {
        await sendFcm(account, {
          token,
          title: input.title,
          body: input.body,
          collapseKey: input.collapseKey,
          data: {
            id: row.id,
            kind: input.kind,
            title: input.title,
            body: input.body,
            ...(input.subjectId ? { taskId: input.subjectId } : {}),
            ...(input.route ? { route: input.route } : {}),
          },
        });
        // sentAt is best-effort; a failed push still leaves the inbox row.
      } catch {
        // Inbox is the source of truth. FCM is the wake-up.
      }
    }
  }
  return toInboxItem(row);
}
