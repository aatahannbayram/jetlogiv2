import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../motion.dart';
import '../theme.dart';
import 'status.dart';

/// Kart yüzeyi: çerçevesiz, gölge ve tonla ayrışır. İsteğe bağlı başlık.
class DgPanel extends StatelessWidget {
  const DgPanel({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      width: double.infinity,
      padding: padding,
      decoration: Dg.card(),
      child: title == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title!,
                        style: Dg.ui(size: 15, weight: FontWeight.w700),
                      ),
                    ),
                    ?trailing,
                  ],
                ),
                const SizedBox(height: 10),
                child,
              ],
            ),
    );
    if (onTap == null) return body;
    return Pressable(onTap: onTap!, child: body);
  }
}

/// Sayfa başlığı (üst barın altında): büyük başlık + isteğe bağlı alt satır.
class DgPageTitle extends StatelessWidget {
  const DgPageTitle(this.title, {super.key, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Dg.ui(size: 24, weight: FontWeight.w700, height: 1.15),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: Dg.typeCaption()),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// KPI kutusu (mockup): solda dolu renkli ikon dairesi, sağda sayı ve
/// etiket. Değer yoksa (sunucu vermiyorsa) "—" yazar; uydurmaz.
class DgKpiTile extends StatelessWidget {
  const DgKpiTile({
    super.key,
    required this.icon,
    required this.tone,
    required this.label,
    required this.value,
    this.suffix = '',
    this.onTap,
  });

  final IconData icon;
  final DgTone tone;
  final String label;
  final int? value;
  final String suffix;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final number = value == null
        ? Text('—', style: Dg.stat(size: 24, color: Dg.text3))
        : CountUp(
            value!,
            suffix: suffix,
            style: Dg.stat(size: 24, weight: FontWeight.w700, color: Dg.text1),
          );
    return Semantics(
      button: onTap != null,
      label: '$label: ${value ?? '—'}$suffix',
      excludeSemantics: true,
      child: DgPanel(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        child: Row(
          children: [
            DgIconBadge(icon: icon, tone: tone, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: number,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Dg.ui(
                      size: 14,
                      weight: FontWeight.w500,
                      color: Dg.text2,
                      height: 1.2,
                    ).copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Adım çubuğu: tamamlanan adımlar dolu, geçerli adım çerçeveli; aradaki
/// çizgi ilerledikçe dolar.
class DgStepper extends StatelessWidget {
  const DgStepper({super.key, required this.steps, required this.current});

  final List<String> steps;
  final int current;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    Widget dot(int i) {
      final done = i < current;
      final now = i == current;
      return AnimatedContainer(
        duration: reduce ? Duration.zero : DgMotion.standard,
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? Dg.action : Dg.surface2,
          border: Border.all(
            color: done || now ? Dg.action : Dg.hairline,
            width: now ? 2 : 1,
          ),
        ),
        child: done
            ? const Icon(LucideIcons.check, size: 14, color: Colors.white)
            : Text(
                '${i + 1}',
                style: Dg.ui(
                  size: 14,
                  weight: FontWeight.w700,
                  color: now ? Dg.highlight : Dg.text3,
                ).copyWith(fontSize: 12),
              ),
      );
    }

    Widget line(int i) => Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Dg.surface2,
          borderRadius: BorderRadius.circular(2),
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: i < current ? 1 : 0),
          duration: reduce ? Duration.zero : const Duration(milliseconds: 360),
          curve: DgMotion.emphasizedCurve,
          builder: (context, t, _) => FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: t,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: Dg.brandFlow,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );

    return RepaintBoundary(
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                dot(i),
                if (i < steps.length - 1) line(i),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < steps.length; i++)
                Expanded(
                  child: Text(
                    steps[i],
                    textAlign: i == 0
                        ? TextAlign.left
                        : i == steps.length - 1
                        ? TextAlign.right
                        : TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Dg.ui(
                      size: 14,
                      weight: i == current ? FontWeight.w700 : FontWeight.w500,
                      color: i <= current ? Dg.text1 : Dg.text3,
                    ).copyWith(fontSize: 11),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Beklenen / Okunan / Eksik / Fazla (/ Hasarlı) özeti.
class DgCountSummary extends StatelessWidget {
  const DgCountSummary({
    super.key,
    required this.expected,
    required this.read,
    this.missing,
    this.extra,
    this.damaged,
  });

  final int expected;
  final int read;
  final int? missing;
  final int? extra;
  final int? damaged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final miss = missing ?? (expected - read).clamp(0, expected);
    final cells = <(String, int, DgTone)>[
      (l.countExpected, expected, DgTone.neutral),
      (l.countRead, read, DgTone.info),
      (l.countMissing, miss, miss > 0 ? DgTone.bad : DgTone.neutral),
      if (extra != null)
        (l.countExtra, extra!, extra! > 0 ? DgTone.warn : DgTone.neutral),
      if (damaged != null)
        (
          l.countDamaged,
          damaged!,
          damaged! > 0 ? DgTone.accent : DgTone.neutral,
        ),
    ];
    return DgPanel(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      child: Row(
        children: [
          for (final c in cells)
            Expanded(
              child: Column(
                children: [
                  CountUp(
                    c.$2,
                    style: Dg.stat(
                      size: 22,
                      weight: FontWeight.w700,
                      color: c.$3 == DgTone.neutral
                          ? Dg.text1
                          : dgToneColor(c.$3),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.$1,
                    textAlign: TextAlign.center,
                    style: Dg.ui(
                      size: 14,
                      color: Dg.text3,
                    ).copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Etiket — değer satırı (detay ekranları).
class DgInfoRow extends StatelessWidget {
  const DgInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.trailing,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Dg.text3),
            const SizedBox(width: 10),
          ],
          SizedBox(width: 104, child: Text(label, style: Dg.typeCaption())),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: Dg.ui(size: 14, weight: FontWeight.w600),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Belge satırı: ikon + ad + alt bilgi + durum hapı.
class DgDocRow extends StatelessWidget {
  const DgDocRow({
    super.key,
    required this.icon,
    required this.title,
    required this.status,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final DgStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Dg.rowMin),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              DgIconBadge(icon: icon, tone: status.tone, size: 36, soft: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Dg.ui(size: 15, weight: FontWeight.w600),
                    ),
                    if (subtitle != null)
                      Text(subtitle!, style: Dg.typeCaption()),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              DgStatusPill.of(status, dense: true),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detay ekranı üst aksiyon ızgarası: ikon kutuları.
class DgActionGrid extends StatelessWidget {
  const DgActionGrid({super.key, required this.items});

  final List<({IconData icon, String label, DgTone tone, VoidCallback? onTap})>
  items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Opacity(
              opacity: items[i].onTap == null ? 0.45 : 1,
              child: DgPanel(
                onTap: items[i].onTap,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 4,
                ),
                child: Column(
                  children: [
                    DgIconBadge(
                      icon: items[i].icon,
                      tone: items[i].tone,
                      size: 38,
                      soft: true,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      items[i].label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: Dg.ui(
                        size: 14,
                        weight: FontWeight.w600,
                        height: 1.15,
                      ).copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Dikey zaman çizelgesi (işlem geçmişi).
class DgTimeline extends StatelessWidget {
  const DgTimeline({super.key, required this.entries});

  final List<({String title, String subtitle, DgTone tone})> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 20,
                  child: Column(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: 5),
                        decoration: BoxDecoration(
                          color: dgToneColor(entries[i].tone),
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (i < entries.length - 1)
                        Expanded(
                          child: Container(width: 2, color: Dg.hairline),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entries[i].title,
                          style: Dg.ui(size: 14, weight: FontWeight.w600),
                        ),
                        Text(entries[i].subtitle, style: Dg.typeCaption()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Dürüst boş durum: uç henüz yok. Sahte veri göstermez.
class DgPendingBackend extends StatelessWidget {
  const DgPendingBackend({super.key, this.what});

  /// Neyin beklendiği (ör. "Cihaz bilgileri").
  final String? what;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DgPanel(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        children: [
          DgIconBadge(
            icon: LucideIcons.cloudCog,
            tone: DgTone.neutral,
            size: 48,
            soft: true,
          ),
          const SizedBox(height: 12),
          Text(
            l.pendingBackendTitle,
            textAlign: TextAlign.center,
            style: Dg.ui(size: 16, weight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            what == null
                ? l.pendingBackendBody
                : l.pendingBackendBodyFor(what!),
            textAlign: TextAlign.center,
            style: Dg.typeCaption(),
          ),
        ],
      ),
    );
  }
}

/// Liste sayfası iskeleti: [header] (başlık, arama, süzgeç) listeyle birlikte
/// yukarı kayar; [pinned] (durum sekmeleri) üstte yapışık kalır. Tek kaydırma
/// alanıdır: sabit üst bölüm ekranın yarısını kaplamaz. Satırlar tembel
/// çizilir (ekrana girmeyen kurulmaz); çekip yenileme tüm sayfada çalışır.
class DgStickyList extends StatelessWidget {
  const DgStickyList({
    super.key,
    this.header = const [],
    this.pinned,
    required this.itemCount,
    required this.itemBuilder,
    this.empty,
    this.onRefresh,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 120),
  });

  final List<Widget> header;
  final Widget? pinned;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// [itemCount] sıfırken listenin yerine gösterilir.
  final Widget? empty;
  final Future<void> Function()? onRefresh;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scroll = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        for (final h in header) SliverToBoxAdapter(child: h),
        if (pinned != null)
          PinnedHeaderSliver(
            child: ColoredBox(
              color: Dg.bg,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: pinned,
              ),
            ),
          ),
        SliverPadding(
          padding: padding,
          sliver: itemCount == 0
              ? SliverToBoxAdapter(child: empty ?? const SizedBox.shrink())
              : SliverList.builder(
                  itemCount: itemCount,
                  itemBuilder: itemBuilder,
                ),
        ),
      ],
    );
    final refresh = onRefresh;
    if (refresh == null) return scroll;
    return RefreshIndicator(onRefresh: refresh, child: scroll);
  }
}
