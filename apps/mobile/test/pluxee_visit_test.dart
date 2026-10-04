import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dijigoo_kurye/data/database.dart';
import 'package:dijigoo_kurye/data/pluxee_store.dart';
import 'package:dijigoo_kurye/pluxee/catalog.dart';
import 'package:dijigoo_kurye/pluxee/draft.dart';
import 'package:dijigoo_kurye/pluxee/submit.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late PluxeeCatalog catalog;

  setUpAll(() {
    catalog = PluxeeCatalog.parse(
      File('assets/pluxee/iptal_secenekleri.json').readAsStringSync(),
    );
  });

  test('katalog 5 grup ve 22 açıklama, şube notu yok', () {
    expect(catalog.groups, hasLength(5));
    expect(catalog.detailCount, 22);
    expect(catalog.detailsFor('KAPALI'), [
      'Ziyarette kapalı',
      'Tadilat nedeniyle kapalı',
      'Güvenlik giriş izni vermiyor',
    ]);
    final joined = catalog.groups
        .expand((group) => [group.reason, ...group.details])
        .join('\n');
    expect(joined.contains('ŞUBE HATA NOTU'), isFalse);
  });

  test('ana sebep değişince alt seçim boşalır, evet dalı iptali siler', () {
    final draft = PluxeeDraft(taskId: 't');
    draft.setStickerApplied(false);
    draft.setReason('KAPALI');
    draft.setDetail('Ziyarette kapalı');
    expect(catalog.detailsFor(draft.reasonKey!), hasLength(3));
    draft.setReason('ADRES HATALI');
    expect(draft.detailKey, isNull);
    expect(catalog.containsDetail('ADRES HATALI', 'Ziyarette kapalı'), isFalse);
    expect(draft.cancelComplete, isFalse);
    draft.setDetail('Taşınmış');
    expect(draft.cancelComplete, isTrue);
    draft.setStickerApplied(true);
    expect(draft.reasonKey, isNull);
    expect(draft.detailKey, isNull);
    expect(draft.formValues()['cancellationReasonKey'], isNull);
  });

  test('bilinmiyor null gider ve hayır değildir', () {
    final draft = PluxeeDraft(taskId: 't');
    draft.existingSticker = PluxeeAnswer.unknown;
    draft.otherMealCard = PluxeeAnswer.unknown;
    expect(draft.wire(draft.existingSticker), isNull);
    expect(draft.wire(draft.existingSticker), isNot(false));
    expect(draft.formValues()['existingPluxeeSticker'], isNull);
    expect(draft.formValues()['otherMealCard'], isNull);
  });

  test('yuva diğerini silmez, karşı dal gönderilmez, zaman kuralı', () {
    final draft = PluxeeDraft(taskId: 't');
    draft.setStickerApplied(true);
    final beforeAt = DateTime.utc(2026, 10, 4, 9);
    final afterAt = beforeAt.add(const Duration(minutes: 10));
    expect(
      draft.assignPhoto(
        PluxeePhoto(
          slot: PluxeeSlots.beforeApply,
          capturedAt: beforeAt,
          path: 'before.jpg',
          bytes: Uint8List.fromList([1]),
        ),
      ),
      isNull,
    );
    expect(
      draft.assignPhoto(
        PluxeePhoto(
          slot: PluxeeSlots.afterApply,
          capturedAt: afterAt,
          path: 'after.jpg',
          bytes: Uint8List.fromList([2]),
        ),
      ),
      isNull,
    );
    expect(
      draft.assignPhoto(
        PluxeePhoto(
          slot: PluxeeSlots.fullSignage,
          capturedAt: afterAt,
          path: 'sign.jpg',
          bytes: Uint8List.fromList([3]),
        ),
      ),
      isNull,
    );
    draft.confirmPhoto(PluxeeSlots.fullSignage);
    expect(draft.photos[PluxeeSlots.beforeApply]!.used, isFalse);
    expect(draft.photos[PluxeeSlots.fullSignage]!.used, isTrue);

    final rejected = draft.assignPhoto(
      PluxeePhoto(
        slot: PluxeeSlots.beforeApply,
        capturedAt: afterAt.add(const Duration(minutes: 1)),
        path: 'late-before.jpg',
        bytes: Uint8List.fromList([9]),
      ),
    );
    expect(rejected, isNotNull);
    expect(draft.photos[PluxeeSlots.beforeApply]!.path, 'before.jpg');

    final reused = draft.assignPhoto(
      PluxeePhoto(
        slot: PluxeeSlots.beforeApply,
        capturedAt: beforeAt,
        path: 'after.jpg',
        bytes: Uint8List.fromList([2]),
      ),
    );
    expect(reused, contains('sonrası'));
    expect(draft.photos[PluxeeSlots.afterApply]!.path, 'after.jpg');

    draft.setStickerApplied(false);
    draft
      ..reasonKey = 'KAPALI'
      ..detailKey = 'Ziyarette kapalı';
    expect(
      draft.assignPhoto(
        PluxeePhoto(
          slot: PluxeeSlots.exterior,
          capturedAt: afterAt,
          path: 'out.jpg',
          bytes: Uint8List.fromList([4]),
        ),
      ),
      isNull,
    );
    draft.confirmPhoto(PluxeeSlots.exterior);
    draft.confirmPhoto(PluxeeSlots.fullSignage);
    final sent = draft.submitPhotos.map((photo) => photo.slot).toList();
    expect(sent, [PluxeeSlots.fullSignage, PluxeeSlots.exterior]);
    expect(
      draft.excludedPhotos.map((photo) => photo.slot),
      containsAll([PluxeeSlots.beforeApply, PluxeeSlots.afterApply]),
    );
    expect(
      draft.formValues()['evidence'],
      isNot(contains(containsPair('slot', PluxeeSlots.beforeApply))),
    );
  });

  test('gövde değişmeden idempotency anahtarı durur', () {
    final draft = _readyYes(DateTime.utc(2026, 10, 4, 12));
    var n = 0;
    draft.syncFormKey(() => 'key-${n++}');
    final first = draft.formIdempotencyKey;
    draft.syncFormKey(() => 'key-${n++}');
    expect(draft.formIdempotencyKey, first);
    draft.note = 'kapı önü';
    draft.syncFormKey(() => 'key-${n++}');
    expect(draft.formIdempotencyKey, isNot(first));
  });

  test('eksik fotoğraf, konum veya yüklemede başarı yok', () async {
    final now = DateTime.utc(2026, 10, 4, 12);
    final missing = _readyYes(now);
    missing.retake(PluxeeSlots.interior);
    final missingResult = await const PluxeeSubmitter().run(
      draft: missing,
      formVersionId: 'form-1',
      now: now,
      upload: (_, _) async => 'e',
      saveForm: (_, _, _) async {},
    );
    expect(missingResult.markedSuccess, isFalse);

    final stale = _readyYes(now);
    stale.locationCapturedAt = now.subtract(const Duration(minutes: 6));
    final staleResult = await const PluxeeSubmitter().run(
      draft: stale,
      formVersionId: 'form-1',
      now: now,
      upload: (_, _) async => 'e',
      saveForm: (_, _, _) async {},
    );
    expect(staleResult.markedSuccess, isFalse);
    expect(staleResult.message, contains('konum'));

    var uploads = 0;
    final broken = _readyYes(now);
    final brokenResult = await const PluxeeSubmitter().run(
      draft: broken,
      formVersionId: 'form-1',
      now: now,
      upload: (_, _) async {
        uploads += 1;
        throw StateError('ağ');
      },
      saveForm: (_, _, _) async {},
    );
    expect(brokenResult.markedSuccess, isFalse);
    expect(broken.submitted, isFalse);
    expect(uploads, greaterThan(0));
  });

  test('form sürümü yoksa yükleme ve başarı yok', () async {
    final now = DateTime.utc(2026, 10, 4, 12);
    final draft = _readyYes(now);
    var uploads = 0;
    var saves = 0;
    final result = await const PluxeeSubmitter().run(
      draft: draft,
      formVersionId: null,
      now: now,
      upload: (_, _) async {
        uploads += 1;
        return 'e';
      },
      saveForm: (_, _, _) async {
        saves += 1;
      },
    );
    expect(result.markedSuccess, isFalse);
    expect(result.awaitingForm, isTrue);
    expect(draft.submitted, isFalse);
    expect(uploads, 0);
    expect(saves, 0);
  });

  test('kanıtı olmayan istisna taslağı operasyonda bekler', () async {
    final now = DateTime.utc(2026, 10, 4, 12);
    final draft = _readyNo(now);
    draft.retake(PluxeeSlots.exterior);
    draft.setDetail('Fotoğraf izni yok');
    final result = await const PluxeeSubmitter().run(
      draft: draft,
      formVersionId: 'form-1',
      now: now,
      upload: (_, _) async => 'e',
      saveForm: (_, _, _) async {},
    );
    expect(result.markedSuccess, isFalse);
    expect(result.awaitingOps, isTrue);
    expect(draft.heldForOps, isTrue);
    expect(draft.submitted, isFalse);
  });

  test('tam ziyaret formu kaydeder, finalize yoktur', () async {
    final now = DateTime.utc(2026, 10, 4, 12);
    final draft = _readyYes(now);
    final saved = <Map<String, dynamic>>[];
    var finalize = 0;
    final result = await const PluxeeSubmitter().run(
      draft: draft,
      formVersionId: 'form-1',
      now: now,
      newKey: () => 'stable',
      upload: (photo, key) async => 'ev-${photo.slot}-$key',
      saveForm: (_, values, _) async {
        saved.add(values);
      },
    );
    expect(result.markedSuccess, isTrue);
    expect(draft.submitted, isTrue);
    expect(finalize, 0);
    expect(saved, hasLength(1));
    expect(saved.single['catalogVersion'], pluxeeCatalogVersion);
    expect(saved.single['stickerApplied'], isTrue);
    expect(saved.single['evidence'], hasLength(4));
    expect(
      (saved.single['evidence'] as List).every(
        (row) => (row as Map)['evidenceId'] != null,
      ),
      isTrue,
    );
  });

  test('taslak drift kaydından geri gelir', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final store = PluxeeDraftStore(db);
    final draft = _readyYes(DateTime.utc(2026, 10, 4, 12));
    draft.existingSticker = PluxeeAnswer.unknown;
    draft.note = 'kapı';
    await store.save(draft);
    final loaded = await store.load('t1');
    expect(loaded, isNotNull);
    expect(loaded!.note, 'kapı');
    expect(loaded.wire(loaded.existingSticker), isNull);
    expect(loaded.photos[PluxeeSlots.beforeApply]!.used, isTrue);
    expect(jsonEncode(loaded.toJson()), contains('beforeApply'));
    await db.close();
  });
}

