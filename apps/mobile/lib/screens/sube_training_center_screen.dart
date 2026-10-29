import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/branch_models.dart';
import '../branch_workspace.dart';
import '../l10n.dart';
import '../motion.dart';
import '../session.dart';
import '../theme.dart';
import '../ui/ui.dart';
import '../widgets.dart';
import 'sube_manage_screens.dart';
import 'sube_widgets.dart';

String _date(DateTime at) {
  final t = at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}.${two(t.month)}.${t.year}';
}

/// Eğitim Merkezi (mockup 13): Şube / Kurye / Müşteri sekmeleri
/// (`targetType`), ilerleme özeti, tür süzgeci (Video / PDF / Canlı),
/// eğitim kartları ve SSS. Öğrenen eğitimi içerik açılır, cihazda ölçülen
/// süre bildirilip tamamlanır; en kısa izleme süresini sunucu denetler.
class SubeTrainingCenterScreen extends ConsumerStatefulWidget {
  const SubeTrainingCenterScreen({super.key});

  @override
  ConsumerState<SubeTrainingCenterScreen> createState() =>
      _SubeTrainingCenterScreenState();
}

class _SubeTrainingCenterScreenState
    extends ConsumerState<SubeTrainingCenterScreen> {
  static const _tabs = ['BRANCH', 'COURIER', 'CUSTOMER_PROCESS'];
  int _tab = 0;

  /// 0 tümü, 1 video, 2 PDF, 3 canlı (`lessonTypes` üzerinden).
  int _kind = 0;
  final _faq = <String, Future<List<TrainingFaq>>>{};

  BranchWorkspace get _branch => ref.read(sessionProvider).branch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => _branch.loadTrainingCenter(_tabs[_tab]);

  bool _kindMatch(LearnerTraining t) {
    final types = {...t.lessonTypes, t.primaryType};
    return switch (_kind) {
      1 => types.contains('VIDEO') || types.contains('EMBED'),
      2 => types.contains('PDF') || types.contains('DOCUMENT'),
      3 => types.contains('LIVE'),
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final branch = ref.watch(sessionProvider).branch;
    final type = _tabs[_tab];
    final data = branch.trainingTabs[type];
    final faq = _faq[type] ??= branch
        .trainingFaq(type)
        .catchError((Object _) => const <TrainingFaq>[]);
    return Scaffold(
      appBar: AppBar(title: Text(l.trainingCenterTitle)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            DgPillTabs(
              labels: [for (final t in _tabs) l.trainingTab(t)],
              index: _tab,
              onChanged: (i) {
                setState(() => _tab = i);
                _load();
              },
            ),
            const SizedBox(height: 12),
            SubeStatusBanner(branch: branch, onRetry: _load),
            if (data == null)
              branch.loading
                  ? const DgSkeleton(height: 120, radius: 16)
                  : const SizedBox.shrink()
            else if (type == 'COURIER')
              ..._courierTab(context, data)
            else ...[
              if (data.hasSummary) _Summary(data: data),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (i, label) in [
                    l.all,
                    l.trainingFilterVideo,
                    l.trainingFilterPdf,
                    l.trainingFilterLive,
                  ].indexed)
                    ChoiceChip(
                      label: Text(label),
                      selected: _kind == i,
                      onSelected: (_) => setState(() => _kind = i),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ..._learnerCards(context, data, type),
            ],
            const SizedBox(height: 16),
            _Faq(future: faq),
          ],
        ),
      ),
    );
  }

  List<Widget> _learnerCards(
    BuildContext context,
    TrainingCenterData data,
    String type,
  ) {
    final l = context.l10n;
    final list = [
      for (final t in data.learner)
        if (_kindMatch(t)) t,
    ];
    if (list.isEmpty) {
      return [
        DgEmptyState(
          icon: LucideIcons.graduationCap,
          title: l.trainingTabEmpty,
        ),
      ];
    }
    return [
      for (var i = 0; i < list.length; i++)
        StaggerIn(
          index: i,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TrainingCard(
              training: list[i],
              onTap: () => _open(list[i], type),
            ),
          ),
        ),
    ];
  }

  List<Widget> _courierTab(BuildContext context, TrainingCenterData data) {
    final l = context.l10n;
    return [
      if (data.managed.isEmpty)
        DgEmptyState(
          icon: LucideIcons.graduationCap,
          title: l.trainingTabEmpty,
        ),
      for (var i = 0; i < data.managed.length; i++)
        StaggerIn(
          index: i,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DgPanel(
              child: Row(
                children: [
                  const DgIconBadge(
                    icon: LucideIcons.graduationCap,
                    tone: DgTone.accent,
                    soft: true,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.managed[i].title,
                          style: Dg.ui(size: 15, weight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: data.managed[i].learners == 0
                                ? 0
                                : data.managed[i].completed /
                                      data.managed[i].learners,
                            minHeight: 5,
                            color: Dg.ok,
                            backgroundColor: Dg.hairline,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          l.trainingLearners(
                            data.managed[i].completed,
                            data.managed[i].learners,
                          ),
                          style: Dg.typeCaption(),
                        ),
                      ],
                    ),
                  ),
                  if (data.managed[i].mandatory)
                    DgStatusPill(
                      label: l.trainingMandatoryPill,
                      tone: DgTone.warn,
                      dense: true,
                    ),
                ],
              ),
            ),
          ),
        ),
      const SizedBox(height: 4),
      DgButton(
        label: l.trainingManage,
        icon: LucideIcons.settings2,
        tone: DgButtonTone.secondary,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SubeTrainingScreen()),
        ),
      ),
    ];
  }

  Future<void> _open(LearnerTraining training, String type) =>
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Dg.surface,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (ctx) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
          ),
          child: _TrainingSheet(training: training, targetType: type),
        ),
      );
}

