import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:pinput/pinput.dart';

import 'geo.dart';
import 'l10n.dart';
import 'map_config.dart';
import 'models.dart';
import 'motion.dart';
import 'notif.dart';
import 'scan.dart';
import 'theme.dart';

/// Demo courier's base area (Güney / Denizli) — used as the map center when
/// a screen has no specific task coordinates to show (e.g. onboarding
/// previews).
const _dgDefaultMapCenter = LatLng(38.1512, 29.0614);

/// Alt rota sheet (~%42) çizgiyi örtmesin diye kamera payı.
///
/// Sol/sağ payı bilinçli olarak geniş: `fit`'e kendi konumu (self) da dahil
/// ediliyor ve o nokta sık sık durakların en doğusunda/batısında kalıyor —
/// dar bir pay bırakılınca kurye pin'i (36px) ekranın kenarına, neredeyse
/// dışına itiliyor ve "haritada yokmuş" gibi görünüyordu.
EdgeInsets mapRouteFitPadding({
  required double height,
  required double topInset,
}) {
  return EdgeInsets.fromLTRB(44, topInset + 64, 44, height * 0.42 + 12);
}

/// Metin ve ikon kısayollarının görsel boyutundan bağımsız saha dokunma alanı.
class DgTapTarget extends StatelessWidget {
  const DgTapTarget({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(
      minWidth: Dg.touchMin,
      minHeight: Dg.touchMin,
    ),
    child: Listener(
      behavior: HitTestBehavior.opaque,
      child: Align(widthFactor: 1, heightFactor: 1, child: child),
    ),
  );
}

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

/// Durum göstergesi: 6px renkli nokta + nötr metin — dolgulu rozet değil.
/// [dot] rengi tona göre otomatik seçilir (sage/sand/clay), [fg] ile
/// override edilebilir (metin her zaman [Dg.ink2], nötr kalır — vurgu
/// sadece noktada).
class DgIcon extends StatelessWidget {
  const DgIcon(
    this.icon, {
    super.key,
    this.size = 20,
    this.color,
    this.weight = 500,
  });

  final IconData icon;
  final double size;
  final Color? color;
  final int weight;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? Dg.text1;
    if (icon.fontPackage != 'lucide_icons_flutter') {
      return Icon(icon, size: size, color: ink);
    }
    return SizedBox(
      width: size,
      height: size,
      child: FittedBox(
        fit: BoxFit.contain,
        child: Text(
          String.fromCharCode(icon.codePoint),
          textAlign: TextAlign.center,
          style: Dg.lucideStyle(size: size, color: ink, weight: weight),
        ),
      ),
    );
  }
}

class DgIconChip extends StatelessWidget {
  const DgIconChip({
    super.key,
    required this.icon,
    this.accent = false,
    this.size = 40,
    this.color,
    this.background,
  });

  final IconData icon;
  final bool accent;
  final double size;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    // Vurgulu ikon mor rozetle gelir; liste satırları bir bakışta ayrışır.
    final tone = color ?? (accent ? Dg.plum : Dg.text2);
    final bg = background ?? (accent ? Dg.plumSoft : Dg.surface2);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: DgIcon(icon, size: size * 0.44, color: tone, weight: 500),
    );
  }
}

class DgProgressRing extends StatelessWidget {
  const DgProgressRing({
    super.key,
    required this.progress,
    this.size = 76,
    this.stroke = 7,
    this.child,
  });

  final double progress;
  final double size;
  final double stroke;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final target = progress.clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: target),
        duration: const Duration(milliseconds: 720),
        curve: Curves.easeOutCubic,
        builder: (_, value, inner) =>
            CustomPaint(painter: _RingPainter(value, stroke), child: inner),
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.stroke);

  final double progress;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = (size.shortestSide - stroke) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = Dg.stroke;
    canvas.drawCircle(c, r, track);
    if (progress <= 0) return;
    final rect = Rect.fromCircle(center: c, radius: r);
    final sweep = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -pi / 2,
        endAngle: 3 * pi / 2,
        colors: [Dg.brand, Dg.action, Dg.brand],
      ).createShader(rect);
    canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, sweep);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.stroke != stroke;
}

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
  final Color? bg;
  final Color? fg;

  @override
  Widget build(BuildContext context) {
    final ink =
        fg ??
        switch (tone) {
          'hi' => Dg.bad,
          'mid' => Dg.warn,
          'lo' => Dg.ok,
          'lime' => Dg.plum,
          _ => Dg.text2,
        };
    // Yumuşak dolgulu hap: rengi durumdan gelir, çerçeve yok.
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      decoration: BoxDecoration(
        color: bg ?? ink.withValues(alpha: Dg.dark ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DgIcon(
            switch (tone) {
              'hi' => LucideIcons.circleAlert,
              'mid' => LucideIcons.clock,
              'lo' => LucideIcons.circleCheck,
              'lime' => LucideIcons.truck,
              _ => LucideIcons.info,
            },
            size: 14,
            color: ink,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: Dg.typeCaption(color: ink)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Air between content rows, without decorative separator lines.
class DgDivider extends StatelessWidget {
  const DgDivider({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(height: Dg.s12);
}

/// Seçili satır: 2px marka gradyanı çerçeve.
class DgChoiceSurface extends StatelessWidget {
  const DgChoiceSurface({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Çerçeve yok: seçili seçenek dolgu rengiyle ayrışır.
    return Material(
      color: selected ? Dg.warnSoft : Dg.surface,
      borderRadius: BorderRadius.circular(Dg.radiusHero),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Dg.radiusHero),
        child: child,
      ),
    );
  }
}

class DgSelectMark extends StatelessWidget {
  const DgSelectMark({super.key, required this.selected, this.size = 22});

  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (!selected) {
      return DgIcon(LucideIcons.circle, color: Dg.ink3, size: size);
    }
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Dg.action),
      alignment: Alignment.center,
      child: DgIcon(
        LucideIcons.check,
        size: size * 0.58,
        color: Dg.onAction,
        weight: 600,
      ),
    );
  }
}

enum DgButtonTone { primary, secondary, onDark, danger, brand, ember, success }

/// Ana aksiyon dili: gradyanlı birincil, dolu ikincil, koyu zemin, kare ikon.
/// Basınca hafif küçülür; [FilledButton] + şeffaf gradyan sarmalayıcısının
/// yerine geçer.
class DgButton extends StatefulWidget {
  const DgButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailing,
    this.tone = DgButtonTone.primary,
    this.expand = true,
    this.height = 56,
    this.busy = false,
  }) : iconOnly = false,
       iconColor = null,
       fillColor = null;

  const DgButton.icon({
    super.key,
    required IconData this.icon,
    required this.onPressed,
    this.iconColor,
    this.fillColor,
    this.height = 56,
  }) : label = '',
       trailing = null,
       tone = DgButtonTone.secondary,
       expand = false,
       busy = false,
       iconOnly = true;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailing;
  final DgButtonTone tone;
  final bool expand;
  final double height;
  final bool busy;
  final bool iconOnly;
  final Color? iconColor;
  final Color? fillColor;

  @override
  State<DgButton> createState() => _DgButtonState();
}

