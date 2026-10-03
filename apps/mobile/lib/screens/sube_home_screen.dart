import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/jetdiji_branch_models.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'sube_count_screen.dart';
import 'sube_couriers_screen.dart';
import 'sube_dispatch_screen.dart';
import 'sube_eod_screen.dart';
import 'sube_shipments_screen.dart';
import 'sube_stock_screen.dart';

class SubeHomeScreen extends ConsumerStatefulWidget {
  const SubeHomeScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<SubeHomeScreen> createState() => _SubeHomeScreenState();
}

class _SubeHomeScreenState extends ConsumerState<SubeHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(sessionProvider).loadBranchHome());
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final k = s.branchDashboard?.kpis ?? const JetDijiBranchKpis();
    final tiles = <(String, String, Widget?)>[
      ('Bugün', '${k.todayToDeliver}', const SubeShipmentsScreen()),
      ('Teslim', '${k.deliveredToday}', null),
      ('İade', '${k.returnToCenter}', const SubeEodScreen()),
      ('SLA', '${k.urgent}', const SubeShipmentsScreen(initialChip: 'sla')),
      ('Aktif kurye', '${k.activeCouriers}', const SubeCouriersScreen()),
      (
        'Bekleyen',
        '${k.pending}',
        const SubeShipmentsScreen(initialChip: 'waiting'),
      ),
      ('Atanan', '${k.assigned}', const SubeShipmentsScreen()),
      (
        'Sahada',
        '${k.inDistribution}',
        const SubeShipmentsScreen(initialChip: 'out'),
      ),
      ('Atanmamış', '${k.unassigned}', const SubeShipmentsScreen()),
      ('Stok', JetDijiBranchKpis.stockLabel, const SubeStockScreen()),
      ('Teslim edilemedi', '—', null),
      ('İptal', '${k.cancelledToday}', null),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(s.branchDashboard?.branchName ?? s.branchUser?.agencyName ?? 'Şube'),
        automaticallyImplyLeading: widget.embedded,
        actions: [
          if (!widget.embedded)
            TextButton(
              onPressed: () => ref.read(sessionProvider).logout(),
              child: const Text('Çıkış'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (s.branchLoading) const LinearProgressIndicator(),
          if (s.branchError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(s.branchError!, style: TextStyle(color: Dg.hi)),
            ),
          if (s.branchUser != null)
            Text(
              s.branchCanOperate ? 'Yazma açık' : 'Salt okunur',
              style: TextStyle(color: Dg.ink2),
            ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.7,
            children: [
              for (final tile in tiles)
                _Tile(
                  label: tile.$1,
                  value: tile.$2,
                  onTap: tile.$3 == null
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => tile.$3!),
                        ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _link(context, 'Gönderiler', const SubeShipmentsScreen()),
              _link(context, 'Kuryeler', const SubeCouriersScreen()),
              _link(context, 'Sayım', const SubeCountScreen()),
              _link(context, 'Merkeze sevk', const SubeDispatchScreen()),
              _link(context, 'Gün sonu', const SubeEodScreen()),
              _link(context, 'Stok', const SubeStockScreen()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _link(BuildContext context, String label, Widget page) {
    return ActionChip(
      label: Text(label),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => page),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DgCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Dg.ink2, fontSize: 13)),
          const Spacer(),
          Text(value, style: Dg.stat(size: 26)),
        ],
      ),
    );
  }
}
