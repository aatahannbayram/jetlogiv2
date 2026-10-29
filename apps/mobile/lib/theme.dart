import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Kurye ve şube ekranlarının ortak görsel sistemi — Dijigoo kurumsal
/// kimliği (Kılavuz 5.2): lacivert zemin, marka mavisi eylem, mor → mavi →
/// turkuaz yardımcı akış, tek yazı ailesi Inter.
/// Renkler uygulamanın kayıtlı açık/koyu tema tercihinden okunur.
class Dg {
  Dg._();

  /// [DijigooApp.build] her rebuild'de `s.darkModeUi`'den set eder.
  static bool dark = true;

  // ---- Zemin / yüzey ----
  /// Lacivert/beyaz yüzeyler; marka mavisi yalnız eylem ve vurgu için.
  /// İkincil metin her iki temada da okunaklı kalır (kontrast ≥ 4.5:1).
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
  static const night = Color(0xFF0A0F2B);
  static const onNight = Color(0xFFFFFFFF);
  static const mutedOnNight = Color(0xFFC5CAD3);
  static const action = Color(0xFF2563FF);
  static const onAction = Color(0xFFFFFFFF);

  // ---- Dijigoo kurumsal renkleri (Kılavuz s.9) ----
  static const navy = Color(0xFF0A0F2B);
  static const brandBlue = Color(0xFF2563FF);
  static const brandPurple = Color(0xFF8B5CF6);
  static const brandTurquoise = Color(0xFF06D6FF);

  /// Ana renk akışı (s.10): yardımcı grafik — sekme göstergesi, ince ayraç,
  /// ilerleme. Logoya uygulanmaz.
  static const brandFlow = LinearGradient(
    colors: [brandPurple, brandBlue, brandTurquoise],
  );

  /// Koyu temada vurgu metni için turkuaz (10.8:1), açıkta koyu marka mavisi.
  static Color get highlight => dark ? brandTurquoise : brand;

  /// Web dalındaki küçük vurgu rengi; Dijigoo'da turkuaz.
  static const orange = brandTurquoise;
  /// Dolu düğme renkleri: her temada aynı, üstünde beyaz kalın yazı.
  static const go = Color(0xFF16A34A);
  static const stop = Color(0xFFDC2F2F);
  static const touchMin = 48.0;
  static const buttonMin = 56.0;
  static Color get onStatus => dark ? night : Colors.white;

  /// Content is separated by spacing and tonal surfaces, without shadows.
  /// Koyu temada yüzeyler tonla ayrışır; açık temada kartlar tam beyaz
  /// yerine kırık beyazdır ve çok hafif bir gölgeyle zeminden kalkar.
  static List<BoxShadow> get cardShadow => dark
      ? const []
      : const [
          BoxShadow(
            color: Color(0x12202422),
            blurRadius: 24,
            offset: Offset(0, 8),
            spreadRadius: -6,
          ),
        ];
  static List<BoxShadow> get dockShadow => [
    BoxShadow(
      color: night.withValues(alpha: dark ? 0.40 : 0.12),
      blurRadius: 28,
      offset: const Offset(0, 6),
      spreadRadius: -4,
    ),
  ];

