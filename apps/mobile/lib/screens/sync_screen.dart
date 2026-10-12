import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../models.dart';
import '../motion.dart';
import '../session.dart';
import '../sync_label.dart';
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

    final offline = !s.online;
    final (
      IconData icon,
      Color tone,
      String title,
      String body,
    ) = failed.isNotEmpty
        ? (
            LucideIcons.circleAlert,
            Dg.hi,
            l.notSentTitle(failed.length),
            l.notSentBody,
          )
        : pending.isNotEmpty
        ? (
            offline ? LucideIcons.wifiOff : LucideIcons.clock,
            Dg.mid,
            l.waitingToSend(pending.length),
            offline ? l.waitingOfflineBody : l.waitingOnlineBody,
          )
        : (LucideIcons.circleCheck, Dg.ok, l.allSentTitle, l.allSentBody);

    return Scaffold(
      appBar: AppBar(title: Text(l.syncTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          // Tek soru: "Bir şey yapmam gerekiyor mu?"
          Appear(
            child: DgCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  DgIcon(icon, color: tone, size: 32, weight: 600),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Dg.ui(size: 18, weight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(body, style: Dg.ui(size: 14, color: Dg.ink2)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (pending.isNotEmpty) ...[
            const SizedBox(height: 12),
            DgButton(
              label: s.pushingSync ? l.sending : l.pushData,
              icon: LucideIcons.upload,
              busy: s.pushingSync,
              onPressed: () {
                HapticFeedback.mediumImpact();
                s.pushSyncQueue();
              },
            ),
          ],
          if (queue.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              l.waitingList,
              style: Dg.ui(size: 15, weight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < queue.length; i++)
              StaggerIn(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _QueueRow(
                    index: i + 1,
                    event: queue[i],
                    view: describeOutboxEvent(queue[i], s.tasks, l),
                    flushing: s.pushingSync && queue[i].pending,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Text(l.autoSend, style: Dg.ui(size: 15))),
              DgSwitch(
                value: s.workerEnabled,
                onChanged: (_) => s.toggleWorker(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.index,
    required this.event,
    required this.view,
    required this.flushing,
  });

  final int index;
  final OutboxEvent event;
  final SyncQueueView view;
  final bool flushing;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final failed = event.status == 'rejected';
    final tone = failed
        ? Dg.clay
        : flushing
        ? Dg.purpleActive
        : _tone(view.kind);
    final status = failed
        ? l.failed
        : flushing
        ? l.sending
        : l.inLine;

    return DgCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(_icon(view.kind), size: 16, color: tone),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  view.person,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Dg.ui(size: 15, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  view.action,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Dg.ui(size: 13, color: Dg.ink2),
                ),
                const SizedBox(height: 2),
                Mono(view.meta, size: 11),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusChip(
            label: status,
            tone: failed
                ? 'hi'
                : flushing
                ? 'lime'
                : 'mid',
          ),
        ],
      ),
    );
  }
}

IconData _icon(SyncEventKind kind) => switch (kind) {
  SyncEventKind.accept => LucideIcons.circleCheck,
  SyncEventKind.enRoute => LucideIcons.navigation,
  SyncEventKind.arrived => LucideIcons.mapPin,
  SyncEventKind.start => LucideIcons.package,
  SyncEventKind.fail => LucideIcons.packageX,
  SyncEventKind.deliver => LucideIcons.circleCheck,
  SyncEventKind.step => LucideIcons.listChecks,
  SyncEventKind.shiftOn => LucideIcons.play,
  SyncEventKind.shiftOff => LucideIcons.pause,
  SyncEventKind.custody => LucideIcons.packageCheck,
  SyncEventKind.ticket => LucideIcons.lifeBuoy,
  SyncEventKind.other => LucideIcons.refreshCw,
};

Color _tone(SyncEventKind kind) => switch (kind) {
  SyncEventKind.fail => Dg.clay,
  SyncEventKind.deliver => Dg.sage,
  SyncEventKind.enRoute ||
  SyncEventKind.arrived ||
  SyncEventKind.start => Dg.purpleActive,
  SyncEventKind.shiftOn || SyncEventKind.shiftOff => Dg.sand,
  _ => Dg.blue,
};
