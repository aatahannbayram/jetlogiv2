import 'dart:convert';

import '../pluxee/draft.dart';
import 'database.dart';

class PluxeeDraftStore {
  PluxeeDraftStore(this.db);

  final AppDatabase db;

  Future<PluxeeDraft?> load(String taskId) async {
    final row = await (db.select(
      db.pluxeeDraftRows,
    )..where((table) => table.taskId.equals(taskId))).getSingleOrNull();
    if (row == null) return null;
    final decoded = jsonDecode(row.bodyJson);
    if (decoded is! Map) return null;
    return PluxeeDraft.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<void> save(PluxeeDraft draft) async {
    await db
        .into(db.pluxeeDraftRows)
        .insertOnConflictUpdate(
          PluxeeDraftRowsCompanion.insert(
            taskId: draft.taskId,
            bodyJson: jsonEncode(draft.toJson()),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }
}
