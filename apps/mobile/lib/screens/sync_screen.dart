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
    final linked = s.online && s.workerEnabled;

    return Scaffold(
      appBar: AppBar(title: Text(l.syncTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Appear(
            child: _HubLinkCard(
              linked: linked,
              flushing: s.pushingSync,
              workerOn: s.workerEnabled,
              pending: pending.length,
              onToggle: s.toggleWorker,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              StatTile(
                label: l.pendingCaps,
                value: '${pending.length}',
              ),
              const SizedBox(width: 12),
              StatTile(
                label: l.failedCaps,
                value: '${failed.length}',
                subColor: Dg.hi,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            l.queue,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          const SizedBox(height: 10),
          if (queue.isEmpty)
            Appear(
              child: DgCard(
                child: Row(
                  children: [
                    Icon(LucideIcons.circleCheck, color: Dg.sage, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l.queueEmptyAllSent,
                        style: Dg.ui(size: 15, color: Dg.ink2),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
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
          const SizedBox(height: 16),
          DgButton(
            label: s.pushingSync
                ? l.sending
                : (queue.isEmpty ? l.queueEmpty : l.pushData),
            icon: LucideIcons.upload,
            busy: s.pushingSync,
            onPressed: queue.isEmpty
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    s.pushSyncQueue();
                  },
          ),
        ],
      ),
    );
  }
}

class _HubLinkCard extends StatelessWidget {
  const _HubLinkCard({
    required this.linked,
    required this.flushing,
    required this.workerOn,
    required this.pending,
    required this.onToggle,
  });

  final bool linked;
  final bool flushing;
  final bool workerOn;
  final int pending;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final ink = flushing
        ? Dg.purpleActive
        : linked
        ? Dg.sage
        : Dg.sand;
    final title = flushing
        ? l.hubFlushing
        : linked
        ? l.hubLinked
        : l.hubOffline;
    final body = flushing
        ? l.hubQueuedCount(pending)
        : linked
        ? (pending == 0 ? l.syncCleanBody : l.hubQueuedCount(pending))
        : l.hubQueuedOnPhone;

    return DgCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l.hubLine,
                style: Dg.ui(size: 16, weight: FontWeight.w600),
              ),
              const Spacer(),
              DgSwitch(value: workerOn, onChanged: (_) => onToggle()),
            ],
          ),
          const SizedBox(height: 14),
          _SocketRail(linked: linked, flushing: flushing, color: ink),
          const SizedBox(height: 14),
          Row(
            children: [
              _LiveDot(color: ink, live: linked || flushing),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Dg.ui(size: 15, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(body, style: Dg.ui(size: 13, color: Dg.ink2)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            workerOn ? l.workerOn : l.workerOff,
            style: Dg.ui(size: 12, color: Dg.ink3),
          ),
        ],
      ),
    );
  }
}

class _SocketRail extends StatelessWidget {
  const _SocketRail({
    required this.linked,
    required this.flushing,
    required this.color,
  });

  final bool linked;
  final bool flushing;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Row(
      children: [
        _RailEnd(icon: LucideIcons.smartphone, label: l.phoneEnd, color: color),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _PacketTrack(
              linked: linked,
              flushing: flushing,
              color: color,
            ),
          ),
        ),
        _RailEnd(
          icon: linked || flushing ? LucideIcons.radio : LucideIcons.cloudOff,
          label: l.hubEnd,
          color: color,
        ),
      ],
    );
  }
}

class _RailEnd extends StatelessWidget {
  const _RailEnd({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(height: 4),
        Text(label, style: Dg.ui(size: 11, color: Dg.ink3)),
      ],
    );
  }
}

class _PacketTrack extends StatefulWidget {
  const _PacketTrack({
    required this.linked,
    required this.flushing,
    required this.color,
  });

  final bool linked;
  final bool flushing;
  final Color color;

  @override
  State<_PacketTrack> createState() => _PacketTrackState();
}

class _PacketTrackState extends State<_PacketTrack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tick;

  @override
  void initState() {
    super.initState();
    _tick = AnimationController(vsync: this, duration: const Duration(seconds: 2));
  }

  @override
  void didUpdateWidget(covariant _PacketTrack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  void _syncTicker() {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final live = (widget.linked || widget.flushing) && !reduce;
    _tick.duration = Duration(milliseconds: widget.flushing ? 700 : 1800);
    if (live) {
      if (!_tick.isAnimating) _tick.repeat();
    } else {
      _tick.stop();
      _tick.value = 0;
    }
  }

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: AnimatedBuilder(
        animation: _tick,
        builder: (context, _) {
          return CustomPaint(
            painter: _PacketPainter(
              t: _tick.value,
              color: widget.color,
              dashed: !widget.linked && !widget.flushing,
              live: widget.linked || widget.flushing,
            ),
          );
        },
      ),
    );
  }
}

class _PacketPainter extends CustomPainter {
  _PacketPainter({
    required this.t,
    required this.color,
    required this.dashed,
    required this.live,
  });

  final double t;
  final Color color;
  final bool dashed;
  final bool live;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final line = Paint()
      ..color = color.withValues(alpha: dashed ? 0.35 : 0.45)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (dashed) {
      const dash = 5.0;
      const gap = 5.0;
      var x = 0.0;
      while (x < size.width) {
        canvas.drawLine(
          Offset(x, y),
          Offset((x + dash).clamp(0, size.width), y),
          line,
        );
        x += dash + gap;
      }
      return;
    }

    canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    if (!live) return;

    final packet = Paint()..color = color;
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1.0;
      final x = p * size.width;
      final glow = 1.0 - ((p - 0.5).abs() * 1.2).clamp(0.0, 0.55);
      canvas.drawCircle(
        Offset(x, y),
        3.4,
        Paint()..color = color.withValues(alpha: 0.18 + glow * 0.35),
      );
      canvas.drawCircle(Offset(x, y), 2.2, packet);
    }
  }

  @override
  bool shouldRepaint(covariant _PacketPainter old) =>
      old.t != t || old.color != color || old.dashed != dashed || old.live != live;
}

class _LiveDot extends StatefulWidget {
  const _LiveDot({required this.color, required this.live});

  final Color color;
  final bool live;

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void didUpdateWidget(covariant _LiveDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  void _sync() {
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (widget.live && !reduce) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final scale = 0.85 + (_pulse.value * 0.2);
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: widget.live
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.45 * _pulse.value),
                      blurRadius: 8 * scale,
                    ),
                  ]
                : null,
          ),
        );
      },
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
          SizedBox(
            width: 28,
            child: Text(
              index.toString().padLeft(2, '0'),
              style: Dg.stat(size: 14, color: Dg.ink3),
            ),
          ),
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
  SyncEventKind.enRoute || SyncEventKind.arrived || SyncEventKind.start =>
    Dg.purpleActive,
  SyncEventKind.shiftOn || SyncEventKind.shiftOff => Dg.sand,
  _ => Dg.blue,
};
