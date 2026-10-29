import 'api/agency_models.dart';
import 'api/branch_models.dart';
import 'api/panel_client.dart';
import 'api/panel_models.dart';
import 'branch_workspace.dart';
import 'data/vault.dart';
import 'screens/sube_demo.dart';

/// Dersli eğitim oynatıcısı: izleme süresi, dersler, sınav, kurye SSS'si,
/// şubede kurye eğitimini önizleme ve düzenleme. Varsayılan açık (ürün
/// kararı, 29.10.2026); `--dart-define=TRAINING_PLAYER=false` ile kapanır,
/// eğitimler o zaman sade görünümde açılır. Testler açıp kapatabilir.
const kTrainingPlayerDefault = bool.fromEnvironment(
  'TRAINING_PLAYER',
  defaultValue: true,
);
bool trainingPlayerEnabled = kTrainingPlayerDefault;

/// Eğitim oynatıcının konuştuğu taraf: kurye (`courier-trainings`) ya da
/// şube kullanıcısı (`branch/training`). Hatalar gösterilecek Türkçe metne
/// çevrilir; başarıda `null` döner.
abstract class TrainingPort {
  /// Önizleme (şube, kurye eğitimi): ilerleme kaydedilmez, sınav gitmez.
  bool get preview => false;

  Future<LearnerTraining?> detail(String trainingId);

  /// İzleme ilerlemesi (kümülatif saniye). Sessizdir; hata gösterilmez.
  Future<void> progress(String trainingId, int viewedSeconds);

  Future<String?> complete(String trainingId, int viewedSeconds);

  Future<String?> lessonProgress(
    String trainingId,
    String lessonId, {
    required int viewedSeconds,
    bool completed = false,
  });

  Future<({QuizResult? result, String? error})> submitQuiz(
    String trainingId,
    String lessonId,
    Map<String, List<String>> answers,
  );
}

/// Sunucu hata kodu → kullanıcıya gösterilecek metin. Sunucunun kendi
/// Türkçe mesajı varsa o kullanılır.
String trainingErrorText(String code, String? serverMessage) {
  if (serverMessage != null && serverMessage.trim().isNotEmpty) {
    return serverMessage;
  }
  return switch (code) {
    'TRAINING_MIN_VIEW_NOT_REACHED' || 'LESSON_MIN_VIEW_NOT_REACHED' =>
      'En kısa izleme süresi dolmadı. Biraz daha izleyip tekrar deneyin.',
    'LESSON_LOCKED' => 'Önce önceki zorunlu dersi bitirin.',
    'LIVE_NOT_STARTED' =>
      'Canlı oturuma başlangıçtan 15 dakika önce katılabilirsiniz.',
    'QUIZ_EMPTY' ||
    'LESSON_NOT_QUIZ' ||
    'ANSWERS_REQUIRED' => 'Sınav gönderilemedi.',
    'TRAINING_NOT_FOUND' || 'LESSON_NOT_FOUND' => 'Eğitim bulunamadı.',
    _ => 'İşlem tamamlanamadı. Tekrar deneyin.',
  };
}

/// Kurye uygulaması: `courier-trainings/*`.
class CourierTrainingPort extends TrainingPort {
  CourierTrainingPort(this.api);

  final PanelApi api;

  String _text(Object e) => e is PanelApiException
      ? trainingErrorText(e.code, e.serverMessage)
      : trainingErrorText('', null);

  Future<String?> _guard(Future<void> Function() run) async {
    try {
      await run();
      return null;
    } catch (e) {
      return _text(e);
    }
  }

  @override
  Future<LearnerTraining?> detail(String trainingId) =>
      api.fetchTrainingDetail(trainingId);

  @override
  Future<void> progress(String trainingId, int viewedSeconds) async {
    try {
      await api.recordTrainingProgress(
        trainingId,
        viewedSeconds: viewedSeconds,
      );
    } catch (_) {
      // İlerleme bir sonraki kayıtta (kümülatif) yeniden gider.
    }
  }

