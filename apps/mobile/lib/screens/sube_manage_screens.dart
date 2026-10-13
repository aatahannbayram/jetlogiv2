import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'sube_more_screens.dart';
import 'sube_widgets.dart';

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
            for (final t in items ?? const [])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DgCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.title,
                              style: Dg.ui(size: 15, weight: FontWeight.w600),
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
                ),
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
                      StatusChip(
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
