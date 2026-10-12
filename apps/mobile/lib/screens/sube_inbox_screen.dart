import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/branch_models.dart';
import '../l10n.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'sube_manage_screens.dart';
import 'sube_widgets.dart';

/// Şube kullanıcısının bildirim kutusu, duyurular ve operasyon uyarıları.
class SubeInboxScreen extends ConsumerStatefulWidget {
  const SubeInboxScreen({super.key});

  @override
  ConsumerState<SubeInboxScreen> createState() => _SubeInboxScreenState();
}

class _SubeInboxScreenState extends ConsumerState<SubeInboxScreen> {
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
    final inbox = branch.inbox;
    final news = branch.announcements;
    return Scaffold(
      appBar: AppBar(title: Text(l.subeInboxTitle)),
      body: RefreshIndicator(
        onRefresh: branch.loadInbox,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
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
            if (inbox == null && branch.loading)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (inbox != null) ...[
              if (inbox.isEmpty &&
                  (news?.announcements.isEmpty ?? true) &&
                  (news?.alerts.isEmpty ?? true))
                DgEmptyState(icon: LucideIcons.bell, title: l.nothingWaiting),
              for (final item in inbox)
                _InboxTile(item: item, onTap: () => branch.markRead(item)),
            ],
            if (news != null && news.alerts.isNotEmpty) ...[
              SubeSection(l.subeAlerts, trailing: '${news.alerts.length}'),
              for (final item in news.alerts) _InboxTile(item: item),
            ],
            if (news != null && news.announcements.isNotEmpty) ...[
              SubeSection(
                l.subeAnnouncements,
                trailing: '${news.announcements.length}',
              ),
              for (final item in news.announcements) _InboxTile(item: item),
            ],
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
    final color = switch (item.severity) {
      'CRITICAL' => Dg.hi,
      'WARNING' => Dg.mid,
      _ => Dg.ink3,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DgCard(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 10),
              child: Icon(
                item.read ? LucideIcons.circle : LucideIcons.circleDot,
                size: 12,
                color: color,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.body.isEmpty ? item.category : item.body,
                    style: Dg.ui(
                      size: 14,
                      weight: item.read ? FontWeight.w400 : FontWeight.w600,
                    ),
                  ),
                  if (item.createdAt != null)
                    Text(
                      subeClock(item.createdAt!),
                      style: Dg.ui(size: 12, color: Dg.ink3),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
