import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/branch_models.dart';
import '../l10n.dart';
import '../motion.dart';
import '../scan.dart';
import '../theme.dart';
import '../training_port.dart';
import '../ui/ui.dart';
import '../widgets.dart';

String _stamp(DateTime at) {
  final t = at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}.${two(t.month)}.${t.year} ${two(t.hour)}:${two(t.minute)}';
}

IconData _lessonIcon(String type) => switch (type) {
  'VIDEO' || 'EMBED' => LucideIcons.circlePlay,
  'LIVE' => LucideIcons.radio,
  'PDF' || 'DOCUMENT' => LucideIcons.fileText,
  'LINK' => LucideIcons.link,
  'QUIZ' => LucideIcons.listChecks,
  _ => LucideIcons.bookOpen,
};

Future<void> _openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Yeni bildirim öncekini kapatır; art arda tamamlanan dersler sıraya
/// girip alttaki düğmeleri saniyelerce örtmez.
void _snack(BuildContext context, String text) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));

/// Eğitim oynatıcı (kurye ve şube ortak). Tek içerikli eğitimde içerik ve
/// "Tamamladım"; dersli eğitimde ders listesi ve ders ekranı (içerik, canlı
/// oturuma katılım, sınav). İzleme süresi cihazda ölçülür, sunucudaki
/// birikmiş sürenin üstüne eklenerek kümülatif gönderilir; en kısa süreyi
/// sunucu denetler.
class TrainingPlayerScreen extends StatefulWidget {
  const TrainingPlayerScreen({
    super.key,
    required this.port,
    required this.trainingId,
    this.title,
    this.onChanged,
  });

  final TrainingPort port;
  final String trainingId;
  final String? title;

  /// Tamamlama ya da ders ilerlemesi sonrası (listeyi tazelemek için).
  final VoidCallback? onChanged;

  @override
  State<TrainingPlayerScreen> createState() => _TrainingPlayerScreenState();
}

class _TrainingPlayerScreenState extends State<TrainingPlayerScreen> {
  late Future<LearnerTraining?> _future;
  LearnerTraining? _training;
  final _clock = Stopwatch()..start();
  Timer? _tick;
  DateTime? _openedAt;
  bool _busy = false;

  bool get _tracksProgress {
    final t = _training;
    return t != null && t.lessons.isEmpty && !t.completed && !t.preview;
  }

  int get _viewed => (_training?.viewedSeconds ?? 0) + _clock.elapsed.inSeconds;

  @override
  void initState() {
    super.initState();
    _load();
    if (!inWidgetTest && !widget.port.preview) {
      _tick = Timer.periodic(const Duration(seconds: 30), (_) => _save());
    }
  }

  void _load() {
    _future = widget.port.detail(widget.trainingId).then((t) {
      _training = t;
      return t;
    });
  }

  void _save() {
    if (!_tracksProgress) return;
    unawaited(widget.port.progress(widget.trainingId, _viewed));
  }

  @override
  void dispose() {
    _tick?.cancel();
    _save();
    super.dispose();
  }

  Future<void> _complete() async {
    final l = context.l10n;
    setState(() => _busy = true);
    final error = await widget.port.complete(widget.trainingId, _viewed);
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(context, error ?? l.trainingCompletedMsg);
    if (error == null) {
      widget.onChanged?.call();
      setState(_load);
    }
  }

