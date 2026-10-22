import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/panel_models.dart';
import '../capture_check.dart';
import '../l10n.dart';
import '../local_image.dart';
import '../motion.dart';
import '../scan.dart';
import '../session.dart';
import '../theme.dart';
import '../visit_requirements.dart';
import '../widgets.dart';
import 'result_screen.dart';
import 'wizard_screen.dart';

enum _StepKind { reason, photo, form }

class _Step {
  const _Step(this.kind, [this.photo]);
  final _StepKind kind;
  final PhotoRequirement? photo;
}

/// Bir fotoğraf gereksiniminin çekim durumu.
class _Shot {
  _Shot(this.uploaded);

  /// Sunucuya ulaşmış fotoğraf sayısı.
  int uploaded;
  String? path;
  CaptureQuality? quality;
  String? overrideReason;
  final checked = <int>{};

  void clear() {
    path = null;
    quality = null;
    overrideReason = null;
    checked.clear();
  }
}

/// Sunucudan gelen gereksinimlerle adım adım ziyaret kapatma: her fotoğraf
/// kontrol listesiyle, ardından anket. "Yapamadım" yolunda önce neden seçilir.
class VisitFlowScreen extends ConsumerStatefulWidget {
  const VisitFlowScreen({
    super.key,
    required this.taskId,
    this.startFailed = false,
  });

  final String taskId;

  /// "Olmadı / teslim edilemedi" girişlerinden açılınca doğrudan neden adımı.
  final bool startFailed;

  @override
  ConsumerState<VisitFlowScreen> createState() => _VisitFlowScreenState();
}

class _VisitFlowScreenState extends ConsumerState<VisitFlowScreen> {
  bool failed = false;
  int step = 0;
  bool busy = false;
  bool done = false;
  String? error;

  List<({String code, String name})>? reasons;
  String? reasonCode;
  final note = TextEditingController();

