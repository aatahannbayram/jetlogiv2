import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/activation_screen.dart';
import 'screens/onboard_screen.dart';
import 'screens/permissions_screen.dart';
import 'screens/shell_screen.dart';
import 'screens/shift_screen.dart';
import 'screens/splash_screen.dart';
import 'session.dart';
import 'theme.dart';
import 'widgets.dart';

class DijigooApp extends ConsumerWidget {
  const DijigooApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(sessionProvider).phase;
    final page = switch (phase) {
      AppPhase.onboard => const OnboardScreen(),
      AppPhase.splash => const SplashScreen(),
      AppPhase.activation => const ActivationScreen(),
      AppPhase.permissions => const PermissionsScreen(),
      AppPhase.shift => const ShiftScreen(),
      AppPhase.main => const ShellScreen(),
    };
    return MaterialApp(
      title: 'JetLogi Kurye',
      debugShowCheckedModeBanner: false,
      locale: const Locale('tr'),
      theme: Dg.theme(),
      builder: (context, child) => PhoneShell(child: child ?? const SizedBox.shrink()),
      home: page,
    );
  }
}
