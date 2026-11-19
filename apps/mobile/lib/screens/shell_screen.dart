import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../alerts.dart';
import '../courier_home.dart';
import '../api/models.dart';
import '../geo.dart';
import '../l10n.dart';
import '../map_config.dart';
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
      unawaited(ref.read(sessionProvider).onForeground());
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
      unawaited(ref.read(sessionProvider).onForeground());
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

  bool _navCompact = false;

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(sessionProvider.select((s) => s.unreadNotifCount));
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
      body: Stack(
        children: [
          NavShrinkOnScroll(
            compact: _navCompact,
            onCompact: (v) => setState(() => _navCompact = v),
            // Kamera sekmesi kaydırmayla açılmaz: yanlışlıkla kamera açılmasın.
            child: SwipeTabs(
              index: index,
              count: pages.length,
              skip: const {ShellNav.scan},
              onChanged: (i) {
                if (_navCompact) setState(() => _navCompact = false);
                nav.go(i);
              },
              child: DgTabStack(index: index, children: pages),
            ),
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
        primaryIndex: ShellNav.scan,
        index: index,
        compact: _navCompact,
        onChanged: (i) {
          // Sekme değişince menü yeniden büyür.
          if (_navCompact) setState(() => _navCompact = false);
          nav.go(i);
        },
        badges: [0, 0, 0, unread, 0],
        items: [
          (LucideIcons.house, LucideIcons.house, l.home),
          (LucideIcons.truck, LucideIcons.truck, l.route),
          (LucideIcons.qrCode, LucideIcons.qrCode, l.scan),
          (LucideIcons.bell, LucideIcons.bell, l.permPush),
          (LucideIcons.menu, LucideIcons.menu, l.menu),
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
                  icon: DgIcon(LucideIcons.x, size: 16, color: Dg.ink3),
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
          const _MissingLocationBanner(),
          const _RouteSheet(),
          Positioned(
            right: 16,
            bottom: MediaQuery.sizeOf(context).height * 0.42 + 70,
            child: const _GeofenceChip(),
          ),
          Positioned(
            right: 16,
            top: MediaQuery.paddingOf(context).top + 132,
            child: const _MapStyleChip(),
          ),
          Positioned(
            right: 16,
            bottom: MediaQuery.sizeOf(context).height * 0.42 + 12,
            child: _MapChip(
              onTap: () => setState(() => _fitEpoch++),
              child: Tooltip(
                message: context.l10n.recenterRoute,
                child: DgIcon(
                  LucideIcons.locate,
                  size: 18,
                  color: Dg.ink,
                  weight: 600,
                ),
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
      fitPadding: mapRouteFitPadding(height: size.height, topInset: topInset),
      fitTo: keepNearStops([
        LatLng(s.selfLat, s.selfLng),
        ...pts,
        if (day != null) ...day.waypoints,
      ], pts),
    );
  }
}

class _MissingLocationBanner extends ConsumerWidget {
  const _MissingLocationBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(
      sessionProvider.select((s) => s.unlocatedOpenTasks.length),
    );
    if (n == 0) return const SizedBox.shrink();
    return Positioned(
      left: 16,
      right: 16,
      top: MediaQuery.paddingOf(context).top + 132,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Dg.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${context.l10n.stopsWithoutLocation} · $n',
            style: Dg.ui(size: 13, weight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _RouteTopBar extends ConsumerWidget {
  const _RouteTopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final l = context.l10n;
    final day = s.dayRoute;
    final plan = s.routePlan;
    final count = s.orderedOpenTasks.length;
    final minutes = day?.minutes ??
        (plan == null ? null : (plan.totalDurationSeconds / 60).round());
    final meters = day?.meters.toDouble() ?? plan?.totalDistanceMeters.toDouble();
    final computing = s.dayRouteLoading && (day == null || day.estimated);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          children: [
            Row(
              children: [
                _MapChip(
                  onTap: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: DgIcon(LucideIcons.arrowLeft, size: 18, color: Dg.ink),
                ),
                Expanded(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Dg.surface,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: _floatingPillShadow,
                      ),
                      child: Text(
                        l.route,
                        style: Dg.ui(size: 17, weight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                _MapChip(
                  onTap: s.toggleOnline,
                  child: Tooltip(
                    message: s.online ? l.homeActive : l.homePassive,
                    child: Icon(
                      s.online ? LucideIcons.pause : LucideIcons.play,
                      size: 18,
                      color: Dg.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _RouteStat(
                    icon: LucideIcons.package,
                    label: l.routeTasksCount(count),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RouteStat(
                    icon: LucideIcons.clock,
                    caption: 'ETA',
                    label: computing || minutes == null
                        ? '…'
                        : etaLabel(minutes),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RouteStat(
                    icon: LucideIcons.route,
                    caption: l.routeDistance,
                    label: computing || meters == null
                        ? '…'
                        : distanceLabel(meters),
                  ),
                ),
              ],
            ),
            if (day?.estimated ?? false) ...[
              const SizedBox(height: 6),
              Text(
                l.approxRoute,
                style: Dg.ui(size: 12, color: Dg.ink2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// K04 katman düğmesi: Sokak → Koyu → Uydu.
class _MapStyleChip extends StatelessWidget {
  const _MapStyleChip();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ValueListenableBuilder<MapStyle>(
      valueListenable: mapStyle,
      builder: (context, style, _) {
        final label = switch (style) {
          MapStyle.street => l.mapStreet,
          MapStyle.dark => l.mapDark,
          MapStyle.satellite => l.mapSatellite,
        };
        return Semantics(
          button: true,
          label: '${l.mapLayer}: $label',
          excludeSemantics: true,
          child: _MapChip(
            onTap: () => mapStyle.value = MapStyle
                .values[(style.index + 1) % MapStyle.values.length],
            child: Tooltip(
              message: '${l.mapLayer}: $label',
              child: DgIcon(LucideIcons.layers, size: 18, color: Dg.ink),
            ),
          ),
        );
      },
    );
  }
}

class _RouteStat extends StatelessWidget {
  const _RouteStat({required this.icon, required this.label, this.caption});

  final IconData icon;
  final String label;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Dg.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Dg.hairline),
        boxShadow: _floatingPillShadow,
      ),
      child: Row(
        children: [
          DgIcon(icon, size: 18, color: Dg.ink2, weight: 500),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (caption != null)
                  Text(caption!, style: Dg.ui(size: 11, color: Dg.ink3)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: Dg.ui(size: 14, weight: FontWeight.w700),
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

/// Haritanın altında: sıradaki durağa uzaklık 500 m (varsayılan) içindeyse
/// "Geofence uygun". Konum yoksa çip görünmez; tahmin gösterilmez.
class _GeofenceChip extends ConsumerWidget {
  const _GeofenceChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final next = s.nextStop;
    if (next == null) return const SizedBox.shrink();
    final d = geofenceDistance(
      located: s.selfLocated,
      selfLat: s.selfLat,
      selfLng: s.selfLng,
      stopLat: next.lat,
      stopLng: next.lng,
      stopHasCoordinates: next.hasCoordinates,
    );
    if (d == null) return const SizedBox.shrink();
    final inside = d <= kDefaultGeofenceMeters;
    final color = inside ? Dg.ok : Dg.warn;
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Dg.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
        boxShadow: _floatingPillShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DgIcon(
            inside ? LucideIcons.shieldCheck : LucideIcons.shieldAlert,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            inside ? l.geofenceOk : l.geofenceFar(distanceLabel(d)),
            style: Dg.ui(size: 13, weight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _MapChip extends StatelessWidget {
  const _MapChip({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Dg.surface,
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
    final missing = s.unlocatedOpenTasks;
    final doors = groupTasksByDoor(openTasks.where((t) => t.hasCoordinates));
    final nextId = s.nextStop?.id;
    final stopCount = doors.length + missing.length;

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
                  width: 48,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Dg.ink2.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (s.nextStop != null) ...[
                _NextStopPanel(
                  task: s.nextStop!,
                  index: (doors.indexWhere(
                            (d) => d.any((t) => t.id == nextId),
                          ) +
                          1)
                      .clamp(1, stopCount == 0 ? 1 : stopCount),
                  total: stopCount,
                  legMeters: day != null && day.stops.isNotEmpty
                      ? day.stops.first.meters.toDouble()
                      : null,
                ),
                const SizedBox(height: 18),
              ],
              Text(
                '${context.l10n.allStops} · ${context.l10n.remainingStopsHint(stopCount)}',
                style: Dg.ui(size: 15, weight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              if (s.routeLoading && plan == null)
                const DgSkeleton(width: double.infinity, height: 88)
              else if (doors.isEmpty && missing.isEmpty)
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
                for (var i = 0; i < doors.length; i++) ...[
                  if (i > 0)
                    _TravelSegment(
                      meters: day == null
                          ? _findStop(
                              plan?.stops ?? const [],
                              doors[i].first.id,
                            )?.distanceMeters
                          : _dayLeg(day, doors[i].first.id)?.meters,
                      seconds: day == null
                          ? _findStop(
                              plan?.stops ?? const [],
                              doors[i].first.id,
                            )?.durationSeconds
                          : _dayLeg(day, doors[i].first.id)?.seconds,
                    ),
                  _StopNode(
                    task: doors[i].first,
                    extras: doors[i].length > 1
                        ? doors[i].skip(1).toList()
                        : const [],
                    visitIndex: i + 1,
                    // Sıradaki durak üstteki kartta; listede satır olarak kalır.
                    active: false,
                    last: i == doors.length - 1,
                  ),
                ],
              ],
              if (missing.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  context.l10n.stopsWithoutLocation,
                  style: Dg.ui(size: 15, weight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                for (final t in missing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${t.recipient} · ${t.ref}',
                      style: Dg.ui(size: 14, color: Dg.ink2),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// K04 "Sıradaki Durak": ad, adres, hizmet tipi, uzaklık; Detay + Yola Çık.
class _NextStopPanel extends ConsumerWidget {
  const _NextStopPanel({
    required this.task,
    required this.index,
    required this.total,
    this.legMeters,
  });

  final DeliveryTask task;
  final int index;
  final int total;
  final double? legMeters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final l = context.l10n;
    final d = geofenceDistance(
          located: s.selfLocated,
          selfLat: s.selfLat,
          selfLng: s.selfLng,
          stopLat: task.lat,
          stopLng: task.lng,
          stopHasCoordinates: task.hasCoordinates,
        ) ??
        legMeters;
    // Hizmet tipi panelden gelir (ör. "Pluxee Sticker Dağıtımı").
    final kind =
        task.serviceName ??
        (task.isCard ? l.cardDelivery : l.standardDelivery);
    Future<void> setOff() async {
      final messenger = ScaffoldMessenger.of(context);
      final warn = l.startNeedsLocation;
      if (task.status != TaskStatus.inProgress) {
        final ok = await s.startTask(task.id);
        if (!ok) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(warn)));
        }
      }
      if (!context.mounted) return;
      await openDirections(context, task);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.nextStopTitle,
                style: Dg.ui(size: 17, weight: FontWeight.w700),
              ),
            ),
            Text(
              '$index / $total',
              style: Dg.ui(size: 15, weight: FontWeight.w700, color: Dg.ink2),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Dg.surface2,
                shape: BoxShape.circle,
              ),
              child: DgIcon(LucideIcons.mapPin, size: 22, color: Dg.warn),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.recipient,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Dg.ui(size: 17, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    task.address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Dg.ui(size: 13, color: Dg.ink2, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Dg.stroke),
                  ),
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    kind,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Dg.ui(size: 12, weight: FontWeight.w600),
                  ),
                ),
                if (d != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        distanceLabel(d),
                        style: Dg.ui(
                          size: 15,
                          weight: FontWeight.w700,
                          color: Dg.warn,
                        ),
                      ),
                      const SizedBox(width: 4),
                      DgIcon(LucideIcons.navigation, size: 14, color: Dg.warn),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: DgButton(
                label: l.detailShort,
                icon: LucideIcons.fileText,
                tone: DgButtonTone.secondary,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TaskDetailScreen(taskId: task.id),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DgButton(
                label: l.setOff,
                icon: LucideIcons.navigation,
                onPressed: setOff,
              ),
            ),
          ],
        ),
      ],
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
    if (!t.hasCoordinates) continue;
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

/// Dikey zaman çizelgesindeki bir durak düğümü — canvas'ın "1c Rota"
/// tasarımı dört görünüm ayırt ediyor: teslim edilmiş (yeşil check),
/// aktif/sıradaki durak (tam mor gradyan kart + CTA), bekleyen ara durak
/// (sade gri satır), son durak (bayrak ikonu).
class _StopNode extends StatelessWidget {
  const _StopNode({
    required this.task,
    required this.active,
    required this.last,
    this.extras = const [],
    this.visitIndex,
  });

  final DeliveryTask task;
  final List<DeliveryTask> extras;
  final bool active;
  final bool last;
  final int? visitIndex;

  int get _doorCount => 1 + extras.length;

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
          color: Dg.surface2,
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
                    extras.isEmpty
                        ? task.recipient
                        : '${task.recipient} · ${l.sameAddressCount(_doorCount)}',
                    style: Dg.ui(
                      size: 17,
                      weight: FontWeight.w700,
                      color: Dg.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    task.address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Dg.ui(size: 13, color: Dg.ink2, height: 1.3),
                  ),
                  if (meta.isNotEmpty || extras.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      [
                        if (meta.isNotEmpty) meta,
                        if (extras.isNotEmpty)
                          extras.map((t) => t.recipient).join(' · '),
                      ].join(' · '),
                      style: Dg.ui(
                        size: 12,
                        weight: FontWeight.w600,
                        color: Dg.ink2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Ana eylem: diğer ekranlardaki gradyan düğme.
            DgButton(
              label: l.goToThisStop,
              icon: LucideIcons.navigation,
              onPressed: () => openDirections(context, task),
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
              ),
              child: last
                  ? DgIcon(LucideIcons.flag, size: 11, color: Dg.brand)
                  : Text(
                      '${visitIndex ?? taskBadgeNumber(task)}',
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
                    extras.isEmpty
                        ? task.recipient
                        : '${task.recipient} · ${l.sameAddressCount(_doorCount)}',
                    style: Dg.ui(size: 15, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      task.address,
                      if (task.custodyCount != null)
                        l.itemsCount(task.custodyCount!),
                      if (extras.isNotEmpty)
                        extras.map((t) => t.recipient).join(', '),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Dg.ui(size: 13, color: Dg.ink2),
                  ),
                ],
              ),
            ),
            DgIcon(LucideIcons.chevronRight, size: 16, color: Dg.ink3),
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
    // Yürüme mesafesindeki ilk durak: süre yerine "yürüyerek".
    final walking = fromYou && distanceMeters < kWalkMeters;
    final travel = context.l10n.travelLabel(
      distanceMeters,
      minutes,
      walking: walking,
    );
    final label = fromYou ? '${context.l10n.youToNext}  ·  $travel' : travel;
    return Padding(
      padding: const EdgeInsets.fromLTRB(11, 2, 0, 2),
      child: Row(
        children: [
          // Araçla gidilen bacak düz, yürünen bacak kesikli çizgi.
          if (walking)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    width: 2,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 1.3),
                    color: Dg.rule,
                  ),
              ],
            )
          else
            Container(width: 2, height: 20, color: Dg.rule),
          const SizedBox(width: 14),
          if (walking) ...[
            DgIcon(LucideIcons.footprints, size: 13, color: Dg.ink3),
            const SizedBox(width: 5),
          ],
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
