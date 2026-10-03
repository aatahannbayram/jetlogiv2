import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n.dart';
import '../session.dart';
import '../widgets.dart';

class SubeEodScreen extends ConsumerWidget {
  const SubeEodScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final o = ref.watch(sessionProvider).agencyOverview;
    return Scaffold(
      appBar: AppBar(title: Text(l.branchEodTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            children: [
              StatTile(label: l.kpiToday, value: '${o?.currentShipments ?? 42}'),
              const SizedBox(width: 12),
              StatTile(label: l.kpiAssigned, value: '28'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              StatTile(label: l.kpiCompleted, value: '19'),
              const SizedBox(width: 12),
              StatTile(label: l.kpiOpen, value: '7'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              StatTile(label: l.kpiWaiting, value: '6'),
              const SizedBox(width: 12),
              StatTile(label: l.kpiReturnPend, value: '3'),
            ],
          ),
        ],
      ),
    );
  }
}
