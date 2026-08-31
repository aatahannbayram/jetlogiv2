import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client.dart';
import '../models.dart';
import '../motion.dart';
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
  String? editingField;
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

  void _startEditing(String field) => setState(() => editingField = field);

  void _saveField(String field) {
    ref
        .read(sessionProvider)
        .updateProfile(
          fullName: name.text.trim(),
          phone: phone.text.trim(),
          plateValue: plate.text.trim(),
        );
    setState(() => editingField = null);
  }

  Future<void> _confirmLogout(BuildContext context, SessionController s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çıkış yap'),
        content: const Text(
          'Oturumun kapatılacak, tekrar giriş yapman gerekecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Çıkış yap', style: TextStyle(color: Dg.hi)),
          ),
        ],
      ),
    );
    if (confirmed == true) await s.logout();
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
    String key,
    String label,
    TextEditingController controller, {
    String mono = '',
  }) {
    final isEditing = editingField == key;
    final textStyle = TextStyle(
      fontFamily: mono.isEmpty ? Dg.sans : Dg.mono,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Mono(label, size: 11, color: Dg.ink3),
                const SizedBox(height: 6),
                isEditing
                    ? TextField(
                        controller: controller,
                        autofocus: true,
                        style: textStyle,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onSubmitted: (_) => _saveField(key),
                      )
                    : Text(controller.text, style: textStyle),
              ],
            ),
          ),
          Pressable(
            onTap: () => isEditing ? _saveField(key) : _startEditing(key),
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                isEditing ? LucideIcons.circleCheck : LucideIcons.pencil,
                size: 20,
                color: isEditing ? Dg.purple : Dg.ink3,
              ),
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
    // ProfileScreen doubles as the "Profil" bottom tab (no back needed —
    // it's a shell root) and as a screen menu_screen.dart pushes on top of
    // the shell ("Profilim" tile) — canPop tells them apart, since only the
    // pushed case has anything to pop back to.
    final canPop = Navigator.canPop(context);
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
                  if (canPop) ...[
                    _BackButton(onTap: () => Navigator.of(context).pop()),
                    const SizedBox(height: 14),
                  ],
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
            Text(
              'Kullanıcı',
              style: Dg.ui(size: 20, weight: FontWeight.w700, color: Dg.ink),
            ),
            const SizedBox(height: 4),
            Text(
              'Her alanı ayrı ayrı düzenleyebilirsin.',
              style: Dg.ui(size: 13, color: Dg.ink3),
            ),
            const SizedBox(height: 10),
            DgCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _field('name', 'AD SOYAD', name),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: DgDivider(),
                  ),
                  _field('phone', 'TELEFON', phone, mono: 'm'),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: DgDivider(),
                  ),
                  _field('plate', 'PLAKA', plate, mono: 'm'),
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
                    icon: LucideIcons.palette,
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
                                LucideIcons.sun,
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
                                LucideIcons.moon,
                                size: 17,
                                color: s.darkModeUi ? Colors.white : Dg.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const DgDivider(),
                  _switchRow(
                    'Sesli barkod onayı',
                    s.beepEnabled ? 'Açık · bip + titreşim' : 'Kapalı',
                    s.beepEnabled,
                    s.toggleBeep,
                    icon: LucideIcons.volume2,
                  ),
                  const DgDivider(),
                  _switchRow(
                    'Yeni durak bildirimi',
                    s.notifyEnabled ? 'Açık · titreşim + ses' : 'Kapalı',
                    s.notifyEnabled,
                    s.toggleNotifyPref,
                    icon: LucideIcons.bellRing,
                  ),
                  const DgDivider(),
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
                    icon: LucideIcons.briefcase,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => _confirmLogout(context, s),
              child: Container(
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Dg.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Dg.hi),
                ),
                child: Text(
                  'Çıkış yap',
                  style: Dg.ui(size: 16, weight: FontWeight.w600, color: Dg.hi),
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
          Text(value, style: Dg.stat(size: 28, color: color)),
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

  Widget _settingRow(
    String title,
    String sub, {
    required Widget trailing,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          if (icon != null) ...[
            IconTintBadge(icon: icon, tint: Dg.elev, ink: Dg.ink2, size: 36),
            const SizedBox(width: 12),
          ],
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

  Widget _switchRow(
    String title,
    String sub,
    bool on,
    VoidCallback onTap, {
    IconData? icon,
  }) {
    return _settingRow(
      title,
      sub,
      icon: icon,
      trailing: DgSwitch(value: on, onChanged: (_) => onTap()),
    );
  }
}

/// Translucent on the dark hero header specifically (unlike
/// task_detail_screen's solid version, needed there for legible contrast
/// over unpredictable light map tiles) — here the backdrop is always
/// [Dg.night], so a glass pill reads cleanly against it.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      shape: const CircleBorder(side: BorderSide(color: Colors.white24)),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Icon(LucideIcons.arrowLeft, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}
