import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../brand.dart';
import '../l10n.dart';
import '../motion.dart';
import '../launchers.dart';
import '../models.dart';
import '../session.dart';
import '../shell_nav.dart';
import '../theme.dart';
import '../widgets.dart';
import 'notif_screen.dart';
import 'shell_screen.dart' show RouteScreen;
import 'sync_screen.dart';
import 'wizard_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _startShift(BuildContext context, SessionController s) async {
    if (s.bypassShiftGate) {
      s.setShiftOpen(true);
      return;
    }
    final ok = await showShiftSelfieSheet(context, onPhoto: s.takeShiftPhoto);
    if (ok) s.setShiftOpen(true);
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
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: Dg.primaryGradient,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const DijigooMark(size: 18, onDark: true),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Dijigoo',
                            style: Dg.ui(
                              size: 18,
                              weight: FontWeight.w700,
                            ).copyWith(letterSpacing: -0.5),
                          ),
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
                                Icon(LucideIcons.bell, size: 22, color: Dg.ink),
                                if (s.unreadNotifCount > 0)
                                  Positioned(
                                    top: -2,
                                    right: -3,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Dg.red,
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
              Appear(
                delay: const Duration(milliseconds: 40),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Dg.pagePad),
                  child: !s.shiftOpen
                      ? _ShiftClosedCard(onStart: () => _startShift(context, s))
                      : _ShiftOpenCard(session: s),
                ),
              ),
              if (s.shiftOpen) ...[
                const SizedBox(height: 22),
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
                if (hero != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dg.pagePad,
                    ),
                    child: _HeroStop(task: hero),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: Dg.pagePad),
                    child: _NoStopCard(),
                  ),
              ],
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
                          child: Icon(
                            LucideIcons.refreshCw,
                            size: 16,
                            color: syncDone ? Dg.green : Dg.purpleActive,
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
                          color: Dg.purpleActive,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Dg.pagePad),
                child: s.visibleNotifications.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          l.noNotifications,
                          style: Dg.ui(size: 14, color: Dg.ink3),
                        ),
                      )
                    : DgCard(
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
                child: const Icon(LucideIcons.sun, size: 18, color: Dg.amber),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: Dg.sage, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              l.shiftOpen,
              style: Dg.ui(size: 13, weight: FontWeight.w600),
            ),
            const Spacer(),
            DgSwitch(
              value: true,
              onChanged: (_) async {
                final ok = await confirmEndShift(context);
                if (ok) session.setShiftOpen(false);
              },
              activeColor: Dg.ink,
              thumbColor: Dg.surface,
            ),
          ],
        ),
        const SizedBox(height: 12),
        DgCard(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
          child: Column(
            children: [
              Row(
                children: [
                  _stat('${session.openCount}', l.openShort, brand: true),
                  _statDivider(),
                  _stat('${session.deliveredCount}', l.deliveredShort),
                  _statDivider(),
                  _stat('${session.returnCount}', l.returnShort),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                km == null
                    ? l.sinceFrom(session.shiftStartLabel)
                    : l.shiftDayLine(session.shiftStartLabel, km),
                style: Dg.ui(size: 12, color: Dg.ink2),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(String value, String label, {bool brand = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Dg.stat(
              size: 24,
              color: brand ? Dg.purpleActive : Dg.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: Dg.ui(size: 13, color: Dg.ink2)),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(width: 1, height: 36, color: Dg.rule);
  }
}

class _HeroStop extends ConsumerStatefulWidget {
  const _HeroStop({required this.task});
  final DeliveryTask task;

  @override
  ConsumerState<_HeroStop> createState() => _HeroStopState();
}

class _HeroStopState extends ConsumerState<_HeroStop> {
  bool _open = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(sessionProvider);
      unawaited(s.ensureDayRoute());
    });
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final s = ref.watch(sessionProvider);
    final slice = s.roadToTask(task.id);
    final day = s.dayRoute;
    final pending = s.pendingSync;
    final later = s.remainingStops;
    final nextLabel = later.isEmpty
        ? context.l10n.none
        : later.length == 1
        ? later.first.recipient
        : '${later.first.recipient} +${later.length - 1}';
    final note = task.note?.trim();

    final meta = [
      task.ref,
      if (task.custodyCount != null)
        context.l10n.itemsCount(task.custodyCount!),
    ].join('  ·  ');

    return DgCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(Dg.radiusHero),
            ),
            child: MapStrip(
              height: 152,
              rounded: false,
              clipTopOnly: false,
              points: [LatLng(task.lat, task.lng)],
              roadPoints: slice != null && slice.points.length > 1
                  ? slice.points
                  : day != null && day.highlight.length > 1
                  ? day.highlight
                  : null,
              polylinePrecision: slice?.precision ?? day?.precision ?? 5,
              estimated: slice?.estimated ?? day == null || day.estimated,
              couriers: [s.fleet.first],
              fitTo: [
                LatLng(s.selfLat, s.selfLng),
                LatLng(task.lat, task.lng),
              ],
              label: slice != null
                  ? context.l10n.etaMinutesLabel(slice.minutes)
                  : (task.etaMinutes == null
                      ? null
                      : context.l10n.etaMinutesLabel(task.etaMinutes!)),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _open = !_open),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InitialsAvatar(
                        name: task.recipient,
                        photoUrl: task.personPhoto,
                        size: 44,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.recipient,
                              style: Dg.ui(size: 18, weight: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              task.address,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Dg.ui(
                                size: 13,
                                color: Dg.ink2,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              meta,
                              style: Dg.ui(
                                size: 12,
                                weight: FontWeight.w600,
                                color: Dg.purpleActive,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        context.l10n.shipmentAndQueue,
                        style: Dg.ui(
                          size: 13,
                          weight: FontWeight.w600,
                          color: Dg.ink2,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _open ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                        size: 16,
                        color: Dg.purpleActive,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: Column(
                      children: [
                        _detailBlock(
                          title: context.l10n.shipment,
                          rows: [
                            (context.l10n.shipmentNo, task.ref),
                            (context.l10n.type, context.l10n.kindOf(task.kind)),
                            if (task.custodyCount != null)
                              (
                                context.l10n.custody,
                                context.l10n.itemsWithRef(
                                  task.custodyCount!,
                                  task.custodyRef,
                                ),
                              ),
                            if (task.otpRequired)
                              (
                                context.l10n.deliveryCode,
                                context.l10n.required,
                              ),
                            if (task.cod != null)
                              (context.l10n.cashOnDelivery, '₺${task.cod}'),
                            if (note != null && note.isNotEmpty)
                              (context.l10n.note, note),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _detailBlock(
                          title: context.l10n.queue,
                          rows: [
                            (
                              context.l10n.order,
                              '${task.sequence} / ${s.tasks.length}',
                            ),
                            (context.l10n.openStop, '${s.openCount}'),
                            (context.l10n.next, nextLabel),
                            (
                              context.l10n.sync,
                              pending == 0
                                  ? context.l10n.clean
                                  : context.l10n.pendingRecords(pending),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              children: [
                DgButton(
                  label: context.l10n.startDelivery,
                  tone: DgButtonTone.brand,
                  onPressed: () {
                    ref.read(sessionProvider).startTask(task.id);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => WizardScreen(taskId: task.id),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DgButton(
                        label: context.l10n.directions,
                        tone: DgButtonTone.secondary,
                        onPressed: () => openDirections(context, task),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DgButton.icon(
                      icon: LucideIcons.phone,
                      iconColor: Dg.purpleActive,
                      onPressed: () =>
                          ref.read(sessionProvider).callTask(context, task),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailBlock({
    required String title,
    required List<(String, String)> rows,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Dg.elev,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Dg.ui(
              size: 11,
              weight: FontWeight.w700,
              color: Dg.ink3,
            ).copyWith(letterSpacing: 0.3),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < rows.length; i += 2)
            Padding(
              padding: EdgeInsets.only(bottom: i + 2 < rows.length ? 8 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _detailTile(rows[i].$1, rows[i].$2)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: i + 1 < rows.length
                        ? _detailTile(rows[i + 1].$1, rows[i + 1].$2)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _detailTile(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Dg.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Dg.ui(size: 11, color: Dg.ink3)),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Dg.ui(size: 14, weight: FontWeight.w700),
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
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Dg.greenBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(LucideIcons.circleCheck, size: 20, color: Dg.green),
          ),
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
