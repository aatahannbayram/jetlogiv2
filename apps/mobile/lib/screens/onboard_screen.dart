import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n.dart';
import '../session.dart';
import '../brand.dart';
import '../motion.dart';
import '../onboard_art.dart';
import '../theme.dart';
import '../widgets.dart';

class OnboardScreen extends ConsumerStatefulWidget {
  const OnboardScreen({super.key, this.forBranch = false});

  final bool forBranch;

  @override
  ConsumerState<OnboardScreen> createState() => _OnboardScreenState();
}

class _OnboardScreenState extends ConsumerState<OnboardScreen> {
  final _pages = PageController();
  int _index = 0;

  List<(String, String, String, OnboardScene)> _slides(L10n l) {
    if (widget.forBranch) {
      return [
        (
          l.subeOnboard1Kicker,
          l.subeOnboard1Title,
          l.subeOnboard1Body,
          OnboardScene.branchSummary,
        ),
        (
          l.subeOnboard2Kicker,
          l.subeOnboard2Title,
          l.subeOnboard2Body,
          OnboardScene.branchAssign,
        ),
        (
          l.subeOnboard3Kicker,
          l.subeOnboard3Title,
          l.subeOnboard3Body,
          OnboardScene.branchStock,
        ),
      ];
    }
    return [
      (l.onboard1Kicker, l.onboard1Title, l.onboard1Body, OnboardScene.stops),
      (l.onboard2Kicker, l.onboard2Title, l.onboard2Body, OnboardScene.route),
      (l.onboard4Kicker, l.onboard4Title, l.onboard4Body, OnboardScene.scan),
      (l.onboard3Kicker, l.onboard3Title, l.onboard3Body, OnboardScene.proof),
      (l.onboard5Kicker, l.onboard5Title, l.onboard5Body, OnboardScene.shift),
    ];
  }

  void _next() {
    final last = _index >= _slides(context.l10n).length - 1;
    if (last) {
      if (widget.forBranch) {
        ref.read(sessionProvider).finishSubeOnboard();
      } else {
        ref.read(sessionProvider).finishOnboard();
      }
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
    final l = context.l10n;
    final slides = _slides(l);
    final last = _index == slides.length - 1;
    return Scaffold(
      backgroundColor: Dg.ground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Appear(
                      child: DijigooWordmark(height: 26, onDark: Dg.dark),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      if (widget.forBranch) {
                        ref.read(sessionProvider).finishSubeOnboard();
                      } else {
                        ref.read(sessionProvider).finishOnboard();
                      }
                    },
                    child: Text(l.skip),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final s = slides[i];
                  return LayoutBuilder(
                    builder: (context, box) => SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                      child: ConstrainedBox(
                        // Kısa metinde altta boşluk kalmasın: sayfa ortalanır.
                        constraints: BoxConstraints(
                          minHeight: box.maxHeight - 16,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            OnboardArt(
                              scene: s.$4,
                              height: (box.maxHeight * 0.52).clamp(
                                200.0,
                                320.0,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Column(
                                  key: ValueKey(i),
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.$1,
                                      style: Dg.kicker(color: Dg.plum),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      s.$2,
                                      style: Dg.serif(
                                        size: 30,
                                        weight: FontWeight.w700,
                                        height: 1.12,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      s.$3,
                                      style: Dg.ui(
                                        size: 16,
                                        color: Dg.ink2,
                                        height: 1.45,
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
                      ),
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
                      for (var i = 0; i < slides.length; i++) ...[
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
                  DgButton(
                    label: last ? l.done : l.continueLabel,
                    trailing: last ? LucideIcons.check : LucideIcons.arrowRight,
                    onPressed: _next,
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
