import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../session.dart';
import '../widgets.dart';

class NotifScreen extends ConsumerWidget {
  const NotifScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.notifications),
        actions: [
          TextButton(
            onPressed: s.unreadNotifCount == 0
                ? null
                : s.markAllNotificationsRead,
            child: Text(l.markAllRead),
          ),
        ],
      ),
      body: s.notifications.isEmpty
          ? Center(
              child: DgEmptyState(
                icon: LucideIcons.bellOff,
                title: l.noNotifications,
                body: l.noNotifBody,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 108),
              itemCount: s.notifications.length,
              separatorBuilder: (context, i) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final n = s.notifications[i];
                final unread = !s.isNotifRead(i);
                return Opacity(
                  opacity: unread ? 1 : 0.68,
                  child: NotifCard(
                    notification: n,
                    unread: unread,
                    onTap: () => s.markNotificationRead(i),
                  ),
                );
              },
            ),
    );
  }
}
