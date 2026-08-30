import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../api/models.dart';
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
import 'profile_screen.dart';

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomeScreen(),
      const MenuScreen(),
      const ListScreen(),
      const NotifScreen(),
      const ProfileScreen(),
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
        items: const [
          (Icons.home_outlined, Icons.home_rounded, 'Ana sayfa'),
          (Icons.grid_view_outlined, Icons.grid_view_rounded, 'Menü'),
          (Icons.local_shipping_outlined, Icons.local_shipping_rounded, 'Dağıtım'),
          (Icons.notifications_outlined, Icons.notifications_rounded, 'Bildirim'),
          (Icons.person_outline, Icons.person_rounded, 'Profil'),
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
    final open = tasks.where((t) => t.status != TaskStatus.delivered && t.status != TaskStatus.failed).length;
    final next = s.nextStop;
    final summary = _routeSummary(plan, fallback: next == null ? 'Rota bitti' : '0,6 km  sağa');
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MapStrip(
              height: 900,
              clipTopOnly: false,
              points: [for (final t in tasks) LatLng(t.lat, t.lng)],
              encodedPolyline: plan?.geometry,
              label: '$open durak',
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
                      decoration: const BoxDecoration(color: Dg.surface, shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_back_rounded, size: 18, color: Dg.ink),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Dg.purple,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Dg.ui(size: 13, weight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: s.toggleOnline,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Dg.ink,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        s.online ? 'Mola' : 'Devam',
                        style: Dg.ui(size: 13, weight: FontWeight.w700, color: Colors.white),
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
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$open durak kaldı. Durağa basınca yol tarifi açılır.', style: Dg.ui(size: 15, color: Dg.ink2)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 168,
                          child: s.routeLoading && plan == null
                              ? ListView.separated(
                                  itemCount: 3,
                                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                                  itemBuilder: (context, i) => const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 6),
                                    child: DgSkeleton(width: double.infinity, height: 20),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: tasks.length,
                                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                                  itemBuilder: (context, i) {
                                    final task = tasks[i];
                                    final leg = plan == null ? null : _findStop(plan.stops, task.id);
                                    return _RouteStop(task: task, stop: leg, last: i == tasks.length - 1);
                                  },
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

class _RouteStop extends StatelessWidget {
  const _RouteStop({required this.task, required this.stop, required this.last});

  final DeliveryTask task;
  /// Distance/duration for the leg arriving at this stop — null for the
  /// first stop (no incoming leg) or when no route has been computed yet.
  final RouteStopDto? stop;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final distanceMeters = stop?.distanceMeters;
    final legLabel = distanceMeters == null
        ? null
        : '${(distanceMeters / 1000).toStringAsFixed(1)} km · ${((stop!.durationSeconds ?? 0) / 60).round()} dk';
    return GestureDetector(
      onTap: () => openDirections(context, task),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: last ? Dg.ink : Dg.purple,
              shape: BoxShape.circle,
              border: Border.all(color: Dg.ink, width: 1),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Display(task.recipient, size: 16),
                Text(
                  legLabel == null ? task.window : '${task.window}  ·  $legLabel',
                  style: const TextStyle(fontSize: 12, color: Dg.ink3),
                ),
              ],
            ),
          ),
          const Icon(Icons.navigation_rounded, size: 18, color: Dg.ink),
        ],
      ),
    );
  }
}
