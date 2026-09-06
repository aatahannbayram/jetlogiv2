import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../models.dart';
import '../motion.dart';
import '../road.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(sessionProvider).ensureDayRoute());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);
    final acik = s.orderedOpenTasks;
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
    final day = s.dayRoute;
    final kmLabel = day != null
        ? (day.meters / 1000).toStringAsFixed(1)
        : s.routePlan == null
        ? null
        : (s.routePlan!.totalDistanceMeters / 1000).toStringAsFixed(1);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Appear(
              child: Padding(
              padding: const EdgeInsets.fromLTRB(Dg.pagePad, 8, Dg.pagePad, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.distribution,
                          style: Dg.ui(size: 22, weight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.listSummary(s.tasks.length, acik.length, kmLabel),
                          style: Dg.ui(size: 13, color: Dg.ink3),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RouteScreen(),
                      ),
                    ),
                    child: Icon(LucideIcons.map, size: 22, color: Dg.ink),
                  ),
                ],
              ),
            ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: SegmentedTabs(
                labels: [
                  l.openTab(acik.length),
                  l.deliveredTab(teslim.length),
                  l.returnedTab(iade.length),
                ],
                index: tab,
                onChanged: (i) => setState(() => tab = i),
              ),
            ),
            DgDivider(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: dgSwitchTransition,
                child: KeyedSubtree(
                  key: ValueKey(tab),
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
                    : Builder(
                        builder: (context) {
                          final items = _groupRows(rows);
                          final visitAt = <String, int>{
                            for (var i = 0; i < acik.length; i++) acik[i].id: i + 1,
                          };
                          return ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(
                              Dg.pagePad,
                              10,
                              Dg.pagePad,
                              24,
                            ),
                            itemCount: items.length,
                            separatorBuilder: (context, i) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final item = items[i];
                              void openTask(String id) =>
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          TaskDetailScreen(taskId: id),
                                    ),
                                  );
                              return StaggerIn(
                                index: i,
                                child: item.length == 1
                                    ? _RotaTaskCard(
                                        task: item.single,
                                        visitIndex: visitAt[item.single.id],
                                        travel: s.roadToTask(item.single.id),
                                        onTap: () => openTask(item.single.id),
                                      )
                                    : _GroupedTaskCard(
                                        tasks: item,
                                        onTapTask: openTask,
                                      ),
                              );
                            },
                          );
                        },
                      ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [rows]'u aynı [DeliveryTask.groupKey] değerine sahip görevler için
/// birleştirir — her eleman ya tek bir görev (`length == 1`) ya da "aynı
/// adres" grubu (`length >= 2`) olur. Sıra korunur, gruplar ilk görüldükleri
/// yerde oluşur.
List<List<DeliveryTask>> _groupRows(List<DeliveryTask> rows) {
  final byKey = <String, List<DeliveryTask>>{};
  for (final t in rows) {
    final key = t.groupKey;
    if (key != null) (byKey[key] ??= []).add(t);
  }
  final out = <List<DeliveryTask>>[];
  final seenKeys = <String>{};
  for (final t in rows) {
    final key = t.groupKey;
    if (key != null && byKey[key]!.length > 1) {
      if (seenKeys.add(key)) out.add(byKey[key]!);
    } else {
      out.add([t]);
    }
  }
  return out;
}

/// Canvas'ın "aynı adres" kartı: tek bir adres altında birden çok alıcı —
/// "Birlikte teslim edilebilir" rozetiyle işaretlenir, her satır kendi
/// görev detayına gider.
class _GroupedTaskCard extends StatelessWidget {
  const _GroupedTaskCard({required this.tasks, required this.onTapTask});

  final List<DeliveryTask> tasks;
  final ValueChanged<String> onTapTask;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final first = tasks.first;
    return DgCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.sameAddressCount(tasks.length),
                style: Dg.ui(size: 13, weight: FontWeight.w600),
              ),
              Text(
                first.address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Dg.ui(size: 12, color: Dg.ink3),
              ),
              const SizedBox(height: 4),
              StatusChip(label: l.deliverTogether, tone: 'lime'),
            ],
          ),
        ),
          for (final t in tasks)
            InkWell(
              onTap: () => onTapTask(t.id),
              borderRadius: BorderRadius.circular(Dg.radius),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    InitialsAvatar(
                      name: t.recipient,
                      photoUrl: t.personPhoto,
                      size: 34,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.recipient,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Dg.ink,
                            ),
                          ),
                          Text(
                            t.window,
                            style: TextStyle(fontSize: 12, color: Dg.ink3),
                          ),
                        ],
                      ),
                    ),
                    StatusChip(
                      label: taskStatusLabel(t.status, l),
                      tone: taskStatusTone(t.status),
                    ),
                    const SizedBox(width: 4),
                    Icon(LucideIcons.chevronRight, size: 16, color: Dg.ink3),
                  ],
                ),
              ),
            ),
      ],
      ),
    );
  }
}

/// Canvas'ın "1l Dağıtım listesi" kart dili: numaralı rozet + durum
/// noktası, sonra Aralık/Zimmet/Teslim kodu bilgi pilleri (açık görevler
/// için) ya da teslim/iade özeti (kapanmış görevler için).
class _RotaTaskCard extends StatelessWidget {
  const _RotaTaskCard({
    required this.task,
    required this.onTap,
    this.visitIndex,
    this.travel,
  });

  final DeliveryTask task;
  final VoidCallback onTap;
  final int? visitIndex;
  final RoadSlice? travel;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final open = task.isOpen;
    return DgCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: open ? Dg.violetBg : Dg.elev,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${visitIndex ?? task.sequence}',
                style: Dg.ui(
                  size: 12,
                  weight: FontWeight.w700,
                  color: open ? Dg.purpleActive : Dg.ink3,
                ),
              ),
            ),
            const SizedBox(width: 10),
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.recipient,
                          style: Dg.ui(size: 16, weight: FontWeight.w600),
                        ),
                      ),
                      StatusChip(
                        label: taskStatusLabel(task.status, context.l10n),
                        tone: taskStatusTone(task.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    task.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Dg.ui(size: 13, color: Dg.ink3),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    open
                        ? [
                            if (travel != null)
                              context.l10n.routeKmMin(
                                (travel!.meters / 1000).toStringAsFixed(1),
                                travel!.minutes,
                              ),
                            task.window,
                            if (task.custodyCount != null)
                              l.itemsCount(task.custodyCount!),
                            if (task.otpRequired) l.deliveryCode,
                          ].join('  ·  ')
                        : [
                            task.window,
                            if (task.signed) l.signature,
                            if (task.otpRequired) l.codeShort,
                          ].join('  ·  '),
                    style: Dg.ui(size: 12, color: Dg.ink3),
                  ),
                ],
              ),
            ),
          ],
      ),
    );
  }
}
