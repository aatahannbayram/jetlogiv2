import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../motion.dart';
import '../theme.dart';

/// Marka ana düğmesi: mor → mavi → turkuaz gradyan, beyaz yazı, basınca
/// küçülür. Meşgulken döner gösterge, devre dışıyken soluk.
class DgGradientButton extends StatelessWidget {
  const DgGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailing,
    this.busy = false,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailing;
  final bool busy;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final body = AnimatedOpacity(
      duration: DgMotion.quick,
      opacity: onPressed == null ? 0.5 : 1,
      child: Container(
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          gradient: Dg.brandCta,
          borderRadius: BorderRadius.circular(16),
        ),
        child: busy
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: Colors.white),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Dg.ui(
                        size: 16,
                        weight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 10),
                    Icon(trailing, size: 20, color: Colors.white),
                  ],
                ],
              ),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: enabled ? Pressable(onTap: onPressed!, child: body) : body,
    );
  }
}

/// Hap sekmeler. Az sekmede seçili zemin yaylanarak kayar; çok sekmede
/// yatay kaydırılan haplara döner.
class DgPillTabs extends StatelessWidget {
  const DgPillTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.counts,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  /// İsteğe bağlı adetler (etiketin yanında).
  final List<int?>? counts;

  String _text(int i) {
    final c = counts != null && i < counts!.length ? counts![i] : null;
    return c == null ? labels[i] : '${labels[i]} ($c)';
  }

  /// Eşit genişlikli bölmelere her etiket sığıyor mu (yazı ölçeği dahil).
  bool _fits(BuildContext context, double width) {
    final segment = (width - 8) / labels.length - 12;
    final scaler = MediaQuery.textScalerOf(context);
    final style = Dg.ui(size: 14, weight: FontWeight.w600);
    for (var i = 0; i < labels.length; i++) {
      final painter = TextPainter(
        text: TextSpan(text: _text(i), style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final w = painter.width;
      painter.dispose();
      if (w > segment) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (labels.length > 4) return _scrolling(context);
    // Etiket bölmeye sığmazsa kesilmesin: kayan haplara geçilir.
    return LayoutBuilder(
      builder: (context, outer) => _fits(context, outer.maxWidth)
          ? _segmented(context)
          : _scrolling(context),
    );
  }

  Widget _segmented(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Dg.surface2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / labels.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: reduce
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: DgMotion.emphasizedCurve,
                left: w * index,
                top: 0,
                bottom: 0,
                width: w,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Dg.action,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: Semantics(
                        selected: i == index,
                        button: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (i == index) return;
                            HapticFeedback.selectionClick();
                            onChanged(i);
                          },
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: DgMotion.quick,
                              style: Dg.ui(
                                size: 14,
                                weight: FontWeight.w600,
                                color: i == index ? Colors.white : Dg.text2,
                              ),
                              child: Text(
                                _text(i),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _scrolling(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final selected = i == index;
          return Semantics(
            selected: selected,
            button: true,
            child: GestureDetector(
              onTap: () {
                if (selected) return;
                HapticFeedback.selectionClick();
                onChanged(i);
              },
              child: AnimatedContainer(
                duration: DgMotion.quick,
                curve: DgMotion.enter,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? Dg.action : Dg.surface2,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _text(i),
                  style: Dg.ui(
                    size: 14,
                    weight: FontWeight.w600,
                    color: selected ? Colors.white : Dg.text2,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Arama alanı: dolgulu, büyüteç ikonlu; yazı varken temizle düğmesi.
class DgSearchField extends StatefulWidget {
  const DgSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  @override
  State<DgSearchField> createState() => _DgSearchFieldState();
}

class _DgSearchFieldState extends State<DgSearchField> {
  late final TextEditingController _c =
      widget.controller ?? TextEditingController();

  @override
  void dispose() {
    if (widget.controller == null) _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      onChanged: (v) {
        setState(() {});
        widget.onChanged(v);
      },
      textInputAction: TextInputAction.search,
      style: Dg.ui(size: 16, color: Dg.text1),
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.hint,
        filled: true,
        fillColor: Dg.surface1,
        prefixIcon: Icon(LucideIcons.search, size: 18, color: Dg.text3),
        suffixIcon: _c.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(LucideIcons.x, size: 18, color: Dg.text3),
                onPressed: () {
                  _c.clear();
                  setState(() {});
                  widget.onChanged('');
                },
              ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Dg.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Dg.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Dg.highlight, width: 1.4),
        ),
      ),
    );
  }
}

/// Süzgeç çipi: "İlçe ▾". Değer seçiliyse dolu, etiket yerine değeri yazar.
class DgFilterChip extends StatelessWidget {
  const DgFilterChip({
    super.key,
    required this.label,
    required this.onTap,
    this.value,
    this.icon,
  });

  final String label;
  final String? value;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final on = value != null;
    return Semantics(
      button: true,
      label: on ? '$label: $value' : label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: DgMotion.quick,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: on ? Dg.action.withValues(alpha: 0.18) : Dg.surface1,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: on ? Dg.action.withValues(alpha: 0.6) : Dg.hairline,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: on ? Dg.highlight : Dg.text3),
                const SizedBox(width: 6),
              ],
              // Yatay listede de (sınırsız genişlik) çalışsın diye Flexible
              // yerine üst sınır: uzun değer üç noktayla kısalır.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(
                  value ?? label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Dg.ui(
                    size: 14,
                    weight: FontWeight.w600,
                    color: on ? Dg.highlight : Dg.text2,
                  ).copyWith(fontSize: 13),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                LucideIcons.chevronDown,
                size: 14,
                color: on ? Dg.highlight : Dg.text3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Basit seçim sayfası: başlık + seçenekler + "Tümü" (null döner).
Future<({bool picked, T? value})> showDgPicker<T>(
  BuildContext context, {
  required String title,
  required String allLabel,
  required List<(T, String)> options,
  T? selected,
}) async {
  final result = await showModalBottomSheet<({T? value})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Dg.surface1,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Text(title, style: Dg.typeH2()),
            ),
            _PickRow(
              label: allLabel,
              selected: selected == null,
              onTap: () => Navigator.pop(ctx, (value: null)),
            ),
            for (final o in options)
              _PickRow(
                label: o.$2,
                selected: o.$1 == selected,
                onTap: () => Navigator.pop(ctx, (value: o.$1)),
              ),
          ],
        ),
      ),
    ),
  );
  if (result == null) return (picked: false, value: selected);
  return (picked: true, value: result.value);
}

class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: false,
      minTileHeight: Dg.rowMin,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(label, style: Dg.typeBody()),
      trailing: selected
          ? Icon(LucideIcons.check, size: 18, color: Dg.highlight)
          : null,
      onTap: onTap,
    );
  }
}

