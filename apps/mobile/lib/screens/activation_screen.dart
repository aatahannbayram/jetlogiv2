import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/agency_models.dart';
import '../l10n.dart';
import '../login_identifier.dart';
import '../login_kit.dart';
import '../motion.dart';
import '../privacy.dart';
import '../session.dart';
import 'join_screens.dart';

enum LoginRole { courier, branch }

/// Giriş (teslim v1.1): tek ekranda İş Ortağı / Kurye seçimi, akıllı kimlik
/// alanı, şifre ya da SMS kodu. SMS istendiğinde aynı ekranda doğrulama
/// görünümü açılır (6 kutu, geri sayım, ekran tuş takımı).
class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({
    super.key,
    this.initialRole = LoginRole.courier,
    this.pushed = false,
  });

  final LoginRole initialRole;

  /// Bir ekranın üstüne açıldıysa (şube bağlantısı) başarıda kapanır.
  final bool pushed;

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  final _phone = TextEditingController();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  late LoginRole _role = widget.initialRole;
  String _code = '';
  Object? _codeError;
  bool _sent = false;
  bool _remember = true;
  bool _panelMode = true;
  bool _panelBusy = false;
  bool _verifying = false;
  bool _obscurePassword = true;
  bool _skipStoredPanel = false;
  AgencyDto? _pickedAgency;
  String? _error;

  bool get _branch => _role == LoginRole.branch;

  @override
  void initState() {
    super.initState();
    unawaited(
      ref.read(sessionProvider).rememberLogin.then((v) {
        if (mounted) setState(() => _remember = v);
      }),
    );
  }

  @override
  void dispose() {
    _phone.dispose();
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  String _activationError(
    L10n l,
    SessionController session, {
    bool verify = false,
  }) {
    final raw = session.lastActivationError;
    if (raw == 'NETWORK') return l.activationSendFailed;
    if (raw == 'OTP_RESEND_TOO_SOON' ||
        raw == 'RATE_LIMITED' ||
        raw == 'SMS_CODE_RATE_LIMITED') {
      return l.waitToResend;
    }
    final sms = l.smsLoginError(raw, session.loginRemainingAttempts);
    if (sms != null) return sms;
    if (raw != null &&
        raw != 'REQUEST_FAILED' &&
        raw != 'VERIFY_FAILED' &&
        raw != 'NO_CHALLENGE') {
      return raw;
    }
    return verify ? l.codeMismatch : l.activationSendFailed;
  }

  Future<void> _sendSms(L10n l) async {
    setState(() => _error = null);
    final ok = await ref
        .read(sessionProvider)
        .requestActivationCode(normalizeIdentifier(_phone.text));
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = _activationError(l, ref.read(sessionProvider)));
      return;
    }
    setState(() {
      _sent = true;
      _code = '';
      _codeError = null;
    });
  }

  Future<void> _loginPanel(L10n l) async {
    setState(() {
      _panelBusy = true;
      // Giriş sonrası veriler yüklenirken "kayıtlı oturum" kartı araya
      // girmesin; düğme yükleme bitene kadar döner.
      _skipStoredPanel = true;
      _error = null;
    });
    await ref.read(sessionProvider).setRememberLogin(_remember);
    final ok = await ref
        .read(sessionProvider)
        .loginWithPanel(
          identifier: normalizeIdentifier(_identifier.text),
          password: _password.text,
        );
    if (!mounted) return;
    setState(() => _panelBusy = false);
    if (!ok) {
      final s = ref.read(sessionProvider);
      final code = s.lastPanelError;
      setState(
        () => _error = code == 'PANEL_UNAVAILABLE'
            ? l.panelUnavailable
            : l.loginError(
                code,
                remainingAttempts: s.loginRemainingAttempts,
                lockedUntil: s.loginLockedUntil,
                fallback: l.loginFailed,
              ),
      );
      return;
    }
    ref.read(sessionProvider).completeActivation();
  }

  Future<void> _loginBranch() async {
    final s = ref.read(sessionProvider);
    final ok = await s.loginAsAgency(
      email: normalizeIdentifier(_identifier.text),
      password: _password.text,
      agencyId: _pickedAgency?.id,
    );
    if (!mounted) return;
    if (ok) {
      if (widget.pushed) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      return;
    }
    setState(() {});
    if (s.lastAgencyError == 'AGENCY_SELECTION_REQUIRED' &&
        s.agencySelectionOptions.isNotEmpty &&
        _pickedAgency == null) {
      await _pickAgency(context.l10n);
    }
  }

  Future<void> _verify(L10n l) async {
    if (_verifying) return;
    setState(() => _verifying = true);
    await ref.read(sessionProvider).setRememberLogin(_remember);
    final ok = await ref.read(sessionProvider).verifyLoginOtp(_code);
    if (!mounted) return;
    setState(() => _verifying = false);
    if (!ok) {
      setState(() {
        _error = _activationError(l, ref.read(sessionProvider), verify: true);
        _codeError = Object();
        _code = '';
      });
      return;
    }
    ref.read(sessionProvider).completeActivation();
  }

  void _typeDigit(L10n l, String d) {
    if (_code.length >= 6 || _verifying) return;
    setState(() {
      _code += d;
      _codeError = null;
      _error = null;
    });
    if (_code.length == 6) unawaited(_verify(l));
  }

  void _switchRole(LoginRole role) {
    if (role == _role) return;
    setState(() {
      _role = role;
      _error = null;
      _pickedAgency = null;
      if (role == LoginRole.branch) {
        _panelMode = true;
        _sent = false;
      }
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = ref.watch(sessionProvider);
    final storedPanel =
        !_branch && session.panelLoggedIn && !_sent && !_skipStoredPanel;
    return PrivacyGate(
      active: true,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: _usesDecor(session, storedPanel)
              ? LoginInk.decorGround
              : LoginInk.ground,
          body: _maybeBackdrop(
            _usesDecor(session, storedPanel),
            child: SafeArea(
              child: AnimatedSwitcher(
                duration: DgMotion.standard,
                switchInCurve: DgMotion.enter,
                switchOutCurve: DgMotion.exit,
                transitionBuilder: dgSwitchTransition,
                child: _sent && !_branch
                    ? KeyedSubtree(
                        key: const ValueKey('sms-verify'),
                        child: _smsVerify(l, session),
                      )
                    : KeyedSubtree(
                        key: const ValueKey('login-form'),
                        child: storedPanel
                            ? _page(l, session, storedPanel)
                            : _decorPage(l, session),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Teslim v1.1 katman sırası: dekor (cam çerçeve + ışıklar) → marka →
  /// yazısız yüzeyler (`yuzeyler/`) → gerçek alanlar, butonlar, ikonlar.
  /// Ölçüler `tasarim/yerlesim.json`; yatay ölçek = genişlik / 627.
  Widget _decorPage(L10n l, SessionController session) {
    final layout = _branch ? LoginLayout.partner : LoginLayout.courier;
    final smsMode = !_branch && !_panelMode;
    final kind = identifierKind(_identifier.text);
    final agencyError =
        _branch &&
            session.lastAgencyError != null &&
            session.lastAgencyError != 'AGENCY_SELECTION_REQUIRED'
        ? l.loginError(
            session.lastAgencyError,
            remainingAttempts: session.loginRemainingAttempts,
            lockedUntil: session.loginLockedUntil,
            fallback: l.subeLoginFailed,
          )
        : null;
    final error = _branch ? agencyError : _error;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth.clamp(0.0, 540.0);
        final s = w / LoginLayout.width;
        final h = LoginLayout.height * s;
        Widget placed(String key, Widget child) => layout.place(key, s, child);
        final stack = SizedBox(
          width: w,
          height: h,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: Image.asset(
                    layout.asset('dekor'),
                    key: ValueKey(layout.dir),
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
              placed(
                'logo',
                Semantics(
                  label: 'Dijigoo',
                  image: true,
                  child: Image.asset(
                    'assets/login/d-ikonu.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
              placed(
                'slogan',
                FittedBox(
                  child: LoginSlogan(
                    lead: l.sloganLead,
                    accent: l.sloganAccent,
                  ),
                ),
              ),
              placed('roller', _roleTabs(l, layout, s)),
              placed(
                'kimlik',
                smsMode
                    ? SurfaceField(
                        key: const Key('sms-phone'),
                        surface: layout.asset('kimlik'),
                        scale: s,
                        icon: 'telefon',
                        controller: _phone,
                        hint: l.phoneHint,
                        keyboardType: TextInputType.phone,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        inputFormatters: const [
                          SmartIdentifierFormatter(phoneOnly: true),
                        ],
                        textInputAction: TextInputAction.done,
                        onChanged: (_) => setState(() {}),
                      )
                    : SurfaceField(
                        key: Key(_branch ? 'sube-email' : 'panel-identifier'),
                        surface: layout.asset('kimlik'),
                        scale: s,
                        icon: kind == IdentifierKind.email
                            ? 'kullanici'
                            : 'telefon',
                        controller: _identifier,
                        hint: l.phoneOrEmail,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email,
                        ],
                        inputFormatters: const [SmartIdentifierFormatter()],
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() {}),
                      ),
              ),
              placed(
                'sifre',
                SurfaceField(
                  key: Key(
                    smsMode
                        ? 'sms-info'
                        : (_branch ? 'sube-password' : 'panel-password'),
                  ),
                  surface: layout.asset('sifre'),
                  scale: s,
                  icon: smsMode ? 'kilit' : 'kilit',
                  controller: _password,
                  hint: l.password,
                  obscure: _obscurePassword,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  readOnlyText: smsMode ? l.smsSentGeneric : null,
                  onSubmitted: (_) => _submit(l, session),
                  trailing: smsMode
                      ? null
                      : PasswordEye(
                          visible: !_obscurePassword,
                          label: l.password,
                          onTap: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                ),
              ),
              placed(
                'sms',
                SurfaceTile(
                  key: const Key('login-method-sms'),
                  surface: layout.asset('sms'),
                  scale: s,
                  icon: 'sms',
                  label: l.loginSmsMethod,
                  selected: smsMode,
                  onTap: () => _toggleSms(l),
                ),
              ),
              placed(
                'biyometri',
                SurfaceTile(
                  key: const Key('login-method-biometric'),
                  surface: layout.asset('biyometri'),
                  scale: s,
                  icon: 'biyometrik-tarama',
                  iconHeight: 36,
                  label: l.loginBiometricMethod,
                  onTap: () => _toast(l.loginMethodSoon),
                ),
              ),
              placed(
                'qr',
                SurfaceTile(
                  key: const Key('login-method-qr'),
                  surface: layout.asset('qr'),
                  scale: s,
                  icon: 'qr',
                  label: l.loginQrMethod,
                  onTap: () => _toast(l.loginMethodSoon),
                ),
              ),
              // Onay kutusu + "Beni hatırla" (etiket kutunun sağında).
              Positioned(
                left: layout.rects['hatirla']![0] * s - 10,
                top: layout.rects['hatirla']![1] * s - 10,
                height: layout.rects['hatirla']![3] * s + 20,
                width: 260 * s,
                child: _RememberBox(
                  value: _remember,
                  size: layout.rects['hatirla']![3] * s,
                  label: l.rememberMeShort,
                  fontSize: (20 * s).clamp(13.0, 18.0),
                  onChanged: (v) => setState(() => _remember = v),
                ),
              ),
              placed(
                'unutulan-sifre',
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    key: smsMode ? const Key('login-method-password') : null,
                    behavior: HitTestBehavior.opaque,
                    onTap: smsMode
                        ? () => _toggleSms(l)
                        : () => _toast(l.supportHint),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        smsMode ? l.usePasswordInstead : l.forgotPasswordShort,
                        style: LoginInk.style(
                          size: (20 * s).clamp(13.0, 18.0),
                          color: LoginInk.lavender,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              placed('giris', _submitButton(l, session, height: 70 * s)),
              placed(
                'alt-bilgi',
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: error == null
                      ? LoginSecureFooter(
                          key: const ValueKey('secure'),
                          label: l.secureLogin,
                        )
                      : _error == l.waitToResend && !_branch
                      ? _Countdown(
                          until: session.smsRetryAt,
                          builder: (left) => _InlineError(
                            left > 0 ? l.waitToResendIn(left) : l.waitToResend,
                          ),
                        )
                      : _InlineError(error, key: ValueKey(error)),
                ),
              ),
            ],
          ),
        );
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.pushed)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(
                        LucideIcons.arrowLeft,
                        color: LoginInk.text,
                      ),
                    ),
                  ),
                stack,
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        l.noAccount,
                        style: LoginInk.style(size: 13, color: LoginInk.muted),
                      ),
                      TextButton(
                        key: const Key('join-link'),
                        onPressed: _branch
                            ? () => _toast(l.supportHint)
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const JoinScreen(),
                                ),
                              ),
                        child: Text(
                          l.getSupport,
                          style: LoginInk.style(
                            size: 13,
                            weight: FontWeight.w600,
                            color: LoginInk.lavender,
                          ),
                        ),
                      ),
                      Text(
                        '· ${l.fieldAppVersion}',
                        style: LoginInk.style(
                          size: 12,
                          weight: FontWeight.w400,
                          color: LoginInk.muted.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Rol sekmesi: seçili sekmenin arka planı `roller.png` içinde.
  Widget _roleTabs(L10n l, LoginLayout layout, double s) {
    Widget tab(int i, String label, Key key) {
      final selected = (_branch ? 0 : 1) == i;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          inMutuallyExclusiveGroup: true,
          child: GestureDetector(
            key: key,
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              _switchRole(i == 0 ? LoginRole.branch : LoginRole.courier);
            },
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: LoginInk.style(
                    size: (22 * s).clamp(14.0, 20.0),
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: l.roleLabel,
      container: true,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            layout.asset('roller'),
            fit: BoxFit.fill,
            gaplessPlayback: true,
            excludeFromSemantics: true,
          ),
          Row(
            children: [
              tab(0, l.loginRoleBranch, const Key('role-branch')),
              tab(1, l.loginRoleCourier, const Key('role-courier')),
            ],
          ),
          // Testler ve eski "Şube girişi" bağlantısı için sabit anahtar.
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 1,
            child: GestureDetector(
              key: const Key('sube-login-link'),
              behavior: HitTestBehavior.translucent,
              onTap: () => _switchRole(LoginRole.branch),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleSms(L10n l) {
    if (_branch) {
      _toast(l.loginSmsPartnerOff);
      return;
    }
    setState(() {
      if (_panelMode) {
        if (_phone.text.isEmpty &&
            identifierKind(_identifier.text) == IdentifierKind.phone) {
          _phone.text = formatTrPhone(_identifier.text);
        }
        _panelMode = false;
      } else {
        if (_identifier.text.isEmpty && _phone.text.isNotEmpty) {
          _identifier.text = _phone.text;
        }
        _panelMode = true;
        _sent = false;
      }
      _skipStoredPanel = true;
      _error = null;
    });
  }

  void _submit(L10n l, SessionController session) {
    if (_branch) {
      if (!session.agencyLoginBusy) _loginBranch();
    } else if (_panelMode) {
      if (!_panelBusy) _loginPanel(l);
    } else {
      if (!session.activationBusy) _sendSms(l);
    }
  }

  /// 409 AGENCY_SELECTION_REQUIRED: iş ortağı seçimi alttan açılan listede.
  Future<void> _pickAgency(L10n l) async {
    final session = ref.read(sessionProvider);
    final picked = await showModalBottomSheet<AgencyDto>(
      context: context,
      backgroundColor: const Color(0xFF0B1235),
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text(
              l.subeSelectAgency,
              style: LoginInk.style(size: 17, weight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            for (final option in session.agencySelectionOptions)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AgencyOption(
                  name: option.name,
                  selected: _pickedAgency?.id == option.id,
                  onTap: () => Navigator.of(context).pop(option),
                ),
              ),
          ],
        ),
      ),
    );
    if (!mounted || picked == null) return;
    setState(() => _pickedAgency = picked);
    await _loginBranch();
  }

  /// Normal giriş formu teslimdeki dekorla çizilir; SMS doğrulama ve
  /// kayıtlı oturum kartı esnek cam kartla.
  bool _usesDecor(SessionController session, bool storedPanel) =>
      !storedPanel && !(_sent && !_branch);

  Widget _maybeBackdrop(bool decor, {required Widget child}) =>
      decor ? child : LoginBackdrop(child: child);

  Widget _page(L10n l, SessionController session, bool storedPanel) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - 28).clamp(0.0, double.infinity),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.pushed)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          LucideIcons.arrowLeft,
                          color: LoginInk.text,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 20),
                  Appear(
                    child: LoginBrand(
                      lead: l.sloganLead,
                      accent: l.sloganAccent,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Appear(
                    delay: const Duration(milliseconds: 90),
                    slide: 0.02,
                    child: GlassFrame(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: storedPanel
                            ? _storedPanelCard(l)
                            : _form(l, session),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        l.noAccount,
                        style: LoginInk.style(size: 14, color: LoginInk.muted),
                      ),
                      TextButton(
                        key: const Key('join-link'),
                        onPressed: _branch
                            ? () => _toast(l.supportHint)
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const JoinScreen(),
                                ),
                              ),
                        child: Text(
                          l.getSupport,
                          style: LoginInk.style(
                            size: 14,
                            weight: FontWeight.w600,
                            color: LoginInk.lavender,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    l.fieldAppVersion,
                    style: LoginInk.style(
                      size: 12,
                      weight: FontWeight.w400,
                      color: LoginInk.muted.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 110),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(L10n l, SessionController session) {
    final needsSelection =
        _branch &&
        session.lastAgencyError == 'AGENCY_SELECTION_REQUIRED' &&
        session.agencySelectionOptions.isNotEmpty;
    final kind = identifierKind(_identifier.text);
    final smsMode = !_branch && !_panelMode;
    return Column(
      key: ValueKey('form-$_role'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            LoginRoleSwitch(
              semanticLabel: l.roleLabel,
              labels: [l.loginRoleBranch, l.loginRoleCourier],
              keys: const [Key('role-branch'), Key('role-courier')],
              selected: _branch ? 0 : 1,
              onChanged: (i) =>
                  _switchRole(i == 0 ? LoginRole.branch : LoginRole.courier),
            ),
            // İş Ortağı sekmesinin üstünde sabit anahtarlı dokunma alanı
            // (testler ve eski "Şube girişi" bağlantısı için).
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 1,
              child: GestureDetector(
                key: const Key('sube-login-link'),
                behavior: HitTestBehavior.translucent,
                onTap: () => _switchRole(LoginRole.branch),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        if (needsSelection)
          ..._agencyPicker(l, session)
        else if (smsMode)
          LoginField(
            key: const Key('sms-phone'),
            controller: _phone,
            icon: 'telefon',
            hint: l.phoneHint,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            inputFormatters: const [SmartIdentifierFormatter(phoneOnly: true)],
            onChanged: (_) => setState(() {}),
          )
        else ...[
          LoginField(
            key: Key(_branch ? 'sube-email' : 'panel-identifier'),
            controller: _identifier,
            icon: kind == IdentifierKind.phone ? 'telefon' : 'kullanici',
            hint: l.phoneOrEmail,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            inputFormatters: const [SmartIdentifierFormatter()],
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          LoginField(
            key: Key(_branch ? 'sube-password' : 'panel-password'),
            controller: _password,
            icon: 'kilit',
            hint: l.password,
            obscure: _obscurePassword,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            trailing: PasswordEye(
              visible: !_obscurePassword,
              label: l.password,
              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ],
        if (!needsSelection) ...[
          const SizedBox(height: 22),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: LoginMethodTile(
                    key: const Key('login-method-sms'),
                    icon: 'sms',
                    label: l.loginSmsMethod,
                    selected: smsMode,
                    onTap: () {
                      if (_branch) {
                        _toast(l.loginSmsPartnerOff);
                        return;
                      }
                      setState(() {
                        if (_panelMode) {
                          // Yazılan telefon SMS alanına taşınır.
                          if (_phone.text.isEmpty &&
                              identifierKind(_identifier.text) ==
                                  IdentifierKind.phone) {
                            _phone.text = formatTrPhone(_identifier.text);
                          }
                          _panelMode = false;
                        } else {
                          if (_identifier.text.isEmpty &&
                              _phone.text.isNotEmpty) {
                            _identifier.text = _phone.text;
                          }
                          _panelMode = true;
                        }
                        _skipStoredPanel = true;
                        _error = null;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LoginMethodTile(
                    key: const Key('login-method-biometric'),
                    icon: 'biyometrik-tarama',
                    iconHeight: 28,
                    label: l.loginBiometricMethod,
                    onTap: () => _toast(l.loginMethodSoon),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LoginMethodTile(
                    key: const Key('login-method-qr'),
                    icon: 'qr',
                    label: l.loginQrMethod,
                    onTap: () => _toast(l.loginMethodSoon),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              LoginCheck(
                value: _remember,
                onChanged: (v) => setState(() => _remember = v),
                label: l.rememberMeShort,
              ),
              if (smsMode)
                TextButton(
                  key: const Key('login-method-password'),
                  onPressed: () => setState(() {
                    if (_identifier.text.isEmpty && _phone.text.isNotEmpty) {
                      _identifier.text = _phone.text;
                    }
                    _panelMode = true;
                    _sent = false;
                    _skipStoredPanel = true;
                    _error = null;
                  }),
                  child: Text(
                    l.usePasswordInstead,
                    style: LoginInk.style(size: 15, color: LoginInk.lavender),
                  ),
                )
              else
                TextButton(
                  onPressed: () => _toast(l.supportHint),
                  child: Text(
                    l.forgotPasswordShort,
                    style: LoginInk.style(size: 15, color: LoginInk.lavender),
                  ),
                ),
            ],
          ),
          if (_branch &&
              session.lastAgencyError != null &&
              session.lastAgencyError != 'AGENCY_SELECTION_REQUIRED')
            _ErrorText(
              l.loginError(
                session.lastAgencyError,
                remainingAttempts: session.loginRemainingAttempts,
                lockedUntil: session.loginLockedUntil,
                fallback: l.subeLoginFailed,
              ),
            ),
          if (!_branch && _error != null)
            _error == l.waitToResend
                ? _Countdown(
                    until: session.smsRetryAt,
                    builder: (left) => _ErrorText(
                      left > 0 ? l.waitToResendIn(left) : l.waitToResend,
                    ),
                  )
                : _ErrorText(_error!),
          const SizedBox(height: 14),
          _submitButton(l, session),
          const SizedBox(height: 22),
          LoginSecureFooter(label: l.secureLogin),
        ],
      ],
    );
  }

  Widget _submitButton(
    L10n l,
    SessionController session, {
    double height = 58,
  }) {
    if (_branch) {
      final needsSelection =
          session.lastAgencyError == 'AGENCY_SELECTION_REQUIRED' &&
          session.agencySelectionOptions.isNotEmpty;
      return LoginCta(
        key: const Key('sube-login'),
        height: height,
        label: l.loginSignIn,
        busy: session.agencyLoginBusy,
        onPressed:
            session.agencyLoginBusy || (needsSelection && _pickedAgency == null)
            ? null
            : _loginBranch,
      );
    }
    final busy = _panelMode ? _panelBusy : session.activationBusy;
    Widget button({bool waiting = false}) => LoginCta(
      key: Key(_panelMode ? 'panel-login' : 'sms-login'),
      height: height,
      label: _panelMode ? l.loginSignIn : l.sendCodeCta,
      busy: busy,
      onPressed: busy || waiting
          ? null
          : () => _panelMode ? _loginPanel(l) : _sendSms(l),
    );
    if (_panelMode) return button();
    // Sunucu yeni kodu bir süre vermez (429): düğme o süre kilitli kalır.
    return _Countdown(
      until: session.smsRetryAt,
      builder: (left) => button(waiting: left > 0),
    );
  }

  List<Widget> _agencyPicker(L10n l, SessionController session) => [
    Text(
      l.subeSelectAgency,
      style: LoginInk.style(size: 16, weight: FontWeight.w600),
    ),
    const SizedBox(height: 12),
    for (final option in session.agencySelectionOptions)
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _AgencyOption(
          name: option.name,
          selected: _pickedAgency?.id == option.id,
          onTap: () => setState(() => _pickedAgency = option),
        ),
      ),
    const SizedBox(height: 8),
    _submitButton(l, session),
  ];

  Widget _storedPanelCard(L10n l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.panelSessionOn,
          key: const Key('panel-session-ready'),
          textAlign: TextAlign.center,
          style: LoginInk.style(size: 19, weight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          l.panelReadyHint,
          textAlign: TextAlign.center,
          style: LoginInk.style(
            size: 15,
            weight: FontWeight.w400,
            color: LoginInk.muted,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        LoginCta(
          key: const Key('panel-continue'),
          label: l.goToPermissions,
          onPressed: () => ref.read(sessionProvider).completeActivation(),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => setState(() {
            _panelMode = true;
            _skipStoredPanel = true;
            _error = null;
          }),
          child: Text(l.otherAccount, style: LoginInk.style(size: 15)),
        ),
        TextButton(
          onPressed: () => setState(() {
            _skipStoredPanel = true;
            _panelMode = false;
            _sent = false;
            _error = null;
          }),
          child: Text(
            l.smsLogin,
            style: LoginInk.style(size: 15, color: LoginInk.muted),
          ),
        ),
      ],
    );
  }

  /// SMS doğrulama: 6 kutu, geri sayım, ekran tuş takımı.
  Widget _smsVerify(L10n l, SessionController session) {
    final masked = session.otpMaskedPhone;
    final hasMask = masked != null && masked.isNotEmpty;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      key: const Key('sms-back'),
                      onPressed: () => setState(() {
                        _sent = false;
                        _code = '';
                        _error = null;
                      }),
                      icon: const Icon(
                        LucideIcons.arrowLeft,
                        color: LoginInk.text,
                      ),
                    ),
                  ),
                  const LoginIcon('sms', height: 44),
                  const SizedBox(height: 16),
                  Text(
                    l.smsVerifyTitle,
                    style: LoginInk.style(size: 22, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  if (hasMask)
                    Text(
                      masked,
                      style: LoginInk.style(size: 18, weight: FontWeight.w700),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    hasMask ? l.smsSentTo('').trim() : l.smsSentGeneric,
                    textAlign: TextAlign.center,
                    style: LoginInk.style(
                      size: 14,
                      weight: FontWeight.w400,
                      color: LoginInk.muted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _CodeBoxes(value: _code, error: _codeError != null),
                  if (_error != null) _ErrorText(_error!),
                  const SizedBox(height: 12),
                  _ResendCountdown(
                    until: session.otpResendAt,
                    busy: session.activationBusy,
                    label: l.resendNow,
                    onResend: () async {
                      setState(() => _error = null);
                      final ok = await ref
                          .read(sessionProvider)
                          .requestActivationCode(
                            normalizeIdentifier(_phone.text),
                          );
                      if (!mounted) return;
                      if (!ok) {
                        setState(
                          () => _error = _activationError(
                            l,
                            ref.read(sessionProvider),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_verifying)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: LoginInk.turkuaz,
                        ),
                      ),
                    ),
                  _Keypad(
                    onDigit: (d) => _typeDigit(l, d),
                    onBackspace: () => setState(() {
                      if (_code.isNotEmpty) {
                        _code = _code.substring(0, _code.length - 1);
                      }
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        maxLines: 2,
        textAlign: TextAlign.center,
        style: LoginInk.style(size: 14, color: LoginInk.error),
      ),
    ),
  );
}

class _RememberBox extends StatelessWidget {
  const _RememberBox({
    required this.value,
    required this.size,
    required this.label,
    required this.fontSize,
    required this.onChanged,
  });

  final bool value;
  final double size;
  final String label;
  final double fontSize;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: value,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: value ? LoginInk.turkuaz : Colors.transparent,
                  borderRadius: BorderRadius.circular(size * 0.22),
                  border: Border.all(
                    color: value
                        ? LoginInk.turkuaz
                        : LoginInk.text.withValues(alpha: 0.75),
                    width: 1.4,
                  ),
                ),
                child: value ? CustomPaint(painter: _CheckPainter()) : null,
              ),
              SizedBox(width: size * 0.55),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label, style: LoginInk.style(size: fontSize)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// İkon fontuna bağlı kalmadan tik işareti.
class _CheckPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = LoginInk.ground
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.24, size.height * 0.52)
        ..lineTo(size.width * 0.43, size.height * 0.70)
        ..lineTo(size.width * 0.77, size.height * 0.32),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: LoginInk.style(size: 14, color: LoginInk.error, height: 1.35),
    ),
  );
}

/// Koyu cam kutularda 6 haneli kod (yalnız gösterim; giriş ekran tuşlarıyla).
class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({required this.value, required this.error});

  final String value;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${value.length}/6',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 6; i++)
            Flexible(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(maxWidth: 50),
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: LoginInk.field,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: error
                        ? LoginInk.error
                        : i == value.length
                        ? LoginInk.turkuaz
                        : LoginInk.fieldLine,
                    width: i == value.length && !error ? 1.5 : 1.1,
                  ),
                  boxShadow: i == value.length && !error
                      ? [
                          BoxShadow(
                            color: LoginInk.turkuaz.withValues(alpha: 0.2),
                            blurRadius: 12,
                          ),
                        ]
                      : const [],
                ),
                child: Text(
                  i < value.length ? value[i] : '',
                  style: LoginInk.style(size: 24, weight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ekran tuş takımı (koyu).
class _Keypad extends StatelessWidget {
  const _Keypad({required this.onDigit, required this.onBackspace});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {VoidCallback? onTap, Widget? child}) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Material(
          color: onTap == null ? Colors.transparent : LoginInk.field,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onTap();
                  },
            child: SizedBox(
              height: 58,
              child: Center(
                child:
                    child ??
                    Text(
                      label,
                      style: LoginInk.style(size: 24, weight: FontWeight.w600),
                    ),
              ),
            ),
          ),
        ),
      ),
    );
    Widget row(List<String> ds) =>
        Row(children: [for (final d in ds) key(d, onTap: () => onDigit(d))]);
    return Column(
      children: [
        row(['1', '2', '3']),
        row(['4', '5', '6']),
        row(['7', '8', '9']),
        Row(
          children: [
            key(''),
            key('0', onTap: () => onDigit('0')),
            key(
              '',
              onTap: onBackspace,
              child: Semantics(
                label: MaterialLocalizations.of(context).deleteButtonTooltip,
                child: const Icon(
                  LucideIcons.delete,
                  size: 22,
                  color: LoginInk.text,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AgencyOption extends StatelessWidget {
  const _AgencyOption({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: LoginInk.field,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected
                  ? LoginInk.turkuaz.withValues(alpha: 0.85)
                  : LoginInk.fieldLine,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? LucideIcons.circleCheck : LucideIcons.circle,
                size: 20,
                color: selected ? LoginInk.turkuaz : LoginInk.muted,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(name, style: LoginInk.style(size: 16))),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Kodu tekrar gönder" + kalan süre; süre dolunca dokunulabilir. Yalnız bu
/// küçük parça saniyede bir yenilenir; süre bitince zamanlayıcı durur.
/// [until] anına kalan saniyeyle her saniye yeniden çizer; süre dolunca
/// durur (boşta çalışan sayaç bırakmaz).
class _Countdown extends StatefulWidget {
  const _Countdown({required this.until, required this.builder});

  final DateTime? until;
  final Widget Function(int secondsLeft) builder;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  Timer? _timer;

  int get _left {
    final until = widget.until;
    if (until == null) return 0;
    final ms = until.difference(DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  void _start() {
    _timer?.cancel();
    _timer = null;
    if (_left == 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_left == 0) {
        _timer?.cancel();
        _timer = null;
      }
      setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(_Countdown old) {
    super.didUpdateWidget(old);
    if (widget.until != old.until) _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_left);
}

class _ResendCountdown extends StatefulWidget {
  const _ResendCountdown({
    required this.until,
    required this.busy,
    required this.label,
    required this.onResend,
  });

  final DateTime? until;
  final bool busy;
  final String label;
  final Future<void> Function() onResend;

  @override
  State<_ResendCountdown> createState() => _ResendCountdownState();
}

class _ResendCountdownState extends State<_ResendCountdown> {
  Timer? _timer;

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final until = widget.until;
      if (until == null || DateTime.now().isAfter(until)) {
        _timer?.cancel();
        _timer = null;
      }
      setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(_ResendCountdown old) {
    super.didUpdateWidget(old);
    if (widget.until != old.until) _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final until = widget.until;
    final left = until == null
        ? Duration.zero
        : until.difference(DateTime.now());
    final waiting = left > Duration.zero;
    String two(int n) => n.toString().padLeft(2, '0');
    return Column(
      children: [
        if (waiting)
          Text(
            '${two(left.inMinutes)}:${two(left.inSeconds % 60)}',
            style: LoginInk.style(
              size: 16,
              weight: FontWeight.w600,
              color: LoginInk.lavender,
            ),
          ),
        TextButton(
          key: const Key('sms-resend'),
          onPressed: waiting || widget.busy ? null : widget.onResend,
          child: Text(
            widget.label,
            style: LoginInk.style(
              size: 15,
              weight: FontWeight.w600,
              color: waiting
                  ? LoginInk.muted.withValues(alpha: 0.5)
                  : LoginInk.lavender,
            ),
          ),
        ),
      ],
    );
  }
}