class _DgButtonState extends State<DgButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    final primary = widget.tone == DgButtonTone.primary;
    final brand = widget.tone == DgButtonTone.brand;
    final ember = widget.tone == DgButtonTone.ember;
    final onDark = widget.tone == DgButtonTone.onDark;
    final danger = widget.tone == DgButtonTone.danger;
    final success = widget.tone == DgButtonTone.success;
    final action = primary || brand || ember;
    final ink =
        widget.iconColor ??
        (action || danger || success
            ? Dg.onAction
            : onDark
            ? Colors.white
            : Dg.ink);
    final fill =
        widget.fillColor ??
        (danger
            ? Dg.stop
            : success
            ? Dg.go
            : onDark
            ? Dg.night
            : Dg.surface);

    final body = widget.busy
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.3, color: ink),
          )
        : widget.iconOnly
        ? DgIcon(widget.icon!, size: 20, color: ink, weight: 600)
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                DgIcon(widget.icon!, size: 18, color: ink),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: Dg.sans,
                    color: ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    letterSpacing: -0.15,
                  ),
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 8),
                DgIcon(widget.trailing!, size: 18, color: ink),
              ],
            ],
          );

    final button = AnimatedScale(
      scale: _down && enabled ? 0.97 : 1,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: enabled ? 1 : 0.42,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: action && enabled ? Dg.emberGradient : null,
            color: action && enabled ? null : fill,
            borderRadius: BorderRadius.circular(Dg.radiusPill),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: max(
                widget.height,
                widget.iconOnly ? Dg.touchMin : Dg.buttonMin,
              ),
              minWidth: widget.iconOnly ? max(widget.height, Dg.touchMin) : 0,
            ),
            child: Padding(
              padding: widget.iconOnly
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Center(child: body),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.iconOnly ? null : widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: () {
          if (_down) setState(() => _down = false);
        },
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                widget.onPressed!();
              }
            : null,
        child: widget.expand && !widget.iconOnly
            ? SizedBox(width: double.infinity, child: button)
            : button,
      ),
    );
  }
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
  Widget build(BuildContext context) => Switch(
    value: value,
    onChanged: onChanged,
    activeTrackColor: activeColor ?? Dg.action,
    activeThumbColor: thumbColor ?? Dg.onAction,
    inactiveTrackColor: inactiveColor ?? Dg.surface2,
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
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
        fontSize: max(14, size),
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

  /// A permanently dark surface, with the same soft depth as other cards.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    // Card radius is unified at Dg.radiusHero across the whole app now —
    // [hero] only still switches shadow weight/fill below, not shape.
    const radius = Dg.rLg;
    final body = Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(Dg.s16),
      decoration: BoxDecoration(
        color: dark ? Dg.night : (lime ? Dg.surface2 : Dg.surface1),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: Dg.cardShadow,
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

/// Home / bildirim listesi kartı — sol çubuk her kartta aynı inset ve
/// genişlikte; ClipRRect köşeyi keser, IntrinsicHeight kayması olmaz.
class NotifCard extends StatelessWidget {
  const NotifCard({
    super.key,
    required this.notification,
    this.unread = false,
    this.onTap,
    this.onLongPress,
    this.compact = false,
  });

  final AppNotification notification;
  final bool unread;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final l = L10n.of(context);
    final titleColor = unread ? Dg.ink : Dg.ink2;
    final time = formatNotifTime(
      n.createdAt,
      DateTime.now(),
      yesterdayLabel: l.yesterday,
    );
    final pad = compact
        ? const EdgeInsets.symmetric(vertical: 10)
        : const EdgeInsets.fromLTRB(12, 12, 12, 12);
    final row = Padding(
      padding: pad,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Okunmamış bildirimin ikonu mor rozetle öne çıkar.
          Container(
            width: compact ? 34 : 40,
            height: compact ? 34 : 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: unread ? Dg.plumSoft : Dg.elev,
              shape: BoxShape.circle,
            ),
            child: DgIcon(
              n.icon,
              size: compact ? 17 : 19,
              color: unread ? Dg.plum : Dg.text3,
              weight: 500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.notifTitle(n.title),
                  style: Dg.ui(
                    size: 15,
                    weight: unread ? FontWeight.w700 : FontWeight.w500,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  n.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Dg.ui(size: 13, color: Dg.ink3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(time, style: Dg.ui(size: 12, color: Dg.ink3)),
              if (unread) ...[
                const SizedBox(height: 8),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Dg.text2,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
          if (!compact && onTap != null) ...[
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: DgIcon(LucideIcons.chevronRight, size: 16, color: Dg.ink3),
            ),
          ],
        ],
      ),
    );
    final painted = compact
        ? row
        : DecoratedBox(
            decoration: BoxDecoration(
              color: Dg.surface1,
              borderRadius: BorderRadius.circular(Dg.rLg),
              boxShadow: Dg.cardShadow,
            ),
            child: row,
          );
    if (onTap == null && onLongPress == null) return painted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(Dg.radiusHero),
        child: painted,
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
    this.interactive = false,
    this.points = const [],
    this.encodedPolyline,
    this.roadPoints,
    this.highlightPoints,
    this.polylinePrecision = 5,
    this.estimated = false,
    this.couriers = const [],
    this.fitTo,
    this.label,
    this.showBadge = true,
    this.fitEpoch = 0,
    this.numberStops = false,
    this.fitPadding = const EdgeInsets.all(40),
    this.onTap,
    this.pinLabel,
    this.onCourierTap,
    this.selectedCourierId,
  });

  /// Hedef iğnesinin üstünde küçük balon (ör. "4 dk"). Tek hedefli
  /// haritalarda kullanılır.
  final String? pinLabel;

  /// Kurye pinine dokunulunca kurye id'si (şube haritası).
  final ValueChanged<String>? onCourierTap;

  /// Vurgulanan kurye (seçili pin büyür, turkuaz halka).
  final String? selectedCourierId;

  final int? eta;
  final double height;
  final bool clipTopOnly;

  /// Set false for a full-bleed map flush against the screen edge (e.g. a
  /// tracking screen with a bottom sheet floating over it) — no corners are
  /// rounded regardless of [clipTopOnly].
  final bool rounded;

  /// Home screen's preview strip stays a static, non-interactive thumbnail
  /// (default false) — a small map you can accidentally drag doesn't help
  /// anyone. [RouteScreen]'s full map passes true so the courier can
  /// actually pan/zoom around today's stops.
  final bool interactive;
  final List<LatLng> points;

  /// Real road-following geometry from `GET /v1/routes/current` (Google
  /// encoded polyline, see lib/geo.dart). When present, this draws the line
  /// instead of the straight segments between [points] — [points] still
  /// supplies the stop markers either way. Prefer [roadPoints] when the
  /// decoder precision is not 5 (OSRM/Mapbox `polyline6`).
  final String? encodedPolyline;

  /// Pre-decoded road vertices. Wins over [encodedPolyline].
  final List<LatLng>? roadPoints;

  /// Current leg (origin → next stop), painted in brand purple on top.
  final List<LatLng>? highlightPoints;

  final int polylinePrecision;

  /// True when the line is bird-flight / locally guessed. Drawn dashed so
  /// the courier does not treat it as a driven path.
  final bool estimated;
  final List<FleetCourier> couriers;
  final List<LatLng>? fitTo;
  final String? label;
  final bool showBadge;
  final int fitEpoch;

  /// Rota ekranı: durakları 1…n numaralandır. Tek-nokta şeritlerde kapalı.
  final bool numberStops;

  /// Interactive fit — rota sheet altı kapalıyken alt padding büyütülür.
  final EdgeInsets fitPadding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final center = points.isNotEmpty ? points.first : _dgDefaultMapCenter;
    final decoded = roadPoints != null && roadPoints!.length > 1
        ? roadPoints!
        : encodedPolyline != null && encodedPolyline!.isNotEmpty
        ? decodePolyline(encodedPolyline!, precision: polylinePrecision)
        : const <LatLng>[];
    final line = decoded.length > 1
        ? decoded
        : [
            for (final c in couriers.where((c) => c.self)) LatLng(c.lat, c.lng),
            ...points,
          ];
    final highlight = highlightPoints != null && highlightPoints!.length > 1
        ? highlightPoints!
        : const <LatLng>[];
    final markers = !estimated && line.length > 1
        ? alignStopsToRoute(points, line)
        : points;
    final fit = [
      ...?fitTo,
      if (fitTo == null) ...line,
      if (fitTo == null) ...markers,
      if (fitTo == null)
        for (final c in couriers.where((c) => c.self)) LatLng(c.lat, c.lng),
    ];
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
              ignoring: !interactive,
              child: RepaintBoundary(
                child: _StableMapView(
                  center: center,
                  fit: fit,
                  line: line,
                  highlight: highlight,
                  points: markers,
                  couriers: couriers,
                  estimated: estimated,
                  interactive: interactive,
                  fitEpoch: fitEpoch,
                  numberStops: numberStops,
                  fitPadding: fitPadding,
                  pinLabel: pinLabel,
                  onCourierTap: onCourierTap,
                  selectedCourierId: selectedCourierId,
                ),
              ),
            ),
            if (showBadge)
              Positioned(
                right: 12,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    // Sabit koyu zemin: bu rozet her zaman açık renkli harita
                    // karosunun üstünde duruyor (map_config.dart, haritayı
                    // temadan bağımsız hep açık tutuyor) — Dg.ink kullanılırsa
                    // koyu temada neredeyse beyaza döner ve altındaki sabit
                    // beyaz yazıyla kontrastı kaybolur.
                    color: Dg.night,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label ?? (eta == null ? 'Sıradaki durak' : '~$eta dk'),
                    style: const TextStyle(
                      fontFamily: Dg.mono,
                      color: Colors.white,
                      fontSize: 14,
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

/// Doygunluğu %35'e indirir ve çok az aydınlatır.
const _calmMapFilter = ColorFilter.matrix(<double>[
  0.4882, 0.4648, 0.0469, 0, 6, //
  0.1382, 0.8148, 0.0469, 0, 6, //
  0.1382, 0.4648, 0.3969, 0, 6, //
  0, 0, 0, 1, 0,
]);

/// Kamera [MapController] ile yaşar — session her notify ettiğinde
/// FlutterMap yeniden yaratılıp zoom sıfırlanmasın.
class _StableMapView extends StatefulWidget {
  const _StableMapView({
    required this.center,
    required this.fit,
    required this.line,
    required this.highlight,
    required this.points,
    required this.couriers,
    required this.estimated,
    required this.interactive,
    required this.fitEpoch,
    required this.numberStops,
    required this.fitPadding,
    this.pinLabel,
    this.onCourierTap,
    this.selectedCourierId,
  });

  final String? pinLabel;
  final ValueChanged<String>? onCourierTap;
  final String? selectedCourierId;
  final LatLng center;
  final List<LatLng> fit;
  final List<LatLng> line;
  final List<LatLng> highlight;
  final List<LatLng> points;
  final List<FleetCourier> couriers;
  final bool estimated;
  final bool interactive;
  final int fitEpoch;
  final bool numberStops;
  final EdgeInsets fitPadding;

  @override
  State<_StableMapView> createState() => _StableMapViewState();
}

class _StableMapViewState extends State<_StableMapView>
    with TickerProviderStateMixin {
  final _controller = MapController();
  String? _fitKey;

  /// Kurye iğneleri yeni konuma 800 ms'de kayar; yalnız konum değişince
  /// çalışır, hareket azaltılmışsa sıçrar. Yalnız iğne katmanı yeniden
  /// çizilir.
  late final AnimationController _pins = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  Map<String, LatLng> _pinFrom = const {};
  Map<String, LatLng> _pinTo = const {};

  Map<String, LatLng> get _courierPoints => {
    for (final c in widget.couriers) c.id: LatLng(c.lat, c.lng),
  };

  LatLng? _pinAt(String id) {
    final a = _pinFrom[id], b = _pinTo[id];
    if (a == null || b == null) return b;
    final t = Curves.easeInOutCubic.transform(_pins.value);
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  @override
  void didUpdateWidget(covariant _StableMapView old) {
    super.didUpdateWidget(old);
    final next = _courierPoints;
    final moved = next.entries.any((e) {
      final was = _pinTo[e.key];
      return was != null &&
          (was.latitude != e.value.latitude ||
              was.longitude != e.value.longitude);
    });
    if (moved && !inWidgetTest && !MediaQuery.disableAnimationsOf(context)) {
      _pinFrom = {
        for (final e in next.entries) e.key: _pinAt(e.key) ?? e.value,
      };
      _pinTo = next;
      _pins.forward(from: 0);
    } else {
      _pinFrom = next;
      _pinTo = next;
    }
  }

  /// Kadraj değişince kamera sıçramaz, kısa bir geçişle kayar. İlk
  /// kadrajda ve "hareketi azalt" açıkken geçiş yoktur.
  late final AnimationController _glide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  bool _fittedOnce = false;
  LatLng? _fromCenter, _toCenter;
  double _fromZoom = 0, _toZoom = 0;

  @override
  void initState() {
    super.initState();
    _pinFrom = _pinTo = _courierPoints;
    _glide.addListener(() {
      final a = _fromCenter, b = _toCenter;
      if (a == null || b == null) return;
      final t = Curves.easeOutCubic.transform(_glide.value);
      try {
        _controller.move(
          LatLng(
            a.latitude + (b.latitude - a.latitude) * t,
            a.longitude + (b.longitude - a.longitude) * t,
          ),
          _fromZoom + (_toZoom - _fromZoom) * t,
        );
      } catch (_) {}
    });
  }

  void _goTo(LatLng center, double zoom) {
    final first = !_fittedOnce;
    _fittedOnce = true;
    final still =
        first || MediaQuery.disableAnimationsOf(context) || inWidgetTest;
    if (still) {
      _controller.move(center, zoom);
      return;
    }
    final cam = _controller.camera;
    _fromCenter = cam.center;
    _fromZoom = cam.zoom;
    _toCenter = center;
    _toZoom = zoom;
    _glide.forward(from: 0);
  }

  @override
  void dispose() {
    _pins.dispose();
    _glide.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Dokunulabilen haritada kullanıcının kaydırmasını ezmemek için yalnız
  /// sayılar; sabit (kart) haritada kadrajın kendisi de anahtara girer ki
  /// görevler ve konum sonradan gelince harita yeniden kadrajlansın.
  String get _key {
    final base =
        '${widget.line.length}|${widget.points.length}|${widget.couriers.length}|${widget.fit.length}|${widget.fitEpoch}|${widget.fitPadding}';
    if (widget.interactive || widget.fit.isEmpty) return base;
    final a = widget.fit.first;
    final b = widget.fit.last;
    String r(double v) => v.toStringAsFixed(4);
    return '$base|${r(a.latitude)},${r(a.longitude)}|${r(b.latitude)},${r(b.longitude)}';
  }

  /// Dolgu haritadan büyükse (alçak kart haritası) kadraj hesabı çöker ve
  /// harita dünya ölçeğine uzaklaşır; dolgu harita boyuna göre kısılır.
  EdgeInsets _safePadding() {
    final size = context.size;
    final pad = widget.fitPadding;
    if (size == null || size.isEmpty) return pad;
    double cap(double v, double max) => v > max ? max : v;
    return EdgeInsets.fromLTRB(
      cap(pad.left, size.width / 4),
      cap(pad.top, size.height / 4),
      cap(pad.right, size.width / 4),
      cap(pad.bottom, size.height / 4),
    );
  }

  /// Kadraja girecek noktalar birbirine çok yakınsa (kurye durağın
  /// dibinde) sınır kutusu neredeyse sıfırdır ve otomatik kadraj dünya
  /// ölçeğine savrulabilir; o durumda orta nokta sabit yakınlıkla gösterilir.
  LatLng? get _tightCenter {
    final fit = widget.fit;
    if (fit.length < 2) return null;
    var minLat = fit.first.latitude, maxLat = minLat;
    var minLng = fit.first.longitude, maxLng = minLng;
    for (final p in fit) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final span = haversineMeters(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
    if (span > _tightSpanMeters) return null;
    return LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
  }

  static const _tightSpanMeters = 300.0;
  static const _tightZoom = 16.6;

  void _fitIfNeeded() {
    if (widget.fit.isEmpty) return;
    if (widget.interactive && widget.fit.length < 2) return;
    if (_fitKey == _key) return;
    _fitKey = _key;
    try {
      if (widget.fit.length < 2) {
        _goTo(widget.fit.first, 14.5);
        return;
      }
      final tight = _tightCenter;
      if (tight != null) {
        _goTo(tight, _tightZoom);
        return;
      }
      final target = CameraFit.coordinates(
        coordinates: widget.fit,
        padding: _safePadding(),
        maxZoom: 17,
      ).fit(_controller.camera);
      _goTo(target.center, target.zoom);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitIfNeeded();
    });
    final fit = widget.fit;
    final center = widget.center;
    final tight = _tightCenter;
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: tight ?? (fit.isNotEmpty ? fit.first : center),
        initialZoom: tight != null
            ? _tightZoom
            : fit.length > 1
            ? 13.4
            : 14.5,
        initialCameraFit: tight == null && !widget.interactive && fit.length > 1
            ? CameraFit.coordinates(
                coordinates: fit,
                padding: widget.fitPadding,
                maxZoom: 17,
              )
            : null,
        interactionOptions: InteractionOptions(
          flags: widget.interactive
              ? InteractiveFlag.all
              : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: mapTileUrlTemplate,
          userAgentPackageName: 'com.dijigoo.dijigooKurye',
          tileDimension: useMapboxTiles ? 512 : 256,
          zoomOffset: useMapboxTiles ? -1 : 0,
          // Sokak haritasının sarı-turuncu kalabalığı kısılır: sokak adları
          // okunur kalır, rota ve iğneler öne çıkar.
          tileBuilder: useMapboxTiles
              ? null
              : (context, tile, _) =>
                    ColorFiltered(colorFilter: _calmMapFilter, child: tile),
        ),
        if (widget.line.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.line,
                // Tek bacak (kart, görev) mor çizilir; günün tamamında
                // gidilecek bacak mor, geri kalanı sakin koyu gri.
                color: widget.estimated
                    ? Dg.night.withValues(alpha: 0.45)
                    : widget.highlight.length > 1
                    ? const Color(0xFF59605C)
                    : Dg.neon,
                strokeWidth: widget.estimated ? 3.4 : 4.6,
                borderStrokeWidth: widget.estimated ? 0 : 2,
                borderColor: Colors.white,
                strokeCap: StrokeCap.round,
                strokeJoin: StrokeJoin.round,
                pattern: widget.estimated
                    ? StrokePattern.dashed(segments: const [10, 8])
                    : const StrokePattern.solid(),
              ),
              if (!widget.estimated && widget.highlight.length > 1)
                Polyline(
                  points: widget.highlight,
                  color: Dg.neon,
                  strokeWidth: 5.6,
                  borderStrokeWidth: 1.6,
                  borderColor: Colors.white,
                  strokeCap: StrokeCap.round,
                  strokeJoin: StrokeJoin.round,
                ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (var i = 0; i < widget.points.length; i++)
              Marker(
                point: widget.points[i],
                width: widget.numberStops
                    ? 28
                    : (i == widget.points.length - 1 ? 32 : 14),
                height: widget.numberStops
                    ? 28
                    : (i == widget.points.length - 1 ? 40 : 14),
                // Hedef iğnesinin ucu tam adrese değer.
                alignment: !widget.numberStops && i == widget.points.length - 1
                    ? Alignment.topCenter
                    : Alignment.center,
                child: widget.numberStops
                    ? _StopNumber(
                        index: i + 1,
                        next: i == 0,
                        last: i == widget.points.length - 1,
                      )
                    : i == widget.points.length - 1
                    ? const _DestinationPin()
                    : const _WaypointDot(),
              ),
            if (widget.pinLabel != null &&
                !widget.numberStops &&
                widget.points.isNotEmpty)
              Marker(
                point: widget.points.last,
                width: 120,
                height: 78,
                alignment: Alignment.topCenter,
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: _PinBubble(text: widget.pinLabel!),
                  ),
                ),
              ),
            if (widget.points.isEmpty && widget.couriers.isEmpty)
              Marker(
                point: center,
                width: 30,
                height: 30,
                child: const _DestinationPin(),
              ),
          ],
        ),
        if (widget.couriers.isNotEmpty)
          AnimatedBuilder(
            animation: _pins,
            builder: (context, _) => MarkerLayer(
              markers: [
                for (final c in widget.couriers)
                  Marker(
                    point: _pinAt(c.id) ?? LatLng(c.lat, c.lng),
                    width: c.self || c.id == widget.selectedCourierId ? 38 : 30,
                    height: c.self || c.id == widget.selectedCourierId
                        ? 38
                        : 30,
                    child: widget.onCourierTap == null
                        ? _CourierPin(courier: c)
                        : GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => widget.onCourierTap!(c.id),
                            child: _CourierPin(
                              courier: c,
                              selected: c.id == widget.selectedCourierId,
                            ),
                          ),
                  ),
              ],
            ),
          ),
        RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          popupInitialDisplayDuration: Duration.zero,
          showFlutterMapAttribution: false,
          attributions: [
            TextSourceAttribution(
              useMapboxTiles ? '© Mapbox © OpenStreetMap' : '© Esri',
            ),
          ],
        ),
      ],
    );
  }
}