  final shots = <String, _Shot>{};
  final values = <String, Object?>{};
  final texts = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    if (widget.startFailed) {
      failed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadReasons());
    }
  }

  @override
  void dispose() {
    note.dispose();
    for (final c in texts.values) {
      c.dispose();
    }
    super.dispose();
  }

  VisitRequirements get req =>
      ref.read(sessionProvider).visitRequirements(widget.taskId) ??
      const VisitRequirements();

  List<_Step> get steps => [
    if (failed) const _Step(_StepKind.reason),
    for (final p in req.photosFor(delivered: !failed))
      _Step(_StepKind.photo, p),
    // Gönderilmiş anket değiştirilemez; yeniden sorulmaz.
    if (_askForm) const _Step(_StepKind.form),
  ];

  bool get _askForm => req.formNeeded(delivered: !failed) && !req.formSubmitted;

  _Shot _shot(PhotoRequirement p) =>
      shots.putIfAbsent(p.code, () => _Shot(req.uploaded[p.code] ?? 0));

  Future<void> _loadReasons() async {
    try {
      final rows = await ref
          .read(sessionProvider)
          .visitFailReasons(widget.taskId);
      if (mounted) setState(() => reasons = rows);
    } catch (_) {
      if (mounted) setState(() => reasons = const []);
    }
  }

  void _switchMode() {
    setState(() {
      failed = !failed;
      step = 0;
      error = null;
    });
    if (failed && reasons == null) _loadReasons();
  }

  void _back() {
    if (step > 0) {
      setState(() {
        step -= 1;
        error = null;
      });
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _capture(PhotoRequirement p) async {
    final path = await capturePhoto();
    if (path == null || !mounted) return;
    final shot = _shot(p);
    setState(() {
      shot.clear();
      shot.path = path;
      error = null;
    });
    final quality = await gradePhotoFile(path);
    if (mounted && shot.path == path) setState(() => shot.quality = quality);
  }

  String _errorText(L10n l, Object e) {
    if (e is PanelApiException) {
      if (e.statusCode == null && e.code == 'PANEL_REQUEST_FAILED') {
        return l.visitOffline;
      }
      return l.visitError(
        e.code,
        missing: e.missing,
        serverMessage: e.serverMessage,
      );
    }
    return l.visitError('');
  }

  /// Adımı doğrular; fotoğraf adımında yüklemeyi de yapar. Hata metni döner.
  Future<String?> _completeStep(L10n l, _Step current) async {
    final s = ref.read(sessionProvider);
    switch (current.kind) {
      case _StepKind.reason:
        final code = reasonCode;
        if (code == null) return l.visitPickReason;
        final name = reasons!.firstWhere((r) => r.code == code).name;
        final form = req.form;
        if (form != null) values.addAll(form.prefillForReason(name));
        return null;
      case _StepKind.photo:
        final p = current.photo!;
        final shot = _shot(p);
        if (shot.path == null) {
          return shot.uploaded >= p.minCount ? null : l.visitPhotoNeeded;
        }
        final q = shot.quality;
        if (q != null && !q.ok && shot.overrideReason == null) {
          return l.visitOverrideNeeded;
        }
        if (shot.checked.length < p.checklist.length) {
          return l.visitChecklistNeeded;
        }
        if (!s.online) return l.visitOffline;
        try {
          final id = await s.uploadVisitPhoto(
            widget.taskId,
            path: shot.path,
            requirement: p,
            quality: q,
            overrideReason: shot.overrideReason,
          );
          if (id == null) return l.visitUploadFailed;
        } catch (e) {
          return e is PanelApiException && e.code == 'PHOTO_UNAVAILABLE'
              ? l.visitPhotoUnavailable
              : e is PanelApiException && e.statusCode != null
              ? _errorText(l, e)
              : l.visitUploadFailed;
        }
        shot.uploaded += 1;
        shot.clear();
        // Birden çok fotoğraf isteniyorsa aynı adımda kalınır.
        return shot.uploaded < p.minCount ? '' : null;
      case _StepKind.form:
        final form = req.form!;
        for (final e in texts.entries) {
          final f = form.fields.firstWhere((f) => f.code == e.key);
          final raw = e.value.text.trim();
          values[e.key] = f.type == 'NUMBER'
              ? num.tryParse(raw.replaceAll(',', '.'))
              : raw;
        }
        return form.missing(values, everyQuestion: !failed).isEmpty
            ? null
            : l.visitSurveyMissing;
    }
  }

  Future<void> _next() async {
    final l = context.l10n;
    final all = steps;
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    String? problem;
    if (all.isNotEmpty) problem = await _completeStep(l, all[step]);
    if (!mounted) return;
    if (problem != null) {
      setState(() {
        busy = false;
        error = problem!.isEmpty ? null : problem;
      });
      return;
    }
    if (step < all.length - 1) {
      setState(() {
        busy = false;
        step += 1;
      });
      return;
    }
    final s = ref.read(sessionProvider);
    if (!s.online) {
      setState(() {
        busy = false;
        error = l.visitOffline;
      });
      return;
    }
    try {
      await s.finalizeVisit(
        widget.taskId,
        delivered: !failed,
        reasonCode: failed ? reasonCode : null,
        note: note.text.trim(),
        form: _askForm ? req.form : null,
        formValues: values,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        error = _errorText(l, e);
      });
      return;
    }
    if (mounted) {
      setState(() {
        busy = false;
        done = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final l = context.l10n;
    final task = s.taskOrNull(widget.taskId);
    if (task == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.stopGone)),
      );
    }
    if (done) {
      return DeliveryResultScreen(
        success: !failed,
        task: task,
        online: s.online,
        next: s.nextStop,
        onClose: () => Navigator.popUntil(context, (r) => r.isFirst),
        onNext: () {
          final n = ref.read(sessionProvider).nextStop;
          Navigator.popUntil(context, (r) => r.isFirst);
          if (n == null) return;
          final nav = Navigator.of(context);
          final messenger = ScaffoldMessenger.of(context);
          final warn = context.l10n.startNeedsLocation;
          ref.read(sessionProvider).startTask(n.id).then((ok) {
            if (!ok) {
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(warn)));
              return;
            }
            nav.push(
              MaterialPageRoute<void>(
                builder: (_) => WizardScreen(taskId: n.id),
              ),
            );
          });
        },
      );
    }

    final all = steps;
    if (step >= all.length) step = all.isEmpty ? 0 : all.length - 1;
    final current = all.isEmpty ? null : all[step];
    final last = step >= all.length - 1;
    final title = switch (current?.kind) {
      _StepKind.reason => l.visitWhyTitle,
      _StepKind.photo => current!.photo!.label,
      _StepKind.form => req.form?.title ?? '',
      null => task.recipient,
    };

    return PopScope(
      canPop: step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _back),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                all.length > 1
                    ? '${l.stepOf(step + 1, all.length)}  ·  ${task.recipient}'
                    : task.recipient,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Dg.ink3,
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            if (all.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    for (var i = 0; i < all.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: i <= step ? Dg.primaryGradient : null,
                            color: i <= step ? null : Dg.elev,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            Expanded(
              child: ListView(
                key: ValueKey('visit-$failed-$step'),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  if (current?.kind == _StepKind.reason) ..._reasonStep(l),
                  if (current?.kind == _StepKind.photo)
                    ..._photoStep(l, current!.photo!),
                  if (current?.kind == _StepKind.form) ..._formStep(l),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: ShakeError(
                        trigger: error,
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Dg.hi,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Material(
              color: Dg.surface,
              elevation: 8,
              shadowColor: const Color(0x1412191A),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Column(
                    children: [
                      DgButton(
                        label: last ? l.visitSend : l.continueLabel,
                        trailing: last
                            ? LucideIcons.send
                            : LucideIcons.arrowRight,
                        tone: failed && last
                            ? DgButtonTone.danger
                            : DgButtonTone.primary,
                        busy: busy,
                        onPressed: _next,
                      ),
                      TextButton(
                        onPressed: busy ? null : _switchMode,
                        child: Text(
                          failed ? l.visitBackToDone : l.visitCouldNot,
                          style: TextStyle(
                            color: failed ? Dg.ink2 : Dg.hi,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _choice({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: DgChoiceSurface(
      selected: selected,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Dg.ui(size: 16, weight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 10),
            DgSelectMark(selected: selected),
          ],
        ),
      ),
    ),
  );

  List<Widget> _reasonStep(L10n l) {
    final rows = reasons;
    return [
      if (rows == null)
        const Padding(
          padding: EdgeInsets.only(top: 32),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (rows.isEmpty) ...[
        Text(l.visitNoReasons, style: Dg.ui(size: 15, color: Dg.ink2)),
        const SizedBox(height: 12),
        DgButton(
          label: l.retryNow,
          tone: DgButtonTone.secondary,
          onPressed: () {
            setState(() => reasons = null);
            _loadReasons();
          },
        ),
      ] else ...[
        for (final r in rows)
          _choice(
            label: r.name,
            selected: reasonCode == r.code,
            onTap: () => setState(() {
              reasonCode = r.code;
              error = null;
            }),
          ),
        const SizedBox(height: 8),
        TextField(
          controller: note,
          minLines: 2,
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(hintText: l.visitNoteHint),
        ),
      ],
    ];
  }

  List<Widget> _photoStep(L10n l, PhotoRequirement p) {
    final shot = _shot(p);
    final path = shot.path;
    final q = shot.quality;
    final real = path != null && !path.startsWith('test://');
    final enough = shot.uploaded >= p.minCount;
    return [
      if (p.hint != null && p.hint!.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(p.hint!, style: Dg.ui(size: 15, color: Dg.ink2)),
        ),
      if (p.minCount > 1)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Mono(
            l.visitPhotoCount(
              (shot.uploaded + 1).clamp(1, p.minCount),
              p.minCount,
            ),
            size: 13,
            color: Dg.ink3,
          ),
        ),
      ClipRRect(
        borderRadius: BorderRadius.circular(Dg.radius),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Material(
            color: Dg.elev,
            child: InkWell(
              onTap: busy ? null : () => _capture(p),
              child: real
                  ? localImage(path, fit: BoxFit.cover)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DgIcon(
                          path != null || (enough && path == null)
                              ? LucideIcons.circleCheck
                              : LucideIcons.camera,
                          size: 36,
                          color: path != null || enough ? Dg.sage : Dg.ink2,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          path != null || enough
                              ? l.visitPhotoReady
                              : l.visitTakePhoto,
                          style: Dg.ui(size: 16, weight: FontWeight.w600),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
      if (path != null || enough)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: busy ? null : () => _capture(p),
            child: Text(l.retake),
          ),
        ),
      if (path != null && q != null && !q.ok) ...[
        const SizedBox(height: 4),
        Text(
          l.visitQuality(q.quality),
          style: Dg.ui(size: 16, weight: FontWeight.w700, color: Dg.hi),
        ),
        const SizedBox(height: 4),
        Text(l.visitQualityAsk, style: Dg.ui(size: 14, color: Dg.ink2)),
        const SizedBox(height: 10),
        for (final code in captureOverrideReasons)
          _choice(
            label: l.visitOverride(code),
            selected: shot.overrideReason == code,
            onTap: () => setState(() {
              shot.overrideReason = code;
              error = null;
            }),
          ),
      ],
      if (path != null && p.checklist.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(
          l.visitChecklistTitle,
          style: Dg.ui(size: 14, weight: FontWeight.w600, color: Dg.ink2),
        ),
        const SizedBox(height: 10),
        for (final (i, item) in p.checklist.indexed)
          _choice(
            label: item,
            selected: shot.checked.contains(i),
            onTap: () => setState(() {
              if (!shot.checked.remove(i)) shot.checked.add(i);
              error = null;
            }),
          ),
      ],
    ];
  }

  List<Widget> _formStep(L10n l) {
    final form = req.form!;
    final out = <Widget>[];
    final hint = form.instructions;
    if (hint != null && hint.isNotEmpty) {
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(hint, style: Dg.ui(size: 14, color: Dg.ink2)),
        ),
      );
    }
    for (final f in form.visibleFields(values)) {
      final required =
          form.isRequired(f, values) || (!failed && f.type != 'STRING');
      out.add(
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  f.label,
                  style: Dg.ui(size: 16, weight: FontWeight.w700),
                ),
              ),
              if (required)
                Text(
                  l.visitRequired,
                  style: Dg.ui(
                    size: 12,
                    weight: FontWeight.w600,
                    color: Dg.mid,
                  ),
                ),
            ],
          ),
        ),
      );
      out.addAll(_field(l, f));
      out.add(const SizedBox(height: 10));
    }
    return out;
  }

  void _set(String code, Object? value) => setState(() {
    values[code] = value;
    error = null;
  });

  List<Widget> _field(L10n l, VisitFormField f) {
    final v = values[f.code];
    switch (f.type) {
      case 'BOOLEAN':
        return [
          Row(
            children: [
              for (final (label, value) in [
                (l.visitYes, true),
                (l.visitNo, false),
              ]) ...[
                if (!value) const SizedBox(width: 8),
                Expanded(
                  child: DgChoiceSurface(
                    selected: v == value,
                    onTap: () => _set(f.code, value),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: Text(
                          label,
                          style: Dg.ui(size: 16, weight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ];
      case 'CODE':
        return [
          for (final o in f.options)
            _choice(
              label: o.label,
              selected: f.isMultiValue
                  ? (v is List && v.contains(o.code))
                  : v == o.code,
              onTap: () {
                if (!f.isMultiValue) return _set(f.code, o.code);
                final list = [...(v is List ? v : const [])];
                if (!list.remove(o.code)) list.add(o.code);
                _set(f.code, list);
              },
            ),
        ];
      case 'DATE':
      case 'TIMESTAMP':
        return [
          DgButton(
            label: v is String && v.length >= 10
                ? v.substring(0, 10).split('-').reversed.join('.')
                : l.visitPickDate,
            icon: LucideIcons.calendar,
            tone: DgButtonTone.secondary,
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: now,
                firstDate: DateTime(now.year - 5),
                lastDate: DateTime(now.year + 5),
              );
              if (picked == null) return;
              String two(int n) => n.toString().padLeft(2, '0');
              final day =
                  '${picked.year}-${two(picked.month)}-${two(picked.day)}';
              _set(
                f.code,
                f.type == 'DATE'
                    ? day
                    : DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        now.hour,
                        now.minute,
                      ).toUtc().toIso8601String(),
              );
            },
          ),
        ];
      default:
        final c = texts.putIfAbsent(
          f.code,
          () => TextEditingController(text: v == null ? '' : '$v'),
        );
        return [
          TextField(
            controller: c,
            keyboardType: f.type == 'NUMBER'
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            minLines: 1,
            maxLines: f.type == 'NUMBER' ? 1 : 4,
            decoration: InputDecoration(hintText: f.description),
          ),
        ];
    }
  }
}
