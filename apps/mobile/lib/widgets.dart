import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:pinput/pinput.dart';

import 'geo.dart';
import 'map_config.dart';
import 'models.dart';
import 'theme.dart';

/// Demo courier's base area (Güney / Denizli) — used as the map center when
/// a screen has no specific task coordinates to show (e.g. onboarding
/// previews).
const _dgDefaultMapCenter = LatLng(38.1512, 29.0614);

class Display extends StatelessWidget {
  const Display(
    this.text, {
    super.key,
    this.size = 34,
    this.italic = false,
    this.color,
    this.weight = FontWeight.w600,
    this.maxLines,
  });

  final String text;
  final double size;
  final bool italic;
  final Color? color;
  final FontWeight weight;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: Dg.serif(
        size: size,
        italic: italic,
        color: color ?? Dg.ink,
        weight: weight,
      ),
    );
  }
}

class DemoPill extends StatelessWidget {
  const DemoPill({super.key, this.onLongPress});

  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Dg.ink.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Dg.ink.withValues(alpha: 0.12)),
        ),
        child: Text(
          'DEMO',
          style: TextStyle(
            fontFamily: Dg.mono,
            color: Dg.ink,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

/// Durum göstergesi: 6px renkli nokta + nötr metin — dolgulu rozet değil.
/// [dot] rengi tona göre otomatik seçilir (sage/sand/clay), [fg] ile
/// override edilebilir (metin her zaman [Dg.ink2], nötr kalır — vurgu
/// sadece noktada).
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.tone,
    this.bg,
    this.fg,
  });

  final String label;
  final String tone;

  /// Eski API'den kalan override'lar — artık dolgu/kenarlık değil, nokta
  /// rengini belirlemek için kullanılıyor. [bg] artık okunmuyor (dolgu yok).
  final Color? bg;
  final Color? fg;

  @override
  Widget build(BuildContext context) {
    final dot =
        fg ??
        switch (tone) {
          'hi' => Dg.clay,
          'mid' => Dg.sand,
          'lo' => Dg.sage,
          'lime' => Dg.primaryGradientStart,
          _ => Dg.ink3,
        };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: Dg.mono,
            color: Dg.ink2,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// A single horizontal rule — replaces the `Container(height: 1, color:
/// Dg.rule)` pattern repeated by hand across profile/earnings/task-detail/
/// wizard screens.
class DgDivider extends StatelessWidget {
  const DgDivider({super.key});

  @override
  Widget build(BuildContext context) => Container(height: 1, color: Dg.rule);
}

/// One boolean on/off switch shape, replacing the two near-identical
/// hand-rolled toggles in home_screen.dart (shift open/close) and
/// profile_screen.dart (`_switchRow`) — colors are parameterized rather than
/// forked into two widgets since the only real difference between those two
/// call sites was track/thumb color, not shape or motion.
class DgSwitch extends StatelessWidget {
  const DgSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? thumbColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 58,
        height: 34,
        decoration: BoxDecoration(
          color: value
              ? (activeColor ?? Dg.primaryGradientStart)
              : (inactiveColor ?? Dg.rule),
          borderRadius: BorderRadius.circular(20),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(4),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: thumbColor ?? Dg.ink,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class Mono extends StatelessWidget {
  const Mono(
    this.text, {
    super.key,
    this.size = 13,
    this.weight = FontWeight.w500,
    this.color,
  });

  final String text;
  final double size;
  final FontWeight weight;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: Dg.mono,
        fontSize: size,
        fontWeight: weight,
        color: color ?? Dg.ink3,
      ),
    );
  }
}

class DgCard extends StatelessWidget {
  const DgCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.hero = false,
    this.lime = false,
    this.dark = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool hero;
  final bool lime;

