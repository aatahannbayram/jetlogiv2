import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../branch_workspace.dart';
import '../l10n.dart';
import '../motion.dart';
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
  const SubeKpiGrid(
    this.tiles, {
    super.key,
    this.attention = false,
    this.icons = const [],
    this.onTapTile,
  });

  /// Verilirse kutuya dokununca etiketiyle çağrılır.
  final void Function(String label)? onTapTile;

  /// Kutularla aynı sırada ikonlar; eksik olan kutu ikonsuz kalır.
  final List<IconData> icons;

  final List<(String, String)> tiles;

  /// İlgi bekleyen işler: sıfır olmayan sayılar kehribar yazılır.
  final bool attention;

  Color? _tint(String value) => attention && value != '0' ? Dg.warn : null;

  /// İkon ve rengi etiketten bulunur; böylece her ekrandaki sayı kutusu
  /// aynı kavram için aynı ikonu ve rengi taşır. Yeşil olumlu, kırmızı
  /// olumsuz, kehribar bekleyen, mor bilgi.
  (IconData, Color)? _badge(int i, L10n l) {
    final known = <String, (IconData, Color)>{
      l.kpiToday: (LucideIcons.truck, Dg.plum),
      l.kpiDelivered: (LucideIcons.packageCheck, Dg.ok),
      l.kpiAssigned: (LucideIcons.handshake, Dg.plum),
      l.kpiWaiting: (LucideIcons.packageSearch, Dg.warn),
      l.kpiCancelled: (LucideIcons.packageX, Dg.bad),
      l.kpiReturnToCenter: (LucideIcons.warehouse, Dg.plum),
      l.kpiUrgent: (LucideIcons.flame, Dg.bad),
      l.kpiPendingOps: (LucideIcons.listTodo, Dg.warn),
      l.kpiActiveCouriers: (LucideIcons.bike, Dg.ok),
      l.kpiAwaitAccept: (LucideIcons.userCheck, Dg.warn),
      l.kpiAwaitReturn: (LucideIcons.undo2, Dg.warn),
      l.kpiOpen: (LucideIcons.circleDashed, Dg.warn),
      l.filterLate: (LucideIcons.alarmClockOff, Dg.bad),
      l.perfDeliveryRate: (LucideIcons.chartNoAxesCombined, Dg.ok),
      l.perfFirstAttempt: (LucideIcons.target, Dg.ok),
      l.perfSla: (LucideIcons.timer, Dg.plum),
      l.perfAvgMinutes: (LucideIcons.hourglass, Dg.plum),
      l.perfAttempted: (LucideIcons.package, Dg.plum),
      l.perfFailed: (LucideIcons.packageX, Dg.bad),
      l.onShiftNow: (LucideIcons.userCheck, Dg.ok),
      l.plannedLabel: (LucideIcons.calendarClock, Dg.plum),
      l.plannedNotStarted: (LucideIcons.circleAlert, Dg.warn),
      l.onLeaveLabel: (LucideIcons.palmtree, Dg.plum),
    };
    final hit = known[tiles[i].$1];
    if (hit != null) return hit;
    return i < icons.length ? (icons[i], Dg.plum) : null;
  }

  @override
  Widget build(BuildContext context) {
    // Büyük yazıda kutular tek sütuna iner.
    final columns = MediaQuery.textScalerOf(context).scale(14) > 20 ? 1 : 2;
    final l = context.l10n;
    return Column(
      children: [
        for (var i = 0; i < tiles.length; i += columns) ...[
          // Uzun etiket iki satıra inse de yan yana kutular aynı boyda kalır.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StatTile(
                  label: tiles[i].$1,
                  value: tiles[i].$2,
                  valueColor: _tint(tiles[i].$2),
                  icon: _badge(i, l)?.$1,
                  iconColor: _badge(i, l)?.$2,
                  onTap: onTapTile == null
                      ? null
                      : () => onTapTile!(tiles[i].$1),
                ),
                if (columns == 2) ...[
                  const SizedBox(width: 12),
                  if (i + 1 < tiles.length)
                    StatTile(
                      label: tiles[i + 1].$1,
                      value: tiles[i + 1].$2,
                      valueColor: _tint(tiles[i + 1].$2),
                      icon: _badge(i + 1, l)?.$1,
                      iconColor: _badge(i + 1, l)?.$2,
                      onTap: onTapTile == null
                          ? null
                          : () => onTapTile!(tiles[i + 1].$1),
                    )
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

enum KpiTone { neutral, brand, ok, warn, bad }

Color kpiToneColor(KpiTone tone) => switch (tone) {
  KpiTone.neutral => Dg.text2,
  KpiTone.brand => Dg.highlight,
  KpiTone.ok => Dg.ok,
  KpiTone.warn => Dg.warn,
  KpiTone.bad => Dg.bad,
};

/// Dashboard kartı: ikon + sayı (değişince sayar) + etiket. Dokununca
/// ilgili filtreli listeye gider. Sıfırdan büyük uyarı/hata kartı tonunu
/// kenar şeridiyle de gösterir (yalnız renge dayanmaz: ikon + metin).
class SubeKpiCard extends StatelessWidget {
  const SubeKpiCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.tone = KpiTone.neutral,
    this.suffix = '',
    this.onTap,
  });

  final IconData icon;
  final String label;
  final int value;
  final String suffix;
  final KpiTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = kpiToneColor(tone);
    final alert = value > 0 && (tone == KpiTone.warn || tone == KpiTone.bad);
    final card = Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      decoration: BoxDecoration(
        color: Dg.surface1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: alert ? color.withValues(alpha: 0.45) : Dg.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: Dg.dark ? 0.16 : 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DgIcon(icon, size: 17, color: color, weight: 600),
              ),
              const Spacer(),
              if (onTap != null)
                DgIcon(LucideIcons.chevronRight, size: 16, color: Dg.text3),
            ],
          ),
          const SizedBox(height: 12),
          CountUp(
            value,
            suffix: suffix,
            style: Dg.stat(size: 28, weight: FontWeight.w700, color: Dg.text1),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Dg.ui(size: 14, weight: FontWeight.w500, color: Dg.text2),
          ),
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      label: '$label: $value$suffix',
      excludeSemantics: true,
      child: onTap == null ? card : Pressable(onTap: onTap!, child: card),
    );
  }
}

