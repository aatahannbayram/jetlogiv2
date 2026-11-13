import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../login_kit.dart';
import '../motion.dart';
import '../privacy.dart';
import '../session.dart';
import 'join_screens.dart';

/// Giriş türü. Mobilde rol seçimi formun üstündedir (teslim v1.1).
enum LoginRole { partner, courier }

/// Ortak giriş ekranı: İş Ortağı (şube/acente) ve Kurye.
///
/// Görünüm `Dijigoo-Panel-App-Yazilim-Teslimi-v1.1` onaylı ekranlarından:
/// D ikonu + slogan, köşeleri kırık cam kart, rol sekmesi, ikonlu alanlar,
/// SMS / Biyometrik / QR kutuları, ortak degrade "Giriş yap" butonu.
/// Kimlik doğrulama mantığı [SessionController] içinde, değişmedi.
class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key, this.initialRole = LoginRole.courier});

  final LoginRole initialRole;

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  // Kurye
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _password = TextEditingController();
  // İş Ortağı
  final _email = TextEditingController();
  final _agencyPassword = TextEditingController();

  late LoginRole _role = widget.initialRole;
  bool _smsMode = false;
  bool _sent = false;
  bool _remember = true;
  bool _panelBusy = false;
  bool _obscure = true;
  bool _skipStoredPanel = false;
  String? _error;
  String? _pickedAgencyId;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    _password.dispose();
    _email.dispose();
    _agencyPassword.dispose();
    super.dispose();
  }

  /// Telefon alanı "+90" önekiyle gösterilir; sunucu `5XX…` ve `+905XX…`
  /// biçimlerini eşleştirir. E-posta yapıştırılırsa olduğu gibi gider.
  String get _courierIdentifier => _normalizeIdentifier(_phone.text);

  /// Telefon ya da e-posta. Telefon `+905XXXXXXXXX` biçimine çevrilir.
  static String _normalizeIdentifier(String input) {
    final raw = input.trim();
    if (raw.contains('@')) return raw;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10 && digits.startsWith('5')) return '+90$digits';
    if (digits.length == 11 && digits.startsWith('05')) {
      return '+90${digits.substring(1)}';
    }
    return raw;
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

  void _setRole(LoginRole role) {
    setState(() {
      _role = role;
      _error = null;
      _smsMode = false;
      _sent = false;
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendSms(L10n l) async {
    setState(() => _error = null);
    final ok = await ref
        .read(sessionProvider)
        .requestActivationCode(_courierIdentifier);
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = _activationError(l, ref.read(sessionProvider)));
      return;
    }
    setState(() => _sent = true);
  }

  Future<void> _loginCourier(L10n l) async {
    setState(() {
      _panelBusy = true;
      _error = null;
    });
    final ok = await ref
        .read(sessionProvider)
        .loginWithPanel(
          identifier: _courierIdentifier,
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

  Future<void> _loginPartner() async {
    setState(() => _error = null);
    final s = ref.read(sessionProvider);
    final ok = await s.loginAsAgency(
      email: _normalizeIdentifier(_email.text),
      password: _agencyPassword.text,
      agencyId: _pickedAgencyId,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = ref.watch(sessionProvider);
    final storedPanel =
        _role == LoginRole.courier &&
        session.panelLoggedIn &&
        !_sent &&
        !_skipStoredPanel;
    final canPop = Navigator.of(context).canPop();

    return PrivacyGate(
      active: true,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: LoginInk.ground,
          body: LoginBackdrop(
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (constraints.maxHeight - 28).clamp(
                          0.0,
                          double.infinity,
                        ),
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (canPop)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: IconButton(
                                    tooltip: MaterialLocalizations.of(context)
                                        .backButtonTooltip,
                                    onPressed: () =>
                                        Navigator.of(context).maybePop(),
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
                                        : _sent
                                        ? _otpCard(l, session)
                                        : _form(l, session),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              if (_role == LoginRole.courier)
                                TextButton(
                                  key: const Key('join-link'),
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => JoinScreen(),
                                    ),
                                  ),
                                  child: Text(
                                    l.joinTitle,
                                    style: LoginInk.style(
                                      size: 15,
                                      weight: FontWeight.w600,
                                      color: LoginInk.muted,
                                    ),
                                  ),
                                ),
                              Text(
                                l.fieldAppVersion,
                                style: LoginInk.style(
                                  size: 13,
                                  weight: FontWeight.w400,
                                  color: LoginInk.muted.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 120),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(L10n l, SessionController s) {
    final partner = _role == LoginRole.partner;
    final needsSelection =
        partner &&
        s.lastAgencyError == 'AGENCY_SELECTION_REQUIRED' &&
        s.agencySelectionOptions.isNotEmpty;
    final busy = partner
        ? s.agencyLoginBusy
        : (_smsMode ? s.activationBusy : _panelBusy);
    final error = partner ? _partnerError(l, s) : _error;

    return Column(
      key: ValueKey('form-$_role'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LoginRoleSwitch(
          semanticLabel: l.roleLabel,
          labels: [l.rolePartner, l.roleCourier],
          keys: const [Key('role-partner'), Key('role-courier')],
          selected: partner ? 0 : 1,
          onChanged: (i) =>
              _setRole(i == 0 ? LoginRole.partner : LoginRole.courier),
        ),
        const SizedBox(height: 22),
        if (needsSelection)
          ..._agencyPicker(l, s)
        else if (partner) ...[
          LoginField(
            key: const Key('sube-email'),
            controller: _email,
            icon: 'telefon',
            prefixText: '+90',
            hint: l.phoneOrEmail,
            keyboardType: TextInputType.text,
            autofillHints: const [
              AutofillHints.telephoneNumberNational,
              AutofillHints.email,
            ],
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          LoginField(
            key: const Key('sube-password'),
            controller: _agencyPassword,
            icon: 'kilit',
            hint: l.password,
            obscure: _obscure,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => busy ? null : _loginPartner(),
            trailing: _eye(l),
          ),
        ] else ...[
          LoginField(
            key: const Key('panel-identifier'),
            controller: _phone,
            icon: 'telefon',
            prefixText: '+90',
            hint: l.phoneNumber,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            textInputAction: _smsMode
                ? TextInputAction.done
                : TextInputAction.next,
          ),
          if (!_smsMode) ...[
            const SizedBox(height: 16),
            LoginField(
              key: const Key('panel-password'),
              controller: _password,
              icon: 'kilit',
              hint: l.password,
              obscure: _obscure,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => busy ? null : _loginCourier(l),
              trailing: _eye(l),
            ),
          ],
        ],
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
                  selected: _smsMode,
                  onTap: () {
                    if (partner) {
                      _toast(l.loginSmsPartnerOff);
                      return;
                    }
                    setState(() {
                      _smsMode = !_smsMode;
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
            if (_smsMode && !partner)
              TextButton(
                key: const Key('login-method-password'),
                onPressed: () => setState(() {
                  _smsMode = false;
                  _error = null;
                }),
                child: Text(
                  l.usePasswordInstead,
                  style: LoginInk.style(
                    size: 15,
                    weight: FontWeight.w500,
                    color: LoginInk.lavender,
                  ),
                ),
              )
            else
              TextButton(
                onPressed: () => _toast(l.supportHint),
                child: Text(
                  l.forgotPasswordShort,
                  style: LoginInk.style(
                    size: 15,
                    weight: FontWeight.w500,
                    color: LoginInk.lavender,
                  ),
                ),
              ),
          ],
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: error == null
              ? const SizedBox(height: 10)
              : Padding(
                  key: ValueKey(error),
                  padding: const EdgeInsets.only(top: 2, bottom: 12),
                  child: Text(
                    error,
                    style: LoginInk.style(
                      size: 14,
                      weight: FontWeight.w500,
                      color: LoginInk.error,
                      height: 1.35,
                    ),
                  ),
                ),
        ),
        LoginCta(
          key: partner
              ? const Key('sube-login')
              : (_smsMode ? const Key('sms-login') : const Key('panel-login')),
          label: _smsMode && !partner ? l.sendCodeCta : l.loginSignIn,
          busy: busy,
          onPressed: busy || (needsSelection && _pickedAgencyId == null)
              ? null
              : () {
                  if (partner) {
                    _loginPartner();
                  } else if (_smsMode) {
                    _sendSms(l);
                  } else {
                    _loginCourier(l);
                  }
                },
        ),
        const SizedBox(height: 22),
        LoginSecureFooter(label: l.secureLogin),
      ],
    );
  }

  String? _partnerError(L10n l, SessionController s) {
    final code = s.lastAgencyError;
    if (code == null || code == 'AGENCY_SELECTION_REQUIRED') return null;
    return l.loginError(
      code,
      remainingAttempts: s.loginRemainingAttempts,
      lockedUntil: s.loginLockedUntil,
      fallback: l.subeLoginFailed,
    );
  }

  Widget _eye(L10n l) => PasswordEye(
    visible: !_obscure,
    label: l.password,
    onTap: () => setState(() => _obscure = !_obscure),
  );

  List<Widget> _agencyPicker(L10n l, SessionController s) {
    return [
      Text(
        l.subeSelectAgency,
        style: LoginInk.style(size: 16, weight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      for (final option in s.agencySelectionOptions)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _AgencyOption(
            name: option.name,
            selected: _pickedAgencyId == option.id,
            onTap: () => setState(() => _pickedAgencyId = option.id),
          ),
        ),
    ];
  }

  Widget _storedPanelCard(L10n l) {
    return Column(
      key: const ValueKey('stored'),
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
            _smsMode = false;
            _skipStoredPanel = true;
            _error = null;
          }),
          child: Text(l.otherAccount, style: LoginInk.style(size: 15)),
        ),
        TextButton(
          onPressed: () => setState(() {
            _smsMode = true;
            _skipStoredPanel = true;
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

  Widget _otpCard(L10n l, SessionController session) {
    final resendLocked =
        session.activationBusy ||
        (session.otpResendAt != null &&
            DateTime.now().isBefore(session.otpResendAt!));
    return Column(
      key: const ValueKey('otp'),
      children: [
        const LoginIcon('sms', height: 34),
        const SizedBox(height: 14),
        Text(
          l.askFourDigit,
          textAlign: TextAlign.center,
          style: LoginInk.style(size: 18, weight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          l.codeNotDelivery,
          textAlign: TextAlign.center,
          style: LoginInk.style(
            size: 14,
            weight: FontWeight.w400,
            color: LoginInk.muted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        LoginPin(controller: _otp, error: _error != null),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: LoginInk.style(size: 14, color: LoginInk.error),
            ),
          ),
        const SizedBox(height: 22),
        LoginCta(
          key: const Key('otp-verify'),
          label: l.verifyCode,
          onPressed: () async {
            final ok = await ref
                .read(sessionProvider)
                .verifyLoginOtp(_otp.text.trim());
            if (!mounted) return;
            if (!ok) {
              setState(
                () => _error = _activationError(
                  l,
                  ref.read(sessionProvider),
                  verify: true,
                ),
              );
              return;
            }
            ref.read(sessionProvider).completeActivation();
          },
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: resendLocked
              ? null
              : () async {
                  setState(() => _error = null);
                  final ok = await ref
                      .read(sessionProvider)
                      .requestActivationCode(_courierIdentifier);
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
          child: Text(
            l.resendCode,
            style: LoginInk.style(
              size: 15,
              color: resendLocked
                  ? LoginInk.muted.withValues(alpha: 0.5)
                  : LoginInk.lavender,
            ),
          ),
        ),
        TextButton(
          onPressed: () => setState(() {
            _sent = false;
            _otp.clear();
            _error = null;
          }),
          child: Text(
            l.usePasswordInstead,
            style: LoginInk.style(size: 15, color: LoginInk.muted),
          ),
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
                selected ? LucideIcons.checkCircle2 : LucideIcons.circle,
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
