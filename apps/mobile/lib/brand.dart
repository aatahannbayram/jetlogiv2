import 'package:flutter/material.dart';

/// Dijigoo marka varlıkları — Kurumsal Kimlik Kılavuzu 5.2'den birebir
/// çıkarılmış görseller (`assets/brand/`). Kurallar:
/// - Ana logo yalnız "Dijig" yazısı + sonsuzluk; önüne D ikonu eklenmez.
/// - Logo yeniden çizilmez, döndürülmez, renk geçişi yeniden üretilmez;
///   hareket gerekiyorsa bütün olarak yalnız opaklık/ölçek.
/// - Dijital minimum: ana logo 120 px genişlik, D ikonu 24 px.
/// - Koruma alanı x = D harfi yüksekliğinin 1/4'ü.

/// Bağımsız D ikonu — avatar, dar yuvalar, bildirim/boş durum.
class DijigooMark extends StatelessWidget {
  const DijigooMark({super.key, this.size = 28, this.onDark = false});

  /// Minimum 24 (kılavuz s.6).
  final double size;

  /// D ikonu her iki zeminde aynıdır; parametre eski çağrılar için duruyor.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final s = size < 24 ? 24.0 : size;
    return SizedBox(
      width: s,
      height: s,
      child: Image.asset(
        'assets/brand/d_mark.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        semanticLabel: 'Dijigoo',
      ),
    );
  }
}

/// Ana logo (yazı + sonsuzluk). [onDark] koyu zeminde beyaz, açık zeminde
/// lacivert harfli varyantı seçer (kılavuz s.7). [height] logonun kendi
/// yüksekliğidir; koruma alanı [withClearSpace] ile dışa eklenir.
class DijigooWordmark extends StatelessWidget {
  const DijigooWordmark({
    super.key,
    this.height = 28,
    this.onDark = false,
    this.showName = true,
    this.withClearSpace = false,
  });

  /// Görselin en/boy oranı (çıkarılan varlıktan).
  static const aspect = 2734 / 775;

  /// 120 px genişliğe karşılık gelen en küçük yükseklik.
  static const minHeight = 120 / aspect;

  final double height;
  final bool onDark;

  /// Eski API; lockup her zaman isimle birlikte tek görsel.
  final bool showName;
  final bool withClearSpace;

  @override
  Widget build(BuildContext context) {
    final h = height < minHeight ? minHeight : height;
    final logo = Image.asset(
      onDark
          ? 'assets/brand/wordmark_white.png'
          : 'assets/brand/wordmark_navy.png',
      height: h,
      width: h * aspect,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Dijigoo',
    );
    if (!withClearSpace) return logo;
    // D harfi logonun ~%60'ı; x = onun 1/4'ü.
    return Padding(padding: EdgeInsets.all(h * 0.6 / 4), child: logo);
  }
}

/// Önceden üretilmiş mor → mavi → turkuaz ışık dalgası (yardımcı grafik).
/// Çalışma zamanında blur/gradyan hesaplanmaz; tek görsel, yalnız transform.
class BrandWave extends StatelessWidget {
  const BrandWave({super.key, this.opacity = 1, this.alignment});

  final double opacity;
  final Alignment? alignment;

  @override
  Widget build(BuildContext context) {
    // Image.opacity katman (saveLayer) açmadan doğrudan boyar.
    return IgnorePointer(
      child: Image.asset(
        'assets/brand/wave.webp',
        fit: BoxFit.cover,
        alignment: alignment ?? Alignment.bottomRight,
        filterQuality: FilterQuality.low,
        excludeFromSemantics: true,
        opacity: opacity >= 1 ? null : AlwaysStoppedAnimation(opacity),
      ),
    );
  }
}
