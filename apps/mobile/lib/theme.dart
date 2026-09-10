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
  static Color get ground => bg;
  static Color get surface => surface1;
  static Color get elev => surface2;
  static Color get ink => text1;
  static Color get ink2 => text2;
  static Color get ink3 => text3;
  static Color get rule => stroke;

  /// Koşulsuz koyu — temadan bağımsız gerçek siyah/gece yüzeyler için
  /// (giriş/tören ekranı gradyanının tabanı, PhoneShell çerçevesi).
  static const night = Color(0xFF0C0C0F);

  // ---- Marka moru ----
  /// Birincil eylem gradyanı — buton/CTA ve seçili halka.
  /// Pastel lila yerine doygun, koyu zeminle uyumlu marka moru.
  static Color get primaryGradientStart => brand;
  static Color get primaryGradientEnd => warn;
  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7B61FF), Color(0xFFFF7A2F)],
  );

  static Color get purpleActive => brand;

  /// Giriş/tören ekranı zemin gradyanı (üstten alta).
  static LinearGradient get heroGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: dark
        ? const [Color(0xFF4B268F), Color(0xFF2A1360), Color(0xFF150A2E)]
        : const [Color(0xFFEDE4FF), Color(0xFFF7F4FF), Color(0xFFF4F3F0)],
  );
  static const heroAccentOrange = Color(0xFFF08A24);
  static const emberGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFFFC15A), Color(0xFFF08A24), Color(0xFFE07010)],
  );

  static Color get onHero => dark ? Colors.white : ink;
  static Color get onHeroMuted =>
      dark ? const Color(0xFFCBBEEE) : ink2;

  /// Giriş/tören ekranındaki cam-efekti kart yüzeyi.
  static Color get heroGlass =>
      dark ? const Color(0x80140A2A) : const Color(0xF2FFFFFF);

  // Legacy brand-purple isimleri — hâlâ referans veren yerler (menü ikon
  // rozetleri, harita polyline'ı, hero kart zemini gibi "marka moru" ama
  // "birincil eylem gradyanı" olmayan kullanımlar) için korunuyor.
  static Color get purple => brand;
  static Color get purpleDeep => brand;
  static Color get purpleBright => brand;
  static Color get accent => brand;
  static const accentSoft = Color(0xFFEAF6B8);

  // ---- Durum vurguları: 6px nokta + nötr metin, dolgulu rozet yok ----
  /// Olumlu / tamamlandı (ör. teslim edildi, doğrulandı).
  static Color get sage => ok;
  static Color get sand => warn;
  static Color get clay => bad;

  // Eski hi/mid/lo isimleri — status olmayan (hata metni, ikon tint'i gibi)
  // kullanım yerleri için korunuyor; yeni status göstergeleri sage/sand/clay
  // kullanmalı.
  static Color get hi => bad;
  static Color get hiBg => bad.withValues(alpha: 0.12);
  static Color get mid => warn;
  static Color get midBg => warnSoft;
  static Color get lo => ok;
  static Color get loBg => ok.withValues(alpha: 0.12);
  static Color get glow => brand;

  // Design-token tints for menu/notification icon badges — koyu temada
  // tint arka planı %10 alpha'ya düşer, ink rengi olduğu gibi kalır.
  static Color get violet => brand;
  static Color get violetBg => brandSoft;
  static Color get blue => brand;
  static Color get blueBg => brandSoft;
  static Color get amber => warn;
  static Color get amberBg => warnSoft;
  static Color get green => ok;
  static Color get greenBg => ok.withValues(alpha: 0.12);
  static Color get red => bad;
  static Color get redBg => bad.withValues(alpha: 0.12);

  // ---- Tipografi ----
  static const display = 'Geist';
  static const sans = 'Geist';
  static const statFamily = 'Geist';
  static const mono = 'Geist Mono';

  // ---- Radius: Uber/IG — küçük köşe, yüzen “AI kartı” yok ----
  static const radiusPhone = 46.0;
  static const radiusHero = 20.0;
  static const radius = 14.0;
  static const radiusPill = 14.0;
  static const pagePad = 20.0;

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

  // ---- Yeni görsel sistem (önce menü; diğer ekranlar sonra) ----
  static Color get bg =>
      dark ? const Color(0xFF0B0B0F) : const Color(0xFFF7F7F9);
  static Color get surface1 =>
      dark ? const Color(0xFF141419) : const Color(0xFFFFFFFF);
  static Color get surface2 =>
      dark ? const Color(0xFF1C1C23) : const Color(0xFFF1F1F4);
  static Color get stroke =>
      dark ? const Color(0xFF26262E) : const Color(0x14000000);
  static Color get text1 =>
      dark ? const Color(0xFFF5F5F7) : const Color(0xFF0B0B0F);
  static Color get text2 =>
      dark ? const Color(0xFFA1A1AA) : const Color(0xFF52525B);
  static Color get text3 =>
      dark ? const Color(0xFF6B6B76) : const Color(0xFF8A8A94);
  static Color get brand =>
      dark ? const Color(0xFF7B61FF) : const Color(0xFF7159EB);
  static Color get warn =>
      dark ? const Color(0xFFFF7A2F) : const Color(0xFFEA702B);
  static Color get ok =>
      dark ? const Color(0xFF22C55E) : const Color(0xFF1FB556);
  static Color get bad =>
      dark ? const Color(0xFFEF4444) : const Color(0xFFDC3E3E);
  static Color get hairline =>
      dark ? const Color(0x0FFFFFFF) : const Color(0x0F000000);
  static Color get warnSoft => warn.withValues(alpha: 0.12);
  static Color get brandSoft => brand.withValues(alpha: 0.12);
  static Color get muteSoft =>
      dark ? const Color(0xFF1C1C23) : const Color(0xFFF1F1F4);

  static const rSm = 10.0;
  static const rMd = 14.0;
  static const rLg = 20.0;
  static const s4 = 4.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
  static const s28 = 28.0;
  static const s32 = 32.0;
  static const menuRow = 64.0;

  static TextStyle typeH2({Color? color}) => ui(
    size: 20,
    weight: FontWeight.w600,
    color: color ?? text1,
    height: 1.2,
    letterSpacing: 20 * -0.01,
  );
  static TextStyle typeBody({Color? color, FontWeight weight = FontWeight.w500}) =>
      ui(size: 16, weight: weight, color: color ?? text1);
  static TextStyle typeLabel({Color? color}) =>
      ui(size: 14, weight: FontWeight.w500, color: color ?? text2);
  static TextStyle typeCaption({Color? color}) =>
      ui(size: 13, weight: FontWeight.w400, color: color ?? text3);
  static TextStyle typeOverline({Color? color}) => ui(
    size: 11,
    weight: FontWeight.w600,
    color: color ?? text3,
    letterSpacing: 11 * 0.08,
    height: 1.2,
  );
  static TextStyle typeNum({
    double size = 16,
    FontWeight weight = FontWeight.w500,
    Color? color,
  }) =>
      stat(size: size, weight: weight, color: color ?? text1, letterSpacing: 0);

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

  static String lucideFamily({int weight = 500}) => switch (weight) {
        100 => 'Lucide100',
        200 => 'Lucide200',
        300 => 'Lucide300',
        400 => 'Lucide400',
        600 => 'Lucide600',
        _ => 'Lucide500',
      };

  static TextStyle lucideStyle({
    required double size,
    Color? color,
    int weight = 500,
  }) =>
      TextStyle(
        fontFamily: lucideFamily(weight: weight),
        package: 'lucide_icons_flutter',
        fontSize: size,
        color: color,
        height: 1,
        leadingDistribution: TextLeadingDistribution.even,
      );

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
