import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'l10n.dart';
import 'theme.dart';
import 'widgets.dart';

/// İlk girişte gösterilen kısa tanıtımın bir adımı.
class IntroStep {
  const IntroStep({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

List<IntroStep> courierIntroSteps(L10n l) => [
  IntroStep(
    icon: LucideIcons.mapPin,
    title: l.introCourier1Title,
    body: l.introCourier1Body,
  ),
  IntroStep(
    icon: LucideIcons.packageCheck,
    title: l.introCourier2Title,
    body: l.introCourier2Body,
  ),
  IntroStep(
    icon: LucideIcons.qrCode,
    title: l.introCourier3Title,
    body: l.introCourier3Body,
  ),
  IntroStep(
    icon: LucideIcons.cloudUpload,
    title: l.introCourier4Title,
    body: l.introCourier4Body,
  ),
];

List<IntroStep> branchIntroSteps(L10n l) => [
  IntroStep(
    icon: LucideIcons.house,
    title: l.introBranch1Title,
    body: l.introBranch1Body,
  ),
  IntroStep(
    icon: LucideIcons.packageCheck,
    title: l.introBranch2Title,
    body: l.introBranch2Body,
  ),
  IntroStep(
    icon: LucideIcons.users,
    title: l.introBranch3Title,
    body: l.introBranch3Body,
  ),
  IntroStep(
    icon: LucideIcons.layoutGrid,
    title: l.introBranch4Title,
    body: l.introBranch4Body,
  ),
];

/// [show] doğruyken tanıtımı bir kez açar; kapanınca [onDone] çağrılır.
/// Ekranın içine görünmez bir parça olarak konur.
class IntroTourTrigger extends StatefulWidget {
  const IntroTourTrigger({
    super.key,
    required this.show,
    required this.steps,
    required this.onDone,
  });

  final bool show;
  final List<IntroStep> steps;
  final VoidCallback onDone;

  @override
  State<IntroTourTrigger> createState() => _IntroTourTriggerState();
}

class _IntroTourTriggerState extends State<IntroTourTrigger> {
  bool _opened = false;

  void _maybeOpen() {
    if (!widget.show || _opened) return;
    _opened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _IntroSheet(steps: widget.steps),
      );
      widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) {
    _maybeOpen();
    return const SizedBox.shrink();
  }
}

class _IntroSheet extends StatefulWidget {
  const _IntroSheet({required this.steps});

  final List<IntroStep> steps;

  @override
  State<_IntroSheet> createState() => _IntroSheetState();
}

class _IntroSheetState extends State<_IntroSheet> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final step = widget.steps[_index];
    final last = _index == widget.steps.length - 1;
    final still = MediaQuery.disableAnimationsOf(context);
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        decoration: BoxDecoration(
          color: Dg.surface,
          borderRadius: BorderRadius.circular(Dg.radiusPill),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Adım göstergesi: geçerli adım uzun çizgi.
                for (var i = 0; i < widget.steps.length; i++)
                  AnimatedContainer(
                    duration: Duration(milliseconds: still ? 0 : 220),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.only(right: 6),
                    width: i == _index ? 22 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _index ? Dg.action : Dg.elev,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                const Spacer(),
                if (!last)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      l.introSkip,
                      style: Dg.ui(size: 14, color: Dg.ink3),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: Duration(milliseconds: still ? 0 : 240),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0.06, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topLeft,
                children: [...previous, ?current],
              ),
              child: Column(
                key: ValueKey(_index),
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(child: DgIllustration(icon: step.icon, size: 148)),
                  const SizedBox(height: 16),
                  Text(
                    step.title,
                    style: Dg.ui(
                      size: 22,
                      weight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    step.body,
                    style: Dg.ui(size: 16, color: Dg.ink2, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            DgButton(
              label: last ? l.introStart : l.introNext,
              trailing: last ? null : LucideIcons.arrowRight,
              onPressed: () {
                if (last) {
                  Navigator.of(context).pop();
                } else {
                  setState(() => _index++);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