/// Seçim kutusu: işaretlenince dolup tik belirir.
class DgSelectBox extends StatelessWidget {
  const DgSelectBox({super.key, required this.selected, this.size = 22});

  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: DgMotion.quick,
      curve: DgMotion.enter,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: selected ? Dg.action : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: selected ? Dg.action : Dg.stroke, width: 1.6),
      ),
      child: AnimatedScale(
        duration: DgMotion.quick,
        curve: DgMotion.springy,
        scale: selected ? 1 : 0,
        child: Icon(LucideIcons.check, size: size * 0.7, color: Colors.white),
      ),
    );
  }
}

/// Toplu işlem çubuğu: seçim varken aşağıdan kayarak gelir, adet
/// değişince sayı çaprazlanır.
class DgBulkBar extends StatelessWidget {
  const DgBulkBar({
    super.key,
    required this.count,
    required this.label,
    required this.onPressed,
    this.icon = LucideIcons.layers,
  });

  final int count;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final visible = count > 0;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        duration: reduce ? Duration.zero : DgMotion.standard,
        curve: visible ? DgMotion.emphasizedCurve : DgMotion.exit,
        offset: visible ? Offset.zero : const Offset(0, 1.4),
        child: AnimatedOpacity(
          duration: reduce ? Duration.zero : DgMotion.quick,
          opacity: visible ? 1 : 0,
          child: DgGradientButton(
            label: '$label ($count)',
            icon: icon,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}
