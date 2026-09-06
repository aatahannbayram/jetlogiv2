import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../api/models.dart';
import '../l10n.dart';
import '../launchers.dart';
import '../models.dart';
import '../motion.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'home_screen.dart';
import 'list_screen.dart';
import 'menu_screen.dart';
import 'notif_screen.dart';
import 'tara_screen.dart';

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

class _ShellScreenState extends ConsumerState<ShellScreen> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    // Profil artık ayrı bir sekme değil — Menü'nün üst kartından açılıyor
    // (canvas'ın "1k Menü" tasarımı, profil özetini orada gösteriyor).
    final pages = [
      const HomeScreen(),
      const ListScreen(),
      const TaraScreen(),
      const NotifScreen(),
      const MenuScreen(),
    ];
    return Scaffold(
      extendBody: true,
      // IndexedStack keeps all 5 tabs mounted so switching tabs no longer
      // resets scroll position or in-progress state (e.g. ListScreen's
      // search field) — previously this was a plain `pages[index]` swap,
      // rebuilding the destination tab from scratch every time. The
      // AnimatedOpacity per-page gives a soft cross-fade cue without
      // wrapping in AnimatedSwitcher, which would dispose+rebuild the whole
      // stack on every switch and defeat the point of IndexedStack.
      body: IndexedStack(
        index: index,
        children: [
          for (var i = 0; i < pages.length; i++)
            AnimatedOpacity(
              opacity: index == i ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              child: pages[i],
            ),
        ],
      ),
      bottomNavigationBar: DgPillNav(
        index: index,
        onChanged: (i) => setState(() => index = i),
        items: [
          (LucideIcons.house, LucideIcons.house, context.l10n.home),
          (LucideIcons.truck, LucideIcons.truck, context.l10n.route),
          (LucideIcons.qrCode, LucideIcons.qrCode, context.l10n.scan),
          (LucideIcons.bell, LucideIcons.bell, context.l10n.permPush),
          (LucideIcons.layoutGrid, LucideIcons.layoutGrid, context.l10n.menu),
        ],
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
  bool _panelExpanded = true;

  @override
  void initState() {
    super.initState();
    // Loaded proactively on shift-open (session.dart#openShift), but the
    // screen can be reached before that finishes, or after tasks changed —
    // this catches those cases without blocking first paint.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(sessionProvider);
      if (!s.routeLoading) unawaited(s.loadRoute());
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final plan = s.routePlan;
    // The optimizer (apps/api/src/services/optimizer.ts, Faz 2) may reorder
    // stops for the shortest real drive time — reflect that order here
    // rather than the raw dispatch list, with any task the plan does not
    // know about yet (freshly assigned, not in the last computed route)
    // appended at the end so nothing silently disappears.
    final tasks = _orderedTasks(s.tasks, plan);
    final open = tasks.where((t) => t.isOpen).length;
    final next = s.nextStop;
    final summary = _routeSummary(
      plan,
      fallback: next == null ? 'Rota bitti' : '0,6 km  sağa',
    );
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MapStrip(
              height: 900,
              clipTopOnly: false,
              interactive: true,
              points: [for (final t in tasks) LatLng(t.lat, t.lng)],
              encodedPolyline: plan?.geometry,
              label: context.l10n.stopsCount(open),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Dg.surface,
                        shape: BoxShape.circle,
                        boxShadow: _floatingPillShadow,
                      ),
                      child: Icon(
                        LucideIcons.arrowLeft,
                        size: 18,
                        color: Dg.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Dg.purple,
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
                  GestureDetector(
                    onTap: s.toggleOnline,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Dg.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _floatingPillShadow,
                      ),
                      child: Text(
                        s.online ? 'Mola' : 'Devam',
                        style: Dg.ui(
                          size: 13,
                          weight: FontWeight.w700,
                          color: Dg.ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DgCard(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sürüklenebilir alt panel görünümünü çağrıştıran
                        // tutamaç — dokununca listeyi açıp kapatıyor, harita
                        // görünür kalsın isteyen kurye için.
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () =>
                              setState(() => _panelExpanded = !_panelExpanded),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 36,
                                height: 4,
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Dg.ink2.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      context.l10n.remainingStopsHint(open),
                                      style: Dg.ui(size: 15, color: Dg.ink2),
                                    ),
                                  ),
                                  Icon(
                                    _panelExpanded
                                        ? LucideIcons.chevronDown
                                        : LucideIcons.chevronUp,
                                    size: 18,
                                    color: Dg.ink2,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: !_panelExpanded
                              ? const SizedBox.shrink()
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      // Zengin durak kartları (özellikle aktif
                                      // durağın tam mor kartı) eski 168px'e
                                      // sığmıyor — ekranın ~%45'i kadar yer
                                      // ayırıp gerisini ListView'ın kendi
                                      // kaydırmasına bırakıyoruz.
                                      height:
                                          MediaQuery.of(context).size.height *
                                          0.45,
                                      child: s.routeLoading && plan == null
                                          ? ListView.separated(
                                              itemCount: 3,
                                              separatorBuilder: (
                                                context,
                                                index,
                                              ) => const SizedBox(height: 8),
                                              itemBuilder: (context, i) =>
                                                  const Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          vertical: 6,
                                                        ),
                                                    child: DgSkeleton(
                                                      width: double.infinity,
                                                      height: 20,
                                                    ),
                                                  ),
                                            )
                                          : ListView.builder(
                                              // Dikey zaman çizelgesi: durak
                                              // düğümü → yolculuk segmenti →
                                              // durak düğümü — bu yüzden n
                                              // durak için 2n-1 öğe var, tek
                                              // indeksler segment.
                                              itemCount: tasks.isEmpty
                                                  ? 0
                                                  : tasks.length * 2 - 1,
                                              itemBuilder: (context, i) {
                                                if (i.isOdd) {
                                                  final task =
                                                      tasks[(i + 1) ~/ 2];
                                                  final leg = plan == null
                                                      ? null
                                                      : _findStop(
                                                          plan.stops,
                                                          task.id,
                                                        );
                                                  return _TravelSegment(
                                                    stop: leg,
                                                  );
                                                }
                                                final idx = i ~/ 2;
                                                return _StopNode(
                                                  task: tasks[idx],
                                                  active:
                                                      tasks[idx].id == next?.id,
                                                  last: idx == tasks.length - 1,
                                                );
                                              },
                                            ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
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

/// Reorders [tasks] to match `plan.stops` (optimizer output); a task the
/// plan does not mention — newly assigned since the last computed route —
/// is appended at the end rather than dropped.
List<DeliveryTask> _orderedTasks(List<DeliveryTask> tasks, RoutePlanDto? plan) {
  if (plan == null || plan.stops.isEmpty) return tasks;
  final byId = {for (final t in tasks) t.id: t};
  final ordered = <DeliveryTask>[
    for (final stop in plan.stops) ?byId[stop.taskId],
  ];
  final seen = ordered.map((t) => t.id).toSet();
  ordered.addAll(tasks.where((t) => !seen.contains(t.id)));
  return ordered;
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

  @override
  Widget build(BuildContext context) {
    final delivered = task.status == TaskStatus.delivered;
    final cancelled = task.status == TaskStatus.cancelled;
    final icon = delivered
        ? LucideIcons.check
        : cancelled
        ? LucideIcons.x
        : (last
              ? LucideIcons.flag
              : (active ? LucideIcons.mapPin : LucideIcons.layers));

    if (active) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Dg.primaryGradientStart,
              ),
              child: Icon(icon, size: 14, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: Dg.primaryGradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Display(
                            task.recipient,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                        StatusChip(
                          label: taskStatusLabel(task.status, context.l10n),
                          tone: 'lime',
                          fg: Colors.white,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${task.address}  ·  ${task.window}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (task.custodyCount != null)
                          _pill('Zimmet', '${task.custodyCount} kalem'),
                        if (task.otpRequired) _pill('Kod', 'Gerekli'),
                        if (task.slaMinutesLeft != null)
                          _pill('Kalan', task.slaLabel),
                      ],
                    ),
                    if (task.isOpen) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Dg.primaryGradientStart,
                          ),
                          onPressed: () => openDirections(context, task),
                          icon: const Icon(LucideIcons.navigation, size: 15),
                          label: Text(context.l10n.goToThisStop),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => openDirections(context, task),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: delivered
                  ? Dg.sage
                  : cancelled
                  ? Dg.ink3
                  : Dg.elev,
            ),
            child: Icon(
              icon,
              size: 14,
              color: delivered || cancelled ? Colors.white : Dg.ink2,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InitialsAvatar(
                      name: task.recipient,
                      photoUrl: task.personPhoto,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Display(task.recipient, size: 15)),
                    Text(
                      task.window.split('–').first,
                      style: TextStyle(fontSize: 12, color: Dg.ink3),
                    ),
                  ],
                ),
                Text(
                  task.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Dg.ink3),
                ),
                if (delivered || task.custodyCount != null) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (task.custodyCount != null)
                        _pill('Zimmet', '${task.custodyCount} kalem'),
                      if (delivered && task.signed)
                        _pillIcon(LucideIcons.penLine, 'İmzalandı'),
                      if (delivered && task.otpRequired)
                        _pillIcon(LucideIcons.key, 'Kod'),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _pillIcon(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Dg.elev,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Dg.ink2),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Dg.ink2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// İki durak arasındaki yolculuğu gösteren segment — araç ikonu + süre/km,
/// ince dikey bir çizgi üzerinde (durak noktalarını görsel olarak bağlar).
class _TravelSegment extends StatelessWidget {
  const _TravelSegment({required this.stop});

  /// Null: rota henüz hesaplanmadı, ya da bu bacak için veri yok.
  final RouteStopDto? stop;

  @override
  Widget build(BuildContext context) {
    final distanceMeters = stop?.distanceMeters;
    final label = distanceMeters == null
        ? '…'
        : '${(distanceMeters / 1000).toStringAsFixed(1)} km · ${((stop!.durationSeconds ?? 0) / 60).round()} dk';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            child: Center(
              child: Container(width: 2, height: 22, color: Dg.rule),
            ),
          ),
          const SizedBox(width: 12),
          Icon(LucideIcons.truck, size: 13, color: Dg.ink3),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, color: Dg.ink3)),
        ],
      ),
    );
  }
}
