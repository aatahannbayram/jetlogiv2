import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../motion.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'depo_screen.dart';
import 'earnings_screen.dart';
import 'envanter_screen.dart';
import 'kyc_screen.dart';
import 'profile_screen.dart';
import 'sync_screen.dart';
import 'tara_screen.dart';
import 'zimmet_screen.dart';

typedef _MenuRow = ({
  String label,
  IconData icon,
  String? badge,
  Widget Function() open,
});

/// Canvas'ın "1k Menü" tasarımı — renkli 2 sütunlu kart grid'i yerine üstte
/// profil özet kartı + düz liste satırları.
class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final pending = s.outbox.events.where((e) => e.pending).length;

    final saha = <_MenuRow>[
      (
        label: 'Zimmetim',
        icon: LucideIcons.qrCode,
        badge: null,
        open: () => const TaraScreen(),
      ),
      (
        label: 'Şubeye teslim',
        icon: LucideIcons.building2,
        badge: null,
        open: () => const ZimmetScreen(mode: 'sube'),
      ),
      (
        label: 'Depodan alım',
        icon: LucideIcons.warehouse,
        badge: null,
        open: () => const DepoScreen(),
      ),
      (
        label: 'Verileri gönder',
        icon: LucideIcons.uploadCloud,
        badge: pending > 0 ? '$pending' : null,
        open: () => const SyncScreen(),
      ),
      (
        label: 'Ürün envanterim',
        icon: LucideIcons.package,
        badge: s.inventoryPending > 0 ? '${s.inventoryPending}' : null,
        open: () => const EnvanterScreen(),
      ),
    ];

    final hesap = <_MenuRow>[
      (
        label: 'Performansım',
        icon: LucideIcons.trendingUp,
        badge: null,
        open: () => const EarningsScreen(),
      ),
      (
        label: 'Kimlik doğrulama',
        icon: LucideIcons.badgeCheck,
        badge: null,
        open: () => const KycScreen(),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 108),
          children: [
            const Display('Menü', size: 26),
            const SizedBox(height: 18),
            _ProfileCard(session: s),
            const SizedBox(height: 22),
            _Section(title: 'SAHA İŞLERİ', items: saha),
            const SizedBox(height: 20),
            _Section(title: 'HESAP', items: hesap),
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
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const ProfileScreen())),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(name: c.fullName, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Mono(
                      '${session.plate} · ${c.vehicle}',
                      size: 12,
                      color: const Color(0xFF9A9E90),
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
          Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 16),
          Row(
            children: [
              _stat('${session.deliveredCount}', 'teslim', Dg.sage),
              _stat('${session.openCount}', 'açık', Dg.sand),
              _stat('${session.returnCount}', 'iade', Dg.clay),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, Color tone) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
              ),
              Text(value, style: Dg.stat(size: 22, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF9A9E90), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.items});

  final String title;
  final List<_MenuRow> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Mono(title, size: 11, weight: FontWeight.w600, color: Dg.ink3),
        const SizedBox(height: 10),
        for (final (i, m) in items.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: StaggerIn(
              index: i,
              child: DgCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => m.open())),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Dg.elev,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(m.icon, size: 17, color: Dg.ink2),
                    ),
                    const SizedBox(width: 14),
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
          ),
      ],
    );
  }
}
