import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'alerts.dart';
import 'api/client.dart';
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
    FlutterError.presentError(details);
  };
  if (_sentryDsn.isEmpty) {
    await _bootstrap();
  } else {
    await SentryFlutter.init((options) {
      options.dsn = _sentryDsn;
      options.tracesSampleRate = 0.2;
    }, appRunner: _bootstrap);
  }
}

Future<void> _bootstrap() async {
  final vault = Vault();
  var cipherOn = false;
  AppDatabase? db;
  try {
    db = await AppDatabase.openEncrypted(vault);
    await db.ping();
    cipherOn = true;
  } catch (_) {
    db = AppDatabase.memory();
    cipherOn = false;
  }
  final api = MobileApi.create(vault: vault);
  PanelApi? panel;
  try {
    panel = await PanelApi.create();
  } catch (_) {
    panel = null;
  }
  final seen = await vault.onboardSeen;
  final outbox = OutboxStore(db: db);
  await outbox.hydrateFromDb();
  final session = SessionController(
    outbox: outbox,
    api: api,
    panel: panel,
    vault: vault,
    waitForConfig: true,
    initialPhase: seen ? AppPhase.splash : AppPhase.onboard,
  )..cipherOn = cipherOn;
  await session.restoreUiPrefs();
  await session.restoreLocalShift();
  await DgLog.attach();
  DgLog.i(LogLayer.boot, 'app start cipher=$cipherOn seen=$seen');

  runApp(
    ProviderScope(
      overrides: [sessionProvider.overrideWith((ref) => session)],
      child: const DijigooApp(),
    ),
  );
  unawaited(FieldAlerts.attach().then((_) => session.resyncAlerts()));
}