/// [MapStrip]'in durak/hedef karalaması — marka gradyanı + beyaz halka +
/// yumuşak gölge, önceki düz "beyaz köşeli kutu" yer tutucunun yerine.
class _DestinationPin extends StatelessWidget {
  const _DestinationPin();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _PinPainter(),
      child: Align(
        alignment: const Alignment(0, -0.62),
        child: Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// Hedef iğnesinin üstündeki süre balonu.
class _PinBubble extends StatelessWidget {
  const _PinBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        maxLines: 1,
        style: const TextStyle(
          fontFamily: Dg.sans,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF101010),
          height: 1.1,
        ),
      ),
    );
  }
}

/// Damla biçimli hedef iğnesi: ucu kutunun alt ortasındadır.
class _PinPainter extends CustomPainter {
  const _PinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2 - 2;
    final c = Offset(size.width / 2, r + 2);
    final tip = Offset(size.width / 2, size.height - 1);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..quadraticBezierTo(
        c.dx - r * 0.25,
        c.dy + r * 1.05,
        c.dx - r * 0.82,
        c.dy + r * 0.57,
      )
      ..arcToPoint(
        Offset(c.dx + r * 0.82, c.dy + r * 0.57),
        radius: Radius.circular(r),
        largeArc: true,
      )
      ..quadraticBezierTo(c.dx + r * 0.25, c.dy + r * 1.05, tip.dx, tip.dy)
      ..close();
    canvas.drawShadow(path, const Color(0x66000000), 3, false);
    canvas.drawPath(path, Paint()..color = Dg.orange);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_PinPainter oldDelegate) => false;
}

