import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'sube_courier_detail_screen.dart';
import 'sube_widgets.dart';

/// Kurye havuzu: canlı durum, üzerindeki ve geciken adet, son görülme.
class SubeCouriersScreen extends ConsumerWidget {
  const SubeCouriersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final branch = ref.watch(sessionProvider).branch;
    final couriers = branch.dashboard?.courierList ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(l.subeCouriersTitle)),
      body: RefreshIndicator(
        onRefresh: branch.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
          children: [
            SubeStatusBanner(branch: branch),
            if (couriers.isEmpty && !branch.loading)
              DgEmptyState(icon: LucideIcons.users, title: l.emptyCouriers),
            for (final c in couriers)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DgCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SubeCourierDetailScreen(
                        courierId: c.id,
                        fallbackName: c.name,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      InitialsAvatar(
                        name: c.name,
                        size: 40,
                        online: c.liveStatus == 'ACTIVE',
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: Dg.ui(size: 15, weight: FontWeight.w600),
                            ),
                            Text(
                              [
                                l.holdingCount(c.holdingCount),
                                if (c.overdueCount > 0)
                                  l.overdueCount(c.overdueCount),
                              ].join(' · '),
                              style: Dg.ui(
                                size: 12,
                                color: c.overdueCount > 0 ? Dg.hi : Dg.ink3,
                              ),
                            ),
                            if (c.lastSeenAt != null)
                              Text(
                                l.lastSeenAt(subeClock(c.lastSeenAt!)),
                                style: Dg.ui(size: 12, color: Dg.ink3),
                              ),
                          ],
                        ),
                      ),
                      StatusChip(
                        label: switch (c.liveStatus) {
                          'ACTIVE' => l.liveActive,
                          'BREAK' => l.liveBreak,
                          _ => l.liveOffline,
                        },
                        tone: switch (c.liveStatus) {
                          'ACTIVE' => 'lo',
                          'BREAK' => 'mid',
                          _ => '',
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
