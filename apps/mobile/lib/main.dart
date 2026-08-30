import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/client.dart';
import 'app.dart';
import 'data/database.dart';
import 'data/outbox.dart';
import 'data/vault.dart';
import 'session.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  final seen = await vault.onboardSeen;
  final session = SessionController(
    outbox: OutboxStore(db: db),
    api: api,
    vault: vault,
    waitForConfig: true,
    initialPhase: seen ? AppPhase.splash : AppPhase.onboard,
  )..cipherOn = cipherOn;

  runApp(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith((ref) => session),
      ],
      child: const DijigooApp(),
    ),
  );
}
