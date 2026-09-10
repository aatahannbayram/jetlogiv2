import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../models.dart';
import '../motion.dart';
import '../theme.dart';
import '../widgets.dart';

/// Shown after a delivery is closed, either successfully or as a return
/// ("İade"). Reused by [WizardScreen]'s success path and [ReturnScreen].
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
    final l = context.l10n;
    final now = DateTime.now();
    final clock =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return Scaffold(
      backgroundColor: success ? Dg.loBg : Dg.redBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ResultIcon(
                icon: success ? LucideIcons.circleCheck : LucideIcons.packageX,
                color: success ? Dg.lo : Dg.red,
              ),
              const SizedBox(height: 16),
              Display(success ? l.deliveredOk : l.returnRecorded, size: 36),
              const SizedBox(height: 6),
              Mono(clock, size: 16, weight: FontWeight.w700, color: Dg.ink2),
              const SizedBox(height: 20),
              DgCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Display(task.recipient, size: 22),
                    const SizedBox(height: 6),
                    Text(
                      task.address,
                      style: TextStyle(
                        fontSize: 16,
                        color: Dg.ink2,
                        height: 1.35,
                      ),
                    ),
                    if (success && who != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        l.whoTook(who!),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Dg.night,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DgIcon(
                            success ? LucideIcons.doorOpen : LucideIcons.undo2,
                            color: success
                                ? const Color(0xFF3FB3A8)
                                : Dg.brand,
                            weight: 600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        StatusChip(
                          label: online ? l.sent : l.waitingOnDevice,
                          tone: online ? 'lo' : 'mid',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      online
                          ? (success ? l.deliveryRecordSent : l.returnRecordSent)
                          : l.recordOnDevice,
                      style: TextStyle(fontSize: 15, color: Dg.ink2),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              DgButton(
                label: next != null ? l.nextStopCta : l.backToList,
                icon: next != null ? LucideIcons.navigation : LucideIcons.list,
                tone: success ? DgButtonTone.primary : DgButtonTone.secondary,
                onPressed: next != null ? onNext : onClose,
              ),
              if (next != null)
                TextButton(
                  onPressed: onClose,
                  child: Text(l.backToList),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
