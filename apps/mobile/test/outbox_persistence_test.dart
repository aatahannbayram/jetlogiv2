import 'dart:io';

import 'package:dijigoo_kurye/data/database.dart';
import 'package:dijigoo_kurye/data/outbox.dart';
import 'package:dijigoo_kurye/models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('outbox_persistence_test');
    path = '${dir.path}/test.sqlite';
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test('kuyruk app kill sonrası kaybolmaz, aynı dosyadan geri yüklenir', () async {
    // "1. açılış": kuyruğa iki öğe ekle, diske yazılmasını bekle, kapat.
    var db = AppDatabase(NativeDatabase(File(path)));
    var store = OutboxStore(db: db);
    store.enqueue(
      operation: SyncOperation.taskFinalize,
      subjectId: 't1',
      payload: const {'outcome': 'DELIVERED'},
    );
    store.enqueue(
      operation: SyncOperation.taskTransition,
      subjectId: 't2',
      payload: const {'outcome': 'FAILED'},
    );
    await store.waitForPersistence();
    await db.close();

    // "Kill + yeniden aç": taze bir OutboxStore, aynı veritabanı dosyası.
    db = AppDatabase(NativeDatabase(File(path)));
    store = OutboxStore(db: db);
    expect(store.events, isEmpty, reason: 'hydrate çağrılmadan önce boş olmalı');

    await store.hydrateFromDb();

    expect(store.pendingCount, 2);
    expect(
      store.events.map((e) => e.subjectId).toSet(),
      {'t1', 't2'},
    );

    // Yeni bir enqueue, önceki (persisted) sequence'lerle çakışan bir
    // clientEventId üretmemeli.
    final existingIds = store.events.map((e) => e.clientEventId).toSet();
    final third = store.enqueue(operation: SyncOperation.stepSubmit, subjectId: 't3');
    expect(existingIds.contains(third.clientEventId), isFalse);

    await db.close();
  });

  test('applyResults sonrası applied olanlar hydrate ile tekrar pending gelmez', () async {
    var db = AppDatabase(NativeDatabase(File(path)));
    var store = OutboxStore(db: db);
    final event = store.enqueue(
      operation: SyncOperation.taskFinalize,
      subjectId: 't1',
    );
    await store.waitForPersistence();
    await store.applyResults([(id: event.clientEventId, status: 'applied')]);
    await db.close();

    db = AppDatabase(NativeDatabase(File(path)));
    store = OutboxStore(db: db);
    await store.hydrateFromDb();

    expect(store.pendingCount, 0);
    expect(store.events.single.status, 'applied');

    await db.close();
  });
}
