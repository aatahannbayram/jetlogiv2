import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/branch_models.dart';
import '../l10n.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'sube_widgets.dart';

/// Şube gün sonu kontrolü — stok sayımı değil, günün operasyon sonucu:
/// dağıtılacak, zimmetlenen, teslim, açık kalan ve kurye üzerinde kalanlar.
class SubeEodScreen extends ConsumerWidget {
  const SubeEodScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final branch = ref.watch(sessionProvider).branch;
    final d = branch.dashboard;
    final k = branch.board?.kpis;
    final p = branch.pending;
    return Scaffold(
      appBar: AppBar(title: Text(l.branchEodTitle)),
      body: RefreshIndicator(
        onRefresh: branch.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            SubeStatusBanner(branch: branch),
            SubeKpiGrid([
              if (d != null) (l.kpiToday, '${d.todayToDeliver}'),
              if (k != null) (l.kpiAssigned, '${k.assigned}'),
              if (d != null) (l.kpiDelivered, '${d.deliveredToday}'),
              if (d != null) (l.kpiCancelled, '${d.cancelledToday}'),
              if (k != null) (l.kpiWaiting, '${k.unassigned}'),
              if (p != null) (l.kpiAwaitReturn, '${p.returns.length}'),
              if (p != null) (l.kpiOpen, '${p.endOfDay.length}'),
              if (p != null) (l.filterLate, '${p.overdue.length}'),
            ]),
            if (p != null) ...[
              _list(l, l.eodAwaitingResult, p.endOfDay),
              _list(l, l.eodOverdueTitle, p.overdue),
            ],
          ],
        ),
      ),
    );
  }

  Widget _list(L10n l, String title, List<PendingItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SubeSection(title, trailing: '${items.length}'),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l.nothingWaiting,
              style: Dg.ui(size: 13, color: Dg.ink3),
            ),
          ),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DgCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Mono(
                          item.shipmentNumber,
                          size: 13,
                          weight: FontWeight.w700,
                        ),
                        Text(
                          [
                            if (item.recipientName.isNotEmpty)
                              item.recipientName,
                            if (item.courierName.isNotEmpty) item.courierName,
                          ].join(' · '),
                          style: Dg.ui(size: 14, color: Dg.ink2),
                        ),
                      ],
                    ),
                  ),
                  if (item.resultMissing)
                    StatusChip(label: l.resultMissing, tone: 'hi'),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
