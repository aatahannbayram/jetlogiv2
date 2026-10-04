import 'dart:convert';
import 'dart:typed_data';

import 'catalog.dart';

/// Üçlü yanıt. [unknown] telde `null` gider; `null` Hayır değildir.
enum PluxeeAnswer { yes, no, unknown }

class PluxeeSlots {
  static const beforeApply = 'beforeApply';
  static const afterApply = 'afterApply';
  static const fullSignage = 'fullSignage';
  static const interior = 'interior';
  static const exterior = 'exterior';

  static const yesBranch = <String>[
    beforeApply,
    afterApply,
    fullSignage,
    interior,
  ];

  static const noBranch = <String>[fullSignage, exterior];

  static const labels = <String, String>{
    beforeApply: 'Uygulama öncesi fotoğrafı',
    afterApply: 'Uygulama sonrası fotoğrafı',
    fullSignage: 'Mekân tam tabela',
    interior: 'İç mekân',
    exterior: 'Dış mekân',
  };
}

class PluxeePhoto {
  PluxeePhoto({
    required this.slot,
    required this.capturedAt,
    this.bytes,
    this.path,
    this.used = false,
    this.evidenceId,
    this.uploadFailed = false,
    this.idempotencyKey,
  });

  final String slot;
  Uint8List? bytes;
  String? path;
  final DateTime capturedAt;
  bool used;
  String? evidenceId;
  bool uploadFailed;
  String? idempotencyKey;

  Map<String, dynamic> toJson() => {
    'slot': slot,
    'capturedAt': capturedAt.toUtc().toIso8601String(),
    'path': path,
    'bytes': bytes == null ? null : base64Encode(bytes!),
    'used': used,
    'evidenceId': evidenceId,
    'uploadFailed': uploadFailed,
    'idempotencyKey': idempotencyKey,
  };

  factory PluxeePhoto.fromJson(Map<String, dynamic> json) {
    final raw = json['bytes'];
    return PluxeePhoto(
      slot: json['slot'] as String? ?? '',
      capturedAt:
          DateTime.tryParse('${json['capturedAt']}')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      path: json['path'] as String?,
      bytes: raw is String ? base64Decode(raw) : null,
      used: json['used'] == true,
      evidenceId: json['evidenceId'] as String?,
      uploadFailed: json['uploadFailed'] == true,
      idempotencyKey: json['idempotencyKey'] as String?,
    );
  }
}

class PluxeeDraft {
  PluxeeDraft({required this.taskId});

  final String taskId;
  bool? stickerApplied;
  PluxeeAnswer? existingSticker;
  PluxeeAnswer? otherMealCard;
  bool? visualDelivered;
  String note = '';
  String? reasonKey;
  String? detailKey;
  final Map<String, PluxeePhoto> photos = {};
  double? latitude;
  double? longitude;
  DateTime? locationCapturedAt;
  bool cameraDenied = false;
  bool submitted = false;
  bool awaitingForm = false;
  bool heldForOps = false;
  String? formIdempotencyKey;
  String? formFingerprint;

  static const locationFreshFor = Duration(minutes: 5);

  bool? wire(PluxeeAnswer? answer) => switch (answer) {
    PluxeeAnswer.yes => true,
    PluxeeAnswer.no => false,
    PluxeeAnswer.unknown => null,
    null => null,
  };

  List<String> get activeSlots =>
      stickerApplied == false ? PluxeeSlots.noBranch : PluxeeSlots.yesBranch;

  List<PluxeePhoto> get excludedPhotos => [
    for (final photo in photos.values)
      if (!activeSlots.contains(photo.slot)) photo,
  ];

  List<PluxeePhoto> get submitPhotos => [
    for (final slot in activeSlots)
      if (photos[slot] case final photo?)
        if (photo.used) photo,
  ];

  List<String> get missingSlots => [
    for (final slot in activeSlots)
      if (photos[slot] == null || photos[slot]!.used == false) slot,
  ];

  bool get cancelComplete =>
      reasonKey != null &&
      reasonKey!.isNotEmpty &&
      detailKey != null &&
      detailKey!.isNotEmpty;

  bool locationFresh(DateTime now) {
    final captured = locationCapturedAt;
    if (latitude == null || longitude == null || captured == null) {
      return false;
    }
    return now.toUtc().difference(captured.toUtc()) <= locationFreshFor;
  }

  bool answersComplete() {
    if (stickerApplied == null || visualDelivered == null) return false;
    if (existingSticker == null || otherMealCard == null) return false;
    if (stickerApplied == false && !cancelComplete) return false;
    return true;
  }

  bool holdsForOps() {
    final exception = pluxeeOpsHoldDetails.contains(detailKey);
    if (!exception && !cameraDenied) return false;
    return missingSlots.isNotEmpty;
  }

  void setStickerApplied(bool value) {
    stickerApplied = value;
    submitted = false;
    if (value) {
      reasonKey = null;
      detailKey = null;
    }
  }

  /// Ana sebep değişince alt seçim sıfırlanır.
  void setReason(String key) {
    if (reasonKey != key) detailKey = null;
    reasonKey = key;
    submitted = false;
  }

  void setDetail(String key) {
    detailKey = key;
    submitted = false;
  }

