import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'l10n.dart';
import 'theme.dart';

/// Tanıtım ve ilk-giriş turundaki sahneler: uygulamanın gerçek ekranlarını
/// andıran sade, kodla çizilmiş küçük görseller. Ağdan harita karosu
/// indirmez; her sahne tek bir fikri anlatır.
enum OnboardScene {
  stops,
  route,
  scan,
  proof,
  shift,
  offline,
  branchSummary,
  branchAssign,
  branchCouriers,
  branchOps,
  branchStock,
}

class OnboardArt extends StatelessWidget {
  const OnboardArt({super.key, required this.scene, this.height = 260});

  final OnboardScene scene;
  final double height;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    String t(String tr, String en) => l.isEn ? en : tr;
    final child = switch (scene) {
      OnboardScene.stops => _Stops(t: t),
      OnboardScene.route => _Route(t: t),
      OnboardScene.scan => _Scan(t: t),
      OnboardScene.proof => _Proof(t: t),
      OnboardScene.shift => _Shift(t: t),
      OnboardScene.offline => _Offline(t: t),
      OnboardScene.branchSummary => _BranchSummary(t: t),
      OnboardScene.branchAssign => _BranchAssign(t: t),
      OnboardScene.branchCouriers => _BranchCouriers(t: t),
      OnboardScene.branchOps => _BranchOps(t: t),
      OnboardScene.branchStock => _BranchStock(t: t),
    };
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Dg.radiusHero),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Dg.plum.withValues(alpha: Dg.dark ? 0.22 : 0.14),
            Dg.surface,
          ],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(18),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(width: 300, child: child),
        ),
      ),
    );
  }
}

typedef _T = String Function(String tr, String en);

// ── Ortak parçalar ──────────────────────────────────────────────────────

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.highlight = false});
  final Widget child;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: highlight ? Dg.surface : Dg.elev,
      borderRadius: BorderRadius.circular(16),
      boxShadow: highlight
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: Dg.dark ? 0.35 : 0.10),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ]
          : null,
    ),
    child: child,
  );
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, {required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: Dg.ui(size: 11, weight: FontWeight.w700, color: color),
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.icon, {required this.color, this.size = 36});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(size * 0.32),
    ),
    child: Icon(icon, size: size * 0.5, color: color),
  );
}

/// Metin yerine gri çizgi: sahnede okunması gerekmeyen satırlar.
class _Bar extends StatelessWidget {
  const _Bar({required this.width, this.height = 7});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Dg.ink3.withValues(alpha: 0.28),
      borderRadius: BorderRadius.circular(height),
    ),
  );
}

Widget _title(String s, {double size = 15}) => Text(
  s,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: Dg.ui(size: size, weight: FontWeight.w700, color: Dg.ink),
);

Widget _caption(String s) =>
    Text(s, style: Dg.ui(size: 12, color: Dg.ink3, height: 1.2));

// ── Kurye sahneleri ─────────────────────────────────────────────────────

