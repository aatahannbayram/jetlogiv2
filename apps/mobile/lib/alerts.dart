import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';
import 'notif.dart';

/// Sistem tepsisi bildirimi. Yalnız [attach] çağrılınca açılır — testler
/// ve ilk kare startup'ı etkilemez. Ön planda sessiz kalır (kabuk bandı
/// zaten gösterir); arka planda durak/senkron olayını iletir.
class FieldAlerts {
  FieldAlerts._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static final tapId = ValueNotifier<String?>(null);
  static bool _ready = false;

  static const infoChannel = 'dijigoo.field';
  static const alertChannel = 'dijigoo.field.alert';
  static const badgeSyncId = 91000;
  static const shiftReminderId = 91001;
  static const shiftPayload = 'shift-reminder';

  static int inboxNotifyId(String payload) {
    var id = payload.hashCode & 0x7fffffff;
    if (id == badgeSyncId || id == shiftReminderId) id ^= 0x111111;
    return id;
  }

  static Future<void> attach() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
      const android = AndroidInitializationSettings('@drawable/ic_stat_notify');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: android,
          iOS: darwin,
          macOS: darwin,
        ),
        onDidReceiveNotificationResponse: (response) {
          final id = response.payload;
          if (id != null && id.isNotEmpty) tapId.value = id;
        },
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final fromTap = launch?.notificationResponse?.payload;
      if (launch?.didNotificationLaunchApp == true &&
          fromTap != null &&
          fromTap.isNotEmpty) {
        tapId.value = fromTap;
      }
      _ready = true;
    } catch (_) {}
  }

  static Future<void> announce(
    AppNotification n, {
    required String title,
    int unread = 1,
  }) async {
    if (!_ready) return;
    if (!_inBackground) return;
    try {
      final alert = notifIsAlert(n.kind);
      await _plugin.show(
        id: inboxNotifyId(n.id),
        title: title,
        body: n.body,
        notificationDetails: _details(alert: alert, badge: unread),
        payload: n.id,
      );
    } catch (_) {}
  }

  static Future<void> scheduleShiftReminder({
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
    try {
      final local = nextShiftReminderAt(DateTime.now());
      final when = tz.TZDateTime(
        tz.local,
        local.year,
        local.month,
        local.day,
        local.hour,
        local.minute,
      );
      await _plugin.zonedSchedule(
        id: shiftReminderId,
        title: title,
        body: body,
        scheduledDate: when,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: _details(alert: false, badge: 1),
        payload: shiftPayload,
      );
    } catch (_) {}
  }

  static Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      await _plugin.cancelAllPendingNotifications();
    } catch (_) {}
  }

  static Future<void> cancelShiftReminder() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: shiftReminderId);
    } catch (_) {}
  }

  static Future<void> dismissInbox(String payload) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: inboxNotifyId(payload));
    } catch (_) {}
  }

  /// iOS ikon rozeti. Android rozeti tepsideki kayıtlardan gelir; sessiz
  /// senkron hemen iptal edilir ki boş satır kalmasın.
  static Future<void> syncBadge(int unread) async {
    if (!_ready) return;
    try {
      final count = unread < 0 ? 0 : unread;
      await _plugin.show(
        id: badgeSyncId,
        title: null,
        body: null,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            infoChannel,
            'Saha',
            channelDescription: 'Durak, zimmet ve vardiya',
            importance: Importance.min,
            priority: Priority.min,
            silent: true,
            playSound: false,
            enableVibration: false,
            showWhen: false,
            autoCancel: true,
            timeoutAfter: 1,
            channelShowBadge: count > 0,
            number: count,
            icon: '@drawable/ic_stat_notify',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: false,
            presentSound: false,
            presentBanner: false,
            presentList: false,
            presentBadge: true,
            badgeNumber: count,
          ),
          macOS: DarwinNotificationDetails(
            presentAlert: false,
            presentSound: false,
            presentBadge: true,
            badgeNumber: count,
          ),
        ),
      );
      await _plugin.cancel(id: badgeSyncId);
    } catch (_) {}
  }

  static NotificationDetails _details({required bool alert, required int badge}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        alert ? alertChannel : infoChannel,
        alert ? 'Uyarı' : 'Saha',
        channelDescription: alert
            ? 'İptal, çekim ve senkron hataları'
            : 'Durak, zimmet ve vardiya',
        importance: alert ? Importance.max : Importance.high,
        priority: alert ? Priority.max : Priority.high,
        icon: '@drawable/ic_stat_notify',
        color: const Color(0xFF6B46D4),
        number: badge,
        channelShowBadge: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
        badgeNumber: badge,
        interruptionLevel: alert
            ? InterruptionLevel.timeSensitive
            : InterruptionLevel.active,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        badgeNumber: badge,
      ),
    );
  }

  static bool get _inBackground {
    try {
      final state = WidgetsBinding.instance.lifecycleState;
      return state != null && state != AppLifecycleState.resumed;
    } catch (_) {
      return false;
    }
  }
}
