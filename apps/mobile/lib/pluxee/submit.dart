import 'draft.dart';

class PluxeeSubmitResult {
  const PluxeeSubmitResult({
    required this.markedSuccess,
    this.awaitingForm = false,
    this.awaitingOps = false,
    this.message,
  });

  final bool markedSuccess;
  final bool awaitingForm;
  final bool awaitingOps;
  final String? message;
}

/// Kargo `finalize` çağrılmaz. Form sürümü yoksa yükleme de yapılmaz.
class PluxeeSubmitter {
  const PluxeeSubmitter();

  Future<PluxeeSubmitResult> run({
    required PluxeeDraft draft,
    required String? formVersionId,
    required DateTime now,
    required Future<String?> Function(PluxeePhoto photo, String idempotencyKey)
    upload,
    required Future<void> Function(
      String formVersionId,
      Map<String, dynamic> values,
      String idempotencyKey,
    )
    saveForm,
    String Function()? newKey,
  }) async {
    String mint() => (newKey ?? _fallbackKey)();
    draft.submitted = false;

    if (!draft.answersComplete() || draft.missingSlots.isNotEmpty) {
      if (draft.holdsForOps()) {
        draft.heldForOps = true;
        draft.awaitingForm = false;
        return const PluxeeSubmitResult(
          markedSuccess: false,
          awaitingOps: true,
          message:
              'Kanıt tamam değil. Taslak operasyon incelemesi için bekliyor.',
        );
      }
      draft.heldForOps = false;
      return PluxeeSubmitResult(
        markedSuccess: false,
        message: draft.missingSlots.isNotEmpty
            ? 'Zorunlu fotoğraflar kullanılmadan gönderilmez.'
            : 'Zorunlu yanıtlar tamamlanmadan gönderilmez.',
      );
    }

    if (!draft.locationFresh(now)) {
      draft.heldForOps = false;
      return const PluxeeSubmitResult(
        markedSuccess: false,
        message: 'Taze konum kaydı olmadan gönderilmez.',
      );
    }

    final version = formVersionId?.trim() ?? '';
    if (version.isEmpty) {
      draft.awaitingForm = true;
      draft.heldForOps = false;
      return const PluxeeSubmitResult(
        markedSuccess: false,
        awaitingForm: true,
        message: 'Form sürümü yok. Taslak bekliyor, gönderim yapılmadı.',
      );
    }

    var uploadFailed = false;
    for (final photo in draft.submitPhotos) {
      if (photo.evidenceId != null && photo.evidenceId!.isNotEmpty) continue;
      try {
        final id = await upload(photo, draft.photoKey(photo, mint));
        if (id == null || id.isEmpty) {
          photo.uploadFailed = true;
          uploadFailed = true;
        } else {
          photo
            ..evidenceId = id
            ..uploadFailed = false;
        }
      } catch (_) {
        photo.uploadFailed = true;
        uploadFailed = true;
      }
    }
    if (uploadFailed) {
      draft.awaitingForm = false;
      draft.heldForOps = false;
      return const PluxeeSubmitResult(
        markedSuccess: false,
        message: 'Fotoğraf yüklenemedi. Taslak duruyor, tekrar deneyin.',
      );
    }

    draft.syncFormKey(mint);
    try {
      await saveForm(version, draft.formValues(), draft.formIdempotencyKey!);
    } catch (_) {
      draft.awaitingForm = false;
      return const PluxeeSubmitResult(
        markedSuccess: false,
        message: 'Form kaydedilemedi. Taslak duruyor, tekrar deneyin.',
      );
    }
    draft
      ..submitted = true
      ..awaitingForm = false
      ..heldForOps = false;
    return const PluxeeSubmitResult(markedSuccess: true);
  }
}

int _keySeq = 0;

String _fallbackKey() {
  _keySeq += 1;
  final n = _keySeq.toRadixString(16).padLeft(12, '0');
  return '00000000-0000-4000-8000-$n';
}
