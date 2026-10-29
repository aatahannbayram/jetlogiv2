import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../session.dart';
import '../shell_nav.dart';
import '../theme.dart';
import '../ui/ui.dart';
import 'sube_count_reconcile_screen.dart';
import 'sube_count_screen.dart';
import 'sube_courier_map_screen.dart';
import 'sube_dispatch_screen.dart';
import 'sube_eod_screen.dart';
import 'sube_header.dart';
import 'sube_inbox_screen.dart';
import 'sube_labels_screen.dart';
import 'sube_manage_screens.dart';
import 'sube_more_screens.dart';
import 'sube_performance_screen.dart';
import 'sube_return_flow.dart';
import 'sube_shifts_screen.dart';
import 'sube_sms_screen.dart';
import 'sube_stock_screen.dart';
import 'sube_widgets.dart';

/// İşlemler merkezi: aynı işi yapan sayfalar tek girişte toplanır, gruplar
/// saha → stok/zimmet → iletişim → şube sırasında. Çıkış Profil'dedir.
class SubeOpsScreen extends ConsumerWidget {
  const SubeOpsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);
    void open(Widget page) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => page));
    final violet = Dg.violet;
    final ok = Dg.ok;
    final warn = Dg.warn;
    return Scaffold(
      appBar: const SubeHeaderBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          DgPageTitle(l.subeOpsTitle),
          SubeStatusBanner(branch: s.branch),
          SubeOverline(l.opsGroupField),
          SubeGroup(
            children: [
              SubeNavTile(
                icon: LucideIcons.userPlus,
                label: l.quickAssign,
                onTap: () => ref
                    .read(subeNavProvider)
                    .go(SubeNav.shipments, filter: 'waiting'),
              ),
              SubeNavTile(
                icon: LucideIcons.undo2,
                tint: warn,
                label: l.courierReturnTitle,
                onTap: () => open(const SubeReturnFlow()),
              ),
              SubeNavTile(
                icon: LucideIcons.map,
                label: l.courierMapTitle,
                onTap: () => open(const SubeCourierMapScreen()),
              ),
              SubeNavTile(
                icon: LucideIcons.chartColumn,
                tint: ok,
                label: l.subePerformanceTitle,
                onTap: () => open(const SubePerformanceScreen()),
              ),
              SubeNavTile(
                icon: LucideIcons.sunset,
                tint: violet,
                label: l.branchEodTitle,
                onTap: () => open(const SubeEodScreen()),
              ),
            ],
          ),
          SubeOverline(l.opsGroupStock),
          SubeGroup(
            children: [
              SubeNavTile(
                icon: LucideIcons.boxes,
                label: l.subeStockTitle,
                onTap: () => open(const SubeStockScreen()),
              ),
              SubeNavTile(
                icon: LucideIcons.clipboardList,
                tint: violet,
                label: l.subeCountTitle,
                onTap: () => open(const SubeCountScreen()),
              ),
              SubeNavTile(
                icon: LucideIcons.scale,
                tint: warn,
                label: l.reconcileTitle,
                onTap: () => open(const SubeCountReconcileScreen()),
              ),
              SubeNavTile(
                icon: LucideIcons.arrowUpFromLine,
                label: l.transferOutgoing,
                onTap: () => open(const SubeDispatchScreen()),
              ),
              if (!s.branch.demo)
                SubeNavTile(
                  icon: LucideIcons.listChecks,
                  tint: ok,
                  label: l.prepTitle,
                  onTap: () => open(const SubePrepScreen()),
                ),
              SubeNavTile(
                icon: LucideIcons.tag,
                tint: violet,
                label: l.subeLabelsTitle,
                onTap: () => open(const SubeLabelsScreen()),
              ),
            ],
          ),
          SubeOverline(l.opsGroupComms),
          SubeGroup(
            children: [
              SubeNavTile(
                icon: LucideIcons.bell,
                label: l.subeInboxTitle,
                onTap: () => open(const SubeInboxScreen()),
              ),
              SubeNavTile(
                icon: LucideIcons.messageSquare,
                tint: violet,
                label: l.subeSmsTitle,
                onTap: () => open(const SubeSmsScreen()),
              ),
              SubeNavTile(
                icon: LucideIcons.graduationCap,
                tint: ok,
                label: l.subeTrainingTitle,
                onTap: () => open(const SubeTrainingScreen()),
              ),
            ],
          ),
          SubeOverline(l.opsGroupBranch),
          SubeGroup(
            children: [
              if (!s.branch.demo)
                SubeNavTile(
                  icon: LucideIcons.receipt,
                  tint: ok,
                  label: l.invoicesTitle,
                  onTap: () => open(const SubeInvoicesScreen()),
                ),
              if (!s.branch.demo)
                SubeNavTile(
                  icon: LucideIcons.building2,
                  label: l.agencyInfoTitle,
                  onTap: () => open(const SubeAgencyInfoScreen()),
                ),
              SubeNavTile(
                icon: LucideIcons.calendarClock,
                label: l.subeShiftsTitle,
                onTap: () => open(const SubeShiftsScreen()),
              ),
              SubeNavTile(
                icon: LucideIcons.fileCheck,
                tint: violet,
                label: l.subeComplianceTitle,
                onTap: () => open(const SubeComplianceScreen()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
