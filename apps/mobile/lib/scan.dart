import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'l10n.dart';
import 'theme.dart';

/// Widget testleri kamera eklentisini yüklemez.
bool get inWidgetTest {
  final name = WidgetsBinding.instance.runtimeType.toString();
  return name.contains('TestWidgetsFlutterBinding') ||
      name.contains('AutomatedTest');
}

Future<void> playScanFeedback({required bool beep}) async {
  await HapticFeedback.mediumImpact();
  if (beep) await SystemSound.play(SystemSoundType.click);
}

/// Sistem kamerasını açar. İptalde null. Testte sahte bir yol döner.
Future<String?> capturePhoto({bool front = false}) async {
  if (inWidgetTest) return 'test://capture';
  final file = await ImagePicker().pickImage(
    source: ImageSource.camera,
    preferredCameraDevice: front ? CameraDevice.front : CameraDevice.rear,
    maxWidth: 1600,
    imageQuality: 85,
    requestFullMetadata: false,
  );
  return file?.path;
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message ?? l.openCameraHint,
              style: Dg.ui(size: 14, color: const Color(0xCCF3F0E7)),
            ),
            const Spacer(),
            TextField(
              controller: _manual,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: l.typeCode,
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
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
              IgnorePointer(child: CustomPaint(painter: _ScanFramePainter())),
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: Text(
                  context.l10n.bringBarcode,
                  style: Dg.ui(
                    size: 13,
                    color: const Color(0xCCF3F0E7),
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
                    hintText: context.l10n.typeCodeSend,
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                    filled: true,
                    fillColor: const Color(0xE6150A2E),
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
        width: 40,
        height: 40,
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

class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xCCFFFFFF)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const l = 26.0;
    const m = 18.0;
    void corner(double x, double y, double dx, double dy) {
      canvas.drawLine(Offset(x, y + dy * l), Offset(x, y), p);
      canvas.drawLine(Offset(x, y), Offset(x + dx * l, y), p);
    }

    corner(m, m, 1, 1);
    corner(size.width - m, m, -1, 1);
    corner(m, size.height - m, 1, -1);
    corner(size.width - m, size.height - m, -1, -1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
