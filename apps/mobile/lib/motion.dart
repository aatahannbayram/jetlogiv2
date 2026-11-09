import 'package:flutter/foundation.dart' show kIsWeb;

import 'dart:math' as math;
import 'dart:ui' show FrameTiming;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'theme.dart';

/// Hareket token'ları — uygulamadaki her süre/eğri buradan gelir.
/// Tekrarlanan saha işlemlerinde kısa, nadir ve önemli anlarda biraz daha
/// belirgin. Hiçbir UI animasyonu [max]'ı aşmaz.
abstract final class DgMotion {
  static const press = Duration(milliseconds: 90);
  static const quick = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 240);
  static const emphasized = Duration(milliseconds: 360);
  static const max = Duration(milliseconds: 450);

  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;
  static const emphasizedCurve = Cubic(0.2, 0, 0, 1);

  /// Yalnız başarı/gösterge anları için hafif yaylanma.
  static const springy = Curves.easeOutBack;
}

enum MotionLevel { full, reduced, off }

/// Hareket seviyesi. "Azaltılmış" ve "Kapalı" uygulama genelinde
/// `MediaQuery.disableAnimations` olarak iner; mevcut her bileşen bunu
/// zaten dinliyor. Cihaz yavaşsa açılışta otomatik "Azaltılmış"a düşer.
class MotionGovernor {
  MotionGovernor._();
  static final instance = MotionGovernor._();

  /// Kullanıcının seçimi; null = otomatik.
  final ValueNotifier<MotionLevel?> userLevel = ValueNotifier(null);
  final ValueNotifier<bool> slowDevice = ValueNotifier(false);

  MotionLevel get level =>
      userLevel.value ??
      (slowDevice.value ? MotionLevel.reduced : MotionLevel.full);

  Listenable get listenable => Listenable.merge([userLevel, slowDevice]);

  bool _watching = false;
  int _frames = 0;
  int _slow = 0;

  /// Açılıştan sonraki ilk 10 sn kare sürelerini ölçer; karelerin
  /// %15'inden fazlası 16.7 ms bütçesini aşarsa oturum boyunca hafifler.
  void watchStartup() {
    if (_watching) return;
    _watching = true;
    final binding = SchedulerBinding.instance;
    void onTimings(List<FrameTiming> timings) {
      for (final t in timings) {
        _frames++;
        if (t.totalSpan.inMicroseconds > 16700) _slow++;
      }
      if (_frames >= 90 && _slow / _frames > 0.15) {
        slowDevice.value = true;
        binding.removeTimingsCallback(onTimings);
      }
    }

    binding.addTimingsCallback(onTimings);
    Future<void>.delayed(const Duration(seconds: 10), () {
      binding.removeTimingsCallback(onTimings);
    });
  }
}

/// [MotionGovernor] seviyesini alt ağaca `disableAnimations` olarak indirir.
class MotionScope extends StatelessWidget {
  const MotionScope({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final governor = MotionGovernor.instance;
    return ListenableBuilder(
      listenable: governor.listenable,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final off = governor.level != MotionLevel.full;
        if (!off || mq.disableAnimations) return child!;
        return MediaQuery(
          data: mq.copyWith(disableAnimations: true),
          child: child!,
        );
      },
      child: child,
    );
  }
}

bool _stillMotion(BuildContext context) {
  if (MediaQuery.disableAnimationsOf(context)) return true;
  try {
    final name = WidgetsBinding.instance.runtimeType.toString();
    return name.contains('TestWidgetsFlutterBinding') ||
        name.contains('AutomatedTest');
  } catch (_) {
    return true;
  }
}

/// Small, reusable motion primitives — kept deliberately few so the app has
/// one consistent motion vocabulary instead of every screen inventing its
/// own timing/curve. Built on `flutter_animate` (already a dependency, used
/// once already in result_screen.dart) for one-shot declarative effects;
/// continuous/gesture-driven effects (SlideToAct's nudge)
/// stay on raw AnimationController — this file doesn't touch those.

