import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/branch_models.dart';
import '../l10n.dart';
import '../scan_router.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'sube_incoming_screen.dart';
import 'sube_scan_sheet.dart';
import 'sube_widgets.dart';

/// Stok & Zimmet: fiziksel sorumluluğun el değiştirdiği üç kuyruk —
/// kuryenin kabulünü bekleyen zimmetler, kuryeden şubeye dönüşler ve
/// şubeye gelen transferler. Her kabul barkodla yapılır.
class SubeStockScreen extends ConsumerStatefulWidget {
  const SubeStockScreen({super.key});

  @override
  ConsumerState<SubeStockScreen> createState() => _SubeStockScreenState();
}

class _SubeStockScreenState extends ConsumerState<SubeStockScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final branch = ref.read(sessionProvider).branch;
      branch.loadStockSummary();
      branch.loadIncoming();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final branch = ref.watch(sessionProvider).branch;
    final canOperate = branch.capabilities.operate;
    final pending = branch.pending;
    final incoming = branch.incoming?.transfers ?? const <BranchTransfer>[];
    return Scaffold(
      appBar: AppBar(title: Text(l.subeStockTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          await branch.refresh();
          await branch.loadStockSummary();
          await branch.loadIncoming();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
          children: [
            SubeStatusBanner(branch: branch),
            if (branch.stockSummary != null) ...[
              SubeKpiGrid([
                (l.stockInWarehouse, '${branch.stockSummary!.inWarehouse}'),
                (l.stockAtCourier, '${branch.stockSummary!.atCourier}'),
                (l.stockInTransit, '${branch.stockSummary!.inTransit}'),
                (l.stockReturnPending, '${branch.stockSummary!.returnPending}'),
              ]),
              const SizedBox(height: 8),
            ],
            SubeSection(
              l.courierReturnsTitle,
              trailing: '${pending?.returns.length ?? 0}',
            ),
            for (final item in pending?.returns ?? const <PendingItem>[])
              _PendingTile(item: item),
            if (canOperate)
              DgButton(
                label: l.scanCourierReturn,
                icon: LucideIcons.undo2,
                onPressed: () => showSubeScanSheet(
                  context,
                  scanContext: ScanContext.courierReturn,
                  hint: 'Kuryeden dönen gönderiyi okutun',
                ),
              ),
            const SizedBox(height: 16),
            SubeSection(
              l.awaitingAcceptTitle,
              trailing: '${pending?.handovers.length ?? 0}',
            ),
            if (pending != null && pending.handovers.isEmpty)
              Text(l.nothingWaiting, style: Dg.ui(size: 13, color: Dg.ink3)),
            for (final item in pending?.handovers ?? const <PendingItem>[])
              _PendingTile(item: item),
            const SizedBox(height: 16),
            SubeSection(
              l.incomingTransfersTitle,
              trailing: '${incoming.length}',
            ),
            if (branch.incoming != null && incoming.isEmpty)
              Text(l.nothingWaiting, style: Dg.ui(size: 13, color: Dg.ink3)),
            for (final t in incoming)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DgCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SubeIncomingScreen(transfer: t),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Mono(
                              t.transferNumber,
                              size: 13,
                              weight: FontWeight.w700,
                            ),
                            Text(
                              t.partyName,
                              style: Dg.ui(size: 14, color: Dg.ink2),
                            ),
                          ],
                        ),
                      ),
                      Mono('${t.acceptedItemCount} / ${t.itemCount}'),
                    ],
                  ),
                ),
              ),
            if (canOperate) ...[
              const SizedBox(height: 4),
              DgButton(
                label: l.scanIncoming,
                icon: LucideIcons.packagePlus,
                tone: DgButtonTone.secondary,
                onPressed: () => showSubeScanSheet(
                  context,
                  scanContext: ScanContext.stockIn,
                  hint: 'Gelen koli veya gönderi barkodunu okutun',
                ),
              ),
            ],
          ],
        ),
      ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DgCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Mono(item.shipmentNumber, size: 13, weight: FontWeight.w700),
                  if (who.isNotEmpty)
                    Text(who, style: Dg.ui(size: 14, color: Dg.ink2)),
                ],
              ),
            ),
            if (item.overdue)
              StatusChip(label: l.filterLate, tone: 'hi')
            else if (item.since != null)
              Text(
                subeClock(item.since!),
                style: Dg.ui(size: 12, color: Dg.ink3),
              ),
          ],
        ),
      ),
    );
  }
}
