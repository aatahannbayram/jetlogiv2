import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../brand.dart';
import '../l10n.dart';
import '../motion.dart';
import '../session.dart';
import '../shell_nav.dart';
import '../theme.dart';
import '../intro_tour.dart';
import '../widgets.dart';
import 'mistakes_screen.dart';
import 'profile_screen.dart';
import 'eod_screen.dart';
import 'next_stop_card.dart';
import 'notif_screen.dart';
import 'shell_screen.dart' show RouteScreen;
import 'sync_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _startShift(BuildContext context, SessionController s) async {
    s.openShift();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    if (!s.shiftOpen && s.bypassShiftGate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        s.ensureOpenForTest();
      });
    }
    final l = context.l10n;
    final hero = s.nextStop;
    final syncTotal = s.outbox.events.where((e) => e.pending).length;
    final syncDone = syncTotal == 0;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => s.refreshField(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(0, 8, 0, Dg.bottomNavClearance),
            children: [
              Appear(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Dg.pagePad),
                  child: Column(
                    children: [
                      // Üst alan tek parça: logo, durum ve bildirim üstte;
                      // altında küçük profil satırı (dokununca profil açılır).
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 6, 6, 12),
                        decoration: BoxDecoration(
                          color: Dg.surface,
                          borderRadius: BorderRadius.circular(Dg.rLg),
                          boxShadow: Dg.cardShadow,
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                DijigooWordmark(height: 22, onDark: Dg.dark),
                                const Spacer(),
                                DgOnlineChip(
                                  online: s.online && s.shiftOpen,
                                  onTap: s.shiftOpen ? s.toggleOnline : () {},
                                ),
                                const SizedBox(width: 2),
                                IconButton(
                                  onPressed: () => ref
                                      .read(shellNavProvider)
                                      .go(ShellNav.notif),
                                  icon: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      DgIcon(
                                        LucideIcons.bell,
                                        size: 22,
                                        color: Dg.ink,
                                      ),
                                      if (s.unreadNotifCount > 0)
                                        Positioned(
                                          top: -2,
                                          right: -3,
                                          child: Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: Dg.warn,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const ProfileScreen(),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: Row(
                                  children: [
                                    InitialsAvatar(
                                      name: s.courier.fullName,
                                      photoUrl: s.courier.photoUrl,
                                      online: s.online,
                                      size: 32,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text.rich(
                                        TextSpan(
                                          text: s.courier.fullName,
                                          children: [
                                            TextSpan(
                                              text:
                                                  '  ·  ${s.courier.district} / ${s.courier.city}',
                                              style: Dg.ui(
                                                size: 13,
                                                color: Dg.ink3,
                                              ),
                                            ),
                                          ],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Dg.ui(
                                          size: 14,
                                          weight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    DgIcon(
                                      LucideIcons.chevronRight,
                                      size: 16,
                                      color: Dg.ink3,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (s.showPanelFieldError)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DgRetryBanner(
                            message: l.panelTasksFailed,
                            retryLabel: l.retryNow,
                            onRetry: () => unawaited(s.loadPanelTasks()),
                          ),
                        ),
                      if (s.shiftOpen) _DaySummary(session: s),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // İlk girişte kısa tanıtım; bir kez gösterilir.
              IntroTourTrigger(
                show: !s.tipsSeen,
                steps: courierIntroSteps(l),
                onDone: s.markTipsSeen,
              ),
              if (s.shiftOpen) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Dg.pagePad),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.nextStop,
                          style: Dg.ui(size: 16, weight: FontWeight.w700),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const RouteScreen(),
                          ),
                        ),
                        child: DgTapTarget(
                          child: Text(
                            l.seeRoute,
                            style: Dg.ui(
                              size: 14,
                              weight: FontWeight.w600,
                              color: Dg.ink2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Dg.pagePad),
                  child: hero != null
                      ? const NextStopPager()
                      : const _NoStopCard(),
                ),
                const SizedBox(height: 16),
              ],
              Appear(
                delay: const Duration(milliseconds: 40),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Dg.pagePad),
                  child: !s.shiftOpen
                      ? _ShiftClosedCard(onStart: () => _startShift(context, s))
                      : _ShiftOpenCard(session: s),
                ),
              ),
              // Her şey gönderildiyse satır hiç görünmez; yalnız kuryenin
              // bilmesi gereken bir şey varken çıkar.
              if (!syncDone) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Dg.pagePad),
                  child: Pressable(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SyncScreen(),
                      ),
                    ),
                    child: DgCard(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Row(
                        children: [
                          DgIcon(
                            LucideIcons.clock,
                            size: 18,
                            color: Dg.mid,
                            weight: 500,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l.waitingToSend(syncTotal),
                              style: Dg.ui(size: 15, weight: FontWeight.w600),
                            ),
                          ),
                          DgIcon(
                            LucideIcons.chevronRight,
                            size: 18,
                            color: Dg.ink3,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              if (s.photoMistakes != null) ...[
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Dg.pagePad),
                  child: PhotoScoreCard(
                    data: s.photoMistakes!,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MistakesScreen(),
                      ),
                    ),
                  ),
                ),
              ],
              if (s.visibleNotifications.isNotEmpty) ...[
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Dg.pagePad),
                  child: Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              l.notifications,
                              style: Dg.ui(size: 16, weight: FontWeight.w700),
                            ),
                            if (s.unreadNotifCount > 0) ...[
                              Text(
                                l.unreadLeft(s.unreadNotifCount),
                                style: Dg.ui(size: 13, color: Dg.ink3),
                              ),
                            ],
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            ref.read(shellNavProvider).go(ShellNav.notif),
                        child: DgTapTarget(
                          child: Text(
                            l.all,
                            style: Dg.ui(
                              size: 14,
                              weight: FontWeight.w700,
                              color: Dg.brand,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Dg.pagePad),
                  child: DgCard(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                    child: Column(
                      children: [
                        for (final (i, n)
                            in s.visibleNotifications.take(2).indexed) ...[
                          if (i > 0) const DgDivider(),
                          StaggerIn(
                            index: i,
                            child: NotifCard(
                              notification: n,
                              unread: !s.isNotifRead(n.id),
                              compact: true,
                              onTap: () => openAppNotification(context, s, n),
                              onLongPress: () {
                                if (s.isNotifRead(n.id)) {
                                  s.markNotificationUnread(n.id);
                                } else {
                                  s.markNotificationRead(n.id);
                                }
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ShiftClosedCard extends StatelessWidget {
  const _ShiftClosedCard({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return DgCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Dg.amberBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DgIcon(
                  LucideIcons.sun,
                  size: 18,
                  color: Dg.warn,
                  weight: 600,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                context.l10n.shiftStatus,
                style: Dg.ui(size: 12, weight: FontWeight.w600, color: Dg.ink3),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.closed,
            style: Dg.serif(size: 32, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.shiftSelfieNeeded,
            style: Dg.ui(size: 15, color: Dg.ink2, height: 1.4),
          ),
          const SizedBox(height: 16),
          DgButton(
            label: context.l10n.startShiftCta,
            tone: DgButtonTone.brand,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}

class _ShiftOpenCard extends StatelessWidget {
  const _ShiftOpenCard({required this.session});
  final SessionController session;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final plan = session.routePlan;
    final km = plan == null
        ? null
        : (plan.totalDistanceMeters / 1000).toStringAsFixed(1);
    return DgCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: Dg.ok, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.shiftOpen,
                      style: Dg.ui(size: 15, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      km == null
                          ? l.sinceFrom(session.shiftStartLabel)
                          : l.shiftDayLine(session.shiftStartLabel, km),
                      style: Dg.ui(size: 12, color: Dg.ink3),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const EodScreen()),
                ),
                child: Row(
                  children: [
                    DgIcon(
                      LucideIcons.moon,
                      size: 14,
                      color: Dg.text3,
                      weight: 500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l.eodTitle,
                      style: Dg.ui(
                        size: 13,
                        weight: FontWeight.w600,
                        color: Dg.text2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoStopCard extends StatelessWidget {
  const _NoStopCard();

  @override
  Widget build(BuildContext context) {
    return DgCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Row(
        children: [
          DgIconChip(icon: LucideIcons.packageCheck, accent: false),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.noNextStop,
                  style: Dg.ui(size: 16, weight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.noOpenTasksLeft,
                  style: Dg.ui(size: 14, color: Dg.ink2, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Günün özeti, en üstte: kaç durak kaldı, ne kadarı bitti (çubuk) ve
/// dikkat isteyenler (renkli etiketler).
class _DaySummary extends StatelessWidget {
  const _DaySummary({required this.session});
  final SessionController session;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final open = session.orderedOpenTasks.length;
    final done = session.deliveredCount + session.returnCount;
    final total = open + done;
    final chips = [
      if (session.slaRiskCount > 0)
        (l.lateCount(session.slaRiskCount), Dg.hiBg, Dg.hi),
      if (session.appointmentCount > 0)
        (l.apptCount(session.appointmentCount), Dg.surface2, Dg.text2),
      if (session.returnCount > 0)
        (l.toBranchCount(session.returnCount), Dg.surface2, Dg.text2),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CountUp(open, style: Dg.stat(size: 44, color: Dg.ink)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.kpiLeftHint,
                      style: Dg.ui(size: 16, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    // Biten sayısı ve dikkat isteyenler aynı satırda;
                    // sığmazsa alta iner.
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          l.doneOf(done, total),
                          style: Dg.ui(size: 13, color: Dg.ink3),
                        ),
                        for (final (text, bg, fg) in chips)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              text,
                              style: Dg.ui(
                                size: 12,
                                weight: FontWeight.w600,
                                color: fg,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Günün ilerlemesi: dolan kısım biten duraklar.
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: Dg.surface2),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: total == 0 ? 0 : done / total,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(gradient: Dg.primaryGradient),
                    ),
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
