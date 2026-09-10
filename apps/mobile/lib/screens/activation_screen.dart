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
import 'sube_login_screen.dart';

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
  bool _panelMode = false;
  bool _panelBusy = false;
  bool _obscurePassword = true;
  bool _skipStoredPanel = false;
  String? _error;

  static const _onHero = Colors.white;
  static const _muted = Color(0xFFCBBEEE);

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  String _activationError(L10n l, SessionController session, {bool verify = false}) {
    final raw = session.lastActivationError;
    if (raw == 'NETWORK') return l.activationSendFailed;
    if (raw == 'OTP_RESEND_TOO_SOON' || raw == 'RATE_LIMITED') {
      return l.waitToResend;
    }
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
      fillColor: Colors.white.withValues(alpha: 0.06),
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0x99CBBEEE), fontSize: 15),
      prefixIcon: prefix,
      prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      suffixIcon: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Dg.heroAccentOrange, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Future<void> _sendSms(L10n l) async {
    setState(() => _error = null);
    final ok = await ref.read(sessionProvider).requestActivationCode(_phone.text);
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
    final ok = await ref.read(sessionProvider).loginWithPanel(
      identifier: _identifier.text,
      password: _password.text,
    );
    if (!mounted) return;
    setState(() => _panelBusy = false);
    if (!ok) {
      final code = ref.read(sessionProvider).lastPanelError;
      setState(
        () => _error = code == 'PANEL_UNAVAILABLE'
            ? l.panelUnavailable
            : l.loginFailed,
      );
      return;
    }
    ref.read(sessionProvider).completeActivation();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = ref.watch(sessionProvider);
    final storedPanel = session.panelLoggedIn &&
        !_panelMode &&
        !_sent &&
        !_skipStoredPanel;

    return PrivacyGate(
      active: _sent || _panelMode,
      child: Scaffold(
        body: HeroBackground(
          vivid: true,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 12),
                        const Appear(
                          child: DijigooWordmark(height: 56, onDark: true),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 14,
                              height: 1,
                              color: _muted.withValues(alpha: 0.45),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                l.loginTagline,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 12,
                                  letterSpacing: 0.4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 14,
                              height: 1,
                              color: _muted.withValues(alpha: 0.45),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        if (storedPanel)
                          _storedPanelCard(l)
                        else if (_sent)
                          _otpCard(l, session)
                        else ...[
                          if (_panelMode) ...[
                            TextField(
                              key: const Key('panel-identifier'),
                              controller: _identifier,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              style: const TextStyle(color: _onHero),
                              decoration: _glassDecoration(
                                hint: l.loginIdentifierHint,
                                prefix: const Icon(
                                  LucideIcons.user,
                                  size: 18,
                                  color: _muted,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              key: const Key('panel-password'),
                              controller: _password,
                              obscureText: _obscurePassword,
                              style: const TextStyle(color: _onHero),
                              decoration: _glassDecoration(
                                hint: l.password,
                                prefix: const Icon(
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
                              style: const TextStyle(color: _onHero),
                              decoration: _glassDecoration(
                                hint: '+90 5xx xxx xx xx',
                                prefix: const Icon(
                                  LucideIcons.user,
                                  size: 18,
                                  color: _muted,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _MethodTile(
                                  key: const Key('login-method-sms'),
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
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MethodTile(
                                  key: const Key('login-method-password'),
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
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _remember = !_remember),
                                child: Row(
                                  children: [
                                    Icon(
                                      _remember
                                          ? LucideIcons.checkSquare
                                          : LucideIcons.square,
                                      size: 18,
                                      color: _remember
                                          ? Dg.heroAccentOrange
                                          : _muted,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      l.rememberMe,
                                      style: const TextStyle(
                                        color: _muted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              if (_panelMode)
                                Flexible(
                                  child: TextButton(
                                    onPressed: () {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(content: Text(l.supportHint)),
                                      );
                                    },
                                    child: Text(
                                      l.forgotPassword,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Dg.heroAccentOrange,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: Dg.clay,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          const SizedBox(height: 14),
                          DgButton(
                            key: _panelMode
                                ? const Key('panel-login')
                                : const Key('sms-login'),
                            label: _panelMode
                                ? (_panelBusy ? l.signingIn : l.signInCta)
                                : l.signInCta,
                            trailing: LucideIcons.arrowRight,
                            tone: DgButtonTone.ember,
                            height: 54,
                            busy: _panelMode
                                ? _panelBusy
                                : session.activationBusy,
                            onPressed: (_panelMode
                                    ? _panelBusy
                                    : session.activationBusy)
                                ? null
                                : () => _panelMode ? _loginPanel(l) : _sendSms(l),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              LucideIcons.lock,
                              size: 13,
                              color: _onHero.withValues(alpha: 0.45),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l.secureLoginSsl,
                              style: TextStyle(
                                color: _onHero.withValues(alpha: 0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l.fieldAppVersion,
                          style: TextStyle(
                            color: _onHero.withValues(alpha: 0.32),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: TextButton(
                            key: const Key('sube-login-link'),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SubeLoginScreen(),
                              ),
                            ),
                            child: Text(
                              l.subeLoginTitle,
                              style: TextStyle(
                                color: _onHero.withValues(alpha: 0.6),
                                fontSize: 12,
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
          key: const Key('panel-session-ready'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _onHero,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l.panelReadyHint,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 18),
        DgButton(
          key: const Key('panel-continue'),
          label: l.goToPermissions,
          trailing: LucideIcons.arrowRight,
          tone: DgButtonTone.ember,
          onPressed: () => ref.read(sessionProvider).completeActivation(),
        ),
        TextButton(
          onPressed: () => setState(() {
            _panelMode = true;
            _error = null;
          }),
          child: Text(l.otherAccount, style: const TextStyle(color: _muted)),
        ),
        TextButton(
          onPressed: () => setState(() {
            _skipStoredPanel = true;
            _sent = false;
            _error = null;
          }),
          child: Text(l.smsLogin, style: const TextStyle(color: _muted)),
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
          style: const TextStyle(
            color: _onHero,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l.codeNotDelivery,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: _muted),
        ),
        const SizedBox(height: 16),
        OtpPin(controller: _otp, error: _error != null),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _error!,
              style: TextStyle(color: Dg.clay, fontSize: 14),
            ),
          ),
        const SizedBox(height: 16),
        DgButton(
          label: l.verifyCode,
          trailing: LucideIcons.arrowRight,
          tone: DgButtonTone.ember,
          onPressed: () async {
            final ok =
                await ref.read(sessionProvider).verifyLoginOtp(_otp.text.trim());
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
          onPressed: session.activationBusy ||
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
          child: Text(l.resendCode, style: const TextStyle(color: _muted)),
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
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        height: 88,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: selected ? 0.09 : 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? Dg.heroAccentOrange
                : Colors.white.withValues(alpha: 0.16),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x66F08A24),
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
              color: selected ? Dg.heroAccentOrange : _ActivationScreenState._muted,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : _ActivationScreenState._muted,
                fontSize: 12,
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
