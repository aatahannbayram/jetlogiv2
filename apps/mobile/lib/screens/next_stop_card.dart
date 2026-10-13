import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../geo.dart';
import '../l10n.dart';
import '../launchers.dart';
import '../models.dart';
import '../next_stop.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'return_screen.dart';
import 'task_detail_screen.dart';
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
      height: 424 + (MediaQuery.textScalerOf(context).scale(16) - 16) * 24,
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
    // Konum ölçülmeden mesafe ve süre uydurulmaz.
    final minutes = s.selfLocated ? slice?.minutes ?? task.etaMinutes : null;
    final km = meters == null || !s.selfLocated
        ? null
        : (meters / 1000).toStringAsFixed(1);
    final index = s.visitNumber(task.id);
    final total = s.orderedOpenTasks.length;
    final mapH = phase == NextStopPhase.enroute ? 118.0 : 80.0;
    final snap = mapSnapshotUrl(
      task: task,
      selfLat: s.selfLat,
      selfLng: s.selfLng,
      road: slice?.points,
    );

    final travel = [
      if (km != null) '$km km',
      if (minutes != null) '$minutes dk',
    ].join(' · ');

    return RepaintBoundary(
      child: SingleChildScrollView(
        // Karta dokunmak o durağın kendi ekranını açar; içindeki düğmeler
        // kendi işini yapar.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TaskDetailScreen(taskId: task.id),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Dg.surface1,
              borderRadius: BorderRadius.circular(Dg.rLg),
              boxShadow: Dg.cardShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MapShot(
                  height: mapH,
                  url: snap,
                  map: task.hasCoordinates
                      ? MapStrip(
                          height: mapH,
                          clipTopOnly: false,
                          rounded: false,
                          showBadge: false,
                          points: [LatLng(task.lat, task.lng)],
                          roadPoints: slice?.points,
                          couriers: [
                            FleetCourier(
                              id: 'self',
                              name: '',
                              lat: s.selfLat,
                              lng: s.selfLng,
                              self: true,
                            ),
                          ],
                          fitTo: keepNearStops(
                            [
                              LatLng(s.selfLat, s.selfLng),
                              LatLng(task.lat, task.lng),
                              ...?slice?.points,
                            ],
                            [LatLng(task.lat, task.lng)],
                          ),
                        )
                      : null,
                  indexLabel: l.stopIndexOf(index, total),
                  travelLabel: travel.isEmpty ? null : travel,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TaskDetailScreen(taskId: task.id),
                    ),
                  ),
                ),
                // Kime ve nereye: ikisi de kırpılmadan okunur.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Text(
                    task.recipient,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Dg.ui(
                      size: 21,
                      weight: FontWeight.w700,
                      letterSpacing: 21 * -0.01,
                      height: 1.2,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Text(
                    addr.street,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Dg.ui(
                      size: 16,
                      weight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ),
                // Mahalle solda, gönderi no ve kalem sağda; sığmazsa alt satıra
                // iner (büyük yazı ayarı).
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      if (addr.hood != null)
                        Text(
                          addr.hood!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Dg.ui(size: 14, color: Dg.text2),
                        ),
                      _MetaLine(task: task),
                    ],
                  ),
                ),
                if (appt != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: _ApptPill(window: appt),
                  ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _SolidCta(
                      key: const Key('next-stop-cta'),
                      label: phase == NextStopPhase.arrived
                          ? l.startDelivery
                          : l.directions,
                      icon: phase == NextStopPhase.arrived
                          ? LucideIcons.packageCheck
                          : LucideIcons.arrowRight,
                      ember: phase != NextStopPhase.arrived,
                      color: Dg.ok,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        if (phase == NextStopPhase.arrived) {
                          final nav = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          final warn = context.l10n.startNeedsLocation;
                          s.startTask(task.id).then((ok) {
                            if (!ok) {
                              messenger
                                ..hideCurrentSnackBar()
                                ..showSnackBar(SnackBar(content: Text(warn)));
                              return;
                            }
                            nav.push(
                              MaterialPageRoute<void>(
                                builder: (_) => WizardScreen(taskId: task.id),
                              ),
                            );
                          });
                        } else {
                          openDirections(context, task);
                        }
                      },
                    ),
                  ),
                ),
                // Asıl düğmenin altında yardımcı işlemler: tek satır, eşit boy.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.offerArrive &&
                            !s.selfLocated &&
                            !arrivedManual) ...[
                          Expanded(
                            flex: 5,
                            child: _Ghost(
                              key: const Key('next-stop-arrived'),
                              icon: LucideIcons.mapPin,
                              label: l.arrivedHere,
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                widget.onArrived();
                                setState(() => _arrivedHere = true);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          flex: 4,
                          child: _Ghost(
                            icon: LucideIcons.phone,
                            label: l.call,
                            onTap: () => s.callTask(context, task),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 6,
                          child: _Ghost(
                            icon: LucideIcons.circleX,
                            label: l.couldNotDeliverShort,
                            danger: true,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ReturnScreen(taskId: task.id),
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
          ),
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
    this.map,
    this.travelLabel,
  });

  /// "0.7 km · 1 dk"; haritanın sağ altında durur.
  final String? travelLabel;
  final double height;
  final String? url;
  final Widget? map;
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
                errorBuilder: (_, _, _) => map ?? const SizedBox.shrink(),
              )
            else if (map != null)
              map!
            else
              Center(child: DgIcon(LucideIcons.map, color: Dg.text3, size: 22)),
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
                  // Etiket zemini her temada koyu; yazı da hep beyaz.
                  style: Dg.typeNum(
                    size: 12,
                    weight: FontWeight.w600,
                  ).copyWith(color: Colors.white),
                ),
              ),
            ),
            if (travelLabel != null)
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Dg.neon,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.navigation,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        travelLabel!,
                        style: Dg.typeNum(
                          size: 12,
                          weight: FontWeight.w600,
                        ).copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
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
        ? '${l.appointment.toUpperCase()} $clock · ${_left! < 0
              ? l.minutesLate(-_left!)
              : _left == 0
              ? l.timeIsUp
              : l.minutesLeft(_left!)}'
        : '${l.appointment.toUpperCase()} $clock';
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DgIcon(
            danger ? LucideIcons.circleAlert : LucideIcons.clock,
            size: 16,
            color: ink,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: Dg.ui(size: 14, weight: FontWeight.w600, color: ink),
            ),
          ),
        ],
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
    // Wrap: büyük yazı ayarında kalem sayısı alt satıra iner, taşmaz.
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          task.ref,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Dg.ui(size: 14, color: Dg.text2).copyWith(fontFamily: Dg.mono),
        ),
        if (task.custodyCount != null) ...[
          Text(' · ', style: Dg.ui(size: 14, color: Dg.text2)),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _sheet(context, l),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                l.itemsCount(task.custodyCount!),
                style: Dg.ui(
                  size: 14,
                  weight: FontWeight.w600,
                  color: Dg.text2,
                ).copyWith(decoration: TextDecoration.underline),
              ),
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
  const _Ghost({
    super.key,
    required this.onTap,
    this.label,
    this.icon,
    this.danger = false,
  });

  /// Olumsuz işlem (teslim edilemedi): kırmızı yazı ve ikon, kırmızımsı zemin.
  final bool danger;
  final VoidCallback onTap;
  final String? label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label == null
        ? MaterialLocalizations.of(context).moreButtonTooltip
        : null,
    child: Material(
      // Çerçeve yok; hafif dolgu düğme olduğunu belli eder.
      color: danger ? Dg.redBg : Dg.surface2,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56, minWidth: 52),
          // İkonlar aynı hizada kalsın diye içerik üstten başlar.
          alignment: label == null ? Alignment.center : Alignment.topCenter,
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
          // İkon üstte, yazı altta: dar kartta da hepsi aynı boyda sığar.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null)
                DgIcon(icon!, size: 20, color: danger ? Dg.bad : Dg.ink2),
              if (icon != null && label != null) const SizedBox(height: 4),
              if (label != null)
                Text(
                  label!,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: Dg.ui(
                    size: 13,
                    weight: FontWeight.w600,
                    height: 1.15,
                    color: danger ? Dg.bad : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SolidCta extends StatelessWidget {
  const _SolidCta({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    this.icon,
    this.ember = false,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final IconData? icon;
  final bool ember;

  @override
  Widget build(BuildContext context) => DgButton(
    label: label,
    onPressed: onTap,
    icon: ember ? null : icon,
    trailing: ember ? icon : null,
    tone: DgButtonTone.primary,
  );
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
