import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'scan.dart';

/// Çekim anındaki parlaklık / netlik ölçümü. Sunucuya `captureCheck` olarak
/// gider; `GOOD` olmayan fotoğraf ancak bir neden seçilerek kullanılır.
class CaptureQuality {
  const CaptureQuality({
    required this.quality,
    required this.brightness,
    required this.sharpness,
  });

  /// GOOD, DARK, BRIGHT, BLURRY.
  final String quality;

  /// Ortalama ışık, 0–255.
  final double brightness;

  /// Kenar keskinliği (Laplace varyansı); düşükse fotoğraf bulanıktır.
  final double sharpness;

  bool get ok => quality == 'GOOD';
}

/// Kontrolden geçmeyen fotoğrafı kullanma nedenleri (`overrideReason`).
const captureOverrideReasons = ['LIGHTING', 'REFLECTIVE', 'NO_RETAKE', 'OTHER'];

const _darkBelow = 45.0;
const _brightAbove = 225.0;
const _blurryBelow = 20.0;

/// [rgba] satır satır RGBA baytlarıdır ([width] × [height]).
CaptureQuality gradeRgba(Uint8List rgba, int width, int height) {
  final n = width * height;
  if (n == 0 || rgba.length < n * 4) {
    return const CaptureQuality(quality: 'GOOD', brightness: 0, sharpness: 0);
  }
  final luma = Float32List(n);
  var sum = 0.0;
  for (var i = 0; i < n; i++) {
    final o = i * 4;
    final y = 0.299 * rgba[o] + 0.587 * rgba[o + 1] + 0.114 * rgba[o + 2];
    luma[i] = y;
    sum += y;
  }
  final brightness = sum / n;

  var lapSum = 0.0;
  var lapSq = 0.0;
  var count = 0;
  for (var y = 1; y < height - 1; y++) {
    for (var x = 1; x < width - 1; x++) {
      final i = y * width + x;
      final v =
          luma[i - 1] +
          luma[i + 1] +
          luma[i - width] +
          luma[i + width] -
          4 * luma[i];
      lapSum += v;
      lapSq += v * v;
      count++;
    }
  }
  final mean = count == 0 ? 0.0 : lapSum / count;
  final sharpness = count == 0 ? 0.0 : lapSq / count - mean * mean;

  final quality = brightness < _darkBelow
      ? 'DARK'
      : brightness > _brightAbove
      ? 'BRIGHT'
      : sharpness < _blurryBelow
      ? 'BLURRY'
      : 'GOOD';
  return CaptureQuality(
    quality: quality,
    brightness: double.parse(brightness.toStringAsFixed(1)),
    sharpness: double.parse(sharpness.toStringAsFixed(1)),
  );
}

/// Çekilen dosyayı küçültüp ölçer. Dosya okunamazsa (test, simülatör) null.
Future<CaptureQuality?> gradePhotoFile(String? path) async {
  if (path == null || path.isEmpty || path.startsWith('test://')) return null;
  if (inWidgetTest) return null;
  try {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 320);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final width = image.width;
    final height = image.height;
    image.dispose();
    codec.dispose();
    if (data == null) return null;
    return gradeRgba(data.buffer.asUint8List(), width, height);
  } catch (_) {
    return null;
  }
}

/// Yükleme isteğindeki `captureCheck` nesnesi.
Map<String, Object?> captureCheckJson({
  required CaptureQuality? quality,
  required bool selfChecked,
  String? overrideReason,
  int? distanceMeters,
  int? maxDistanceMeters,
}) => {
  'source': 'CAMERA',
  'quality': quality?.quality ?? 'GOOD',
  if (quality != null) ...{
    'brightness': quality.brightness,
    'sharpness': quality.sharpness,
  },
  if (quality != null && !quality.ok) 'overrideReason': ?overrideReason,
  'distanceMeters': ?distanceMeters,
  'maxDistanceMeters': ?maxDistanceMeters,
  'selfChecked': selfChecked,
};