PluxeeDraft _readyYes(DateTime now) {
  final draft = PluxeeDraft(taskId: 't1');
  draft.setStickerApplied(true);
  draft.existingSticker = PluxeeAnswer.yes;
  draft.otherMealCard = PluxeeAnswer.no;
  draft.visualDelivered = true;
  draft.setLocation(latitude: 37.7, longitude: 29.1, capturedAt: now);
  final before = now.subtract(const Duration(minutes: 2));
  for (final slot in PluxeeSlots.yesBranch) {
    final captured = slot == PluxeeSlots.afterApply
        ? before.add(const Duration(minutes: 1))
        : before;
    expect(
      draft.assignPhoto(
        PluxeePhoto(
          slot: slot,
          capturedAt: captured,
          path: '$slot.jpg',
          bytes: Uint8List.fromList([slot.codeUnitAt(0)]),
        ),
      ),
      isNull,
    );
    draft.confirmPhoto(slot);
  }
  return draft;
}

PluxeeDraft _readyNo(DateTime now) {
  final draft = PluxeeDraft(taskId: 't1');
  draft.setStickerApplied(false);
  draft.existingSticker = PluxeeAnswer.unknown;
  draft.otherMealCard = PluxeeAnswer.unknown;
  draft.visualDelivered = false;
  draft.setReason('KAPALI');
  draft.setDetail('Ziyarette kapalı');
  draft.setLocation(latitude: 37.7, longitude: 29.1, capturedAt: now);
  for (final slot in PluxeeSlots.noBranch) {
    expect(
      draft.assignPhoto(
        PluxeePhoto(
          slot: slot,
          capturedAt: now,
          path: '$slot.jpg',
          bytes: Uint8List.fromList([1]),
        ),
      ),
      isNull,
    );
    draft.confirmPhoto(slot);
  }
  return draft;
}
