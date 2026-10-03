import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

class SubeCouriersScreen extends ConsumerStatefulWidget {
  const SubeCouriersScreen({super.key});

  @override
  ConsumerState<SubeCouriersScreen> createState() => _SubeCouriersScreenState();
}

class _SubeCouriersScreenState extends ConsumerState<SubeCouriersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(sessionProvider).loadBranchCouriers());
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final map = s.branchMap;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kuryeler'),
        actions: [
          IconButton(
            onPressed: () => ref.read(sessionProvider).loadBranchCouriers(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (s.branchError != null)
            Text(s.branchError!, style: TextStyle(color: Dg.hi)),
          if (map != null)
            Text(
              '${map.total} kurye · ${map.withLocation} konum · ${map.shipmentsInHand} elde',
              style: TextStyle(color: Dg.ink2),
            ),
          const SizedBox(height: 12),
          const Display('Canlı', size: 22),
          const SizedBox(height: 8),
          if (map == null || map.couriers.isEmpty)
            Text('Canlı konum yok.', style: TextStyle(color: Dg.ink2))
          else
            for (final courier in map.couriers)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DgCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        courier.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${courier.liveStatus ?? '—'} · elde ${courier.holdingCount} · geciken ${courier.overdueCount}',
                        style: TextStyle(color: Dg.ink2),
                      ),
                      if (courier.latitude != null && courier.longitude != null)
                        Text(
                          '${courier.latitude}, ${courier.longitude}',
                          style: TextStyle(color: Dg.ink3, fontSize: 12),
                        ),
                      for (final shipment in courier.shipments)
                        Text(
                          '${shipment.shipmentNumber} · ${shipment.recipientName ?? ''}',
                          style: const TextStyle(fontSize: 13),
                        ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 16),
          const Display('Atamalar', size: 22),
          const SizedBox(height: 8),
          for (final courier in s.branchCouriers)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(courier.fullName),
              subtitle: Text(
                [
                  courier.courierCode,
                  courier.status,
                  '${courier.shipmentCount} gönderi',
                  if (courier.isPrimary) 'birincil',
                ].whereType<String>().join(' · '),
              ),
            ),
        ],
      ),
    );
  }
}
