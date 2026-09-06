import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../models.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);
    final pending = s.outbox.events.where((e) => e.pending).toList();
    final failed = s.outbox.events
        .where((e) => e.status == 'rejected')
        .toList();
    final queue = [...pending, ...failed];

    return Scaffold(
      appBar: AppBar(title: Text(l.syncTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          DgCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.backgroundSend,
                        style: Dg.ui(size: 16, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        s.workerEnabled ? l.workerOn : l.workerOff,
                        style: Dg.ui(size: 13, color: Dg.ink2),
                      ),
                    ],
                  ),
                ),
                DgSwitch(
                  value: s.workerEnabled,
                  onChanged: (_) => s.toggleWorker(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatTile(label: l.pendingCaps, value: '${pending.length}'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  label: l.failedCaps,
                  value: '${failed.length}',
                  subColor: Dg.hi,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l.queue,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          const SizedBox(height: 10),
          if (queue.isEmpty)
            DgCard(
              child: Text(
                l.queueEmptyAllSent,
                style: Dg.ui(size: 15, color: Dg.ink2),
              ),
            )
          else
            for (final e in queue)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DgCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: e.status == 'rejected' ? Dg.red : Dg.amber,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.operation.wire,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            if (e.subjectId != null)
                              Mono(e.subjectId!, size: 12),
                          ],
                        ),
                      ),
                      StatusChip(
                        label: e.status == 'rejected'
                            ? l.failed
                            : l.waiting,
                        tone: e.status == 'rejected' ? 'hi' : 'mid',
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 16),
          DgButton(
            label: s.pushingSync
                ? l.sending
                : (queue.isEmpty ? l.queueEmpty : l.pushData),
            icon: LucideIcons.upload,
            busy: s.pushingSync,
            onPressed: queue.isEmpty ? null : () => s.pushSyncQueue(),
          ),
        ],
      ),
    );
  }
}
