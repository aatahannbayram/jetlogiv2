import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../motion.dart';
import '../session.dart';
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
  Color tint,
  Color ink,
  Widget Function() open,
});

/// Profil fotoğraflı hero + 2 sütun saha kartları + tek hesap kartı.
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
        tint: Dg.violetBg,
        ink: Dg.violet,
        open: () => const TaraScreen(),
      ),
      (
        label: l.branchHandover,
        icon: LucideIcons.building2,
        badge: null,
        tint: Dg.blueBg,
        ink: Dg.blue,
        open: () => const ZimmetScreen(mode: 'sube'),
      ),
      (
        label: l.depotPickup,
        icon: LucideIcons.warehouse,
        badge: null,
        tint: Dg.amberBg,
        ink: Dg.amber,
        open: () => const DepoScreen(),
      ),
      (
        label: l.supportTicket,
        icon: LucideIcons.lifeBuoy,
        badge: s.tickets.isEmpty ? null : '${s.tickets.length}',
        tint: Dg.greenBg,
        ink: Dg.green,
        open: () => const SupportScreen(),
      ),
      (
        label: l.sendData,
        icon: LucideIcons.uploadCloud,
        badge: pending > 0 ? '$pending' : null,
        tint: Dg.violetBg,
        ink: Dg.violet,
        open: () => const SyncScreen(),
      ),
      (
        label: l.myInventory,
        icon: LucideIcons.package,
        badge: s.inventoryPending > 0 ? '${s.inventoryPending}' : null,
        tint: Dg.amberBg,
        ink: Dg.amber,
        open: () => const EnvanterScreen(),
      ),
    ];

    final hesap = <_MenuRow>[
      (
        label: l.myPerformance,
        icon: LucideIcons.trendingUp,
        badge: null,
        tint: Dg.greenBg,
        ink: Dg.green,
        open: () => const EarningsScreen(),
      ),
      (
        label: l.identityCheck,
        icon: LucideIcons.badgeCheck,
        badge: null,
        tint: Dg.blueBg,
        ink: Dg.blue,
        open: () => const KycScreen(),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 108),
          children: [
            Display(l.menu, size: 26),
            const SizedBox(height: 16),
            _ProfileCard(session: s),
            const SizedBox(height: 22),
            Mono(
              l.fieldWork,
              size: 11,
              weight: FontWeight.w600,
              color: Dg.ink3,
            ),
            const SizedBox(height: 12),
            _Grid(items: saha),
            const SizedBox(height: 22),
            Mono(l.account, size: 11, weight: FontWeight.w600, color: Dg.ink3),
            const SizedBox(height: 12),
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
    return DgCard(
      dark: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const ProfileScreen())),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(name: c.fullName, photoUrl: c.photoUrl, size: 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Mono(
                      '${session.plate} · ${c.vehicle}',
                      size: 12,
                      color: const Color(0xFF9A9E90),
                    ),
                    const SizedBox(height: 8),
                    if (session.panelLoggedIn)
                      Text(
                        context.l10n.panelSessionOn,
                        key: const Key('panel-session-chip'),
                        style: const TextStyle(
                          color: Color(0xFFB7C4C1),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else if (session.lastPanelError ==
                        SessionController.panelSessionExpired)
                      Text(
                        context.l10n.panelSessionOff,
                        key: const Key('panel-session-expired'),
                        style: const TextStyle(
                          color: Color(0xFFC9A9A4),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Text(
                        context.l10n.openProfile,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _stat(
                '${session.deliveredCount}',
                context.l10n.deliveredShort,
                Dg.sage,
              ),
              const SizedBox(width: 8),
              _stat('${session.openCount}', context.l10n.openShort, Dg.sand),
              const SizedBox(width: 8),
              _stat('${session.returnCount}', context.l10n.returnShort, Dg.clay),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, Color tone) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: tone,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(value, style: Dg.stat(size: 20, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Color(0xFF9A9E90), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.items});

  final List<_MenuRow> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (context, i) {
        final m = items[i];
        return StaggerIn(
          index: i,
          child: DgCard(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            onTap: () =>
                Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => m.open())),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: m.tint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(m.icon, size: 18, color: m.ink),
                    ),
                    const Spacer(),
                    if (m.badge != null)
                      StatusChip(label: m.badge!, tone: 'mid'),
                  ],
                ),
                const Spacer(),
                Text(
                  m.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Dg.ui(size: 14, weight: FontWeight.w700),
                ),
              ],
            ),
          ),
        );
      },
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
            if (i > 0) Divider(height: 1, color: Dg.rule, indent: 68),
            InkWell(
              onTap: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => m.open())),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: m.tint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(m.icon, size: 18, color: m.ink),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        m.label,
                        style: Dg.ui(size: 15, weight: FontWeight.w600),
                      ),
                    ),
                    if (m.badge != null) ...[
                      StatusChip(label: m.badge!, tone: 'mid'),
                      const SizedBox(width: 8),
                    ],
                    Icon(LucideIcons.chevronRight, size: 18, color: Dg.ink3),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