  Future<void> _openLesson(LearnerTraining t, TrainingLesson lesson) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            _LessonScreen(port: widget.port, trainingId: t.id, lesson: lesson),
      ),
    );
    if (!mounted) return;
    if (changed == true) widget.onChanged?.call();
    setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? l.trainingCenterTitle)),
      body: FutureBuilder<LearnerTraining?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                DgSkeleton(height: 120, radius: 16),
                SizedBox(height: 12),
                DgSkeleton(height: 200, radius: 16),
              ],
            );
          }
          final t = snap.data;
          if (snap.hasError || t == null) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: DgEmptyState(
                icon: LucideIcons.graduationCap,
                title: trainingErrorText('TRAINING_NOT_FOUND', null),
              ),
            );
          }
          final required = t.lessons.where((x) => x.required).toList();
          final doneRequired = required.where((x) => x.completed).length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              _Header(training: t),
              if (t.preview) ...[
                const SizedBox(height: 10),
                DgPanel(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(LucideIcons.eye, size: 18, color: Dg.text3),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l.trainingPreviewNote,
                          style: Dg.typeCaption(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (t.lessons.isEmpty) ...[
                if (t.contentBody != null)
                  DgPanel(
                    child: Text(
                      t.contentBody!,
                      style: Dg.ui(size: 15, height: 1.5),
                    ),
                  ),
                if (t.contentUrl != null) ...[
                  const SizedBox(height: 12),
                  DgGradientButton(
                    label: l.trainingOpen,
                    icon: LucideIcons.circlePlay,
                    onPressed: () {
                      setState(() => _openedAt ??= DateTime.now());
                      unawaited(_openUrl(t.contentUrl!));
                    },
                  ),
                ],
                if (!t.completed && !t.preview) ...[
                  if (t.acknowledgementText != null) ...[
                    const SizedBox(height: 12),
                    Text(t.acknowledgementText!, style: Dg.typeCaption()),
                  ],
                  if (t.minimumViewSeconds > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      l.minViewHint((t.minimumViewSeconds / 60).ceil()),
                      style: Dg.typeCaption(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  DgButton(
                    key: const Key('training-complete'),
                    label: l.trainingComplete,
                    icon: LucideIcons.check,
                    tone: DgButtonTone.secondary,
                    busy: _busy,
                    // Bağlantılı içerik önce açılır; metin hemen okunabilir.
                    onPressed:
                        _busy || (t.contentUrl != null && _openedAt == null)
                        ? null
                        : _complete,
                  ),
                ],
              ] else ...[
                Text(
                  l.trainingLessonsDone(
                    t.lessons.where((x) => x.completed).length,
                    t.lessons.length,
                  ),
                  style: Dg.ui(size: 15, weight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < t.lessons.length; i++)
                  StaggerIn(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _LessonTile(
                        lesson: t.lessons[i],
                        onTap: t.lessons[i].locked
                            ? null
                            : () => _openLesson(t, t.lessons[i]),
                      ),
                    ),
                  ),
                if (!t.completed &&
                    !t.preview &&
                    required.isNotEmpty &&
                    doneRequired == required.length) ...[
                  const SizedBox(height: 6),
                  DgGradientButton(
                    label: l.trainingFinish,
                    icon: LucideIcons.check,
                    busy: _busy,
                    onPressed: _busy ? null : _complete,
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.training});

  final LearnerTraining training;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = training;
    return DgPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.title, style: Dg.ui(size: 19, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              DgStatusPill(
                label: l.trainingStatus(t.status),
                tone: switch (t.status) {
                  'COMPLETED' => DgTone.ok,
                  'IN_PROGRESS' => DgTone.info,
                  'EXPIRED' => DgTone.bad,
                  _ => DgTone.neutral,
                },
                dense: true,
              ),
              if (t.mandatory)
                DgStatusPill(
                  label: l.trainingMandatoryPill,
                  tone: DgTone.warn,
                  dense: true,
                ),
              if (t.dueAt != null)
                DgStatusPill(
                  label: l.trainingDue(_stamp(t.dueAt!).split(' ').first),
                  tone: t.overdue ? DgTone.bad : DgTone.neutral,
                  dense: true,
                ),
            ],
          ),
          if ((t.description ?? t.summary) != null) ...[
            const SizedBox(height: 10),
            Text(
              t.description ?? t.summary!,
              style: Dg.ui(size: 15, color: Dg.text2),
            ),
          ],
          if (t.progressPercent != null && !t.completed) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (t.progressPercent! / 100).clamp(0, 1).toDouble(),
                minHeight: 5,
                color: Dg.brandBlue,
                backgroundColor: Dg.hairline,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.lesson, required this.onTap});

  final TrainingLesson lesson;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final x = lesson;
    final minutes = x.durationSeconds == null
        ? null
        : (x.durationSeconds! / 60).ceil();
    return Opacity(
      opacity: x.locked ? 0.55 : 1,
      child: DgPanel(
        onTap: onTap,
        child: Row(
          children: [
            DgIconBadge(
              icon: x.completed
                  ? LucideIcons.circleCheck
                  : x.locked
                  ? LucideIcons.lock
                  : _lessonIcon(x.contentType),
              tone: x.completed
                  ? DgTone.ok
                  : x.locked
                  ? DgTone.neutral
                  : DgTone.info,
              size: 40,
              soft: true,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${x.order > 0 ? '${x.order}. ' : ''}${x.title}',
                    style: Dg.ui(size: 15, weight: FontWeight.w600),
                  ),
                  Text(
                    [
                      l.lessonType(x.contentType),
                      if (minutes != null) l.trainingMinutes(minutes),
                      if (x.locked) l.lessonLocked,
                    ].join(' · '),
                    style: Dg.typeCaption(),
                  ),
                ],
              ),
            ),
            if (x.completed)
              DgStatusPill(
                label: l.lessonCompleted,
                tone: DgTone.ok,
                dense: true,
              )
            else if (!x.locked)
              Icon(LucideIcons.chevronRight, size: 18, color: Dg.text3),
          ],
        ),
      ),
    );
  }
}

