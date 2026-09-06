import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../launchers.dart';
import '../models.dart';
import '../motion.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'notif_screen.dart';
import 'shell_screen.dart' show RouteScreen;
import 'sync_screen.dart';
import 'wizard_screen.dart';

String _homeGreeting(L10n l) => l.greeting(DateTime.now().hour);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _startShift(BuildContext context, SessionController s) async {
    final ok = await showShiftSelfieSheet(context);
    if (ok) s.setShiftOpen(true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 108),
            children: [
              Row(
                children: [
                  InitialsAvatar(
                    name: s.courier.fullName,
                    photoUrl: s.courier.photoUrl,
                    online: s.online,
                    size: 46,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_homeGreeting(l), style: Dg.kicker()),
                        const SizedBox(height: 2),
                        Text(
                          s.courier.fullName,
                          style: Dg.ui(size: 17, weight: FontWeight.w700),
                        ),
                        Text(
                          '${s.courier.district} / ${s.courier.city}',
                          style: Dg.ui(size: 12, color: Dg.ink3),
                        ),
                      ],
                    ),
                  ),
                  DgOnlineChip(online: s.online, onTap: s.toggleOnline),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const NotifScreen(),
                      ),
                    ),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Dg.elev,
                        shape: BoxShape.circle,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(LucideIcons.bell, size: 17, color: Dg.ink),
                          if (s.unreadNotifCount > 0)
                            Positioned(
                              top: 5,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 15,
                                  minHeight: 15,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Dg.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Dg.ground,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  '${s.unreadNotifCount}',
                                  style: const TextStyle(
                                    fontFamily: Dg.mono,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!s.shiftOpen)
                _ShiftClosedCard(onStart: () => _startShift(context, s))
              else
                _ShiftOpenCard(session: s),
              if (s.shiftOpen) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.nextStop,
                        style: Dg.serif(size: 19, weight: FontWeight.w600),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const RouteScreen(),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            l.seeRoute,
                            style: Dg.ui(
                              size: 13,
                              weight: FontWeight.w600,
                              color: Dg.primaryGradientStart,
                            ),
                          ),
                          Icon(
                            LucideIcons.chevronRight,
                            size: 16,
                            color: Dg.primaryGradientStart,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (hero != null)
                  _HeroStop(task: hero)
                else
                  const _NoStopCard(),
              ],
              const SizedBox(height: 20),
              DgCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SyncScreen()),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: syncDone ? Dg.greenBg : Dg.amberBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            LucideIcons.refreshCw,
                            size: 18,
                            color: syncDone ? Dg.green : Dg.amber,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.syncTitle,
                                style: Dg.ui(size: 16, weight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                syncDone
                                    ? l.syncCleanBody
                                    : l.syncPendingBody(syncTotal),
                                style: Dg.ui(size: 13, color: Dg.ink2),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: syncDone ? Dg.greenBg : Dg.amberBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            syncDone ? l.clean : l.pendingChip(syncTotal),
                            style: TextStyle(
                              fontFamily: Dg.mono,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: syncDone ? Dg.green : Dg.amber,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: syncDone ? 1 : 0.62,
                        minHeight: 7,
                        backgroundColor: Dg.elev,
                        valueColor: AlwaysStoppedAnimation(
                          syncDone ? Dg.sage : Dg.primaryGradientStart,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.notifications,
                      style: Dg.serif(size: 21, weight: FontWeight.w600),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const NotifScreen(),
                      ),
                    ),
                    child: Text(
                      l.all,
                      style: Dg.ui(
                        size: 13,
                        weight: FontWeight.w600,
                        color: Dg.primaryGradientStart,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (s.notifications.isEmpty)
                DgCard(
                  child: Row(
                    children: [
                      Icon(LucideIcons.bell, size: 20, color: Dg.ink3),
                      const SizedBox(width: 10),
                      Text(
                        l.noNotifications,
                        style: Dg.ui(size: 14, color: Dg.ink3),
                      ),
                    ],
                  ),
                )
              else
                for (final (i, n) in s.notifications.take(2).indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: StaggerIn(
                      index: i,
                      child: NotifCard(
                        notification: n,
                        unread: !s.isNotifRead(i),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const NotifScreen(),
                          ),
                        ),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(Dg.radiusHero),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(color: Dg.night),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.shiftStatus,
                style: TextStyle(
                  fontFamily: Dg.mono,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: Color(0xFF8A8F80),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                context.l10n.closed,
                style: TextStyle(
                  fontFamily: Dg.display,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.shiftSelfieNeeded,
                style: TextStyle(
                  color: Color(0xFF9A9E90),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              DgButton(
                label: context.l10n.startShiftCta,
                icon: LucideIcons.camera,
                onPressed: onStart,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShiftOpenCard extends StatelessWidget {
  const _ShiftOpenCard({required this.session});
  final SessionController session;

  @override
  Widget build(BuildContext context) {
    final plan = session.routePlan;
    final km = plan == null
        ? '—'
        : (plan.totalDistanceMeters / 1000).toStringAsFixed(1);
    return ClipRRect(
      borderRadius: BorderRadius.circular(Dg.radiusHero),
      child: Container(
        decoration: BoxDecoration(
          gradient: Dg.primaryGradient,
          boxShadow: Dg.shadowHero,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.l10n.shiftOpen,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  DgSwitch(
                    value: true,
                    onChanged: (_) => session.setShiftOpen(false),
                    activeColor: Colors.white,
                    thumbColor: Dg.primaryGradientStart,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    session.shiftElapsedLabel,
                    style: Dg.stat(size: 30, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      "${session.shiftStartLabel}'tan beri",
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFDCCFEF),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _pill(
                      context.l10n.delivered,
                      '${session.deliveredCount} / ${session.tasks.length}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _pill(context.l10n.distance, km)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFFDCCFEF), fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(value, style: Dg.stat(size: 16, color: Colors.white)),
        ],
      ),
    );
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
  Widget build(BuildContext context) {
    final task = widget.task;
    final s = ref.watch(sessionProvider);
    final pending = s.pendingSync;
    final later = s.remainingStops;
    final nextLabel = later.isEmpty
        ? context.l10n.none
        : later.length == 1
        ? later.first.recipient
        : '${later.first.recipient} +${later.length - 1}';
    final note = task.note?.trim();

    return DgCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _open = !_open),
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MapStrip(
                  height: 80,
                  points: [LatLng(task.lat, task.lng)],
                  label: task.etaMinutes == null
                      ? task.window
                      : '${task.etaMinutes} dk',
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Row(
                    children: [
                      InitialsAvatar(
                        name: task.recipient,
                        photoUrl: task.personPhoto,
                        size: 42,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Display(task.recipient, size: 20),
                            const SizedBox(height: 3),
                            Text(
                              task.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Dg.ui(size: 13, color: Dg.ink2),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${task.ref}  ·  ${task.window}',
                              style: Dg.ui(size: 12, color: Dg.ink3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Text(
                        context.l10n.shipmentAndQueue,
                        style: Dg.ui(
                          size: 13,
                          weight: FontWeight.w600,
                          color: Dg.primaryGradientStart,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _open ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                        size: 16,
                        color: Dg.primaryGradientStart,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Column(
                      children: [
                        _detailBlock(
                          title: context.l10n.shipment,
                          rows: [
                            (context.l10n.shipmentNo, task.ref),
                            (context.l10n.type, context.l10n.kindOf(task.kind)),
                            (context.l10n.deliveryWindow, task.window),
                            if (task.custodyCount != null)
                              (
                                context.l10n.custody,
                                context.l10n.itemsWithRef(
                                  task.custodyCount!,
                                  task.custodyRef,
                                ),
                              ),
                            if (task.otpRequired)
                              (context.l10n.deliveryCode, context.l10n.required),
                            if (task.cod != null)
                              (context.l10n.cashOnDelivery, '₺${task.cod}'),
                            if (note != null && note.isNotEmpty)
                              (context.l10n.note, note),
                          ],
                        ),
                        const SizedBox(height: 8),
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              children: [
                DgButton(
                  label: context.l10n.startDelivery,
                  icon: LucideIcons.package,
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
                        icon: LucideIcons.navigation,
                        tone: DgButtonTone.secondary,
                        onPressed: () => openDirections(context, task),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DgButton.icon(
                      icon: LucideIcons.phone,
                      iconColor: Dg.green,
                      fillColor: Dg.greenBg,
                      onPressed: () => callRecipient(context),
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
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: Dg.elev,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Dg.ui(size: 11, weight: FontWeight.w700, color: Dg.ink3),
          ),
          const SizedBox(height: 8),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(row.$1, style: Dg.ui(size: 13, color: Dg.ink3)),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      row.$2,
                      textAlign: TextAlign.right,
                      style: Dg.ui(size: 13, weight: FontWeight.w600),
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

class _NoStopCard extends StatelessWidget {
  const _NoStopCard();

  @override
  Widget build(BuildContext context) {
    return DgCard(
      hero: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTintBadge(
            icon: LucideIcons.listChecks,
            tint: Dg.greenBg,
            ink: Dg.green,
            size: 44,
          ),
          const SizedBox(height: 14),
          Text(
            context.l10n.noNextStop,
            style: Dg.serif(size: 20, weight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.noOpenTasksLeft,
            style: Dg.ui(size: 14, color: Dg.ink2, height: 1.4),
          ),
        ],
      ),
    );
  }
}
