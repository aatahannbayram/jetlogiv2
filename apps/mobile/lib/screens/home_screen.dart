import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

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

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 6) return 'İyi geceler';
    if (h < 12) return 'Günaydın';
    if (h < 18) return 'İyi günler';
    return 'İyi akşamlar';
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
                Image.asset('assets/images/jetlogi_logo_color.png', height: 26),
                const Spacer(),
                InitialsAvatar(name: s.courier.fullName, online: s.online, size: 36),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NotifScreen())),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(color: Dg.surface, shape: BoxShape.circle),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(Icons.notifications_outlined, size: 19, color: Dg.ink),
                        if (s.unreadNotifCount > 0)
                          Positioned(
                            top: 5,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: Dg.red, shape: BoxShape.circle, border: Border.all(color: Dg.surface, width: 1.5)),
                              child: Text(
                                '${s.unreadNotifCount}',
                                style: const TextStyle(fontFamily: Dg.mono, fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white, height: 1),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text('${_greeting()}, ${s.courier.fullName.split(' ').first}', style: Dg.serif(size: 27, weight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.shiftOpen ? 'Vardiya açık  ·  ${s.courier.district} / ${s.courier.city}' : 'Vardiya kapalı',
                    style: Dg.ui(size: 14, color: Dg.ink2, height: 1.2),
                  ),
                ),
                GestureDetector(
                  onTap: s.toggleOnline,
                  child: StatusChip(label: s.online ? 'Çevrimiçi' : 'Çevrimdışı', tone: s.online ? 'lime' : 'hi'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (!s.shiftOpen)
              _ShiftClosedCard(onStart: () => _startShift(context, s))
            else ...[
              _ShiftOpenCard(session: s),
              const SizedBox(height: 14),
              if (hero != null) _HeroStop(task: hero) else const _NoStopCard(),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                if (s.courier.canSeePricing) ...[
                  StatTile(label: 'BUGÜN', value: SessionController.todayEarn, sub: SessionController.earnDelta, subColor: Dg.purpleDeep),
                  const SizedBox(width: 12),
                ],
                StatTile(
                  label: 'TESLİM',
                  value: '${s.deliveredCount}/${s.tasks.length}',
                  sub: '${s.openCount} durak açık',
                ),
              ],
            ),
            const SizedBox(height: 12),
            DgCard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SyncScreen())),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.sync_rounded, size: 19, color: syncDone ? Dg.purpleDeep : Dg.amber),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Senkronizasyon', style: Dg.ui(size: 16, weight: FontWeight.w600))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                        decoration: BoxDecoration(color: syncDone ? Dg.greenBg : Dg.amberBg, borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          syncDone ? 'Temiz' : '$syncTotal bekliyor',
                          style: TextStyle(fontFamily: Dg.mono, fontSize: 11, fontWeight: FontWeight.w700, color: syncDone ? Dg.green : Dg.amber),
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
                    syncDone ? 'Tüm kayıtlar merkeze iletildi.' : '$syncTotal kayıt çevrimdışı kuyrukta, çevrimiçi olunca gönderilir.',
                    style: Dg.ui(size: 13, color: Dg.ink2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                Expanded(child: Text('Bildirimler', style: Dg.serif(size: 21, weight: FontWeight.w600))),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NotifScreen())),
                  child: Text('Tümü', style: Dg.ui(size: 13, weight: FontWeight.w600, color: Dg.purpleDeep)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (s.notifications.isEmpty)
              DgCard(
                child: Row(
                  children: [
                    const Icon(Icons.notifications_none_rounded, size: 20, color: Dg.ink3),
                    const SizedBox(width: 10),
                    Text('Yeni bildirim yok', style: Dg.ui(size: 14, color: Dg.ink3)),
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
                            Container(width: 3, decoration: BoxDecoration(color: n.ink, borderRadius: const BorderRadius.horizontal(left: Radius.circular(Dg.radius)))),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                child: Row(
                                  children: [
                                    IconTintBadge(icon: n.icon, tint: n.tint, ink: n.ink),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(n.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                          const SizedBox(height: 3),
                                          Text(n.body, style: Dg.ui(size: 13, color: Dg.ink3)),
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
                  const Text('VARDİYA DURUMU', style: TextStyle(fontFamily: Dg.mono, fontSize: 11, letterSpacing: 1.2, color: Color(0xFF8A8F80))),
                  const SizedBox(height: 10),
                  const Text('Kapalı', style: TextStyle(fontFamily: Dg.display, fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5)),
                  const SizedBox(height: 8),
                  const Text(
                    'Vardiyayı başlatmak için selfie doğrulaması gerekir.',
                    style: TextStyle(color: Color(0xFF9A9E90), fontSize: 15, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Dg.purple, foregroundColor: Colors.white),
                    onPressed: onStart,
                    icon: const Icon(Icons.photo_camera_outlined, size: 19),
                    label: const Text('Vardiyayı başlat'),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(Dg.radiusHero),
      child: Container(
        decoration: BoxDecoration(color: Dg.purple, boxShadow: Dg.shadowHero),
        child: Stack(
          children: [
            const Positioned.fill(child: RouteGlowBackground()),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('VARDİYA AÇIK', style: TextStyle(fontFamily: Dg.mono, fontSize: 11, letterSpacing: 1.2, color: Color(0xFFDCCFEF))),
                        const SizedBox(height: 8),
                        Text(session.shiftElapsedLabel, style: Dg.stat(size: 30, color: Colors.white)),
                        const SizedBox(height: 6),
                        Text('${session.openCount} durak açık', style: const TextStyle(color: Color(0xFFE3D9F2), fontSize: 13)),
                      ],
                    ),
                  ),
                  DgSwitch(
                    value: true,
                    onChanged: (_) => session.setShiftOpen(false),
                    activeColor: Dg.ink,
                    thumbColor: Colors.white,
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

class _HeroStop extends ConsumerWidget {
  const _HeroStop({required this.task});
  final DeliveryTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DgCard(
      lime: false,
      hero: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MapStrip(
            eta: task.etaMinutes,
            height: 108,
            points: [LatLng(task.lat, task.lng)],
            onTap: () => openDirections(context, task),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Mono('#${task.sequence}  ${task.ref}', color: Dg.ink),
                    const Spacer(),
                    StatusChip(label: taskStatusLabel(task.status), tone: 'lime'),
                  ],
                ),
                const SizedBox(height: 8),
                Display(task.recipient, size: 30),
                const SizedBox(height: 6),
                Text(task.address, style: Dg.ui(size: 15, color: Dg.ink2, height: 1.35)),
                const SizedBox(height: 8),
                Text('${task.kindLabel}  ·  ${task.window}', style: Dg.ui(size: 13, color: Dg.ink2)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          ref.read(sessionProvider).startTask(task.id);
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => WizardScreen(taskId: task.id)),
                          );
                        },
                        child: const Text('Teslime başla'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RouteScreen())),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(color: Dg.elev, borderRadius: BorderRadius.circular(20)),
                        child: const Icon(Icons.near_me_outlined, size: 20, color: Dg.ink),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
          IconTintBadge(icon: Icons.task_alt_rounded, tint: Dg.greenBg, ink: Dg.green, size: 44),
          const SizedBox(height: 14),
          Text('Sıradaki durak yok', style: Dg.serif(size: 20, weight: FontWeight.w600)),
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
