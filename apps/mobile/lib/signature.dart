import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// Sahada alınan ıslak imza — BTK nitelikli elektronik imza / zaman damgası
/// bağlanınca aynı [toProof] şemasına `btk.qualified` ve `btk.tsa` dolar.
class SignatureCapture {
  const SignatureCapture({
    required this.strokes,
    required this.size,
    required this.capturedAt,
  });

  final List<List<Offset>> strokes;
  final Size size;
  final DateTime capturedAt;

  bool get isEmpty => strokes.every((s) => s.isEmpty);

  int get pointCount =>
      strokes.fold(0, (n, stroke) => n + stroke.length);

  Map<String, Object?> toProof() {
    final w = size.width <= 0 ? 1.0 : size.width;
    final h = size.height <= 0 ? 1.0 : size.height;
    return {
      'type': 'RECIPIENT_SIGNATURE',
      'channel': 'WET_INK_CAPTURE',
      'capturedAt': capturedAt.toUtc().toIso8601String(),
      'pointCount': pointCount,
      'pad': {'w': w, 'h': h},
      'strokes': [
        for (final stroke in strokes)
          [
            for (final p in stroke)
              {'x': (p.dx / w).clamp(0.0, 1.0), 'y': (p.dy / h).clamp(0.0, 1.0)},
          ],
      ],
      'btk': const {
        'status': 'PENDING_INTEGRATION',
        'qualified': false,
      },
    };
  }
}

class SignaturePad extends StatefulWidget {
  const SignaturePad({
    super.key,
    required this.onChanged,
    this.hint = 'Parmağınla imzala',
  });

  final ValueChanged<SignatureCapture> onChanged;
  final String hint;

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad>
    with SingleTickerProviderStateMixin {
  final _strokes = <List<Offset>>[];
  late final AnimationController _ink;
  DateTime _capturedAt = DateTime.now();
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _ink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    _ink.dispose();
    super.dispose();
  }

  void clear() {
    setState(() {
      _strokes.clear();
      _capturedAt = DateTime.now();
    });
    _ink.forward(from: 0);
    widget.onChanged(_capture());
  }

  SignatureCapture _capture() => SignatureCapture(
    strokes: [for (final s in _strokes) List<Offset>.from(s)],
    size: _size,
    capturedAt: _capturedAt,
  );

  void _emit() => widget.onChanged(_capture());

  void _start(Offset local) {
    HapticFeedback.selectionClick();
    _capturedAt = DateTime.now();
    setState(() => _strokes.add([local]));
    _ink.forward(from: 0);
    _emit();
  }

  void _move(Offset local) {
    if (_strokes.isEmpty) return;
    final stroke = _strokes.last;
    if (stroke.isNotEmpty && (stroke.last - local).distance < 1.2) return;
    setState(() => stroke.add(local));
    _emit();
  }

  void _end() {
    HapticFeedback.lightImpact();
    _ink.forward(from: 0.45);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final empty = _strokes.every((s) => s.isEmpty);
    return AspectRatio(
      aspectRatio: 342 / 200,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF6F1E8),
          borderRadius: BorderRadius.circular(Dg.radius),
          border: Border.all(color: const Color(0xFFD8D0C2)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Dg.radius),
          child: LayoutBuilder(
            builder: (context, box) {
              _size = Size(box.maxWidth, box.maxHeight);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) => _start(d.localPosition),
                onPanUpdate: (d) => _move(d.localPosition),
                onPanEnd: (_) => _end(),
                child: AnimatedBuilder(
                  animation: _ink,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _InkPainter(
                        strokes: _strokes,
                        wet: _ink.value,
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (empty)
                            Center(
                              child: Text(
                                widget.hint,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF8A8376),
                                ),
                              ),
                            ),
                          const Positioned(
                            left: 20,
                            right: 20,
                            bottom: 28,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Color(0xFFC9C0B2),
                                  ),
                                ),
                              ),
                              child: SizedBox(height: 1),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InkPainter extends CustomPainter {
  _InkPainter({required this.strokes, required this.wet});

  final List<List<Offset>> strokes;
  final double wet;

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = const Color(0xFF1A1612).withValues(alpha: 0.82 + wet * 0.18)
      ..strokeWidth = 2.7 + wet * 0.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 1.6, ink);
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        final prev = stroke[i - 1];
        final cur = stroke[i];
        final mid = Offset((prev.dx + cur.dx) / 2, (prev.dy + cur.dy) / 2);
        path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
      }
      path.lineTo(stroke.last.dx, stroke.last.dy);
      canvas.drawPath(path, ink);
    }
  }

  @override
  bool shouldRepaint(covariant _InkPainter old) {
    if (old.wet != wet || old.strokes.length != strokes.length) return true;
    if (strokes.isEmpty) return old.strokes.isNotEmpty;
    final a = old.strokes.isEmpty ? 0 : old.strokes.last.length;
    final b = strokes.last.length;
    return a != b;
  }
}
