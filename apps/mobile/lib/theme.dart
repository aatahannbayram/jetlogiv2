import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Saha uygulaması: açık zemin, mor vurgu (JetLogi marka rengi #614293), siyah hap.
class Dg {
  static const ground = Color(0xFFF4F5F0);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF121212);
  static const ink2 = Color(0xFF5F6357);
  static const ink3 = Color(0xFF8B8F82);
  static const rule = Color(0xFFE3E6DC);
  static const elev = Color(0xFFF0F1EA);

  /// Primary brand purple — matches jetlogi.com's dominant button/heading
  /// color. Medium-dark: pairs with white text/icons, not black.
  static const purple = Color(0xFF614293);

  /// Darker purple for borders/pressed states and as text/icon color on
  /// light surfaces (small badges, links, checkmarks).
  static const purpleDeep = Color(0xFF4A3373);

  /// Lighter, more luminant purple — used instead of [purple]/[purpleDeep]
  /// wherever the accent sits directly on a near-black background (the
  /// bottom nav pill, dark hero cards), since the brand purple's contrast
  /// against black is too low there.
  static const purpleBright = Color(0xFFAF93DC);
  static const accent = Color(0xFF121212);
  static const accentSoft = Color(0xFFEAF6B8);
  static const hi = Color(0xFFC23B32);
  static const hiBg = Color(0xFFF8E4E1);
  static const mid = Color(0xFF9A6B12);
  static const midBg = Color(0xFFF6EBD2);
  static const lo = Color(0xFF2F6A3A);
  static const loBg = Color(0xFFDCEFD8);
  static const night = Color(0xFF121212);
  static const glow = Color(0xFF614293);

  // Design-token tints for menu/notification icon badges.
  static const violet = Color(0xFF7B5AC2);
  static const violetBg = Color(0xFFF3F0FB);
  static const blue = Color(0xFF4A7FD8);
  static const blueBg = Color(0xFFEEF4FF);
  static const amber = Color(0xFFE8A33D);
  static const amberBg = Color(0xFFFFF6E6);
  static const green = Color(0xFF4E9B4E);
  static const greenBg = Color(0xFFEDF6EC);
  static const red = Color(0xFFD8543C);
  static const redBg = Color(0xFFFDEEEA);

  static const display = 'Newsreader';
  static const sans = 'Inter';
  static const statFamily = 'Archivo';
  static const mono = 'IBMPlexMono';

  static const radius = 22.0;
  static const radiusHero = 28.0;
  static const radiusPill = 32.0;

  // Contact shadow stays neutral black (grounds the card against the page);
  // the soft ambient layer is tinted with the brand purple instead of flat
  // black — a common "premium" cue, and cheap here since it's just a color
  // swap on an existing two-layer recipe.
  static const shadow = [
    BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x14614293), blurRadius: 24, offset: Offset(0, 12)),
  ];

  static const shadowHero = [
    BoxShadow(color: Color(0x1E000000), blurRadius: 8, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x30614293), blurRadius: 36, offset: Offset(0, 18)),
  ];

  static TextStyle serif({
    double size = 34,
    FontWeight weight = FontWeight.w600,
    Color color = ink,
    bool italic = false,
    double height = 1.04,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: display,
      fontSize: size,
      fontWeight: weight,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontVariations: [
        FontVariation('opsz', size.clamp(14, 32)),
        FontVariation('wght', _wght(weight)),
      ],
    );
  }

  static TextStyle ui({
    double size = 16,
    FontWeight weight = FontWeight.w500,
    Color color = ink,
    double height = 1.35,
    double letterSpacing = 0.05,
  }) {
    return TextStyle(
      fontFamily: sans,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontVariations: [
        FontVariation('opsz', size.clamp(14, 32)),
        FontVariation('wght', _wght(weight)),
      ],
    );
  }

  /// Big numerals (earnings, ETA, stat tiles) — Archivo's `wdth` axis pulled
  /// in slightly narrower than 100 for a denser, more "engineered" numeral
  /// feel distinct from both [display] and [ui].
  static TextStyle stat({
    double size = 28,
    FontWeight weight = FontWeight.w700,
    Color color = ink,
    double width = 92,
    double height = 1.0,
    double letterSpacing = -0.2,
  }) {
    return TextStyle(
      fontFamily: statFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontVariations: [
        FontVariation('wght', _wght(weight)),
        FontVariation('wdth', width),
      ],
    );
  }

  static TextStyle kicker({Color color = ink3}) {
    return ui(size: 11, weight: FontWeight.w600, color: color, letterSpacing: 1.4, height: 1.2);
  }

  static double _wght(FontWeight w) => w.value.toDouble();

  static ThemeData theme() {
    final text = TextTheme(
      displaySmall: serif(size: 36, weight: FontWeight.w600),
      headlineMedium: serif(size: 26, weight: FontWeight.w600, letterSpacing: -0.2),
      titleLarge: ui(size: 17, weight: FontWeight.w600, color: ink, height: 1.25),
      bodyLarge: ui(size: 16, color: ink2),
      bodyMedium: ui(size: 15, color: ink2),
      labelLarge: ui(size: 16, weight: FontWeight.w700, color: Colors.white, height: 1.1),
      labelMedium: ui(size: 12, weight: FontWeight.w600, color: ink2),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: sans,
      // primary/secondary keep this app's actual brand colors (ink = the
      // real CTA color, purple = accent — see Dg.purple's doc comment); only
      // the on* pairs were wrong before (onPrimary/onSecondary must be the
      // text/icon color drawn *on top of* primary/secondary, not each other).
      colorScheme: const ColorScheme.light(
        primary: ink,
        onPrimary: Colors.white,
        secondary: purple,
        onSecondary: Colors.white,
        surface: surface,
        onSurface: ink,
        error: hi,
      ),
      scaffoldBackgroundColor: ground,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: ground,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: serif(size: 20, weight: FontWeight.w600),
      ),
      dividerColor: rule,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0x55121212),
          disabledForegroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
          textStyle: ui(size: 16, weight: FontWeight.w700, color: Colors.white, height: 1.1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size.fromHeight(56),
          side: const BorderSide(color: Color(0xFFC9CCC3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
          textStyle: ui(size: 16, weight: FontWeight.w600, height: 1.1),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ink,
          textStyle: ui(size: 15, weight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: ui(size: 14, color: ink3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: rule),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: rule),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: ink, width: 1.5),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
