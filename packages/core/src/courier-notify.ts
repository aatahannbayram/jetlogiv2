import type { PushNotificationKind } from '@dijigoo/contracts';
import { devices, notifications } from '@dijigoo/db';
import type { Database } from '@dijigoo/db';
import { and, desc, eq, isNull } from 'drizzle-orm';

export interface CourierNotifyInput {
  courierId: string;
  kind: PushNotificationKind;
  title: string;
  body: string;
  route?: string | null;
  subjectId?: string | null;
  collapseKey?: string | null;
}

export interface CourierNotifyRow {
  id: string;
  kind: string;
  title: string;
  body: string;
  route: string | null;
  subjectId: string | null;
  collapseKey: string | null;
  readAt: Date | null;
  createdAt: Date;
}

/**
 * Writes the courier inbox row. Same collapseKey + unread → reuse the row
 * so a burst of SLA ticks does not flood the list.
 */
export async function insertCourierNotification(
  db: Database,
  input: CourierNotifyInput,
): Promise<CourierNotifyRow> {
  if (input.collapseKey) {
    const [existing] = await db
      .select()
      .from(notifications)
      .where(
        and(
          eq(notifications.courierId, input.courierId),
          eq(notifications.collapseKey, input.collapseKey),
          isNull(notifications.readAt),
        ),
      )
      .orderBy(desc(notifications.createdAt))
      .limit(1);
    if (existing) {
      const [updated] = await db
        .update(notifications)
        .set({
          title: input.title,
          body: input.body,
          route: input.route ?? existing.route,
          subjectId: input.subjectId ?? existing.subjectId,
          kind: input.kind,
        })
        .where(eq(notifications.id, existing.id))
        .returning();
      if (updated) return toRow(updated);
    }
  }

  const [row] = await db
    .insert(notifications)
    .values({
      courierId: input.courierId,
      kind: input.kind,
      title: input.title,
      body: input.body,
      route: input.route ?? null,
      subjectId: input.subjectId ?? null,
      collapseKey: input.collapseKey ?? null,
    })
    .returning();
  if (!row) throw new Error('notifications insert returned no row');
  return toRow(row);
}

export async function latestPushToken(
  db: Database,
  courierId: string,
): Promise<string | null> {
  const [row] = await db
    .select({ pushToken: devices.pushToken })
    .from(devices)
    .where(and(eq(devices.courierId, courierId), isNull(devices.revokedAt)))
    .orderBy(desc(devices.lastSeenAt), desc(devices.boundAt))
    .limit(1);
  return row?.pushToken ?? null;
}

function toRow(row: typeof notifications.$inferSelect): CourierNotifyRow {
  return {
    id: row.id,
    kind: row.kind,
    title: row.title ?? '',
    body: row.body ?? '',
    route: row.route ?? null,
    subjectId: row.subjectId ?? null,
    collapseKey: row.collapseKey ?? null,
    readAt: row.readAt ?? null,
    createdAt: row.createdAt,
  };
}