/// Ders ekranı. İçerik dersinde izleme süresi 30 sn'de bir ve çıkarken
/// bildirilir; "Dersi tamamla" en kısa süre dolmuşsa dersi bitirir. Canlı
/// derste katılım tamamlamadır. Sınav dersinde form gösterilir.
class _LessonScreen extends StatefulWidget {
  const _LessonScreen({
    required this.port,
    required this.trainingId,
    required this.lesson,
  });

  final TrainingPort port;
  final String trainingId;
  final TrainingLesson lesson;

  @override
  State<_LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<_LessonScreen> {
  final _clock = Stopwatch()..start();
  Timer? _tick;
  bool _busy = false;
  bool _done = false;

  TrainingLesson get _lesson => widget.lesson;

  bool get _tracks =>
      !_lesson.isQuiz &&
      !_lesson.isLive &&
      !_lesson.completed &&
      !_done &&
      !widget.port.preview;

  int get _viewed => _lesson.viewedSeconds + _clock.elapsed.inSeconds;

  @override
  void initState() {
    super.initState();
    if (!inWidgetTest && _tracks) {
      _tick = Timer.periodic(const Duration(seconds: 30), (_) => _save());
    }
  }

  void _save() {
    if (!_tracks) return;
    unawaited(
      widget.port.lessonProgress(
        widget.trainingId,
        _lesson.id,
        viewedSeconds: _viewed,
      ),
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    _save();
    super.dispose();
  }

  Future<void> _complete() async {
    final l = context.l10n;
    setState(() => _busy = true);
    final error = await widget.port.lessonProgress(
      widget.trainingId,
      _lesson.id,
      viewedSeconds: _viewed,
      completed: true,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = error == null;
    });
    _snack(context, error ?? l.lessonCompleted);
    if (error == null) Navigator.of(context).pop(true);
  }

  Future<void> _joinLive() async {
    final url = _lesson.openUrl;
    if (url != null) unawaited(_openUrl(url));
    if (widget.port.preview) return;
    // Katılım = tamamlama (en kısa süre uygulanmaz).
    await _complete();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final x = _lesson;
    return Scaffold(
      appBar: AppBar(title: Text(x.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Row(
            children: [
              DgIconBadge(
                icon: _lessonIcon(x.contentType),
                tone: DgTone.info,
                size: 40,
                soft: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  [
                    l.lessonType(x.contentType),
                    if (x.durationSeconds != null)
                      l.trainingMinutes((x.durationSeconds! / 60).ceil()),
                  ].join(' · '),
                  style: Dg.ui(size: 15, color: Dg.text2),
                ),
              ),
              if (x.completed || _done)
                DgStatusPill(
                  label: l.lessonCompleted,
                  tone: DgTone.ok,
                  dense: true,
                ),
            ],
          ),
          if (x.description != null) ...[
            const SizedBox(height: 12),
            Text(x.description!, style: Dg.ui(size: 15, color: Dg.text2)),
          ],
          const SizedBox(height: 16),
          if (x.isQuiz)
            _QuizForm(
              quiz: x.quiz ?? const TrainingQuiz(),
              passingScore: x.passingScore,
              enabled: !widget.port.preview,
              onSubmit: (answers) =>
                  widget.port.submitQuiz(widget.trainingId, x.id, answers),
              onPassed: () => Navigator.of(context).pop(true),
            )
          else if (x.isLive) ...[
            if (x.startsAt != null)
              Text(
                l.liveStarts(_stamp(x.startsAt!)),
                style: Dg.ui(size: 15, weight: FontWeight.w600),
              ),
            const SizedBox(height: 12),
            DgGradientButton(
              label: l.liveJoin,
              icon: LucideIcons.video,
              busy: _busy,
              onPressed: _busy || x.openUrl == null ? null : _joinLive,
            ),
          ] else ...[
            if (x.contentBody != null)
              DgPanel(
                child: Text(
                  x.contentBody!,
                  style: Dg.ui(size: 15, height: 1.5),
                ),
              ),
            if (x.openUrl != null) ...[
              const SizedBox(height: 12),
              DgGradientButton(
                label: l.trainingOpen,
                icon: _lessonIcon(x.contentType),
                onPressed: () => unawaited(_openUrl(x.openUrl!)),
              ),
            ],
            if (x.minimumViewSeconds > 0 && !x.completed) ...[
              const SizedBox(height: 8),
              Text(
                l.minViewHint((x.minimumViewSeconds / 60).ceil()),
                style: Dg.typeCaption(),
              ),
            ],
            if (!x.completed && !_done && !widget.port.preview) ...[
              const SizedBox(height: 12),
              DgButton(
                key: const Key('lesson-complete'),
                label: l.lessonComplete,
                icon: LucideIcons.check,
                tone: DgButtonTone.secondary,
                busy: _busy,
                onPressed: _busy ? null : _complete,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Sınav formu: tek ya da çok seçimli sorular. Puan sunucuda hesaplanır;
/// doğru cevap ve açıklama yalnız geçilince gelir.
class _QuizForm extends StatefulWidget {
  const _QuizForm({
    required this.quiz,
    required this.passingScore,
    required this.enabled,
    required this.onSubmit,
    required this.onPassed,
  });

  final TrainingQuiz quiz;
  final int? passingScore;
  final bool enabled;
  final Future<({QuizResult? result, String? error})> Function(
    Map<String, List<String>> answers,
  )
  onSubmit;
  final VoidCallback onPassed;

  @override
  State<_QuizForm> createState() => _QuizFormState();
}

class _QuizFormState extends State<_QuizForm> {
  final _picked = <String, Set<String>>{};
  QuizResult? _result;
  bool _busy = false;

  bool get _complete =>
      widget.quiz.questions.every((q) => (_picked[q.id] ?? {}).isNotEmpty);

  void _toggle(QuizQuestion q, String optionId) {
    if (_result != null) return;
    setState(() {
      final set = _picked.putIfAbsent(q.id, () => <String>{});
      if (q.multiple) {
        if (!set.remove(optionId)) set.add(optionId);
      } else {
        set
          ..clear()
          ..add(optionId);
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final out = await widget.onSubmit({
      for (final e in _picked.entries) e.key: e.value.toList(),
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = out.result;
    });
    if (out.error != null) _snack(context, out.error!);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final questions = widget.quiz.questions;
    if (questions.isEmpty) {
      return DgEmptyState(
        icon: LucideIcons.listChecks,
        title: l.quizUnavailable,
      );
    }
    final result = _result;
    final verdict = {
      for (final r in result?.results ?? const []) r.questionId: r,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (result != null) ...[
          Appear(
            child: DgPanel(
              child: Row(
                children: [
                  DgIconBadge(
                    icon: result.passed
                        ? LucideIcons.circleCheck
                        : LucideIcons.circleX,
                    tone: result.passed ? DgTone.ok : DgTone.bad,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.passed ? l.quizPassed : l.quizFailed,
                          style: Dg.ui(size: 16, weight: FontWeight.w700),
                        ),
                        Text(
                          l.quizScore(
                            result.score,
                            result.passingScore ?? widget.passingScore,
                          ),
                          style: Dg.typeCaption(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        for (final (i, q) in questions.indexed) ...[
          DgPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${i + 1}. ${q.text}',
                        style: Dg.ui(size: 15, weight: FontWeight.w600),
                      ),
                    ),
                    if (verdict[q.id] != null)
                      Icon(
                        verdict[q.id]!.correct
                            ? LucideIcons.circleCheck
                            : LucideIcons.circleX,
                        size: 18,
                        color: verdict[q.id]!.correct ? Dg.ok : Dg.bad,
                      ),
                  ],
                ),
                if (q.multiple)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(l.quizMultiple, style: Dg.typeCaption()),
                  ),
                const SizedBox(height: 6),
                for (final o in q.options)
                  _OptionTile(
                    text: o.text,
                    multiple: q.multiple,
                    selected: _picked[q.id]?.contains(o.id) ?? false,
                    onTap: widget.enabled ? () => _toggle(q, o.id) : null,
                  ),
                if (verdict[q.id]?.explanation != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      verdict[q.id]!.explanation!,
                      style: Dg.typeCaption(),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (widget.enabled)
          if (result != null && !result.passed)
            DgButton(
              label: l.quizRetry,
              icon: LucideIcons.rotateCcw,
              tone: DgButtonTone.secondary,
              onPressed: () => setState(() {
                _result = null;
                _picked.clear();
              }),
            )
          else if (result != null && result.passed)
            DgGradientButton(
              label: l.done,
              icon: LucideIcons.check,
              onPressed: widget.onPassed,
            )
          else
            DgGradientButton(
              key: const Key('quiz-submit'),
              label: l.quizSubmit,
              icon: LucideIcons.send,
              busy: _busy,
              onPressed: _busy || !_complete ? null : _submit,
            ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.text,
    required this.multiple,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool multiple;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              multiple
                  ? DgSelectBox(selected: selected, size: 20)
                  : AnimatedContainer(
                      duration: DgMotion.quick,
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Dg.action : Dg.stroke,
                          width: selected ? 6 : 1.6,
                        ),
                      ),
                    ),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: Dg.ui(size: 15))),
            ],
          ),
        ),
      ),
    );
  }
}
