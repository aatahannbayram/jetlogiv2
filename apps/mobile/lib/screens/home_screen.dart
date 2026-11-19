import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../motion.dart';
import '../session.dart';
import '../shell_nav.dart';
import '../theme.dart';
import '../intro_tour.dart';
import '../widgets.dart';
import 'courier_header.dart';
import 'mistakes_screen.dart';
import 'eod_screen.dart';
import 'next_stop_card.dart';
import 'notif_screen.dart';
import 'shell_screen.dart' show RouteScreen;
import 'support_screen.dart';
import 'sync_screen.dart';
import 'training_screen.dart';
import 'zimmet_screen.dart';

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
      appBar: const CourierHeaderBar(),
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
                      _Greeting(session: s),
                      const SizedBox(height: 14),
                      // Şube kuryeye gönderi atadıysa ilk iş okutup kabul
                      // etmek: kabul edilmeden görev listesi boş görünür.
                      if ((s.courierCounts['pendingCustody'] ?? 0) > 0) ...[
                        Pressable(
                          key: const Key('home-pending-custody'),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ZimmetScreen(mode: 'kurye'),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Dg.ok.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Dg.ok),
                            ),
                            child: Row(
                              children: [
                                DgIcon(
                                  LucideIcons.scanLine,
                                  size: 24,
                                  color: Dg.ok,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l.pendingCustodyTitle(
                                          s.courierCounts['pendingCustody']!,
                                        ),
                                        style: Dg.ui(
                                          size: 15,
                                          weight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        l.pendingCustodyBody,
                                        style: Dg.ui(size: 13, color: Dg.ink2),
                                      ),
                                    ],
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
                        const SizedBox(height: 12),
                      ],
                      if (s.pendingMandatoryTrainings > 0) ...[
                        Pressable(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const TrainingScreen(),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Dg.warn.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Dg.warn),
                            ),
                            child: Row(
                              children: [
                                DgIcon(
                                  LucideIcons.graduationCap,
                                  size: 22,
                                  color: Dg.warn,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    l.mandatoryTrainingPending(
                                      s.pendingMandatoryTrainings,
                                    ),
                                    style: Dg.ui(
                                      size: 14,
                                      weight: FontWeight.w600,
                                    ),
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
                        const SizedBox(height: 12),
                      ],
                      _HomeDashboard(
                        session: s,
                        onOpen: (filter) {
                          if (filter == 'faulty') {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const MistakesScreen(),
                              ),
                            );
                            return;
                          }
                          ref.read(shellNavProvider).openList(filter);
                        },
                      ),
                      const SizedBox(height: 18),
                      const _QuickActions(),
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

/// K01 üst kart: avatar, selam ve vardiya durumu.
class _Greeting extends StatelessWidget {
  const _Greeting({required this.session});

  final SessionController session;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final name = session.courier.fullName.trim();
    final first = name.isEmpty ? '' : name.split(RegExp(r'\s+')).first;
    final active = session.online && session.shiftOpen;
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Dg.surface2,
            border: Border.all(color: Dg.plum, width: 1.5),
          ),
          child: DgIcon(
            LucideIcons.user,
            size: 24,
            color: Dg.warn,
            weight: 500,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                first.isEmpty ? l.homeHello : l.homeHelloName(first),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Dg.ui(size: 18, weight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                session.shiftOpen ? l.homeSubtitle : l.shiftSelfieNeeded,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Dg.ui(size: 13, color: Dg.ink2, height: 1.3),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: active ? l.homeActive : l.homePassive,
          child: Pressable(
            onTap: session.shiftOpen ? session.toggleOnline : session.openShift,
            child: Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (active ? Dg.ok : Dg.ink3).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: active ? Dg.ok : Dg.stroke),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? Dg.ok : Dg.ink3,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    active ? l.homeActive : l.homePassive,
                    style: Dg.ui(
                      size: 14,
                      weight: FontWeight.w700,
                      color: active ? Dg.ok : Dg.ink2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// K01 sayaçları: 2 sütun, altta tam genişlikte "İş Ortağına getirilecek".
/// Vardiya kapalıyken de görünür. Dokununca liste o süzgeçle açılır.
class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({required this.session, required this.onOpen});

  final SessionController session;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tiles = <(String, String, int, IconData, Color)>[
      (
        'awaiting',
        l.dashAwaiting,
        session.shownDash('awaitingDelivery', 'awaiting'),
        LucideIcons.package,
        Dg.warn,
      ),
      // Toplantı kararı: "Randevulu" yerine kontrolde eksik/hatalı
      // bulunan işler (reddedilen fotoğraf ve evrak). Dokununca Hatalarım.
      (
        'faulty',
        l.dashFaultyShort,
        session.photoMistakes?.unacknowledged ?? 0,
        LucideIcons.fileWarning,
        Dg.plum,
      ),
      (
        'out',
        l.dashOut,
        session.shownDash('outForDelivery', 'out'),
        LucideIcons.truck,
        Dg.brand,
      ),
      (
        'overdue',
        l.dashOverdue,
        session.shownDash('overdue', 'overdue'),
        LucideIcons.clock,
        Dg.bad,
      ),
      (
        'delivered',
        l.dashDelivered,
        session.shownDash('deliveredToday', 'delivered'),
        LucideIcons.shieldCheck,
        Dg.ok,
      ),
      (
        'failed',
        l.dashFailed,
        session.shownDash('failedToday', 'failed'),
        LucideIcons.circleX,
        Dg.bad,
      ),
    ];
    final branch = (
      'branch',
      l.dashToBranch,
      session.shownDash('toReturnToBranch', 'branch'),
      LucideIcons.building2,
      Dg.ink2,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < tiles.length; i += 2) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _DashTile(tile: tiles[i], onOpen: onOpen),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DashTile(tile: tiles[i + 1], onOpen: onOpen),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        _DashTile(tile: branch, onOpen: onOpen, wide: true),
      ],
    );
  }
}