class _Summary extends StatelessWidget {
  const _Summary({required this.data});

  final TrainingCenterData data;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final total = data.total;
    final progress = total == 0 ? 0.0 : data.completed / total;
    return DgPanel(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          FlowProgressRing(
            progress: progress,
            size: 84,
            track: Dg.hairline,
            child: Center(
              child: Text(
                '${(progress * 100).round()}%',
                style: Dg.stat(size: 18, weight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.trainingDoneOf(data.completed, total),
                  style: Dg.ui(size: 16, weight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                if (data.mandatoryPending > 0)
                  Text(
                    l.trainingMandatoryPending(data.mandatoryPending),
                    style: Dg.ui(size: 13, color: Dg.warn),
                  ),
                if (data.overdue > 0)
                  Text(
                    l.overdueCount(data.overdue),
                    style: Dg.ui(size: 13, color: Dg.bad),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingCard extends StatelessWidget {
  const _TrainingCard({required this.training, required this.onTap});

  final LearnerTraining training;
  final VoidCallback onTap;

  static IconData _icon(String type) => switch (type) {
    'VIDEO' || 'EMBED' => LucideIcons.circlePlay,
    'PDF' || 'DOCUMENT' => LucideIcons.fileText,
    'LIVE' => LucideIcons.radio,
    'QUIZ' => LucideIcons.listChecks,
    'LINK' => LucideIcons.link,
    _ => LucideIcons.bookOpen,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = training;
    final status = switch (t.status) {
      'COMPLETED' => DgTone.ok,
      'IN_PROGRESS' => DgTone.info,
      'EXPIRED' => DgTone.bad,
      _ => DgTone.neutral,
    };
    final minutes = t.durationSeconds == null
        ? null
        : (t.durationSeconds! / 60).ceil();
    return DgPanel(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: AspectRatio(
              aspectRatio: 16 / 7,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1B2A6B), Dg.navy],
                      ),
                    ),
                  ),
                  if (t.coverUrl != null)
                    Image.network(
                      t.coverUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  Center(
                    child: Icon(
                      _icon(t.primaryType),
                      size: 40,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  if (minutes != null)
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          l.trainingMinutes(minutes),
                          style: Dg.ui(
                            size: 14,
                            weight: FontWeight.w600,
                            color: Colors.white,
                          ).copyWith(fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title, style: Dg.ui(size: 16, weight: FontWeight.w700)),
                if (t.summary != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      t.summary!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Dg.typeCaption(),
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    DgStatusPill(
                      label: l.trainingStatus(t.status),
                      tone: status,
                      dense: true,
                    ),
                    if (t.mandatory)
                      DgStatusPill(
                        label: l.trainingMandatoryPill,
                        tone: DgTone.warn,
                        dense: true,
                      ),
                    if (t.overdue)
                      DgStatusPill(
                        label: l.filterLate,
                        tone: DgTone.bad,
                        dense: true,
                      ),
                    if (t.lessonCount > 1)
                      DgStatusPill(
                        label: l.trainingLessons(t.lessonCount),
                        tone: DgTone.neutral,
                        dense: true,
                      ),
                  ],
                ),
                if (t.progressPercent != null && !t.completed) ...[
                  const SizedBox(height: 10),
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
          ),
        ],
      ),
    );
  }
}

/// Eğitim detayı: açıklama, içerik (bağlantı ya da metin), tamamla.
class _TrainingSheet extends ConsumerStatefulWidget {
  const _TrainingSheet({required this.training, required this.targetType});

  final LearnerTraining training;
  final String targetType;

  @override
  ConsumerState<_TrainingSheet> createState() => _TrainingSheetState();
}

class _TrainingSheetState extends ConsumerState<_TrainingSheet> {
  late final Future<LearnerTraining?> _detail = ref
      .read(sessionProvider)
      .branch
      .trainingDetail(widget.training.id);
  DateTime? _openedAt;
  bool _showText = false;
  bool _busy = false;

  Future<void> _openContent(LearnerTraining t) async {
    _openedAt ??= DateTime.now();
    final url = t.contentUrl;
    if (url == null || url.isEmpty) {
      setState(() => _showText = true);
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _complete(LearnerTraining t) async {
    final l = context.l10n;
    setState(() => _busy = true);
    final seconds = _openedAt == null
        ? 0
        : DateTime.now().difference(_openedAt!).inSeconds;
    final error = await ref
        .read(sessionProvider)
        .branch
        .completeTraining(
          t,
          targetType: widget.targetType,
          viewedSeconds: seconds,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    subeSnack(context, error ?? l.trainingCompletedMsg);
    if (error == null) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return FutureBuilder<LearnerTraining?>(
      future: _detail,
      builder: (context, snap) {
        final t = snap.data ?? widget.training;
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(t.title, style: Dg.ui(size: 19, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                DgStatusPill(
                  label: l.trainingStatus(t.status),
                  tone: t.completed ? DgTone.ok : DgTone.info,
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
                    label: l.trainingDue(_date(t.dueAt!)),
                    tone: t.overdue ? DgTone.bad : DgTone.neutral,
                    dense: true,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (snap.connectionState != ConnectionState.done)
              const DgSkeleton(height: 80, radius: 12)
            else if (snap.hasError)
              Text(
                BranchWorkspace.describeError(snap.error!),
                style: Dg.ui(size: 14, color: Dg.bad),
              )
            else ...[
              if ((t.description ?? t.summary) != null)
                Text(
                  t.description ?? t.summary!,
                  style: Dg.ui(size: 15, color: Dg.text2),
                ),
              if (_showText && t.contentBody != null) ...[
                const SizedBox(height: 12),
                Appear(
                  child: DgPanel(
                    child: Text(t.contentBody!, style: Dg.ui(size: 15)),
                  ),
                ),
              ],
              if (_showText && t.contentBody == null && t.contentUrl == null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(l.trainingNoContent, style: Dg.typeCaption()),
                ),
              const SizedBox(height: 16),
              DgGradientButton(
                label: l.trainingOpen,
                icon: LucideIcons.circlePlay,
                onPressed: () => _openContent(t),
              ),
              if (!t.completed) ...[
                const SizedBox(height: 10),
                DgButton(
                  key: const Key('training-complete'),
                  label: l.trainingComplete,
                  icon: LucideIcons.check,
                  tone: DgButtonTone.secondary,
                  busy: _busy,
                  onPressed: _openedAt == null || _busy
                      ? null
                      : () => _complete(t),
                ),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _Faq extends StatelessWidget {
  const _Faq({required this.future});

  final Future<List<TrainingFaq>> future;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return FutureBuilder<List<TrainingFaq>>(
      future: future,
      builder: (context, snap) {
        final items = snap.data ?? const <TrainingFaq>[];
        if (items.isEmpty) return const SizedBox.shrink();
        return DgPanel(
          title: l.trainingFaqTitle,
          padding: const EdgeInsets.fromLTRB(14, 14, 6, 6),
          // ExpansionTile mürekkebi panelin rengine boyansın.
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                for (final f in items)
                  Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(
                        bottom: 10,
                        right: 8,
                      ),
                      expandedAlignment: Alignment.centerLeft,
                      title: Text(
                        f.question,
                        style: Dg.ui(size: 15, weight: FontWeight.w600),
                      ),
                      children: [Text(f.answer, style: Dg.typeCaption())],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
