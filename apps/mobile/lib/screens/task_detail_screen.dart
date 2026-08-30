import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../launchers.dart';
import '../models.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'fail_screen.dart';
import 'wizard_screen.dart';

class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final t = session.taskById(taskId);
    final done = t.status == TaskStatus.delivered;

    void start() {
      ref.read(sessionProvider).startTask(t.id);
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => WizardScreen(taskId: t.id)),
      );
    }

    return Scaffold(
      backgroundColor: Dg.night,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MapStrip(
                  eta: t.etaMinutes,
                  height: double.infinity,
                  rounded: false,
                  points: [LatLng(t.lat, t.lng)],
                  onTap: () => openDirections(context, t),
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        _GlassPill(
                          onTap: () => Navigator.of(context).pop(),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Colors.white),
                        ),
                        const Spacer(),
                        _GlassPill(child: Mono('#${t.sequence}  ${t.ref}', color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                if (t.etaMinutes != null)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 66,
                    left: 16,
                    child: _StatPill(label: 'ETA', value: '${t.etaMinutes} dk'),
                  ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Dg.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(Dg.radiusHero)),
              boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 40, offset: Offset(0, -16))],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(color: Dg.rule, borderRadius: BorderRadius.circular(3)),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InitialsAvatar(name: t.recipient, size: 52),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Hero(tag: 'recipient-${t.id}', child: Material(color: Colors.transparent, child: Display(t.recipient, size: 22))),
                              const SizedBox(height: 4),
                              Text(t.address, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Dg.ink2, fontSize: 13, height: 1.3)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusChip(label: taskStatusLabel(t.status), tone: taskStatusTone(t.status)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const DgDivider(),
                    _kv('Saat', t.window),
                    _kv('İş', t.kindLabel),
                    if (t.cod != null && session.courier.canSeePricing) _kv('Kapıda', '${t.cod} ₺'),
                    if (t.otpRequired) _kv('Kod', 'Alıcıdan alınacak'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        SquareAction(
                          icon: Icons.phone_outlined,
                          label: 'Ara',
                          onTap: () => callRecipient(context),
                        ),
                        const SizedBox(width: 10),
                        SquareAction(
                          icon: Icons.navigation_outlined,
                          label: 'Yol',
                          onTap: () => openDirections(context, t),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (done)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(color: Dg.loBg, borderRadius: BorderRadius.circular(Dg.radiusPill)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 20, color: Dg.lo),
                            const SizedBox(width: 8),
                            Text('Teslim edildi', style: Dg.ui(size: 16, weight: FontWeight.w700, color: Dg.lo)),
                          ],
                        ),
                      ).animate().scale(begin: const Offset(0.96, 0.96), duration: 220.ms, curve: Curves.easeOutBack).fadeIn(duration: 180.ms)
                    else
                      SlideToAct(label: 'Teslim etmek için kaydır', onConfirm: start),
                    if (!done) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: () async {
                            final failed = await Navigator.of(context).push<bool>(
                              MaterialPageRoute<bool>(builder: (_) => FailScreen(taskId: t.id)),
                            );
                            if (failed == true && context.mounted) Navigator.of(context).pop();
                          },
                          child: const Text('Teslim edilemedi', style: TextStyle(color: Dg.hi, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 72, child: Text(k, style: const TextStyle(color: Dg.ink3, fontSize: 13))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, height: 1.3))),
        ],
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      height: 38,
      constraints: const BoxConstraints(minWidth: 38),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(borderRadius: BorderRadius.circular(19), onTap: onTap, child: content),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontFamily: Dg.mono, fontSize: 10, color: Color(0xFF9A9E90))),
          Text(value, style: Dg.stat(size: 16, color: Colors.white)),
        ],
      ),
    );
  }
}