  @override
  Future<String?> complete(String trainingId, int viewedSeconds) => _guard(
    () => api.completeTraining(trainingId, viewedSeconds: viewedSeconds),
  );

  @override
  Future<String?> lessonProgress(
    String trainingId,
    String lessonId, {
    required int viewedSeconds,
    bool completed = false,
  }) => _guard(
    () => api.recordLessonProgress(
      trainingId,
      lessonId,
      viewedSeconds: viewedSeconds,
      completed: completed,
    ),
  );

  @override
  Future<({QuizResult? result, String? error})> submitQuiz(
    String trainingId,
    String lessonId,
    Map<String, List<String>> answers,
  ) async {
    try {
      return (
        result: await api.submitLessonQuiz(trainingId, lessonId, answers),
        error: null,
      );
    } catch (e) {
      return (result: null, error: _text(e));
    }
  }
}

/// Şube kullanıcısı: `branch/training/*`. [preview] kurye eğitiminin
/// önizlemesidir. Demo girişinde örnek veriyle, sunucuya gitmeden çalışır.
class BranchTrainingPort extends TrainingPort {
  BranchTrainingPort(
    this.branch, {
    required this.targetType,
    this.preview = false,
  });

  final BranchWorkspace branch;
  final String targetType;

  @override
  final bool preview;

  String _text(Object e) => e is AgencyApiException
      ? trainingErrorText(e.code, e.serverMessage)
      : trainingErrorText('', null);

  @override
  Future<LearnerTraining?> detail(String trainingId) async {
    if (branch.demo) {
      return kSubeDemoTrainingDetail(
        trainingId,
        doneLessons: branch.demoLessonsDone,
        preview: preview,
      );
    }
    final api = branch.api!;
    return preview
        ? api.fetchTrainingPreview(trainingId)
        : api.fetchTrainingDetail(trainingId);
  }

  @override
  Future<void> progress(String trainingId, int viewedSeconds) async {
    if (preview || branch.demo) return;
    try {
      await branch.api!.trainingAction(trainingId, 'progress', {
        'viewedSeconds': viewedSeconds,
      }, idempotencyKey: Vault.newUuid());
    } catch (_) {
      // İlerleme bir sonraki kayıtta (kümülatif) yeniden gider.
    }
  }

  @override
  Future<String?> complete(String trainingId, int viewedSeconds) async {
    if (preview) return null;
    return branch.completeTrainingById(
      trainingId,
      targetType: targetType,
      viewedSeconds: viewedSeconds,
    );
  }

  @override
  Future<String?> lessonProgress(
    String trainingId,
    String lessonId, {
    required int viewedSeconds,
    bool completed = false,
  }) async {
    if (preview) return null;
    if (branch.demo) {
      if (completed) {
        branch.demoCompleteLesson(trainingId, lessonId, targetType);
      }
      return null;
    }
    try {
      await branch.api!.recordLessonProgress(
        trainingId,
        lessonId,
        viewedSeconds: viewedSeconds,
        completed: completed,
        idempotencyKey: Vault.newUuid(),
      );
      return null;
    } catch (e) {
      return _text(e);
    }
  }

  @override
  Future<({QuizResult? result, String? error})> submitQuiz(
    String trainingId,
    String lessonId,
    Map<String, List<String>> answers,
  ) async {
    if (preview) return (result: null, error: null);
    if (branch.demo) {
      final result = kSubeDemoGradeQuiz(lessonId, answers);
      if (result.passed) {
        branch.demoCompleteLesson(trainingId, lessonId, targetType);
      }
      return (result: result, error: null);
    }
    try {
      return (
        result: await branch.api!.submitLessonQuiz(
          trainingId,
          lessonId,
          answers,
          idempotencyKey: Vault.newUuid(),
        ),
        error: null,
      );
    } catch (e) {
      return (result: null, error: _text(e));
    }
  }
}
