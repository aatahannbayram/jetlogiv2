import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Kurye ve şube ekranlarının ortak görsel sistemi.
/// Renkler uygulamanın kayıtlı açık/koyu tema tercihinden okunur.
class Dg {
  Dg._();

  /// [DijigooApp.build] her rebuild'de `s.darkModeUi`'den set eder.
  static bool dark = true;

  // ---- Zemin / yüzey ----
  /// Sıcak taş yüzeyler ve kömür tonları; turuncu yalnız eylem ve vurgu için.
  /// İkincil metin her iki temada da okunaklı kalır.
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
  static const night = Color(0xFF202422);
  static const onNight = Color(0xFFF8F5F0);
  static const mutedOnNight = Color(0xFFD2D7D3);
  // Logodaki turuncu.
  static const action = Color(0xFFFF8A1E);
  static const onAction = Color(0xFF101010);
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
  /// Sakin yüzeyler üzerinde sıcak turuncu eylem vurgusu.
  static Color get primaryGradientStart => action;
  static Color get primaryGradientEnd => heroAccentOrange;
  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFA63D), Color(0xFFFF8A1E), Color(0xFFF5740A)],
  );

  // Persistent charcoal dock, independent of the content theme.
  static const dock = Color(0xFF202422);
  static const onDock = Color(0xFFF7F4EE);
  static const mutedOnDock = Color(0xFFC9C4BB);
  // Seçili sekme beyaz; turuncu yalnız alt çizgide.
  static const dockActive = Color(0xFFF7F4EE);
  static const dockSelected = Color(0xFF3D332A);

  static Color get purpleActive => brand;

  /// Giriş/tören ekranı zemin gradyanı (üstten alta).
  static LinearGradient get heroGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: dark
        ? const [Color(0xFF2D3330), Color(0xFF252A27), Color(0xFF202422)]
        : const [Color(0xFFF0F2EB), Color(0xFFF8F9F5), Color(0xFFF5F5F2)],
  );
  static const heroAccentOrange = Color(0xFFFF8A1E);
  static const emberGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFFFA63D), Color(0xFFFF8A1E), Color(0xFFF5740A)],
  );

  static Color get onHero => dark ? Colors.white : ink;
  static Color get onHeroMuted => dark ? const Color(0xFFD2D7D3) : ink2;

  /// Giriş/tören ekranındaki cam-efekti kart yüzeyi.
  static Color get heroGlass =>
      dark ? const Color(0xCC242320) : const Color(0xF2FFFFFF);

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
  static Color get violet => plum;
  static Color get violetBg => plumSoft;
  static Color get blue => plum;
  static Color get blueBg => plumSoft;
  static Color get amber => warn;
  static Color get amberBg => warnSoft;
  static Color get green => ok;
  static Color get greenBg => ok.withValues(alpha: 0.12);
  static Color get red => bad;
  static Color get redBg => bad.withValues(alpha: 0.12);

  // ---- Tipografi ----
  // Başlık, gövde ve rakamlar Inter (değişken yazı tipi: kalınlık ve optik
  // boyut eksenleri). Gönderi no ve saat gibi tek aralıklı yazılar Geist Mono.
  static const display = 'Inter';
  static const sans = 'Inter';
  static const statFamily = 'Inter';
  static const mono = 'Geist Mono';

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

  /// Kartlar artık gölgeyle yüzmüyor — Instagram/Uber satır dili.
  static const shadow = <BoxShadow>[];

  static const shadowHero = <BoxShadow>[];

  /// Kartın üst kenarına eklenen 1px inset beyaz ışık — [DgCard] bunu
  /// `Container`'ın `foregroundDecoration`'ında bir üst-kenar `Border` ile
  /// simüle eder (Flutter'ın `BoxShadow`'u gerçek inset desteklemiyor).
  static const insetHighlight = Color(0x1FFFFFFF);

  // ---- Kurye ve şube için ortak taş–kömür saha paleti ----
  static Color get bg =>
      dark ? const Color(0xFF111312) : const Color(0xFFF1F1EC);
  static Color get surface1 =>
      dark ? const Color(0xFF1C1F1E) : const Color(0xFFFAFAF7);
  static Color get surface2 =>
      dark ? const Color(0xFF292D2B) : const Color(0xFFEBEEEA);
  static Color get stroke =>
      dark ? const Color(0xFF8C8B82) : const Color(0xFF807B72);
  static Color get text1 =>
      dark ? const Color(0xFFFCFAF6) : const Color(0xFF101010);
  static Color get text2 =>
      dark ? const Color(0xFFD2D7D3) : const Color(0xFF4A4A4A);
  static Color get text3 =>
      dark ? const Color(0xFFB4BCB6) : const Color(0xFF5A635D);
  static Color get brand =>
      dark ? const Color(0xFFFF962E) : const Color(0xFFB04400);

  /// Uyarı / bekleyen: markadan ayrışsın diye kehribar.
  static Color get warn =>
      dark ? const Color(0xFFFFCB52) : const Color(0xFF8A5A00);

  /// Logodaki mor: ikincil vurgu (ikon rozetleri, bilgi etiketleri).
  static Color get plum =>
      dark ? const Color(0xFFB79BFF) : const Color(0xFF6A3FB5);
  static Color get plumSoft => plum.withValues(alpha: dark ? 0.16 : 0.10);
  static Color get ok =>
      dark ? const Color(0xFF4ADE80) : const Color(0xFF0F7A3C);

  /// Olumsuz metin ve düğmeler: belirgin kırmızı.
  static Color get bad =>
      dark ? const Color(0xFFFF6666) : const Color(0xFFCC1F1F);

  /// Neon mor: harita üstündeki rota etiketi gibi bilgi vurguları.
  static const neon = Color(0xFF7C4DFF);
  static const onNeon = Color(0xFFFFFFFF);
  static Color get hairline =>
      dark ? const Color(0x0FFFFFFF) : const Color(0x0F000000);

  /// Legacy decorative edge: subtle and separate from control outlines.
  static Color get cardEdge => hairline;
  static Color get warnSoft => warn.withValues(alpha: 0.12);
  static Color get brandSoft => brand.withValues(alpha: 0.12);
  static Color get muteSoft =>
      dark ? const Color(0xFF2D302F) : const Color(0xFFEBEEEA);

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
      fontFamilyFallback: const ['Geist'],
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
      fontFamilyFallback: const ['Geist'],
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
      fontFamilyFallback: const ['Geist'],
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
        selectedColor: warnSoft,
        showCheckmark: false,
        labelStyle: ui(size: 14, weight: FontWeight.w600, color: ink),
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
