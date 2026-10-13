import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../intro_tour.dart';
import '../brand.dart';
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
        // Başlıkta logo; şube adı uzun olabildiği için aşağıda iki satıra
        // kadar yazılır.
        title: DijigooWordmark(height: 34, onDark: Dg.dark),
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
              d?.branchName.isNotEmpty == true
                  ? d!.branchName
                  : user?.agency.name ?? l.subeHome,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Dg.ui(size: 22, weight: FontWeight.w700, height: 1.2),
            ),
            const SizedBox(height: 2),
            Text(user?.fullName ?? '', style: Dg.ui(size: 14, color: Dg.ink2)),
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
                    (l.kpiWaiting, '${kpis.unassigned}', LucideIcons.clock),
                  if (d.approvalsHandover > 0)
                    (
                      l.kpiAwaitAccept,
                      '${d.approvalsHandover}',
                      LucideIcons.userCheck,
                    ),
                  if (d.approvalsReturns > 0)
                    (
                      l.kpiAwaitReturn,
                      '${d.approvalsReturns}',
                      LucideIcons.undo2,
                    ),
                  if (d.urgent > 0)
                    (l.kpiUrgent, '${d.urgent}', LucideIcons.zap),
                  if (d.pending > 0)
                    (l.kpiPendingOps, '${d.pending}', LucideIcons.listTodo),
                ];
                return [
                  if (todo.isNotEmpty) ...[
                    SubeSection(l.subeNeedsYou),
                    SubeKpiGrid(
                      [for (final t in todo) (t.$1, t.$2)],
                      attention: true,
                      icons: [for (final t in todo) t.$3],
                    ),
                  ],
                ];
              }(),
              SubeSection(l.subeTodayTitle),
              // "Bugün dağıtılacak" şubenin günlük toplam işidir; kuryelere
              // zimmetlenen onun bir parçasıdır, ayrı kutuda gösterilir.
              SubeKpiGrid(
                [
                  (l.kpiToday, '${d.todayToDeliver}'),
                  (l.kpiDelivered, '${d.deliveredToday}'),
                  if (kpis != null) (l.kpiAssigned, '${kpis.assigned}'),
                  (
                    l.kpiActiveCouriers,
                    '${d.couriersActive} / ${d.couriersTotal}',
                  ),
                  (l.kpiCancelled, '${d.cancelledToday}'),
                  (l.kpiReturnToCenter, '${d.returnToCenter}'),
                ],
                icons: [
                  LucideIcons.truck,
                  LucideIcons.circleCheck,
                  if (kpis != null) LucideIcons.packageCheck,
                  LucideIcons.users,
                  LucideIcons.circleX,
                  LucideIcons.warehouse,
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
