import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'alerts.dart';
import 'api/client.dart';
import 'push.dart';
import 'api/panel_client.dart';
import 'app.dart';
import 'data/database.dart';
import 'data/outbox.dart';
import 'data/vault.dart';
import 'log.dart';
import 'session.dart';

/// Boş bırakılırsa Sentry hiç başlatılmaz (ağ çağrısı, ek yük yok) — DSN
/// verilince `--dart-define=SENTRY_DSN=https://...` ile tek satır açılır.
/// Sahada bir kuryenin uygulaması çökünce bugüne kadar bunu görmenin tek
/// yolu kuryenin kendi bildirmesiydi.
const _sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    DgLog.e(LogLayer.ui, details.exceptionAsString());
    if (_sentryDsn.isNotEmpty) {
      unawaited(
        Sentry.captureException(details.exception, stackTrace: details.stack),
      );
    }
    FlutterError.presentError(details);
  };
  if (_sentryDsn.isEmpty) {
    await _bootstrap();
  } else {
    await SentryFlutter.init((options) {
      options.dsn = _sentryDsn;
      options.tracesSampleRate = 0.2;
      // Konum/telefon gibi PII log satırlarına zaten redactForLog ile
      // giriyor (bkz. secure.dart) — Sentry breadcrumb'larında da aynı
      // disiplin: varsayılan PII toplamayı kapalı bırak.
      options.sendDefaultPii = false;
    }, appRunner: _bootstrap);
  }
}

Future<void> _bootstrap() async {
  final vault = Vault();
  var cipherOn = false;
  var storageOk = true;
  AppDatabase? db;
  try {
    db = await AppDatabase.openEncrypted(vault);
    await db.ping();
    cipherOn = true;
  } catch (_) {
    db = AppDatabase.memory();
    cipherOn = false;
    // Şifreli depo açılmazsa kilit ekranı yerine bellek DB: aynı APK
    // yine sahaya düşer. Canlı yazmalar storageOk ile ayrı korunur.
  }
  late final MobileApi api;
  try {
    api = MobileApi.create(vault: vault);
  } catch (_) {
    api = MobileApi(
      dio: Dio(
        BaseOptions(
          baseUrl: kApiBase,
          connectTimeout: const Duration(seconds: 2),
        ),
      ),
      vault: vault,
    );
  }
  PanelApi? panel;
  try {
    panel = await PanelApi.create(vault: vault);
  } catch (_) {
    panel = null;
  }
  final seen = await vault.onboardSeen;
  final outbox = OutboxStore(db: db);
  await outbox.hydrateFromDb();
  final session =
      SessionController(
          outbox: outbox,
          api: api,
          panel: panel,
          vault: vault,
          waitForConfig: true,
          initialPhase: seen ? AppPhase.splash : AppPhase.onboard,
        )
        ..cipherOn = cipherOn
        ..storageOk = storageOk;
  await session.restoreUiPrefs();
  await session.restoreLocalShift();
  await DgLog.attach();
  DgLog.i(
    LogLayer.boot,
    'app start cipher=$cipherOn storage=$storageOk seen=$seen',
  );

  runApp(
    ProviderScope(
      overrides: [sessionProvider.overrideWith((ref) => session)],
      child: const DijigooApp(),
    ),
  );
  if (storageOk) {
    unawaited(FieldAlerts.attach().then((_) => session.resyncAlerts()));
    FieldPush.incoming.addListener(() {
      final data = FieldPush.incoming.value;
      if (data != null) session.ingestPushData(data);
    });
    unawaited(FieldPush.attach().then((_) => session.registerPushToken()));
  }
}
