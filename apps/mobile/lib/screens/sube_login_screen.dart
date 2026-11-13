import 'package:flutter/material.dart';

import 'activation_screen.dart';

/// Şube/Acente girişi: ortak giriş ekranı "İş Ortağı" sekmesi seçili açılır.
class SubeLoginScreen extends StatelessWidget {
  const SubeLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ActivationScreen(initialRole: LoginRole.partner);
  }
}
