import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../models.dart';
import '../motion.dart';
import '../notif.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'earnings_screen.dart';
import 'sync_screen.dart';
import 'tara_screen.dart';
import 'task_detail_screen.dart';

Future<void> openAppNotification(
  BuildContext context,
  SessionController s,
  AppNotification n,
) async {
  s.markNotificationRead(n.id);
  if (!context.mounted) return;
  final nav = Navigator.of(context);
  switch (notifOpenTarget(n.kind)) {
    case NotifOpenTarget.task:
      final id = n.taskId;
      if (id != null && !s.tasks.any((t) => t.id == id) && s.liveApi) {
        await s.pullTasks();
      }
      if (id != null && s.tasks.any((t) => t.id == id)) {
        await nav.push(
          MaterialPageRoute<void>(builder: (_) => TaskDetailScreen(taskId: id)),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.notifStopGone)));
      }
    case NotifOpenTarget.sync:
      await nav.push(
        MaterialPageRoute<void>(builder: (_) => const SyncScreen()),
      );
    case NotifOpenTarget.custody:
      await nav.push(
        MaterialPageRoute<void>(builder: (_) => const TaraScreen()),
      );
    case NotifOpenTarget.earnings:
      await nav.push(
        MaterialPageRoute<void>(builder: (_) => const EarningsScreen()),
      );
    case NotifOpenTarget.none:
      break;
  }
}

class NotifScreen extends ConsumerStatefulWidget {
  const NotifScreen({super.key});

  @override
  ConsumerState<NotifScreen> createState() => _NotifScreenState();
}

class _NotifScreenState extends ConsumerState<NotifScreen> {
  NotifFilter _filter = NotifFilter.all;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);
    final canPop = Navigator.canPop(context);
    final visible = s.visibleNotifications;
    final unread = s.unreadNotifCount;
    final filtered = filterNotifications(
      items: visible,
      filter: _filter,
      isRead: s.isNotifRead,
    );
    final now = DateTime.now();
    final rows = <Object>[];
    NotifDayGroup? lastGroup;
    for (final n in filtered) {
      final g = notifDayGroup(n.createdAt, now);
      if (g != lastGroup) {
        rows.add(g);
        lastGroup = g;
      }
      rows.add(n);
    }

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
                    if (canPop) ...[
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8, top: 4),
                          child: Icon(
                            LucideIcons.chevronLeft,
                            size: 22,
                            color: Dg.ink,
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.notifications,
                            style: Dg.ui(size: 22, weight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            unread == 0 ? l.allCaughtUp : l.unreadLeft(unread),
                            style: Dg.ui(size: 13, color: Dg.ink3),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      key: const Key('notif-mark-all'),
                      onPressed: unread == 0
                          ? null
                          : () {
                              HapticFeedback.selectionClick();
                              s.markAllNotificationsRead();
                            },
                      child: Text(l.markAllRead),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: SegmentedTabs(
                labels: [l.all, l.notifUnread, l.notifAlerts],
                index: _filter.index,
                onChanged: (i) =>
                    setState(() => _filter = NotifFilter.values[i]),
              ),
            ),
            const DgDivider(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: RefreshIndicator(
                  key: ValueKey(_filter),
                  onRefresh: () => s.refreshField(),
                  child: filtered.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            DgEmptyState(
                              icon: switch (_filter) {
                                NotifFilter.unread => LucideIcons.bell,
                                NotifFilter.alerts => LucideIcons.circleAlert,
                                NotifFilter.all => LucideIcons.bellOff,
                              },
                              title: switch (_filter) {
                                NotifFilter.unread => l.noUnreadTitle,
                                NotifFilter.alerts => l.noAlertNotifs,
                                NotifFilter.all => l.noNotifications,
                              },
                              body: switch (_filter) {
                                NotifFilter.unread => l.noUnreadBody,
                                NotifFilter.alerts => l.noAlertNotifsBody,
                                NotifFilter.all => l.noNotifBody,
                              },
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            Dg.pagePad,
                            8,
                            Dg.pagePad,
                            24,
                          ),
                          itemCount: rows.length,
                          itemBuilder: (context, i) {
                            final row = rows[i];
                            if (row is NotifDayGroup) {
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                                child: Text(
                                  switch (row) {
                                    NotifDayGroup.today => l.today,
                                    NotifDayGroup.yesterday => l.yesterday,
                                    NotifDayGroup.earlier => l.earlier,
                                  },
                                  style: Dg.ui(
                                    size: 12,
                                    weight: FontWeight.w600,
                                    color: Dg.ink3,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              );
                            }
                            final n = row as AppNotification;
                            final unreadItem = !s.isNotifRead(n.id);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Dismissible(
                                key: ValueKey(n.id),
                                background: unreadItem
                                    ? _SwipeCue(
                                        align: Alignment.centerLeft,
                                        color: Dg.greenBg,
                                        icon: LucideIcons.check,
                                        ink: Dg.green,
                                        label: l.notifMarkedRead,
                                      )
                                    : _SwipeCue(
                                        align: Alignment.centerLeft,
                                        color: Dg.blueBg,
                                        icon: LucideIcons.bell,
                                        ink: Dg.blue,
                                        label: l.notifMarkedUnread,
                                      ),
                                secondaryBackground: _SwipeCue(
                                  align: Alignment.centerRight,
                                  color: Dg.redBg,
                                  icon: LucideIcons.eyeOff,
                                  ink: Dg.red,
                                  label: l.notifHide,
                                ),
                                confirmDismiss: (dir) async {
                                  if (dir == DismissDirection.startToEnd) {
                                    HapticFeedback.selectionClick();
                                    if (unreadItem) {
                                      s.markNotificationRead(n.id);
                                    } else {
                                      s.markNotificationUnread(n.id);
                                    }
                                    return false;
                                  }
                                  HapticFeedback.lightImpact();
                                  s.dismissNotification(n.id);
                                  if (!context.mounted) return true;
                                  ScaffoldMessenger.of(context)
                                    ..clearSnackBars()
                                    ..showSnackBar(
                                      SnackBar(
                                        content: Text(l.notifHidden),
                                        action: SnackBarAction(
                                          label: l.undo,
                                          onPressed: () =>
                                              s.restoreNotification(n.id),
                                        ),
                                      ),
                                    );
                                  return true;
                                },
                                child: RepaintBoundary(
                                  child: NotifCard(
                                    key: Key('notif-${n.id}'),
                                    notification: n,
                                    unread: unreadItem,
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      openAppNotification(context, s, n);
                                    },
                                    onLongPress: () {
                                      HapticFeedback.selectionClick();
                                      if (unreadItem) {
                                        s.markNotificationRead(n.id);
                                      } else {
                                        s.markNotificationUnread(n.id);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
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

class _SwipeCue extends StatelessWidget {
  const _SwipeCue({
    required this.align,
    required this.color,
    required this.icon,
    required this.ink,
    required this.label,
  });

  final Alignment align;
  final Color color;
  final IconData icon;
  final Color ink;
  final String label;

  @override
  Widget build(BuildContext context) {
    final start = align == Alignment.centerLeft;
    return Container(
      alignment: align,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(Dg.radiusHero),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (start) ...[
            Icon(icon, size: 16, color: ink),
            const SizedBox(width: 6),
            Text(label, style: Dg.ui(size: 13, weight: FontWeight.w600, color: ink)),
          ] else ...[
            Text(label, style: Dg.ui(size: 13, weight: FontWeight.w600, color: ink)),
            const SizedBox(width: 6),
            Icon(icon, size: 16, color: ink),
          ],
        ],
      ),
    );
  }
}
