import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../alerts.dart';
import '../api/models.dart';
import '../geo.dart';
import '../l10n.dart';
import '../launchers.dart';
import '../models.dart';
import '../motion.dart';
import '../road.dart';
import '../session.dart';
import '../shell_nav.dart';
import '../theme.dart';
import '../widgets.dart';
import 'home_screen.dart';
import 'list_screen.dart';
import 'menu_screen.dart';
import 'notif_screen.dart';
import 'tara_screen.dart';
import 'task_detail_screen.dart';

/// Rota haritası açık renkli karolarla (bkz. map_config.dart) çalışıyor —
/// üstteki yüzen pilller karonun rengine göre gözden kaybolmasın diye hepsi
/// aynı yumuşak gölgeyi paylaşıyor.
const _floatingPillShadow = [
  BoxShadow(color: Color(0x1F000000), blurRadius: 8, offset: Offset(0, 2)),
];

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen>
    with WidgetsBindingObserver {
  int _seenUnread = -1;
  AppNotification? _banner;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FieldAlerts.tapId.addListener(_onAlertTap);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onAlertTap();
      unawaited(ref.read(sessionProvider).reconcilePushPermit());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FieldAlerts.tapId.removeListener(_onAlertTap);
    _bannerTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(sessionProvider).reconcilePushPermit());
    }
  }

  void _onAlertTap() {
    final id = FieldAlerts.tapId.value;
    if (id == null) return;
    FieldAlerts.tapId.value = null;
    ref.read(shellNavProvider).go(ShellNav.notif);
    if (id == FieldAlerts.shiftPayload) return;
    final s = ref.read(sessionProvider);
    final n = s.notificationById(id);
    if (n == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      openAppNotification(context, s, n);
    });
  }

  void _showArrival(AppNotification n) {
    _bannerTimer?.cancel();
    final s = ref.read(sessionProvider);
    if (s.beepEnabled) {
      unawaited(SystemSound.play(SystemSoundType.click));
    }
    setState(() => _banner = n);
    _bannerTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _banner = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(
      sessionProvider.select((s) => s.unreadNotifCount),
    );
    ref.listen<SessionController>(sessionProvider, (prev, next) {
      if (_seenUnread < 0) {
        _seenUnread = next.unreadNotifCount;
        return;
      }
      if (next.unreadNotifCount > _seenUnread &&
          next.notifyEnabled &&
          ref.read(shellNavProvider).index != ShellNav.notif &&
          next.visibleNotifications.isNotEmpty) {
        HapticFeedback.mediumImpact();
        _showArrival(next.visibleNotifications.first);
      }
      _seenUnread = next.unreadNotifCount;
    });
    // Profil artık ayrı bir sekme değil — Menü'nün üst kartından açılıyor
    // (canvas'ın "1k Menü" tasarımı, profil özetini orada gösteriyor).
    final pages = [
      const HomeScreen(),
      const ListScreen(),
      const TaraScreen(),
      const NotifScreen(),
      const MenuScreen(),
    ];
    final nav = ref.watch(shellNavProvider);
    final index = nav.index;
    final l = context.l10n;
    return Scaffold(
      extendBody: false,
      // IndexedStack keeps all 5 tabs mounted so switching tabs no longer
      // resets scroll position or in-progress state (e.g. ListScreen's
      // search field) — previously this was a plain `pages[index]` swap,
      // rebuilding the destination tab from scratch every time. The
      // AnimatedOpacity per-page gives a soft cross-fade cue without
      // wrapping in AnimatedSwitcher, which would dispose+rebuild the whole
      // stack on every switch and defeat the point of IndexedStack.
      body: Stack(
        children: [
          IndexedStack(
            index: index,
            children: [
              for (var i = 0; i < pages.length; i++)
                AnimatedOpacity(
                  opacity: index == i ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: pages[i],
                ),
            ],
          ),
          if (_banner != null)
            Positioned(
              left: Dg.pagePad,
              right: Dg.pagePad,
              top: MediaQuery.paddingOf(context).top + 8,
              child: _ArrivalBanner(
                notification: _banner!,
                onTap: () {
                  _bannerTimer?.cancel();
                  final n = _banner!;
                  setState(() => _banner = null);
                  nav.go(ShellNav.notif);
                  openAppNotification(context, ref.read(sessionProvider), n);
                },
                onClose: () {
                  _bannerTimer?.cancel();
                  setState(() => _banner = null);
                },
              ),
            ),
        ],
      ),
      bottomNavigationBar: DgPillNav(
        index: index,
        onChanged: nav.go,
        badges: [0, 0, 0, unread, 0],
        items: [
          (LucideIcons.house, LucideIcons.house, l.home),
          (LucideIcons.truck, LucideIcons.truck, l.route),
          (LucideIcons.qrCode, LucideIcons.qrCode, l.scan),
          (LucideIcons.bell, LucideIcons.bell, l.permPush),
          (LucideIcons.layoutGrid, LucideIcons.layoutGrid, l.menu),
        ],
      ),
    );
  }
}

