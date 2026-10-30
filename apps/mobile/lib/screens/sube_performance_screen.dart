import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/branch_models.dart';
import '../branch_features.dart';
import '../l10n.dart';
import '../motion.dart';
import '../session.dart';
import '../theme.dart';
import '../ui/ui.dart';
import '../widgets.dart';
import 'sube_eod_screen.dart';
import 'sube_widgets.dart';

/// Performans & Gün Sonu (mockup 7): bugün / 7 gün / 30 gün, kurye
/// süzgeci, teslim halkası ve oranlar, günlük çubuk grafik, kurye
/// sıralaması; altta gün sonu özeti ve rapora geçiş. Serbest tarih aralığı
/// önerilen `range=custom` ucuna bağlı (docs/15 §4).
class SubePerformanceScreen extends ConsumerStatefulWidget {
  const SubePerformanceScreen({super.key});

  @override
  ConsumerState<SubePerformanceScreen> createState() =>
      _SubePerformanceScreenState();
}

class _SubePerformanceScreenState extends ConsumerState<SubePerformanceScreen> {
  static const _ranges = ['today', '7d', '30d'];
  int _range = 1;
  String? _courierId;

  /// Serbest aralık; seçiliyken çipe yeniden dokunmak aralığı kaldırır.
  DateTimeRange? _custom;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => ref
      .read(sessionProvider)
      .branch
      .loadPerformance(_ranges[_range], from: _custom?.start, to: _custom?.end);

  static const _monthsTr = [
    'Oca',
    'Şub',
    'Mar',
    'Nis',
    'May',
    'Haz',
    'Tem',
    'Ağu',
    'Eyl',
    'Eki',
    'Kas',
    'Ara',
  ];
  static const _monthsEn = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _pct(L10n l, num? v) {
    if (v == null) return '—';
    final n = v.toStringAsFixed(1);
    return l.isEn ? '$n%' : '%${n.replaceAll('.', ',')}';
  }

  /// Sunucunun `2026-01-01` gününü "1 Oca" diye gösterir.
  static String _day(L10n l, String raw) {
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    return '${d.day} ${(l.isEn ? _monthsEn : _monthsTr)[d.month - 1]}';
  }

