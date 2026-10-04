import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

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

class PluxeeDraftRows extends Table {
  TextColumn get taskId => text()();
  TextColumn get bodyJson => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {taskId};
}

@DriftDatabase(tables: [OutboxRows, PluxeeDraftRows])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) await migrator.createTable(pluxeeDraftRows);
    },
  );

  /// Opens the on-device file with SQLCipher / sqlite3mc. Key lives in the vault.
  static Future<AppDatabase> openEncrypted(Vault vault) async {
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

  static AppDatabase memory() => AppDatabase(NativeDatabase.memory());

  Future<void> ping() async {
    await customSelect('select 1').get();
  }
}
