import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../launchers.dart';
import '../models.dart';
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
            Image.asset('assets/images/jetlogi_logo_color.png', height: 32),
            const SizedBox(height: 14),
            Row(
              children: [
                InitialsAvatar(name: s.courier.fullName, online: s.online),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.courier.fullName, style: Dg.ui(size: 16, weight: FontWeight.w700, height: 1.2)),
                      Text(
                        s.shiftOpen ? 'Vardiya açık  ·  ${s.courier.district} / ${s.courier.city}' : 'Vardiya kapalı',
                        style: Dg.ui(size: 13, color: Dg.ink2, height: 1.2),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: s.toggleOnline,
                  child: StatusChip(label: s.online ? 'Çevrimiçi' : 'Çevrimdışı', tone: s.online ? 'lime' : 'hi'),
                ),
                const SizedBox(width: 8),
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
                            top: 9,
                            right: 10,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: Dg.red, shape: BoxShape.circle, border: Border.all(color: Dg.surface, width: 2)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!s.shiftOpen)
              _ShiftClosedCard(onStart: () => _startShift(context, s))
            else ...[
              _ShiftOpenCard(session: s),
              if (hero != null) ...[
                const SizedBox(height: 14),
                _HeroStop(task: hero),
              ],
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                s.courier.canSeePricing
                    ? StatTile(label: 'BUGÜN', value: SessionController.todayEarn, sub: SessionController.earnDelta, subColor: Dg.purpleDeep)
                    : StatTile(label: 'AYLIK KARŞILIK', value: s.courier.monthlyPayLabel, sub: 'sabit ücret'),
                const SizedBox(width: 12),
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
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(child: Text('Bildirimler', style: Dg.ui(size: 20, weight: FontWeight.w700, color: Dg.ink))),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NotifScreen())),
                  child: Text('Tümü', style: Dg.ui(size: 13, weight: FontWeight.w600, color: Dg.purpleDeep)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final n in s.notifications.take(2))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DgCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        Text(session.shiftElapsedLabel, style: const TextStyle(fontFamily: Dg.display, fontSize: 30, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5)),
                        const SizedBox(height: 6),
                        Text('${session.openCount} durak açık', style: const TextStyle(color: Color(0xFFE3D9F2), fontSize: 13)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => session.setShiftOpen(false),
                    child: Container(
                      width: 58,
                      height: 34,
                      decoration: BoxDecoration(color: Dg.ink, borderRadius: BorderRadius.circular(20)),
                      child: const Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: EdgeInsets.all(4),
                          child: DecoratedBox(decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: SizedBox(width: 26, height: 26)),
                        ),
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
