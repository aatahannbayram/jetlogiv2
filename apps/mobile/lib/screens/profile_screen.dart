import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client.dart';
import '../l10n.dart';
import '../locate.dart';
import '../log.dart';
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
    if (kReleaseMode) return;
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
        title: Text(context.l10n.logout),
        content: Text(
          s.panelLoggedIn
              ? context.l10n.logoutPanelBody
              : context.l10n.logoutBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.logout, style: TextStyle(color: Dg.hi)),
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
                      if (!kReleaseMode)
                        const Text('OTP      giriş 123456  ·  teslim 482913'),
                      const SizedBox(height: 10),
                      const Text('Panel cookie dokunulmaz. JWT Keychain.'),
                      const SizedBox(height: 12),
                      Text(
                        'log      ${DgLog.counts.values.fold<int>(0, (a, b) => a + b)}  ·  '
                        '${LogLayer.values.map((l) => '${l.name[0]}${DgLog.counts[l]}').join(' ')}',
                      ),
                      const SizedBox(height: 8),
                      for (final rec in DgLog.snapshot(last: 16))
                        Text(rec.line, maxLines: 2, overflow: TextOverflow.ellipsis),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Dg.rowMin),
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Mono(label, size: 12, color: Dg.ink2),
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
          padding: const EdgeInsets.fromLTRB(Dg.pagePad, 12, Dg.pagePad, 108),
          children: [
            if (canPop) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: _BackButton(onTap: () => Navigator.of(context).pop()),
              ),
              const SizedBox(height: 16),
            ],
            Center(
              child: InitialsAvatar(
                name: c.fullName,
                photoUrl: c.photoUrl,
                size: 86,
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                c.fullName,
                style: Dg.ui(size: 22, weight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: _onSecretTap,
              behavior: HitTestBehavior.opaque,
              child: Column(
                children: [
                  Text(c.vehicle, style: Dg.ui(size: 13, color: Dg.ink3)),
                  Text(c.code, style: Dg.ui(size: 13, color: Dg.ink3)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            DgCard(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  _stat('${s.deliveredCount}', context.l10n.deliveredShort, Dg.ink),
                  Container(width: 1, height: 36, color: Dg.rule),
                  _stat('${s.openCount}', context.l10n.openShort, Dg.ink),
                  Container(width: 1, height: 36, color: Dg.rule),
                  _stat('${s.returnCount}', context.l10n.returnShort, Dg.ink),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              context.l10n.userSection,
              style: Dg.kicker(color: Dg.ink2),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.editFieldsHint,
              style: Dg.ui(size: 14, color: Dg.ink2),
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
                  _field('phone', context.l10n.phoneCaps, phone, mono: 'm'),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: DgDivider(),
                  ),
                  _field('plate', context.l10n.plate, plate, mono: 'm'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              context.l10n.appSection,
              style: Dg.kicker(color: Dg.ink2),
            ),
            const SizedBox(height: 10),
            DgCard(
              child: Column(
                children: [
                  _settingRow(
                    context.l10n.appearance,
                    s.darkModeUi ? context.l10n.darkTheme : context.l10n.lightTheme,
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
                                    : Dg.ink,
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
                                    ? Dg.ink
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
                  _settingRow(
                    context.l10n.language,
                    s.localeCode == 'en'
                        ? context.l10n.languageEn
                        : context.l10n.languageTr,
                    icon: LucideIcons.languages,
                    trailing: GestureDetector(
                      onTap: () => s.setLocale(s.localeCode == 'en' ? 'tr' : 'en'),
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
                                color: s.localeCode == 'tr'
                                    ? Dg.ink
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'TR',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: s.localeCode == 'tr'
                                      ? Colors.white
                                      : Dg.ink,
                                ),
                              ),
                            ),
                            Container(
                              width: 44,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: s.localeCode == 'en'
                                    ? Dg.ink
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'EN',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: s.localeCode == 'en'
                                      ? Colors.white
                                      : Dg.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const DgDivider(),
                  _switchRow(
                    context.l10n.barcodeBeep,
                    s.beepEnabled ? context.l10n.onBeep : context.l10n.off,
                    s.beepEnabled,
                    s.toggleBeep,
                    icon: LucideIcons.volume2,
                  ),
                  const DgDivider(),
                  _switchRow(
                    context.l10n.newStopAlerts,
                    !s.notifyEnabled
                        ? context.l10n.off
                        : s.notifyOsBlocked
                        ? context.l10n.notifyNeedOs
                        : context.l10n.onNotify,
                    s.notifyEnabled,
                    () async {
                      final permit = await s.toggleNotifyPref();
                      if (!context.mounted) return;
                      if (permit == null || permit == PushPermit.granted) {
                        return;
                      }
                      explainPushPermit(context, permit);
                    },
                    icon: LucideIcons.bellRing,
                  ),
                  const DgDivider(),
                  _switchRow(
                    s.shiftOpen
                        ? context.l10n.shiftOpen
                        : context.l10n.shiftClosed,
                    context.l10n.shiftCityHint(
                      s.courier.district,
                      s.courier.city,
                      s.shiftOpen,
                    ),
                    s.shiftOpen,
                    () async {
                      if (s.shiftOpen) {
                        final end = await confirmEndShift(context);
                        if (end) s.setShiftOpen(false);
                      } else if (s.bypassShiftGate) {
                        s.setShiftOpen(true);
                      } else {
                        final ok = await showShiftSelfieSheet(
                          context,
                          onPhoto: s.takeShiftPhoto,
                        );
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
        children: [
          Text(value, style: Dg.stat(size: 22, color: color)),
          const SizedBox(height: 2),
          Text(label, style: Dg.ui(size: 12, color: Dg.ink3)),
        ],
      ),
    );
  }

  Widget _settingRow(
    String title,
    String sub, {
    required Widget trailing,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Dg.rowMin),
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
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(LucideIcons.arrowLeft, size: 20, color: Dg.ink),
        ),
      ),
    );
  }
}
