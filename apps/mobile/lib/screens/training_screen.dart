import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../motion.dart';
import '../session.dart';
import '../theme.dart';
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
  @override
  void initState() {
    super.initState();
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
              child: Text(l.trainingEmpty, style: Dg.ui(size: 15, color: Dg.ink3)),
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
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                TrainingDetailScreen(moduleId: module.id),
                          ),
                        ),
                        child: Row(
                          children: [
                            DgIconChip(
                              icon: module.completed
                                  ? LucideIcons.circleCheck
                                  : LucideIcons.graduationCap,
                              accent: !module.completed,
                              color: module.completed ? Dg.ok : Dg.warn,
                              background: module.completed
                                  ? Dg.ok.withValues(alpha: 0.12)
                                  : Dg.warnSoft,
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
              ],
            ),
    );
  }
}
