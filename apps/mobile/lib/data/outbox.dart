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

  int get pendingCount => events.where((e) => e.pending).length;

  OutboxEvent enqueue({
    required SyncOperation operation,
    String? subjectId,
    Map<String, Object?> payload = const {},
  }) {
    _seq += 1;
    final event = OutboxEvent(
      clientEventId: _clientEventId(_seq),
      operation: operation,
      subjectId: subjectId,
      occurredAt: DateTime.now().toUtc(),
      sequence: _seq,
      payload: payload,
    );
    events.add(event);
    final conn = db;
    if (conn != null) {
      unawaited(
        conn
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
            ),
      );
    }
    return event;
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
