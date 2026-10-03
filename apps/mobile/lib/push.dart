import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'alerts.dart';
import 'scan.dart';

/// FCM. Yalnız [attach] ve dart-define ile açılır — test / demo etkilenmez.
class FieldPush {
  FieldPush._();

  static final incoming = ValueNotifier<Map<String, String>?>(null);
  static String? token;
  static bool _ready = false;

  static const _apiKey = String.fromEnvironment('FCM_API_KEY');
  static const _appId = String.fromEnvironment('FCM_APP_ID');
  static const _senderId = String.fromEnvironment('FCM_MESSAGING_SENDER_ID');
  static const _projectId = String.fromEnvironment('FCM_PROJECT_ID');

  static bool get configured =>
      _apiKey.isNotEmpty &&
      _appId.isNotEmpty &&
      _senderId.isNotEmpty &&
      _projectId.isNotEmpty;

  static Future<void> attach({bool requestOs = false}) async {
    if (!configured || inWidgetTest) return;
    try {
      if (!_ready) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: _apiKey,
            appId: _appId,
            messagingSenderId: _senderId,
            projectId: _projectId,
          ),
        );
        final messaging = FirebaseMessaging.instance;
        await messaging.setForegroundNotificationPresentationOptions(
          alert: false,
          badge: true,
          sound: false,
        );
        FirebaseMessaging.onMessage.listen(_onMessage);
        FirebaseMessaging.onMessageOpenedApp.listen(_onOpen);
        final initial = await messaging.getInitialMessage();
        if (initial != null) _onOpen(initial);
        messaging.onTokenRefresh.listen((next) {
          token = next;
          incoming.value = {'token': next};
        });
        _ready = true;
      }
      if (requestOs) {
        await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      token = await FirebaseMessaging.instance.getToken();
    } catch (_) {}
  }

  static void _onMessage(RemoteMessage message) {
    incoming.value = _dataOf(message);
  }

  static void _onOpen(RemoteMessage message) {
    final id = message.data['id'];
    if (id is String && id.isNotEmpty) {
      FieldAlerts.tapId.value = id;
    }
  }

  static Map<String, String> _dataOf(RemoteMessage message) {
    final data = <String, String>{
      for (final e in message.data.entries) e.key: '${e.value}',
    };
    final n = message.notification;
    if (n?.title != null) data.putIfAbsent('title', () => n!.title!);
    if (n?.body != null) data.putIfAbsent('body', () => n!.body!);
    return data;
  }
}
