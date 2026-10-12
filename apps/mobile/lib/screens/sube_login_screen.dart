import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/agency_models.dart';
import '../brand.dart';
import '../l10n.dart';
import '../privacy.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

/// Şube/Acente girişi. Kurye girişiyle aynı törensel ekran; hesap ve oturum ayrı.
class SubeLoginScreen extends ConsumerStatefulWidget {
  const SubeLoginScreen({super.key});

  @override
  ConsumerState<SubeLoginScreen> createState() => _SubeLoginScreenState();
}

class _SubeLoginScreenState extends ConsumerState<SubeLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  AgencyDto? _pickedAgency;

  static Color get _onHero => Dg.onHero;
  static Color get _muted => Dg.onHeroMuted;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = ref.read(sessionProvider);
    final ok = await s.loginAsAgency(
      email: _email.text,
      password: _password.text,
      agencyId: _pickedAgency?.id,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    setState(() {});
  }

  InputDecoration _glass({String? hint, Widget? prefix, Widget? suffix}) {
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
        borderSide: BorderSide(color: Dg.rule),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Dg.warn, width: 1.4),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);
    final needsSelection =
        s.lastAgencyError == 'AGENCY_SELECTION_REQUIRED' &&
        s.agencySelectionOptions.isNotEmpty;
    final blocked =
        s.agencyLoginBusy || (needsSelection && _pickedAgency == null);

    return PrivacyGate(
      active: true,
      child: Scaffold(
        body: HeroBackground(
          vivid: true,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 24,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: Icon(LucideIcons.arrowLeft, color: _onHero),
                          ),
                        ),
                        DijigooWordmark(height: 56, onDark: Dg.dark),
                        SizedBox(height: 14),
                        Text(
                          l.subeLoginTitle,
                          style: TextStyle(
                            color: _muted,
                            fontSize: 14,
                            letterSpacing: 0.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 22),
                        if (needsSelection) ...[
                          Text(
                            l.subeSelectAgency,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _onHero, fontSize: 16),
                          ),
                          SizedBox(height: 12),
                          for (final option in s.agencySelectionOptions)
                            Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Material(
                                color: Dg.heroGlass,
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () =>
                                      setState(() => _pickedAgency = option),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _pickedAgency?.id == option.id
                                              ? LucideIcons.checkCircle2
                                              : LucideIcons.circle,
                                          size: 18,
                                          color: _pickedAgency?.id == option.id
                                              ? Dg.warn
                                              : _muted,
                                        ),
                                        SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            option.name,
                                            style: TextStyle(
                                              color: _onHero,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ] else ...[
                          TextField(
                            key: Key('sube-email'),
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            style: TextStyle(color: _onHero),
                            decoration: _glass(
                              hint: l.email,
                              prefix: Icon(
                                LucideIcons.user,
                                size: 18,
                                color: _muted,
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                          TextField(
                            key: Key('sube-password'),
                            controller: _password,
                            obscureText: _obscure,
                            style: TextStyle(color: _onHero),
                            decoration: _glass(
                              hint: l.password,
                              prefix: Icon(
                                LucideIcons.lock,
                                size: 18,
                                color: _muted,
                              ),
                              suffix: IconButton(
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? LucideIcons.eye
                                      : LucideIcons.eyeOff,
                                  size: 18,
                                  color: _muted,
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (s.lastAgencyError != null &&
                            s.lastAgencyError != 'AGENCY_SELECTION_REQUIRED')
                          Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: Text(
                              l.subeLoginFailed,
                              style: TextStyle(color: Dg.bad, fontSize: 14),
                            ),
                          ),
                        SizedBox(height: 16),
                        DgButton(
                          key: Key('sube-login'),
                          label: l.signInCta,
                          trailing: LucideIcons.arrowRight,
                          tone: DgButtonTone.ember,
                          height: 54,
                          busy: s.agencyLoginBusy,
                          onPressed: blocked ? null : _submit,
                        ),
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
}
