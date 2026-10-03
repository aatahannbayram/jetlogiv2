import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/jetdiji_http.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

class JetdijiLoginScreen extends ConsumerStatefulWidget {
  const JetdijiLoginScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<JetdijiLoginScreen> createState() => _JetdijiLoginScreenState();
}

class _JetdijiLoginScreenState extends ConsumerState<JetdijiLoginScreen> {
  late int tab = widget.initialTab;
  final identifier = TextEditingController();
  final password = TextEditingController();
  final email = TextEditingController();
  final branchPassword = TextEditingController();
  List<JetDijiAgencyOption> agencies = const [];
  String? agencyId;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    identifier.dispose();
    password.dispose();
    email.dispose();
    branchPassword.dispose();
    super.dispose();
  }

  Future<void> _courier() async {
    setState(() {
      busy = true;
      error = null;
    });
    final ok = await ref.read(sessionProvider).loginWithJetdiji(
      identifier: identifier.text.trim(),
      password: password.text,
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) {
      setState(
        () => error = ref.read(sessionProvider).lastJetdijiError ?? 'Giriş olmadı.',
      );
    }
  }

  Future<void> _branch() async {
    setState(() {
      busy = true;
      error = null;
    });
    final result = await ref.read(sessionProvider).loginWithBranch(
      email: email.text.trim(),
      password: branchPassword.text,
      agencyId: agencyId,
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (result.agencies.isNotEmpty) {
      setState(() {
        agencies = result.agencies;
        error = 'Şube seçin.';
      });
      return;
    }
    if (!result.ok) {
      setState(() => error = result.errorCode ?? 'Giriş olmadı.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('JetDiji')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          SegmentedTabs(
            labels: const ['Kurye', 'Şube'],
            index: tab,
            onChanged: (i) => setState(() {
              tab = i;
              error = null;
            }),
          ),
          const SizedBox(height: 20),
          if (tab == 0) ...[
            const Display('Kurye girişi', size: 28),
            const SizedBox(height: 12),
            TextField(
              controller: identifier,
              decoration: const InputDecoration(labelText: 'Kod veya telefon'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Şifre'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : _courier,
              child: Text(busy ? 'Giriliyor' : 'Giriş'),
            ),
          ] else ...[
            const Display('Şube girişi', size: 28),
            const SizedBox(height: 12),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-posta'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: branchPassword,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Şifre'),
            ),
            if (agencies.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Acente', style: TextStyle(color: Dg.ink2)),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: agencyId,
                onChanged: (id) => setState(() => agencyId = id),
                child: Column(
                  children: [
                    for (final agency in agencies)
                      RadioListTile<String>(
                        value: agency.id,
                        title: Text(agency.name),
                        subtitle: agency.code == null ? null : Text(agency.code!),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : _branch,
              child: Text(busy ? 'Giriliyor' : 'Giriş'),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: TextStyle(color: Dg.hi)),
          ],
        ],
      ),
    );
  }
}
