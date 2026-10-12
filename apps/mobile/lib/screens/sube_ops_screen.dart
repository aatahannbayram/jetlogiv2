import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'sube_count_screen.dart';
import 'sube_dispatch_screen.dart';
import 'sube_eod_screen.dart';
import 'sube_manage_screens.dart';
import 'sube_inbox_screen.dart';
import 'sube_shifts_screen.dart';
import 'sube_sms_screen.dart';
import 'sube_labels_screen.dart';
import 'sube_performance_screen.dart';
import 'sube_widgets.dart';

/// İşlemler: sayım, merkeze sevk, etiket, performans, gün sonu ve çıkış.
class SubeOpsScreen extends ConsumerWidget {
  const SubeOpsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);
    void open(Widget page) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => page));
    return Scaffold(
      appBar: AppBar(title: Text(l.subeOpsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
        children: [
          SubeStatusBanner(branch: s.branch),
          _OpTile(
            icon: LucideIcons.clipboardList,
            label: l.subeCountTitle,
            onTap: () => open(const SubeCountScreen()),
          ),
          _OpTile(
            icon: LucideIcons.truck,
            label: l.subeDispatchTitle,
            onTap: () => open(const SubeDispatchScreen()),
          ),
          _OpTile(
            icon: LucideIcons.tag,
            label: l.subeLabelsTitle,
            onTap: () => open(const SubeLabelsScreen()),
          ),
          _OpTile(
            icon: LucideIcons.chartColumn,
            label: l.subePerformanceTitle,
            onTap: () => open(const SubePerformanceScreen()),
          ),
          _OpTile(
            icon: LucideIcons.bell,
            label: l.subeInboxTitle,
            onTap: () => open(const SubeInboxScreen()),
          ),
          _OpTile(
            icon: LucideIcons.calendarClock,
            label: l.subeShiftsTitle,
            onTap: () => open(const SubeShiftsScreen()),
          ),
          _OpTile(
            icon: LucideIcons.messageSquare,
            label: l.subeSmsTitle,
            onTap: () => open(const SubeSmsScreen()),
          ),
          _OpTile(
            icon: LucideIcons.graduationCap,
            label: l.subeTrainingTitle,
            onTap: () => open(const SubeTrainingScreen()),
          ),
          _OpTile(
            icon: LucideIcons.fileCheck,
            label: l.subeComplianceTitle,
            onTap: () => open(const SubeComplianceScreen()),
          ),
          _OpTile(
            icon: LucideIcons.sunset,
            label: l.branchEodTitle,
            onTap: () => open(const SubeEodScreen()),
          ),
          const SizedBox(height: 16),
          DgButton(
            label: l.subeLogout,
            icon: LucideIcons.logOut,
            tone: DgButtonTone.secondary,
            onPressed: s.logoutAgency,
          ),
        ],
      ),
    );
  }
}

class _OpTile extends StatelessWidget {
  const _OpTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DgCard(
        onTap: onTap,
        child: Row(
          children: [
            DgIconChip(icon: icon, accent: true, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Dg.ui(size: 15, weight: FontWeight.w600),
              ),
            ),
            DgIcon(LucideIcons.chevronRight, size: 18, color: Dg.ink3),
          ],
        ),
      ),
    );
  }
}
