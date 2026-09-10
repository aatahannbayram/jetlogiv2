import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../session.dart';
import '../secure.dart';
import '../brand.dart';
import '../motion.dart';
import '../theme.dart';
import '../widgets.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(sessionProvider).bootstrap());
    });
    _timer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);
    final canGo = _ready && s.configReady && !s.forceUpdate;
    final open = s.openCount;
    final next = s.nextStop;
    final onHero = Dg.onHero;
    final muted = Dg.onHeroMuted;
    return Scaffold(
      backgroundColor: Dg.dark ? Dg.night : Dg.ground,
      body: Stack(
        children: [
          if (Dg.dark)
            Align(
              alignment: Alignment.topCenter,
              child: AspectRatio(
                aspectRatio: 1290 / 1596,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/jetlogi_splash_bg.png',
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            Dg.night,
                          ],
                          stops: [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            const Positioned.fill(
              child: HeroBackground(child: SizedBox.expand()),
            ),
          NightGrain(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Appear(
                          child: DijigooWordmark(height: 28, onDark: Dg.dark),
                        ),
                        const Spacer(),
                        if (s.panelLoggedIn)
                          Text(
                            l.panelSessionOn,
                            style: TextStyle(
                              color: muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (s.demo) ...[
                          const SizedBox(width: 8),
                          DemoPill(
                            onLongPress: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l.demoCodesHint)),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                    const Spacer(),
                    Container(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                          decoration: BoxDecoration(
                            color: Dg.heroGlass,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: onHero.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  InitialsAvatar(
                                    name: s.courier.fullName,
                                    photoUrl: s.courier.photoUrl,
                                    size: 52,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s.courier.fullName,
                                          style: TextStyle(
                                            color: onHero,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 17,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${s.courier.district} / ${s.courier.city}',
                                          style: TextStyle(
                                            color: muted,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: onHero.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Dg.violetBg,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        LucideIcons.mapPin,
                                        size: 18,
                                        color: Dg.dark
                                            ? const Color(0xFFE3D9F2)
                                            : Dg.violet,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.demo
                                                ? l.todayStopsGuney
                                                : l.todayFieldHint,
                                            style: TextStyle(
                                              color: onHero,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              height: 1.3,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            next == null
                                                ? l.openStops(open)
                                                : l.openInQueue(
                                                    open,
                                                    next.recipient,
                                                  ),
                                            style: TextStyle(
                                              color: muted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (next != null)
                                      InitialsAvatar(
                                        name: next.recipient,
                                        photoUrl: next.personPhoto,
                                        size: 32,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              DgButton(
                                label: s.forceUpdate
                                    ? l.updateApp
                                    : l.startShiftCta,
                                icon: LucideIcons.play,
                                busy: !canGo,
                                onPressed: canGo
                                    ? () =>
                                          ref.read(sessionProvider).enterField()
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              DgButton(
                                label: l.showActivation,
                                icon: LucideIcons.key,
                                tone: Dg.dark
                                    ? DgButtonTone.onDark
                                    : DgButtonTone.secondary,
                                onPressed: () =>
                                    ref.read(sessionProvider).finishSplash(),
                              ),
                              if (demoFieldAllowed()) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  key: const Key('open-demo'),
                                  onPressed: () =>
                                      ref.read(sessionProvider).skipToDemo(),
                                  child: Text(
                                    l.openDemo,
                                    style: TextStyle(color: muted),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                        .animate(delay: 160.ms)
                        .fadeIn(duration: 420.ms, curve: Curves.easeOutCubic)
                        .slideY(
                          begin: 0.08,
                          end: 0,
                          duration: 420.ms,
                          curve: Curves.easeOutCubic,
                        ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