class _DashTile extends StatelessWidget {
  const _DashTile({
    required this.tile,
    required this.onOpen,
    this.wide = false,
  });

  final (String, String, int, IconData, Color) tile;
  final ValueChanged<String> onOpen;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final (filter, label, value, icon, color) = tile;
    // Renk yalnız dikkat isteyen kutuda: gecikme, olmayan teslim, eksik.
    final alert =
        (filter == 'overdue' || filter == 'failed' || filter == 'faulty') &&
        value > 0;
    final accent = alert ? (filter == 'faulty' ? Dg.warn : Dg.bad) : null;
    final number = CountUp(
      value,
      style: Dg.stat(
        size: wide ? 24 : 28,
        weight: FontWeight.w700,
        color: accent ?? (value == 0 ? Dg.ink3 : Dg.ink),
      ),
    );
    final head = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: DgIcon(icon, size: 15, color: accent ?? Dg.ink3),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Dg.ui(size: 13, weight: FontWeight.w500, color: Dg.ink2),
          ),
        ),
        DgIcon(LucideIcons.chevronRight, size: 16, color: Dg.ink3),
      ],
    );
    return Semantics(
      button: true,
      label: '$label $value',
      excludeSemantics: true,
      child: Pressable(
        onTap: () => onOpen(filter),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: Dg.card(radius: 16).copyWith(
            border: Border.all(
              color: alert ? accent!.withValues(alpha: 0.45) : Dg.cardEdge,
            ),
          ),
          child: wide
              ? Row(
                  children: [
                    DgIcon(icon, size: 16, color: Dg.ink3),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        style: Dg.ui(size: 14, weight: FontWeight.w600),
                      ),
                    ),
                    number,
                    const SizedBox(width: 6),
                    DgIcon(LucideIcons.chevronRight, size: 16, color: Dg.ink3),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [head, const SizedBox(height: 6), number],
                ),
        ),
      ),
    );
  }
}

/// K01 "Hızlı İşlemler": Görevlerim, Rota, Destek, Eğitim.
class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    void push(Widget page) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => page));
    final items = <(IconData, String, VoidCallback, Color)>[
      (
        LucideIcons.listTodo,
        l.homeMyTasks,
        () => ref.read(shellNavProvider).go(ShellNav.route),
        Dg.warn,
      ),
      (LucideIcons.mapPin, l.route, () => push(const RouteScreen()), Dg.plum),
      (
        LucideIcons.headset,
        l.homeSupport,
        () => push(const SupportScreen()),
        Dg.warn,
      ),
      (
        LucideIcons.graduationCap,
        l.homeTraining,
        () => push(const TrainingScreen()),
        Dg.plum,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            DgIcon(LucideIcons.zap, size: 18, color: Dg.warn, weight: 600),
            const SizedBox(width: 6),
            Text(l.homeQuick, style: Dg.ui(size: 16, weight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final (i, (icon, label, onTap, color)) in items.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  button: true,
                  label: label,
                  excludeSemantics: true,
                  child: Pressable(
                    onTap: onTap,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 76),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Dg.surface1,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Dg.hairline),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          DgIcon(icon, size: 24, color: color, weight: 500),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              label,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              style: Dg.ui(size: 12, weight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
