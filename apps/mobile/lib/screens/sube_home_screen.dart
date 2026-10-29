import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/branch_models.dart';
import '../brand.dart';
import '../intro_tour.dart';
import '../l10n.dart';
import '../motion.dart';
import '../session.dart';
import '../shell_nav.dart';
import '../theme.dart';
import '../widgets.dart';
import 'sube_dispatch_screen.dart';
import 'sube_eod_screen.dart';
import 'sube_inbox_screen.dart';
import 'sube_performance_screen.dart';
import 'sube_stock_screen.dart';
import 'sube_widgets.dart';

/// Ana Şube Dashboard: günün operasyonu tek ekranda. Her kart ilgili
/// filtreli listeye açılır; sunucunun vermediği sayı gösterilmez.
class SubeHomeScreen extends ConsumerStatefulWidget {
  const SubeHomeScreen({super.key});

  @override
  ConsumerState<SubeHomeScreen> createState() => _SubeHomeScreenState();
}

class _SubeHomeScreenState extends ConsumerState<SubeHomeScreen> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _shipments(String filter) =>
      ref.read(subeNavProvider).go(SubeNav.shipments, filter: filter);

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  Future<void> _transferSheet() async {
    final l = context.l10n;
    final pick = await showModalBottomSheet<int>(
      context: context,
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
    final couriers = d?.courierList ?? const <BranchCourierLive>[];
    final couriersOut = couriers
        .where((c) => c.liveStatus == 'ACTIVE' && c.holdingCount > 0)
        .length;
    final unread = (branch.inbox ?? const []).where((i) => !i.read).length;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: branch.refresh,
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            _HeroHeader(
              scroll: _scroll,
              userName: s.agencyUser?.fullName ?? '',
              branchName: d?.branchName.isNotEmpty == true
                  ? d!.branchName
                  : s.agencyUser?.agency.name ?? l.subeHome,
              syncedAt: branch.syncedAt,
              total: d?.todayToDeliver,
              delivered: d?.deliveredToday,
              unread: unread,
              loading: branch.loading,
              onInbox: () => _push(const SubeInboxScreen()),
            ),
            const SizedBox(height: 12),
            IntroTourTrigger(
              show: !s.tipsSeen,
              steps: branchIntroSteps(l),
              onDone: s.markTipsSeen,
            ),
            SubeStatusBanner(branch: branch),
            if (d == null)
              branch.loading ? const _DashSkeleton() : const SizedBox.shrink()
            else ...[
              SubeOverline(l.dashToday),
              SubeCardGrid(
                children: [
                  if (kpis != null)
                    SubeKpiCard(
                      icon: LucideIcons.package,
                      label: l.dashTotal,
                      value: kpis.total,
                      tone: KpiTone.brand,
                      onTap: () => _shipments('all'),
                    ),
                  SubeKpiCard(
                    icon: LucideIcons.truck,
                    label: l.dashOut,
                    value: out,
                    tone: KpiTone.brand,
                    onTap: () => _shipments('out'),
                  ),
                  SubeKpiCard(
                    icon: LucideIcons.packageCheck,
                    label: l.dashDelivered,
                    value: d.deliveredToday,
                    tone: KpiTone.ok,
                    onTap: () => _push(const SubePerformanceScreen()),
                  ),
                  if (kpis != null)
                    SubeKpiCard(
                      icon: LucideIcons.userPlus,
                      label: l.dashAwaitCourier,
                      value: kpis.unassigned,
                      tone: KpiTone.warn,
                      onTap: () => _shipments('waiting'),
                    ),
                  SubeKpiCard(
                    icon: LucideIcons.triangleAlert,
                    label: l.dashFaulty,
                    value: d.pending,
                    tone: KpiTone.bad,
                    onTap: () => _push(const SubeEodScreen()),
                  ),
                  SubeKpiCard(
                    icon: LucideIcons.undo2,
                    label: l.dashAwaitReturn,
                    value: d.approvalsReturns,
                    tone: KpiTone.warn,
                    onTap: () => _push(const SubeStockScreen()),
                  ),
                ],
              ),
              SubeOverline(
                l.dashLiveOps,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PulseDot(color: Dg.ok, size: 8),
                    const SizedBox(width: 6),
                    Text(l.liveActive, style: Dg.typeCaption()),
                  ],
                ),
              ),
              SubeCardGrid(
                children: [
                  SubeKpiCard(
                    icon: LucideIcons.radio,
                    label: l.dashActiveCouriers,
                    value: d.couriersActive,
                    suffix: ' / ${d.couriersTotal}',
                    tone: KpiTone.ok,
                    onTap: () => ref.read(subeNavProvider).go(SubeNav.couriers),
                  ),
                  SubeKpiCard(
                    icon: LucideIcons.bike,
                    label: l.dashCouriersOut,
                    value: couriersOut,
                    tone: KpiTone.brand,
                    onTap: () => ref.read(subeNavProvider).go(SubeNav.couriers),
                  ),
                  SubeKpiCard(
                    icon: LucideIcons.undo2,
                    label: l.dashAwaitReturn,
                    value: d.approvalsReturns,
                    tone: KpiTone.warn,
                    onTap: () => _push(const SubeStockScreen()),
                  ),
                  SubeKpiCard(
                    icon: LucideIcons.arrowUpFromLine,
                    label: l.dashToCenter,
                    value: d.returnToCenter,
                    tone: KpiTone.neutral,
                    onTap: () => _push(const SubeDispatchScreen()),
                  ),
                ],
              ),
              SubeOverline(l.dashQuick),
              Row(
                children: [
                  Expanded(
                    child: SubeQuickAction(
                      icon: LucideIcons.userPlus,
                      label: l.quickAssign,
                      accent: true,
                      onTap: () => _shipments('waiting'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SubeQuickAction(
                      icon: LucideIcons.undo2,
                      label: l.quickReturn,
                      onTap: () => _push(const SubeStockScreen()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SubeQuickAction(
                      icon: LucideIcons.arrowLeftRight,
                      label: l.quickTransfer,
                      onTap: _transferSheet,
                    ),
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

/// Lacivert marka başlığı: dalga (kaydırmayla paralaks), logo, selam,
/// günün toplamı ve teslim halkası. Temadan bağımsız koyu yüzey.
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.scroll,
    required this.userName,
    required this.branchName,
    required this.syncedAt,
    required this.total,
    required this.delivered,
    required this.unread,
    required this.loading,
    required this.onInbox,
  });

  final ScrollController scroll;
  final String userName;
  final String branchName;
  final DateTime? syncedAt;
  final int? total;
  final int? delivered;
  final int unread;
  final bool loading;
  final VoidCallback onInbox;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final hour = DateTime.now().hour;
    final first = userName.split(' ').first;
    // `todayToDeliver` kalan iş gibi davranıyor (demo: 7 kalan, 19 teslim);
    // oran teslim / (teslim + kalan). Swagger'dan teyit edilmeli.
    final t = total ?? 0;
    final done = delivered ?? 0;
    final all = t + done;
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF16205A), Color(0xFF0D1338), Dg.navy],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ParallaxLayer(
                controller: scroll,
                factor: -0.25,
                child: const BrandWave(alignment: Alignment.bottomRight),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const DijigooWordmark(height: 34, onDark: true),
                      const Spacer(),
                      _InboxButton(unread: unread, onTap: onInbox),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Appear(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          first.isEmpty
                              ? l.greeting(hour)
                              : '${l.greeting(hour)}, $first',
                          style: Dg.ui(
                            size: 22,
                            weight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          branchName,
                          style: Dg.ui(
                            size: 15,
                            weight: FontWeight.w500,
                            color: Dg.mutedOnNight,
                          ),
                        ),
                        if (syncedAt != null)
                          Text(
                            l.lastSyncAt(subeClock(syncedAt!)),
                            style: Dg.ui(size: 13, color: Dg.mutedOnNight),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (total == null)
                              Text(
                                '—',
                                style: Dg.stat(size: 44, color: Colors.white),
                              )
                            else
                              CountUp(
                                t,
                                style: Dg.stat(
                                  size: 44,
                                  weight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              l.kpiToday,
                              style: Dg.ui(
                                size: 14,
                                weight: FontWeight.w500,
                                color: Dg.mutedOnNight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Semantics(
                          label: l.dashDeliveredOf(done, all),
                          excludeSemantics: true,
                          child: FlowProgressRing(
                            progress: all == 0 ? 0 : done / all,
                            size: 84,
                            track: Colors.white.withValues(alpha: 0.12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      all == 0
                                          ? '0%'
                                          : '${(done * 100 / all).round()}%',
                                      style: Dg.stat(
                                        size: 18,
                                        weight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      l.kpiDelivered,
                                      style: Dg.ui(
                                        size: 14,
                                        color: Dg.mutedOnNight,
                                      ).copyWith(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (loading) ...[
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        color: Dg.brandTurquoise,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxButton extends StatelessWidget {
  const _InboxButton({required this.unread, required this.onTap});

  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Semantics(
      button: true,
      label: unread > 0 ? '${l.subeInboxTitle}, $unread' : l.subeInboxTitle,
      excludeSemantics: true,
      child: IconButton(
        onPressed: onTap,
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const DgIcon(LucideIcons.bell, size: 22, color: Colors.white),
            if (unread > 0)
              Positioned(
                top: -4,
                right: -6,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Dg.brandTurquoise,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Dg.navy, width: 2),
                  ),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      fontFamily: Dg.sans,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Dg.navy,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DashSkeleton extends StatelessWidget {
  const _DashSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget box() => const DgSkeleton(height: 118, radius: 20);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          for (var i = 0; i < 3; i++) ...[
            Row(
              children: [
                Expanded(child: box()),
                const SizedBox(width: 12),
                Expanded(child: box()),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