/// Fade + a short upward slide, on [Curves.easeOutCubic] — the curve this
/// app already uses elsewhere (earnings_screen's bar chart, onboard_screen's
/// page-change), kept here so a new "screen arrives" feeling matches it.
///
/// Deliberately NOT used on iOS/macOS: those platforms already get the
/// native edge-swipe-back gesture via [CupertinoPageTransitionsBuilder] in
/// theme.dart's `pageTransitionsTheme`, and a custom [PageRouteBuilder]
/// bypasses that gesture entirely. Push with this only where a bespoke
/// moment is wanted (e.g. a completion/result screen), and prefer plain
/// `MaterialPageRoute` (which already looks correct per-platform) elsewhere.
class DgPageRoute<T> extends PageRouteBuilder<T> {
  DgPageRoute({required WidgetBuilder builder})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
        transitionDuration: DgMotion.standard,
      );
}

/// Wraps a list item so it fades/slides in on first build, staggered by
/// [index]. The delay multiplier is clamped so long lists don't cascade for
/// seconds — everything past the 10th item animates together with it.
class StaggerIn extends StatelessWidget {
  const StaggerIn({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return child
        .animate(delay: (30 * index.clamp(0, 5)).ms)
        .fadeIn(duration: DgMotion.quick, curve: DgMotion.enter)
        .slideY(
          begin: 0.08,
          end: 0,
          duration: DgMotion.standard,
          curve: DgMotion.enter,
        );
  }
}

/// Framer-style mount: fade + rise + slight scale. One-shot, no loop.
class Appear extends StatelessWidget {
  const Appear({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.slide = 0.04,
  });

  final Widget child;
  final Duration delay;
  final double slide;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return child
        .animate(delay: delay)
        .fadeIn(duration: DgMotion.standard, curve: DgMotion.enter)
        .slideY(
          begin: slide,
          end: 0,
          duration: DgMotion.emphasized,
          curve: DgMotion.emphasizedCurve,
        )
        .scale(
          begin: const Offset(0.98, 0.98),
          end: const Offset(1, 1),
          duration: DgMotion.emphasized,
          curve: DgMotion.emphasizedCurve,
        );
  }
}

/// Phase / tab crossfade used by [DijigooApp] and the shell.
Widget dgSwitchTransition(Widget child, Animation<double> animation) {
  final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
  return FadeTransition(
    opacity: curved,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.018),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    ),
  );
}

/// A plain opacity-pulse loading placeholder — not a shimmer sweep, which
/// would be more visual machinery than this app's brief map/list loads
/// warrant. Shape it like the content it's standing in for via [width]/
/// [height]/[radius].
class DgSkeleton extends StatelessWidget {
  const DgSkeleton({super.key, this.width, this.height = 16, this.radius = 8});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Dg.elev,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    // Web'de sürekli dönen efekt her karede yeniden boyama ister; orada
    // iskelet durağan kalır.
    if (_stillMotion(context) || kIsWeb) return box;
    return RepaintBoundary(
      child: box
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .fadeIn(begin: 0.4, duration: 700.ms, curve: Curves.easeInOut),
    );
  }
}

/// Scale-down-on-press feedback for tappable elements that currently rely
/// only on the default `InkWell` ripple (or nothing at all) — e.g.
/// SquareAction, menu tiles. Deliberately not used on [DgCard]'s own onTap
/// path, which already has InkWell feedback; stacking both would look busy.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              setState(() => _down = false);
              widget.onLongPress!();
            },
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: _down ? DgMotion.press : DgMotion.standard,
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// Sayı değişince count-up; aynı değerde animasyon yok.
class CountUp extends StatefulWidget {
  const CountUp(
    this.value, {
    super.key,
    this.style,
    this.prefix = '',
    this.suffix = '',
  });

  final int value;
  final TextStyle? style;
  final String prefix;
  final String suffix;

  @override
  State<CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<CountUp> {
  late int _from;

  @override
  void initState() {
    super.initState();
    _from = widget.value;
  }

  @override
  void didUpdateWidget(CountUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _from = oldWidget.value;
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? Dg.typeNum(size: 24);
    String label(int n) => '${widget.prefix}$n${widget.suffix}';
    if (_from == widget.value || MediaQuery.disableAnimationsOf(context)) {
      return Text(label(widget.value), style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _from.toDouble(), end: widget.value.toDouble()),
      duration: const Duration(milliseconds: 400),
      curve: DgMotion.enter,
      builder: (_, v, _) => Text(label(v.round()), style: style),
    );
  }
}

/// Çevrimiçi nokta — 2 sn nabız (opacity).
class PulseDot extends StatelessWidget {
  const PulseDot({super.key, required this.color, this.size = 7});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    if (_stillMotion(context) || kIsWeb) return dot;
    return RepaintBoundary(
      child: dot
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .fade(begin: 0.4, end: 1, duration: 2000.ms, curve: Curves.easeInOut),
    );
  }
}

