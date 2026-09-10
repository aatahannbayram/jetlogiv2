import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../session.dart';
import '../widgets.dart';

class EodScreen extends ConsumerWidget {
  const EodScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);
    final pending = s.outbox.events.where((e) => e.pending).length;
    return Scaffold(
      appBar: AppBar(title: Text(l.eodTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            children: [
              StatTile(label: l.eodOpen, value: '${s.openCount}'),
              const SizedBox(width: 12),
              StatTile(label: l.eodReturn, value: '${s.returnCount}'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              StatTile(label: l.eodSync, value: '$pending'),
            ],
          ),
          const SizedBox(height: 24),
          DgButton(
            label: l.eodClose,
            icon: LucideIcons.moon,
            onPressed: s.shiftOpen
                ? () async {
                    final ok = await confirmEndShift(context);
                    if (ok && context.mounted) {
                      s.setShiftOpen(false);
                      Navigator.of(context).pop();
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
