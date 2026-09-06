import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../session.dart';
import '../brand.dart';
import '../motion.dart';
import '../theme.dart';
import '../widgets.dart';
import 'depo_screen.dart';
import 'earnings_screen.dart';
import 'envanter_screen.dart';
import 'kyc_screen.dart';
import 'profile_screen.dart';
import 'support_screen.dart';
import 'sync_screen.dart';
import 'tara_screen.dart';
import 'zimmet_screen.dart';

typedef _MenuRow = ({
  String label,
  IconData icon,
  String? badge,
  Widget Function() open,
});

/// Profil fotoğraflı hero + gruplu saha / hesap listeleri.
class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);
    final pending = s.outbox.events.where((e) => e.pending).length;

    final saha = <_MenuRow>[
      (
        label: l.myCustody,
        icon: LucideIcons.qrCode,
        badge: null,
        open: () => const TaraScreen(),
      ),
      (
        label: l.branchHandover,
        icon: LucideIcons.building2,
        badge: null,
        open: () => const ZimmetScreen(mode: 'sube'),
      ),
      (
        label: l.depotPickup,
        icon: LucideIcons.warehouse,
        badge: null,
        open: () => const DepoScreen(),
      ),
      (
        label: l.supportTicket,
        icon: LucideIcons.lifeBuoy,
        badge: s.tickets.isEmpty ? null : '${s.tickets.length}',
        open: () => const SupportScreen(),
      ),
      (
        label: l.sendData,
        icon: LucideIcons.uploadCloud,
        badge: pending > 0 ? '$pending' : null,
        open: () => const SyncScreen(),
      ),
      (
        label: l.myInventory,
        icon: LucideIcons.package,
        badge: s.inventoryPending > 0 ? '${s.inventoryPending}' : null,
        open: () => const EnvanterScreen(),
      ),
    ];

    final hesap = <_MenuRow>[
      (
        label: l.myPerformance,
        icon: LucideIcons.trendingUp,
        badge: null,
        open: () => const EarningsScreen(),
      ),
      (
        label: l.identityCheck,
        icon: LucideIcons.badgeCheck,
        badge: null,
        open: () => const KycScreen(),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Dg.pagePad, 12, Dg.pagePad, 28),
          children: [
            const Appear(child: DijigooWordmark(height: 28)),
            const SizedBox(height: 8),
            Text(l.menu, style: Dg.ui(size: 24, weight: FontWeight.w600)),
            const SizedBox(height: 16),
            _ProfileCard(session: s),
            const SizedBox(height: 22),
            Text(l.fieldWork, style: Dg.kicker(color: Dg.ink2)),
            const SizedBox(height: 8),
            _GroupedList(items: saha),
            const SizedBox(height: 22),
            Text(l.account, style: Dg.kicker(color: Dg.ink2)),
            const SizedBox(height: 8),
            _GroupedList(items: hesap),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.session});

  final SessionController session;

  @override
  Widget build(BuildContext context) {
    final c = session.courier;
    return GestureDetector(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const ProfileScreen())),
      child: DgCard(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: Dg.primaryGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            InitialsAvatar(name: c.fullName, photoUrl: c.photoUrl, size: 80),
            const SizedBox(height: 14),
            Text(c.fullName, style: Dg.ui(size: 22, weight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              '${session.plate} · ${c.vehicle}',
              style: Dg.ui(size: 14, color: Dg.ink2),
            ),
            const SizedBox(height: 8),
            if (session.panelLoggedIn)
              Text(
                context.l10n.panelSessionOn,
                key: const Key('panel-session-chip'),
                style: Dg.ui(size: 13, color: Dg.ink2),
              )
            else if (session.lastPanelError ==
                SessionController.panelSessionExpired)
              Text(
                context.l10n.panelSessionOff,
                key: const Key('panel-session-expired'),
                style: Dg.ui(size: 13, color: Dg.clay),
              )
            else
              Text(
                context.l10n.openProfile,
                style: Dg.ui(size: 14, weight: FontWeight.w600, color: Dg.ink2),
              ),
            const SizedBox(height: 18),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Dg.elev,
                borderRadius: BorderRadius.circular(Dg.radiusHero),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    _stat('${session.deliveredCount}', context.l10n.deliveredShort),
                    Container(width: 1, height: 36, color: Dg.rule),
                    _stat('${session.openCount}', context.l10n.openShort),
                    Container(width: 1, height: 36, color: Dg.rule),
                    _stat('${session.returnCount}', context.l10n.returnShort),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: Dg.stat(size: 24)),
          const SizedBox(height: 4),
          Text(label, style: Dg.ui(size: 13, color: Dg.ink2)),
        ],
      ),
    );
  }
}

class _GroupedList extends StatelessWidget {
  const _GroupedList({required this.items});

  final List<_MenuRow> items;

  @override
  Widget build(BuildContext context) {
    return DgCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, m) in items.indexed) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.only(left: 62),
                child: DgDivider(),
              ),
            StaggerIn(
              index: i,
              child: Pressable(
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => m.open())),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: Dg.rowMin),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Dg.violetBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            m.icon,
                            size: 18,
                            color: Dg.purpleActive,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            m.label,
                            style: Dg.ui(size: 16, weight: FontWeight.w600),
                          ),
                        ),
                        if (m.badge != null) ...[
                          Text(m.badge!, style: Dg.ui(size: 14, color: Dg.ink2)),
                          const SizedBox(width: 8),
                        ],
                        Icon(LucideIcons.chevronRight, size: 18, color: Dg.ink2),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
