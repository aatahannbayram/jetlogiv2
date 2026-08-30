import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'depo_screen.dart';
import 'earnings_screen.dart';
import 'envanter_screen.dart';
import 'kyc_screen.dart';
import 'list_screen.dart';
import 'profile_screen.dart';
import 'zimmet_screen.dart';

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final items = <({String label, IconData icon, Color tint, Color ink, String? badge, Widget Function() open})>[
      (
        label: 'Dağıtım Listem',
        icon: Icons.local_shipping_outlined,
        tint: Dg.violetBg,
        ink: Dg.violet,
        badge: '${s.openCount}',
        open: () => const ListScreen(),
      ),
      (
        label: 'Kurye Zimmet',
        icon: Icons.qr_code_scanner_rounded,
        tint: Dg.redBg,
        ink: Dg.red,
        badge: null,
        open: () => const ZimmetScreen(mode: 'kurye'),
      ),
      (
        label: 'Şube Zimmet',
        icon: Icons.qr_code_scanner_rounded,
        tint: Dg.greenBg,
        ink: Dg.green,
        badge: null,
        open: () => const ZimmetScreen(mode: 'sube'),
      ),
      (
        label: 'Depodan Alım',
        icon: Icons.warehouse_outlined,
        tint: Dg.blueBg,
        ink: Dg.blue,
        badge: null,
        open: () => const DepoScreen(),
      ),
      (
        label: 'Ürün Envanterim',
        icon: Icons.inventory_2_outlined,
        tint: Dg.amberBg,
        ink: Dg.amber,
        badge: s.inventoryPending > 0 ? '${s.inventoryPending}' : null,
        open: () => const EnvanterScreen(),
      ),
      (
        label: 'Kazanç & Prim',
        icon: Icons.account_balance_wallet_outlined,
        tint: Dg.greenBg,
        ink: Dg.green,
        badge: null,
        open: () => const EarningsScreen(),
      ),
      (
        label: 'Digital Test (KYC)',
        icon: Icons.badge_outlined,
        tint: Dg.blueBg,
        ink: Dg.blue,
        badge: null,
        open: () => const KycScreen(),
      ),
      (
        label: 'Profilim',
        icon: Icons.person_outline_rounded,
        tint: Dg.violetBg,
        ink: Dg.violet,
        badge: null,
        open: () => const ProfileScreen(),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 108),
          children: [
            const Display('Menü', size: 26),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
              ),
              itemBuilder: (context, i) {
                final m = items[i];
                return DgCard(
                  padding: const EdgeInsets.all(16),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => m.open())),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconTintBadge(icon: m.icon, tint: m.tint, ink: m.ink),
                          const Spacer(),
                          if (m.badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: m.tint, borderRadius: BorderRadius.circular(20)),
                              child: Text(m.badge!, style: TextStyle(fontFamily: Dg.mono, fontSize: 11, fontWeight: FontWeight.w700, color: m.ink)),
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(m.label, style: Dg.ui(size: 15, weight: FontWeight.w600, height: 1.2)),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
