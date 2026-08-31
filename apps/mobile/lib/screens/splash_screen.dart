import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session.dart';
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
    final s = ref.watch(sessionProvider);
    final canGo = _ready && s.configReady && !s.forceUpdate;
    return Scaffold(
      backgroundColor: Dg.night,
      body: Stack(
        children: [
          // Shown at its own aspect ratio, anchored to the top, instead of
          // full-bleed BoxFit.cover — on tall/narrow phones cover was
          // cropping ~40-60% off each side (this art is a wide 1290×1596
          // render), slicing straight through the embossed logo. This way
          // the whole piece is always visible, at native resolution (no
          // upscaling blur), and just fades into the solid Dg.night below
          // it rather than being forced to fill the full screen.
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
                        stops: [0.0, 0.62, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          NightGrain(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Spacer(),
                        DemoPill(
                          onLongPress: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Giriş 123456  ·  Teslim 482913'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                          'Bugünün durakları Güney’de.',
                          style: Dg.ui(
                            size: 17,
                            color: const Color(0xFFB7C4C1),
                            height: 1.4,
                          ),
                        )
                        .animate(delay: 160.ms)
                        .fadeIn(duration: 420.ms, curve: Curves.easeOutCubic),
                    const Spacer(),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Dg.purple,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: canGo
                          ? () => ref.read(sessionProvider).skipToDemo()
                          : null,
                      child: canGo
                          ? Text(
                              s.forceUpdate
                                  ? 'Uygulamayı güncelle'
                                  : 'Vardiyaya başla',
                            )
                          : const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF3F0E7),
                        side: const BorderSide(color: Color(0xFF3A4744)),
                        backgroundColor: Colors.transparent,
                      ),
                      onPressed: () => ref.read(sessionProvider).finishSplash(),
                      child: const Text('Aktivasyonu göster'),
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