/// Sıradaki durak en üstte, diğerleri altında sönük.
class _Stops extends StatelessWidget {
  const _Stops({required this.t});
  final _T t;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _Panel(
        highlight: true,
        child: Row(
          children: [
            _Badge(LucideIcons.mapPin, color: Dg.orange),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Chip(t('Sıradaki', 'Next'), color: Dg.plum),
                  const SizedBox(height: 6),
                  _title('Ayşe Kaya'),
                  _caption(t('Kızılay Mah. No:12', 'Kızılay Ave. No:12')),
                ],
              ),
            ),
            Column(
              children: [
                Text('14:30', style: Dg.ui(size: 15, weight: FontWeight.w700)),
                _caption('~6 dk'),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      for (final w in [150.0, 120.0])
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Opacity(
            opacity: 0.55,
            child: _Panel(
              child: Row(
                children: [
                  _Badge(LucideIcons.package, color: Dg.ink3, size: 28),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Bar(width: w),
                      const SizedBox(height: 6),
                      _Bar(width: w * 0.6, height: 6),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}

/// Haritada sırayla duraklar: kıvrımlı yol ve numaralı noktalar.
class _Route extends StatelessWidget {
  const _Route({required this.t});
  final _T t;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 200,
    child: Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _RoutePainter())),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Dg.action,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.navigation,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  t('Yol tarifi', 'Directions'),
                  style: Dg.ui(
                    size: 13,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _RoutePainter extends CustomPainter {
  static const _stops = [
    Offset(0.08, 0.80),
    Offset(0.34, 0.52),
    Offset(0.62, 0.66),
    Offset(0.86, 0.18),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Silik sokak ızgarası: harita hissi, karo indirmeden.
    final grid = Paint()
      ..color = Dg.ink3.withValues(alpha: 0.10)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y - 14), grid);
      final x = size.width * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x + 18, size.height), grid);
    }
    final pts = [
      for (final s in _stops) Offset(s.dx * size.width, s.dy * size.height),
    ];
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i];
      final mid = Offset((a.dx + b.dx) / 2, math.min(a.dy, b.dy) - 18);
      path.quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Dg.action.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Dg.action
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    for (var i = 0; i < pts.length; i++) {
      final first = i == 0;
      canvas.drawCircle(
        pts[i],
        first ? 13 : 11,
        Paint()..color = first ? Dg.orange : Dg.surface,
      );
      canvas.drawCircle(
        pts[i],
        first ? 13 : 11,
        Paint()
          ..color = first ? Dg.orange : Dg.action
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            fontFamily: Dg.sans,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: first ? Colors.white : Dg.ink,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pts[i] - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Barkod okuma çerçevesi ve okunan paket sayısı.
class _Scan extends StatelessWidget {
  const _Scan({required this.t});
  final _T t;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 220,
        height: 130,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(size: const Size(220, 130), painter: _CornersPainter()),
            CustomPaint(size: const Size(150, 64), painter: _BarcodePainter()),
            Positioned(
              left: 24,
              right: 24,
              top: 64,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: Dg.bad,
                  boxShadow: [
                    BoxShadow(
                      color: Dg.bad.withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _Panel(
        highlight: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.circleCheck, size: 20, color: Dg.ok),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                t('3 / 3 paket okundu', '3 / 3 parcels scanned'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Dg.ui(size: 14, weight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _CornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Dg.ink
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const c = 26.0;
    final w = size.width, h = size.height;
    for (final (o, dx, dy) in [
      (Offset.zero, 1.0, 1.0),
      (Offset(w, 0), -1.0, 1.0),
      (Offset(0, h), 1.0, -1.0),
      (Offset(w, h), -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(o.dx, o.dy + c * dy)
          ..lineTo(o.dx, o.dy)
          ..lineTo(o.dx + c * dx, o.dy),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BarcodePainter extends CustomPainter {
  static const _widths = [3, 1, 2, 1, 4, 1, 1, 3, 2, 1, 3, 1, 2, 4, 1, 2, 1, 3];

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / (_widths.fold<int>(0, (a, b) => a + b) * 1.6);
    var x = 0.0;
    final p = Paint()..color = Dg.ink;
    for (var i = 0; i < _widths.length; i++) {
      final w = _widths[i] * unit;
      canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), p);
      x += w + unit * (i.isEven ? 1.2 : 0.6);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Teslimi kapatmak için gereken üç adım.
class _Proof extends StatelessWidget {
  const _Proof({required this.t});
  final _T t;

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String label, bool done) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          _Badge(icon, color: done ? Dg.ok : Dg.plum, size: 32),
          const SizedBox(width: 10),
          Expanded(child: _title(label, size: 14)),
          Icon(
            done ? LucideIcons.circleCheck : LucideIcons.circle,
            size: 20,
            color: done ? Dg.ok : Dg.ink3,
          ),
        ],
      ),
    );
    return _Panel(
      highlight: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row(LucideIcons.camera, t('Kapı fotoğrafı', 'Door photo'), true),
          row(LucideIcons.keyRound, t('Alıcının kodu', 'Recipient code'), true),
          row(LucideIcons.user, t('Teslim alan kişi', 'Received by'), false),
          const SizedBox(height: 2),
          Container(
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Dg.action.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(19),
            ),
            child: Text(
              t('Teslimi bitir', 'Finish delivery'),
              style: Dg.ui(
                size: 14,
                weight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Açık vardiya kartı ve gün sonu düğmesi.
class _Shift extends StatelessWidget {
  const _Shift({required this.t});
  final _T t;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _Panel(
        highlight: true,
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Dg.ok,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Dg.ok.withValues(alpha: 0.6), blurRadius: 8),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _title(t('Vardiya açık', 'Shift open')),
                  _caption(
                    t('08:30’dan beri · Müsait', 'Since 08:30 · Available'),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Dg.elev,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.moon, size: 14, color: Dg.ink2),
                  const SizedBox(width: 4),
                  Text(
                    t('Gün sonu', 'End day'),
                    style: Dg.ui(size: 12, weight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          for (final (i, (n, label, color)) in [
            ('12', t('Teslim', 'Delivered'), Dg.ok),
            ('3', t('Yolda', 'On route'), Dg.plum),
            ('1', t('İade', 'Return'), Dg.warn),
          ].indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _Panel(
                child: Column(
                  children: [
                    Text(
                      n,
                      style: Dg.ui(
                        size: 22,
                        weight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    _caption(label),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    ],
  );
}

/// Çekim yokken kayıtlar telefonda bekler, çekince gider.
class _Offline extends StatelessWidget {
  const _Offline({required this.t});
  final _T t;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Badge(LucideIcons.smartphone, color: Dg.plum, size: 52),
          const SizedBox(width: 10),
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Dg.plum.withValues(alpha: 0.4 + i * 0.2),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          const SizedBox(width: 10),
          _Badge(LucideIcons.cloudUpload, color: Dg.ok, size: 52),
        ],
      ),
      const SizedBox(height: 16),
      _Panel(
        highlight: true,
        child: Row(
          children: [
            Icon(LucideIcons.wifiOff, size: 18, color: Dg.warn),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t('3 kayıt bekliyor', '3 records waiting'),
                style: Dg.ui(size: 14, weight: FontWeight.w700),
              ),
            ),
            _Chip(t('Çekince gider', 'Sends on signal'), color: Dg.ok),
          ],
        ),
      ),
    ],
  );
}

// ── Şube sahneleri ──────────────────────────────────────────────────────

class _Tile extends StatelessWidget {
  const _Tile(this.icon, this.n, this.label, this.color);
  final IconData icon;
  final String n;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => _Panel(
    highlight: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Badge(icon, color: color, size: 30),
        const SizedBox(height: 8),
        Text(n, style: Dg.ui(size: 22, weight: FontWeight.w800)),
        _caption(label),
      ],
    ),
  );
}

class _BranchSummary extends StatelessWidget {
  const _BranchSummary({required this.t});
  final _T t;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          Expanded(
            child: _Tile(
              LucideIcons.truck,
              '24',
              t('Dağıtılacak', 'To deliver'),
              Dg.plum,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Tile(
              LucideIcons.users,
              '6',
              t('Yoldaki kurye', 'Couriers out'),
              Dg.ok,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _Tile(
              LucideIcons.packageCheck,
              '12',
              t('Zimmette', 'Assigned'),
              Dg.orange,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Tile(
              LucideIcons.warehouse,
              '38',
              t('Stokta', 'In stock'),
              Dg.warn,
            ),
          ),
        ],
      ),
    ],
  );
}

class _PersonRow extends StatelessWidget {
  const _PersonRow(this.initials, this.name, this.trailing);
  final String initials;
  final String name;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: _Panel(
      highlight: true,
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: Dg.plum.withValues(alpha: 0.2),
            child: Text(
              initials,
              style: Dg.ui(size: 11, weight: FontWeight.w800, color: Dg.plum),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _title(name, size: 14)),
          trailing,
        ],
      ),
    ),
  );
}

class _BranchAssign extends StatelessWidget {
  const _BranchAssign({required this.t});
  final _T t;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _Panel(
        child: Row(
          children: [
            _Badge(LucideIcons.package, color: Dg.orange, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: _title(
                t('3 gönderi seçili', '3 shipments selected'),
                size: 14,
              ),
            ),
          ],
        ),
      ),
      Icon(LucideIcons.arrowDown, size: 22, color: Dg.ink3),
      _PersonRow(
        'MK',
        'Mehmet Kaya',
        _Chip(t('Müsait', 'Available'), color: Dg.ok),
      ),
      Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Dg.action,
          borderRadius: BorderRadius.circular(19),
        ),
        child: Text(
          t('Kuryeye ata', 'Assign to courier'),
          style: Dg.ui(size: 14, weight: FontWeight.w700, color: Colors.white),
        ),
      ),
    ],
  );
}

class _BranchCouriers extends StatelessWidget {
  const _BranchCouriers({required this.t});
  final _T t;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _PersonRow(
        'MK',
        'Mehmet Kaya',
        _Chip(t('Yolda · 4', 'Out · 4'), color: Dg.plum),
      ),
      _PersonRow(
        'EA',
        'Elif Aydın',
        _Chip(t('Müsait', 'Available'), color: Dg.ok),
      ),
      _PersonRow(
        'CT',
        'Can Tekin',
        _Chip(t('Molada', 'On break'), color: Dg.warn),
      ),
    ],
  );
}

class _BranchOps extends StatelessWidget {
  const _BranchOps({required this.t});
  final _T t;

