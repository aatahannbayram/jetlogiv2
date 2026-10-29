import 'package:flutter/material.dart';

import 'activation_screen.dart';

/// Şube girişi: birleşik giriş ekranı, Şube sekmesi seçili ve geri
/// düğmeli açılır (eski bağlantılar ve demo karşılama ekranı için).
class SubeLoginScreen extends StatelessWidget {
  const SubeLoginScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const ActivationScreen(initialRole: LoginRole.branch, pushed: true);
}