  Future<void> _customRange() async {
    final branch = ref.read(sessionProvider).branch;
    if (!branch.proposed(BranchFeatures.customDateRange)) {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Dg.surface,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: DgPendingBackend(what: context.l10n.customRangeWhat),
          ),
        ),
      );
      return;
    }
    if (_custom != null) {
      setState(() => _custom = null);
      await _load();
      return;
    }
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      initialDateRange: _custom,
    );
    if (picked == null || !mounted) return;
    setState(() => _custom = picked);
    await _load();
  }

  String _rangeLabel(L10n l, DateTimeRange r) =>
      '${_day(l, r.start.toIso8601String())} – '
      '${_day(l, r.end.toIso8601String())}';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final branch = ref.watch(sessionProvider).branch;
    final loaded = branch.performance;
    final want = _custom == null ? _ranges[_range] : 'custom';
    final p = loaded?.range == want ? loaded : null;
    final couriers = p?.couriers ?? const <CourierPerformance>[];
    final focus = couriers.where((c) => c.courierId == _courierId).firstOrNull;
    final pending = branch.pending;
    return Scaffold(
      appBar: AppBar(title: Text(l.subePerformanceTitle)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            // Serbest aralık seçiliyken hazır aralıklar soluk görünür.
            Opacity(
              opacity: _custom == null ? 1 : 0.5,
              child: DgPillTabs(
                labels: [l.rangeToday, l.range7d, l.range30d],
                index: _range,
                onChanged: (i) {
                  setState(() {
                    _range = i;
                    _custom = null;
                  });
                  _load();
                },
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                DgFilterChip(
                  label: l.filterCourier,
                  value: focus?.name,
                  icon: LucideIcons.bike,
                  onTap: () async {
                    final r = await showDgPicker<String>(
                      context,
                      title: l.filterCourier,
                      allLabel: l.perfCourierAll,
                      options: [
                        for (final c in couriers) (c.courierId, c.name),
                      ],
                      selected: _courierId,
                    );
                    if (r.picked && mounted) {
                      setState(() => _courierId = r.value);
                    }
                  },
                ),
                DgFilterChip(
                  key: const Key('perf-custom-range'),
                  label: l.customRangeWhat,
                  value: _custom == null ? null : _rangeLabel(l, _custom!),
                  icon: LucideIcons.calendarRange,
                  onTap: _customRange,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SubeStatusBanner(branch: branch, onRetry: _load),
            if (p == null)
              if (branch.loading)
                const Column(
                  children: [
                    DgSkeleton(height: 150, radius: 16),
                    SizedBox(height: 12),
                    DgSkeleton(height: 160, radius: 16),
                  ],
                )
              else
                const SizedBox.shrink()
            else ...[
              if (p.truncated)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    l.perfTruncated,
                    style: Dg.ui(size: 13, color: Dg.warn),
                  ),
                ),
              _RatePanel(
                rate: focus?.deliveryRate ?? p.deliveryRate,
                label: l.perfDeliveryRate,
                pct: _pct(l, focus?.deliveryRate ?? p.deliveryRate),
                rows: [
                  (
                    l.perfFirstAttempt,
                    _pct(l, focus?.firstAttemptRate ?? p.firstAttemptRate),
                  ),
                  if (focus == null) (l.perfSla, _pct(l, p.slaCompliance)),
                  if (focus == null)
                    (
                      l.perfAvgMinutes,
                      p.averageDeliveryMinutes == null
                          ? '—'
                          : '${p.averageDeliveryMinutes!.round()}',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _Counters(
                tiles: [
                  DgKpiTile(
                    icon: LucideIcons.packageSearch,
                    tone: DgTone.info,
                    label: l.perfAttempted,
                    value: focus?.shipments ?? p.attemptedShipments,
                  ),
                  DgKpiTile(
                    icon: LucideIcons.packageCheck,
                    tone: DgTone.ok,
                    label: l.kpiDelivered,
                    value: focus?.delivered ?? p.deliveredShipments,
                  ),
                  DgKpiTile(
                    icon: LucideIcons.packageX,
                    tone: DgTone.bad,
                    label: l.perfFailed,
                    value: focus?.failed ?? p.failedAttempts,
                  ),
                  if (focus == null)
                    DgKpiTile(
                      icon: LucideIcons.users,
                      tone: DgTone.accent,
                      label: l.kpiActiveCouriers,
                      value: p.activeCouriers,
                    ),
                ],
              ),
              if (focus == null && p.daily.length > 1) ...[
                const SizedBox(height: 2),
                DgPanel(
                  title: l.perfDaily,
                  child: _DailyBars(
                    days: [
                      for (final d in p.daily)
                        (
                          label: _day(l, d.day),
                          delivered: d.delivered,
                          failed: d.failed,
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              DgPanel(
                title: l.perfByCourier,
                trailing: Text(
                  '${couriers.length}',
                  style: Dg.ui(size: 14, color: Dg.text3),
                ),
                child: couriers.isEmpty
                    ? Text('—', style: Dg.typeCaption())
                    : Column(
                        children: [
                          for (var i = 0; i < couriers.length; i++)
                            _CourierRank(
                              rank: i + 1,
                              courier: couriers[i],
                              rate: _pct(l, couriers[i].deliveryRate),
                              selected: couriers[i].courierId == _courierId,
                              onTap: () => setState(
                                () => _courierId =
                                    _courierId == couriers[i].courierId
                                    ? null
                                    : couriers[i].courierId,
                              ),
                            ),
                        ],
                      ),
              ),
            ],
            const SizedBox(height: 12),
            DgPanel(
              title: l.perfEodTitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SubeEodScreen()),
              ),
              trailing: Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: Dg.text3,
              ),
              child: Row(
                children: [
                  const DgIconBadge(
                    icon: LucideIcons.sunset,
                    tone: DgTone.accent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.perfEodOpen(pending?.endOfDay.length ?? 0),
                          style: Dg.ui(size: 15, weight: FontWeight.w600),
                        ),
                        Text(l.perfEodReport, style: Dg.typeCaption()),
                      ],
                    ),
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

/// Teslim oranı halkası ve yanında ikincil oranlar.
class _RatePanel extends StatelessWidget {
  const _RatePanel({
    required this.rate,
    required this.rows,
    required this.label,
    required this.pct,
  });

  final num? rate;
  final List<(String, String)> rows;
  final String label;
  final String pct;

  @override
  Widget build(BuildContext context) {
    final progress = ((rate ?? 0) / 100).clamp(0.0, 1.0).toDouble();
    return DgPanel(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Semantics(
            label: '$label $pct',
            excludeSemantics: true,
            child: FlowProgressRing(
              progress: progress,
              size: 104,
              track: Dg.hairline,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        pct,
                        style: Dg.stat(size: 22, weight: FontWeight.w700),
                      ),
                      Text(
                        label,
                        style: Dg.ui(
                          size: 14,
                          color: Dg.text3,
                        ).copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final r in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(child: Text(r.$1, style: Dg.typeCaption())),
                        Text(
                          r.$2,
                          style: Dg.ui(size: 15, weight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sayaçlar: iki sütun, satırdaki kutular aynı boyda (yükseklik yazı
/// ölçeğinden; IntrinsicHeight yok).
class _Counters extends StatelessWidget {
  const _Counters({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final height = 24 + MediaQuery.textScalerOf(context).scale(62);
    return Column(
      children: [
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
                  Expanded(
                    child: i + 1 < tiles.length
                        ? tiles[i + 1]
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

typedef _Day = ({String label, int delivered, int failed});

/// Günlük teslim (yeşil) / başarısız (kırmızı) yığılmış çubuklar. Tek
/// CustomPaint; çubuklar açılışta bir kez büyür.
class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.days});

  final List<_Day> days;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final shown = days.length > 14 ? days.sublist(days.length - 14) : days;
    final still = MediaQuery.disableAnimationsOf(context);
    Widget chart(double t) => CustomPaint(
      size: const Size.fromHeight(120),
      painter: _BarsPainter(
        days: shown,
        grow: t,
        ok: Dg.ok,
        bad: Dg.bad,
        grid: Dg.hairline,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepaintBoundary(
          child: still
              ? chart(1)
              : TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: DgMotion.emphasized,
                  curve: DgMotion.enter,
                  builder: (_, t, _) => chart(t),
                ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(shown.first.label, style: Dg.typeCaption()),
            const Spacer(),
            Text(shown.last.label, style: Dg.typeCaption()),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          children: [
            _Legend(color: Dg.ok, label: l.kpiDelivered),
            _Legend(color: Dg.bad, label: l.kpiUndelivered),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Dg.typeCaption()),
      ],
    );
  }
}

class _BarsPainter extends CustomPainter {
  const _BarsPainter({
    required this.days,
    required this.grow,
    required this.ok,
    required this.bad,
    required this.grid,
  });

  final List<_Day> days;
  final double grow;
  final Color ok;
  final Color bad;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    final peak = days
        .map((d) => d.delivered + d.failed)
        .fold<int>(1, (a, b) => a > b ? a : b);
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()
        ..color = grid
        ..strokeWidth = 1,
    );
    final slot = size.width / days.length;
    final bar = (slot * 0.56).clamp(4.0, 22.0);
    final okPaint = Paint()..color = ok;
    final badPaint = Paint()..color = bad;
    for (var i = 0; i < days.length; i++) {
      final d = days[i];
      final x = slot * i + (slot - bar) / 2;
      final okH = size.height * d.delivered / peak * grow;
      final badH = size.height * d.failed / peak * grow;
      final radius = Radius.circular(bar / 3);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, size.height - okH, bar, okH),
          topLeft: badH == 0 ? radius : Radius.zero,
          topRight: badH == 0 ? radius : Radius.zero,
        ),
        okPaint,
      );
      if (badH > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x, size.height - okH - badH, bar, badH),
            topLeft: radius,
            topRight: radius,
          ),
          badPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.grow != grow || old.days != days || old.ok != ok;
}

class _CourierRank extends StatelessWidget {
  const _CourierRank({
    required this.rank,
    required this.courier,
    required this.rate,
    required this.selected,
    required this.onTap,
  });

  final int rank;
  final CourierPerformance courier;
  final String rate;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = courier;
    final share = c.shipments == 0 ? 0.0 : c.delivered / c.shipments;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: DgMotion.quick,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? Dg.action.withValues(alpha: 0.10) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '$rank',
                style: Dg.ui(
                  size: 14,
                  weight: FontWeight.w700,
                  color: Dg.text3,
                ),
              ),
            ),
            InitialsAvatar(name: c.name, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Dg.ui(size: 15, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: share,
                      minHeight: 5,
                      color: Dg.ok,
                      backgroundColor: Dg.hairline,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${l.kpiDelivered} ${c.delivered} · '
                    '${l.kpiUndelivered} ${c.failed}',
                    style: Dg.ui(
                      size: 14,
                      color: Dg.text3,
                    ).copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(rate, style: Dg.ui(size: 15, weight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
