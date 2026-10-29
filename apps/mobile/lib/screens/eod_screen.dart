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
    final kpis = <(String, String, IconData, Color)>[
      if (c.isEmpty) ...[
        (l.eodOpen, '${s.openCount}', LucideIcons.package, Dg.brand),
        (l.eodReturn, '${s.returnCount}', LucideIcons.undo2, Dg.warn),
      ] else ...[
        (
          l.kpiOnMe,
          '${(c['awaitingDelivery'] ?? 0) + (c['outForDelivery'] ?? 0)}',
          LucideIcons.package,
          Dg.brand,
        ),
        (
          l.kpiInField,
          '${c['outForDelivery'] ?? 0}',
          LucideIcons.truck,
          Dg.plum,
        ),
        (
          l.kpiDelivered,
          '${c['deliveredToday'] ?? 0}',
          LucideIcons.circleCheck,
          Dg.ok,
        ),
        (
          l.kpiUndelivered,
          '${c['failedToday'] ?? 0}',
          LucideIcons.circleX,
          Dg.bad,
        ),
        (
          l.filterBooked,
          '${c['appointment'] ?? 0}',
          LucideIcons.calendarClock,
          Dg.brand,
        ),
        (l.kpiSlaRisk, '${c['overdue'] ?? 0}', LucideIcons.timer, Dg.warn),
        (
          l.eodReturn,
          '${c['toReturnToBranch'] ?? 0}',
          LucideIcons.undo2,
          Dg.warn,
        ),
        (
          l.kpiAwaitAccept,
          '${c['pendingCustody'] ?? 0}',
          LucideIcons.hourglass,
          Dg.plum,
        ),
      ],
      (l.eodSync, '$pending', LucideIcons.cloudUpload, Dg.brand),
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
                StatTile(
                  label: kpis[i].$1,
                  value: kpis[i].$2,
                  icon: kpis[i].$3,
                  iconColor: kpis[i].$4,
                ),
                const SizedBox(width: 12),
                if (i + 1 < kpis.length)
                  StatTile(
                    label: kpis[i + 1].$1,
                    value: kpis[i + 1].$2,
                    icon: kpis[i + 1].$3,
                    iconColor: kpis[i + 1].$4,
                  )
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
