import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../motion.dart';
import '../scan_router.dart';
import '../session.dart';
import '../shell_nav.dart';
import '../theme.dart';
import '../widgets.dart';
import 'sube_couriers_screen.dart';
import 'sube_home_screen.dart';
import 'sube_ops_screen.dart';
import 'sube_profile_screen.dart';
import 'sube_scan_sheet.dart';
import 'sube_shipments_screen.dart';

/// Şube/Acente kabuğu: Ana Sayfa • Gönderiler • Kuryeler • İşlemler •
/// Profil ve sabit "Barkod Okut". Okutma, açık sekmenin bağlamına gider.
/// Stok & Zimmet İşlemler'in altındadır.
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
      final branch = ref.read(sessionProvider).branch;
      branch.refresh();
      // Üst bardaki zil rozeti açılışta dolsun (Bildirimler açılmadan).
      branch.loadInbox();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final nav = ref.watch(subeNavProvider);
    final index = nav.index;
    // Eski tasarımdaki tanıtım kartları gösterilmez (mockup'larda yok);
    // giriş doğrudan ana sayfaya açılır.
    final l = context.l10n;
    const pages = [
      SubeHomeScreen(),
      SubeShipmentsScreen(),
      SubeCouriersScreen(),
      SubeOpsScreen(),
      SubeProfileScreen(),
    ];
    // İşlemler sekmesinde okutma, alt ekranların (sayım, sevk) kendi
    // düğmesinden yapılır; orada genel sorgu açılır.
    final scans = <(ScanContext, String)>[
      (ScanContext.lookup, 'Gönderi barkodu okutun'),
      (ScanContext.assign, 'Zimmete eklenecek gönderiyi okutun'),
      (ScanContext.lookup, 'Gönderi barkodu okutun'),
      (ScanContext.lookup, 'Gönderi barkodu okutun'),
      (ScanContext.lookup, 'Gönderi barkodu okutun'),
    ];
    final unread = (s.branch.inbox ?? const []).where((i) => !i.read).length;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    void openScan() => showSubeScanSheet(
      context,
      scanContext: scans[index].$1,
      hint: scans[index].$2,
    );
    return Scaffold(
      body: _ShellGlow(
        child: SafeArea(
          bottom: false,
          child: NavShrinkOnScroll(
            compact: _navCompact,
            onCompact: (v) => setState(() => _navCompact = v),
            child: DgTabStack(index: index, children: pages),
          ),
        ),
      ),
      // Büyük yazı ayarında yüzen düğme içeriği kapatır; alt çubuğun üstüne
      // tam genişlikte düğme olarak iner.
      // Gönderi seçiliyken "Kuryeye zimmetle" düğmesi öne geçer; iki düğme
      // üst üste binmesin diye okutma düğmesi gizlenir.
      floatingActionButton:
          largeText ||
              index == SubeNav.profile ||
              (index == SubeNav.shipments && s.branch.picked.isNotEmpty)
          ? null
          : FloatingActionButton.extended(
              onPressed: openScan,
              icon: DgIcon(
                LucideIcons.scanLine,
                color: Dg.onAction,
                weight: 600,
              ),
              label: Text(l.scanAction),
            ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (largeText && index != SubeNav.profile)
            Padding(
              padding: const EdgeInsets.all(12),
              child: DgButton(
                label: l.scanAction,
                icon: LucideIcons.qrCode,
                onPressed: openScan,
              ),
            ),
          DgPillNav(
            index: index,
            compact: _navCompact,
            badges: [0, 0, 0, 0, unread],
            onChanged: (i) {
              setState(() => _navCompact = false);
              nav.go(i);
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

/// Koyu temada üstte hafif marka ışığı (giriş ekranındaki dekorun devamı).
/// Durağan bir gradyan; boyama maliyeti yok denecek kadar az.
class _ShellGlow extends StatelessWidget {
  const _ShellGlow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!Dg.dark) return child;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.2, -1.15),
          radius: 1.1,
          colors: [Color(0x2A2B4BFF), Color(0x00020823)],
        ),
      ),
      child: child,
    );
  }
}
