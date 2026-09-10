import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/agency_models.dart';
import '../l10n.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

/// Şube/Acente girişi — kurye aktivasyon akışından tamamen ayrı, çünkü farklı
/// bir hesap türü (dijigoo-ops'un acente portalı, e-posta+şifre, ayrı bir
/// cookie-session). Bkz. docs/08-sube-acente-entegrasyonu.md.
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
      // Bu ekran ActivationScreen üzerine push edilmişti — giriş başarılı
      // olup [SessionController.phase] değişince kök `app.dart` gösterdiği
      // ekranı SubeShellScreen'e çevirir, ama bu push edilmiş rota önünde
      // durmaya devam eder ve yeni ekranı gizler. Kapatmak gerekiyor.
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);
    final needsSelection = s.lastAgencyError == 'AGENCY_SELECTION_REQUIRED' &&
        s.agencySelectionOptions.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(l.subeLoginTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          DgIcon(LucideIcons.building2, size: 40, color: Dg.brand, weight: 600),
          const SizedBox(height: 12),
          Text(l.subeLoginHint, style: Dg.ui(size: 14, color: Dg.ink2)),
          const SizedBox(height: 24),
          if (needsSelection) ...[
            Text(l.subeSelectAgency, style: Dg.ui(size: 14, weight: FontWeight.w600)),
            const SizedBox(height: 10),
            for (final option in s.agencySelectionOptions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DgCard(
                  onTap: () => setState(() => _pickedAgency = option),
                  child: Row(
                    children: [
                      Icon(
                        _pickedAgency?.id == option.id
                            ? LucideIcons.checkCircle2
                            : LucideIcons.circle,
                        size: 18,
                        color: _pickedAgency?.id == option.id ? Dg.purple : Dg.ink3,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(option.name, style: Dg.ui(size: 15))),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ] else ...[
            DgCard(
              child: TextField(
                key: const Key('sube-email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: l.email,
                  border: InputBorder.none,
                  icon: DgIcon(LucideIcons.user, size: 18),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DgCard(
              child: TextField(
                key: const Key('sube-password'),
                controller: _password,
                obscureText: _obscure,
                decoration: InputDecoration(
                  hintText: l.password,
                  border: InputBorder.none,
                  icon: DgIcon(LucideIcons.lock, size: 18),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (s.lastAgencyError != null && s.lastAgencyError != 'AGENCY_SELECTION_REQUIRED') ...[
            const SizedBox(height: 12),
            Text(l.subeLoginFailed, style: Dg.ui(size: 13, color: Dg.hi)),
          ],
          const SizedBox(height: 20),
          DgButton(
            key: const Key('sube-login'),
            label: l.signInCta,
            icon: LucideIcons.logIn,
            tone: DgButtonTone.brand,
            busy: s.agencyLoginBusy,
            onPressed: s.agencyLoginBusy || (needsSelection && _pickedAgency == null)
                ? null
                : _submit,
          ),
        ],
      ),
    );
  }
}
