import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../launchers.dart';
import '../models.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'fail_screen.dart';
import 'wizard_screen.dart';

/// Canvas'ın "1d Görev detayı" tasarımı — tam ekran harita + kaydırmalı
/// alt sheet. Kapıda ödeme yerine Zimmet/Teslim penceresi/Teslim kodu
/// ikonlu bilgi kartları (bkz. plan Faz E).
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
                // eta bilinçli olarak geçilmiyor: aşağıdaki _EtaPill zaten
                // gösteriyor, MapStrip'in kendi pill'i aynı bilgiyi ikinci
                // kez basıp üst üste iki rozet oluşturuyordu.
                MapStrip(
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
                        // Solid (not glass) so it stays legible over light OSM
                        // tiles — a translucent white pill nearly disappeared
                        // against pale map backgrounds.
                        _BackButton(onTap: () => Navigator.of(context).pop()),
                        const Spacer(),
                        if (t.etaMinutes != null)
                          _EtaPill(minutes: t.etaMinutes!),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Dg.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(Dg.radiusHero),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 40,
                  offset: Offset(0, -16),
                ),
              ],
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
                        decoration: BoxDecoration(
                          color: Dg.rule,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Mono('#${t.sequence}  ·  ${t.ref}', color: Dg.ink3),
                        const Spacer(),
                        StatusChip(
                          label: taskStatusLabel(t.status),
                          tone: taskStatusTone(t.status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Hero(
                      tag: 'recipient-${t.id}',
                      child: Material(
                        color: Colors.transparent,
                        child: Display(t.recipient, size: 22),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Dg.ink2,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _InfoCard(
                      icon: LucideIcons.layers,
                      label: 'Zimmet',
                      value: t.custodyCount == null
                          ? '—'
                          : '${t.custodyCount} kalem${t.custodyRef == null ? '' : ' · ${t.custodyRef}'}',
                    ),
                    const SizedBox(height: 8),
                    _InfoCard(
                      icon: LucideIcons.clock,
                      label: 'Teslim penceresi',
                      value: t.slaMinutesLeft == null
                          ? t.window
                          : '${t.slaLabel} kaldı',
                    ),
                    if (t.otpRequired) ...[
                      const SizedBox(height: 8),
                      const _InfoCard(
                        icon: LucideIcons.key,
                        label: 'Teslim kodu',
                        value: 'Alıcıdan istenecek',
                        dot: true,
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        SquareAction(
                          icon: LucideIcons.phone,
                          label: 'Ara',
                          onTap: () => callRecipient(context),
                        ),
                        const SizedBox(width: 10),
                        SquareAction(
                          icon: LucideIcons.navigation,
                          label: 'Yol',
                          onTap: () => openDirections(context, t),
                        ),
                        const SizedBox(width: 10),
                        SquareAction(
                          icon: LucideIcons.camera,
                          label: 'Foto',
                          onTap: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (done)
                      Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: Dg.loBg,
                              borderRadius: BorderRadius.circular(
                                Dg.radiusPill,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  LucideIcons.circleCheck,
                                  size: 20,
                                  color: Dg.lo,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Teslim edildi',
                                  style: Dg.ui(
                                    size: 16,
                                    weight: FontWeight.w700,
                                    color: Dg.lo,
                                  ),
                                ),
                              ],
                            ),
                          )
                          .animate()
                          .scale(
                            begin: const Offset(0.96, 0.96),
                            duration: 220.ms,
                            curve: Curves.easeOutBack,
                          )
                          .fadeIn(duration: 180.ms)
                    else
                      SlideToAct(
                        label: 'Teslim etmek için kaydır',
                        onConfirm: start,
                      ),
                    if (!done) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: () async {
                            final failed = await Navigator.of(context)
                                .push<bool>(
                                  MaterialPageRoute<bool>(
                                    builder: (_) => FailScreen(taskId: t.id),
                                  ),
                                );
                            if (failed == true && context.mounted)
                              Navigator.of(context).pop();
                          },
                          child: Text(
                            'Teslim edilemedi',
                            style: TextStyle(
                              color: Dg.hi,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
}

/// Canvas'ın "Zimmet/Teslim penceresi/Teslim kodu" bilgi satırları —
/// ikon + etiket solda, değer sağda; [dot] gerektiğinde değerin önüne
/// bekleyen-durum noktası ekler (teslim kodu henüz alınmadıysa).
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    this.dot = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Dg.elev,
        borderRadius: BorderRadius.circular(Dg.radius),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: Dg.ink2),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: Dg.ui(size: 14, color: Dg.ink2)),
          ),
          if (dot) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: Dg.sand, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Dg.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Dg.night, not Dg.ink: this sits on the map photo, not the app's own
    // background, so it must stay a fixed dark chip regardless of the
    // active koyu/açık tema — Dg.ink flips to near-white in dark mode and
    // would disappear here (that's what made this invisible before).
    return Material(
      color: Dg.night,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 38,
          height: 38,
          child: Icon(LucideIcons.arrowLeft, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

/// Birleşik ETA rozeti — canvas'ta "↗ ~6 dk" — opak mor gradyan dolgu
/// kullanır, böylece haritanın gerçek renginden bağımsız her zaman
/// okunaklı kalır (glass/translucent pillerin aksine).
class _EtaPill extends StatelessWidget {
  const _EtaPill({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        gradient: Dg.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.navigation, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            '~$minutes dk',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
