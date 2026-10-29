import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/branch_models.dart';
import '../l10n.dart';
import '../session.dart';
import '../theme.dart';
import '../training_port.dart';
import '../widgets.dart';
import 'sube_more_screens.dart';
import 'sube_widgets.dart';
import 'training_player_screen.dart';

/// Başlık + metin (+ bir onay kutusu) isteyen alt sayfa. İptalde null döner.
Future<({String title, String body, bool flag})?> showSubeComposeSheet(
  BuildContext context, {
  required String heading,
  required String titleHint,
  required String bodyHint,
  required String flagLabel,
  required String submitLabel,
}) {
  final title = TextEditingController();
  final body = TextEditingController();
  var flag = false;
  return showModalBottomSheet<({String title, String body, bool flag})>(
    context: context,
    backgroundColor: Dg.surface,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          16 + MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(heading, style: Dg.ui(size: 17, weight: FontWeight.w700)),
            TextField(
              controller: title,
              maxLength: 120,
              decoration: InputDecoration(hintText: titleHint),
            ),
            TextField(
              controller: body,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(hintText: bodyHint),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: flag,
              onChanged: (v) => setState(() => flag = v ?? false),
              title: Text(flagLabel, style: Dg.ui(size: 14)),
            ),
            DgButton(
              label: submitLabel,
              onPressed: () => Navigator.pop(ctx, (
                title: title.text,
                body: body.text,
                flag: flag,
              )),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Şubenin kuryeleri için eğitimler: tamamlanma durumu ve yeni metin eğitimi.
class SubeTrainingScreen extends ConsumerStatefulWidget {
  const SubeTrainingScreen({super.key});

  @override
  ConsumerState<SubeTrainingScreen> createState() => _SubeTrainingScreenState();
}

class _SubeTrainingScreenState extends ConsumerState<SubeTrainingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionProvider).branch.loadTrainings();
    });
  }

  Future<void> _create() async {
    final l = context.l10n;
    final input = await showSubeComposeSheet(
      context,
      heading: l.newTraining,
      titleHint: l.announceTitle,
      bodyHint: l.trainingContent,
      flagLabel: l.trainingMandatory,
      submitLabel: l.publish,
    );
    if (input == null || !mounted) return;
    final error = await ref
        .read(sessionProvider)
        .branch
        .createTraining(
          title: input.title,
          body: input.body,
          mandatory: input.flag,
        );
    if (mounted) subeSnack(context, error ?? l.trainingCreated);
  }

  Future<void> _preview(ManagedTraining t) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TrainingPlayerScreen(
        port: BranchTrainingPort(
          ref.read(sessionProvider).branch,
          targetType: 'COURIER',
          preview: true,
        ),
        trainingId: t.id,
        title: t.title,
      ),
    ),
  );

  /// Düzenleme: mevcut metin önizleme ucundan okunur, form doldurulur.
  Future<void> _edit(ManagedTraining t) async {
    final l = context.l10n;
    final branch = ref.read(sessionProvider).branch;
    LearnerTraining? current;
    try {
      current = await branch.trainingPreview(t.id);
    } catch (_) {
      current = null;
    }
    if (!mounted) return;
    final input = await showModalBottomSheet<_TrainingEdit>(
      context: context,
      backgroundColor: Dg.surface,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TrainingEditSheet(
        title: current?.title ?? t.title,
        body: current?.contentBody ?? '',
        mandatory: t.mandatory,
      ),
    );
    if (input == null || !mounted || input.title.isEmpty) return;
    final error = await branch.updateTraining(
      t.id,
      title: input.title,
      body: input.body,
      mandatory: input.mandatory,
      bumpVersion: input.bump,
    );
    if (mounted) subeSnack(context, error ?? l.trainingUpdated);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final branch = ref.watch(sessionProvider).branch;
    final items = branch.trainings;
    return Scaffold(
      appBar: AppBar(title: Text(l.subeTrainingTitle)),
      body: RefreshIndicator(
        onRefresh: branch.loadTrainings,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            SubeStatusBanner(branch: branch, onRetry: branch.loadTrainings),
            if (branch.capabilities.manage) ...[
              DgButton(
                label: l.newTraining,
                icon: LucideIcons.plus,
                onPressed: _create,
              ),
              const SizedBox(height: 16),
            ],
            if (items == null && branch.loading)
              const Center(child: CircularProgressIndicator()),
            if (items != null && items.isEmpty)
              DgEmptyState(
                icon: LucideIcons.graduationCap,
                title: l.trainingEmpty,
              ),
            for (final t in items ?? const <ManagedTraining>[])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DgCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.title,
                                  style: Dg.ui(
                                    size: 15,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  l.trainingProgress(t.completed, t.learners),
                                  style: Dg.ui(size: 12, color: Dg.ink3),
                                ),
                              ],
                            ),
                          ),
                          if (t.mandatory)
                            StatusChip(label: l.mandatoryLabel, tone: 'mid'),
                        ],
                      ),
                      // Dar ekranda ve büyük yazıda alt satıra geçer.
                      if (trainingPlayerEnabled)
                        Wrap(
                          children: [
                            TextButton.icon(
                              onPressed: () => _preview(t),
                              icon: const Icon(LucideIcons.eye, size: 16),
                              label: Text(l.trainingPreview),
                            ),
                            if (t.editable && branch.capabilities.manage)
                              TextButton.icon(
                                key: Key('training-edit-${t.id}'),
                                onPressed: () => _edit(t),
                                icon: const Icon(LucideIcons.pencil, size: 16),
                                label: Text(l.trainingEdit),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

typedef _TrainingEdit = ({
  String title,
  String body,
  bool mandatory,
  bool bump,
});

/// Eğitim düzenleme formu. Metin denetleyicileri sayfa kapanma animasyonu
/// bitene kadar yaşar; sayfa kendi denetleyicilerini kendisi atar.
class _TrainingEditSheet extends StatefulWidget {
  const _TrainingEditSheet({
    required this.title,
    required this.body,
    required this.mandatory,
  });

  final String title;
  final String body;
  final bool mandatory;

  @override
  State<_TrainingEditSheet> createState() => _TrainingEditSheetState();
}

class _TrainingEditSheetState extends State<_TrainingEditSheet> {
  late final _title = TextEditingController(text: widget.title);
  late final _body = TextEditingController(text: widget.body);
  late bool _mandatory = widget.mandatory;
  bool _bump = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.trainingEdit,
              style: Dg.ui(size: 17, weight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _title,
              maxLength: 200,
              decoration: InputDecoration(hintText: l.announceTitle),
            ),
            TextField(
              controller: _body,
              minLines: 3,
              maxLines: 8,
              decoration: InputDecoration(hintText: l.trainingContent),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _mandatory,
              onChanged: (v) => setState(() => _mandatory = v),
              title: Text(l.trainingMandatory),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _bump,
              onChanged: (v) => setState(() => _bump = v),
              title: Text(l.trainingBumpVersion),
            ),
            const SizedBox(height: 8),
            DgButton(
              label: l.availabilitySave,
              onPressed: () => Navigator.pop<_TrainingEdit>(context, (
                title: _title.text.trim(),
                body: _body.text.trim(),
                mandatory: _mandatory,
                bump: _bump,
              )),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kuryelerin evrak ve sahaya hazır olma durumu.
class SubeComplianceScreen extends ConsumerStatefulWidget {
  const SubeComplianceScreen({super.key});

  @override
  ConsumerState<SubeComplianceScreen> createState() =>
      _SubeComplianceScreenState();
}

class _SubeComplianceScreenState extends ConsumerState<SubeComplianceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionProvider).branch.loadCompliance();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final branch = ref.watch(sessionProvider).branch;
    final items = branch.compliance;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.subeComplianceTitle),
        actions: branch.demo
            ? null
            : [
                IconButton(
                  icon: const Icon(LucideIcons.qrCode),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SubeCardsScreen(),
                    ),
                  ),
                ),
              ],
      ),
      body: RefreshIndicator(
        onRefresh: branch.loadCompliance,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            SubeStatusBanner(branch: branch, onRetry: branch.loadCompliance),
            if (items == null && branch.loading)
              const Center(child: CircularProgressIndicator()),
            if (items != null && items.isEmpty)
              DgEmptyState(icon: LucideIcons.users, title: l.emptyCouriers),
            for (final c in items ?? const [])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DgCard(
                  child: Row(
                    children: [
                      InitialsAvatar(name: c.name, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: Dg.ui(size: 15, weight: FontWeight.w600),
                            ),
                            if (c.operationReady)
                              Text(
                                l.operationReady,
                                style: Dg.ui(size: 12, color: Dg.ink3),
                              ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: StatusChip(
                          label: switch (c.documentStatus) {
                            'COMPLETE' => l.docsComplete,
                            'IN_REVIEW' => l.docsInReview,
                            'MISSING' => l.docsMissing(c.missing),
                            _ => l.docsNoPackage,
                          },
                          tone: switch (c.documentStatus) {
                            'COMPLETE' => 'lo',
                            'IN_REVIEW' => 'mid',
                            _ => 'hi',
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
