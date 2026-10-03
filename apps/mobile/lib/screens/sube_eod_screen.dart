import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session.dart';
import '../theme.dart';

class SubeEodScreen extends ConsumerStatefulWidget {
  const SubeEodScreen({super.key});

  @override
  ConsumerState<SubeEodScreen> createState() => _SubeEodScreenState();
}

class _SubeEodScreenState extends ConsumerState<SubeEodScreen> {
  final scan = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(sessionProvider).loadBranchPending());
    });
  }

  @override
  void dispose() {
    scan.dispose();
    super.dispose();
  }

  int _len(String key) {
    final raw = ref.read(sessionProvider).branchPending[key];
    return raw is List ? raw.length : 0;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final queues = [
      ('Zimmet', _len('handovers')),
      ('İade', _len('returns')),
      ('Gün sonu', _len('endOfDay')),
      ('Geciken', _len('overdue')),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Gün sonu')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Ayrı özet ucu yok. Kuyruklar bekleyen işlerden okunur.',
            style: TextStyle(color: Dg.ink2, height: 1.4),
          ),
          if (s.branchError != null) ...[
            const SizedBox(height: 8),
            Text(s.branchError!, style: TextStyle(color: Dg.hi)),
          ],
          const SizedBox(height: 12),
          for (final queue in queues)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(queue.$1),
              trailing: Text('${queue.$2}', style: Dg.stat(size: 20)),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: scan,
            decoration: const InputDecoration(labelText: 'Kurye iade barkodu'),
            onSubmitted: (value) async {
              final ok = await ref
                  .read(sessionProvider)
                  .scanBranchReturn(value.trim());
              if (ok) scan.clear();
            },
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: s.branchCanOperate
                ? () async {
                    final ok = await ref
                        .read(sessionProvider)
                        .scanBranchReturn(scan.text.trim());
                    if (ok) scan.clear();
                  }
                : null,
            child: const Text('İade okut'),
          ),
        ],
      ),
    );
  }
}
