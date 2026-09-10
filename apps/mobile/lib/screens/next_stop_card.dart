import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../launchers.dart';
import '../models.dart';
import '../next_stop.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'return_screen.dart';
import 'shell_screen.dart' show RouteScreen;
import 'wizard_screen.dart';

class NextStopPager extends ConsumerStatefulWidget {
  const NextStopPager({super.key});

  @override
  ConsumerState<NextStopPager> createState() => _NextStopPagerState();
}

class _NextStopPagerState extends ConsumerState<NextStopPager> {
  late final PageController _pages;
  final _arrived = <String>{};
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pages = PageController(viewportFraction: 0.92);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final stops = s.orderedOpenTasks;
    if (stops.isEmpty) return const _NoOpenStop();
    return SizedBox(
      height: 380,
      child: PageView.builder(
        controller: _pages,
        padEnds: false,
        itemCount: stops.length,
        onPageChanged: (i) => setState(() => _page = i),
        itemBuilder: (context, i) {
          return Padding(
            padding: EdgeInsets.only(right: i == stops.length - 1 ? 0 : 12),
            child: NextStopCard(
              key: ValueKey(stops[i].id),
              task: stops[i],
              arrivedManual: _arrived.contains(stops[i].id),
              offerArrive: i == _page,
              onArrived: () => setState(() => _arrived.add(stops[i].id)),
            ),
          );
        },
      ),
    );
  }
}

class NextStopCard extends ConsumerStatefulWidget {
  const NextStopCard({
    super.key,
    required this.task,
    required this.arrivedManual,
    required this.offerArrive,
    required this.onArrived,
  });

  final DeliveryTask task;
  final bool arrivedManual;
  final bool offerArrive;
  final VoidCallback onArrived;

  @override
  ConsumerState<NextStopCard> createState() => _NextStopCardState();
}

class _NextStopCardState extends ConsumerState<NextStopCard> {
  NextStopPhase? _lastPhase;
  bool _arrivedHere = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);
    final task = widget.task;
    final slice = s.roadToTask(task.id);
    final meters = stopDistanceMeters(
      task: task,
      selfLat: s.selfLat,
      selfLng: s.selfLng,
      slice: slice,
    );
    final arrivedManual = widget.arrivedManual || _arrivedHere;
    final phase = nextStopPhase(
      selfLocated: s.selfLocated,
      arrivedManual: arrivedManual,
      distanceMeters: meters,
      status: task.status,
    );
    if (_lastPhase != phase) {
      final from = _lastPhase;
      _lastPhase = phase;
      if (from == NextStopPhase.enroute && phase == NextStopPhase.arrived) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          HapticFeedback.heavyImpact();
        });
      }
    }

    final addr = parseStopAddress(task.address);
    final appt = parseAppointmentWindow(
      task.window,
      slaMinutesLeft: task.slaMinutesLeft,
    );
    final minutes = slice?.minutes ?? task.etaMinutes;
    final km = meters == null ? null : (meters / 1000).toStringAsFixed(1);
    final index = s.visitNumber(task.id);
    final total = s.orderedOpenTasks.length;
    final mapH = phase == NextStopPhase.enroute ? 112.0 : 64.0;
    final snap = mapSnapshotUrl(
      task: task,
      selfLat: s.selfLat,
      selfLng: s.selfLng,
      road: slice?.points,
    );

    final travel = [
      if (addr.hood != null) addr.hood!,
      if (km != null) '$km km',
      if (minutes != null) '$minutes dk',
    ].join(' · ');

    return RepaintBoundary(
      child: Container(
          decoration: BoxDecoration(
            color: Dg.surface1,
            borderRadius: BorderRadius.circular(Dg.rLg),
            border: Border(top: BorderSide(color: Dg.hairline, width: 0.5)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MapShot(
                height: mapH,
                url: snap,
                indexLabel: l.stopIndexOf(index, total),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const RouteScreen()),
                ),
              ),
              if (appt != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: _ApptPill(window: appt),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Text(
                  addr.street,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Dg.ui(
                    size: 22,
                    weight: FontWeight.w700,
                    letterSpacing: 22 * -0.01,
                  ),
                ),
              ),
              if (travel.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 3, 16, 0),
                  child: Text(
                    travel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Dg.ui(size: 14, color: Dg.text2),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: _MetaLine(task: task),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  children: [
                    _Ghost(
                      label: l.call,
                      onTap: () => s.callTask(context, task),
                    ),
                    const SizedBox(width: 8),
                    _Ghost(
                      label: l.kpiFailed,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ReturnScreen(taskId: task.id),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Ghost(
                      icon: LucideIcons.ellipsis,
                      label: l.moreActions,
                      onTap: () => _more(context, l),
                    ),
                    if (widget.offerArrive &&
                        !s.selfLocated &&
                        !arrivedManual) ...[
                      const SizedBox(width: 8),
                      _Ghost(
                        key: const Key('next-stop-arrived'),
                        label: l.arrivedHere,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          widget.onArrived();
                          setState(() => _arrivedHere = true);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _SolidCta(
                    key: const Key('next-stop-cta'),
                    label: phase == NextStopPhase.arrived
                        ? l.startDelivery
                        : l.directions,
                    color: phase == NextStopPhase.arrived ? Dg.ok : Dg.brand,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      if (phase == NextStopPhase.arrived) {
                        s.startTask(task.id);
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => WizardScreen(taskId: task.id),
                          ),
                        );
                      } else {
                        openDirections(context, task);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }

  void _more(BuildContext context, L10n l) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Dg.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Dg.rLg)),
      ),
      builder: (ctx) => SafeArea(
        child: ListTile(
          leading: DgIcon(LucideIcons.map),
          title: Text(l.seeRoute),
          onTap: () {
            Navigator.pop(ctx);
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RouteScreen()),
            );
          },
        ),
      ),
    );
  }
}

