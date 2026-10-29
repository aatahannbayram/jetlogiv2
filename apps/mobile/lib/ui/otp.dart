import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../motion.dart';
import '../theme.dart';

/// Doğrulama kodu kutuları. Dolan kutu hafifçe "pop" eder; sıradaki kutu
/// vurgulu çerçeveyle bekler. [error] değişince kutular sarsılır.
class DgOtpBoxes extends StatelessWidget {
  const DgOtpBoxes({
    super.key,
    required this.value,
    this.length = 6,
    this.error,
  });

  final String value;
  final int length;

  /// Hata anahtarı: her yeni hata kutuları bir kez sarsar.
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    Widget box(int i) {
      final filled = i < value.length;
      final active = i == value.length;
      final char = filled ? value[i] : '';
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AspectRatio(
            aspectRatio: 0.82,
            child: AnimatedContainer(
              duration: DgMotion.quick,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Dg.surface1,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: error != null
                      ? Dg.bad
                      : active
                      ? Dg.brandPurple
                      : filled
                      ? Dg.action.withValues(alpha: 0.6)
                      : Dg.hairline,
                  width: active ? 2 : 1.2,
                ),
              ),
              child: AnimatedSwitcher(
                duration: reduce ? Duration.zero : DgMotion.quick,
                transitionBuilder: (child, a) => ScaleTransition(
                  scale: Tween(begin: 0.6, end: 1.0).animate(
                    CurvedAnimation(parent: a, curve: DgMotion.springy),
                  ),
                  child: FadeTransition(opacity: a, child: child),
                ),
                child: Text(
                  char,
                  key: ValueKey('$i$char'),
                  style: Dg.stat(size: 24, weight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final row = Row(children: [for (var i = 0; i < length; i++) box(i)]);
    return Semantics(
      label: '${value.length} / $length',
      child: error == null ? row : ShakeError(trigger: error, child: row),
    );
  }
}

/// Ekran tuş takımı (sistem klavyesi açılmaz). Basınca tuş küçülür,
/// hafif titreşim verir.
class DgKeypad extends StatelessWidget {
  const DgKeypad({super.key, required this.onDigit, required this.onBackspace});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {VoidCallback? onTap, IconData? icon}) {
      final face = Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: onTap == null ? Colors.transparent : Dg.surface1,
          borderRadius: BorderRadius.circular(14),
        ),
        child: icon != null
            ? Icon(icon, size: 22, color: Dg.text1)
            : Text(label, style: Dg.stat(size: 24, weight: FontWeight.w600)),
      );
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: onTap == null
              ? face
              : Semantics(
                  button: true,
                  label: icon != null ? 'Sil' : label,
                  excludeSemantics: true,
                  child: Pressable(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onTap();
                    },
                    child: face,
                  ),
                ),
        ),
      );
    }

    Widget digit(String d) => key(d, onTap: () => onDigit(d));
    return Column(
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(children: [for (final d in row) digit(d)]),
        Row(
          children: [
            key(''),
            digit('0'),
            key('', onTap: onBackspace, icon: LucideIcons.delete),
          ],
        ),
      ],
    );
  }
}
