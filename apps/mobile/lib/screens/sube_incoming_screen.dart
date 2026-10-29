import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/branch_models.dart';
import '../l10n.dart';
import '../motion.dart';
import '../scan_router.dart';
import '../session.dart';
import '../theme.dart';
import '../ui/ui.dart';
import '../widgets.dart';
import 'sube_scan_sheet.dart';
import 'sube_widgets.dart';

/// Transfer Kabul (mockup 9): kalemler okutulur → "Tümünü zimmetle"
/// (okunanlar içeri alınır) → "Transferi onayla". Onayda okutulmayan
/// kalemler eksik olarak kapanır. Adım çubuğu ve sayım özeti sunucunun
/// kalem durumlarından hesaplanır.
class SubeIncomingScreen extends ConsumerStatefulWidget {
  const SubeIncomingScreen({super.key, required this.transfer});

  final BranchTransfer transfer;

  @override
  ConsumerState<SubeIncomingScreen> createState() => _SubeIncomingScreenState();
}

class _SubeIncomingScreenState extends ConsumerState<SubeIncomingScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionProvider).branch.openIncoming(widget.transfer.id);
    });
  }

  Future<void> _guard(Future<String?> Function() run, String done) async {
    setState(() => _busy = true);
    final error = await run();
    if (!mounted) return;
    setState(() => _busy = false);
    subeSnack(context, error ?? done);
  }

  static DgTone _tone(String state) => switch (state) {
    'IN' => DgTone.ok,
    'SCANNED' => DgTone.info,
    'MISSING' || 'EXCEPTION' => DgTone.bad,
    _ => DgTone.neutral,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final branch = ref.watch(sessionProvider).branch;
    final loaded = branch.incomingDetail;
    final detail = loaded?.transfer.id == widget.transfer.id ? loaded : null;
    final transfer = detail?.transfer ?? widget.transfer;
    final open =
        transfer.statusCode == 'DISPATCHED' ||
        transfer.statusCode == 'ACCEPTANCE_PENDING';
    final canAct = branch.capabilities.operate && open;
    final lines = detail?.lines ?? const <TransferLine>[];
    final inside = lines.where((x) => x.state == 'IN').length;
    final scanned = lines.where((x) => x.state == 'SCANNED').length;
    final missing = lines.where((x) => x.state == 'MISSING').length;
    final faulty = lines.where((x) => x.state == 'EXCEPTION').length;
    final waiting = detail?.pendingScannedCount ?? 0;
    final step = !open
        ? 3
        : waiting > 0
        ? 1
        : inside > 0
        ? 2
        : 0;
    return Scaffold(
      appBar: AppBar(title: Text(l.transferIncoming)),
      body: RefreshIndicator(
        onRefresh: () => branch.openIncoming(widget.transfer.id),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            DgStepper(
              steps: [l.stepScan, l.stepAccept, l.stepConfirm],
              current: step,
            ),
            const SizedBox(height: 14),
            SubeStatusBanner(
              branch: branch,
              onRetry: () => branch.openIncoming(widget.transfer.id),
            ),
            DgPanel(
              child: Row(
                children: [
                  const DgIconBadge(icon: LucideIcons.truck, tone: DgTone.info),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transfer.transferNumber,
                          style: Dg.ui(size: 16, weight: FontWeight.w700),
                        ),
                        Text(
                          transfer.partyName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Dg.typeCaption(),
                        ),
                      ],
                    ),
                  ),
                  DgStatusPill(
                    label: l.transferStatus(transfer.statusCode),
                    tone: open ? DgTone.warn : DgTone.ok,
                    dense: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (detail == null && branch.loading)
              const DgSkeleton(height: 120, radius: 16)
            else
              DgCountSummary(
                expected: detail == null ? transfer.itemCount : lines.length,
                read: detail == null
                    ? transfer.acceptedItemCount
                    : inside + scanned,
                missing: missing,
                damaged: faulty,
              ),
            const SizedBox(height: 12),
            if (canAct) ...[
              DgGradientButton(
                label: l.scanIncoming,
                icon: LucideIcons.scanLine,
                onPressed: () => showSubeScanSheet(
                  context,
                  scanContext: ScanContext.stockIn,
                  hint: l.scanIncoming,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DgButton(
                      key: const Key('incoming-accept'),
                      label: l.acceptAll(waiting),
                      icon: LucideIcons.packagePlus,
                      tone: DgButtonTone.secondary,
                      busy: _busy,
                      onPressed: waiting == 0
                          ? null
                          : () => _guard(
                              () => branch.acceptIncoming(transfer),
                              l.done,
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DgButton(
                      label: l.confirmTransfer,
                      icon: LucideIcons.clipboardCheck,
                      tone: DgButtonTone.secondary,
                      busy: _busy,
                      onPressed: detail == null ? null : () => _confirm(detail),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (detail != null)
              DgPanel(
                title: l.incomingTransfersTitle,
                trailing: Text(
                  '${lines.length}',
                  style: Dg.ui(size: 14, color: Dg.text3),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < lines.length; i++)
                      _LineRow(
                        line: lines[i],
                        tone: _tone(lines[i].state),
                        index: i,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(IncomingTransferDetail detail) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.confirmTransfer),
        content: Text(
          [
            if (detail.pendingCount > 0) l.remainingItems(detail.pendingCount),
            l.confirmTransferHint,
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.confirmTransfer),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _guard(
      () => ref.read(sessionProvider).branch.confirmIncoming(detail.transfer),
      l.done,
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, required this.tone, required this.index});

  final TransferLine line;
  final DgTone tone;
  final int index;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.shipmentNumber.isEmpty
                      ? line.cargoCode
                      : line.shipmentNumber,
                  style: Dg.ui(size: 15, weight: FontWeight.w600),
                ),
                if (line.product.isNotEmpty)
                  Text(line.product, style: Dg.typeCaption()),
              ],
            ),
          ),
          DgStatusPill(
            label: l.transferLineState(line.state),
            tone: tone,
            dense: true,
          ),
        ],
      ),
    );
    return index < 8 ? StaggerIn(index: index, child: row) : row;
  }
}
