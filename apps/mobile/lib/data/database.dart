import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';

import 'memory_executor.dart';
import 'vault.dart';

part 'database.g.dart';

/// Offline drain queue — same envelope as `@dijigoo/contracts` SyncEnvelope.
class OutboxRows extends Table {
  TextColumn get clientEventId => text()();
  TextColumn get operation => text()();
  TextColumn get subjectId => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  IntColumn get sequence => integer()();
  TextColumn get payloadJson => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))();

  @override
  Set<Column<Object>> get primaryKey => {clientEventId};
}

@DriftDatabase(tables: [OutboxRows])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  /// Opens the on-device file with SQLCipher / sqlite3mc. Key lives in the vault.
  /// Web'de şifreleme yok: sqlite3.wasm tarayıcı deposunda (OPFS/IndexedDB)
  /// düz açılır; dosyalar `web/` içinde.
  static Future<AppDatabase> openEncrypted(Vault vault) async {
    if (kIsWeb) {
      return AppDatabase(driftDatabase(name: 'dijigoo_kurye', web: _web));
    }
    final hex = await vault.databaseKeyHex();
    return AppDatabase(
      driftDatabase(
        name: 'dijigoo_kurye',
        native: DriftNativeOptions(
          setup: (db) {
            db.execute("PRAGMA key = \"x'$hex'\"");
            db.execute('PRAGMA foreign_keys = ON');
          },
        ),
      ),
    );
  }

  /// Kalıcı depo açılamazsa kuyruk bellekte tutulur. Web'de ayrı bir
  /// tarayıcı veritabanı açılır.
  static AppDatabase memory() => AppDatabase(
    kIsWeb
        ? driftDatabase(name: 'dijigoo_kurye_mem', web: _web)
        : memoryExecutor(),
  );

  static final _web = DriftWebOptions(
    sqlite3Wasm: Uri.parse('sqlite3.wasm'),
    driftWorker: Uri.parse('drift_worker.js'),
  );

  Future<void> ping() async {
    await customSelect('select 1').get();
  }
}
