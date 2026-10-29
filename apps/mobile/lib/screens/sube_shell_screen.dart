import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../motion.dart';
import '../scan_router.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'onboard_screen.dart';
import 'sube_couriers_screen.dart';
import 'sube_home_screen.dart';
import 'sube_nav.dart';
import 'sube_ops_screen.dart';
import 'sube_profile_screen.dart';
import 'sube_scan_sheet.dart';
import 'sube_shipments_screen.dart';

/// Şube/Acente kabuğu: Ana Sayfa • Gönderiler • Kuryeler • İşlemler •
/// Profil ve sabit "Barkod Okut". Okutma, açık sekmenin bağlamına gider.
/// Stok & Zimmet, İşlemler'in altındadır.
class SubeShellScreen extends ConsumerStatefulWidget {
  const SubeShellScreen({super.key});

  @override
  ConsumerState<SubeShellScreen> createState() => _SubeShellScreenState();
}

class _SubeShellScreenState extends ConsumerState<SubeShellScreen> {
  bool _navCompact = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionProvider).branch.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    if (!s.subeOnboardSeen) {
      return const OnboardScreen(forBranch: true);
    }
    final l = context.l10n;
    final index = ref.watch(subeTabProvider);
    const pages = [
      SubeHomeScreen(),
      SubeShipmentsScreen(),
      SubeCouriersScreen(),
      SubeOpsScreen(),
      SubeProfileScreen(),
    ];
    // İşlemler'de okutma, alt ekranların (sayım, sevk) kendi düğmesinden
    // yapılır; orada ve Profil'de genel sorgu açılır.
    final scans = <(ScanContext, String)>[
      (ScanContext.lookup, 'Gönderi barkodu okutun'),
      (ScanContext.assign, 'Zimmete eklenecek gönderiyi okutun'),
      (ScanContext.lookup, 'Gönderi barkodu okutun'),
      (ScanContext.lookup, 'Gönderi barkodu okutun'),
      (ScanContext.lookup, 'Gönderi barkodu okutun'),
    ];
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    void openScan() => showSubeScanSheet(
      context,
      scanContext: scans[index].$1,
      hint: scans[index].$2,
    );
    final unread = (s.branch.inbox ?? const []).where((i) => !i.read).length;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: NavShrinkOnScroll(
          compact: _navCompact,
          onCompact: (v) => setState(() => _navCompact = v),
          child: DgTabStack(index: index, children: pages),
        ),
      ),
      // Büyük yazı ayarında yüzen düğme içeriği kapatır; alt çubuğun üstüne
      // tam genişlikte düğme olarak iner. Profil'de okutma düğmesi yok.
      floatingActionButton: largeText || index == SubeTab.profile
          ? null
          : AnimatedScale(
              scale: _navCompact ? 0.9 : 1,
              duration: DgMotion.quick,
              curve: DgMotion.enter,
              child: FloatingActionButton.extended(
                onPressed: openScan,
                icon: DgIcon(
                  LucideIcons.scanLine,
                  color: Dg.onAction,
                  weight: 600,
                ),
                label: Text(l.scanAction),
              ),
            ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (largeText && index != SubeTab.profile)
            Padding(
              padding: const EdgeInsets.all(12),
              child: DgButton(
                label: l.scanAction,
                icon: LucideIcons.scanLine,
                onPressed: openScan,
              ),
            ),
          DgPillNav(
            index: index,
            compact: _navCompact,
            badges: [0, 0, 0, 0, unread],
            onChanged: (i) {
              ref.read(subeTabProvider.notifier).state = i;
              setState(() => _navCompact = false);
            },
            items: [
              (LucideIcons.house, LucideIcons.house, l.subeTabHome),
              (
                LucideIcons.package,
                LucideIcons.packageCheck,
                l.subeTabShipments,
              ),
              (LucideIcons.users, LucideIcons.usersRound, l.subeTabCouriers),
              (LucideIcons.layoutGrid, LucideIcons.layoutGrid, l.subeTabOps),
              (
                LucideIcons.circleUser,
                LucideIcons.circleUserRound,
                l.subeTabProfile,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
