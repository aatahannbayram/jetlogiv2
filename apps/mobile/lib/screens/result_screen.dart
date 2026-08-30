import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

/// Shown after a delivery is closed, either successfully or as a return
/// ("İade"). Reused by [WizardScreen]'s success path and [FailScreen].
class DeliveryResultScreen extends StatelessWidget {
  const DeliveryResultScreen({
    super.key,
    required this.success,
    required this.task,
    this.who,
    required this.online,
    required this.next,
    required this.onClose,
    required this.onNext,
  });

  final bool success;
  final DeliveryTask task;
  final String? who;
  final bool online;
  final DeliveryTask? next;
  final VoidCallback onClose;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final clock = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return Scaffold(
      backgroundColor: success ? Dg.loBg : Dg.redBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Builder(
                builder: (context) {
                  Widget icon = Icon(
                    success ? Icons.check_circle_rounded : Icons.assignment_return_rounded,
                    size: 56,
                    color: success ? Dg.lo : Dg.red,
                  );
                  if (!MediaQuery.disableAnimationsOf(context)) {
                    icon = icon
                        .animate()
                        .scale(begin: const Offset(0.7, 0.7), duration: 280.ms, curve: Curves.easeOutBack)
                        .fadeIn(duration: 200.ms);
                  }
                  return icon;
                },
              ),
              const SizedBox(height: 16),
              Display(success ? 'Teslim edildi' : 'İade kaydedildi', size: 36),
              const SizedBox(height: 6),
              Mono(clock, size: 16, weight: FontWeight.w700, color: Dg.ink2),
              const SizedBox(height: 20),
              DgCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Display(task.recipient, size: 22),
                    const SizedBox(height: 6),
                    Text(task.address, style: const TextStyle(fontSize: 16, color: Dg.ink2, height: 1.35)),
                    if (success && who != null) ...[
                      const SizedBox(height: 10),
                      Text('Kim aldı: $who', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(color: Dg.night, borderRadius: BorderRadius.circular(12)),
                          child: Icon(
                            success ? Icons.door_front_door_rounded : Icons.undo_rounded,
                            color: success ? const Color(0xFF3FB3A8) : Dg.purpleBright,
                          ),
                        ),
                        const SizedBox(width: 12),
                        StatusChip(
                          label: online ? 'Gönderildi' : 'Cihazda bekliyor',
                          tone: online ? 'lo' : 'mid',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      online
                          ? (success ? 'Teslim kaydı gönderildi.' : 'İade kaydı merkeze gönderildi.')
                          : 'Kayıt cihazda. İnternet gelince gönderilecek.',
                      style: const TextStyle(fontSize: 15, color: Dg.ink2),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              FilledButton(
                style: !success ? FilledButton.styleFrom(backgroundColor: Dg.ink, foregroundColor: Colors.white) : null,
                onPressed: next != null ? onNext : onClose,
                child: Text(next != null ? 'Sıradaki durak' : 'Listeye dön'),
              ),
              if (next != null) TextButton(onPressed: onClose, child: const Text('Listeye dön')),
            ],
          ),
        ),
      ),
    );
  }
}
