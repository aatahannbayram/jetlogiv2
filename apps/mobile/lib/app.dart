import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n.dart';
import 'motion.dart';
import 'screens/activation_screen.dart';
import 'screens/onboard_screen.dart';
import 'screens/permissions_screen.dart';
import 'screens/shell_screen.dart';
import 'screens/shift_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/sube_shell_screen.dart';
import 'session.dart';
import 'theme.dart';
import 'widgets.dart';

class DijigooApp extends ConsumerWidget {
  const DijigooApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kök yalnız tema, dil, depolama ve aşama değişince yeniden kurulur;
    // oturumdaki diğer her bildirim yalnız onu izleyen ekranları yeniler.
    final dark = ref.watch(sessionProvider.select((s) => s.darkModeUi));
    final localeCode = ref.watch(sessionProvider.select((s) => s.localeCode));
    final phase = ref.watch(sessionProvider.select((s) => s.phase));
    final storageOk = ref.watch(sessionProvider.select((s) => s.storageOk));
    Dg.dark = dark;
    final l10n = L10n(localeCode);
    if (!storageOk) {
      return L10nScope(
        l10n: l10n,
        child: MaterialApp(
          title: 'Dijigoo',
          debugShowCheckedModeBanner: false,
          locale: Locale(localeCode),
          theme: Dg.theme(),
          home: const _StorageLockedPage(),
        ),
      );
    }
    final page = switch (phase) {
      AppPhase.onboard => const OnboardScreen(),
      AppPhase.splash => const SplashScreen(),
      AppPhase.activation => const ActivationScreen(),
      AppPhase.permissions => const PermissionsScreen(),
      AppPhase.shift => const ShiftScreen(),
      AppPhase.main => const ShellScreen(),
      AppPhase.subeMain => const SubeShellScreen(),
    };
    return L10nScope(
      l10n: l10n,
      child: MaterialApp(
        title: 'Dijigoo',
        debugShowCheckedModeBanner: false,
        locale: Locale(localeCode),
        supportedLocales: const [Locale('tr'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: Dg.theme(),
        builder: (context, child) => MotionScope(
          child: PhoneShell(child: child ?? const SizedBox.shrink()),
        ),
        home: AnimatedSwitcher(
          duration: DgMotion.emphasized,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: dgSwitchTransition,
          child: KeyedSubtree(key: ValueKey(phase), child: page),
        ),
      ),
    );
  }
}

class _StorageLockedPage extends StatelessWidget {
  const _StorageLockedPage();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Dg.night,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 48, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.storageLockedTitle,
                style: Dg.serif(
                  size: 28,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l.storageLockedBody,
                style: const TextStyle(
                  color: Color(0xFFE0D5EF),
                  fontSize: 16,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
