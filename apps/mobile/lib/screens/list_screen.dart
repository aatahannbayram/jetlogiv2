import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../models.dart';
import '../motion.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'shell_screen.dart' show RouteScreen;
import 'task_detail_screen.dart';

/// Bottom nav'ın "Rota" sekmesi — liste görünümü (canvas'ın "1l Dağıtım
/// listesi"). Sağ üstteki harita ikonu [RouteScreen]'i (dikey zaman
/// çizelgesi, canvas'ın "1c Rota") push eder — iki ekran aynı verinin
/// harita/liste iki hâli.
class ListScreen extends ConsumerStatefulWidget {
  const ListScreen({super.key});

  @override
  ConsumerState<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends ConsumerState<ListScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);
    final acik = s.tasks.where((t) => t.isOpen).toList();
    final teslim = s.tasks
        .where((t) => t.status == TaskStatus.delivered)
        .toList();
    final iade = s.tasks
        .where(
          (t) =>
              t.status == TaskStatus.failed || t.status == TaskStatus.cancelled,
        )
        .toList();
    final rows = switch (tab) {
      0 => acik,
      1 => teslim,
      _ => iade,
    };
    final plan = s.routePlan;
    final kmLabel = plan == null
        ? null
        : (plan.totalDistanceMeters / 1000).toStringAsFixed(1);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Display(l.distribution, size: 26),
                        const SizedBox(height: 2),
                        Text(
                          l.listSummary(s.tasks.length, acik.length, kmLabel),
                          style: Dg.ui(size: 13, color: Dg.ink3),
                        ),
                      ],
                    ),
                  ),
                  _ToggleIcon(
                    icon: LucideIcons.map,
                    active: false,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RouteScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const _ToggleIcon(icon: LucideIcons.list, active: true),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _FilterPill(
                      label: l.openTab(acik.length),
                      active: tab == 0,
                      onTap: () => setState(() => tab = 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FilterPill(
                      label: l.deliveredTab(teslim.length),
                      active: tab == 1,
                      onTap: () => setState(() => tab = 1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FilterPill(
                      label: l.returnedTab(iade.length),
                      active: tab == 2,
                      onTap: () => setState(() => tab = 2),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => s.refreshField(),
                child: rows.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          DgEmptyState(
                            icon: switch (tab) {
                              0 => LucideIcons.circleCheck,
                              1 => LucideIcons.package,
                              _ => LucideIcons.undo2,
                            },
                            title: switch (tab) {
                              0 => l.emptyOpenTitle,
                              1 => l.emptyDeliveredTitle,
                              _ => l.emptyReturnTitle,
                            },
                            body: switch (tab) {
                              0 => l.emptyOpenBody,
                              1 => l.emptyDeliveredBody,
                              _ => l.emptyReturnBody,
                            },
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        itemCount: rows.length,
                        separatorBuilder: (context, i) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          return StaggerIn(
                            index: i,
                            child: _RotaTaskCard(
                              task: rows[i],
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      TaskDetailScreen(taskId: rows[i].id),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleIcon extends StatelessWidget {
  const _ToggleIcon({required this.icon, required this.active, this.onTap});

  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Dg.primaryGradientStart : Dg.elev,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 17, color: active ? Colors.white : Dg.ink2),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Dg.primaryGradientStart : Dg.elev,
          borderRadius: BorderRadius.circular(Dg.radiusPill),
        ),
        child: Text(
          textAlign: TextAlign.center,
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : Dg.ink2,
          ),
        ),
      ),
    );
  }
}

/// Canvas'ın "1l Dağıtım listesi" kart dili: numaralı rozet + durum
/// noktası, sonra Aralık/Zimmet/Teslim kodu bilgi pilleri (açık görevler
/// için) ya da teslim/iade özeti (kapanmış görevler için).
class _RotaTaskCard extends StatelessWidget {
  const _RotaTaskCard({required this.task, required this.onTap});

  final DeliveryTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final open = task.isOpen;
    return DgCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InitialsAvatar(
                name: task.recipient,
                photoUrl: task.personPhoto,
                size: 44,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Display(task.recipient, size: 16)),
                        StatusChip(
                          label: taskStatusLabel(task.status, context.l10n),
                          tone: taskStatusTone(task.status),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          LucideIcons.chevronRight,
                          size: 16,
                          color: Dg.ink3,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      task.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: Dg.ink3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: open
                ? [
                    _InfoPill(
                      label: l.window,
                      value: task.window.split('–').first,
                    ),
                    if (task.custodyCount != null)
                      _InfoPill(
                        label: l.custody,
                        value: l.itemsCount(task.custodyCount!),
                      ),
                    if (task.otpRequired)
                      _InfoPill(
                        label: l.deliveryCode,
                        value: l.required,
                        dot: true,
                      ),
                  ]
                : [
                    _InfoPill(label: l.time, value: task.window),
                    if (task.signed)
                      _InfoPill(
                        label: '',
                        value: l.signature,
                        icon: LucideIcons.penLine,
                      ),
                    if (task.otpRequired)
                      _InfoPill(
                        label: '',
                        value: l.codeShort,
                        icon: LucideIcons.key,
                      ),
                  ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.task});

  final DeliveryTask task;

  @override
  Widget build(BuildContext context) {
    if (task.status == TaskStatus.delivered) {
      return _badge(
        color: Dg.sage,
        child: const Icon(LucideIcons.check, size: 16, color: Colors.white),
      );
    }
    if (task.status == TaskStatus.failed ||
        task.status == TaskStatus.cancelled) {
      return _badge(
        color: Dg.elev,
        child: Icon(LucideIcons.undo2, size: 16, color: Dg.ink2),
      );
    }
    return _badge(
      color: Dg.primaryGradientStart,
      child: Text(
        '${task.sequence}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _badge({required Color color, required Widget child}) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(9),
      ),
      child: child,
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.label,
    required this.value,
    this.dot = false,
    this.icon,
  });

  final String label;
  final String value;
  final bool dot;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Dg.elev,
        borderRadius: BorderRadius.circular(Dg.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label.isNotEmpty)
            Text(label, style: TextStyle(fontSize: 10, color: Dg.ink3)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: Dg.ink2),
                const SizedBox(width: 4),
              ],
              if (dot) ...[
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Dg.sand,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Dg.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
