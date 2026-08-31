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
    final session = ref.watch(sessionProvider);
    // Dg's color getters read this flag directly (see theme.dart) — set it
    // before building anything so the whole tree picks up the right theme
    // in one pass, no per-widget Theme.of(context) plumbing needed.
    Dg.dark = session.darkModeUi;
    final phase = session.phase;
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
      builder: (context, child) =>
          PhoneShell(child: child ?? const SizedBox.shrink()),
      home: page,
    );
  }
}