  // ---- Eylem ve vurgu ----
  /// Sakin yüzeyler üzerinde marka mavisi eylem vurgusu.
  static Color get primaryGradientStart => action;
  static Color get primaryGradientEnd => heroAccentOrange;
  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2563FF), Color(0xFF1F56E8), Color(0xFF1A49C9)],
  );

  // Temadan bağımsız lacivert dock.
  static const dock = Color(0xFF121936);
  static const onDock = Color(0xFFFFFFFF);
  static const mutedOnDock = Color(0xFF9CA3AF);
  static const dockActive = Color(0xFF06D6FF);
  static const dockSelected = Color(0xFF1E2A55);

  static Color get purpleActive => brand;

  /// Giriş/tören ekranı zemin gradyanı (üstten alta).
  static LinearGradient get heroGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: dark
        ? const [Color(0xFF131C4A), Color(0xFF0D1338), Color(0xFF0A0F2B)]
        : const [Color(0xFFE9EDFF), Color(0xFFF3F5FC), Color(0xFFF4F5F8)],
  );
  static const heroAccentOrange = brandBlue;
  /// Eylem gradyanı: her durağı beyaz metinle ≥ 4.5:1. Marka akışı
  /// (mor/turkuaz) metin taşımaz, bkz. [brandFlow].
  static const emberGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF2563FF), Color(0xFF1F56E8), Color(0xFF1A49C9)],
  );

  static Color get onHero => dark ? Colors.white : ink;
  static Color get onHeroMuted => dark ? const Color(0xFFC5CAD3) : ink2;

  /// Giriş/tören ekranındaki kart yüzeyi (blur yok, yarı opak dolgu).
  static Color get heroGlass =>
      dark ? const Color(0xE6121936) : const Color(0xF2FFFFFF);

  // Legacy brand-purple isimleri — hâlâ referans veren yerler (menü ikon
  // rozetleri, harita polyline'ı, hero kart zemini gibi "marka moru" ama
  // "birincil eylem gradyanı" olmayan kullanımlar) için korunuyor.
  static Color get purple => plum;
  static Color get purpleDeep => plum;
  static Color get purpleBright => plum;
  static Color get accent => plum;
  static Color get accentSoft => plumSoft;

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
  static Color get violet => dark ? const Color(0xFFA78BFA) : brandPurple;
  static Color get violetBg =>
      brandPurple.withValues(alpha: dark ? 0.18 : 0.12);
  static Color get blue => brand;
  static Color get blueBg => brandSoft;
  static Color get amber => warn;
  static Color get amberBg => warnSoft;
  static Color get green => ok;
  static Color get greenBg => ok.withValues(alpha: 0.12);
  static Color get red => bad;
  static Color get redBg => bad.withValues(alpha: 0.12);

  // ---- Tipografi ----
  // Kılavuz s.11: tek aile Inter (başlık SemiBold/Bold, gövde Regular,
  // buton Medium). Kod/barkod da Inter + sabit genişlikli rakam.
  static const display = 'Inter';
  static const sans = 'Inter';
  static const statFamily = 'Inter';
  static const mono = 'Inter';

  /// Inter'in optik boyut ekseni 14–32 aralığında; büyük başlıklarda harfler
  /// daha sıkı ve keskin, küçük metinde daha açık ve okunur çizilir.
  static double _opsz(double size) => size.clamp(14, 32).toDouble();

  // ---- Yumuşak kartlar ve kapsül düğmeler ----
  static const radiusPhone = 46.0;
  static const radiusHero = 24.0;
  static const radius = 18.0;
  static const radiusPill = 28.0;
  static const pagePad = 20.0;

  /// Saha dokunma hedefi. Apple HIG 44pt, Material 48dp; eldiven/araç için 56.
  static const rowMin = 56.0;

  /// İçerik, alt tab bar'ın bu kadar üstünde bitmeli (ör. son elemana
  /// `SizedBox(height: Dg.bottomNavClearance)` veya liste `padding.bottom`).
  static const bottomNavClearance = 76.0;

  /// Kartlar gölgeyle yüzmüyor; ton farkıyla ayrışıyor.
  static const shadow = <BoxShadow>[];

  static const shadowHero = <BoxShadow>[];

  /// Kartın üst kenarına eklenen 1px inset beyaz ışık — [DgCard] bunu
  /// `Container`'ın `foregroundDecoration`'ında bir üst-kenar `Border` ile
  /// simüle eder (Flutter'ın `BoxShadow`'u gerçek inset desteklemiyor).
  static const insetHighlight = Color(0x1FFFFFFF);

  // ---- Kurye ve şube için ortak lacivert saha paleti ----
  static Color get bg =>
      dark ? const Color(0xFF0A0F2B) : const Color(0xFFF4F5F8);
  static Color get surface1 =>
      dark ? const Color(0xFF121936) : const Color(0xFFFFFFFF);
  static Color get surface2 =>
      dark ? const Color(0xFF1A2244) : const Color(0xFFEDF0F6);
  static Color get stroke =>
      dark ? const Color(0xFF6B7591) : const Color(0xFF737C8C);
  static Color get text1 =>
      dark ? const Color(0xFFFFFFFF) : const Color(0xFF0A0F2B);
  static Color get text2 =>
      dark ? const Color(0xFFC5CAD3) : const Color(0xFF374151);
  static Color get text3 =>
      dark ? const Color(0xFF9CA3AF) : const Color(0xFF5B6472);
  static Color get brand =>
      dark ? const Color(0xFF5B8CFF) : const Color(0xFF1D4FE0);
  // Durum renkleri kılavuzda yok; her zaman ikon + metinle kullanılır.
  static Color get warn =>
      dark ? const Color(0xFFFBBF24) : const Color(0xFF9A4508);
  static Color get ok =>
      dark ? const Color(0xFF4ADE80) : const Color(0xFF136C37);
  static Color get bad =>
      dark ? const Color(0xFFF87171) : const Color(0xFFB91C1C);

  /// Mor: ikincil vurgu (ikon rozetleri, bilgi etiketleri) — marka moru.
  static Color get plum =>
      dark ? const Color(0xFFA78BFA) : const Color(0xFF6A3FB5);
  static Color get plumSoft => plum.withValues(alpha: dark ? 0.16 : 0.10);

  /// Harita üstündeki rota etiketi gibi bilgi vurguları: marka mavisi.
  static const neon = brandBlue;
  static const onNeon = Color(0xFFFFFFFF);
  static Color get hairline =>
      dark ? const Color(0x14FFFFFF) : const Color(0x140A0F2B);

  /// Legacy decorative edge: subtle and separate from control outlines.
  static Color get cardEdge => hairline;
  static Color get warnSoft => warn.withValues(alpha: 0.12);
  static Color get brandSoft => brand.withValues(alpha: 0.12);
  static Color get muteSoft =>
      dark ? const Color(0xFF1A2244) : const Color(0xFFEDF0F6);

  static const rSm = 10.0;
  static const rMd = 14.0;
  static const rLg = 24.0;
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
    weight: FontWeight.w700,
    color: color ?? text1,
    height: 1.2,
    letterSpacing: 20 * -0.02,
  );
  static TextStyle typeBody({
    Color? color,
    FontWeight weight = FontWeight.w500,
  }) => ui(size: 16, weight: weight, color: color ?? text1);
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
    double height = 1.12,
    double letterSpacing = -0.025,
  }) {
    return TextStyle(
      fontFamily: display,
      fontFamilyFallback: const ['Inter'],
      fontSize: size < 14 ? 14 : (size == 15 ? 16 : size),
      fontWeight: weight,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      color: color ?? ink,
      height: height,
      // letterSpacing brief'te "em" cinsinden (-.03em) verildi; Flutter
      // mutlak px bekliyor, punto başına ölçekliyoruz.
      letterSpacing: size * letterSpacing,
      fontVariations: [
        FontVariation('wght', _wght(weight)),
        FontVariation('opsz', _opsz(size)),
      ],
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
      fontFamilyFallback: const ['Inter'],
      fontSize: size < 14 ? 14 : (size == 15 ? 16 : size),
      fontWeight: weight,
      color: color ?? ink,
      height: height,
      // Harf aralığı verilmemişse boyuta göre: başlıklar sıkı, gövde normal.
      letterSpacing: letterSpacing != 0
          ? letterSpacing
          : size >= 20
          ? size * -0.02
          : size >= 17
          ? size * -0.012
          : 0,
      fontVariations: [
        FontVariation('wght', _wght(weight)),
        FontVariation('opsz', _opsz(size)),
      ],
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
      fontFamilyFallback: const ['Inter'],
      fontSize: size < 14 ? 14 : (size == 15 ? 16 : size),
      fontWeight: weight,
      color: color ?? ink,
      height: height,
      letterSpacing: size * letterSpacing,
      fontFeatures: const [FontFeature.tabularFigures()],
      fontVariations: [
        FontVariation('wght', _wght(weight)),
        FontVariation('opsz', _opsz(size)),
      ],
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
  }) => TextStyle(
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
      headlineMedium: serif(size: 26),
      titleLarge: ui(
        size: 18,
        weight: FontWeight.w700,
        color: ink,
        height: 1.25,
      ),
      bodyLarge: ui(size: 16, color: ink2),
      bodyMedium: ui(size: 16, color: ink2),
      labelLarge: ui(
        size: 16,
        weight: FontWeight.w700,
        color: onAction,
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
        primary: brand,
        onPrimary: dark ? night : Colors.white,
        secondary: purpleActive,
        onSecondary: dark ? night : Colors.white,
        surface: surface,
        onSurface: ink,
        error: clay,
        onError: onStatus,
      ),
      scaffoldBackgroundColor: ground,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(touchMin, touchMin),
          foregroundColor: ink,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: action,
        foregroundColor: onAction,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusPill)),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusHero)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: typeH2(),
        contentTextStyle: typeBody(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusHero),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface2,
        contentTextStyle: typeBody(),
        actionTextColor: brand,
        behavior: SnackBarBehavior.floating,
      ),
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: ground,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // Ekran başlığı: kalın ve sıkı, tek satırda.
        titleTextStyle: serif(size: 22, weight: FontWeight.w700, height: 1.2),
      ),
      dividerColor: hairline,
      // Material butonları da ortak eylem paletini kullanır.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: action,
          foregroundColor: onAction,
          disabledBackgroundColor: primaryGradientStart.withValues(alpha: 0.35),
          disabledForegroundColor: ink3,
          minimumSize: const Size.fromHeight(buttonMin),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
          textStyle: ui(
            size: 15,
            weight: FontWeight.w700,
            color: onAction,
            height: 1.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          backgroundColor: surface,
          minimumSize: const Size.fromHeight(buttonMin),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
          textStyle: ui(size: 15, weight: FontWeight.w700, height: 1.1),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brand,
          minimumSize: const Size(touchMin, touchMin),
          textStyle: ui(size: 15, weight: FontWeight.w600),
        ),
      ),
      // Süzgeç çipleri çerçevesiz; seçili olan dolgu rengiyle ayrışır.
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        backgroundColor: surface2,
        // Seçili filtre ters renkli hap; sekmelerle aynı dil.
        selectedColor: ink,
        showCheckmark: false,
        labelStyle: ui(size: 14, weight: FontWeight.w600).copyWith(
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected) ? ground : ink,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface2,
        labelStyle: ui(size: 14, color: ink2),
        hintStyle: ui(size: 16, color: ink3),
        constraints: const BoxConstraints(minHeight: buttonMin),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        // Çerçevesiz, dolgulu alan; yalnız odaktayken ince vurgu çizgisi.
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusHero),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusHero),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusHero),
          borderSide: BorderSide(color: ink3, width: 1.2),
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
