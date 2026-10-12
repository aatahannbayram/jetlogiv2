import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../coach.dart';
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
            if (!s.tipsSeen)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CoachBanner(
                  title: l.subeOnboard1Title,
                  body: l.tipHomeBody,
                  onDismiss: s.markTipsSeen,
                ),
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
              // "Bugün dağıtılacak" şubenin günlük toplam işidir; kuryelere
              // zimmetlenen onun bir parçasıdır, ayrı kutuda gösterilir.
              SubeKpiGrid([
                (l.kpiToday, '${d.todayToDeliver}'),
                (l.kpiDelivered, '${d.deliveredToday}'),
                if (kpis != null) (l.kpiAssigned, '${kpis.assigned}'),
                if (kpis != null) (l.kpiWaiting, '${kpis.unassigned}'),
                (l.kpiCancelled, '${d.cancelledToday}'),
                (l.kpiReturnToCenter, '${d.returnToCenter}'),
                (l.kpiUrgent, '${d.urgent}'),
                (l.kpiPendingOps, '${d.pending}'),
                (
                  l.kpiActiveCouriers,
                  '${d.couriersActive} / ${d.couriersTotal}',
                ),
                (l.kpiAwaitAccept, '${d.approvalsHandover}'),
                (l.kpiAwaitReturn, '${d.approvalsReturns}'),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
