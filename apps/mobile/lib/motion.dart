import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'theme.dart';

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
        transitionDuration: const Duration(milliseconds: 260),
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
        .animate(delay: (36 * index.clamp(0, 8)).ms)
        .fadeIn(duration: 280.ms, curve: Curves.easeOutCubic)
        .slideY(
          begin: 0.06,
          end: 0,
          duration: 420.ms,
          curve: Curves.easeOutCubic,
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
        .fadeIn(duration: 280.ms, curve: Curves.easeOutCubic)
        .slideY(
          begin: slide,
          end: 0,
          duration: 420.ms,
          curve: Curves.easeOutCubic,
        )
        .scale(
          begin: const Offset(0.98, 0.98),
          end: const Offset(1, 1),
          duration: 420.ms,
          curve: Curves.easeOutCubic,
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
    return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Dg.elev,
            borderRadius: BorderRadius.circular(radius),
          ),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fadeIn(begin: 0.4, duration: 700.ms, curve: Curves.easeInOut);
  }
}

/// Scale-down-on-press feedback for tappable elements that currently rely
/// only on the default `InkWell` ripple (or nothing at all) — e.g.
/// SquareAction, menu tiles. Deliberately not used on [DgCard]'s own onTap
/// path, which already has InkWell feedback; stacking both would look busy.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

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
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: Duration(milliseconds: _down ? 80 : 220),
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
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
    final child = Icon(icon, size: size, color: color);
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

/// Shakes [child] whenever [trigger] changes — e.g. key it on an error
/// message string so a fresh error re-shakes even if the text repeats.
class ShakeError extends StatelessWidget {
  const ShakeError({super.key, required this.child, required this.trigger});

  final Widget child;
  final Object? trigger;

  @override
  Widget build(BuildContext context) {
    return child
        .animate(key: ValueKey(trigger))
        .shake(hz: 4, duration: 320.ms, curve: Curves.easeOut);
  }
}
