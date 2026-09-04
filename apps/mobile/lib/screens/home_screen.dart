import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../launchers.dart';
import '../models.dart';
import '../motion.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'notif_screen.dart';
import 'shell_screen.dart' show RouteScreen;
import 'sync_screen.dart';
import 'wizard_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _startShift(BuildContext context, SessionController s) async {
    final ok = await showShiftSelfieSheet(context);
    if (ok) s.setShiftOpen(true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final hero = s.nextStop;
    final syncTotal = s.outbox.events.where((e) => e.pending).length;
    final syncDone = syncTotal == 0;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 108),
          children: [
            Row(
              children: [
                InitialsAvatar(
                  name: s.courier.fullName,
                  online: s.online,
                  size: 42,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.courier.fullName,
                        style: Dg.ui(size: 16, weight: FontWeight.w700),
                      ),
                      Text(
                        '${s.courier.district} / ${s.courier.city}',
                        style: Dg.ui(size: 12, color: Dg.ink3),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NotifScreen(),
                    ),
                  ),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Dg.elev,
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(LucideIcons.bell, size: 17, color: Dg.ink),
                        if (s.unreadNotifCount > 0)
                          Positioned(
                            top: 5,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 15,
                                minHeight: 15,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Dg.red,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Dg.ground,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                '${s.unreadNotifCount}',
                                style: const TextStyle(
                                  fontFamily: Dg.mono,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: s.toggleOnline,
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Dg.elev,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(LucideIcons.search, size: 17, color: Dg.ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!s.shiftOpen)
              _ShiftClosedCard(onStart: () => _startShift(context, s))
            else
              _ShiftOpenCard(session: s),
            if (s.shiftOpen) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Sıradaki durak',
                      style: Dg.serif(size: 19, weight: FontWeight.w600),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RouteScreen(),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Rotayı gör',
                          style: Dg.ui(
                            size: 13,
                            weight: FontWeight.w600,
                            color: Dg.primaryGradientStart,
                          ),
                        ),
                        Icon(
                          LucideIcons.chevronRight,
                          size: 16,
                          color: Dg.primaryGradientStart,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (hero != null) _HeroStop(task: hero) else const _NoStopCard(),
            ],
            const SizedBox(height: 20),
            DgCard(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SyncScreen()),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.refreshCw,
                        size: 19,
                        color: syncDone ? Dg.purpleDeep : Dg.amber,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Senkronizasyon',
                          style: Dg.ui(size: 16, weight: FontWeight.w600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: syncDone ? Dg.greenBg : Dg.amberBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          syncDone ? 'Temiz' : '$syncTotal bekliyor',
                          style: TextStyle(
                            fontFamily: Dg.mono,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: syncDone ? Dg.green : Dg.amber,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: syncDone ? 1 : 0.6,
                      minHeight: 6,
                      backgroundColor: Dg.elev,
                      valueColor: const AlwaysStoppedAnimation(Dg.purple),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    syncDone
                        ? 'Tüm kayıtlar merkeze iletildi.'
                        : '$syncTotal kayıt çevrimdışı kuyrukta, çevrimiçi olunca gönderilir.',
                    style: Dg.ui(size: 13, color: Dg.ink2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Bildirimler',
                    style: Dg.serif(size: 21, weight: FontWeight.w600),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NotifScreen(),
                    ),
                  ),
                  child: Text(
                    'Tümü',
                    style: Dg.ui(
                      size: 13,
                      weight: FontWeight.w600,
                      color: Dg.purpleDeep,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (s.notifications.isEmpty)
              DgCard(
                child: Row(
                  children: [
                    Icon(LucideIcons.bell, size: 20, color: Dg.ink3),
                    const SizedBox(width: 10),
                    Text(
                      'Yeni bildirim yok',
                      style: Dg.ui(size: 14, color: Dg.ink3),
                    ),
                  ],
                ),
              )
            else
              for (final (i, n) in s.notifications.take(2).indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: StaggerIn(
                    index: i,
                    child: DgCard(
                      padding: EdgeInsets.zero,
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            Container(
                              width: 3,
                              decoration: BoxDecoration(
                                color: n.ink,
                                borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(Dg.radius),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    IconTintBadge(
                                      icon: n.icon,
                                      tint: n.tint,
                                      ink: n.ink,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            n.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            n.body,
                                            style: Dg.ui(
                                              size: 13,
                                              color: Dg.ink3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Mono(n.time, size: 11),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _ShiftClosedCard extends StatelessWidget {
  const _ShiftClosedCard({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Dg.radiusHero),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(color: Dg.night),
        child: Stack(
          children: [
            const Positioned.fill(child: RouteGlowBackground()),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'VARDİYA DURUMU',
                    style: TextStyle(
                      fontFamily: Dg.mono,
                      fontSize: 11,
                      letterSpacing: 1.2,
                      color: Color(0xFF8A8F80),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Kapalı',
                    style: TextStyle(
                      fontFamily: Dg.display,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Vardiyayı başlatmak için selfie doğrulaması gerekir.',
                    style: TextStyle(
                      color: Color(0xFF9A9E90),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: Dg.primaryGradient,
                        borderRadius: BorderRadius.circular(Dg.radiusPill),
                      ),
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                        ),
                        onPressed: onStart,
                        icon: const Icon(LucideIcons.camera, size: 19),
                        label: const Text('Vardiyayı başlat'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShiftOpenCard extends StatelessWidget {
  const _ShiftOpenCard({required this.session});
  final SessionController session;

  @override
  Widget build(BuildContext context) {
    final plan = session.routePlan;
    final km = plan == null
        ? '—'
        : (plan.totalDistanceMeters / 1000).toStringAsFixed(1);
    return ClipRRect(
      borderRadius: BorderRadius.circular(Dg.radiusHero),
      child: Container(
        decoration: BoxDecoration(
          gradient: Dg.primaryGradient,
          boxShadow: Dg.shadowHero,
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: RouteGlowBackground()),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Vardiya açık',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      DgSwitch(
                        value: true,
                        onChanged: (_) => session.setShiftOpen(false),
                        activeColor: Colors.white,
                        thumbColor: Dg.primaryGradientStart,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        session.shiftElapsedLabel,
                        style: Dg.stat(size: 30, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          "${session.shiftStartLabel}'tan beri",
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFDCCFEF),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _pill(
                          'Teslim',
                          '${session.deliveredCount} / ${session.tasks.length}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _pill('Mesafe', km)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFFDCCFEF), fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(value, style: Dg.stat(size: 16, color: Colors.white)),
        ],
      ),
    );
  }
}

class _HeroStop extends ConsumerWidget {
  const _HeroStop({required this.task});
  final DeliveryTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DgCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              // eta bilinçli olarak geçilmiyor: aşağıdaki gradyanlı rozet
              // zaten ETA'yı gösteriyor, MapStrip'in kendi alt-sağ pill'ine
              // aynı bilgiyi ikinci kez bastırmak sadece iki üst üste binen
              // rozet üretiyordu.
              MapStrip(
                height: 108,
                points: [LatLng(task.lat, task.lng)],
                onTap: () => openDirections(context, task),
              ),
              if (task.etaMinutes != null)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: Dg.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.navigation,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '-${task.etaMinutes} dk',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Mono('#${task.sequence}  ·  ${task.ref}', color: Dg.ink3),
                    const Spacer(),
                    StatusChip(
                      label: taskStatusLabel(task.status),
                      tone: taskStatusTone(task.status),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Display(task.recipient, size: 22),
                const SizedBox(height: 4),
                Text(
                  task.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Dg.ui(size: 13, color: Dg.ink2),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _pill('Aralık', task.window.split('–').first),
                    if (task.custodyCount != null)
                      _pill('Zimmet', '${task.custodyCount} kalem'),
                    if (task.otpRequired) _pill('Teslim kodu', 'Gerekli'),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: Dg.primaryGradient,
                            borderRadius: BorderRadius.circular(Dg.radiusPill),
                          ),
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                            ),
                            onPressed: () {
                              ref.read(sessionProvider).startTask(task.id);
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => WizardScreen(taskId: task.id),
                                ),
                              );
                            },
                            icon: const Icon(LucideIcons.navigation, size: 16),
                            label: const Text('Yol tarifi'),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _squareIcon(
                      LucideIcons.phone,
                      () => callRecipient(context),
                      tint: Dg.violetBg,
                      ink: Dg.violet,
                    ),
                    const SizedBox(width: 8),
                    _squareIcon(LucideIcons.messageSquare, () {}),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Dg.elev,
        borderRadius: BorderRadius.circular(Dg.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Dg.ink3)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Dg.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _squareIcon(
    IconData icon,
    VoidCallback onTap, {
    Color? tint,
    Color? ink,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: tint ?? Dg.elev,
          borderRadius: BorderRadius.circular(16),
          border: Border(top: BorderSide(color: Dg.insetHighlight)),
          boxShadow: Dg.shadow,
        ),
        child: Icon(icon, size: 18, color: ink ?? Dg.ink),
      ),
    );
  }
}

class _NoStopCard extends StatelessWidget {
  const _NoStopCard();

  @override
  Widget build(BuildContext context) {
    return DgCard(
      hero: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTintBadge(
            icon: LucideIcons.listChecks,
            tint: Dg.greenBg,
            ink: Dg.green,
            size: 44,
          ),
          const SizedBox(height: 14),
          Text(
            'Sıradaki durak yok',
            style: Dg.serif(size: 20, weight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Açık göreviniz kalmadı — yeni bir durak atandığında burada görünecek.',
            style: Dg.ui(size: 14, color: Dg.ink2, height: 1.4),
          ),
        ],
      ),
    );
  }
}
