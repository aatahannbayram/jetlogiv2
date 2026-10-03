import type { CourierInboxItem, PushNotificationKind } from '@dijigoo/contracts';
import { insertCourierNotification, parseFcmAccount, tryDispatchInboxPush } from '@dijigoo/core';
import type { Database } from '@dijigoo/db';

import type { Env } from '../env.js';

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
  await tryDispatchInboxPush(
    db,
    parseFcmAccount(env.FCM_SERVICE_ACCOUNT_JSON, env.FCM_PROJECT_ID),
    {
      courierId: input.courierId,
      id: row.id,
      kind: input.kind,
      title: input.title,
      body: input.body,
      subjectId: input.subjectId,
      route: input.route,
      collapseKey: input.collapseKey,
    },
  );
  return toInboxItem(row);
}
