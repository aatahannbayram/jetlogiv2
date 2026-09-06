import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Saha uygulaması design tokens.
///
/// [Dg]'nin renk alanları artık `static const` değil, `static Color get` —
/// çünkü aynı isim (`Dg.ink`, `Dg.surface`, ...) hem koyu hem açık temada
/// geçerli kalsın istedik: her çağrı yerini `Theme.of(context)` kullanacak
/// şekilde yeniden yazmak (100+ yer) yerine, [Dg.dark] bayrağını
/// [DijigooApp.build] içinde `s.darkModeUi`'ye göre bir kez set ediyoruz;
/// mevcut her `Dg.xxx` referansı otomatik doğru temayı okur. Bedeli:
/// `const BoxDecoration(color: Dg.ink)` gibi compile-time-const kullanımlar
/// artık derlenmez — `const` anahtar kelimesi kaldırılmalı (flutter analyze
/// bunları tek tek gösterir).
class Dg {
  Dg._();

  /// [DijigooApp.build] her rebuild'de `s.darkModeUi`'den set eder.
  static bool dark = true;

  // ---- Zemin / yüzey ----
  /// Koyu tema: saf #000 + #737373 ikincil metin WCAG 2.2 SC 1.4.3'ü
  /// (~4.1:1) kaçırıyordu. Material 3 yüzey tonu (#121212) + iOS grouped
  /// #1C1C1E; saf siyah/beyaz parlamayı ve okunaksız griyi keser.
  /// https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html
  /// https://m3.material.io/styles/color/system/overview
  static Color get ground =>
      dark ? const Color(0xFF121212) : const Color(0xFFF4F4F5);
  static Color get surface =>
      dark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);

  /// İkinci kademe yüzey (surface üstünde surface — skeleton, track, vb.)
  static Color get elev =>
      dark ? const Color(0xFF2C2C2E) : const Color(0xFFEEEEEE);

  // ---- Metin ----
  static Color get ink =>
      dark ? const Color(0xFFF5F5F7) : const Color(0xFF111111);
  static Color get ink2 =>
      dark ? const Color(0xFFC7C7CC) : const Color(0xFF5C5C5C);
  static Color get ink3 =>
      dark ? const Color(0xFFA1A1AA) : const Color(0xFF6B6B6B);
  static Color get rule =>
      dark ? const Color(0xFF3A3A3C) : const Color(0xFFE4E4E7);

  /// Koşulsuz koyu — temadan bağımsız gerçek siyah/gece yüzeyler için
  /// (giriş/tören ekranı gradyanının tabanı, PhoneShell çerçevesi).
  static const night = Color(0xFF0C0C0F);

  // ---- Marka moru ----
  /// Birincil eylem gradyanı — buton/CTA ve seçili halka.
  /// Pastel lila yerine doygun, koyu zeminle uyumlu marka moru.
  static const primaryGradientStart = Color(0xFF6B46D4);
  static const primaryGradientEnd = Color(0xFF3F1F8C);
  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryGradientStart, primaryGradientEnd],
  );

  /// Aktif/seçili durum vurgusu (sekme, adım noktası, seçili kart kenarı).
  static const purpleActive = Color(0xFF8B6AE8);

  /// Giriş/tören ekranı zemin gradyanı (üstten alta).
  static LinearGradient get heroGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: dark
        ? const [Color(0xFF4B268F), Color(0xFF2A1360), Color(0xFF150A2E)]
        : const [Color(0xFFEDE4FF), Color(0xFFF7F4FF), Color(0xFFF4F3F0)],
  );
  static const heroAccentOrange = Color(0xFFF08A24);

  static Color get onHero => dark ? Colors.white : ink;
  static Color get onHeroMuted =>
      dark ? const Color(0xFFCBBEEE) : ink2;

  /// Giriş/tören ekranındaki cam-efekti kart yüzeyi.
  static Color get heroGlass =>
      dark ? const Color(0x80140A2A) : const Color(0xF2FFFFFF);

  // Legacy brand-purple isimleri — hâlâ referans veren yerler (menü ikon
  // rozetleri, harita polyline'ı, hero kart zemini gibi "marka moru" ama
  // "birincil eylem gradyanı" olmayan kullanımlar) için korunuyor.
  static const purple = Color(0xFF7C5CE0);
  static const purpleDeep = Color(0xFF4E2CB8);
  static const purpleBright = Color(0xFFB8A0F0);
  static const accent = primaryGradientStart;
  static const accentSoft = Color(0xFFEAF6B8);

  // ---- Durum vurguları: 6px nokta + nötr metin, dolgulu rozet yok ----
  /// Olumlu / tamamlandı (ör. teslim edildi, doğrulandı).
  static const sage = Color(0xFF7FB097);

  /// Bekleyen / nötr-uyarı (ör. sırada, SLA yaklaşıyor).
  static const sand = Color(0xFFD2AE78);

  /// Olumsuz / başarısız (ör. teslim edilemedi, kod doğrulanamadı).
  static const clay = Color(0xFFC57C71);

  // Eski hi/mid/lo isimleri — status olmayan (hata metni, ikon tint'i gibi)
  // kullanım yerleri için korunuyor; yeni status göstergeleri sage/sand/clay
  // kullanmalı.
  static Color get hi => clay;
  static Color get hiBg =>
      dark ? const Color(0x1AC57C71) : const Color(0xFFF8E4E1);
  static Color get mid => sand;
  static Color get midBg =>
      dark ? const Color(0x1AD2AE78) : const Color(0xFFF6EBD2);
  static Color get lo => sage;
  static Color get loBg =>
      dark ? const Color(0x1A7FB097) : const Color(0xFFDCEFD8);
  static const glow = primaryGradientStart;

  // Design-token tints for menu/notification icon badges — koyu temada
  // tint arka planı %10 alpha'ya düşer, ink rengi olduğu gibi kalır.
  static const violet = Color(0xFFB794F6);
  static Color get violetBg =>
      dark ? const Color(0x2EB794F6) : const Color(0xFFF3F0FB);
  static const blue = Color(0xFF4A7FD8);
  static Color get blueBg =>
      dark ? const Color(0x1A4A7FD8) : const Color(0xFFEEF4FF);
  static const amber = Color(0xFFE8A33D);
  static Color get amberBg =>
      dark ? const Color(0x1AE8A33D) : const Color(0xFFFFF6E6);
  static const green = Color(0xFF4E9B4E);
  static Color get greenBg =>
      dark ? const Color(0x1A4E9B4E) : const Color(0xFFEDF6EC);
  static const red = Color(0xFFD8543C);
  static Color get redBg =>
      dark ? const Color(0x1AD8543C) : const Color(0xFFFDEEEA);

  // ---- Tipografi ----
  static const display = 'Geist';
  static const sans = 'Geist';
  static const statFamily = 'Geist';
  static const mono = 'Geist Mono';

  // ---- Radius: Uber/IG — küçük köşe, yüzen “AI kartı” yok ----
  static const radiusPhone = 46.0;
  static const radiusHero = 14.0;
  static const radius = 8.0;
  static const radiusPill = 10.0;

  /// Yatay içerik — 16px (Material / iOS grouped inset); 20px satırları daraltıyordu.
  static const pagePad = 16.0;

  /// Saha dokunma hedefi. Apple HIG 44pt, Material 48dp; eldiven/araç için 56.
  static const rowMin = 56.0;

  /// İçerik, alt tab bar'ın bu kadar üstünde bitmeli (ör. son elemana
  /// `SizedBox(height: Dg.bottomNavClearance)` veya liste `padding.bottom`).
  static const bottomNavClearance = 76.0;

  /// Kartlar artık gölgeyle yüzmüyor — Instagram/Uber satır dili.
  static const shadow = <BoxShadow>[];

  static const shadowHero = <BoxShadow>[];

  /// Kartın üst kenarına eklenen 1px inset beyaz ışık — [DgCard] bunu
  /// `Container`'ın `foregroundDecoration`'ında bir üst-kenar `Border` ile
  /// simüle eder (Flutter'ın `BoxShadow`'u gerçek inset desteklemiyor).
  static const insetHighlight = Color(0x1FFFFFFF);

  static TextStyle serif({
    double size = 34,
    FontWeight weight = FontWeight.w700,
    Color? color,
    bool italic = false,
    double height = 1.04,
    double letterSpacing = -0.03,
  }) {
    return TextStyle(
      fontFamily: display,
      fontSize: size,
      fontWeight: weight,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      color: color ?? ink,
      height: height,
      // letterSpacing brief'te "em" cinsinden (-.03em) verildi; Flutter
      // mutlak px bekliyor, punto başına ölçekliyoruz.
      letterSpacing: size * letterSpacing,
      fontVariations: [FontVariation('wght', _wght(weight))],
    );
  }

  static TextStyle ui({
    double size = 16,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double height = 1.35,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: sans,
      fontSize: size,
      fontWeight: weight,
      color: color ?? ink,
      height: height,
      letterSpacing: letterSpacing,
      fontVariations: [FontVariation('wght', _wght(weight))],
    );
  }

  /// Büyük rakamlar (kazanç, ETA, stat kutuları) — `tabular-nums` ile
  /// hizalı, sabit genişlikli rakamlar.
  static TextStyle stat({
    double size = 28,
    FontWeight weight = FontWeight.w700,
    Color? color,
    double height = 1.0,
    double letterSpacing = -0.02,
  }) {
    return TextStyle(
      fontFamily: statFamily,
      fontSize: size,
      fontWeight: weight,
      color: color ?? ink,
      height: height,
      letterSpacing: size * letterSpacing,
      fontFeatures: const [FontFeature.tabularFigures()],
      fontVariations: [FontVariation('wght', _wght(weight))],
    );
  }

  static TextStyle kicker({Color? color}) {
    return ui(
      size: 11,
      weight: FontWeight.w600,
      color: color ?? ink3,
      letterSpacing: 1.4,
      height: 1.2,
    );
  }

  static double _wght(FontWeight w) => w.value.toDouble();

  static ThemeData theme() {
    final text = TextTheme(
      displaySmall: serif(size: 36),
      headlineMedium: serif(size: 26, letterSpacing: -0.03),
      titleLarge: ui(
        size: 17,
        weight: FontWeight.w600,
        color: ink,
        height: 1.25,
      ),
      bodyLarge: ui(size: 16, color: ink2),
      bodyMedium: ui(size: 15, color: ink2),
      labelLarge: ui(
        size: 16,
        weight: FontWeight.w700,
        color: dark ? night : Colors.white,
        height: 1.1,
      ),
      labelMedium: ui(size: 12, weight: FontWeight.w600, color: ink2),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      fontFamily: sans,
      colorScheme: ColorScheme(
        brightness: dark ? Brightness.dark : Brightness.light,
        primary: primaryGradientStart,
        onPrimary: Colors.white,
        secondary: purpleActive,
        onSecondary: dark ? night : Colors.white,
        surface: surface,
        onSurface: ink,
        error: clay,
        onError: Colors.white,
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
      // Düz renk (gradyan başlangıcı) — asıl mor gradyan, en öne çıkan
      // birkaç "hero" CTA'da (SlideToAct, splash) doğrudan [Dg.primaryGradient]
      // ile ayrıca uygulanıyor; her yerdeki FilledButton için gradyan
      // render etmek pratik değil (ripple/disabled state karmaşıklaşır).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryGradientStart,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primaryGradientStart.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
          textStyle: ui(
            size: 15,
            weight: FontWeight.w700,
            color: Colors.white,
            height: 1.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          backgroundColor: surface,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          side: BorderSide(color: rule),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
          textStyle: ui(size: 15, weight: FontWeight.w700, height: 1.1),
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
          borderRadius: BorderRadius.circular(radiusHero),
          borderSide: BorderSide(color: rule),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusHero),
          borderSide: BorderSide(color: rule),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusHero),
          borderSide: BorderSide(color: primaryGradientStart, width: 1.5),
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
