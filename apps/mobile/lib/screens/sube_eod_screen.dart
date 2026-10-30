import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/branch_models.dart';
import '../branch_features.dart';
import '../l10n.dart';
import '../session.dart';
import '../theme.dart';
import '../ui/ui.dart';
import 'sube_shipment_detail_screen.dart';
import 'sube_widgets.dart';

/// Şube gün sonu kontrolü — stok sayımı değil, günün operasyon sonucu:
/// dağıtılacak, zimmetlenen, teslim, açık kalan ve kurye üzerinde kalanlar.
/// "Günü kapat" önerilen uca bağlı (docs/15 §5); bayrak kapalıyken düğme
/// kapalı, sahte kapanış gösterilmez.
class SubeEodScreen extends ConsumerStatefulWidget {
  const SubeEodScreen({super.key});

  @override
  ConsumerState<SubeEodScreen> createState() => _SubeEodScreenState();
}

class _SubeEodScreenState extends ConsumerState<SubeEodScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(sessionProvider).branch.loadEndOfDay(),
    );
  }

  Future<void> _close() async {
    final l = context.l10n;
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.eodCloseConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.eodCloseConfirmBody),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              maxLength: 300,
              decoration: InputDecoration(hintText: l.eodNoteHint),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            key: const Key('eod-close-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.eodCloseDay),
          ),
        ],
      ),
    );
    final text = note.text;
    note.dispose();
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final branch = ref.read(sessionProvider).branch;
    final error = await branch.closeEndOfDay(note: text);
    if (!mounted) return;
    setState(() => _busy = false);
    subeSnack(context, error ?? l.eodClosedSnack);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final branch = ref.watch(sessionProvider).branch;
    final ready = branch.proposed(BranchFeatures.endOfDayClose);
    final eod = branch.endOfDay;
    final d = branch.dashboard;
    final k = branch.board?.kpis;
    final p = branch.pending;
    final tiles = <Widget>[
      DgKpiTile(
        icon: LucideIcons.calendarClock,
        tone: DgTone.info,
        label: l.kpiToday,
        value: d?.todayToDeliver,
      ),
      DgKpiTile(
        icon: LucideIcons.userCheck,
        tone: DgTone.accent,
        label: l.kpiAssigned,
        value: k?.assigned,
      ),
      DgKpiTile(
        icon: LucideIcons.packageCheck,
        tone: DgTone.ok,
        label: l.kpiDelivered,
        value: d?.deliveredToday,
      ),
      DgKpiTile(
        icon: LucideIcons.ban,
        tone: DgTone.neutral,
        label: l.kpiCancelled,
        value: d?.cancelledToday,
      ),
      DgKpiTile(
        icon: LucideIcons.userPlus,
        tone: DgTone.warn,
        label: l.kpiWaiting,
        value: k?.unassigned,
      ),
      DgKpiTile(
        icon: LucideIcons.undo2,
        tone: DgTone.warn,
        label: l.kpiAwaitReturn,
        value: p?.returns.length,
      ),
      DgKpiTile(
        icon: LucideIcons.hourglass,
        tone: DgTone.accent,
        label: l.kpiOpen,
        value: p?.endOfDay.length,
      ),
      DgKpiTile(
        icon: LucideIcons.clockAlert,
        tone: DgTone.bad,
        label: l.filterLate,
        value: p?.overdue.length,
      ),
    ];
    final height = 24 + MediaQuery.textScalerOf(context).scale(62);
    return Scaffold(
      appBar: AppBar(title: Text(l.branchEodTitle)),
      body: RefreshIndicator(
        onRefresh: branch.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            SubeStatusBanner(branch: branch),
            for (var i = 0; i < tiles.length; i += 2)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(
                  height: height,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: tiles[i]),
                      const SizedBox(width: 10),
                      Expanded(child: tiles[i + 1]),
                    ],
                  ),
                ),
              ),
            if (p != null) ...[
              const SizedBox(height: 2),
              _Items(title: l.eodAwaitingResult, items: p.endOfDay),
              const SizedBox(height: 12),
              _Items(title: l.eodOverdueTitle, items: p.overdue),
            ],
            const SizedBox(height: 16),
            if (eod != null && eod.closed)
              DgPanel(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const DgIconBadge(
                      icon: LucideIcons.lockKeyhole,
                      tone: DgTone.ok,
                      soft: true,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.eodClosedTitle,
                            style: Dg.ui(size: 15, weight: FontWeight.w700),
                          ),
                          if (eod.closedAt != null)
                            Text(
                              l.eodClosedBy(
                                eod.closedByName ?? '',
                                _clock(eod.closedAt!),
                              ),
                              style: Dg.typeCaption(),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              if (eod != null && eod.blockers.isNotEmpty) ...[
                DgPanel(
                  title: l.eodBlockersTitle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final b in eod.blockers)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.circleAlert,
                                size: 16,
                                color: Dg.warn,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l.eodBlocker(b.code, b.count),
                                  style: Dg.ui(size: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              DgGradientButton(
                key: const Key('eod-close'),
                label: l.eodCloseDay,
                icon: LucideIcons.lock,
                busy: _busy,
                onPressed:
                    ready &&
                        eod != null &&
                        eod.canClose &&
                        branch.capabilities.manage
                    ? _close
                    : null,
              ),
              if (!ready)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l.pendingBackendBodyFor(l.eodCloseWhat),
                    textAlign: TextAlign.center,
                    style: Dg.typeCaption(),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

String _clock(DateTime at) {
  final t = at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}';
}

class _Items extends StatelessWidget {
  const _Items({required this.title, required this.items});

  final String title;
  final List<PendingItem> items;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DgPanel(
      title: title,
      trailing: Text(
        '${items.length}',
        style: Dg.ui(size: 14, color: Dg.text3),
      ),
      child: items.isEmpty
          ? Text(l.nothingWaiting, style: Dg.typeCaption())
          : Column(
              children: [
                for (final item in items)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.shipmentNumber,
                                  style: Dg.ui(
                                    size: 15,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  [
                                    if (item.recipientName.isNotEmpty)
                                      item.recipientName,
                                    if (item.courierName.isNotEmpty)
                                      item.courierName,
                                  ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Dg.typeCaption(),
                                ),
                              ],
                            ),
                          ),
                          if (item.resultMissing)
                            DgStatusPill(
                              label: l.resultMissing,
                              tone: DgTone.bad,
                              dense: true,
                            )
                          else if (item.overdue)
                            DgStatusPill(
                              label: l.filterLate,
                              tone: DgTone.bad,
                              dense: true,
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
