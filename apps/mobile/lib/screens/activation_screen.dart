import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/agency_models.dart';
import '../brand.dart';
import '../l10n.dart';
import '../login_identifier.dart';
import '../motion.dart';
import '../privacy.dart';
import '../session.dart';
import '../theme.dart';
import '../ui/ui.dart';
import 'join_screens.dart';

enum LoginRole { courier, branch }

/// Giriş (mockup 02–03): tek ekranda Şube / Kurye seçimi, akıllı kimlik
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

  InputDecoration _field({
    required String hint,
    String? label,
    Widget? prefix,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Dg.surface1,
      labelText: label,
      labelStyle: Dg.ui(size: 14, color: Dg.text3),
      floatingLabelStyle: Dg.ui(size: 14, color: Dg.highlight),
      hintText: hint,
      hintStyle: Dg.ui(size: 16, color: Dg.text3),
      prefixIcon: prefix,
      prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      suffixIcon: suffix,
      // Çerçevesiz dolgulu alan; odakta ince vurgu.
      border: border(Colors.transparent),
      enabledBorder: border(Colors.transparent),
      focusedBorder: border(Dg.highlight, 1.4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    );
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
      _error = null;
    });
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
      email: _identifier.text.trim(),
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
  }

  Future<void> _verify(L10n l) async {
    if (_verifying) return;
    setState(() => _verifying = true);
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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = ref.watch(sessionProvider);
    final storedPanel =
        !_branch && session.panelLoggedIn && !_sent && !_skipStoredPanel;
    return PrivacyGate(
      active: true,
      child: Scaffold(
        backgroundColor: Dg.bg,
        body: SafeArea(
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
                    child: _form(l, session, storedPanel),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _form(L10n l, SessionController session, bool storedPanel) {
    final needsSelection =
        _branch &&
        session.lastAgencyError == 'AGENCY_SELECTION_REQUIRED' &&
        session.agencySelectionOptions.isNotEmpty;
    final kind = identifierKind(_identifier.text);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.pushed)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(LucideIcons.arrowLeft, color: Dg.text1),
                  ),
                ),
              const SizedBox(height: 8),
              const Appear(child: DijigooMark(size: 72)),
              const SizedBox(height: 22),
              Appear(
                delay: const Duration(milliseconds: 60),
                child: Stack(
                  children: [
                    DgPillTabs(
                      labels: [l.loginRoleBranch, l.loginRoleCourier],
                      index: _branch ? 0 : 1,
                      onChanged: (i) => _switchRole(
                        i == 0 ? LoginRole.branch : LoginRole.courier,
                      ),
                    ),
                    // Şube sekmesinin üstünde sabit anahtarlı dokunma alanı
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
              ),
              if (_branch)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    l.subeLoginTitle,
                    style: Dg.ui(
                      size: 14,
                      weight: FontWeight.w600,
                      color: Dg.text3,
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              if (storedPanel)
                _storedPanelCard(l)
              else if (needsSelection)
                ..._agencyPicker(l, session)
              else ...[
                if (_branch || _panelMode) ...[
                  TextField(
                    key: Key(_branch ? 'sube-email' : 'panel-identifier'),
                    controller: _identifier,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: const [
                      AutofillHints.username,
                      AutofillHints.email,
                    ],
                    inputFormatters: [
                      if (!_branch) const SmartIdentifierFormatter(),
                    ],
                    onChanged: (_) => setState(() {}),
                    style: Dg.ui(size: 16, color: Dg.text1),
                    decoration: _field(
                      label: _branch ? l.email : l.identifierLabel,
                      hint: _branch ? 'ad@sirket.com' : l.loginIdentifierHint,
                      prefix: _KindIcon(
                        kind: _branch ? IdentifierKind.email : kind,
                        active: _identifier.text.isNotEmpty,
                      ),
                      suffix: _branch
                          ? null
                          : _KindChip(
                              kind: kind,
                              phoneLabel: l.idKindPhone,
                              emailLabel: l.idKindEmail,
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: Key(_branch ? 'sube-password' : 'panel-password'),
                    controller: _password,
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.password],
                    style: Dg.ui(size: 16, color: Dg.text1),
                    decoration: _field(
                      label: l.password,
                      hint: '••••••••',
                      prefix: Icon(LucideIcons.lock, size: 18, color: Dg.text3),
                      suffix: IconButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? LucideIcons.eye
                              : LucideIcons.eyeOff,
                          size: 18,
                          color: Dg.text3,
                        ),
                      ),
                    ),
                  ),
                ] else
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    inputFormatters: const [
                      SmartIdentifierFormatter(phoneOnly: true),
                    ],
                    onChanged: (_) => setState(() {}),
                    style: Dg.ui(size: 16, color: Dg.text1),
                    decoration: _field(
                      label: l.idKindPhone,
                      hint: l.phoneHint,
                      prefix: _KindIcon(
                        kind: IdentifierKind.phone,
                        active: _phone.text.isNotEmpty,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                // Büyük yazıda iki öğe sığmazsa alt satıra iner.
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _remember = !_remember),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DgSelectBox(selected: _remember, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                l.rememberMe,
                                style: Dg.ui(size: 14, color: Dg.text2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_branch || _panelMode)
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: () => ScaffoldMessenger.of(context)
                              .showSnackBar(
                                SnackBar(content: Text(l.supportHint)),
                              ),
                          child: Text(
                            l.forgotPassword,
                            style: Dg.ui(
                              size: 14,
                              weight: FontWeight.w600,
                              color: Dg.highlight,
                            ),
                          ),
                        ),
                    ],
                  ),
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
                if (!_branch && _error != null) _ErrorText(_error!),
                const SizedBox(height: 10),
                _submitButton(l, session),
                if (!_branch) ...[
                  const SizedBox(height: 18),
                  _OrDivider(label: l.loginOr),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _MethodTile(
                          key: const Key('login-method-sms'),
                          icon: LucideIcons.messageCircle,
                          label: l.loginSmsTile,
                          selected: !_panelMode,
                          onTap: () => setState(() {
                            // Yazılan telefon SMS alanına taşınır.
                            if (_phone.text.isEmpty &&
                                identifierKind(_identifier.text) ==
                                    IdentifierKind.phone) {
                              _phone.text = formatTrPhone(_identifier.text);
                            }
                            _panelMode = false;
                            _skipStoredPanel = true;
                            _error = null;
                          }),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MethodTile(
                          key: const Key('login-method-password'),
                          icon: LucideIcons.keyRound,
                          label: l.passwordTile,
                          selected: _panelMode,
                          onTap: () => setState(() {
                            if (_identifier.text.isEmpty &&
                                _phone.text.isNotEmpty) {
                              _identifier.text = _phone.text;
                            }
                            _panelMode = true;
                            _sent = false;
                            _skipStoredPanel = true;
                            _error = null;
                          }),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(l.noAccount, style: Dg.ui(size: 14, color: Dg.text3)),
                  TextButton(
                    key: const Key('join-link'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    onPressed: _branch
                        ? () => ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(l.supportHint)))
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const JoinScreen(),
                            ),
                          ),
                    child: Text(
                      l.getSupport,
                      style: Dg.ui(
                        size: 14,
                        weight: FontWeight.w600,
                        color: Dg.highlight,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                l.fieldAppVersion,
                style: Dg.ui(size: 14, color: Dg.text3).copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _submitButton(L10n l, SessionController session) {
    if (_branch) {
      final needsSelection =
          session.lastAgencyError == 'AGENCY_SELECTION_REQUIRED' &&
          session.agencySelectionOptions.isNotEmpty;
      return DgGradientButton(
        key: const Key('sube-login'),
        label: l.signInCta,
        trailing: LucideIcons.arrowRight,
        busy: session.agencyLoginBusy,
        onPressed:
            session.agencyLoginBusy || (needsSelection && _pickedAgency == null)
            ? null
            : _loginBranch,
      );
    }
    final busy = _panelMode ? _panelBusy : session.activationBusy;
    return DgGradientButton(
      key: Key(_panelMode ? 'panel-login' : 'sms-login'),
      label: _panelMode
          ? (_panelBusy ? l.signingIn : l.signInCta)
          : l.sendCodeCta,
      trailing: LucideIcons.arrowRight,
      busy: busy,
      onPressed: busy ? null : () => _panelMode ? _loginPanel(l) : _sendSms(l),
    );
  }

  List<Widget> _agencyPicker(L10n l, SessionController session) => [
    Text(
      l.subeSelectAgency,
      textAlign: TextAlign.center,
      style: Dg.ui(size: 16, color: Dg.text1),
    ),
    const SizedBox(height: 12),
    for (final option in session.agencySelectionOptions)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: DgPanel(
          onTap: () => setState(() => _pickedAgency = option),
          child: Row(
            children: [
              DgSelectBox(selected: _pickedAgency?.id == option.id),
              const SizedBox(width: 12),
              Expanded(child: Text(option.name, style: Dg.typeBody())),
            ],
          ),
        ),
      ),
    const SizedBox(height: 8),
    _submitButton(l, session),
  ];

  Widget _storedPanelCard(L10n l) {
    return Column(
      children: [
        Text(
          l.panelSessionOn,
          key: const Key('panel-session-ready'),
          textAlign: TextAlign.center,
          style: Dg.ui(size: 16, weight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          l.panelReadyHint,
          textAlign: TextAlign.center,
          style: Dg.ui(size: 14, color: Dg.text2, height: 1.4),
        ),
        const SizedBox(height: 18),
        DgGradientButton(
          key: const Key('panel-continue'),
          label: l.goToPermissions,
          trailing: LucideIcons.arrowRight,
          onPressed: () => ref.read(sessionProvider).completeActivation(),
        ),
        TextButton(
          onPressed: () => setState(() {
            _panelMode = true;
            _skipStoredPanel = true;
            _error = null;
          }),
          child: Text(l.otherAccount, style: TextStyle(color: Dg.text2)),
        ),
        TextButton(
          onPressed: () => setState(() {
            _skipStoredPanel = true;
            _panelMode = false;
            _sent = false;
            _error = null;
          }),
          child: Text(l.smsLogin, style: TextStyle(color: Dg.text2)),
        ),
      ],
    );
  }

  /// Mockup 03: SMS doğrulama.
  Widget _smsVerify(L10n l, SessionController session) {
    final masked = session.otpMaskedPhone;
    final hasMask = masked != null && masked.isNotEmpty;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 20),
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
                  icon: Icon(LucideIcons.arrowLeft, color: Dg.text1),
                ),
              ),
              const DijigooMark(size: 52),
              const SizedBox(height: 16),
              Text(
                l.smsVerifyTitle,
                style: Dg.ui(size: 22, weight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              if (hasMask)
                Text(masked, style: Dg.stat(size: 18, weight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                hasMask ? l.smsSentTo('').trim() : l.smsSentGeneric,
                textAlign: TextAlign.center,
                style: Dg.ui(size: 14, color: Dg.text2, height: 1.35),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: DgOtpBoxes(value: _code, error: _codeError),
              ),
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
                      .requestActivationCode(normalizeIdentifier(_phone.text));
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
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                ),
              DgKeypad(
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
    );
  }
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
      style: Dg.ui(size: 14, color: Dg.bad),
    ),
  );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    Widget line(bool flip) => Expanded(
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: flip ? Alignment.centerRight : Alignment.centerLeft,
            end: flip ? Alignment.centerLeft : Alignment.centerRight,
            colors: [
              Dg.brandBlue.withValues(alpha: 0),
              Dg.brandBlue.withValues(alpha: 0.55),
            ],
          ),
        ),
      ),
    );
    return Row(
      children: [
        line(false),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: Dg.ui(size: 14, color: Dg.text3)),
        ),
        line(true),
      ],
    );
  }
}

