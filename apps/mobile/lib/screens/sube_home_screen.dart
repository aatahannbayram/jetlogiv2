import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../intro_tour.dart';
import '../l10n.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'sube_widgets.dart';

class SubeHomeScreen extends ConsumerWidget {
  const SubeHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);
    final branch = s.branch;
    final user = s.agencyUser;
    final d = branch.dashboard;
    final kpis = branch.board?.kpis;
    final synced = branch.syncedAt;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          d?.branchName.isNotEmpty == true
              ? d!.branchName
              : user?.agency.name ?? l.subeHome,
        ),
        actions: [
          IconButton(
            tooltip: l.retryNow,
            icon: DgIcon(LucideIcons.refreshCw),
            onPressed: branch.loading ? null : branch.refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: branch.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
          children: [
            IntroTourTrigger(
              show: !s.tipsSeen,
              steps: branchIntroSteps(l),
              onDone: s.markTipsSeen,
            ),
            Text(
              user?.fullName ?? '',
              style: Dg.ui(size: 16, weight: FontWeight.w600),
            ),
            if (synced != null)
              Text(
                l.lastSyncAt(subeClock(synced)),
                style: Dg.ui(size: 12, color: Dg.ink3),
              ),
            const SizedBox(height: 12),
            SubeStatusBanner(branch: branch),
            if (d == null)
              branch.loading
                  ? const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : const SizedBox.shrink()
            else ...[
              // Önce ilgi bekleyenler, sonra günün özeti. Sıfır olan
              // ilgi kutuları gösterilmez; hepsi sıfırsa bölüm de çıkmaz.
              ...() {
                final todo = [
                  if (kpis != null && kpis.unassigned > 0)
                    (l.kpiWaiting, '${kpis.unassigned}'),
                  if (d.approvalsHandover > 0)
                    (l.kpiAwaitAccept, '${d.approvalsHandover}'),
                  if (d.approvalsReturns > 0)
                    (l.kpiAwaitReturn, '${d.approvalsReturns}'),
                  if (d.urgent > 0) (l.kpiUrgent, '${d.urgent}'),
                  if (d.pending > 0) (l.kpiPendingOps, '${d.pending}'),
                ];
                return [
                  if (todo.isNotEmpty) ...[
                    SubeSection(l.subeNeedsYou),
                    SubeKpiGrid(todo, attention: true),
                  ],
                ];
              }(),
              SubeSection(l.subeTodayTitle),
              // "Bugün dağıtılacak" şubenin günlük toplam işidir; kuryelere
              // zimmetlenen onun bir parçasıdır, ayrı kutuda gösterilir.
              SubeKpiGrid([
                (l.kpiToday, '${d.todayToDeliver}'),
                (l.kpiDelivered, '${d.deliveredToday}'),
                if (kpis != null) (l.kpiAssigned, '${kpis.assigned}'),
                (
                  l.kpiActiveCouriers,
                  '${d.couriersActive} / ${d.couriersTotal}',
                ),
                (l.kpiCancelled, '${d.cancelledToday}'),
                (l.kpiReturnToCenter, '${d.returnToCenter}'),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
