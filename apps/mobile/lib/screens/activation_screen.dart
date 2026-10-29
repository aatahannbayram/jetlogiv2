import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../login_identifier.dart';
import '../session.dart';
import '../brand.dart';
import '../motion.dart';
import '../privacy.dart';
import '../theme.dart';
import '../widgets.dart';
import 'join_screens.dart';

/// Canlı giriş: logo, cam alanlar, yöntem kutuları ve marka mavisi CTA.
/// Kimlik alanı yazılanın türüne (telefon / e-posta) göre biçimlenir.
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
        borderSide: BorderSide(color: Dg.highlight, width: 1.4),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
    setState(() => _sent = true);
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
                              _FlowDash(),
                              SizedBox(width: 10),
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
                              SizedBox(width: 10),
                              _FlowDash(),
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
                              enableSuggestions: false,
                              autofillHints: const [
                                AutofillHints.username,
                                AutofillHints.email,
                                AutofillHints.telephoneNumber,
                              ],
                              inputFormatters: const [
                                SmartIdentifierFormatter(),
                              ],
                              onChanged: (_) => setState(() {}),
                              style: TextStyle(color: _onHero),
                              decoration: _glassDecoration(
                                hint: l.loginIdentifierHint,
                                prefix: _KindIcon(
                                  kind: identifierKind(_identifier.text),
                                ),
                                suffix: _KindChip(
                                  kind: identifierKind(_identifier.text),
                                  phoneLabel: l.idKindPhone,
                                  emailLabel: l.idKindEmail,
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
                              autofillHints: const [
                                AutofillHints.telephoneNumber,
                              ],
                              inputFormatters: const [
                                SmartIdentifierFormatter(phoneOnly: true),
                              ],
                              onChanged: (_) => setState(() {}),
                              style: TextStyle(color: _onHero),
                              decoration: _glassDecoration(
                                hint: '0 5xx xxx xx xx',
                                prefix: _KindIcon(
                                  kind: IdentifierKind.phone,
                                  active: _phone.text.isNotEmpty,
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
                                      // Yazılan telefon SMS alanına taşınır.
                                      if (_phone.text.isEmpty &&
                                          identifierKind(_identifier.text) ==
                                              IdentifierKind.phone) {
                                        _phone.text = formatTrPhone(
                                          _identifier.text,
                                        );
                                      }
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
                                        color: _remember
                                            ? Dg.highlight
                                            : _muted,
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
                                      color: Dg.highlight,
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
          color: selected
              ? Dg.brandBlue.withValues(alpha: Dg.dark ? 0.22 : 0.12)
              : Dg.heroGlass,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? Dg.brandBlue.withValues(alpha: 0.7)
                : Dg.brandBlue.withValues(alpha: 0),
            width: 1.4,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Dg.brandBlue.withValues(
                      alpha: Dg.dark ? 0.35 : 0.18,
                    ),
                    blurRadius: 18,
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
              color: selected ? Dg.highlight : _ActivationScreenState._muted,
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

/// Slogan yanındaki kısa marka akışı çizgisi.
class _FlowDash extends StatelessWidget {
  const _FlowDash();

  @override
  Widget build(BuildContext context) => Container(
    width: 18,
    height: 2,
    decoration: const BoxDecoration(
      gradient: Dg.brandFlow,
      borderRadius: BorderRadius.all(Radius.circular(1)),
    ),
  );
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
        color: lit ? Dg.highlight : Dg.onHeroMuted,
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
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Dg.brandBlue.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: Dg.ui(
                      size: 14,
                      weight: FontWeight.w600,
                      color: Dg.highlight,
                    ).copyWith(fontSize: 12),
                  ),
                ),
              ),
            ),
    );
  }
}
