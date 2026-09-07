import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    DgLog.e(LogLayer.ui, details.exceptionAsString());
    FlutterError.presentError(details);
  };
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
    if (kReleaseMode) storageOk = false;
  }
  late final MobileApi api;
  try {
    api = MobileApi.create(vault: vault);
  } catch (_) {
    storageOk = false;
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
  final session = SessionController(
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
  DgLog.i(LogLayer.boot, 'app start cipher=$cipherOn storage=$storageOk seen=$seen');

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
