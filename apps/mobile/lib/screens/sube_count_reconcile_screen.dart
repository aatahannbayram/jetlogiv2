import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/branch_models.dart';
import '../branch_workspace.dart';
import '../l10n.dart';
import '../motion.dart';
import '../session.dart';
import '../theme.dart';
import '../ui/ui.dart';
import '../widgets.dart';
import 'sube_count_screen.dart';
import 'sube_widgets.dart';

String _date(DateTime at) {
  final t = at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}.${two(t.month)}.${t.year}';
}

/// Sayım Mutabakatı (mockup 12): sayımlar durumlarına göre (Aktif =
/// taslak / sayılıyor, Bekleyen = incelemede, Tamamlanan = onaylı / iptal).
/// Satır, sayımın fark kalemlerini açar; incelemedeki açık sayım yönetici
/// tarafından onaylanıp merkeze gönderilir.
class SubeCountReconcileScreen extends ConsumerStatefulWidget {
  const SubeCountReconcileScreen({super.key});

  @override
  ConsumerState<SubeCountReconcileScreen> createState() =>
      _SubeCountReconcileScreenState();
}

class _SubeCountReconcileScreenState
    extends ConsumerState<SubeCountReconcileScreen> {
  int _tab = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionProvider).branch.loadCounts();
    });
  }

  static int _group(StockCount c) => c.scannable
      ? 0
      : c.statusCode == 'REVIEW'
      ? 1
      : 2;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final branch = ref.watch(sessionProvider).branch;
    final open = branch.count?.count;
    // Açık sayım listede yoksa (yeni başlatıldı) başa eklenir.
    final all = <StockCount>[
      if (open != null &&
          !(branch.counts?.counts ?? const <StockCount>[]).any(
            (c) => c.id == open.id,
          ))
        open,
      for (final c in branch.counts?.counts ?? const <StockCount>[])
        c.id == open?.id ? open! : c,
    ];
    final groups = [
      for (var g = 0; g < 3; g++)
        [
          for (final c in all)
            if (_group(c) == g) c,
        ],
    ];
    final shown = groups[_tab];
    return Scaffold(
      appBar: AppBar(title: Text(l.reconcileTitle)),
      body: RefreshIndicator(
        onRefresh: branch.loadCounts,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            DgPillTabs(
              labels: [l.reconcileActive, l.reconcilePending, l.reconcileDone],
              counts: [for (final g in groups) g.length],
              index: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            const SizedBox(height: 12),
            SubeStatusBanner(branch: branch, onRetry: branch.loadCounts),
            if (shown.isEmpty)
              branch.loading && branch.counts == null
                  ? const DgSkeleton(height: 80, radius: 16)
                  : DgEmptyState(
                      icon: LucideIcons.clipboardList,
                      title: l.reconcileEmpty,
                    ),
            for (var i = 0; i < shown.length; i++)
              StaggerIn(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CountRow(
                    count: shown[i],
                    onTap: () => shown[i].scannable
                        ? Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const SubeCountScreen(),
                            ),
                          )
                        : _openLines(branch, shown[i]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLines(BranchWorkspace branch, StockCount count) {
    final future = branch.countDetail(count.id);
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Dg.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.8,
        ),
        child: _CountLinesSheet(count: count, future: future),
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({required this.count, required this.onTap});

  final StockCount count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tone = switch (count.statusCode) {
      'REVIEW' => DgTone.warn,
      'POSTED' => DgTone.ok,
      'CANCELLED' => DgTone.neutral,
      _ => DgTone.info,
    };
    return DgPanel(
      onTap: onTap,
      child: Row(
        children: [
          DgIconBadge(
            icon: LucideIcons.clipboardList,
            tone: tone,
            size: 40,
            soft: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count.number,
                  style: Dg.ui(size: 15, weight: FontWeight.w700),
                ),
                Text(
                  [
                    count.warehouseName,
                    if (count.startedAt != null) _date(count.startedAt!),
                  ].where((e) => e.isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Dg.typeCaption(),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    DgStatusPill(
                      label: l.countStatus(count.statusCode),
                      tone: tone,
                      dense: true,
                    ),
                    DgStatusPill(
                      label: l.varianceLines(count.varianceLineCount),
                      tone: count.varianceLineCount > 0
                          ? DgTone.bad
                          : DgTone.ok,
                      dense: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight, size: 18, color: Dg.text3),
        ],
      ),
    );
  }
}

/// Sayımın fark kalemleri; incelemedeki açık sayımda yönetici onaylayıp
/// merkeze gönderir.
class _CountLinesSheet extends ConsumerStatefulWidget {
  const _CountLinesSheet({required this.count, required this.future});

  final StockCount count;
  final Future<CountDetail?> future;

  @override
  ConsumerState<_CountLinesSheet> createState() => _CountLinesSheetState();
}

class _CountLinesSheetState extends ConsumerState<_CountLinesSheet> {
  bool _busy = false;

  static String _n(num? v) => v == null
      ? '—'
      : v == v.roundToDouble()
      ? '${v.round()}'
      : '$v';

  Future<void> _post() async {
    final l = context.l10n;
    setState(() => _busy = true);
    final error = await ref
        .read(sessionProvider)
        .branch
        .postCountById(widget.count.id);
    if (!mounted) return;
    setState(() => _busy = false);
    subeSnack(context, error ?? l.done);
    if (error == null) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final branch = ref.watch(sessionProvider).branch;
    final canPost =
        widget.count.statusCode == 'REVIEW' &&
        (branch.capabilities.manage ||
            (branch.counts?.capabilities.manage ?? false));
    return FutureBuilder<CountDetail?>(
      future: widget.future,
      builder: (context, snap) {
        final detail = snap.data;
        final lines = detail?.lines ?? const <CountLine>[];
        var expected = 0;
        var read = 0;
        var missing = 0;
        var extra = 0;
        for (final line in lines) {
          expected += (line.expected ?? 0).round();
          read += (line.counted ?? 0).round();
          final d = (line.difference ?? 0).round();
          if (d < 0) missing += -d;
          if (d > 0) extra += d;
        }
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(
              widget.count.number,
              style: Dg.ui(size: 18, weight: FontWeight.w700),
            ),
            Text(
              '${widget.count.warehouseName} · '
              '${l.countStatus(widget.count.statusCode)}',
              style: Dg.typeCaption(),
            ),
            const SizedBox(height: 12),
            if (snap.connectionState != ConnectionState.done)
              const DgSkeleton(height: 140, radius: 16)
            else if (snap.hasError)
              Text(
                BranchWorkspace.describeError(snap.error!),
                style: Dg.ui(size: 14, color: Dg.bad),
              )
            else if (detail == null)
              Text(l.reconcileEmpty, style: Dg.typeCaption())
            else ...[
              DgCountSummary(
                expected: expected,
                read: read,
                missing: missing,
                extra: extra,
              ),
              const SizedBox(height: 12),
              for (final line in detail.varianceLines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DgPanel(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                line.name,
                                style: Dg.ui(size: 15, weight: FontWeight.w600),
                              ),
                              Text(
                                '${l.countSystem} ${_n(line.expected)} · '
                                '${l.countCounted} ${_n(line.counted)}',
                                style: Dg.typeCaption(),
                              ),
                              if (line.reasonCode != null)
                                Text(
                                  l.countReasonName(line.reasonCode!),
                                  style: Dg.ui(size: 13, color: Dg.text2),
                                ),
                            ],
                          ),
                        ),
                        DgStatusPill(
                          label: (line.difference ?? 0) > 0
                              ? '+${_n(line.difference)}'
                              : _n(line.difference),
                          tone: (line.difference ?? 0) < 0
                              ? DgTone.bad
                              : DgTone.warn,
                        ),
                      ],
                    ),
                  ),
                ),
              if (detail.varianceLines.isEmpty)
                Text(l.countNoVariance, style: Dg.typeCaption()),
              if (widget.count.statusCode == 'REVIEW') ...[
                const SizedBox(height: 12),
                if (canPost)
                  DgGradientButton(
                    key: const Key('reconcile-send'),
                    label: l.reconcileSend,
                    icon: LucideIcons.send,
                    busy: _busy,
                    onPressed: _busy ? null : _post,
                  )
                else
                  Text(l.reconcileManagerOnly, style: Dg.typeCaption()),
              ],
            ],
          ],
        );
      },
    );
  }
}