class _ArrivalBanner extends StatelessWidget {
  const _ArrivalBanner({
    required this.notification,
    required this.onTap,
    required this.onClose,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final l = context.l10n;
    return Material(
      color: Dg.surface,
      borderRadius: BorderRadius.circular(Dg.radiusHero),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Dg.radiusHero),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Dg.radiusHero),
            border: Border.all(color: Dg.rule),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: n.tint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(n.icon, size: 16, color: n.ink),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l.notifTitle(n.title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Dg.ui(size: 14, weight: FontWeight.w700),
                      ),
                      Text(
                        n.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Dg.ui(size: 12, color: Dg.ink3),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onClose,
                  icon: Icon(LucideIcons.x, size: 16, color: Dg.ink3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// In-app stylized route map, reached from a hero-card icon (not a bottom
/// tab) — quick-action "Yol" buttons elsewhere open the real Maps app
/// instead (see launchers.dart#openDirections).
class RouteScreen extends ConsumerStatefulWidget {
  const RouteScreen({super.key});

  @override
  ConsumerState<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends ConsumerState<RouteScreen> {
  int _fitEpoch = 0;

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
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _RouteMap(fitEpoch: _fitEpoch)),
          const _RouteTopBar(),
          const _RouteSheet(),
          Positioned(
            right: 16,
            bottom: MediaQuery.sizeOf(context).height * 0.42 + 12,
            child: _MapChip(
              onTap: () => setState(() => _fitEpoch++),
              child: Tooltip(
                message: context.l10n.recenterRoute,
                child: Icon(LucideIcons.locate, size: 18, color: Dg.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteMap extends ConsumerWidget {
  const _RouteMap({this.fitEpoch = 0});

  final int fitEpoch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(
      sessionProvider.select(
        (s) => Object.hash(
          s.dayRoute?.polyline,
          s.dayRoute?.meters,
          s.dayRoute?.estimated,
          s.dayRouteLoading,
          s.showFleet,
          s.openCount,
          s.tasks.length,
        ),
      ),
    );
    final s = ref.read(sessionProvider);
    final tasks = s.orderedOpenTasks;
    final day = s.dayRoute;
    final pts = _uniquePoints(tasks);
    final size = MediaQuery.sizeOf(context);
    final topInset = MediaQuery.paddingOf(context).top;
    return MapStrip(
      height: size.height,
      clipTopOnly: false,
      rounded: false,
      interactive: true,
      showBadge: false,
      points: pts,
      roadPoints: day != null && day.points.length > 1 ? day.points : null,
      highlightPoints: day != null && !day.estimated ? day.highlight : null,
      polylinePrecision: day?.precision ?? 5,
      estimated: day == null || day.estimated,
      couriers: s.visibleFleet,
      fitEpoch: fitEpoch,
      numberStops: true,
      fitPadding: EdgeInsets.fromLTRB(28, topInset + 64, 28, size.height * 0.42 + 12),
      fitTo: [
        if (day != null && day.points.length > 1) ...day.points
        else ...[
          LatLng(s.selfLat, s.selfLng),
          ...pts,
        ],
      ],
    );
  }
}

class _RouteTopBar extends ConsumerWidget {
  const _RouteTopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final next = s.nextStop;
    final day = s.dayRoute;
    final summary = next == null
        ? context.l10n.routeFinished
        : s.dayRouteLoading && (day == null || day.estimated)
        ? context.l10n.routeComputing
        : day != null
        ? (day.estimated
              ? '${context.l10n.routeKmMin((day.meters / 1000).toStringAsFixed(1), day.minutes)}  ·  ${context.l10n.approxRoute}'
              : context.l10n.routeKmMin(
                  (day.meters / 1000).toStringAsFixed(1),
                  day.minutes,
                ))
        : _routeSummary(s.routePlan, fallback: context.l10n.approxRoute);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          children: [
            _MapChip(
              onTap: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
              child: Icon(LucideIcons.arrowLeft, size: 18, color: Dg.ink),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: Dg.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _floatingPillShadow,
                ),
                child: Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Dg.ui(
                    size: 13,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _MapChip(
              on: s.showFleet,
              onTap: s.toggleFleet,
              child: Icon(
                LucideIcons.users,
                size: 18,
                color: s.showFleet ? Colors.white : Dg.ink,
              ),
            ),
            const SizedBox(width: 8),
            _MapChip(
              onTap: s.toggleOnline,
              child: Icon(
                s.online ? LucideIcons.pause : LucideIcons.play,
                size: 18,
                color: Dg.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapChip extends StatelessWidget {
  const _MapChip({required this.onTap, required this.child, this.on = false});

  final VoidCallback onTap;
  final Widget child;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? Dg.night : Dg.surface,
          shape: BoxShape.circle,
          boxShadow: _floatingPillShadow,
        ),
        child: child,
      ),
    );
  }
}

class _RouteSheet extends ConsumerWidget {
  const _RouteSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final plan = s.routePlan;
    final day = s.dayRoute;
    final openTasks = s.orderedOpenTasks;
    final nextId = s.nextStop?.id;
    final stopCount = day != null && day.stops.isNotEmpty
        ? day.stops.length
        : _uniquePoints(openTasks).length;

    return DraggableScrollableSheet(
      initialChildSize: 0.40,
      minChildSize: 0.16,
      maxChildSize: 0.78,
      snap: true,
      snapSizes: const [0.16, 0.40, 0.78],
      builder: (context, scroll) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Dg.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Dg.ink2.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                context.l10n.remainingStopsHint(stopCount),
                style: Dg.ui(size: 17, weight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              if (s.routeLoading && plan == null)
                const DgSkeleton(width: double.infinity, height: 88)
              else if (openTasks.isEmpty)
                Text(
                  context.l10n.routeFinished,
                  style: Dg.ui(size: 14, color: Dg.ink2),
                )
              else ...[
                if (day != null && day.stops.isNotEmpty)
                  _TravelSegment(
                    meters: day.stops.first.meters,
                    seconds: day.stops.first.seconds,
                    fromYou: true,
                  ),
                for (var i = 0; i < openTasks.length; i++) ...[
                  if (i > 0 &&
                      haversineMeters(
                            LatLng(openTasks[i - 1].lat, openTasks[i - 1].lng),
                            LatLng(openTasks[i].lat, openTasks[i].lng),
                          ) >=
                          kSameStopMeters)
                    _TravelSegment(
                      meters: day == null
                          ? _findStop(plan?.stops ?? const [], openTasks[i].id)
                              ?.distanceMeters
                          : _dayLeg(day, openTasks[i].id)?.meters,
                      seconds: day == null
                          ? _findStop(plan?.stops ?? const [], openTasks[i].id)
                              ?.durationSeconds
                          : _dayLeg(day, openTasks[i].id)?.seconds,
                    ),
                  _StopNode(
                    task: openTasks[i],
                    active: openTasks[i].id == nextId,
                    last: i == openTasks.length - 1,
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

DayStop? _dayLeg(DayRoute route, String taskId) {
  for (final s in route.stops) {
    if (s.taskIds.contains(taskId)) return s;
  }
  return null;
}

/// Aynı adrese gruplanan görevler aynı koordinatı paylaşır ("Aynı adres · N
/// gönderi" kartı) — tekilleştirilmeden polyline'a/fallback düz çizgiye
/// geçilirse, sondaki yinelenen nokta rotanın ortasına geri "sıçrıyormuş"
/// gibi görünen bir zikzak yaratıyordu.
List<LatLng> _uniquePoints(Iterable<DeliveryTask> tasks) {
  final out = <LatLng>[];
  final seen = <String>{};
  for (final t in tasks) {
    final key = '${t.lat.toStringAsFixed(4)},${t.lng.toStringAsFixed(4)}';
    if (seen.add(key)) out.add(LatLng(t.lat, t.lng));
  }
  return out;
}

RouteStopDto? _findStop(List<RouteStopDto> stops, String taskId) {
  for (final s in stops) {
    if (s.taskId == taskId) return s;
  }
  return null;
}

String _routeSummary(RoutePlanDto? plan, {required String fallback}) {
  if (plan == null || plan.stops.isEmpty) return fallback;
  final km = plan.totalDistanceMeters / 1000;
  final minutes = (plan.totalDurationSeconds / 60).round();
  final kmLabel = km >= 10 ? km.toStringAsFixed(0) : km.toStringAsFixed(1);
  return '$kmLabel km  ·  $minutes dk';
}

/// Dikey zaman çizelgesindeki bir durak düğümü — canvas'ın "1c Rota"
/// tasarımı dört görünüm ayırt ediyor: teslim edilmiş (yeşil check),
/// aktif/sıradaki durak (tam mor gradyan kart + CTA), bekleyen ara durak
/// (sade gri satır), son durak (bayrak ikonu).
class _StopNode extends StatelessWidget {
  const _StopNode({
    required this.task,
    required this.active,
    required this.last,
  });

  final DeliveryTask task;
  final bool active;
  final bool last;

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TaskDetailScreen(taskId: task.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final meta = [
      if (task.custodyCount != null) l.itemsCount(task.custodyCount!),
      if (task.otpRequired) l.codeRequired,
    ].join(' · ');

    if (active) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          gradient: Dg.primaryGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => _openDetail(context),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.recipient,
                    style: Dg.ui(
                      size: 17,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    task.address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Dg.ui(
                      size: 13,
                      color: Colors.white.withValues(alpha: 0.82),
                      height: 1.3,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      meta,
                      style: Dg.ui(
                        size: 12,
                        weight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Dg.primaryGradientStart,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => openDirections(context, task),
                icon: const Icon(LucideIcons.navigation, size: 16),
                label: Text(
                  l.goToThisStop,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Pressable(
      onTap: () => _openDetail(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: last ? Dg.violetBg : Dg.elev,
                border: Border.all(color: last ? Dg.purpleActive : Dg.rule),
              ),
              child: last
                  ? Icon(LucideIcons.flag, size: 11, color: Dg.purpleActive)
                  : Text(
                      '${task.sequence}',
                      style: Dg.ui(
                        size: 11,
                        weight: FontWeight.w700,
                        color: Dg.ink2,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.recipient,
                    style: Dg.ui(size: 15, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      task.address,
                      if (task.custodyCount != null)
                        l.itemsCount(task.custodyCount!),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Dg.ui(size: 13, color: Dg.ink2),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 16, color: Dg.ink3),
          ],
        ),
      ),
    );
  }
}

/// İki durak arasındaki yolculuğu gösteren segment — araç ikonu + süre/km,
/// ince dikey bir çizgi üzerinde (durak noktalarını görsel olarak bağlar).
class _TravelSegment extends StatelessWidget {
  const _TravelSegment({this.meters, this.seconds, this.fromYou = false});

  /// Null: rota henüz hesaplanmadı, ya da bu bacak için veri yok.
  final int? meters;
  final int? seconds;
  final bool fromYou;

  @override
  Widget build(BuildContext context) {
    final distanceMeters = meters;
    if (distanceMeters == null) {
      return const SizedBox(height: 8);
    }
    final minutes = ((seconds ?? 0) / 60).clamp(1, 180).round();
    final travel =
        '${(distanceMeters / 1000).toStringAsFixed(1)} km · $minutes dk';
    final label = fromYou
        ? '${context.l10n.youToNext}  ·  $travel'
        : travel;
    return Padding(
      padding: const EdgeInsets.fromLTRB(11, 2, 0, 2),
      child: Row(
        children: [
          Container(width: 2, height: 20, color: Dg.rule),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Dg.ui(size: 12, color: Dg.ink3),
            ),
          ),
        ],
      ),
    );
  }
}
