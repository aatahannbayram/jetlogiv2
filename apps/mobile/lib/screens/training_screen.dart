import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/branch_models.dart' show TrainingFaq;
import '../l10n.dart';
import '../motion.dart';
import '../session.dart';
import '../theme.dart';
import '../training_port.dart';
import '../widgets.dart';
import 'training_detail_screen.dart';

/// Eğitim modülü — toplantı maddesi 5. MVP: metin/checklist içerik, video
/// barındırma yok (bkz. apps/api/src/routes/training.ts).
class TrainingScreen extends ConsumerStatefulWidget {
  const TrainingScreen({super.key});

  @override
  ConsumerState<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends ConsumerState<TrainingScreen> {
  /// Eğitim Merkezi SSS (yalnız gerçek kurye oturumunda).
  Future<List<TrainingFaq>>? _faq;

  @override
  void initState() {
    super.initState();
    final s = ref.read(sessionProvider);
    final panel = s.panel;
    if (trainingPlayerEnabled && s.panelLoggedIn && !s.demo && panel != null) {
      _faq = panel.fetchTrainingFaq().catchError(
        (Object _) => const <TrainingFaq>[],
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionProvider).loadTrainingModules();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);
    final modules = s.trainingModules;

    return Scaffold(
      appBar: AppBar(title: Text(l.trainingTitle)),
      body: modules.isEmpty
          ? Center(
              child: Text(
                l.trainingEmpty,
                style: Dg.ui(size: 15, color: Dg.ink3),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                for (final (i, module) in modules.indexed)
                  StaggerIn(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: DgCard(
                        onTap: () {
                          s.loadTrainingBody(module.id);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  TrainingDetailScreen(moduleId: module.id),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            DgIconChip(
                              icon: module.completed
                                  ? LucideIcons.circleCheck
                                  : LucideIcons.graduationCap,
                              accent: !module.completed,
                              // Dolu renkli daire, beyaz ikon (şube gibi).
                              color: Colors.white,
                              background: module.completed ? Dg.ok : Dg.warn,
                              size: 40,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    module.title,
                                    style: Dg.ui(
                                      size: 15,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                  if (module.summary != null &&
                                      module.summary!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      module.summary!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Dg.ui(size: 12, color: Dg.ink3),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            DgIcon(
                              LucideIcons.chevronRight,
                              size: 18,
                              color: Dg.ink3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_faq != null) _CourierFaq(future: _faq!),
              ],
            ),
    );
  }
}

class _CourierFaq extends StatelessWidget {
  const _CourierFaq({required this.future});

  final Future<List<TrainingFaq>> future;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return FutureBuilder<List<TrainingFaq>>(
      future: future,
      builder: (context, snap) {
        final items = snap.data ?? const <TrainingFaq>[];
        if (items.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: DgCard(
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.trainingFaqTitle,
                    style: Dg.ui(size: 15, weight: FontWeight.w700),
                  ),
                  for (final f in items)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 10),
                      expandedAlignment: Alignment.centerLeft,
                      shape: const Border(),
                      title: Text(
                        f.question,
                        style: Dg.ui(size: 14, weight: FontWeight.w600),
                      ),
                      children: [
                        Text(f.answer, style: Dg.ui(size: 13, color: Dg.ink2)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
