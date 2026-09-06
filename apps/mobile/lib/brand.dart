import 'package:flutter/material.dart';

import 'theme.dart';

/// Dijigoo markası — JetLogi varlıklarının yerine. Harita iğnesi + D kesiti;
/// renk temadan gelir, PNG'ye bağlı değil.
class DijigooMark extends StatelessWidget {
  const DijigooMark({super.key, this.size = 28, this.onDark = false});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final fill = onDark ? Colors.white : Dg.ink;
    final hole = onDark ? Dg.night : Dg.ground;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MarkPainter(fill: fill, hole: hole)),
    );
  }
}

class DijigooWordmark extends StatelessWidget {
  const DijigooWordmark({
    super.key,
    this.height = 28,
    this.onDark = false,
    this.showName = true,
  });

  final double height;
  final bool onDark;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final ink = onDark ? Colors.white : Dg.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DijigooMark(size: height, onDark: onDark),
        if (showName) ...[
          SizedBox(width: height * 0.28),
          Text(
            'Dijigoo',
            style: TextStyle(
              fontFamily: Dg.sans,
              fontSize: height * 0.72,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
              height: 1,
              color: ink,
            ),
          ),
        ],
      ],
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.fill, required this.hole});

  final Color fill;
  final Color hole;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final pin = Path()
      ..moveTo(s * 0.50, s * 0.96)
      ..cubicTo(s * 0.18, s * 0.68, s * 0.08, s * 0.46, s * 0.08, s * 0.38)
      ..cubicTo(s * 0.08, s * 0.16, s * 0.26, s * 0.04, s * 0.50, s * 0.04)
      ..cubicTo(s * 0.74, s * 0.04, s * 0.92, s * 0.16, s * 0.92, s * 0.38)
      ..cubicTo(s * 0.92, s * 0.46, s * 0.82, s * 0.68, s * 0.50, s * 0.96)
      ..close();
    canvas.drawPath(pin, Paint()..color = fill);

    final d = Path()
      ..moveTo(s * 0.38, s * 0.22)
      ..lineTo(s * 0.38, s * 0.54)
      ..lineTo(s * 0.50, s * 0.54)
      ..cubicTo(s * 0.64, s * 0.54, s * 0.72, s * 0.48, s * 0.72, s * 0.38)
      ..cubicTo(s * 0.72, s * 0.28, s * 0.64, s * 0.22, s * 0.50, s * 0.22)
      ..close();
    canvas.drawPath(d, Paint()..color = hole);
  }

  @override
  bool shouldRepaint(covariant _MarkPainter old) =>
      old.fill != fill || old.hole != hole;
}