class _MapShot extends StatelessWidget {
  const _MapShot({
    required this.height,
    required this.url,
    required this.indexLabel,
    required this.onTap,
  });

  final double height;
  final String? url;
  final String indexLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: Dg.surface2),
            if (url != null)
              Image.network(
                url!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            if (url == null)
              Center(
                child: DgIcon(LucideIcons.map, color: Dg.text3, size: 22),
              ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xCC0B0B0F),
                  borderRadius: BorderRadius.circular(Dg.rSm),
                ),
                child: Text(
                  indexLabel,
                  style: Dg.typeNum(size: 12, weight: FontWeight.w600),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(height: 1, color: Dg.stroke),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApptPill extends StatefulWidget {
  const _ApptPill({required this.window});
  final AppointmentWindow window;

  @override
  State<_ApptPill> createState() => _ApptPillState();
}

class _ApptPillState extends State<_ApptPill> {
  Timer? _tick;
  late int? _left;

  @override
  void initState() {
    super.initState();
    _left = widget.window.minutesLeft;
    if (widget.window.urgent) {
      _tick = Timer.periodic(const Duration(minutes: 1), (_) {
        final n = _left;
        if (n == null || !mounted) return;
        setState(() => _left = n - 1);
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final danger = _left != null && _left! < 45;
    final ink = danger ? Dg.bad : Dg.warn;
    final clock = widget.window.label.toUpperCase();
    final text = danger && _left != null
        ? '${l.appointment.toUpperCase()} $clock · ${l.minutesLeft(_left!)}'
        : '${l.appointment.toUpperCase()} $clock';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: ink.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Dg.rSm),
        ),
        child: Text(
          text,
          style: Dg.typeOverline(color: ink),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.task});
  final DeliveryTask task;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Row(
      children: [
        Flexible(
          child: Text(
            task.recipient,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Dg.ui(size: 15, color: Dg.text2),
          ),
        ),
        Text(' · ', style: Dg.ui(size: 15, color: Dg.text2)),
        Flexible(
          child: Text(
            task.ref,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Dg.ui(size: 15, color: Dg.text2).copyWith(fontFamily: Dg.mono),
          ),
        ),
        if (task.custodyCount != null) ...[
          Text(' · ', style: Dg.ui(size: 15, color: Dg.text2)),
          GestureDetector(
            onTap: () => _sheet(context, l),
            child: Text(
              l.itemsCount(task.custodyCount!),
              style: Dg.ui(
                size: 15,
                weight: FontWeight.w600,
                color: Dg.text2,
              ).copyWith(decoration: TextDecoration.underline),
            ),
          ),
        ],
      ],
    );
  }

  void _sheet(BuildContext context, L10n l) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Dg.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Dg.rLg)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.itemsSheetTitle, style: Dg.typeH2()),
            const SizedBox(height: 12),
            Text(
              l.itemsWithRef(task.custodyCount!, task.custodyRef),
              style: Dg.typeBody(),
            ),
            if (task.note != null && task.note!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(task.note!, style: Dg.typeCaption()),
            ],
          ],
        ),
      ),
    );
  }
}

class _Ghost extends StatelessWidget {
  const _Ghost({super.key, required this.onTap, this.label, this.icon});

  final VoidCallback onTap;
  final String? label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Dg.muteSoft,
            borderRadius: BorderRadius.circular(Dg.rSm),
          ),
          child: icon != null
              ? DgIcon(icon!, size: 18, color: Dg.text2)
              : Text(
                  label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Dg.ui(size: 13, weight: FontWeight.w600),
                ),
        ),
      ),
    );
  }
}

class _SolidCta extends StatelessWidget {
  const _SolidCta({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(Dg.radiusPill),
          border: const Border(
            top: BorderSide(color: Color(0x1FFFFFFF), width: 2),
          ),
        ),
        child: Text(
          label,
          style: Dg.ui(size: 15, weight: FontWeight.w700, color: Colors.white),
        ),
      ),
    );
  }
}

class _NoOpenStop extends StatelessWidget {
  const _NoOpenStop();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: Dg.surface1,
        borderRadius: BorderRadius.circular(Dg.rLg),
        border: Border(top: BorderSide(color: Dg.hairline, width: 0.5)),
      ),
      child: Text(
        context.l10n.noOpenTasksLeft,
        style: Dg.ui(size: 15, color: Dg.text2),
      ),
    );
  }
}
