import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/branch_models.dart';
import '../branch_workspace.dart';
import '../l10n.dart';
import '../scan.dart';
import '../scan_router.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'sube_widgets.dart';

/// Stok sayımı — gönderi sayımı değil, şubedeki stoklu ürünlerin fiziksel
/// sayımı. Sayım sunucuda tek kayıttır: panelde başlatılan sayıma buradan
/// devam edilir, burada okutulan panelde görünür.
class SubeCountScreen extends ConsumerStatefulWidget {
  const SubeCountScreen({super.key});

  @override
  ConsumerState<SubeCountScreen> createState() => _SubeCountScreenState();
}

class _SubeCountScreenState extends ConsumerState<SubeCountScreen> {
  bool _busy = false;
  bool _uncountedAsZero = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionProvider).branch.loadCounts();
    });
  }

  Future<void> _guard(Future<String?> Function() run) async {
    setState(() => _busy = true);
    final error = await run();
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) subeSnack(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final branch = ref.watch(sessionProvider).branch;
    final detail = branch.count;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.subeCountTitle),
        actions: [
          IconButton(
            tooltip: l.retryNow,
            icon: DgIcon(LucideIcons.refreshCw),
            onPressed: branch.loading
                ? null
                : detail == null
                ? branch.loadCounts
                : branch.refreshCount,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          SubeStatusBanner(branch: branch, onRetry: branch.loadCounts),
          if (detail == null)
            ..._start(l, branch)
          else if (detail.count.scannable)
            ..._scanning(l, branch, detail)
          else
            ..._review(l, branch, detail),
        ],
      ),
    );
  }

  List<Widget> _start(L10n l, BranchWorkspace branch) {
    final data = branch.counts;
    if (data == null) {
      return [
        if (branch.loading)
          const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Center(child: CircularProgressIndicator()),
          ),
      ];
    }
    if (data.warehouses.isEmpty) {
      return [
        DgEmptyState(icon: LucideIcons.warehouse, title: l.noCountWarehouse),
      ];
    }
    final canOperate = data.capabilities.operate || branch.capabilities.operate;
    return [
      SubeSection(l.pickWarehouse),
      for (final w in data.warehouses)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DgCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.name, style: Dg.ui(size: 15, weight: FontWeight.w600)),
                if (w.code.isNotEmpty) Mono(w.code, size: 12, color: Dg.ink3),
                if (canOperate) ...[
                  const SizedBox(height: 10),
                  DgButton(
                    label: l.startCount,
                    height: 44,
                    busy: _busy,
                    onPressed: () => _guard(() => branch.startCount(w.id)),
                  ),
                ],
              ],
            ),
          ),
        ),
      if (!canOperate)
        Text(l.noPermission, style: Dg.ui(size: 13, color: Dg.ink3)),
    ];
  }

  List<Widget> _scanning(L10n l, BranchWorkspace branch, CountDetail detail) {
    final paused = branch.countPaused;
    final scans = branch.recentScans;
    return [
      _CountHeader(count: detail.count, chip: paused ? l.pauseCount : null),
      const SizedBox(height: 12),
      if (!paused)
        BarcodeScanPane(
          onDetect: (code) async {
            final outcome = await branch.scan(ScanContext.count, code);
            await playScanFeedback(beep: outcome.ok);
          },
        ),
      const SizedBox(height: 12),
      DgButton(
        label: paused ? l.resumeCount : l.pauseCount,
        icon: paused ? LucideIcons.play : LucideIcons.pause,
        tone: DgButtonTone.secondary,
        onPressed: () => branch.setCountPaused(!paused),
      ),
      if (scans.isNotEmpty) ...[
        const SizedBox(height: 12),
        SubeSection(l.recentScansTitle, trailing: '${scans.length}'),
        for (final s in scans.take(6))
          ScanOutcomeTile(code: s.code, outcome: s.outcome),
      ],
      ..._lines(l, branch, detail, editable: false),
      const SizedBox(height: 16),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _uncountedAsZero,
        onChanged: (v) => setState(() => _uncountedAsZero = v ?? false),
        title: Text(l.uncountedAsZero, style: Dg.ui(size: 14)),
      ),
      DgButton(
        label: l.finishCount,
        icon: LucideIcons.clipboardCheck,
        busy: _busy,
        onPressed: () =>
            _guard(() => branch.closeCount(uncountedAsZero: _uncountedAsZero)),
      ),
    ];
  }

  List<Widget> _review(L10n l, BranchWorkspace branch, CountDetail detail) => [
    _CountHeader(count: detail.count, chip: l.countInReview),
    const SizedBox(height: 8),
    Text(l.countInReviewHint, style: Dg.ui(size: 13, color: Dg.ink2)),
    ..._lines(l, branch, detail, editable: true),
  ];

  /// Yalnız farklı satırlar: eksik / fazla otomatik listelenir.
  List<Widget> _lines(
    L10n l,
    BranchWorkspace branch,
    CountDetail detail, {
    required bool editable,
  }) {
    final variance = detail.varianceLines;
    return [
      const SizedBox(height: 12),
      SubeSection(l.countDiff, trailing: '${variance.length}'),
      if (variance.isEmpty)
        Text(l.countNoVariance, style: Dg.ui(size: 13, color: Dg.ink3)),
      for (final line in variance)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DgCard(
            onTap: editable && !_busy ? () => _reason(branch, line) : null,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.name,
                        style: Dg.ui(size: 14, weight: FontWeight.w600),
                      ),
                      Text(
                        '${l.countSystem} ${_n(line.expected)} · '
                        '${l.countCounted} ${_n(line.counted)}',
                        style: Dg.ui(size: 12, color: Dg.ink3),
                      ),
                      if (line.reasonCode != null)
                        Text(
                          l.countReasonName(line.reasonCode!),
                          style: Dg.ui(size: 12, color: Dg.ink2),
                        ),
                    ],
                  ),
                ),
                StatusChip(
                  label: _signed(line.difference),
                  tone: (line.difference ?? 0) < 0 ? 'hi' : 'mid',
                ),
              ],
            ),
          ),
        ),
    ];
  }

  Future<void> _reason(BranchWorkspace branch, CountLine line) async {
    final l = context.l10n;
    final codes = branch.counts?.reasonCodes ?? const <String>[];
    final code = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Dg.surface,
      builder: (ctx) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        shrinkWrap: true,
        children: [
          Text(l.pickReason, style: Dg.ui(size: 17, weight: FontWeight.w700)),
          for (final c in codes)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.countReasonName(c)),
              onTap: () => Navigator.pop(ctx, c),
            ),
        ],
      ),
    );
    if (code == null || !mounted) return;
    await _guard(() => branch.setLineReason(line, code));
  }

  static String _n(num? v) => v == null
      ? '—'
      : v == v.roundToDouble()
      ? '${v.round()}'
      : '$v';

  static String _signed(num? v) {
    if (v == null) return '—';
    return v > 0 ? '+${_n(v)}' : _n(v);
  }
}

class _CountHeader extends StatelessWidget {
  const _CountHeader({required this.count, this.chip});

  final StockCount count;
  final String? chip;

  @override
  Widget build(BuildContext context) {
    return DgCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Mono(count.number, size: 12, color: Dg.ink3),
                Text(
                  count.warehouseName,
                  style: Dg.ui(size: 16, weight: FontWeight.w700),
                ),
              ],
            ),
          ),
          if (chip != null) StatusChip(label: chip!, tone: 'mid'),
        ],
      ),
    );
  }
}
