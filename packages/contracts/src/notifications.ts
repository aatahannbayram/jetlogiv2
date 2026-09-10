import { Timestamp, Uuid, z } from './common.js';
import { PushNotificationKind } from './events.js';

export const CourierInboxItem = z
  .object({
    id: Uuid,
    kind: PushNotificationKind,
    title: z.string().max(120),
    body: z.string().max(300),
    route: z.string().max(200).nullish(),
    subjectId: Uuid.nullish(),
    collapseKey: z.string().max(60).nullish(),
    readAt: Timestamp.nullish(),
    createdAt: Timestamp,
  })
  .openapi('CourierInboxItem');
export type CourierInboxItem = z.infer<typeof CourierInboxItem>;

export const NotificationListResponse = z
  .object({
    items: z.array(CourierInboxItem),
    nextCursor: z.string().nullable(),
  })
  .openapi('NotificationListResponse');
export type NotificationListResponse = z.infer<typeof NotificationListResponse>;

export const NotificationReadRequest = z
  .object({
    ids: z.array(Uuid).min(1).max(100).optional(),
    all: z.boolean().optional(),
  })
  .refine((v) => Boolean(v.all) || (v.ids?.length ?? 0) > 0, {
    message: 'ids veya all zorunlu',
  })
  .openapi('NotificationReadRequest');
export type NotificationReadRequest = z.infer<typeof NotificationReadRequest>;

export const NotificationDispatchRequest = z
  .object({
    courierId: Uuid,
    kind: PushNotificationKind,
    title: z.string().max(120),
    body: z.string().max(300),
    route: z.string().max(200).nullish(),
    subjectId: Uuid.nullish(),
    collapseKey: z.string().max(60).nullish(),
  })
  .openapi('NotificationDispatchRequest');
export type NotificationDispatchRequest = z.infer<typeof NotificationDispatchRequest>;
