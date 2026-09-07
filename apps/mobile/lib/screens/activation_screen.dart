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

/// Canvas'ın "Giriş" ekranı (1a) — ortada büyük logo kartı, alt sabit
/// cam-efekti sheet içinde telefon girişi. Telefon numarasıyla giriş → OTP
/// doğrulama, hepsi tek ekranda (sheet içeriği değişiyor).
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

  InputDecoration _plainFieldDecoration() {
    final fill = Dg.dark
        ? Colors.white.withValues(alpha: 0.06)
        : Dg.elev;
    final border = Dg.onHero.withValues(alpha: Dg.dark ? 0.14 : 0.18);
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: fill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Dg.purpleActive),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  InputDecoration _fieldDecoration() {
    return _plainFieldDecoration().copyWith(
      prefixText: '+90  ',
      prefixStyle: TextStyle(
        color: Dg.onHero,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = ref.watch(sessionProvider);
    final onHero = Dg.onHero;
    final muted = Dg.onHeroMuted;
    return PrivacyGate(
      active: _sent || _panelMode,
      child: Scaffold(
      body: HeroBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Appear(
                      child: DijigooWordmark(height: 36, onDark: true),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      l.welcomeShift,
                      textAlign: TextAlign.center,
                      style: Dg.serif(
                        size: 28,
                        weight: FontWeight.w700,
                        color: onHero,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        l.welcomeBody,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: muted,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                decoration: BoxDecoration(
                  color: Dg.heroGlass,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(Dg.radiusHero),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: onHero.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!session.panelLoggedIn ||
                          _panelMode ||
                          _sent ||
                          _skipStoredPanel) ...[
                        SegmentedTabs(
                          glass: true,
                          labels: [l.smsLogin, l.passwordLogin],
                          index: _panelMode ? 1 : 0,
                          onChanged: (i) => setState(() {
                            _panelMode = i == 1;
                            _sent = false;
                            _skipStoredPanel = true;
                            _error = null;
                          }),
                        ),
                        const SizedBox(height: 18),
                      ],
                      if (session.panelLoggedIn &&
                          !_panelMode &&
                          !_sent &&
                          !_skipStoredPanel) ...[
                        Text(
                          l.panelSessionOn,
                          key: const Key('panel-session-ready'),
                          style: TextStyle(
                            color: onHero,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l.panelReadyHint,
                          style: TextStyle(
                            color: muted,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        DgButton(
                          key: const Key('panel-continue'),
                          label: l.goToPermissions,
                          trailing: LucideIcons.arrowRight,
                          onPressed: () =>
                              ref.read(sessionProvider).completeActivation(),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: () => setState(() {
                              _panelMode = true;
                              _error = null;
                            }),
                            child: Text(
                              l.otherAccount,
                              style: TextStyle(color: muted),
                            ),
                          ),
                        ),
                        Center(
                          child: TextButton(
                            onPressed: () => setState(() {
                              _skipStoredPanel = true;
                              _sent = false;
                              _error = null;
                            }),
                            child: Text(
                              l.smsLogin,
                              style: TextStyle(color: muted),
                            ),
                          ),
                        ),
                      ] else if (_panelMode) ...[
                        Text(
                          l.emailOrPhone,
                          style: TextStyle(
                            color: muted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          key: const Key('panel-identifier'),
                          controller: _identifier,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          style: TextStyle(color: onHero),
                          decoration: _plainFieldDecoration(),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          l.password,
                          style: TextStyle(
                            color: muted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          key: const Key('panel-password'),
                          controller: _password,
                          obscureText: _obscurePassword,
                          style: TextStyle(color: onHero),
                          decoration: _plainFieldDecoration().copyWith(
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? LucideIcons.eyeOff
                                    : LucideIcons.eye,
                                size: 18,
                                color: muted,
                              ),
                            ),
                          ),
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Dg.clay,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        const SizedBox(height: 18),
                        DgButton(
                          key: const Key('panel-login'),
                          label: _panelBusy ? l.signingIn : l.enterPanel,
                          trailing: LucideIcons.arrowRight,
                          busy: _panelBusy,
                          onPressed: _panelBusy
                              ? null
                              : () async {
                                  setState(() {
                                    _panelBusy = true;
                                    _error = null;
                                  });
                                  final ok = await ref
                                      .read(sessionProvider)
                                      .loginWithPanel(
                                        identifier: _identifier.text,
                                        password: _password.text,
                                      );
                                  if (!mounted) return;
                                  setState(() => _panelBusy = false);
                                  if (!ok) {
                                    final code = ref
                                        .read(sessionProvider)
                                        .lastPanelError;
                                    setState(
                                      () => _error = code == 'PANEL_UNAVAILABLE'
                                          ? l.panelUnavailable
                                          : l.loginFailed,
                                    );
                                    return;
                                  }
                                  ref
                                      .read(sessionProvider)
                                      .completeActivation();
                                },
                        ),
                      ] else if (!_sent) ...[
                        Text(
                          l.phoneNumber,
                          style: TextStyle(
                            color: muted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(color: onHero),
                          decoration: _fieldDecoration().copyWith(
                            hintText: '5xx xxx xx xx',
                            hintStyle: TextStyle(color: muted),
                          ),
                        ),
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: () => setState(() => _remember = !_remember),
                          child: Row(
                            children: [
                              Icon(
                                _remember
                                    ? LucideIcons.checkSquare
                                    : LucideIcons.square,
                                size: 20,
                                color: Dg.purpleActive,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l.rememberDevice,
                                style: TextStyle(
                                  color: muted,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Dg.clay,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        const SizedBox(height: 18),
                        DgButton(
                          label: l.sendCode,
                          trailing: LucideIcons.arrowRight,
                          busy: session.activationBusy,
                          onPressed: session.activationBusy
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
                                    return;
                                  }
                                  setState(() => _sent = true);
                                },
                        ),
                      ] else ...[
                        Text(
                          l.askFourDigit,
                          style: TextStyle(
                            color: onHero,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l.codeNotDelivery,
                          style: TextStyle(
                            fontSize: 13,
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OtpPin(controller: _otp, error: _error != null),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Dg.clay,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        DgButton(
                          label: l.verifyCode,
                          trailing: LucideIcons.arrowRight,
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
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: session.activationBusy ||
                                    (session.otpResendAt != null &&
                                        DateTime.now().isBefore(
                                          session.otpResendAt!,
                                        ))
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
                            child: Text(
                              l.resendCode,
                              style: TextStyle(color: muted),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Center(
                        child: Text(
                          l.supportHint,
                          style: TextStyle(
                            color: onHero.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          l.fieldAppVersion,
                          style: TextStyle(
                            color: onHero.withValues(alpha: 0.35),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