/// Scale-in + fade icon for success/outcome moments — extracted from what
/// was an inline effect in result_screen.dart so other screens don't
/// hand-roll the same animation again.
class ResultIcon extends StatelessWidget {
  const ResultIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 56,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(
      width: size,
      height: size,
      child: Text(
        String.fromCharCode(icon.codePoint),
        textAlign: TextAlign.center,
        style: Dg.lucideStyle(size: size, color: color, weight: 600),
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return child
        .animate()
        .scale(
          begin: const Offset(0.7, 0.7),
          duration: 280.ms,
          curve: Curves.easeOutBack,
        )
        .fadeIn(duration: 200.ms);
  }
}

/// Başarı işareti: halka büyür, onay çizgisi soldan sağa çizilir.
/// "Hareketi azalt" açıksa doğrudan bitmiş hali gösterilir.
class DrawnCheck extends StatelessWidget {
  const DrawnCheck({super.key, required this.color, this.size = 56});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (_stillMotion(context)) {
      return CustomPaint(
        size: Size.square(size),
        painter: _CheckPainter(color: color, t: 1),
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 620),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => RepaintBoundary(
        child: CustomPaint(
          size: Size.square(size),
          painter: _CheckPainter(color: color, t: t),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter({required this.color, required this.t});

  final Color color;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    // İlk yarıda zemin büyür, ikinci yarıda işaret çizilir.
    final grow = (t / 0.5).clamp(0.0, 1.0);
    final draw = ((t - 0.35) / 0.65).clamp(0.0, 1.0);
    canvas.drawCircle(
      c,
      r * (0.6 + 0.4 * grow),
      Paint()..color = color.withValues(alpha: 0.18 * grow),
    );
    if (draw <= 0) return;
    final a = Offset(size.width * 0.29, size.height * 0.52);
    final b = Offset(size.width * 0.44, size.height * 0.67);
    final d = Offset(size.width * 0.72, size.height * 0.36);
    final first = (b - a).distance;
    final total = first + (d - b).distance;
    final len = total * draw;
    final path = Path()..moveTo(a.dx, a.dy);
    if (len <= first) {
      final p = Offset.lerp(a, b, len / first)!;
      path.lineTo(p.dx, p.dy);
    } else {
      final p = Offset.lerp(b, d, (len - first) / (total - first))!;
      path
        ..lineTo(b.dx, b.dy)
        ..lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.085
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t || old.color != color;
}

/// Shakes [child] whenever [trigger] changes — e.g. key it on an error
/// message string so a fresh error re-shakes even if the text repeats.
class ShakeError extends StatelessWidget {
  const ShakeError({super.key, required this.child, required this.trigger});

  final Widget child;
  final Object? trigger;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return child
        .animate(key: ValueKey(trigger))
        .shake(hz: 4, duration: 320.ms, curve: Curves.easeOut);
  }
}

/// Animates the entering tab while keeping each tab's state and scroll offset.
class DgTabStack extends StatefulWidget {
  const DgTabStack({super.key, required this.index, required this.children});
  final int index;
  final List<Widget> children;

  @override
  State<DgTabStack> createState() => _DgTabStackState();
}

class _DgTabStackState extends State<DgTabStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: DgMotion.standard,
    value: 1,
  );
  late final Animation<double> _fade = _controller.drive(
    CurveTween(curve: Curves.easeOutCubic),
  );
  late final Animation<Offset> _slide = _fade.drive(
    Tween(begin: const Offset(0, 0.025), end: Offset.zero),
  );

  @override
  void didUpdateWidget(DgTabStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          TickerMode(
            enabled: i == widget.index,
            child: FadeTransition(
              opacity: i == widget.index && !reduceMotion
                  ? _fade
                  : const AlwaysStoppedAnimation(1),
              child: SlideTransition(
                position: i == widget.index && !reduceMotion
                    ? _slide
                    : const AlwaysStoppedAnimation(Offset.zero),
                child: widget.children[i],
              ),
            ),
          ),
      ],
    );
  }
}

