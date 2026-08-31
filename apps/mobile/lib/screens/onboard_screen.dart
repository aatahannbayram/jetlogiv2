import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

class OnboardScreen extends ConsumerStatefulWidget {
  const OnboardScreen({super.key});

  @override
  ConsumerState<OnboardScreen> createState() => _OnboardScreenState();
}

class _OnboardScreenState extends ConsumerState<OnboardScreen> {
  final _pages = PageController();
  int _index = 0;

  static const _slides = [
    (
      kicker: 'Liste',
      title: 'Üstteki durak senin.',
      body: 'Numara, adres, saat kartta.',
    ),
    (
      kicker: 'Yol',
      title: 'Durağa bas, harita açılsın.',
      body: 'Sıra Güney. Mola üstte. Yol tarifi telefonda açılır.',
    ),
    (
      kicker: 'Kapanış',
      title: 'Foto ve kod yoksa bitmez.',
      body: 'Kim aldı, kapı, kod. Sözleşme panele kalır.',
    ),
  ];

  void _next() {
    if (_index >= _slides.length - 1) {
      ref.read(sessionProvider).finishOnboard();
      return;
    }
    _pages.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _slides.length - 1;
    return Scaffold(
      backgroundColor: Dg.ground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Image(
                      image: AssetImage('assets/images/jetlogi_logo_color.png'),
                      height: 30,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => ref.read(sessionProvider).finishOnboard(),
                    child: const Text('Atla'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Center(child: _Art(index: i)),
                        ),
                        const SizedBox(height: 20),
                        Column(
                              key: ValueKey(i),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.kicker,
                                  style: Dg.kicker(color: Dg.ink3),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  s.title,
                                  style: Dg.serif(
                                    size: 34,
                                    weight: FontWeight.w700,
                                    height: 1.08,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  s.body,
                                  style: Dg.ui(
                                    size: 16,
                                    color: Dg.ink2,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            )
                            .animate()
                            .fadeIn(
                              duration: 260.ms,
                              curve: Curves.easeOutCubic,
                            )
                            .slideY(
                              begin: 0.06,
                              end: 0,
                              duration: 260.ms,
                              curve: Curves.easeOutCubic,
                            ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < _slides.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: i == _index ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _index ? Dg.ink : Dg.rule,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _next,
                    child: Text(last ? 'Tamam' : 'Devam'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Art extends StatelessWidget {
  const _Art({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return switch (index) {
      // LayoutBuilder so the map strip shrinks on short screens (e.g.
      // iPhone SE) instead of overflowing the Expanded slot below it —
      // 252 is the natural height on everything else, 130 is the info
      // block beneath it (row + name + address + time, with its padding).
      0 => LayoutBuilder(
        builder: (context, constraints) {
          final mapHeight = constraints.hasBoundedHeight
              ? (constraints.maxHeight - 130).clamp(160.0, 252.0)
              : 252.0;
          return DgCard(
            lime: true,
            hero: true,
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MapStrip(eta: 6, height: mapHeight),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Mono('DGO-8841', color: Colors.white),
                          Spacer(),
                          StatusChip(label: 'Sırada', tone: 'lime'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Ahmet Yılmaz',
                        style: Dg.serif(size: 26, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Kayalık Mah. No:14, Güney',
                        style: TextStyle(
                          fontFamily: Dg.sans,
                          fontSize: 15,
                          color: Color(0xFFE3D9F2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Teslimat  ·  14:30–15:00',
                        style: TextStyle(
                          fontFamily: Dg.sans,
                          fontSize: 13,
                          color: Color(0xFFE3D9F2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      1 => MapStrip(
        height: 280,
        clipTopOnly: false,
        points: const [
          LatLng(38.1512, 29.0614),
          LatLng(38.1481, 29.0558),
          LatLng(38.1554, 29.0692),
          LatLng(38.1460, 29.0488),
        ],
        label: '4 durak',
      ),
      _ => DgCard(
        hero: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Dg.purple,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Bu teslimde kod var.',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _line(LucideIcons.camera, 'Kapı fotoğrafı'),
            _line(LucideIcons.pin, 'Alıcı kodu'),
            _line(LucideIcons.idCard, 'Sözleşme panelde'),
          ],
        ),
      ),
    };
  }

  static Widget _line(IconData icon, String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Dg.ink),
          const SizedBox(width: 10),
          Text(
            t,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