/// "Kodu tekrar gönder" + kalan süre; süre dolunca dokunulabilir. Yalnız bu
/// küçük parça saniyede bir yenilenir; süre bitince zamanlayıcı durur.
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
            style: Dg.stat(size: 16, weight: FontWeight.w600, color: Dg.violet),
          ),
        TextButton(
          key: const Key('sms-resend'),
          onPressed: waiting || widget.busy ? null : widget.onResend,
          child: Text(
            widget.label,
            style: Dg.ui(
              size: 14,
              weight: FontWeight.w600,
              color: waiting ? Dg.text3 : Dg.highlight,
            ),
          ),
        ),
      ],
    );
  }
}

/// Yöntem kutusu ("veya" altında): SMS Kodu / Şifre.
class _MethodTile extends StatelessWidget {
  const _MethodTile({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: DgMotion.quick,
          curve: DgMotion.enter,
          constraints: const BoxConstraints(minHeight: 84),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? Dg.brandBlue.withValues(alpha: Dg.dark ? 0.20 : 0.10)
                : Dg.surface1,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? Dg.brandBlue.withValues(alpha: 0.7)
                  : Dg.hairline,
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DgIconBadge(
                icon: icon,
                tone: selected ? DgTone.info : DgTone.accent,
                size: 36,
                soft: !selected,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Dg.ui(
                  size: 14,
                  weight: FontWeight.w600,
                  color: selected ? Dg.text1 : Dg.text2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Yazılanın türüne göre değişen ön ikon (kişi → telefon / posta).
class _KindIcon extends StatelessWidget {
  const _KindIcon({required this.kind, this.active = true});

  final IdentifierKind kind;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final icon = switch (kind) {
      IdentifierKind.phone => LucideIcons.smartphone,
      IdentifierKind.email => LucideIcons.mail,
      IdentifierKind.empty => LucideIcons.user,
    };
    final lit = active && kind != IdentifierKind.empty;
    return AnimatedSwitcher(
      duration: DgMotion.quick,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: a, child: child),
      ),
      child: Icon(
        icon,
        key: ValueKey(icon),
        size: 18,
        color: lit ? Dg.highlight : Dg.text3,
      ),
    );
  }
}

/// Alanın sağında "Telefon" / "E-posta" etiketi; boşken görünmez.
class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.kind,
    required this.phoneLabel,
    required this.emailLabel,
  });

  final IdentifierKind kind;
  final String phoneLabel;
  final String emailLabel;

  @override
  Widget build(BuildContext context) {
    final label = switch (kind) {
      IdentifierKind.phone => phoneLabel,
      IdentifierKind.email => emailLabel,
      IdentifierKind.empty => null,
    };
    return AnimatedSwitcher(
      duration: DgMotion.quick,
      child: label == null
          ? const SizedBox(key: ValueKey('none'), width: 8)
          : Padding(
              key: ValueKey(label),
              padding: const EdgeInsets.only(right: 10),
              child: Center(
                widthFactor: 1,
                child: DgStatusPill(
                  label: label,
                  tone: DgTone.info,
                  dense: true,
                ),
              ),
            ),
    );
  }
}