/// İkişerli kart ızgarası; büyük yazıda tek sütun.
class SubeCardGrid extends StatelessWidget {
  const SubeCardGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final columns = MediaQuery.textScalerOf(context).scale(14) > 20 ? 1 : 2;
    return Column(
      children: [
        for (var i = 0; i < children.length; i += columns) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: StaggerIn(index: i, child: children[i]),
                ),
                if (columns == 2) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: i + 1 < children.length
                        ? StaggerIn(index: i + 1, child: children[i + 1])
                        : const SizedBox.shrink(),
                  ),
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

/// Bölüm başlığı (küçük, harf aralıklı) — "CANLI OPERASYON".
class SubeOverline extends StatelessWidget {
  const SubeOverline(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final locale = context.l10n.code;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              localeUpper(text, locale),
              style: Dg.typeOverline(color: Dg.text3),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Hızlı işlem düğmesi: büyük ikon + etiket, basınca küçülür.
class SubeQuickAction extends StatelessWidget {
  const SubeQuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          decoration: BoxDecoration(
            color: accent ? Dg.action : Dg.surface1,
            gradient: accent ? Dg.primaryGradient : null,
            borderRadius: BorderRadius.circular(20),
            border: accent ? null : Border.all(color: Dg.hairline),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DgIcon(
                icon,
                size: 26,
                weight: 500,
                color: accent ? Dg.onAction : Dg.highlight,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: Dg.ui(
                  size: 14,
                  weight: FontWeight.w600,
                  color: accent ? Dg.onAction : Dg.text1,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Liste satırı: renkli ikon rozeti + başlık + alt satır + ok.
class SubeNavTile extends StatelessWidget {
  const SubeNavTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.tint,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Color? tint;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = tint ?? Dg.highlight;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Dg.rowMin),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: Dg.dark ? 0.16 : 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DgIcon(icon, size: 19, color: color, weight: 500),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: Dg.typeBody(weight: FontWeight.w600)),
                      if (subtitle != null)
                        Text(subtitle!, style: Dg.typeCaption()),
                    ],
                  ),
                ),
                ?trailing,
                const SizedBox(width: 6),
                DgIcon(LucideIcons.chevronRight, size: 18, color: Dg.text3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Yüzey kartı içinde gruplanmış satırlar (İşlemler, Profil).
class SubeGroup extends StatelessWidget {
  const SubeGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      decoration: BoxDecoration(
        color: Dg.surface1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Dg.hairline),
      ),
      child: Column(children: children),
    );
  }
}
