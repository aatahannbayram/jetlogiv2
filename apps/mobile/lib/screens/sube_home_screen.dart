import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../coach.dart';
import '../l10n.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'sube_dispatch_screen.dart';
import 'sube_eod_screen.dart';

class SubeHomeScreen extends ConsumerWidget {
  const SubeHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);
    final user = s.agencyUser;
    final overview = s.agencyOverview;
    final k = s.branchKpis;
    String n(List<String> keys, String fallback) {
      for (final key in keys) {
        final value = k[key];
        if (value != null) return '$value';
      }
      return fallback;
    }
    final today = overview?.currentShipments ?? 42;
    final couriers = overview?.courierLinks ?? 12;

    final kpis = <(String, String)>[
      (l.kpiToday, n(const ['today', 'awaitingDelivery'], '$today')),
      (l.kpiAssigned, n(const ['assigned', 'outForDelivery'], '28')),
      (l.kpiWaiting, n(const ['waiting', 'pendingCustody', 'pendingItems'], '6')),
      (l.kpiInField, n(const ['inField', 'outForDelivery'], '14')),
      (l.kpiCompleted, n(const ['completed', 'deliveredToday'], '19')),
      (l.kpiDelivered, n(const ['delivered', 'deliveredToday'], '16')),
      (l.kpiUndelivered, n(const ['undelivered', 'failedToday'], '3')),
      (l.kpiOpen, n(const ['open', 'toReturnToBranch'], '7')),
      (l.kpiReturnPend, n(const ['returnPending', 'returnRequired'], '3')),
      (l.kpiSlaRisk, n(const ['slaRisk', 'overdue'], '2')),
      (l.kpiActiveCouriers, n(const ['activeCouriers'], '$couriers')),
      (l.kpiBranchStock, n(const ['branchStock', 'stock'], '1.250')),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(user?.agency.name ?? l.subeHome),
        actions: [
          IconButton(
            tooltip: l.subeLogout,
            icon: DgIcon(LucideIcons.logOut),
            onPressed: () => s.logoutAgency(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (!s.tipsSeen)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CoachBanner(
                title: l.subeOnboard1Title,
                body: l.tipHomeBody,
                onDismiss: s.markTipsSeen,
              ),
            ),
          if (user != null)
            Text(user.fullName, style: Dg.ui(size: 16, weight: FontWeight.w600)),
          const SizedBox(height: 16),
          for (var i = 0; i < kpis.length; i += 2) ...[
            Row(
              children: [
                StatTile(label: kpis[i].$1, value: kpis[i].$2),
                const SizedBox(width: 12),
                if (i + 1 < kpis.length)
                  StatTile(label: kpis[i + 1].$1, value: kpis[i + 1].$2),
              ],
            ),
            const SizedBox(height: 12),
          ],
          DgCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SubeDispatchScreen()),
            ),
            child: Row(
              children: [
                DgIconChip(icon: LucideIcons.truck, accent: true, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l.subeDispatchTitle,
                    style: Dg.ui(size: 15, weight: FontWeight.w600),
                  ),
                ),
                DgIcon(LucideIcons.chevronRight, size: 18, color: Dg.ink3),
              ],
            ),
          ),
          const SizedBox(height: 10),
          DgCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SubeEodScreen()),
            ),
            child: Row(
              children: [
                DgIconChip(icon: LucideIcons.sunset, accent: true, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l.branchEodTitle,
                    style: Dg.ui(size: 15, weight: FontWeight.w600),
                  ),
                ),
                DgIcon(LucideIcons.chevronRight, size: 18, color: Dg.ink3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
