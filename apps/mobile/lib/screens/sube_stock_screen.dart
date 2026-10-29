import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/branch_models.dart';
import '../branch_features.dart';
import '../l10n.dart';
import '../motion.dart';
import '../scan_router.dart';
import '../session.dart';
import '../theme.dart';
import '../ui/ui.dart';
import '../widgets.dart';
import 'custody_dispute_sheet.dart';
import 'sube_count_reconcile_screen.dart';
import 'sube_count_screen.dart';
import 'sube_dispatch_screen.dart';
import 'sube_incoming_screen.dart';
import 'sube_return_flow.dart';
import 'sube_scan_sheet.dart';
import 'sube_shipment_detail_screen.dart';
import 'sube_widgets.dart';

/// Stok & Zimmet (mockup 8): fiziksel sorumluluğun el değiştirdiği üç
/// kuyruk (gelen transferler, kurye kabulü bekleyen zimmetler, kuryeden
/// dönüşler), sayaçlar ve stok işlemlerine geçiş. Her kabul barkodla.
class SubeStockScreen extends ConsumerStatefulWidget {
  const SubeStockScreen({super.key});

  @override
  ConsumerState<SubeStockScreen> createState() => _SubeStockScreenState();
}

class _SubeStockScreenState extends ConsumerState<SubeStockScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final branch = ref.read(sessionProvider).branch;
      branch.loadIncoming();
      branch.loadCustodyDisputes();
      if (branch.counts == null) branch.loadCounts();
    });
  }

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final branch = ref.watch(sessionProvider).branch;
    final canOperate = branch.capabilities.operate;
    final pending = branch.pending;
    final incoming = branch.incoming?.transfers ?? const <BranchTransfer>[];
    final handovers = pending?.handovers ?? const <PendingItem>[];
    final returns = pending?.returns ?? const <PendingItem>[];
    final openCount = branch.count?.count ?? branch.counts?.openCount;
    final disputes = branch.custodyDisputes;
    final openDisputes = disputes?.where((d) => !d.resolved).length ?? 0;
    final height = 24 + MediaQuery.textScalerOf(context).scale(62);
    Widget pair(Widget a, Widget b) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: a),
            const SizedBox(width: 10),
            Expanded(child: b),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.subeStockTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          await branch.refresh();
          await branch.loadIncoming();
          await branch.loadCustodyDisputes();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            SubeStatusBanner(branch: branch),
            pair(
              DgKpiTile(
                icon: LucideIcons.arrowDownToLine,
                tone: DgTone.info,
                label: l.stockIncomingTab,
                value: branch.incoming == null ? null : incoming.length,
                onTap: () => setState(() => _tab = 0),
              ),
              DgKpiTile(
                icon: LucideIcons.hourglass,
                tone: DgTone.accent,
                label: l.awaitingAcceptTitle,
                value: pending == null ? null : handovers.length,
                onTap: () => setState(() => _tab = 1),
              ),
            ),
            pair(
              DgKpiTile(
                icon: LucideIcons.undo2,
                tone: DgTone.warn,
                label: l.courierReturnsTitle,
                value: pending == null ? null : returns.length,
                onTap: () => setState(() => _tab = 2),
              ),
              DgKpiTile(
                icon: LucideIcons.clipboardList,
                tone: DgTone.ok,
                label: openCount == null
                    ? l.stockOpenCount
                    : l.countStatus(openCount.statusCode),
                value: branch.counts == null && openCount == null
                    ? null
                    : (openCount == null ? 0 : 1),
                onTap: () => _push(const SubeCountScreen()),
              ),
            ),
            const SizedBox(height: 4),
            DgActionGrid(
              items: [
                (
                  icon: LucideIcons.packagePlus,
                  label: l.transferIncoming,
                  tone: DgTone.info,
                  onTap: canOperate
                      ? () => showSubeScanSheet(
                          context,
                          scanContext: ScanContext.stockIn,
                          hint: l.scanIncoming,
                        )
                      : null,
                ),
                (
                  icon: LucideIcons.arrowUpFromLine,
                  label: l.transferOutgoing,
                  tone: DgTone.accent,
                  onTap: () => _push(const SubeDispatchScreen()),
                ),
                (
                  icon: LucideIcons.clipboardList,
                  label: l.quickCount,
                  tone: DgTone.ok,
                  onTap: () => _push(const SubeCountScreen()),
                ),
                (
                  icon: LucideIcons.scale,
                  label: l.reconcileTitle,
                  tone: DgTone.warn,
                  onTap: () => _push(const SubeCountReconcileScreen()),
                ),
              ],
            ),
            if (!BranchFeatures.branchStockCounters) ...[
              const SizedBox(height: 10),
              DgPanel(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const DgIconBadge(
                      icon: LucideIcons.cloudCog,
                      tone: DgTone.neutral,
                      size: 36,
                      soft: true,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l.pendingBackendBodyFor(l.stockCountersWhat),
                        style: Dg.typeCaption(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            DgPillTabs(
              labels: [
                l.stockIncomingShort,
                l.stockHandoverTab,
                l.stockReturnTab,
                l.branchDisputesTab,
              ],
              counts: [
                incoming.length,
                handovers.length,
                returns.length,
                openDisputes,
              ],
              index: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: DgMotion.standard,
              switchInCurve: DgMotion.enter,
              switchOutCurve: DgMotion.exit,
              child: KeyedSubtree(
                key: ValueKey(_tab),
                child: switch (_tab) {
                  0 => _IncomingList(
                    transfers: incoming,
                    loading: branch.incoming == null && branch.loading,
                  ),
                  1 => _PendingList(items: handovers),
                  3 => _DisputeList(disputes: disputes),
                  _ => Column(
                    children: [
                      _PendingList(items: returns),
                      if (canOperate)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: DgGradientButton(
                            label: l.stockStartReturn,
                            icon: LucideIcons.undo2,
                            onPressed: () => _push(const SubeReturnFlow()),
                          ),
                        ),
                    ],
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomingList extends StatelessWidget {
  const _IncomingList({required this.transfers, required this.loading});

  final List<BranchTransfer> transfers;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (transfers.isEmpty) {
      return loading
          ? const DgSkeleton(height: 72, radius: 16)
          : DgEmptyState(icon: LucideIcons.inbox, title: l.nothingWaiting);
    }
    return Column(
      children: [
        for (var i = 0; i < transfers.length; i++)
          StaggerIn(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DgPanel(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SubeIncomingScreen(transfer: transfers[i]),
                  ),
                ),
                child: Row(
                  children: [
                    const DgIconBadge(
                      icon: LucideIcons.truck,
                      tone: DgTone.info,
                      soft: true,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transfers[i].transferNumber,
                            style: Dg.ui(size: 15, weight: FontWeight.w700),
                          ),
                          Text(
                            transfers[i].partyName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Dg.typeCaption(),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${transfers[i].acceptedItemCount} / '
                      '${transfers[i].itemCount}',
                      style: Dg.ui(size: 15, weight: FontWeight.w700),
                    ),
                    const SizedBox(width: 6),
                    Icon(LucideIcons.chevronRight, size: 18, color: Dg.text3),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Kurye uyuşmazlıkları: şube yalnız görür, çözüm operasyondadır.
class _DisputeList extends StatelessWidget {
  const _DisputeList({required this.disputes});

  final List<CustodyDispute>? disputes;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rows = disputes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(l.branchDisputesNote, style: Dg.typeCaption()),
        ),
        if (rows == null)
          const DgSkeleton(height: 72, radius: 16)
        else if (rows.isEmpty)
          DgEmptyState(
            icon: LucideIcons.shieldCheck,
            title: l.branchDisputesEmpty,
          )
        else
          for (var i = 0; i < rows.length; i++)
            StaggerIn(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CustodyDisputeTile(dispute: rows[i]),
              ),
            ),
      ],
    );
  }
}

class _PendingList extends StatelessWidget {
  const _PendingList({required this.items});

  final List<PendingItem> items;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (items.isEmpty) {
      return DgEmptyState(
        icon: LucideIcons.circleCheck,
        title: l.nothingWaiting,
      );
    }
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          StaggerIn(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PendingTile(item: items[i]),
            ),
          ),
      ],
    );
  }
}

class _PendingTile extends StatelessWidget {
  const _PendingTile({required this.item});

  final PendingItem item;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final who = [
      if (item.recipientName.isNotEmpty) item.recipientName,
      if (item.courierName.isNotEmpty) item.courierName,
    ].join(' · ');
    return DgPanel(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SubeShipmentDetailScreen(
            row: BranchShipmentRow(
              shipmentId: item.shipmentId,
              shipmentNumber: item.shipmentNumber,
              recipientName: item.recipientName,
              pendingCourierName: item.courierName.isEmpty
                  ? null
                  : item.courierName,
              late: item.overdue,
            ),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.shipmentNumber,
                  style: Dg.ui(size: 15, weight: FontWeight.w700),
                ),
                if (who.isNotEmpty)
                  Text(
                    who,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Dg.typeCaption(),
                  ),
              ],
            ),
          ),
          if (item.overdue)
            DgStatusPill(label: l.filterLate, tone: DgTone.bad, dense: true)
          else if (item.since != null)
            Text(subeClock(item.since!), style: Dg.typeCaption()),
        ],
      ),
    );
  }
}
