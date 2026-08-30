import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client.dart';
import '../models.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _taps = 0;
  DateTime? _lastTap;
  bool editing = false;
  late final name = TextEditingController(
    text: ref.read(sessionProvider).courier.fullName,
  );
  late final phone = TextEditingController(
    text: ref.read(sessionProvider).courier.phone,
  );
  late final plate = TextEditingController(
    text: ref.read(sessionProvider).plate,
  );

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    plate.dispose();
    super.dispose();
  }

  void _onSecretTap() {
    final now = DateTime.now();
    if (_lastTap == null ||
        now.difference(_lastTap!) > const Duration(seconds: 2)) {
      _taps = 1;
    } else {
      _taps += 1;
    }
    _lastTap = now;
    if (_taps >= 5) {
      _taps = 0;
      _showEngineer();
    }
  }

  void _toggleEdit() {
    if (editing) {
      ref
          .read(sessionProvider)
          .updateProfile(
            fullName: name.text.trim(),
            phone: phone.text.trim(),
            plateValue: plate.text.trim(),
          );
    }
    setState(() => editing = !editing);
  }

  void _showEngineer() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Dg.night,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final s = ref.read(sessionProvider);
            final c = s.courier;
            final label = c.affiliation == CourierAffiliation.agency
                ? 'acenta (fiyat gizli)'
                : c.compensationType == CompensationType.pieceRate
                ? 'bağımsız · hakediş (fiyat açık)'
                : 'bağımsız · aylık sabit (fiyat gizli)';
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: DefaultTextStyle(
                  style: const TextStyle(
                    fontFamily: Dg.mono,
                    color: Color(0xFFB7C7C5),
                    fontSize: 13,
                    height: 1.45,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mühendis',
                        style: TextStyle(
                          fontFamily: Dg.display,
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('OpenAPI  1.0.0-draft.2'),
                      Text('Base     $kApiBase'),
                      const Text('GET      /v1/config'),
                      const Text('POST     /v1/sync/batch'),
                      const Text('GET      /v1/me/availability'),
                      const Text('GET      /v1/me/documents'),
                      const SizedBox(height: 10),
                      Text(
                        'env      ${s.config.environment}  ·  live=${s.liveApi}',
                      ),
                      Text(
                        'cipher   ${s.cipherOn ? 'on' : 'off'}  ·  outbox Drift',
                      ),
                      const Text('OTP      giriş 123456  ·  teslim 482913'),
                      const SizedBox(height: 10),
                      const Text('Panel cookie dokunulmaz. JWT Keychain.'),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: () {
                          s.cyclePricingVisibility();
                          setSheetState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2622),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'fiyat görünürlüğü: $label  ·  değiştirmek için dokun',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String mono = '',
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Mono(label, size: 11, color: Dg.ink3),
          const SizedBox(height: 6),
          editing
              ? TextField(
                  controller: controller,
                  style: TextStyle(
                    fontFamily: mono.isEmpty ? Dg.sans : Dg.mono,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                )
              : Text(
                  controller.text,
                  style: TextStyle(
                    fontFamily: mono.isEmpty ? Dg.sans : Dg.mono,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final c = s.courier;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 108),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Dg.night,
                borderRadius: BorderRadius.circular(Dg.radiusHero),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InitialsAvatar(name: c.fullName, size: 62),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.fullName,
                              style: const TextStyle(
                                fontFamily: Dg.display,
                                fontSize: 25,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 5),
                            GestureDetector(
                              onTap: _onSecretTap,
                              behavior: HitTestBehavior.opaque,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.vehicle,
                                    style: const TextStyle(
                                      fontFamily: Dg.mono,
                                      fontSize: 12,
                                      color: Color(0xFF8A8F80),
                                    ),
                                  ),
                                  Text(
                                    c.code,
                                    style: const TextStyle(
                                      fontFamily: Dg.mono,
                                      fontSize: 12,
                                      color: Color(0xFF8A8F80),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _stat('${s.deliveredCount}', 'teslim', Dg.purpleBright),
                      _divider(),
                      _stat('${s.openCount}', 'açık', Colors.white),
                      _divider(),
                      _stat('${s.returnCount}', 'iade', Colors.white),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Kullanıcı',
                    style: Dg.ui(
                      size: 20,
                      weight: FontWeight.w700,
                      color: Dg.ink,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _toggleEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: editing ? Dg.purple : Dg.elev,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      editing ? 'Kaydet' : 'Düzenle',
                      style: Dg.ui(size: 13, weight: FontWeight.w600, color: editing ? Colors.white : Dg.ink),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DgCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _field('AD SOYAD', name),
                  Container(
                    height: 1,
                    color: Dg.rule,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  _field('TELEFON', phone, mono: 'm'),
                  Container(
                    height: 1,
                    color: Dg.rule,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  _field('PLAKA', plate, mono: 'm'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Uygulama',
              style: Dg.ui(size: 20, weight: FontWeight.w700, color: Dg.ink),
            ),
            const SizedBox(height: 10),
            DgCard(
              child: Column(
                children: [
                  _settingRow(
                    'Görünüm',
                    s.darkModeUi ? 'Koyu tema' : 'Açık tema',
                    trailing: GestureDetector(
                      onTap: s.toggleDarkModeUi,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Dg.elev,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: s.darkModeUi
                                    ? Colors.transparent
                                    : Dg.purple,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                Icons.light_mode_outlined,
                                size: 17,
                                color: s.darkModeUi ? Dg.ink : Colors.white,
                              ),
                            ),
                            Container(
                              width: 44,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: s.darkModeUi
                                    ? Dg.purple
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                Icons.dark_mode_outlined,
                                size: 17,
                                color: s.darkModeUi ? Colors.white : Dg.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(height: 1, color: Dg.rule),
                  _switchRow(
                    'Sesli barkod onayı',
                    s.beepEnabled ? 'Açık · bip + titreşim' : 'Kapalı',
                    s.beepEnabled,
                    s.toggleBeep,
                  ),
                  Container(height: 1, color: Dg.rule),
                  _switchRow(
                    'Yeni durak bildirimi',
                    s.notifyEnabled ? 'Açık · titreşim + ses' : 'Kapalı',
                    s.notifyEnabled,
                    s.toggleNotifyPref,
                  ),
                  Container(height: 1, color: Dg.rule),
                  _switchRow(
                    s.shiftOpen ? 'Vardiya açık' : 'Vardiya kapalı',
                    '${s.courier.district} / ${s.courier.city} · ${s.shiftOpen ? "açık" : "yeni durak atanmaz"}',
                    s.shiftOpen,
                    () async {
                      if (s.shiftOpen) {
                        s.setShiftOpen(false);
                      } else {
                        final ok = await showShiftSelfieSheet(context);
                        if (ok) s.setShiftOpen(true);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () {},
              child: Container(
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Dg.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Dg.rule),
                ),
                child: Text(
                  'Çıkış yap',
                  style: Dg.ui(size: 16, weight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _onSecretTap,
              child: Center(
                child: Mono(
                  '1.0.0-draft.2  ·  ${s.liveApi ? 'live' : 'mock'}',
                  size: 12,
                  color: Dg.ink3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: Dg.display,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF8A8F80), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 34,
    color: const Color(0xFF2A2A2A),
    margin: const EdgeInsets.symmetric(horizontal: 4),
  );

  Widget _settingRow(String title, String sub, {required Widget trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 3),
                Text(sub, style: Dg.ui(size: 13, color: Dg.ink2)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _switchRow(String title, String sub, bool on, VoidCallback onTap) {
    return _settingRow(
      title,
      sub,
      trailing: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 58,
          height: 34,
          decoration: BoxDecoration(
            color: on ? Dg.purple : Dg.rule,
            borderRadius: BorderRadius.circular(20),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            alignment: on ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.all(4),
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: Dg.ink,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