  @override
  Widget build(BuildContext context) {
    final items = [
      (LucideIcons.scanBarcode, t('Sayım', 'Count'), Dg.plum),
      (LucideIcons.printer, t('Etiket', 'Labels'), Dg.orange),
      (LucideIcons.truck, t('Sevk', 'Dispatch'), Dg.ok),
      (LucideIcons.messageSquare, 'SMS', Dg.warn),
      (LucideIcons.calendarClock, t('Vardiya', 'Shifts'), Dg.plum),
      (LucideIcons.chartColumn, t('Performans', 'Stats'), Dg.ok),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (icon, label, color) in items)
          SizedBox(
            width: 94,
            child: _Panel(
              highlight: true,
              child: Column(
                children: [
                  _Badge(icon, color: color, size: 34),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    maxLines: 1,
                    style: Dg.ui(size: 12, weight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _BranchStock extends StatelessWidget {
  const _BranchStock({required this.t});
  final _T t;

  @override
  Widget build(BuildContext context) => _Panel(
    highlight: true,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Badge(LucideIcons.warehouse, color: Dg.warn, size: 32),
            const SizedBox(width: 10),
            Expanded(child: _title(t('Raf sayımı', 'Shelf count'), size: 14)),
            Text(
              '46 / 50',
              style: Dg.ui(size: 15, weight: FontWeight.w800, color: Dg.plum),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: 0.92,
            minHeight: 8,
            backgroundColor: Dg.elev,
            valueColor: AlwaysStoppedAnimation(Dg.plum),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _Chip(t('2 eksik', '2 missing'), color: Dg.bad),
            const SizedBox(width: 6),
            _Chip(t('1 fazla', '1 extra'), color: Dg.warn),
          ],
        ),
      ],
    ),
  );
}