  /// Dg.night surface with a white@18% hairline border, matching the
  /// glass-pill language already used on task_detail_screen/home's hero
  /// cards — lets dark-surface stat pills (e.g. task_detail's former
  /// private `_StatPill`) reuse this shape instead of a bespoke widget.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    // Card radius is unified at Dg.radiusHero across the whole app now —
    // [hero] only still switches shadow weight/fill below, not shape.
    const radius = Dg.radiusHero;
    final body = Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? Dg.night : (lime ? Dg.purple : Dg.surface),
        borderRadius: BorderRadius.circular(radius),
        // Çerçeve yok — yüzey tonu + gölge + üst kenardaki 1px ışık ayırıyor.
        border: Border(top: BorderSide(color: Dg.insetHighlight)),
        boxShadow: hero || lime || dark ? Dg.shadowHero : Dg.shadow,
      ),
      child: child,
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: body,
      ),
    );
  }
}

/// A real, recognizable map (OpenStreetMap tiles via flutter_map — no API
/// key required, works on iOS/Android). Replaced the old hand-drawn
/// abstract "map-ish" illustration, which stakeholders found confusing.
///
/// Pass [points] for one or more real task coordinates (a route line is
/// drawn between them when there's more than one); falls back to a fixed
/// demo-area center with no markers when [points] is empty (e.g. generic
/// onboarding previews with no specific task yet).
class MapStrip extends StatelessWidget {
  const MapStrip({
    super.key,
    this.eta,
    this.height = 72,
    this.clipTopOnly = true,
    this.rounded = true,
    this.points = const [],
    this.encodedPolyline,
    this.label,
    this.onTap,
  });

  final int? eta;
  final double height;
  final bool clipTopOnly;

  /// Set false for a full-bleed map flush against the screen edge (e.g. a
  /// tracking screen with a bottom sheet floating over it) — no corners are
  /// rounded regardless of [clipTopOnly].
  final bool rounded;
  final List<LatLng> points;

  /// Real road-following geometry from `GET /v1/routes/current` (Google
  /// encoded polyline, see lib/geo.dart). When present, this draws the line
  /// instead of the straight segments between [points] — [points] still
  /// supplies the stop markers either way.
  final String? encodedPolyline;
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final center = points.isNotEmpty ? points.first : _dgDefaultMapCenter;
    final line = encodedPolyline != null && encodedPolyline!.isNotEmpty
        ? decodePolyline(encodedPolyline!)
        : points;
    final body = ClipRRect(
      borderRadius: !rounded
          ? BorderRadius.zero
          : clipTopOnly
          ? const BorderRadius.vertical(top: Radius.circular(Dg.radiusHero))
          : BorderRadius.circular(Dg.radius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: points.length > 1 ? 13 : 14.5,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: mapTileUrlTemplate,
                    userAgentPackageName: 'com.dijigoo.dijigooKurye',
                    tileDimension: useMapboxTiles ? 512 : 256,
                    // Mapbox's 512px tiles are addressed one zoom level lower
                    // than the 256px XYZ scheme flutter_map assumes by
                    // default — without this offset every tile request hits
                    // the wrong z/x/y and the viewport shows nothing, even
                    // though the (mismatched) requests still succeed.
                    zoomOffset: useMapboxTiles ? -1 : 0,
                    subdomains: useMapboxTiles
                        ? const []
                        : const ['a', 'b', 'c', 'd'],
                    retinaMode: !useMapboxTiles,
                    errorTileCallback: (tile, error, stackTrace) {
                      // ignore: avoid_print
                      print(
                        'TILE ERROR: $error  url=${mapTileUrlTemplate.split('?').first}',
                      );
                    },
                  ),
                  if (line.length > 1)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: line,
                          color: Dg.purpleDeep,
                          strokeWidth: 3.5,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      for (var i = 0; i < points.length; i++)
                        Marker(
                          point: points[i],
                          width: 26,
                          height: 26,
                          child: Container(
                            decoration: BoxDecoration(
                              color: i == points.length - 1
                                  ? Dg.ink
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Dg.ink, width: 1.4),
                            ),
                          ),
                        ),
                      if (points.isEmpty)
                        Marker(
                          point: center,
                          width: 26,
                          height: 26,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Dg.ink,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.white,
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  RichAttributionWidget(
                    alignment: AttributionAlignment.bottomLeft,
                    popupInitialDisplayDuration: Duration.zero,
                    attributions: [
                      TextSourceAttribution(
                        useMapboxTiles
                            ? '© Mapbox © OpenStreetMap'
                            : '© OpenStreetMap contributors © CARTO',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              right: 12,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Dg.ink,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Dg.purple.withValues(alpha: 0.7)),
                ),
                child: Text(
                  label ?? (eta == null ? 'Sıradaki durak' : '~$eta dk'),
                  style: const TextStyle(
                    fontFamily: Dg.mono,
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return body;
    return GestureDetector(onTap: onTap, child: body);
  }
}

class Viewfinder extends StatefulWidget {
  const Viewfinder({
    super.key,
    required this.captured,
    required this.onCapture,
    this.hint = 'Kapıyı ve paketi kadraja alın.',
    this.capturedLabel = 'Kapı / teslim kanıtı',
    this.aspectRatio = 4 / 3,
  });

  final bool captured;
  final VoidCallback onCapture;
  final String hint;
  final String capturedLabel;
  final double aspectRatio;

  @override
  State<Viewfinder> createState() => _ViewfinderState();
}

class _ViewfinderState extends State<Viewfinder> {
  double _flash = 0;

  Future<void> _shoot() async {
    setState(() => _flash = 0.35);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (mounted) setState(() => _flash = 0);
    HapticFeedback.mediumImpact();
    widget.onCapture();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Dg.radius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: Dg.night),
                if (widget.captured)
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF2A3435), Color(0xFF0E1213)],
                      ),
                    ),
                  ),
                CustomPaint(painter: _CornerBrackets()),
                if (widget.captured)
                  const Center(
                    child: Icon(
                      LucideIcons.doorOpen,
                      color: Color(0xFF3FB3A8),
                      size: 48,
                    ),
                  ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: Text(
                    widget.captured ? widget.capturedLabel : widget.hint,
                    textAlign: TextAlign.center,
                    style: Dg.ui(
                      size: 13,
                      color: const Color(0xCCF3F0E7),
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
                IgnorePointer(
                  child: ColoredBox(
                    color: Colors.white.withValues(alpha: _flash),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          key: const Key('shutter'),
          onTap: widget.captured ? null : _shoot,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 6),
              color: widget.captured ? Dg.accent : Dg.accent,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              widget.captured ? LucideIcons.check : LucideIcons.circle,
              color: Colors.white,
              size: widget.captured ? 28 : 22,
            ),
          ),
        ),
        if (widget.captured)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Konum eklenecek. Galeri kapalı.',
              style: TextStyle(color: Dg.ink2, fontSize: 13),
            ),
          ),
      ],
    );
  }
}

