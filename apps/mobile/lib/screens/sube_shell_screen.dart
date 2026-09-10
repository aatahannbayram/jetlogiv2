import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../session.dart';
import '../widgets.dart';
import 'onboard_screen.dart';
import 'sube_count_screen.dart';
import 'sube_couriers_screen.dart';
import 'sube_home_screen.dart';
import 'sube_scan_sheet.dart';
import 'sube_shipments_screen.dart';
import 'sube_stock_screen.dart';

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
      ref.read(sessionProvider).loadAgencyOverview();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    if (!s.subeOnboardSeen) {
      return const OnboardScreen(forBranch: true);
    }
    final pages = const [
      SubeHomeScreen(),
      SubeShipmentsScreen(),
      SubeCouriersScreen(),
      SubeStockScreen(),
      SubeCountScreen(),
    ];
    final hints = [
      'Gönderi veya koli barkodu',
      'Zimmete eklenecek gönderi',
      'Kurye / görev barkodu',
      'Stok girişi',
      'Sayım',
    ];
    return Scaffold(
      body: SafeArea(bottom: false, child: IndexedStack(index: _index, children: pages)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showSubeScanSheet(context, hint: hints[_index]),
        icon: DgIcon(LucideIcons.qrCode, color: Colors.white, weight: 600),
        label: Text(context.l10n.scanAction),
      ),
      bottomNavigationBar: DgPillNav(
        index: _index,
        onChanged: (i) => setState(() => _index = i),
        items: const [
          (LucideIcons.home, LucideIcons.home, 'Ana Sayfa'),
          (LucideIcons.package, LucideIcons.packageCheck, 'Gönderiler'),
          (LucideIcons.users, LucideIcons.users, 'Kuryeler'),
          (LucideIcons.archive, LucideIcons.archiveRestore, 'Stok'),
          (LucideIcons.clipboardList, LucideIcons.clipboardCheck, 'Sayım'),
        ],
      ),
    );
  }
}
