import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/branch_models.dart';
import '../brand.dart';
import '../l10n.dart';
import '../models.dart';
import '../motion.dart';
import '../session.dart';
import '../shell_nav.dart';
import '../theme.dart';
import '../ui/ui.dart';
import '../widgets.dart';
import 'sube_count_screen.dart';
import 'sube_courier_map_screen.dart';
import 'sube_dispatch_screen.dart';
import 'sube_header.dart';
import 'sube_performance_screen.dart';
import 'sube_return_flow.dart';
import 'sube_stock_screen.dart';
import 'sube_widgets.dart';

/// Ana Şube Dashboard (mockup 1): şube ve tarih kartı, günün KPI'ları
/// (renkli ikon daireli), canlı operasyon takibi ve hızlı işlemler. Her
/// kutu ilgili filtreli listeye ya da akışa açılır; sunucunun vermediği
/// sayı "—" yazar.
class SubeHomeScreen extends ConsumerStatefulWidget {
  const SubeHomeScreen({super.key});

  @override
  ConsumerState<SubeHomeScreen> createState() => _SubeHomeScreenState();
}

class _SubeHomeScreenState extends ConsumerState<SubeHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionProvider).branch.loadDashExtras();
    });
  }

  void _shipments(String filter) =>
      ref.read(subeNavProvider).go(SubeNav.shipments, filter: filter);

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  Future<void> _transferSheet() async {
    final l = context.l10n;
    final pick = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Dg.surface,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SubeNavTile(
                icon: LucideIcons.arrowDownToLine,
                label: l.transferIncoming,
                onTap: () => Navigator.pop(ctx, 0),
              ),
              SubeNavTile(
                icon: LucideIcons.arrowUpFromLine,
                tint: Dg.violet,
                label: l.transferOutgoing,
                onTap: () => Navigator.pop(ctx, 1),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || pick == null) return;
    _push(pick == 0 ? const SubeStockScreen() : const SubeDispatchScreen());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);
    final branch = s.branch;
    final d = branch.dashboard;
    final kpis = branch.board?.kpis;
    final out = branch.rows
        .where((r) => r.stage == BranchStage.inDistribution)
        .length;
    final first = (s.agencyUser?.fullName ?? '').split(' ').first;
    final hour = DateTime.now().hour;

    return Scaffold(
      appBar: const SubeHeaderBar(),
      body: RefreshIndicator(
        onRefresh: () async {
          await branch.refresh();
          await branch.loadDashExtras();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          children: [
            Appear(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      first.isEmpty
                          ? l.greeting(hour)
                          : '${l.greeting(hour)}, $first',
                      style: Dg.ui(size: 22, weight: FontWeight.w700),
                    ),
                    if (branch.syncedAt != null)
                      Text(
                        l.lastSyncAt(subeClock(branch.syncedAt!)),
                        style: Dg.typeCaption(),
                      ),
                  ],
                ),
              ),
            ),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: _BranchCard(
                      name: d?.branchName.isNotEmpty == true
                          ? d!.branchName
                          : s.agencyUser?.agency.name ?? l.subeHome,
                      code: d?.branchCode ?? '',
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(flex: 2, child: _DateCard()),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SubeStatusBanner(branch: branch),
            if (d == null)
              branch.loading ? const _DashSkeleton() : const SizedBox.shrink()
            else ...[
              _KpiGrid(
                tiles: [
                  DgKpiTile(
                    icon: LucideIcons.package,
                    tone: DgTone.info,
                    label: l.dashTotal,
                    value: kpis?.total,
                    onTap: () => _shipments('all'),
                  ),
                  DgKpiTile(
                    icon: LucideIcons.truck,
                    tone: DgTone.accent,
                    label: l.dashOut,
                    value: out,
                    onTap: () => _shipments('out'),
                  ),
                  DgKpiTile(
                    icon: LucideIcons.packageCheck,
                    tone: DgTone.ok,
                    label: l.dashDelivered,
                    value: d.deliveredToday,
                    onTap: () => _push(const SubePerformanceScreen()),
                  ),
                  DgKpiTile(
                    icon: LucideIcons.userPlus,
                    tone: DgTone.warn,
                    label: l.dashAwaitCourier,
                    value: kpis?.unassigned,
                    onTap: () => _shipments('waiting'),
                  ),
                  DgKpiTile(
                    icon: LucideIcons.packageX,
                    tone: DgTone.bad,
                    label: l.dashFailed,
                    value: branch.todayPerformance?.failedAttempts,
                    onTap: () => _push(const SubePerformanceScreen()),
                  ),
                  DgKpiTile(
                    icon: LucideIcons.undo2,
                    tone: DgTone.neutral,
                    label: l.dashAwaitReturn,
                    value: branch.pending?.returns.length ?? d.approvalsReturns,
                    onTap: () => _push(const SubeReturnFlow()),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _LiveOps(
                couriers: d.courierList,
                onBreak: branch.couriersOnBreak,
                onOpen: () => _push(const SubeCourierMapScreen()),
              ),
              const SizedBox(height: 16),
              SubeOverline(l.dashQuick),
              DgActionGrid(
                items: [
                  (
                    icon: LucideIcons.userPlus,
                    label: l.quickAssign,
                    tone: DgTone.info,
                    onTap: () => _shipments('waiting'),
                  ),
                  (
                    icon: LucideIcons.undo2,
                    label: l.quickReturn,
                    tone: DgTone.accent,
                    onTap: () => _push(const SubeReturnFlow()),
                  ),
                  (
                    icon: LucideIcons.arrowLeftRight,
                    label: l.quickTransfer,
                    tone: DgTone.ok,
                    onTap: _transferSheet,
                  ),
                  (
                    icon: LucideIcons.clipboardList,
                    label: l.quickCount,
                    tone: DgTone.warn,
                    onTap: () => _push(const SubeCountScreen()),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Şube kartı: lacivert marka yüzeyi, dalga, D ikonu, ad ve kod.
class _BranchCard extends StatelessWidget {
  const _BranchCard({required this.name, required this.code});

  final String name;
  final String code;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF16205A), Dg.navy],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: BrandWave(alignment: Alignment.bottomRight),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const DijigooMark(size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          l.dashBranch,
                          style: Dg.ui(
                            size: 14,
                            color: Dg.mutedOnNight,
                          ).copyWith(fontSize: 12),
                        ),
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Dg.ui(
                            size: 16,
                            weight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        if (code.isNotEmpty)
                          Text(
                            l.dashBranchCode(code),
                            style: Dg.ui(
                              size: 14,
                              color: Dg.mutedOnNight,
                            ).copyWith(fontSize: 12),
                          ),
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

class _DateCard extends StatelessWidget {
  const _DateCard();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final now = DateTime.now();
    return DgPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(LucideIcons.calendarDays, size: 16, color: Dg.highlight),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  l.dashToday,
                  style: Dg.ui(
                    size: 14,
                    weight: FontWeight.w600,
                    color: Dg.text2,
                  ).copyWith(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${now.day} ${l.monthName(now.month)}',
              style: Dg.ui(size: 17, weight: FontWeight.w700),
            ),
          ),
          Text(l.weekday(now.weekday % 7), style: Dg.typeCaption()),
        ],
      ),
    );
  }
}

/// KPI kutuları, iki sütun; satırdaki kutular aynı boyda. Yükseklik yazı
/// ölçeğinden hesaplanır (IntrinsicHeight'ın çift ölçümü yok; sayı sayarken
/// her karede yeniden ölçülmez).
class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    // Sayı (24) + iki satır etiket (13) ≈ 62 px içerik, 24 px dolgu.
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
                  Expanded(
                    child: StaggerIn(index: i, child: tiles[i]),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: i + 1 < tiles.length
                        ? StaggerIn(index: i + 1, child: tiles[i + 1])
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

/// Canlı operasyon takip: küçük harita ve durum sayaçları; "Detaylı gör"
/// tam ekran kurye haritasını açar.
class _LiveOps extends StatelessWidget {
  const _LiveOps({
    required this.couriers,
    required this.onBreak,
    required this.onOpen,
  });

  final List<BranchCourierLive> couriers;
  final Set<String> onBreak;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final kinds = {
      for (final c in couriers)
        c.id: courierKind(c, onBreak: onBreak.contains(c.id)),
    };
    int count(CourierKind k) => kinds.values.where((v) => v == k).length;
    final located = [
      for (final c in couriers)
        if (c.located) c,
    ];
    return DgPanel(
      title: l.dashLiveTrack,
      trailing: TextButton(
        key: const Key('live-ops-details'),
        onPressed: onOpen,
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Text(l.seeDetails),
      ),
      child: Column(
        children: [
          if (located.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: onOpen,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: IgnorePointer(
                    child: MapStrip(
                      height: 140,
                      rounded: false,
                      showBadge: false,
                      couriers: [
                        for (final c in located)
                          FleetCourier(
                            id: c.id,
                            name: c.name,
                            lat: c.latitude!,
                            lng: c.longitude!,
                            status: courierPinStatus(kinds[c.id]!),
                          ),
                      ],
                      fitTo: [
                        for (final c in located)
                          LatLng(c.latitude!, c.longitude!),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Row(
            children: [
              for (final k in const [
                CourierKind.out,
                CourierKind.free,
                CourierKind.onBreak,
                CourierKind.offline,
              ])
                Expanded(
                  child: _LiveCount(
                    status: courierStatus(l, k),
                    value: count(k),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveCount extends StatelessWidget {
  const _LiveCount({required this.status, required this.value});

  final DgStatus status;
  final int value;

  @override
  Widget build(BuildContext context) {
    final color = dgToneColor(status.tone);
    return Semantics(
      label: '${status.label}: $value',
      excludeSemantics: true,
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              status.tone == DgTone.info
                  ? PulseDot(color: color, size: 8)
                  : Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
              const SizedBox(width: 6),
              CountUp(value, style: Dg.stat(size: 20, weight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            status.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Dg.ui(size: 14, color: Dg.text3).copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DashSkeleton extends StatelessWidget {
  const _DashSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget box() => const DgSkeleton(height: 72, radius: 16);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        children: [
          for (var i = 0; i < 3; i++) ...[
            Row(
              children: [
                Expanded(child: box()),
                const SizedBox(width: 10),
                Expanded(child: box()),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
