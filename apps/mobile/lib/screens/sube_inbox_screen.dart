import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/branch_models.dart';
import '../l10n.dart';
import '../motion.dart';
import '../session.dart';
import '../theme.dart';
import '../ui/ui.dart';
import '../widgets.dart';
import 'sube_manage_screens.dart';
import 'sube_more_screens.dart';
import 'sube_widgets.dart';

/// Bildirimler (mockup 22): kategori sekmeleri (Tümü / Okunmamış /
/// kategoriler / duyurular / operasyon uyarıları), okunmamış noktası;
/// dokununca okundu işaretlenir. Yönetici duyuru yayımlar.
class SubeInboxScreen extends ConsumerStatefulWidget {
  const SubeInboxScreen({super.key});

  @override
  ConsumerState<SubeInboxScreen> createState() => _SubeInboxScreenState();
}

class _SubeInboxScreenState extends ConsumerState<SubeInboxScreen> {
  /// Seçili sekme anahtarı: `all`, `unread`, `cat:<KOD>`, `news`, `alerts`.
  String _tab = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionProvider).branch.loadInbox();
    });
  }

  Future<void> _announce() async {
    final l = context.l10n;
    final input = await showSubeComposeSheet(
      context,
      heading: l.newAnnouncement,
      titleHint: l.announceTitle,
      bodyHint: l.announceBody,
      flagLabel: l.announceRequiresAck,
      submitLabel: l.publish,
    );
    if (input == null || !mounted) return;
    final error = await ref
        .read(sessionProvider)
        .branch
        .publishAnnouncement(
          title: input.title,
          body: input.body,
          requiresAck: input.flag,
        );
    if (mounted) subeSnack(context, error ?? l.announcePublished);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final branch = ref.watch(sessionProvider).branch;
    final inbox = branch.inbox ?? const <InboxItem>[];
    final news = branch.announcements;
    final categories = {for (final i in inbox) i.category}.toList()..sort();
    final tabs = <(String, String, int)>[
      ('all', l.all, inbox.length),
      ('unread', l.inboxUnread, inbox.where((i) => !i.read).length),
      for (final c in categories)
        (
          'cat:$c',
          l.inboxCategory(c),
          inbox.where((i) => i.category == c).length,
        ),
      if (news != null && news.announcements.isNotEmpty)
        ('news', l.subeAnnouncements, news.announcements.length),
      if (news != null && news.alerts.isNotEmpty)
        ('alerts', l.subeAlerts, news.alerts.length),
    ];
    final index = tabs
        .indexWhere((t) => t.$1 == _tab)
        .clamp(0, tabs.length - 1);
    final key = tabs[index].$1;
    final items = switch (key) {
      'unread' => [
        for (final i in inbox)
          if (!i.read) i,
      ],
      'news' => news?.announcements ?? const <InboxItem>[],
      'alerts' => news?.alerts ?? const <InboxItem>[],
      'all' => inbox,
      _ => [
        for (final i in inbox)
          if ('cat:${i.category}' == key) i,
      ],
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(l.subeInboxTitle),
        actions: branch.demo
            ? null
            : [
                IconButton(
                  icon: const Icon(LucideIcons.megaphone),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SubeAnnouncementsScreen(),
                    ),
                  ),
                ),
              ],
      ),
      body: RefreshIndicator(
        onRefresh: branch.loadInbox,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            DgPillTabs(
              labels: [for (final t in tabs) t.$2],
              counts: [for (final t in tabs) t.$3],
              index: index,
              onChanged: (i) => setState(() => _tab = tabs[i].$1),
            ),
            const SizedBox(height: 12),
            SubeStatusBanner(branch: branch, onRetry: branch.loadInbox),
            if (branch.capabilities.manage) ...[
              DgButton(
                label: l.newAnnouncement,
                icon: LucideIcons.megaphone,
                tone: DgButtonTone.secondary,
                onPressed: _announce,
              ),
              const SizedBox(height: 12),
            ],
            if (branch.inbox == null && branch.loading)
              for (var i = 0; i < 3; i++)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: DgSkeleton(height: 64, radius: 16),
                )
            else if (items.isEmpty)
              DgEmptyState(icon: LucideIcons.bell, title: l.inboxEmpty)
            else
              for (var i = 0; i < items.length; i++)
                StaggerIn(
                  index: i,
                  child: _InboxTile(
                    item: items[i],
                    onTap: key == 'news' || key == 'alerts'
                        ? null
                        : () => branch.markRead(items[i]),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _InboxTile extends StatelessWidget {
  const _InboxTile({required this.item, this.onTap});

  final InboxItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tone = switch (item.severity) {
      'CRITICAL' => DgTone.bad,
      'WARNING' => DgTone.warn,
      _ => DgTone.info,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DgPanel(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DgIconBadge(
              icon: switch (item.severity) {
                'CRITICAL' => LucideIcons.circleAlert,
                'WARNING' => LucideIcons.triangleAlert,
                _ => LucideIcons.bell,
              },
              tone: item.read ? DgTone.neutral : tone,
              size: 38,
              soft: true,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.body.isEmpty
                        ? l.inboxCategory(item.category)
                        : item.body,
                    style: Dg.ui(
                      size: 15,
                      weight: item.read ? FontWeight.w400 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      l.inboxCategory(item.category),
                      if (item.createdAt != null) subeClock(item.createdAt!),
                    ].join(' · '),
                    style: Dg.typeCaption(),
                  ),
                ],
              ),
            ),
            if (!item.read)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 6),
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: Dg.brandTurquoise,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
