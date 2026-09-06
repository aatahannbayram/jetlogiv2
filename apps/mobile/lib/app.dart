import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n.dart';
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
    Dg.dark = session.darkModeUi;
    final l10n = L10n(session.localeCode);
    final phase = session.phase;
    final page = switch (phase) {
      AppPhase.onboard => const OnboardScreen(),
      AppPhase.splash => const SplashScreen(),
      AppPhase.activation => const ActivationScreen(),
      AppPhase.permissions => const PermissionsScreen(),
      AppPhase.shift => const ShiftScreen(),
      AppPhase.main => const ShellScreen(),
    };
    return L10nScope(
      l10n: l10n,
      child: MaterialApp(
        title: 'JetLogi Kurye',
        debugShowCheckedModeBanner: false,
        locale: Locale(session.localeCode),
        supportedLocales: const [Locale('tr'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: Dg.theme(),
        builder: (context, child) =>
            PhoneShell(child: child ?? const SizedBox.shrink()),
        home: page,
      ),
    );
  }
}
