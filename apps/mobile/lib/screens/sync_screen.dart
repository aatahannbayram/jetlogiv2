import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final pending = s.outbox.events.where((e) => e.pending).toList();
    final failed = s.outbox.events
        .where((e) => e.status == 'rejected')
        .toList();
    final queue = [...pending, ...failed];

    return Scaffold(
      appBar: AppBar(title: const Text('Senkronizasyon')),
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
                        'Arka plan gönderimi',
                        style: Dg.ui(size: 16, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        s.workerEnabled ? 'Worker açık' : 'Worker kapalı',
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
                child: StatTile(label: 'BEKLEYEN', value: '${pending.length}'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  label: 'BAŞARISIZ',
                  value: '${failed.length}',
                  subColor: Dg.hi,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Kuyruk',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          const SizedBox(height: 10),
          if (queue.isEmpty)
            DgCard(
              child: Text(
                'Kuyruk boş, tüm kayıtlar merkeze iletildi.',
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
                            ? 'Başarısız'
                            : 'Bekliyor',
                        tone: e.status == 'rejected' ? 'hi' : 'mid',
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 16),
          FilledButton(
            style: queue.isEmpty
                ? FilledButton.styleFrom(
                    backgroundColor: Dg.elev,
                    foregroundColor: Dg.ink3,
                  )
                : null,
            onPressed: queue.isEmpty ? null : () => s.pushSyncQueue(),
            child: Text(
              s.pushingSync
                  ? 'Gönderiliyor…'
                  : (queue.isEmpty ? 'Kuyruk boş' : 'Verileri gönder'),
            ),
          ),
        ],
      ),
    );
  }
}