class _CornerBrackets extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xCCFFFFFF)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    const l = 28.0;
    const m = 14.0;
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

class OtpPin extends StatelessWidget {
  const OtpPin({
    super.key,
    required this.controller,
    this.onCompleted,
    this.error = false,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onCompleted;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final base = PinTheme(
      width: 48,
      height: 56,
      textStyle: TextStyle(
        fontFamily: Dg.mono,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: Dg.ink,
      ),
      decoration: BoxDecoration(
        color: Dg.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: error ? Dg.hi : Dg.rule, width: 1.5),
      ),
    );
    return Pinput(
      controller: controller,
      length: 6,
      defaultPinTheme: base,
      focusedPinTheme: base.copyDecorationWith(
        border: Border.all(color: Dg.accent, width: 2),
      ),
      submittedPinTheme: base,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onCompleted: onCompleted,
      hapticFeedbackType: HapticFeedbackType.lightImpact,
    );
  }
}

class SquareAction extends StatelessWidget {
  const SquareAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Dg.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dg.radius),
          side: BorderSide(color: Dg.rule),
        ),
        elevation: 2,
        shadowColor: const Color(0x33111716),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Dg.radius),
          child: SizedBox(
            height: 72,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Dg.accent, size: 24),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NightGrain extends StatelessWidget {
  const NightGrain({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _GrainPainter(),
              child: SizedBox.expand(),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _GrainPainter extends CustomPainter {
  const _GrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(7);
    final p = Paint()..color = const Color(0x14F3F0E7);
    for (var i = 0; i < 420; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        rng.nextDouble() * 0.8,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SlideToAct extends StatefulWidget {
  const SlideToAct({super.key, required this.label, required this.onConfirm});

  final String label;
  final VoidCallback onConfirm;

  @override
  State<SlideToAct> createState() => _SlideToActState();
}

class _SlideToActState extends State<SlideToAct>
    with SingleTickerProviderStateMixin {
  double _x = 0;
  bool _dragging = false;
  late final AnimationController _hint = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true, count: 6);

  @override
  void dispose() {
    _hint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const thumb = 52.0;
        final max = (c.maxWidth - thumb - 8).clamp(80.0, 400.0);
        return Container(
          height: 64,
          decoration: BoxDecoration(
            gradient: Dg.primaryGradient,
            borderRadius: BorderRadius.circular(Dg.radiusPill),
            boxShadow: [
              BoxShadow(
                color: Dg.purpleDeep.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Center(
                child: Text(
                  widget.label,
                  style: Dg.ui(
                    size: 15,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _hint,
                builder: (context, child) {
                  final nudge = _dragging ? 0.0 : _hint.value * 8;
                  return Positioned(left: 6 + _x + nudge, child: child!);
                },
                child: GestureDetector(
                  onHorizontalDragStart: (_) =>
                      setState(() => _dragging = true),
                  onHorizontalDragUpdate: (d) {
                    setState(() => _x = (_x + d.delta.dx).clamp(0, max));
                  },
                  onHorizontalDragEnd: (_) {
                    if (_x > max * 0.82) {
                      HapticFeedback.mediumImpact();
                      widget.onConfirm();
                    }
                    setState(() {
                      _x = 0;
                      _dragging = false;
                    });
                  },
                  child: Container(
                    width: thumb,
                    height: thumb,
                    decoration: BoxDecoration(
                      color: Dg.ink,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40000000),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      LucideIcons.chevronsRight,
                      color: Dg.purpleBright,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class DgPillNav extends StatelessWidget {
  const DgPillNav({
    super.key,
    required this.index,
    required this.onChanged,
    required this.items,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final List<(IconData, IconData, String)> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 18),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: Dg.night,
          borderRadius: BorderRadius.circular(Dg.radiusPill),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        index == i ? items[i].$2 : items[i].$1,
                        color: index == i
                            ? Dg.purpleBright
                            : const Color(0x99FFFFFF),
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[i].$3,
                        style: TextStyle(
                          fontFamily: Dg.sans,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: index == i
                              ? Dg.purpleBright
                              : const Color(0x88FFFFFF),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.name,
    this.size = 44,
    this.online = false,
  });

  final String name;
  final double size;

  /// Shows a small status dot in the bottom-right corner when true (e.g. the
  /// courier's own online/offline toggle on Home).
  final bool online;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts
        .take(2)
        .map((p) => p.isEmpty ? '' : p[0])
        .join()
        .toUpperCase();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF8A6BD1), Dg.purpleDeep],
              ),
              boxShadow: [
                BoxShadow(
                  color: Dg.purpleDeep.withValues(alpha: 0.3),
                  blurRadius: size * 0.22,
                  offset: Offset(0, size * 0.09),
                ),
              ],
            ),
            child: Text(
              initials,
              style: TextStyle(
                fontFamily: Dg.sans,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.32,
                color: Colors.white,
              ),
            ),
          ),
          if (online)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: size * 0.3,
                height: size * 0.3,
                decoration: BoxDecoration(
                  color: Dg.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Dg.surface, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Dg.elev,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: index == i ? Dg.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    labels[i],
                    style: Dg.ui(
                      size: 13,
                      weight: FontWeight.w600,
                      color: index == i ? Dg.ink : Dg.ink3,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.subColor,
    this.onTap,
    this.dark = false,
  });

  final String label;
  final String value;
  final String? sub;
  final Color? subColor;
  final VoidCallback? onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DgCard(
        onTap: onTap,
        dark: dark,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Mono(
              label,
              size: 11,
              weight: FontWeight.w500,
              color: dark ? const Color(0xFFDCCFEF) : Dg.ink3,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Dg.stat(size: 24, color: dark ? Colors.white : Dg.ink),
            ),
            if (sub != null) ...[
              const SizedBox(height: 4),
              Text(
                sub!,
                style: Dg.ui(
                  size: 13,
                  color: subColor ?? (dark ? const Color(0xFFE3D9F2) : Dg.ink2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class IconTintBadge extends StatelessWidget {
  const IconTintBadge({
    super.key,
    required this.icon,
    required this.tint,
    required this.ink,
    this.size = 36,
  });

  final IconData icon;
  final Color tint;
  final Color ink;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(size * 0.33),
      ),
      child: Icon(icon, color: ink, size: size * 0.48),
    );
  }
}

String taskStatusLabel(TaskStatus s) => switch (s) {
  TaskStatus.delivered => 'Teslim',
  TaskStatus.failed => 'İade',
  TaskStatus.queued => 'Kuyrukta',
  TaskStatus.inProgress => 'İşlemde',
  TaskStatus.assigned => 'Bekliyor',
};

String taskStatusTone(TaskStatus s) => switch (s) {
  TaskStatus.delivered => 'lo',
  TaskStatus.failed => 'hi',
  TaskStatus.queued => 'mid',
  TaskStatus.inProgress => 'lime',
  _ => 'accent',
};

class TaskListTile extends StatelessWidget {
  const TaskListTile({super.key, required this.task, required this.onTap});

  final DeliveryTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DgCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Mono('#${task.sequence}  ${task.ref}'),
              const Spacer(),
              StatusChip(
                label: taskStatusLabel(task.status),
                tone: taskStatusTone(task.status),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Hero(
            tag: 'recipient-${task.id}',
            child: Material(
              color: Colors.transparent,
              child: Display(task.recipient, size: 22),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            task.address,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Dg.ink2, fontSize: 16, height: 1.3),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${task.kindLabel}  ·  ${task.window}',
                  style: TextStyle(fontSize: 13, color: Dg.ink2),
                ),
              ),
              // Kurye kapıda ödeme almıyor — tutar yerine teslim kodu
              // gerekip gerekmediğini gösteriyoruz.
              if (task.otpRequired)
                const StatusChip(label: 'Kod gerekli', tone: 'mid'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact selfie-capture bottom sheet used to open/close the shift from
/// Home or Profile, without leaving the main shell (unlike the full-screen
/// onboarding [ShiftScreen]).
Future<bool> showShiftSelfieSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Dg.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (ctx) => const _ShiftSelfieSheet(),
  ).then((v) => v ?? false);
}

class _ShiftSelfieSheet extends StatefulWidget {
  const _ShiftSelfieSheet();

  @override
  State<_ShiftSelfieSheet> createState() => _ShiftSelfieSheetState();
}

class _ShiftSelfieSheetState extends State<_ShiftSelfieSheet> {
  bool _shot = false;
  double _flash = 0;

  Future<void> _action() async {
    if (_shot) {
      Navigator.pop(context, true);
      return;
    }
    setState(() => _flash = 0.85);
    HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    setState(() {
      _flash = 0;
      _shot = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Display('Vardiya başlat', size: 24)),
              GestureDetector(
                onTap: () => Navigator.pop(context, false),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Dg.elev,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.x, size: 18, color: Dg.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Kimlik kontrolü için tek selfie. Fotoğraf sadece vardiya kaydına eklenir.',
            style: TextStyle(color: Dg.ink2, fontSize: 14, height: 1.45),
          ),
          const SizedBox(height: 22),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    color: Dg.elev,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _shot ? Dg.purpleDeep : Dg.rule,
                      width: 2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        _shot ? LucideIcons.circleCheck : LucideIcons.scanFace,
                        size: _shot ? 52 : 46,
                        color: _shot ? Dg.purpleDeep : Dg.ink3,
                      ),
                      IgnorePointer(
                        child: ColoredBox(
                          color: Dg.purple.withValues(alpha: _flash),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Dg.elev,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.badgeCheck,
                  size: 17,
                  color: Dg.purpleDeep,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _shot ? 'Yüz doğrulandı. Vardiyayı başlatabilirsin.' : 'Yüzünü çerçeveye ortala, gözlük ve kask çıkarılmalı.',
                    style: TextStyle(color: Dg.ink2, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: _shot
                ? FilledButton.styleFrom(
                    backgroundColor: Dg.purple,
                    foregroundColor: Colors.white,
                  )
                : null,
            onPressed: _action,
            child: Text(_shot ? 'Vardiyayı başlat' : 'Fotoğraf çek'),
          ),
        ],
      ),
    );
  }
}

class PhoneShell extends StatelessWidget {
  const PhoneShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 520) return child;
        return ColoredBox(
          color: Dg.night,
          child: Center(
            child: Container(
              width: 390,
              height: 844,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 28,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Full-screen backdrop for entry/tören ekranları (Giriş, vardiya kapanışı):
/// [Dg.heroGradient] zemin, üst-sol köşede yumuşak mor hale, ince bir
/// perspektif ağ ve birkaç turuncu vurgu noktası. Statik (animasyonsuz) —
/// [RouteGlowBackground]'daki tek pulse'lu rota çizgisi buraya anlamca
/// uymuyor, bu yalnızca ambiyans.
class HeroBackground extends StatelessWidget {
  const HeroBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: Dg.heroGradient),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -100,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.16),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _HeroGridPainter()),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _HeroGridPainter extends CustomPainter {
  const _HeroGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (final dx in [-0.3, 0.0, 0.3, 0.6, 0.9]) {
      canvas.drawLine(
        Offset(size.width * dx, size.height * 1.15),
        Offset(size.width * (dx + 0.45), size.height * -0.15),
        grid,
      );
    }
    final dot = Paint()..color = Dg.heroAccentOrange;
    for (final p in const [
      Offset(0.78, 0.14),
      Offset(0.16, 0.42),
      Offset(0.62, 0.68),
      Offset(0.88, 0.58),
    ]) {
      canvas.drawCircle(
        Offset(size.width * p.dx, size.height * p.dy),
        2.5,
        dot..color = Dg.heroAccentOrange.withValues(alpha: 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Decorative backdrop for dark hero surfaces (shift cards, tracking maps):
/// a faint diagonal grid, a soft curved "route" line, and a pulsing glow dot
/// at one end. Purely visual — sits behind real content via a [Stack].
class RouteGlowBackground extends StatefulWidget {
  const RouteGlowBackground({
    super.key,
    this.dotAlignment = Alignment.topRight,
  });

  /// Where the pulsing glow dot sits, in the painted area's local space.
  final Alignment dotAlignment;

  @override
  State<RouteGlowBackground> createState() => _RouteGlowBackgroundState();
}

class _RouteGlowBackgroundState extends State<RouteGlowBackground>
    with SingleTickerProviderStateMixin {
  // Bounded, not infinite: pumpAndSettle() gives up after ~10s of pumped
  // time regardless of how the count is chosen, so this can't just be a
  // huge number — it has to actually finish quickly. It replays from
  // scratch whenever this widget is freshly built (e.g. toggling the shift
  // switch swaps in a new card instance), so it's not strictly a one-time
  // thing, just not a perpetual background loop.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(count: 4);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _RouteGlowPainter(
            pulse: _c.value,
            dotAlignment: widget.dotAlignment,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _RouteGlowPainter extends CustomPainter {
  _RouteGlowPainter({required this.pulse, required this.dotAlignment});

  final double pulse;
  final Alignment dotAlignment;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFF3A2F4D)
      ..strokeWidth = 1;
    for (final dx in [-0.25, 0.15, 0.55, 0.9]) {
      canvas.drawLine(
        Offset(size.width * dx, size.height * 1.1),
        Offset(size.width * (dx + 0.35), size.height * -0.1),
        grid,
      );
    }

    final dot = dotAlignment.alongSize(size);
    final start = Offset(size.width * -0.05, size.height * 0.85);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        size.width * 0.35,
        size.height * 0.55,
        size.width * 0.4,
        size.height * 0.95,
        dot.dx,
        dot.dy,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = Dg.purpleBright.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    final ringRadius = 5 + pulse * 16;
    canvas.drawCircle(
      dot,
      ringRadius,
      Paint()..color = Dg.purpleBright.withValues(alpha: (1 - pulse) * 0.5),
    );
    canvas.drawCircle(dot, 5, Paint()..color = Dg.purpleBright);
  }

  @override
  bool shouldRepaint(covariant _RouteGlowPainter oldDelegate) =>
      oldDelegate.pulse != pulse;
}
