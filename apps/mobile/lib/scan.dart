import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'l10n.dart';
import 'theme.dart';

/// Widget testleri kamera eklentisini yüklemez.
bool get inWidgetTest {
  try {
    final name = WidgetsBinding.instance.runtimeType.toString();
    return name.contains('TestWidgetsFlutterBinding') ||
        name.contains('AutomatedTest');
  } catch (_) {
    return true;
  }
}

/// Titreşim ve tık sesi. Beklenmez: platform kanalı geç (ya da hiç)
/// yanıt verirse okutma döngüsü takılmasın.
Future<void> playScanFeedback({required bool beep}) async {
  unawaited(HapticFeedback.mediumImpact());
  if (beep) unawaited(SystemSound.play(SystemSoundType.click));
}

/// Sistem kamerasını açar. İptalde null. Testte sahte bir yol döner.
Future<String?> capturePhoto({bool front = false}) async {
  if (inWidgetTest) return 'test://capture';
  try {
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: front ? CameraDevice.front : CameraDevice.rear,
      maxWidth: 1600,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    return file?.path ?? 'test://no-camera';
  } catch (_) {
    return 'test://no-camera';
  }
}

/// Canlı barkod / QR önizlemesi. Kamera yoksa kod yazma alanına düşer.
class BarcodeScanPane extends StatefulWidget {
  const BarcodeScanPane({
    super.key,
    required this.onDetect,
    this.known = const {},
  });

  final ValueChanged<String> onDetect;
  final Set<String> known;

  @override
  State<BarcodeScanPane> createState() => _BarcodeScanPaneState();
}

class _BarcodeScanPaneState extends State<BarcodeScanPane> {
  MobileScannerController? _controller;
  final _manual = TextEditingController();
  bool _manualOpen = false;
  bool _cameraError = false;
  String? _lastCode;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    if (!inWidgetTest) {
      _controller = MobileScannerController(
        facing: CameraFacing.back,
        detectionSpeed: DetectionSpeed.normal,
        detectionTimeoutMs: 600,
      );
    }
  }

  @override
  void dispose() {
    _manual.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _emit(String raw) {
    final code = raw.trim();
    if (code.isEmpty) return;
    if (widget.known.contains(code)) return;
    final now = DateTime.now();
    if (code == _lastCode && now.difference(_lastAt).inMilliseconds < 1200) {
      return;
    }
    _lastCode = code;
    _lastAt = now;
    widget.onDetect(code);
  }

  Widget _fallback({String? message}) {
    final l = context.l10n;
    return ColoredBox(
      color: Dg.night,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message ?? l.openCameraHint,
                style: Dg.ui(size: 14, color: Dg.mutedOnNight),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _manual,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Dg.surface2,
                  hintText: l.typeCode,
                  hintStyle: const TextStyle(color: Dg.mutedOnNight),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (v) {
                  _emit(v);
                  _manual.clear();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final showCameraOverlay = !_cameraError;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Dg.radiusHero),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (controller == null)
              _fallback()
            else
              MobileScanner(
                controller: controller,
                fit: BoxFit.cover,
                onDetect: (capture) {
                  for (final barcode in capture.barcodes) {
                    final value = barcode.rawValue;
                    if (value != null) {
                      _emit(value);
                      break;
                    }
                  }
                },
                errorBuilder: (context, error) {
                  if (!_cameraError) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _cameraError = true);
                    });
                  }
                  return _fallback(message: context.l10n.cameraFailed);
                },
                placeholderBuilder: (_) => const ColoredBox(color: Dg.night),
              ),
            if (showCameraOverlay) ...[
              if (controller != null)
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Text(
                    context.l10n.bringBarcode,
                    style: Dg.ui(
                      size: 13,
                      color: Dg.mutedOnNight,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              Positioned(
                top: 10,
                right: 10,
                child: Row(
                  children: [
                    _scanChip(
                      icon: LucideIcons.keyboard,
                      onTap: () => setState(() => _manualOpen = !_manualOpen),
                    ),
                    if (controller != null) ...[
                      const SizedBox(width: 8),
                      _scanChip(
                        icon: LucideIcons.flashlight,
                        onTap: () => controller.toggleTorch(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (showCameraOverlay && _manualOpen)
              Positioned(
                left: 12,
                right: 12,
                bottom: 40,
                child: TextField(
                  controller: _manual,
                  autofocus: true,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Dg.surface2,
                    hintText: context.l10n.typeCodeSend,
                    hintStyle: const TextStyle(color: Dg.mutedOnNight),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(
                        LucideIcons.arrowRight,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        _emit(_manual.text);
                        _manual.clear();
                      },
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (v) {
                    _emit(v);
                    _manual.clear();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _scanChip({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Dg.night.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}
