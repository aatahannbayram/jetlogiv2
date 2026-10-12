import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

class EodScreen extends ConsumerWidget {
  const EodScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);
    final pending = s.outbox.events.where((e) => e.pending).length;
    final c = s.courierCounts;
    // Backend sayaçları varsa onlar; yoksa cihazdaki görev listesinden.
    final kpis = <(String, String)>[
      if (c.isEmpty) ...[
        (l.eodOpen, '${s.openCount}'),
        (l.eodReturn, '${s.returnCount}'),
      ] else ...[
        (
          l.kpiOnMe,
          '${(c['awaitingDelivery'] ?? 0) + (c['outForDelivery'] ?? 0)}',
        ),
        (l.kpiInField, '${c['outForDelivery'] ?? 0}'),
        (l.kpiDelivered, '${c['deliveredToday'] ?? 0}'),
        (l.kpiUndelivered, '${c['failedToday'] ?? 0}'),
        (l.filterBooked, '${c['appointment'] ?? 0}'),
        (l.kpiSlaRisk, '${c['overdue'] ?? 0}'),
        (l.eodReturn, '${c['toReturnToBranch'] ?? 0}'),
        (l.kpiAwaitAccept, '${c['pendingCustody'] ?? 0}'),
      ],
      (l.eodSync, '$pending'),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.eodTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (s.pendingMandatoryTrainings > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DgCard(
                child: Text(
                  l.mandatoryTrainingPending(s.pendingMandatoryTrainings),
                  style: Dg.ui(size: 14, color: Dg.mid),
                ),
              ),
            ),
          for (var i = 0; i < kpis.length; i += 2) ...[
            Row(
              children: [
                StatTile(label: kpis[i].$1, value: kpis[i].$2),
                const SizedBox(width: 12),
                if (i + 1 < kpis.length)
                  StatTile(label: kpis[i + 1].$1, value: kpis[i + 1].$2)
                else
                  const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
          if (s.mockLocationDetected)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                l.mockLocationWarning,
                style: Dg.ui(size: 13, color: Dg.hi),
              ),
            ),
          if (s.shiftOpen) ...[
            DgButton(
              label: s.onBreak ? l.breakEnd : l.breakStart,
              icon: s.onBreak ? LucideIcons.play : LucideIcons.coffee,
              tone: DgButtonTone.secondary,
              onPressed: () async {
                final error = await s.toggleBreak();
                if (error != null && context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(error)));
                }
              },
            ),
            const SizedBox(height: 8),
          ],
          DgButton(
            label: l.eodClose,
            icon: LucideIcons.moon,
            onPressed: s.shiftOpen
                ? () async {
                    final ok = await confirmEndShift(context);
                    if (!ok || !context.mounted) return;
                    // Bekleyen kayıt varken vardiya kapanmaz.
                    final blocked = await s.closeShiftChecked();
                    if (!context.mounted) return;
                    if (blocked != null) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(blocked)));
                      return;
                    }
                    Navigator.of(context).pop();
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
