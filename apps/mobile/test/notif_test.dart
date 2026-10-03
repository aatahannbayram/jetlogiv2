import 'package:dijigoo_kurye/alerts.dart';
import 'package:dijigoo_kurye/api/client.dart';
import 'package:dijigoo_kurye/locate.dart';
import 'package:dijigoo_kurye/models.dart';
import 'package:dijigoo_kurye/notif.dart';
import 'package:dijigoo_kurye/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  final noon = DateTime(2026, 9, 7, 12);

  test('sunucu push turu kutuya map edilir', () {
    expect(notifKindFromPush('TASK_CANCELLED'), NotifKind.stopCancelled);
    expect(notifKindFromPush('SLA_AT_RISK'), NotifKind.slaRisk);
    expect(notifKindFromPush('TASK_UPDATED'), NotifKind.stopAssigned);
    expect(notifKindFromPush('CUSTODY_TAKEN'), NotifKind.custody);
    expect(notifIsAlert(NotifKind.slaRisk), isTrue);
    final n = appNotificationFromInbox({
      'id': '11111111-1111-4111-8111-111111111111',
      'kind': 'TASK_ASSIGNED',
      'title': 'Yeni durak atandı',
      'body': 'DGO-1',
      'subjectId': '22222222-2222-4222-8222-222222222222',
      'createdAt': '2026-09-07T09:00:00.000Z',
    });
    expect(n.kind, NotifKind.stopAssigned);
    expect(n.taskId, '22222222-2222-4222-8222-222222222222');
  });

  test('ön plan push kutuya düşer, SYNC_HINT düşmez', () {
    final s = SessionController();
    s.ingestPushData({
      'id': '44444444-4444-4444-8444-444444444444',
      'kind': 'SLA_AT_RISK',
      'title': 'SLA riskte',
      'body': 'DGO-1',
      'taskId': '55555555-5555-4555-8555-555555555555',
    });
    expect(s.notifications.any((n) => n.id.startsWith('demo-')), isFalse);
    expect(s.notifications.first.kind, NotifKind.slaRisk);
    expect(s.notifications.first.taskId, '55555555-5555-4555-8555-555555555555');
    final before = s.notifications.length;
    s.ingestPushData({'kind': 'SYNC_HINT'});
    expect(s.notifications.length, before);
  });

  test('canlı kutu demo tohumunu düşürür', () {
    final s = SessionController();
    expect(s.notifications.any((n) => n.id.startsWith('demo-')), isTrue);
    s.ingestServerNotifications([
      InboxItemDto(
        item: appNotificationFromInbox({
          'id': '33333333-3333-4333-8333-333333333333',
          'kind': 'TASK_CANCELLED',
          'title': 'Durak iptal',
          'body': 'DGO-2',
          'createdAt': '2026-09-07T10:00:00.000Z',
        }),
        read: false,
      ),
    ]);
    expect(s.notifications.any((n) => n.id.startsWith('demo-')), isFalse);
    expect(s.notifications.first.title, 'Durak iptal');
  });

  test('bildirim izin durumu ayrılır', () {
    expect(pushPermitFromStatus(PermissionStatus.granted), PushPermit.granted);
    expect(pushPermitFromStatus(PermissionStatus.limited), PushPermit.granted);
    expect(pushPermitFromStatus(PermissionStatus.denied), PushPermit.denied);
    expect(
      pushPermitFromStatus(PermissionStatus.permanentlyDenied),
      PushPermit.blocked,
    );
    expect(
      pushPermitFromStatus(PermissionStatus.restricted),
      PushPermit.blocked,
    );
  });

  test('vardiya hatırlatması bugün 08:50 geçtiyse yarına kayar', () {
    expect(
      nextShiftReminderAt(DateTime(2026, 9, 7, 7, 0)),
      DateTime(2026, 9, 7, 8, 50),
    );
    expect(
      nextShiftReminderAt(DateTime(2026, 9, 7, 9, 0)),
      DateTime(2026, 9, 8, 8, 50),
    );
  });

  test('izin yoksa bildirim anahtarı açık kalmaz', () async {
    final s = SessionController(
      requestPush: () async => PushPermit.denied,
    );
    s.notifyEnabled = false;
    final permit = await s.toggleNotifyPref();
    expect(permit, PushPermit.denied);
    expect(s.notifyEnabled, isFalse);
    expect(s.notifyOsBlocked, isFalse);
  });

  test('kalıcı izin reddinde ayar gerekir', () async {
    final s = SessionController(
      requestPush: () async => PushPermit.blocked,
    );
    s.notifyEnabled = false;
    final permit = await s.toggleNotifyPref();
    expect(permit, PushPermit.blocked);
    expect(s.notifyEnabled, isFalse);
    expect(s.notifyOsBlocked, isTrue);
  });

  test('OS izni geri gelince blok kalkar', () async {
    var permit = PushPermit.denied;
    final s = SessionController(readPush: () async => permit);
    s.notifyEnabled = true;
    await s.reconcilePushPermit();
    expect(s.notifyOsBlocked, isTrue);
    expect(s.notifyEnabled, isTrue);
    permit = PushPermit.granted;
    await s.reconcilePushPermit();
    expect(s.notifyOsBlocked, isFalse);
  });

  test('tepsi id rezerve kanallarla çakışmaz', () {
    expect(FieldAlerts.inboxNotifyId('demo-stop'), isNot(FieldAlerts.badgeSyncId));
    expect(
      FieldAlerts.inboxNotifyId('demo-stop'),
      isNot(FieldAlerts.shiftReminderId),
    );
    expect(
      FieldAlerts.inboxNotifyId(FieldAlerts.shiftPayload),
      isNot(FieldAlerts.shiftReminderId),
    );
  });

  test('okundu geri alınır', () {
    final s = SessionController();
    final id = s.notifications.first.id;
    s.markNotificationRead(id);
    expect(s.isNotifRead(id), isTrue);
    final unread = s.unreadNotifCount;
    s.markNotificationUnread(id);
    expect(s.isNotifRead(id), isFalse);
    expect(s.unreadNotifCount, unread + 1);
    s.dismissNotification(id);
    s.markNotificationUnread(id);
    expect(s.isNotifRead(id), isTrue);
  });

  test('bildirim id ile bulunur', () {
    final s = SessionController();
    final first = s.notifications.first;
    expect(s.notificationById(first.id)?.title, first.title);
    expect(s.notificationById('yok'), isNull);
    s.dismissNotification(first.id);
    expect(s.notificationById(first.id), isNull);
  });

  test('saat etiketi bugün / dün / eski ayrılır', () {
    expect(
      formatNotifTime(
        DateTime(2026, 9, 7, 9, 5),
        noon,
        yesterdayLabel: 'Dün',
      ),
      '09:05',
    );
    expect(
      formatNotifTime(
        DateTime(2026, 9, 6, 18, 0),
        noon,
        yesterdayLabel: 'Dün',
      ),
      'Dün',
    );
    expect(
      formatNotifTime(
        DateTime(2026, 9, 4, 10, 0),
        noon,
        yesterdayLabel: 'Dün',
      ),
      '4.09',
    );
  });

  test('filtre okunmamış ve uyarıları ayırır', () {
    final a = AppNotification(
      id: 'a',
      kind: NotifKind.stopAssigned,
      title: 'Yeni durak atandı',
      body: 'x',
      createdAt: DateTime(2026, 9, 7, 10),
      icon: LucideIcons.truck,
      tint: Color(0x00000000),
      ink: Color(0x00000000),
    );
    final b = AppNotification(
      id: 'b',
      kind: NotifKind.syncFail,
      title: 'Gönderim başarısız',
      body: 'y',
      createdAt: DateTime(2026, 9, 7, 11),
      icon: LucideIcons.circleAlert,
      tint: Color(0x00000000),
      ink: Color(0x00000000),
    );
    final items = [a, b];
    expect(
      filterNotifications(
        items: items,
        filter: NotifFilter.unread,
        isRead: (id) => id == 'a',
      ).map((n) => n.id),
      ['b'],
    );
    expect(
      filterNotifications(
        items: items,
        filter: NotifFilter.alerts,
        isRead: (_) => false,
      ).map((n) => n.id),
      ['b'],
    );
  });

  test('okundu id ile tutulur, yeni eklenince kaymaz', () {
    final s = SessionController();
    final firstId = s.notifications.first.id;
    s.markNotificationRead(firstId);
    expect(s.isNotifRead(firstId), isTrue);
    final unreadBefore = s.unreadNotifCount;
    s.applyTaskDelta(
      changed: [
        DeliveryTask(
          id: 't-new',
          ref: 'DGO-9001',
          recipient: 'Yeni Kişi',
          address: 'x',
          window: '—',
          kind: TaskKind.delivery,
          status: TaskStatus.assigned,
        ),
      ],
      removedIds: const [],
    );
    expect(s.notifications.first.title, 'Yeni durak atandı');
    expect(s.notifications.first.taskId, 't-new');
    expect(s.isNotifRead(firstId), isTrue);
    expect(s.isNotifRead(s.notifications.first.id), isFalse);
    expect(s.unreadNotifCount, unreadBefore + 1);
  });

  test('gizlenen bildirim listeden düşer, geri alınır', () {
    final s = SessionController();
    final id = s.notifications.first.id;
    final before = s.visibleNotifications.length;
    s.dismissNotification(id);
    expect(s.visibleNotifications.any((n) => n.id == id), isFalse);
    expect(s.visibleNotifications.length, before - 1);
    expect(s.isNotifRead(id), isTrue);
    s.restoreNotification(id);
    expect(s.visibleNotifications.first.id, id);
  });

  test('bildirim kutusu 40 ile sınırlı', () {
    final s = SessionController();
    for (var i = 0; i < 45; i++) {
      s.applyTaskDelta(
        changed: [
          DeliveryTask(
            id: 'cap-$i',
            ref: 'DGO-C$i',
            recipient: 'Kişi $i',
            address: 'x',
            window: '—',
            kind: TaskKind.delivery,
            status: TaskStatus.assigned,
          ),
        ],
        removedIds: const [],
      );
    }
    expect(s.notifications.length, 40);
    expect(s.notifications.first.taskId, 'cap-44');
  });

  test('aynı açık durak için ikinci bildirim açılmaz', () {
    final s = SessionController();
    final incoming = DeliveryTask(
      id: 't-dup',
      ref: 'DGO-9002',
      recipient: 'Ada',
      address: 'x',
      window: '—',
      kind: TaskKind.delivery,
      status: TaskStatus.assigned,
    );
    s.applyTaskDelta(changed: [incoming], removedIds: const []);
    final count = s.notifications.where((n) => n.taskId == 't-dup').length;
    expect(count, 1);
    s.tasks.removeWhere((t) => t.id == 't-dup');
    s.applyTaskDelta(changed: [incoming], removedIds: const []);
    expect(s.notifications.where((n) => n.taskId == 't-dup').length, 1);
  });
}
