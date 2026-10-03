import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session.dart';
import '../theme.dart';

class SubeDispatchScreen extends ConsumerStatefulWidget {
  const SubeDispatchScreen({super.key});

  @override
  ConsumerState<SubeDispatchScreen> createState() => _SubeDispatchScreenState();
}

class _SubeDispatchScreenState extends ConsumerState<SubeDispatchScreen> {
  final scan = TextEditingController();
  final warehouse = TextEditingController();
  String transferType = 'TO_CENTER';
  String? shipmentId;
  String? resolvedLabel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(sessionProvider).loadBranchOutgoing());
    });
  }

  @override
  void dispose() {
    scan.dispose();
    warehouse.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    final data = await ref
        .read(sessionProvider)
        .resolveOutgoingScan(scan.text.trim());
    if (!mounted || data == null) return;
    final id = data['shipmentId'] ?? data['id'];
    setState(() {
      shipmentId = id?.toString();
      resolvedLabel = '${data['shipmentNumber'] ?? shipmentId ?? 'Bulunamadı'}';
    });
  }

  Future<void> _send() async {
    final id = shipmentId;
    if (id == null || id.isEmpty) return;
    final ok = await ref.read(sessionProvider).sendOutgoingShipment(
      shipmentId: id,
      destinationWarehouseId: warehouse.text.trim(),
      transferType: transferType,
      barcodes: [scan.text.trim()],
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Sevk kaydı açıldı.' : 'Sevk olmadı.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Merkeze sevk')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Barkodsuz ekipman satırı bu turda yok. Önce gönderi okutun.',
            style: TextStyle(color: Dg.ink2, height: 1.4),
          ),
          if (s.branchError != null) ...[
            const SizedBox(height: 8),
            Text(s.branchError!, style: TextStyle(color: Dg.hi)),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: scan,
            decoration: const InputDecoration(labelText: 'Barkod'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _resolve, child: const Text('Gönderiyi çöz')),
          if (resolvedLabel != null) ...[
            const SizedBox(height: 8),
            Text(resolvedLabel!, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: warehouse,
            decoration: const InputDecoration(labelText: 'Hedef depo'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: s.branchCanOperate && shipmentId != null ? _send : null,
            child: const Text('Sevk et'),
          ),
        ],
      ),
    );
  }
}
