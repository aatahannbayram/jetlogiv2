import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session.dart';
import '../theme.dart';

class SubeCountScreen extends ConsumerStatefulWidget {
  const SubeCountScreen({super.key});

  @override
  ConsumerState<SubeCountScreen> createState() => _SubeCountScreenState();
}

class _SubeCountScreenState extends ConsumerState<SubeCountScreen> {
  final barcode = TextEditingController();
  String? countId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(sessionProvider).loadBranchCounts());
    });
  }

  @override
  void dispose() {
    barcode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sayım')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (s.branchError != null)
            Text(s.branchError!, style: TextStyle(color: Dg.hi)),
          FilledButton(
            onPressed: s.branchCanOperate
                ? () async {
                    final id = await ref.read(sessionProvider).startBranchCount();
                    if (id != null) setState(() => countId = id);
                  }
                : null,
            child: const Text('Sayım başlat'),
          ),
          const SizedBox(height: 12),
          for (final row in s.branchCounts)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${row['id'] ?? row['countId'] ?? 'Sayım'}'),
              subtitle: Text('${row['status'] ?? row['state'] ?? ''}'),
              onTap: () => setState(
                () => countId = '${row['id'] ?? row['countId'] ?? ''}',
              ),
            ),
          if (countId != null) ...[
            const SizedBox(height: 8),
            Text('Açık sayım $countId', style: TextStyle(color: Dg.ink2)),
            TextField(
              controller: barcode,
              decoration: const InputDecoration(labelText: 'Barkod'),
              onSubmitted: (value) async {
                final ok = await ref
                    .read(sessionProvider)
                    .scanBranchCount(countId!, value.trim());
                if (ok) barcode.clear();
              },
            ),
          ],
        ],
      ),
    );
  }
}