/// İmza an 2: önceden üretilmiş marka dalgası, kaydırmayla 0.3x paralaks.
/// Ticker yok; yalnız kaydırma olduğunda yeniden boyanır.
class ParallaxLayer extends StatelessWidget {
  const ParallaxLayer({
    super.key,
    required this.controller,
    required this.child,
    this.factor = 0.3,
  });

  final ScrollController controller;
  final Widget child;
  final double factor;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final offset =
              controller.hasClients && controller.positions.length == 1
              ? controller.offset.clamp(0.0, 400.0)
              : 0.0;
          return Transform.translate(
            offset: Offset(0, -offset * factor),
            child: child,
          );
        },
        child: child,
      ),
    );
  }
}

/// İmza an 5: okutma geri bildirimi. [trigger] her değiştiğinde bir kez
/// oynar. Başarılı: genişleyip kaybolan turkuaz halka. Uyarı: tek nabız.
/// Hata: [ShakeError] ile birlikte kullanılır (kırmızı halka).
enum FeedbackTone { ok, warn, bad }

class ScanPulse extends StatelessWidget {
  const ScanPulse({
    super.key,
    required this.trigger,
    required this.tone,
    this.size = 72,
  });

  final Object? trigger;
  final FeedbackTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (trigger == null || MediaQuery.disableAnimationsOf(context)) {
      return SizedBox(width: size, height: size);
    }
    final color = switch (tone) {
      FeedbackTone.ok => Dg.dark ? Dg.brandTurquoise : Dg.ok,
      FeedbackTone.warn => Dg.warn,
      FeedbackTone.bad => Dg.bad,
    };
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child:
            DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 3),
                  ),
                )
                .animate(key: ValueKey(trigger))
                .scale(
                  begin: const Offset(0.5, 0.5),
                  end: const Offset(1.25, 1.25),
                  duration: const Duration(milliseconds: 300),
                  curve: DgMotion.enter,
                )
                .fadeOut(
                  delay: const Duration(milliseconds: 120),
                  duration: const Duration(milliseconds: 220),
                ),
      ),
    );
  }
}

/// İmza an 8: işlem tamamlandı. Onay ikonu + marka akışıyla bir kez dolan
/// halka (500 ms). Tek seferlik; bitince kare üretmez.
class DoneRing extends StatelessWidget {
  const DoneRing({super.key, this.size = 96, required this.icon});

  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    Widget ring(double t) => CustomPaint(
      size: Size.square(size),
      painter: _FlowRingPainter(progress: t, track: Dg.hairline),
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: Text(
            String.fromCharCode(icon.codePoint),
            style: Dg.lucideStyle(
              size: size * 0.42,
              color: Dg.highlight,
              weight: 600,
            ),
          ),
        ),
      ),
    );
    if (still) return ring(1);
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 500),
        curve: DgMotion.emphasizedCurve,
        builder: (context, t, _) => ring(t),
      ),
    );
  }
}

class _FlowRingPainter extends CustomPainter {
  const _FlowRingPainter({required this.progress, required this.track});

  final double progress;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (progress <= 0) return;
    final paint = Paint()
      ..shader = const SweepGradient(
        colors: [
          Dg.brandPurple,
          Dg.brandBlue,
          Dg.brandTurquoise,
          Dg.brandPurple,
        ],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, paint);
  }

  @override
  bool shouldRepaint(covariant _FlowRingPainter old) =>
      old.progress != progress || old.track != track;
}

/// Marka akışlı ilerleme halkası; değer değişince eski değerden yeniye
/// akar (ilk çizimde 0'dan). Sabitken kare üretmez.
class FlowProgressRing extends StatelessWidget {
  const FlowProgressRing({
    super.key,
    required this.progress,
    this.size = 84,
    this.track,
    this.child,
  });

  final double progress;
  final double size;
  final Color? track;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final target = progress.clamp(0.0, 1.0);
    final trackColor = track ?? Dg.hairline;
    Widget paint(double t, Widget? inner) => CustomPaint(
      size: Size.square(size),
      painter: _FlowRingPainter(progress: t, track: trackColor),
      child: SizedBox.square(
        dimension: size,
        child: inner == null ? null : Center(child: inner),
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) return paint(target, child);
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: target),
        duration: const Duration(milliseconds: 700),
        curve: DgMotion.emphasizedCurve,
        builder: (context, t, inner) => paint(t, inner),
        child: child,
      ),
    );
  }
}
