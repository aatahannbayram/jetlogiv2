import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/branch_models.dart';
import '../l10n.dart';
import '../scan_router.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'sube_scan_sheet.dart';
import 'sube_widgets.dart';

/// Gelen transfer kabulü: kalemler okutulur → "İçeri Al" → "Transferi
/// Onayla". Onayda okutulmayan kalemler eksik olarak kapanır.
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
    return Scaffold(
      appBar: AppBar(title: Text(transfer.transferNumber)),
      body: RefreshIndicator(
        onRefresh: () => branch.openIncoming(widget.transfer.id),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            SubeStatusBanner(
              branch: branch,
              onRetry: () => branch.openIncoming(widget.transfer.id),
            ),
            DgCard(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      transfer.partyName,
                      style: Dg.ui(size: 15, weight: FontWeight.w600),
                    ),
                  ),
                  Mono('${transfer.acceptedItemCount} / ${transfer.itemCount}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (canAct) ...[
              DgButton(
                label: l.scanIncoming,
                icon: LucideIcons.qrCode,
                onPressed: () => showSubeScanSheet(
                  context,
                  scanContext: ScanContext.stockIn,
                  hint: 'Gelen koli veya gönderi barkodunu okutun',
                ),
              ),
              const SizedBox(height: 8),
              DgButton(
                label: l.acceptScannedN(detail?.pendingScannedCount ?? 0),
                icon: LucideIcons.packagePlus,
                tone: DgButtonTone.secondary,
                busy: _busy,
                onPressed: (detail?.pendingScannedCount ?? 0) == 0
                    ? null
                    : () =>
                          _guard(() => branch.acceptIncoming(transfer), l.done),
              ),
              const SizedBox(height: 8),
              DgButton(
                label: l.confirmTransfer,
                icon: LucideIcons.clipboardCheck,
                tone: DgButtonTone.secondary,
                busy: _busy,
                onPressed: detail == null ? null : () => _confirm(detail),
              ),
            ],
            if (detail == null && branch.loading)
              const Padding(
                padding: EdgeInsets.only(top: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (detail != null) ...[
              const SizedBox(height: 8),
              SubeSection(
                l.incomingTransfersTitle,
                trailing: '${detail.lines.length}',
              ),
              for (final line in detail.lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DgCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Mono(
                                line.shipmentNumber.isEmpty
                                    ? line.cargoCode
                                    : line.shipmentNumber,
                                size: 13,
                                weight: FontWeight.w700,
                              ),
                              if (line.product.isNotEmpty)
                                Text(
                                  line.product,
                                  style: Dg.ui(size: 12, color: Dg.ink3),
                                ),
                            ],
                          ),
                        ),
                        StatusChip(
                          label: l.transferLineState(line.state),
                          tone: switch (line.state) {
                            'IN' => 'lo',
                            'SCANNED' => 'lime',
                            'MISSING' || 'EXCEPTION' => 'hi',
                            _ => 'mid',
                          },
                        ),
                      ],
                    ),
                  ),
                ),
            ],
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
