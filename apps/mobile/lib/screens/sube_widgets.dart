import 'package:flutter/material.dart';

import '../branch_workspace.dart';
import '../l10n.dart';
import '../scan_router.dart';
import '../theme.dart';
import '../widgets.dart';

String subeClock(DateTime at) {
  final t = at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}';
}

void subeSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class SubeSection extends StatelessWidget {
  const SubeSection(this.title, {super.key, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Dg.ui(size: 15, weight: FontWeight.w700)),
          ),
          if (trailing != null)
            Text(trailing!, style: Dg.ui(size: 13, color: Dg.ink3)),
        ],
      ),
    );
  }
}

/// İkişerli KPI ızgarası.
class SubeKpiGrid extends StatelessWidget {
  const SubeKpiGrid(this.tiles, {super.key});

  final List<(String, String)> tiles;

  @override
  Widget build(BuildContext context) {
    // Büyük yazıda kutular tek sütuna iner.
    final columns = MediaQuery.textScalerOf(context).scale(14) > 20 ? 1 : 2;
    return Column(
      children: [
        for (var i = 0; i < tiles.length; i += columns) ...[
          // Uzun etiket iki satıra inse de yan yana kutular aynı boyda kalır.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StatTile(label: tiles[i].$1, value: tiles[i].$2),
                if (columns == 2) ...[
                  const SizedBox(width: 12),
                  if (i + 1 < tiles.length)
                    StatTile(label: tiles[i + 1].$1, value: tiles[i + 1].$2)
                  else
                    const Spacer(),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// Son yenileme hatası + bekleyen okutma sayısı. İkisi de yoksa yer tutmaz.
class SubeStatusBanner extends StatelessWidget {
  const SubeStatusBanner({super.key, required this.branch, this.onRetry});

  final BranchWorkspace branch;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final error = branch.error;
    final waiting = branch.pendingScans;
    if (error == null && waiting == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          if (error != null)
            DgRetryBanner(
              message: error,
              onRetry: onRetry ?? branch.refresh,
              retryLabel: l.retryNow,
            ),
          if (waiting > 0)
            Padding(
              padding: EdgeInsets.only(top: error == null ? 0 : 8),
              child: DgRetryBanner(
                message: l.pendingScans(waiting),
                onRetry: branch.flush,
                retryLabel: l.retryNow,
              ),
            ),
        ],
      ),
    );
  }
}

class ScanOutcomeTile extends StatelessWidget {
  const ScanOutcomeTile({super.key, required this.code, required this.outcome});

  final String code;
  final ScanOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final tone = switch (outcome.tone) {
      ScanTone.ok => 'lo',
      ScanTone.warn => 'mid',
      ScanTone.bad => 'hi',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Mono(code, size: 13, weight: FontWeight.w700),
                if (outcome.detail.isNotEmpty && outcome.detail != code)
                  Text(
                    outcome.detail,
                    style: Dg.ui(size: 12, color: Dg.ink3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusChip(label: outcome.title, tone: tone),
        ],
      ),
    );
  }
}
