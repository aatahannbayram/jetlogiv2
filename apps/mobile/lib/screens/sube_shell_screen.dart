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
import 'sube_ops_screen.dart';
import 'sube_scan_sheet.dart';
import 'sube_shipments_screen.dart';
import 'sube_stock_screen.dart';

/// Şube/Acente kabuğu: Ana Sayfa • Gönderiler • Kuryeler • Stok & Zimmet •
/// İşlemler ve sabit "Barkod Okut". Okutma, açık sekmenin bağlamına gider.
class SubeShellScreen extends ConsumerStatefulWidget {
  const SubeShellScreen({super.key});

  @override
  ConsumerState<SubeShellScreen> createState() => _SubeShellScreenState();
}

class _SubeShellScreenState extends ConsumerState<SubeShellScreen> {
  int _index = 0;

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
    const pages = [
      SubeHomeScreen(),
      SubeShipmentsScreen(),
      SubeCouriersScreen(),
      SubeStockScreen(),
      SubeOpsScreen(),
    ];
    // İşlemler sekmesinde okutma, alt ekranların (sayım, sevk) kendi
    // düğmesinden yapılır; orada genel sorgu açılır.
    final scans = <(ScanContext, String)>[
      (ScanContext.lookup, 'Gönderi barkodu okutun'),
      (ScanContext.assign, 'Zimmete eklenecek gönderiyi okutun'),
      (ScanContext.lookup, 'Gönderi barkodu okutun'),
      (ScanContext.courierReturn, 'Kuryeden dönen gönderiyi okutun'),
      (ScanContext.lookup, 'Gönderi barkodu okutun'),
    ];
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    void openScan() => showSubeScanSheet(
      context,
      scanContext: scans[_index].$1,
      hint: scans[_index].$2,
    );
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: DgTabStack(index: _index, children: pages),
      ),
      // Büyük yazı ayarında yüzen düğme içeriği kapatır; alt çubuğun üstüne
      // tam genişlikte düğme olarak iner.
      floatingActionButton: largeText
          ? null
          : FloatingActionButton.extended(
              onPressed: openScan,
              icon: DgIcon(LucideIcons.qrCode, color: Dg.onAction, weight: 600),
              label: Text(l.scanAction),
            ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (largeText)
            Padding(
              padding: const EdgeInsets.all(12),
              child: DgButton(
                label: l.scanAction,
                icon: LucideIcons.qrCode,
                onPressed: openScan,
              ),
            ),
          DgPillNav(
            index: _index,
            onChanged: (i) => setState(() => _index = i),
            items: [
              (LucideIcons.home, LucideIcons.home, l.subeTabHome),
              (
                LucideIcons.package,
                LucideIcons.packageCheck,
                l.subeTabShipments,
              ),
              (LucideIcons.users, LucideIcons.users, l.subeTabCouriers),
              (LucideIcons.archive, LucideIcons.archiveRestore, l.subeTabStock),
              (LucideIcons.layoutGrid, LucideIcons.layoutGrid, l.subeTabOps),
            ],
          ),
        ],
      ),
    );
  }
}
