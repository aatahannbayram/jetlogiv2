import 'dart:async';

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
          const Positioned.fill(
            child: HeroBackground(child: SizedBox.expand()),
          ),
          // Marka dalgası: önceden üretilmiş tek görsel, belirip hafifçe
          // yükselir (yalnız opaklık + transform).
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: AspectRatio(
              aspectRatio: 1440 / 900,
              child: BrandWave(opacity: Dg.dark ? 1 : 0.55)
                  .animate()
                  .fadeIn(duration: DgMotion.emphasized)
                  .slideY(
                    begin: 0.06,
                    end: 0,
                    duration: 900.ms,
                    curve: DgMotion.emphasizedCurve,
                  ),
            ),
          ),
          NightGrain(
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Spacer(),
                                if (s.panelLoggedIn)
                                  Text(
                                    l.panelSessionOn,
                                    style: TextStyle(
                                      color: muted,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                if (s.demo) ...[
                                  const SizedBox(width: 8),
                                  DemoPill(
                                    onLongPress: () {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            SnackBar(
                                              content: Text(l.demoCodesHint),
                                            ),
                                          );
                                    },
                                  ),
                                ],
                              ],
                            ),
                            const Spacer(),
                            // İmza an 1: logo bütün olarak belirir (kılavuz:
                            // sonsuzluk yeniden çizilmez/döndürülmez).
                            Appear(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DijigooWordmark(height: 52, onDark: Dg.dark),
                                  const SizedBox(height: 14),
                                  Text(
                                    l.brandTagline,
                                    style: Dg.ui(
                                      size: 20,
                                      weight: FontWeight.w500,
                                      color: onHero,
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    width: 56,
                                    height: 3,
                                    decoration: const BoxDecoration(
                                      gradient: Dg.brandFlow,
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(2),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),
                            Container(
                                  padding: const EdgeInsets.fromLTRB(
                                    18,
                                    18,
                                    18,
                                    16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Dg.heroGlass,
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                                    fontSize: 14,
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
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 36,
                                              height: 36,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: Dg.violetBg,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Icon(
                                                LucideIcons.mapPin,
                                                size: 18,
                                                color: Dg.violet,
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
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
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
                                                      fontSize: 14,
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
                                            ? () => ref
                                                  .read(sessionProvider)
                                                  .enterField()
                                            : null,
                                      ),
                                      const SizedBox(height: 8),
                                      DgButton(
                                        label: l.showActivation,
                                        icon: LucideIcons.key,
                                        tone: Dg.dark
                                            ? DgButtonTone.onDark
                                            : DgButtonTone.secondary,
                                        onPressed: () => ref
                                            .read(sessionProvider)
                                            .finishSplash(),
                                      ),
                                      if (demoFieldAllowed()) ...[
                                        const SizedBox(height: 8),
                                        TextButton(
                                          key: const Key('open-demo'),
                                          onPressed: () => ref
                                              .read(sessionProvider)
                                              .skipToDemo(),
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
                                .fadeIn(
                                  duration: DgMotion.emphasized,
                                  curve: DgMotion.enter,
                                )
                                .slideY(
                                  begin: 0.08,
                                  end: 0,
                                  duration: DgMotion.emphasized,
                                  curve: DgMotion.emphasizedCurve,
                                ),
                          ],
                        ),
                      ),
                    ),
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