/// Rotadaki durak sırası — 1 = sıradaki (mor), son = hedef.
class _StopNumber extends StatelessWidget {
  const _StopNumber({
    required this.index,
    required this.next,
    required this.last,
  });

  final int index;
  final bool next;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final fill = next ? Dg.neon : (last ? Dg.night : Dg.surface);
    final ink = next
        ? Dg.onNeon
        : last
        ? Dg.onStatus
        : Dg.ink;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(
          color: next ? Colors.white : Dg.ink.withValues(alpha: 0.35),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (next ? Dg.neon : Dg.night).withValues(alpha: 0.28),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '$index',
        style: TextStyle(
          fontFamily: Dg.mono,
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
      ),
    );
  }
}

/// Rotadaki ara duraklar için nötr, küçük nokta — hedef pin'iyle karışmaz.
class _WaypointDot extends StatelessWidget {
  const _WaypointDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Dg.surface,
        border: Border.all(color: Dg.ink3, width: 1.6),
      ),
    );
  }
}

const _selfBlue = Color(0xFF2F7CF6);

class _CourierPin extends StatelessWidget {
  const _CourierPin({required this.courier, this.selected = false});

  final FleetCourier courier;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    // Kendi konumun: yön iddia etmeyen mavi nokta ve yumuşak hale.
    if (courier.self) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _selfBlue.withValues(alpha: 0.22),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _selfBlue,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0x55000000), blurRadius: 4),
            ],
          ),
        ),
      );
    }
    final ring = selected
        ? Dg.brandTurquoise
        : courier.status == 'offline'
        ? const Color(0xFF9CA3AF)
        : courier.status == 'out'
        ? Dg.brandBlue
        : courier.onBreak
        ? const Color(0xFFFFCB52)
        : Dg.go;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Dg.night,
        border: Border.all(
          color: ring,
          width: courier.self || selected ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: ring.withValues(alpha: 0.45),
            blurRadius: courier.self ? 10 : 6,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: courier.photoUrl != null
          ? ClipOval(
              child: Image.asset(
                courier.photoUrl!,
                fit: BoxFit.cover,
                width: courier.self ? 28 : 22,
                height: courier.self ? 28 : 22,
              ),
            )
          : courier.name.trim().isEmpty
          ? DgIcon(LucideIcons.user, size: 13, color: Colors.white, weight: 600)
          // Haritada kimin kim olduğu baş harflerden anlaşılır.
          : Text(
              courier.name
                  .trim()
                  .split(RegExp(r'\s+'))
                  .take(2)
                  .map((p) => p[0])
                  .join()
                  .toUpperCase(),
              style: const TextStyle(
                fontFamily: Dg.sans,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1,
              ),
            ),
    );
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
    this.frontCamera = false,
  });

  final bool captured;
  final ValueChanged<String?> onCapture;
  final String hint;
  final String capturedLabel;
  final double aspectRatio;
  final bool frontCamera;

  @override
  State<Viewfinder> createState() => _ViewfinderState();
}

