import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/jetdiji_branch_models.dart';
import '../session.dart';
import '../theme.dart';

class SubeShipmentsScreen extends ConsumerStatefulWidget {
  const SubeShipmentsScreen({super.key, this.initialChip = 'waiting'});

  final String initialChip;

  @override
  ConsumerState<SubeShipmentsScreen> createState() =>
      _SubeShipmentsScreenState();
}

class _SubeShipmentsScreenState extends ConsumerState<SubeShipmentsScreen> {
  late String chip = widget.initialChip;
  final selected = <String>{};
  String? courierId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final s = ref.read(sessionProvider);
      await s.loadBranchShipments();
      await s.loadBranchCouriers();
    });
  }

  List<JetDijiShipmentRow> _filter(List<JetDijiShipmentRow> rows) {
    return switch (chip) {
      'waiting' =>
        rows.where((r) => r.stage == 'AWAITING_COURIER').toList(),
      'out' => rows.where((r) => r.stage == 'IN_DISTRIBUTION').toList(),
      'booked' => rows.where((r) => r.hasWindow).toList(),
      'sla' => rows.where((r) => r.late).toList(),
      'done' || 'failed' => const [],
      _ => rows,
    };
  }

  Future<void> _handover() async {
    final id = courierId;
    if (id == null || selected.isEmpty) return;
    final ok = await ref.read(sessionProvider).handoverShipments(
      courierId: id,
      shipmentIds: selected.toList(),
    );
    if (!mounted) return;
    if (ok) {
      setState(selected.clear);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zimmet kurye okutmasını bekliyor.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final rows = _filter(s.branchShipments);
    final emptyNote = chip == 'done' || chip == 'failed'
        ? 'Bu listelerde tamamlanan veya teslim edilemeyen gönderi yok.'
        : 'Kayıt yok.';
    return Scaffold(
      appBar: AppBar(title: const Text('Gönderiler')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                for (final item in const [
                  ('waiting', 'Bekleyen'),
                  ('out', 'Dağıtımda'),
                  ('booked', 'Randevulu'),
                  ('sla', 'SLA'),
                  ('done', 'Tamamlanan'),
                  ('failed', 'Teslim edilemedi'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(item.$2),
                      selected: chip == item.$1,
                      onSelected: (_) => setState(() => chip = item.$1),
                    ),
                  ),
              ],
            ),
          ),
          if (s.branchError != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(s.branchError!, style: TextStyle(color: Dg.hi)),
            ),
          Expanded(
            child: rows.isEmpty
                ? Center(child: Text(emptyNote, style: TextStyle(color: Dg.ink2)))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final row in rows)
                        CheckboxListTile(
                          value: selected.contains(row.shipmentId),
                          onChanged: s.branchCanOperate
                              ? (v) => setState(() {
                                  if (v == true) {
                                    selected.add(row.shipmentId);
                                  } else {
                                    selected.remove(row.shipmentId);
                                  }
                                })
                              : null,
                          title: Text(row.shipmentNumber),
                          subtitle: Text(
                            [
                              row.recipientName,
                              row.stage,
                              if (row.late) 'gecikmiş',
                            ].whereType<String>().join(' · '),
                          ),
                        ),
                    ],
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: courierId,
                    decoration: const InputDecoration(labelText: 'Kurye'),
                    items: [
                      for (final courier in s.branchCouriers)
                        DropdownMenuItem(
                          value: courier.courierId,
                          child: Text(courier.fullName),
                        ),
                    ],
                    onChanged: s.branchCanOperate
                        ? (id) => setState(() => courierId = id)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: s.branchCanOperate && selected.isNotEmpty
                        ? () => unawaited(_handover())
                        : null,
                    child: const Text('Kuryeye zimmetle'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
