import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../geo.dart';
import '../l10n.dart';
import '../launchers.dart';
import '../motion.dart';
import '../models.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'fail_screen.dart';
import 'wizard_screen.dart';

/// Canvas'ın "1d Görev detayı" tasarımı — tam ekran harita + kaydırmalı
/// alt sheet. Kapıda ödeme yerine Zimmet/Teslim penceresi/Teslim kodu
/// ikonlu bilgi kartları (bkz. plan Faz E).
class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(sessionProvider);
      unawaited(s.ensureDayRoute());
      if (!s.routeLoading) unawaited(s.loadRoute());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = ref.watch(sessionProvider);
    final t = session.taskOrNull(widget.taskId);
    if (t == null) {
      return Scaffold(
        backgroundColor: Dg.night,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _SheetBack(onTap: () => Navigator.of(context).pop()),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    l.stopGone,
                    style: Dg.ui(size: 15, color: Colors.white70),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final done = t.status == TaskStatus.delivered;
    final canAct = !t.isClosed;
    final self = LatLng(session.selfLat, session.selfLng);
    final dest = LatLng(t.lat, t.lng);
    final slice = t.hasCoordinates ? session.roadToTask(t.id) : null;
    final meters = slice?.meters ?? haversineMeters(self, dest).round();
    final minutes = slice != null
        ? slice.minutes
        : (t.etaMinutes ?? (meters / 450).clamp(1, 40).round());
    final km = meters >= 10000
        ? (meters / 1000).toStringAsFixed(0)
        : (meters / 1000).toStringAsFixed(1);

    void start() {
      ref.read(sessionProvider).startTask(t.id);
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => WizardScreen(taskId: t.id)),
      );
    }

    return Scaffold(
      backgroundColor: Dg.night,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MapStrip(
                  height: double.infinity,
                  rounded: false,
                  interactive: true,
                  points: t.hasCoordinates ? [dest] : [self],
                  roadPoints: slice != null && slice.points.length > 1
                      ? slice.points
                      : null,
                  polylinePrecision: slice?.precision ?? 6,
                  estimated: slice?.estimated ?? true,
                  couriers: session.visibleFleet
                      .where((c) => c.self)
                      .toList(),
                  fitTo: t.hasCoordinates ? [self, dest] : [self],
                  showBadge: false,
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(
                      children: [
                        _SheetBack(
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: _RouteChip(
                            text: slice != null && !slice.estimated
                                ? l.routeKmMin(km, minutes)
                                : '${l.routeKmMin(km, minutes)}  ·  ${l.approxRoute}',
                          ),
                        ),
                        const SizedBox(width: 8),
                        _FleetToggle(
                          on: session.showFleet,
                          label: l.fleetOnMap,
                          onTap: session.toggleFleet,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Dg.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(Dg.radiusHero),
              ),
              border: Border(top: BorderSide(color: Dg.rule, width: 0.5)),
            ),
            child: SafeArea(
              top: false,
              child: Appear(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Dg.pagePad, 16, Dg.pagePad, 22),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Dg.rule,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Mono(
                            taskRefLine(t, visit: session.visitNumber(t.id)),
                            color: Dg.ink3,
                          ),
                        ),
                        StatusChip(
                          label: taskStatusLabel(t.status, l),
                          tone: taskStatusTone(t.status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Hero(
                      tag: 'recipient-${t.id}',
                      child: Material(
                        color: Colors.transparent,
                        child: Row(
                          children: [
                            InitialsAvatar(
                              name: t.recipient,
                              photoUrl: t.personPhoto,
                              size: 40,
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Display(t.recipient, size: 22)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Dg.ink2,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const DgDivider(),
                    _InfoCard(
                      icon: LucideIcons.layers,
                      label: l.custody,
                      value: t.custodyCount == null
                          ? '—'
                          : l.itemsWithRef(t.custodyCount!, t.custodyRef),
                    ),
                    const DgDivider(),
                    _InfoCard(
                      icon: LucideIcons.clock,
                      label: l.deliveryWindowLeft,
                      value: t.slaMinutesLeft == null
                          ? t.window
                          : l.slaLeft(t.slaLabel),
                    ),
                    if (t.otpRequired) ...[
                      const DgDivider(),
                      _InfoCard(
                        icon: LucideIcons.key,
                        label: l.deliveryCode,
                        value: l.askRecipient,
                        dot: true,
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        SquareAction(
                          icon: LucideIcons.phone,
                          label: l.callShort,
                          onTap: () => session.callTask(context, t),
                        ),
                        const SizedBox(width: 10),
                        SquareAction(
                          icon: LucideIcons.navigation,
                          label: l.routeShort,
                          onTap: () => openDirections(context, t),
                        ),
                        const SizedBox(width: 10),
                        SquareAction(
                          icon: LucideIcons.camera,
                          label: l.photo,
                          onTap: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (done)
                      Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: Dg.loBg,
                              borderRadius: BorderRadius.circular(
                                Dg.radiusPill,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  LucideIcons.circleCheck,
                                  size: 20,
                                  color: Dg.lo,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l.deliveredOk,
                                  style: Dg.ui(
                                    size: 16,
                                    weight: FontWeight.w700,
                                    color: Dg.lo,
                                  ),
                                ),
                              ],
                            ),
                          )
                          .animate()
                          .scale(
                            begin: const Offset(0.96, 0.96),
                            duration: 220.ms,
                            curve: Curves.easeOutBack,
                          )
                          .fadeIn(duration: 180.ms)
                    else if (canAct)
                      SlideToAct(
                        label: l.slideToDeliver,
                        onConfirm: start,
                      ),
                    if (canAct) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: () async {
                            final failed = await Navigator.of(context)
                                .push<bool>(
                                  MaterialPageRoute<bool>(
                                    builder: (_) => FailScreen(taskId: t.id),
                                  ),
                                );
                            if (failed == true && context.mounted)
                              Navigator.of(context).pop();
                          },
                          child: Text(
                            l.couldNotDeliverShort,
                            style: TextStyle(
                              color: Dg.hi,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Canvas'ın "Zimmet/Teslim penceresi/Teslim kodu" bilgi satırları —
/// ikon + etiket solda, değer sağda; [dot] gerektiğinde değerin önüne
/// bekleyen-durum noktası ekler (teslim kodu henüz alınmadıysa).
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    this.dot = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Dg.ink3),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: Dg.ui(size: 14, color: Dg.ink3)),
          ),
          if (dot) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: Dg.sand, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(value, style: Dg.ui(size: 14, weight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _RouteChip extends StatelessWidget {
  const _RouteChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Dg.night,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Dg.purple.withValues(alpha: 0.7)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: Dg.mono,
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FleetToggle extends StatelessWidget {
  const _FleetToggle({
    required this.on,
    required this.label,
    required this.onTap,
  });

  final bool on;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: on ? Dg.night : Dg.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: on ? Dg.sage.withValues(alpha: 0.7) : Dg.rule,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.users,
                size: 14,
                color: on ? Colors.white : Dg.ink,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: on ? Colors.white : Dg.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetBack extends StatelessWidget {
  const _SheetBack({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tooltip = MaterialLocalizations.of(context).backButtonTooltip;
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Dg.surface,
          elevation: 3,
          shadowColor: const Color(0x33000000),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(LucideIcons.arrowLeft, size: 17, color: Dg.ink),
            ),
          ),
        ),
      ),
    );
  }
}
