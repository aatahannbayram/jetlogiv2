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
import '../coach.dart';
import '../widgets.dart';
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
            padding: const EdgeInsets.fromLTRB(
              0,
              8,
              0,
              Dg.bottomNavClearance,
            ),
            children: [
              Appear(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Dg.pagePad),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          DijigooWordmark(height: 26, onDark: Dg.dark),
                          const Spacer(),
                          DgOnlineChip(
                            online: s.online && s.shiftOpen,
                            onTap: s.shiftOpen ? s.toggleOnline : () {},
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () =>
                                ref.read(shellNavProvider).go(ShellNav.notif),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                DgIcon(LucideIcons.bell, size: 22, color: Dg.ink),
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
                      Row(
                        children: [
                          InitialsAvatar(
                            name: s.courier.fullName,
                            photoUrl: s.courier.photoUrl,
                            online: s.online,
                            size: 44,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.greeting(DateTime.now().hour),
                                  style: Dg.ui(size: 12, color: Dg.ink3),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  s.courier.fullName,
                                  style: Dg.ui(
                                    size: 17,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${s.courier.district} / ${s.courier.city}',
                                  style: Dg.ui(size: 12, color: Dg.ink2),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (!s.tipsSeen)
                Padding(
                  padding: const EdgeInsets.fromLTRB(Dg.pagePad, 0, Dg.pagePad, 12),
                  child: CoachBanner(
                    title: l.tipHomeTitle,
                    body: l.tipHomeBody,
                    onDismiss: s.markTipsSeen,
                  ),
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
                        child: Text(
                          l.seeRoute,
                          style: Dg.ui(
                            size: 14,
                            weight: FontWeight.w700,
                            color: Dg.purpleActive,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Dg.pagePad,
                  ),
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
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Dg.pagePad),
                child: Pressable(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const SyncScreen()),
                  ),
                  child: DgCard(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: syncDone ? Dg.greenBg : Dg.violetBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: DgIcon(
                            LucideIcons.refreshCw,
                            size: 16,
                            color: syncDone ? Dg.ok : Dg.brand,
                            weight: 600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l.syncTitle,
                            style: Dg.ui(size: 15, weight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          syncDone ? l.clean : l.pendingChip(syncTotal),
                          style: Dg.ui(
                            size: 13,
                            weight: FontWeight.w600,
                            color: syncDone ? Dg.ink2 : Dg.purpleActive,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (s.visibleNotifications.isNotEmpty) ...[
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Dg.pagePad),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              l.notifications,
                              style: Dg.ui(size: 16, weight: FontWeight.w700),
                            ),
                            if (s.unreadNotifCount > 0) ...[
                              const SizedBox(width: 8),
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
                        child: Text(
                          l.all,
                          style: Dg.ui(
                            size: 14,
                            weight: FontWeight.w700,
                            color: Dg.brand,
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
                              onTap: () =>
                                  openAppNotification(context, s, n),
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
                child: DgIcon(LucideIcons.sun, size: 18, color: Dg.warn, weight: 600),
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
                decoration: BoxDecoration(
                  color: Dg.sage,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.shiftOpen,
                  style: Dg.ui(size: 13, weight: FontWeight.w600),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const EodScreen()),
                ),
                child: Row(
                  children: [
                    DgIcon(LucideIcons.moon, size: 15, color: Dg.brand),
                    const SizedBox(width: 6),
                    Text(
                      l.eodTitle,
                      style: Dg.ui(
                        size: 13,
                        weight: FontWeight.w700,
                        color: Dg.purpleActive,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            km == null
                ? l.sinceFrom(session.shiftStartLabel)
                : l.shiftDayLine(session.shiftStartLabel, km),
            style: Dg.ui(size: 12, color: Dg.ink3),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CountUp(
                      session.remainingCount,
                      style: Dg.stat(size: 40, color: Dg.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(l.kpiLeftHint, style: Dg.ui(size: 14, color: Dg.ink2)),
                  ],
                ),
              ),
              DgProgressRing(
                size: 64,
                progress: session.deliveredCount + session.remainingCount == 0
                    ? 1
                    : session.deliveredCount /
                          (session.deliveredCount + session.remainingCount),
                child: Text(
                  session.deliveredCount + session.remainingCount == 0
                      ? '—'
                      : '${((session.deliveredCount / (session.deliveredCount + session.remainingCount)) * 100).round()}%',
                  style: Dg.typeNum(size: 12, weight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _cell(session.openCount, l.kpiOnMe),
              _cell(session.deliveredCount, l.delivered),
              _cell(session.returnCount, l.kpiFailed),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _flag(
                l.kpiAppt,
                session.appointmentCount,
                hot: session.appointmentCount > 0,
                hotColor: Dg.sand,
                hotBg: Dg.midBg,
              ),
              _flag(
                l.kpiSla,
                session.slaRiskCount,
                hot: session.slaRiskCount > 0,
                hotColor: Dg.clay,
                hotBg: Dg.hiBg,
              ),
              _flag(
                l.kpiReturn,
                session.returnCount,
                hot: session.returnCount > 0,
                hotColor: Dg.amber,
                hotBg: Dg.amberBg,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(int value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CountUp(value, style: Dg.stat(size: 22)),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Dg.ui(size: 12, color: Dg.ink3),
          ),
        ],
      ),
    );
  }

  Widget _flag(
    String label,
    int n, {
    required bool hot,
    required Color hotColor,
    required Color hotBg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: hot ? hotBg : Dg.elev,
        borderRadius: BorderRadius.circular(Dg.radius),
      ),
      child: Text(
        '$n  $label',
        style: Dg.ui(
          size: 12,
          weight: FontWeight.w600,
          color: hot ? hotColor : Dg.ink3,
        ),
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
