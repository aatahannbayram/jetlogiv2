import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../theme.dart';
import '../widgets.dart';
import 'sube_demo.dart';

class SubeShipmentsScreen extends StatefulWidget {
  const SubeShipmentsScreen({super.key});

  @override
  State<SubeShipmentsScreen> createState() => _SubeShipmentsScreenState();
}

class _SubeShipmentsScreenState extends State<SubeShipmentsScreen> {
  String _filter = 'all';
  final _picked = <String>{};

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final chips = <(String, String)>[
      ('all', l.all),
      ('waiting', l.filterWaiting),
      ('out', l.filterOut),
      ('done', l.kpiCompleted),
      ('failed', l.filterFailed),
      ('booked', l.filterBooked),
      ('return', l.filterReturn),
      ('sla', l.filterSla),
    ];
    final rows = [
      for (final s in kSubeDemoShipments)
        if (_filter == 'all' || s.filter == _filter) s,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.subeShipmentsTitle)),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final c in chips)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(c.$2),
                      selected: _filter == c.$1,
                      onSelected: (_) => setState(() => _filter = c.$1),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                for (final shipment in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DgCard(
                      onTap: () => setState(() {
                        if (_picked.contains(shipment.ref)) {
                          _picked.remove(shipment.ref);
                        } else {
                          _picked.add(shipment.ref);
                        }
                      }),
                      child: Row(
                        children: [
                          Icon(
                            _picked.contains(shipment.ref)
                                ? LucideIcons.squareCheck
                                : LucideIcons.square,
                            size: 20,
                            color: Dg.ink2,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Mono(shipment.ref, size: 13, weight: FontWeight.w700),
                                Text(shipment.recipient, style: Dg.ui(size: 14, color: Dg.ink2)),
                              ],
                            ),
                          ),
                          StatusChip(label: shipment.filter, tone: shipment.tone),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_picked.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: DgButton(
                label: l.assignToCourier,
                icon: LucideIcons.userPlus,
                onPressed: () => _assign(context, l),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _assign(BuildContext context, L10n l) async {
    final courier = await showModalBottomSheet<SubeDemoCourier>(
      context: context,
      backgroundColor: Dg.surface,
      builder: (ctx) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(l.pickCourier, style: Dg.ui(size: 17, weight: FontWeight.w700)),
          const SizedBox(height: 12),
          for (final c in kSubeDemoCouriers)
            ListTile(
              title: Text(c.name),
              subtitle: Text(l.availableStatus),
              onTap: () => Navigator.pop(ctx, c),
            ),
        ],
      ),
    );
    if (courier == null || !context.mounted) return;
    setState(() => _picked.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${l.confirmAssign}: ${courier.name}')),
    );
  }
}
