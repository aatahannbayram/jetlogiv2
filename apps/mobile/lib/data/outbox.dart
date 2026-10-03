import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../models.dart';
import 'database.dart';

class OutboxStore {
  OutboxStore({this.db, List<OutboxEvent>? seed}) : events = seed ?? [];

  final AppDatabase? db;
  final List<OutboxEvent> events;
  int _seq = 0;
  final List<Future<void>> _pendingWrites = [];

  int get pendingCount => events.where((e) => e.pending).length;

  OutboxEvent enqueue({
    required SyncOperation operation,
    String? subjectId,
    Map<String, Object?> payload = const {},
  }) {
    _seq += 1;
    final clientEventId = _clientEventId(_seq);
    final occurredAt = DateTime.now().toUtc();
    final event = OutboxEvent(
      clientEventId: clientEventId,
      operation: operation,
      subjectId: subjectId,
      occurredAt: occurredAt,
      sequence: _seq,
      payload: {
        ...payload,
        if (!payload.containsKey('clientEventId')) 'clientEventId': clientEventId,
        if (!payload.containsKey('occurredAt'))
          'occurredAt': occurredAt.toIso8601String(),
      },
    );
    events.add(event);
    final conn = db;
    if (conn != null) {
      final write = conn
          .into(conn.outboxRows)
          .insert(
            OutboxRowsCompanion.insert(
              clientEventId: event.clientEventId,
              operation: event.operation.wire,
              subjectId: Value(event.subjectId),
              occurredAt: event.occurredAt,
              sequence: event.sequence,
              payloadJson: jsonEncode(event.payload),
              status: Value(event.status),
            ),
          );
      _pendingWrites.add(write);
      unawaited(write);
    }
    return event;
  }

  /// Awaits any disk writes [enqueue] fired off but didn't wait for. Without
  /// this, an app kill in the window right after `enqueue()` returns can
  /// lose an item that was never actually written to disk. Call this at
  /// safe checkpoints (e.g. after a delivery is confirmed, before the app
  /// backgrounds) when the caller needs the queue to be durable, not just
  /// enqueued in memory.
  Future<void> waitForPersistence() async {
    if (_pendingWrites.isEmpty) return;
    final writes = List<Future<void>>.from(_pendingWrites);
    _pendingWrites.clear();
    await Future.wait(writes);
  }

  /// Restores events persisted by a previous app run. Without this, anything
  /// written to `outboxRows` before the app was killed is never read back —
  /// the in-memory queue starts empty on every launch and those deliveries
  /// silently never get retried, even though the bytes are still on disk.
  /// Must run before any new [enqueue] calls so `_seq` (and therefore new
  /// client event ids) picks up after the highest persisted sequence.
  Future<void> hydrateFromDb() async {
    final conn = db;
    if (conn == null) return;
    final rows = await conn.select(conn.outboxRows).get();
    for (final row in rows) {
      if (events.any((e) => e.clientEventId == row.clientEventId)) continue;
      seedQueued(
        OutboxEvent(
          clientEventId: row.clientEventId,
          operation: SyncOperationWire.fromWire(row.operation),
          subjectId: row.subjectId,
          occurredAt: row.occurredAt,
          sequence: row.sequence,
          payload: (jsonDecode(row.payloadJson) as Map).cast<String, Object?>(),
          status: row.status,
        ),
      );
    }
  }

  void drain() {
    for (final e in events) {
      if (e.pending) e.status = 'applied';
    }
    unawaited(_persistAll());
  }

  Future<void> applyResults(List<({String id, String status})> results) async {
    for (final r in results) {
      for (final e in events) {
        if (e.clientEventId != r.id) continue;
        e.status = (r.status == 'applied' || r.status == 'replayed')
            ? 'applied'
            : r.status == 'rejected'
            ? 'rejected'
            : 'pending';
      }
    }
    await _persistAll();
  }

  void seedQueued(OutboxEvent event) {
    events.add(event);
    if (event.sequence > _seq) _seq = event.sequence;
  }

  Future<void> _persistAll() async {
    final conn = db;
    if (conn == null) return;
    for (final e in events) {
      await (conn.update(conn.outboxRows)
            ..where((t) => t.clientEventId.equals(e.clientEventId)))
          .write(OutboxRowsCompanion(status: Value(e.status)));
    }
  }

  static String _clientEventId(int seq) =>
      '00000000-0000-4000-a000-${seq.toString().padLeft(12, '0')}';
}
