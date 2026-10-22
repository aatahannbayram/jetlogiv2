import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../session.dart';
import '../brand.dart';
import '../motion.dart';
import '../privacy.dart';
import '../theme.dart';
import '../widgets.dart';
import 'join_screens.dart';

/// Canlı giriş — logo + cam alanlar + yöntem kutuları, turuncu CTA.
class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key});

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _sent = false;
  bool _remember = true;
  bool _panelMode = true;
  bool _panelBusy = false;
  bool _obscurePassword = true;
  bool _skipStoredPanel = false;
  String? _error;

  static Color get _onHero => Dg.onHero;
  static Color get _muted => Dg.onHeroMuted;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
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

  InputDecoration _glassDecoration({
    String? hint,
    Widget? prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Dg.heroGlass,
      hintText: hint,
      hintStyle: TextStyle(color: Dg.onHeroMuted, fontSize: 16),
      prefixIcon: prefix,
      prefixIconConstraints: BoxConstraints(minWidth: 48, minHeight: 48),
      suffixIcon: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Dg.warn, width: 1.4),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Future<void> _sendSms(L10n l) async {
    setState(() => _error = null);
    final ok = await ref
        .read(sessionProvider)
        .requestActivationCode(_phone.text);
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = _activationError(l, ref.read(sessionProvider)));
      return;
    }
    setState(() => _sent = true);
  }

  Future<void> _loginPanel(L10n l) async {
    setState(() {
      _panelBusy = true;
      _error = null;
    });
    final ok = await ref
        .read(sessionProvider)
        .loginWithPanel(identifier: _identifier.text, password: _password.text);
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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = ref.watch(sessionProvider);
    final storedPanel = session.panelLoggedIn && !_sent && !_skipStoredPanel;

    return PrivacyGate(
      active: _sent || _panelMode,
      child: Scaffold(
        body: HeroBackground(
          vivid: true,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - 28).clamp(
                        0.0,
                        double.infinity,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 12),
                        Appear(
                          child: DijigooWordmark(height: 56, onDark: Dg.dark),
                        ),
                        SizedBox(height: 14),
                        Appear(
                          delay: Duration(milliseconds: 80),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 14,
                                height: 1,
                                color: _muted.withValues(alpha: 0.45),
                              ),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  l.loginTagline,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _muted,
                                    fontSize: 14,
                                    letterSpacing: 0.4,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Container(
                                width: 14,
                                height: 1,
                                color: _muted.withValues(alpha: 0.45),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 28),
                        if (storedPanel)
                          _storedPanelCard(l)
                        else if (_sent)
                          _otpCard(l, session)
                        else ...[
                          if (_panelMode) ...[
                            TextField(
                              key: Key('panel-identifier'),
                              controller: _identifier,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              style: TextStyle(color: _onHero),
                              decoration: _glassDecoration(
                                hint: l.loginIdentifierHint,
                                prefix: Icon(
                                  LucideIcons.user,
                                  size: 18,
                                  color: _muted,
                                ),
                              ),
                            ),
                            SizedBox(height: 12),
                            TextField(
                              key: Key('panel-password'),
                              controller: _password,
                              obscureText: _obscurePassword,
                              style: TextStyle(color: _onHero),
                              decoration: _glassDecoration(
                                hint: l.password,
                                prefix: Icon(
                                  LucideIcons.lock,
                                  size: 18,
                                  color: _muted,
                                ),
                                suffix: IconButton(
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  icon: Icon(
                                    _obscurePassword
                                        ? LucideIcons.eye
                                        : LucideIcons.eyeOff,
                                    size: 18,
                                    color: _muted,
                                  ),
                                ),
                              ),
                            ),
                          ] else
                            TextField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              style: TextStyle(color: _onHero),
                              decoration: _glassDecoration(
                                hint: '+90 5xx xxx xx xx',
                                prefix: Icon(
                                  LucideIcons.user,
                                  size: 18,
                                  color: _muted,
                                ),
                              ),
                            ),
                          SizedBox(height: 16),
                          Appear(
                            delay: Duration(milliseconds: 160),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _MethodTile(
                                    key: Key('login-method-sms'),
                                    icon: LucideIcons.messageCircle,
                                    label: l.loginSmsTile,
                                    selected: !_panelMode,
                                    onTap: () => setState(() {
                                      _panelMode = false;
                                      _skipStoredPanel = true;
                                      _error = null;
                                    }),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: _MethodTile(
                                    key: Key('login-method-password'),
                                    icon: LucideIcons.lock,
                                    label: l.loginPasswordTile,
                                    selected: _panelMode,
                                    onTap: () => setState(() {
                                      _panelMode = true;
                                      _sent = false;
                                      _skipStoredPanel = true;
                                      _error = null;
                                    }),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            children: [
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _remember = !_remember),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _remember
                                            ? LucideIcons.checkSquare
                                            : LucideIcons.square,
                                        size: 18,
                                        color: _remember ? Dg.warn : _muted,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        l.rememberMe,
                                        style: TextStyle(
                                          color: _muted,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_panelMode)
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    minimumSize: Size(48, 48),
                                    tapTargetSize: MaterialTapTargetSize.padded,
                                  ),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(l.supportHint)),
                                    );
                                  },
                                  child: Text(
                                    l.forgotPassword,
                                    style: TextStyle(
                                      color: Dg.warn,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (_error != null)
                            Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                _error!,
                                style: TextStyle(color: Dg.clay, fontSize: 14),
                              ),
                            ),
                          SizedBox(height: 14),
                          Appear(
                            delay: Duration(milliseconds: 240),
                            child: DgButton(
                              key: _panelMode
                                  ? Key('panel-login')
                                  : Key('sms-login'),
                              label: _panelMode
                                  ? (_panelBusy ? l.signingIn : l.signInCta)
                                  : l.signInCta,
                              trailing: LucideIcons.arrowRight,
                              tone: DgButtonTone.ember,
                              height: 54,
                              busy: _panelMode
                                  ? _panelBusy
                                  : session.activationBusy,
                              onPressed:
                                  (_panelMode
                                      ? _panelBusy
                                      : session.activationBusy)
                                  ? null
                                  : () => _panelMode
                                        ? _loginPanel(l)
                                        : _sendSms(l),
                            ),
                          ),
                        ],
                        SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.lock, size: 13, color: _muted),
                            SizedBox(width: 6),
                            Text(
                              l.secureLoginSsl,
                              style: TextStyle(
                                color: _muted,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          l.fieldAppVersion,
                          style: TextStyle(color: _muted, fontSize: 14),
                        ),
                        SizedBox(height: 6),
                        Center(
                          child: TextButton(
                            key: Key('join-link'),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => JoinScreen()),
                            ),
                            child: Text(
                              l.joinTitle,
                              style: TextStyle(
                                color: _muted,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _storedPanelCard(L10n l) {
    return Column(
      children: [
        Text(
          l.panelSessionOn,
          key: Key('panel-session-ready'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _onHero,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 8),
        Text(
          l.panelReadyHint,
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 14, height: 1.4),
        ),
        SizedBox(height: 18),
        DgButton(
          key: Key('panel-continue'),
          label: l.goToPermissions,
          trailing: LucideIcons.arrowRight,
          tone: DgButtonTone.ember,
          onPressed: () => ref.read(sessionProvider).completeActivation(),
        ),
        TextButton(
          onPressed: () => setState(() {
            _panelMode = true;
            _skipStoredPanel = true;
            _error = null;
          }),
          child: Text(l.otherAccount, style: TextStyle(color: _muted)),
        ),
        TextButton(
          onPressed: () => setState(() {
            _skipStoredPanel = true;
            _sent = false;
            _error = null;
          }),
          child: Text(l.smsLogin, style: TextStyle(color: _muted)),
        ),
      ],
    );
  }

  Widget _otpCard(L10n l, SessionController session) {
    return Column(
      children: [
        Text(
          l.askFourDigit,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _onHero,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 6),
        Text(
          l.codeNotDelivery,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: _muted),
        ),
        SizedBox(height: 16),
        OtpPin(controller: _otp, error: _error != null),
        if (_error != null)
          Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              _error!,
              style: TextStyle(color: Dg.clay, fontSize: 14),
            ),
          ),
        SizedBox(height: 16),
        DgButton(
          label: l.verifyCode,
          trailing: LucideIcons.arrowRight,
          tone: DgButtonTone.ember,
          onPressed: () async {
            final ok = await ref
                .read(sessionProvider)
                .verifyLoginOtp(_otp.text.trim());
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
        TextButton(
          onPressed:
              session.activationBusy ||
                  (session.otpResendAt != null &&
                      DateTime.now().isBefore(session.otpResendAt!))
              ? null
              : () async {
                  setState(() => _error = null);
                  final ok = await ref
                      .read(sessionProvider)
                      .requestActivationCode(_phone.text);
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
          child: Text(l.resendCode, style: TextStyle(color: _muted)),
        ),
      ],
    );
  }
}

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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        constraints: BoxConstraints(minHeight: 104),
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? Dg.warnSoft : Dg.heroGlass,
          borderRadius: BorderRadius.circular(18),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Color(0x55FF7A18),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? Dg.warn : _ActivationScreenState._muted,
            ),
            SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Dg.onHero : _ActivationScreenState._muted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