class _ViewfinderState extends State<Viewfinder> {
  double _flash = 0;

  Future<void> _shoot() async {
    final path = await capturePhoto(front: widget.frontCamera);
    if (!mounted) return;
    if (path == null && !inWidgetTest) {
      // Simulator / izin yok: yine de kanıt adımını tamamla.
    }
    setState(() => _flash = 0.35);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (mounted) setState(() => _flash = 0);
    HapticFeedback.mediumImpact();
    widget.onCapture(path);
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
                        colors: [Color(0xFF35234F), Color(0xFF100C22)],
                      ),
                    ),
                  ),
                if (widget.captured)
                  Center(
                    child: DgIcon(
                      LucideIcons.doorOpen,
                      color: Dg.ok,
                      size: 48,
                      weight: 600,
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
            child: DgIcon(
              widget.captured ? LucideIcons.check : LucideIcons.circle,
              color: Colors.white,
              size: widget.captured ? 28 : 22,
              weight: 600,
            ),
          ),
        ),
        if (widget.captured)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Konum eklenecek. Galeri kapalı.',
              style: TextStyle(color: Dg.ink2, fontSize: 14),
            ),
          ),
      ],
    );
  }
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
      obscureText: true,
      obscuringCharacter: '•',
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
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Verilirse ikon ve yazı bu renkte olur (ör. arama yeşil).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              DgIcon(icon, color: color ?? Dg.ink, size: 20),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Dg.ui(size: 12, weight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
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
        ),
        child: Text(
          'DEMO',
          style: TextStyle(
            fontFamily: Dg.mono,
            color: Dg.ink,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
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
        final maxDrag = (c.maxWidth - thumb - 8).clamp(80.0, 400.0);
        return Container(
          height: max(64, MediaQuery.textScalerOf(context).scale(16) * 2 + 24),
          decoration: BoxDecoration(
            gradient: Dg.emberGradient,
            borderRadius: BorderRadius.circular(Dg.radiusPill),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Center(
                child: Text(
                  widget.label,
                  style: Dg.ui(
                    size: 15,
                    weight: FontWeight.w600,
                    color: Dg.onAction,
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
                    setState(() => _x = (_x + d.delta.dx).clamp(0, maxDrag));
                  },
                  onHorizontalDragEnd: (_) {
                    if (_x > maxDrag * 0.82) {
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
                    decoration: const BoxDecoration(
                      color: Dg.onAction,
                      shape: BoxShape.circle,
                    ),
                    child: DgIcon(
                      LucideIcons.chevronsRight,
                      color: Dg.action,
                      weight: 600,
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

/// Lacivert navigasyon kapsülü. Kurye tarafında ortadaki yuva tarayıcı
/// olabilir; şube sekmeleri eşit navigasyon öğeleridir.
class DgPillNav extends StatelessWidget {
  const DgPillNav({
    super.key,
    required this.index,
    required this.onChanged,
    required this.items,
    this.badges = const [],
    this.primaryIndex,
    this.compact = false,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final List<(IconData, IconData, String)> items;
  final List<int> badges;
  final int? primaryIndex;

  /// Sayfa aşağı kaydırılırken küçük hal: yalnız ikonlar, daha alçak çubuk.
  /// Çubuk yerinde kalır; içerik için yer açılır.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    Widget item(int i) {
      final selected = index == i;
      final primary = primaryIndex == i;
      final count = i < badges.length ? badges[i] : 0;
      final control = Semantics(
        selected: selected,
        button: true,
        label: count > 0 ? '${items[i].$3}, $count' : items[i].$3,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                focusColor: Dg.onDock.withValues(alpha: 0.18),
                splashColor: Dg.dockActive.withValues(alpha: 0.18),
                onTap: () {
                  if (selected) return;
                  HapticFeedback.selectionClick();
                  onChanged(i);
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: Dg.touchMin,
                    minWidth: Dg.touchMin,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: largeText ? 8 : 4,
                    ),
                    child: Flex(
                      direction: largeText ? Axis.horizontal : Axis.vertical,
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            AnimatedContainer(
                              duration: duration,
                              // Küçük halde ortadaki yuvarlak da küçülür;
                              // çubuğun boyunu o belirliyor.
                              width: largeText
                                  ? 28
                                  : primary
                                  ? (compact ? 40 : 48)
                                  : 40,
                              height: largeText
                                  ? 28
                                  : primary
                                  ? (compact ? 40 : 48)
                                  : 36,
                              alignment: Alignment.center,
                              decoration: primary
                                  ? BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: selected ? Dg.action : Dg.onDock,
                                      border: Border.all(
                                        color: Dg.mutedOnDock.withValues(
                                          alpha: 0.3,
                                        ),
                                        width: 2,
                                      ),
                                    )
                                  : BoxDecoration(
                                      // Seçili sekme: yumuşak lacivert kapsül.
                                      color: selected
                                          ? Dg.dockSelected
                                          : Dg.dockSelected.withValues(
                                              alpha: 0,
                                            ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                              child: DgIcon(
                                selected ? items[i].$2 : items[i].$1,
                                color: primary
                                    ? Dg.dock
                                    : selected
                                    ? Dg.dockActive
                                    : Dg.mutedOnDock,
                                size: largeText
                                    ? 18
                                    : primary
                                    ? (compact ? 22 : 25)
                                    : 23,
                                weight: 300,
                              ),
                            ),
                            if (count > 0)
                              Positioned(
                                top: -3,
                                right: -3,
                                child: _NavBadge(count: count),
                              ),
                          ],
                        ),
                        if (largeText) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            fit: FlexFit.loose,
                            child: AnimatedDefaultTextStyle(
                              duration: duration,
                              style: Dg.ui(
                                size: 14,
                                weight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? Dg.dockActive
                                    : Dg.mutedOnDock,
                              ).copyWith(fontSize: 12),
                              child: Text(
                                items[i].$3,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ] else if (!primary)
                          // Aşağı kaydırırken etiket kapanır. Yükseklik
                          // çarpanı ölçümde ve çizimde aynı olduğundan
                          // geçişte taşma olmaz.
                          TweenAnimationBuilder<double>(
                            tween: Tween(end: compact ? 0.0 : 1.0),
                            duration: duration,
                            curve: Curves.easeOutCubic,
                            builder: (context, t, child) => ClipRect(
                              child: Align(
                                alignment: Alignment.topCenter,
                                heightFactor: t,
                                child: Opacity(opacity: t, child: child),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: AnimatedDefaultTextStyle(
                                duration: duration,
                                style: Dg.ui(
                                  size: 14,
                                  weight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: selected
                                      ? Dg.dockActive
                                      : Dg.mutedOnDock,
                                ).copyWith(fontSize: 12),
                                // Dar ekranda kesilmek yerine küçülür.
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    items[i].$3,
                                    maxLines: 1,
                                    softWrap: false,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return Tooltip(
        message: items[i].$3,
        excludeFromSemantics: true,
        child: control,
      );
    }

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Container(
        // Yanlarda pay: ilk ve son sekmenin yazısı kenara yapışmaz.
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Dg.dock,
          borderRadius: BorderRadius.circular(36),
          boxShadow: Dg.dockShadow,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            var minWidth = Dg.touchMin;
            for (final entry in items) {
              final painter = TextPainter(
                text: TextSpan(
                  text: entry.$3,
                  style: Dg.ui(size: 14, weight: FontWeight.w700),
                ),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout();
              // Long labels wrap instead of shrinking system text.
              minWidth = max(minWidth, min(painter.width + 12, 120));
              painter.dispose();
            }
            final columns = (constraints.maxWidth / minWidth).floor().clamp(
              1,
              items.length,
            );
            if (columns == items.length || !largeText) {
              final slot = constraints.maxWidth / items.length;
              const bar = 22.0;
              final reduce = MediaQuery.disableAnimationsOf(context);
              return IntrinsicHeight(
                child: Stack(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Expanded(child: item(i)),
                      ],
                    ),
                    // İmza an: seçili sekmenin altındaki marka akışı çizgisi
                    // yaylanarak kayar. Tek AnimatedPositioned; gradyan sabit.
                    if (primaryIndex != index)
                      AnimatedPositioned(
                        duration: reduce
                            ? Duration.zero
                            : const Duration(milliseconds: 320),
                        curve: Curves.easeOutBack,
                        left: slot * index + (slot - bar) / 2,
                        bottom: 0,
                        width: bar,
                        height: 3,
                        child: const IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: Dg.brandFlow,
                              borderRadius: BorderRadius.all(
                                Radius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }
            return Wrap(
              children: [
                for (var i = 0; i < items.length; i++)
                  SizedBox(
                    width: constraints.maxWidth / columns,
                    child: item(i),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NavBadge extends StatelessWidget {
  const _NavBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Dg.action,
        border: Border.all(color: Dg.dock, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        textScaler: TextScaler.noScaling,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Dg.onAction,
          height: 1,
        ),
      ),
    );
  }
}

class DgOnlineChip extends StatelessWidget {
  const DgOnlineChip({super.key, required this.online, required this.onTap});

  final bool online;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(
          minHeight: Dg.touchMin,
          minWidth: Dg.touchMin,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PulseDot(color: online ? Dg.ok : Dg.warn),
            const SizedBox(width: 6),
            Text(
              online ? L10n.of(context).fieldOn : L10n.of(context).onBreak,
              style: Dg.ui(size: 13, weight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Boş ekran ve tanıtım görseli: iç içe yumuşak halkalar, ortada ana ikon,
/// çevresinde iki küçük vurgu. Vektördür; dosya boyutu ve ağ gerektirmez,
/// temaya kendiliğinden uyar.
class DgIllustration extends StatelessWidget {
  const DgIllustration({super.key, required this.icon, this.size = 132});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final core = size * 0.5;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Dg.plum.withValues(alpha: Dg.dark ? 0.07 : 0.05),
            ),
          ),
          Container(
            width: size * 0.74,
            height: size * 0.74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Dg.plum.withValues(alpha: Dg.dark ? 0.12 : 0.08),
            ),
          ),
          Container(
            width: core,
            height: core,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: Dg.primaryGradient,
            ),
            child: DgIcon(icon, size: core * 0.46, color: Dg.onAction),
          ),
          // Küçük vurgular: turuncu nokta ve yeşil işaret.
          Positioned(
            top: size * 0.12,
            right: size * 0.14,
            child: Container(
              width: size * 0.13,
              height: size * 0.13,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Dg.orange,
              ),
            ),
          ),
          Positioned(
            bottom: size * 0.14,
            left: size * 0.1,
            child: Container(
              width: size * 0.2,
              height: size * 0.2,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Dg.go,
                border: Border.all(color: Dg.ground, width: 3),
              ),
              child: Icon(
                LucideIcons.sparkles,
                size: size * 0.09,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DgEmptyState extends StatelessWidget {
  const DgEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
  });

  final IconData icon;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 24),
      child: Column(
        children: [
          DgIllustration(icon: icon),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Dg.ui(size: 18, weight: FontWeight.w700),
          ),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: Dg.ui(size: 14, color: Dg.ink3, height: 1.4),
            ),
          ],
        ],
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
    this.photoUrl,
  });

  final String name;
  final double size;

  /// Shows a small status dot in the bottom-right corner when true (e.g. the
  /// courier's own online/offline toggle on Home).
  final bool online;

  /// Asset or http portrait. When null, [personPhotoAsset] is tried.
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts
        .take(2)
        .map((p) => p.isEmpty ? '' : p[0])
        .join()
        .toUpperCase();
    final src = photoUrl ?? personPhotoAsset(name);
    final face = _face(initials, src);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          face,
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

  Widget _face(String initials, String? src) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      // Nötr zemin: turuncu yalnız eylem düğmelerinde.
      decoration: BoxDecoration(shape: BoxShape.circle, color: Dg.elev),
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: Dg.sans,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.32,
          color: Dg.ink,
        ),
      ),
    );
    if (src == null || src.isEmpty) return fallback;
    final image = src.startsWith('assets/')
        ? Image.asset(
            src,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          )
        : Image.network(
            src,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          );
    // Fotoğraf yüklenirken ya da gelmezse yer boş kalmasın: baş harfler
    // altta durur, fotoğraf üstüne biner.
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          fallback,
          ClipOval(child: image),
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
    this.glass = false,
    this.soft = false,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final bool glass;

  /// Koyu zeminde yüzen hap. Alt çizgi yerine seçili sekme kart gibi durur.
  final bool soft;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final style = Dg.ui(size: 14, weight: FontWeight.w600);
        final widths = labels.map((label) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final width = max(96.0, painter.width + 32);
          painter.dispose();
          return width;
        }).toList();
        final scroll =
            widths.fold<double>(0, (a, b) => a + b) + 8 * (labels.length - 1) >
            constraints.maxWidth;
        Widget tab(int i) => Semantics(
          selected: index == i,
          button: true,
          child: Material(
            // Seçili sekme ters renkli hap; turuncu kullanılmaz.
            color: index == i ? Dg.ink : Dg.surface,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onChanged(i),
              child: Container(
                constraints: const BoxConstraints(minHeight: Dg.touchMin),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: style.copyWith(
                    color: index == i ? Dg.ground : Dg.ink2,
                  ),
                ),
              ),
            ),
          ),
        );
        final row = Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              if (scroll)
                SizedBox(width: widths[i], child: tab(i))
              else
                Expanded(child: tab(i)),
            ],
          ],
        );
        return scroll
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: row,
              )
            : row;
      },
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
    this.valueColor,
    this.icon,
    this.iconColor,
  });

  /// Kutunun sağ üstünde küçük ikon: sayının neyi saydığı bir bakışta
  /// anlaşılır.
  final IconData? icon;

  /// İkon rozetinin rengi; verilmezse mor.
  final Color? iconColor;

  /// Verilirse sayı bu renkte yazılır (ör. ilgi bekleyen kutuda kehribar).
  final Color? valueColor;
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Dg.ui(
                      size: 14,
                      weight: FontWeight.w500,
                      height: 1.25,
                      color: dark ? Dg.mutedOnNight : Dg.ink3,
                    ),
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 6),
                  // Renkli rozet: kutunun ne saydığı renkten de okunur.
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: (iconColor ?? Dg.plum).withValues(
                        alpha: Dg.dark ? 0.18 : 0.12,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: DgIcon(
                      icon!,
                      size: 18,
                      color: iconColor ?? Dg.plum,
                      weight: 600,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Dg.stat(
                size: 26,
                color: valueColor ?? (dark ? Colors.white : Dg.ink),
              ),
            ),
            if (sub != null) ...[
              const SizedBox(height: 4),
              Text(
                sub!,
                style: Dg.ui(
                  size: 13,
                  color: subColor ?? (dark ? Dg.mutedOnNight : Dg.ink2),
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
        borderRadius: BorderRadius.circular(Dg.rSm),
      ),
      child: DgIcon(icon, color: ink, size: size * 0.46, weight: 600),
    );
  }
}

String taskStatusLabel(TaskStatus s, [L10n? l10n]) =>
    (l10n ?? const L10n('tr')).statusOf(s);

String taskStatusTone(TaskStatus s) => switch (s) {
  TaskStatus.delivered => 'lo',
  TaskStatus.failed => 'hi',
  TaskStatus.queued => 'mid',
  TaskStatus.inProgress => 'lime',
  TaskStatus.cancelled => 'mid',
  _ => 'accent',
};

/// Durak rozeti — SLA'sı kaçmış açık duraklarda normal durum yerine
/// "Gecikti" gösterir (toplantı maddesi 7: gecikme görünür olsun).
String taskChipLabel(DeliveryTask task, [L10n? l10n]) => task.isLate
    ? (l10n ?? const L10n('tr')).lateStop
    : taskStatusLabel(task.status, l10n);

String taskChipTone(DeliveryTask task) =>
    task.isLate ? 'hi' : taskStatusTone(task.status);

String taskRefLine(DeliveryTask task, {int? visit}) {
  final n = visit ?? task.sequence;
  if (n <= 0) return task.ref;
  return '#$n  ·  ${task.ref}';
}

String taskBadgeNumber(DeliveryTask task, {int? visit}) {
  final n = visit ?? task.sequence;
  return n <= 0 ? '·' : '$n';
}

class DgRetryBanner extends StatelessWidget {
  const DgRetryBanner({
    super.key,
    required this.message,
    required this.onRetry,
    required this.retryLabel,
  });

  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Dg.redBg,
      borderRadius: BorderRadius.circular(Dg.radius),
      child: InkWell(
        onTap: onRetry,
        borderRadius: BorderRadius.circular(Dg.radius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              DgIcon(LucideIcons.circleAlert, size: 16, color: Dg.bad),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: Dg.ui(
                    size: 13,
                    weight: FontWeight.w600,
                    color: Dg.red,
                  ),
                ),
              ),
              Text(
                retryLabel,
                style: Dg.ui(size: 13, weight: FontWeight.w700, color: Dg.red),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TaskListTile extends StatelessWidget {
  const TaskListTile({super.key, required this.task, required this.onTap});

  final DeliveryTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Mono(taskRefLine(task)),
                const Spacer(),
                StatusChip(
                  label: taskChipLabel(task, L10n.of(context)),
                  tone: taskChipTone(task),
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
                    '${L10n.of(context).kindOf(task.kind)}  ·  ${task.window}',
                    style: TextStyle(fontSize: 14, color: Dg.ink2),
                  ),
                ),
                if (task.otpRequired)
                  StatusChip(label: L10n.of(context).codeRequired, tone: 'mid'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact selfie-capture bottom sheet used to open/close the shift from
/// Home or Profile, without leaving the main shell (unlike the full-screen
/// onboarding [ShiftScreen]).
Future<bool> confirmEndShift(BuildContext context) async {
  final l = L10n.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.endShiftTitle),
          content: Text(l.endShiftBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.endShiftTitle, style: TextStyle(color: Dg.hi)),
            ),
          ],
        ),
      ) ??
      false;
}

Future<bool> showShiftSelfieSheet(
  BuildContext context, {
  required Future<void> Function(String? path) onPhoto,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Dg.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (ctx) => _ShiftSelfieSheet(onPhoto: onPhoto),
  ).then((v) => v ?? false);
}

class _ShiftSelfieSheet extends StatefulWidget {
  const _ShiftSelfieSheet({required this.onPhoto});

  final Future<void> Function(String? path) onPhoto;

  @override
  State<_ShiftSelfieSheet> createState() => _ShiftSelfieSheetState();
}

class _ShiftSelfieSheetState extends State<_ShiftSelfieSheet> {
  bool _shot = false;
  bool _busy = false;
  double _flash = 0;

  Future<void> _action() async {
    if (_shot) {
      Navigator.pop(context, true);
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final path = await capturePhoto(front: true);
      if (!mounted) return;
      if (kReleaseMode && (path == null || path.isEmpty)) return;
      await widget.onPhoto(path);
      if (!mounted) return;
      setState(() => _flash = 0.85);
      HapticFeedback.mediumImpact();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted) return;
      setState(() {
        _flash = 0;
        _shot = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
              Expanded(
                child: Display(L10n.of(context).startShiftTitle, size: 24),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context, false),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Dg.elev,
                    shape: BoxShape.circle,
                  ),
                  child: DgIcon(LucideIcons.x, size: 18, color: Dg.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            L10n.of(context).selfieIntro,
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
                      DgIcon(
                        _shot ? LucideIcons.circleCheck : LucideIcons.scanFace,
                        size: _shot ? 52 : 46,
                        color: _shot ? Dg.brand : Dg.ink3,
                        weight: 600,
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
                DgIcon(
                  LucideIcons.badgeCheck,
                  size: 17,
                  color: Dg.brand,
                  weight: 600,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _shot
                        ? L10n.of(context).faceOk
                        : L10n.of(context).faceAlign,
                    style: TextStyle(color: Dg.ink2, fontSize: 14, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DgButton(
            label: _shot
                ? L10n.of(context).startShiftCta
                : L10n.of(context).takePhoto,
            icon: _shot ? LucideIcons.sun : LucideIcons.camera,
            busy: _busy,
            onPressed: _busy ? null : _action,
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

/// Giriş ve tören ekranları için marka zemini.
/// [vivid] girişte yavaş nefes alan bir ışık ve alçak ızgara ekler.
class HeroBackground extends StatelessWidget {
  const HeroBackground({super.key, this.vivid = false, required this.child});

  final bool vivid;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (vivid) return _VividHero(child: child);
    return DecoratedBox(
      decoration: BoxDecoration(gradient: Dg.heroGradient),
      child: child,
    );
  }
}

class _VividHero extends StatefulWidget {
  const _VividHero({required this.child});

  final Widget child;

  @override
  State<_VividHero> createState() => _VividHeroState();
}

class _VividHeroState extends State<_VividHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..value = 0.35;
    final test = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    // Tek seferlik süzülme; boşta sürekli kare üretmesin (perf bütçesi).
    if (!test) {
      _pulse.animateTo(
        0.65,
        duration: const Duration(milliseconds: 2400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(decoration: BoxDecoration(gradient: Dg.heroGradient)),
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) => CustomPaint(
            painter: _CalmGridPainter(
              t: MediaQuery.disableAnimationsOf(context) ? 0.35 : _pulse.value,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _CalmGridPainter extends CustomPainter {
  const _CalmGridPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final breath = 0.72 + 0.28 * t;

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                Color.fromRGBO(255, 255, 255, 0.10 * breath),
                Color.fromRGBO(37, 99, 255, 0.10 * breath),
                const Color(0x00000000),
              ],
              stops: const [0, 0.22, 1],
            ).createShader(
              Rect.fromCircle(
                center: Offset(w * 0.5, -h * 0.02),
                radius: w * 0.95,
              ),
            ),
    );

    canvas.drawCircle(
      Offset(w * 0.82, h * 0.92),
      w * 0.55,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                Color.fromRGBO(6, 214, 255, 0.07 * breath),
                const Color(0x00000000),
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset(w * 0.82, h * 0.92),
                radius: w * 0.55,
              ),
            ),
    );

    final horizon = h * 0.58;
    final vp = Offset(w * 0.5, horizon);
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Color.fromRGBO(190, 160, 255, 0.07 + 0.05 * t);

    for (var i = 1; i <= 9; i++) {
      final p = i / 9;
      final y = horizon + (h - horizon) * p * p;
      canvas.drawLine(Offset(0, y), Offset(w, y), grid);
    }
    for (var i = -6; i <= 6; i++) {
      final x = w * 0.5 + i * (w * 0.24);
      canvas.drawLine(Offset(x, h), vp, grid);
    }

    final rng = Random(4);
    final dot = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 16; i++) {
      final x = rng.nextDouble() * w;
      final y = h * 0.45 + rng.nextDouble() * h * 0.55;
      final hot = i.isEven;
      dot.color = hot
          ? Color.fromRGBO(6, 214, 255, 0.16 + 0.22 * breath)
          : Color.fromRGBO(190, 160, 255, 0.10 + 0.16 * breath);
      canvas.drawCircle(Offset(x, y), hot ? 1.8 : 1.3, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _CalmGridPainter old) => old.t != t;
}

/// Sekme içeriği dikey kaydırıldıkça alt menünün küçülüp büyümesini bildirir:
/// aşağı kaydırınca [onCompact] true, yukarı kaydırınca ya da en üste
/// gelince false.
class NavShrinkOnScroll extends StatelessWidget {
  const NavShrinkOnScroll({
    super.key,
    required this.compact,
    required this.onCompact,
    required this.child,
  });

  final bool compact;
  final ValueChanged<bool> onCompact;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.axis != Axis.vertical) return false;
        bool? next;
        if (n is UserScrollNotification) {
          // Yön bildirimi kaydırma başlarken, sayfa daha kıpırdamadan gelir;
          // bu yüzden burada "en üstte mi" diye bakılmaz. Kaydırılacak
          // içerik yoksa menü küçülmez.
          if (n.direction == ScrollDirection.reverse &&
              n.metrics.maxScrollExtent > 0) {
            next = true;
          }
          if (n.direction == ScrollDirection.forward) next = false;
        } else if (n.metrics.pixels <= 0) {
          // En üste dönünce her zaman büyük hal.
          next = false;
        }
        if (next != null && next != compact) onCompact(next);
        return false;
      },
      child: child,
    );
  }
}
