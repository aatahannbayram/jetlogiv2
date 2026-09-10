import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../l10n.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

class TrainingDetailScreen extends ConsumerWidget {
  const TrainingDetailScreen({super.key, required this.moduleId});

  final String moduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);
    final module = s.trainingModules.firstWhere(
      (m) => m.id == moduleId,
      orElse: () => const TrainingModuleDto(
        id: '',
        title: '',
        body: '',
        sortOrder: 0,
        completed: false,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(module.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (module.summary != null && module.summary!.isNotEmpty) ...[
            Text(
              module.summary!,
              style: Dg.ui(size: 14, color: Dg.ink2),
            ),
            const SizedBox(height: 16),
          ],
          DgCard(
            child: Text(
              module.body,
              style: Dg.ui(size: 15, color: Dg.ink, height: 1.5),
            ),
          ),
          const SizedBox(height: 20),
          if (module.completed)
            DgCard(
              child: Row(
                children: [
                  DgIcon(LucideIcons.circleCheck, size: 20, color: Dg.ok, weight: 600),
                  const SizedBox(width: 10),
                  Text(
                    l.trainingCompleted,
                    style: Dg.ui(size: 14, weight: FontWeight.w600, color: Dg.lo),
                  ),
                ],
              ),
            )
          else
            DgButton(
              label: l.trainingMarkComplete,
              icon: LucideIcons.check,
              tone: DgButtonTone.brand,
              onPressed: () => s.completeTrainingModule(moduleId),
            ),
        ],
      ),
    );
  }
}
