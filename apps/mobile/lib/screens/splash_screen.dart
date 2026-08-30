import 'dart:async';

import 'package:flutter/material.dart';
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
      body: NightGrain(
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
                          const SnackBar(content: Text('Giriş 123456  ·  Teslim 482913')),
                        );
                      },
                    ),
                  ],
                ),
                const Spacer(),
                Image.asset('assets/images/dijigoo_logo.png', height: 48),
                const SizedBox(height: 10),
                Text(
                  'Kurye',
                  style: Dg.serif(
                    size: 72,
                    weight: FontWeight.w600,
                    color: const Color(0xFFF3F0E7),
                    height: 0.9,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Bugünün durakları Güney’de.',
                  style: Dg.ui(size: 17, color: const Color(0xFFB7C4C1), height: 1.4),
                ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Dg.purple,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: canGo ? () => ref.read(sessionProvider).skipToDemo() : null,
                  child: Text(s.forceUpdate ? 'Uygulamayı güncelle' : 'Vardiyaya başla'),
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
    );
  }
}