  /// Yeni kare yalnızca kendi yuvasına yazılır. Zaman kuralı bozulursa
  /// mevcut yuva da değişmez.
  String? assignPhoto(PluxeePhoto photo) {
    final after = photos[PluxeeSlots.afterApply];
    final before = photos[PluxeeSlots.beforeApply];
    if (photo.slot == PluxeeSlots.beforeApply && after != null) {
      if (after.path != null && after.path == photo.path) {
        return 'Eski bir sonrası fotoğrafı öncesi alanına yüklenemez.';
      }
      if (photo.capturedAt.isAfter(after.capturedAt)) {
        return 'Öncesi fotoğrafı uygulamadan önce çekilmelidir.';
      }
    }
    if (photo.slot == PluxeeSlots.afterApply &&
        before != null &&
        photo.capturedAt.isBefore(before.capturedAt)) {
      return 'Sonrası fotoğrafı, öncesi fotoğraftan daha eski olamaz.';
    }
    photo
      ..used = false
      ..evidenceId = null
      ..uploadFailed = false
      ..idempotencyKey = null;
    photos[photo.slot] = photo;
    submitted = false;
    return null;
  }

  void confirmPhoto(String slot) {
    final photo = photos[slot];
    if (photo == null) return;
    photo.used = true;
    submitted = false;
  }

  void retake(String slot) {
    photos.remove(slot);
    submitted = false;
  }

  void setLocation({
    required double latitude,
    required double longitude,
    required DateTime capturedAt,
  }) {
    this.latitude = latitude;
    this.longitude = longitude;
    locationCapturedAt = capturedAt.toUtc();
    submitted = false;
  }

  Map<String, dynamic> formValues() => {
    'catalogVersion': pluxeeCatalogVersion,
    'stickerApplied': stickerApplied,
    'existingPluxeeSticker': wire(existingSticker),
    'otherMealCard': wire(otherMealCard),
    'visualMaterialDelivered': visualDelivered,
    'note': note,
    'cancellationReasonKey': stickerApplied == false ? reasonKey : null,
    'cancellationDetailKey': stickerApplied == false ? detailKey : null,
    'evidence': [
      for (final photo in submitPhotos)
        {
          'slot': photo.slot,
          'capturedAt': photo.capturedAt.toUtc().toIso8601String(),
          'evidenceId': photo.evidenceId,
        },
    ],
    'latitude': latitude,
    'longitude': longitude,
    'locationCapturedAt': locationCapturedAt?.toUtc().toIso8601String(),
  };

  /// Gövde değişmeden aynı anahtar. Gövde değişince yeni anahtar.
  void syncFormKey(String Function() newKey) {
    final next = jsonEncode(formValues());
    if (next != formFingerprint) {
      formFingerprint = next;
      formIdempotencyKey = newKey();
    }
  }

  String photoKey(PluxeePhoto photo, String Function() newKey) {
    return photo.idempotencyKey ??= newKey();
  }

  Map<String, dynamic> toJson() => {
    'taskId': taskId,
    'stickerApplied': stickerApplied,
    'existingSticker': existingSticker?.name,
    'otherMealCard': otherMealCard?.name,
    'visualDelivered': visualDelivered,
    'note': note,
    'reasonKey': reasonKey,
    'detailKey': detailKey,
    'photos': [for (final photo in photos.values) photo.toJson()],
    'latitude': latitude,
    'longitude': longitude,
    'locationCapturedAt': locationCapturedAt?.toUtc().toIso8601String(),
    'cameraDenied': cameraDenied,
    'submitted': submitted,
    'awaitingForm': awaitingForm,
    'heldForOps': heldForOps,
    'formIdempotencyKey': formIdempotencyKey,
    'formFingerprint': formFingerprint,
  };

  factory PluxeeDraft.fromJson(Map<String, dynamic> json) {
    final draft = PluxeeDraft(taskId: '${json['taskId'] ?? ''}');
    draft.stickerApplied = json['stickerApplied'] as bool?;
    draft.existingSticker = _answer(json['existingSticker']);
    draft.otherMealCard = _answer(json['otherMealCard']);
    draft.visualDelivered = json['visualDelivered'] as bool?;
    draft.note = json['note'] as String? ?? '';
    draft.reasonKey = json['reasonKey'] as String?;
    draft.detailKey = json['detailKey'] as String?;
    final photos = json['photos'];
    if (photos is List) {
      for (final row in photos) {
        if (row is Map) {
          final photo = PluxeePhoto.fromJson(Map<String, dynamic>.from(row));
          draft.photos[photo.slot] = photo;
        }
      }
    }
    draft.latitude = (json['latitude'] as num?)?.toDouble();
    draft.longitude = (json['longitude'] as num?)?.toDouble();
    draft.locationCapturedAt = DateTime.tryParse(
      '${json['locationCapturedAt']}',
    );
    draft.cameraDenied = json['cameraDenied'] == true;
    draft.submitted = json['submitted'] == true;
    draft.awaitingForm = json['awaitingForm'] == true;
    draft.heldForOps = json['heldForOps'] == true;
    draft.formIdempotencyKey = json['formIdempotencyKey'] as String?;
    draft.formFingerprint = json['formFingerprint'] as String?;
    return draft;
  }

  static PluxeeAnswer? _answer(Object? raw) {
    return switch (raw) {
      'yes' => PluxeeAnswer.yes,
      'no' => PluxeeAnswer.no,
      'unknown' => PluxeeAnswer.unknown,
      _ => null,
    };
  }
}
