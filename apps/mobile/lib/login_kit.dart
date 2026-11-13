import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pinput/pinput.dart';

import 'theme.dart';

/// Giriş ekranının görsel parçaları. Kaynak: Dijigoo Panel/App yazılım
/// teslimi v1.1 (`referans/app-is-ortagi.png`, `app-kurye.png`).
///
/// Giriş ekranı onaylı tasarım gereği temadan bağımsız koyu çalışır; bu
/// yüzden renkler [Dg] tema getter'larından değil sabitlerden okunur.
class LoginInk {
  LoginInk._();

  static const ground = Dg.navy;
  static const text = Color(0xFFFFFFFF);
  static const muted = Color(0xFFB9C0D9);
  static const faint = Color(0x24FFFFFF);
  static const field = Color(0x0DFFFFFF);
  static const fieldLine = Color(0x26FFFFFF);
  static const lavender = Color(0xFFCDBEFF);
  static const error = Color(0xFFFF8E9E);
  static const turkuaz = Dg.dgTurkuaz;

  static const sloganFlow = LinearGradient(
    colors: [Dg.dgTurkuaz, Dg.dgMavi, Dg.dgMorMavi, Dg.dgMor],
  );

  static TextStyle style({
    double size = 16,
    FontWeight weight = FontWeight.w500,
    Color color = text,
    double height = 1.25,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: Dg.sans,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontVariations: [FontVariation('wght', weight.value.toDouble())],
    );
  }
}

/// Teslimdeki SVG ikonu, istenirse tek renge boyanır.
class LoginIcon extends StatelessWidget {
  const LoginIcon(this.name, {super.key, this.height = 20, this.color});

  final String name;
  final double height;
  final Color? color;

  /// Renkli ve parlamalı ikonların onaylı görünümü PNG'dedir (teslim notu).
  static const _raster = {'sms', 'qr', 'biyometrik-tarama'};

  @override
  Widget build(BuildContext context) {
    if (_raster.contains(name)) {
      return Image.asset(
        'assets/login/$name.png',
        height: height,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
      );
    }
    return SvgPicture.asset(
      'assets/login/$name.svg',
      height: height,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color!, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
  }
}

/// Lacivert zemin, üstte silik nokta ızgarası ve logo arkasında ışık,
/// altta teslimdeki ışık şeridi (`dekor/app-*-isik-alt.png`).
class LoginBackdrop extends StatelessWidget {
  const LoginBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: LoginInk.ground,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF060D33), Color(0xFF01061F)],
                stops: [0, 0.7],
              ),
            ),
          ),
          const RepaintBoundary(child: CustomPaint(painter: _DotGrid())),
          const Align(
            alignment: Alignment(0, -0.78),
            child: SizedBox(
              width: 420,
              height: 320,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Color(0x2E0E97FD), Color(0x000E97FD)],
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: IgnorePointer(
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (r) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
                  stops: [0, 0.45],
                ).createShader(r),
                child: Image.asset(
                  'assets/login/isik-alt.png',
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.bottomCenter,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _DotGrid extends CustomPainter {
  const _DotGrid();

  @override
  void paint(Canvas canvas, Size size) {
    const step = 18.0;
    final limit = size.height * 0.45;
    final paint = Paint();
    for (double y = step / 2; y < limit; y += step) {
      // Aşağı indikçe söner.
      final a = 0.07 * (1 - y / limit);
      paint.color = Colors.white.withValues(alpha: a);
      for (double x = step / 2; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 0.7, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGrid oldDelegate) => false;
}

/// D ikonu + slogan. Slogan teslimdeki gibi: ilk iki kelime beyaz,
/// "lojistik gücü" turkuazdan mora geçer, sonda nokta yok.
class LoginBrand extends StatelessWidget {
  const LoginBrand({
    super.key,
    required this.lead,
    required this.accent,
    this.markHeight = 96,
  });

  final String lead;
  final String accent;
  final double markHeight;

  @override
  Widget build(BuildContext context) {
    final style = LoginInk.style(size: 23, weight: FontWeight.w600);
    return Semantics(
      label: 'Dijigoo. $lead$accent',
      container: true,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/login/d-ikonu.png',
              height: markHeight,
              filterQuality: FilterQuality.medium,
            ),
            const SizedBox(height: 14),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: lead, style: style),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: LoginInk.sloganFlow.createShader,
                        child: Text(accent, style: style),
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Köşeleri kırık cam kart: ince degrade kenar çizgisi, dışa hafif ışık,
/// sol üstte cam yansıması ve sağ üstte küçük çentikler.
class GlassFrame extends StatelessWidget {
  const GlassFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 24, 20, 18),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _GlassPainter(),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _GlassPainter extends CustomPainter {
  const _GlassPainter();

  static const _cut = 26.0;

  Path _shape(Rect r) {
    const c = _cut;
    return Path()
      ..moveTo(r.left + c, r.top)
      ..lineTo(r.right - c, r.top)
      ..lineTo(r.right, r.top + c)
      ..lineTo(r.right, r.bottom - c)
      ..lineTo(r.right - c, r.bottom)
      ..lineTo(r.left + c, r.bottom)
      ..lineTo(r.left, r.bottom - c)
      ..lineTo(r.left, r.top + c)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = _shape(rect);
    final edge = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: const [
        Color(0xFF00EAFE),
        Color(0x66A9C4FF),
        Color(0x335140FC),
        Color(0xCC9404FD),
      ],
      stops: const [0, 0.32, 0.62, 1],
    ).createShader(rect);

    // Dış ışık: aynı kenar, bulanık ve kalın.
    canvas.drawPath(
      path,
      Paint()
        ..shader = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
        ..color = const Color(0x80FFFFFF),
    );

    // Cam dolgu.
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xB3101A4A), Color(0xCC070D30), Color(0xD9050A26)],
        ).createShader(rect),
    );

    // Sol üstte cam yansıması.
    canvas.save();
    canvas.clipPath(path);
    final sheen = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.7, 0)
      ..lineTo(0, size.height * 0.42)
      ..close();
    canvas.drawPath(
      sheen,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment(-0.1, -0.35),
          colors: [Color(0x14FFFFFF), Color(0x00FFFFFF)],
        ).createShader(rect),
    );
    canvas.restore();

    // Kenar çizgisi.
    canvas.drawPath(
      path,
      Paint()
        ..shader = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );

    // Sağ üst çentikler (panel referansındaki "| | | |").
    final tick = Paint()
      ..color = const Color(0x66FFFFFF)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final x = size.width - _cut - 30 + i * 6.0;
      canvas.drawLine(Offset(x, 9), Offset(x, 15), tick);
    }
  }

  @override
  bool shouldRepaint(covariant _GlassPainter oldDelegate) => false;
}

/// İki seçenekli rol kontrolü. Seçili sekme dolgulu ve turkuaz çerçeveli,
/// geçiş kayarak olur.
class LoginRoleSwitch extends StatelessWidget {
  const LoginRoleSwitch({
    super.key,
    required this.labels,
    required this.keys,
    required this.selected,
    required this.onChanged,
    required this.semanticLabel,
  });

  final List<String> labels;
  final List<Key> keys;
  final int selected;
  final ValueChanged<int> onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      container: true,
      child: Container(
        height: 54,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: LoginInk.field,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: LoginInk.fieldLine),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              alignment: selected == 0
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2B2EF0), Color(0xFF1652F5)],
                    ),
                    border: Border.all(
                      color: LoginInk.turkuaz.withValues(alpha: 0.9),
                      width: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: LoginInk.turkuaz.withValues(alpha: 0.28),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < labels.length; i++)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: i == selected,
                      inMutuallyExclusiveGroup: true,
                      child: InkWell(
                        key: keys[i],
                        borderRadius: BorderRadius.circular(11),
                        onTap: () {
                          if (i == selected) return;
                          HapticFeedback.selectionClick();
                          onChanged(i);
                        },
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: LoginInk.style(
                              size: 17,
                              weight: FontWeight.w600,
                              color: i == selected
                                  ? LoginInk.text
                                  : LoginInk.text.withValues(alpha: 0.78),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(labels[i], maxLines: 1),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Yazısız alan yüzeyi üzerine gerçek giriş: solda ikon (ve istenirse
/// "+90" öneki), odakta turkuaz kenar.
class LoginField extends StatefulWidget {
  const LoginField({
    super.key,
    required this.controller,
    required this.icon,
    required this.hint,
    this.prefixText,
    this.keyboardType,
    this.obscure = false,
    this.trailing,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String icon;
  final String hint;
  final String? prefixText;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? trailing;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<LoginField> createState() => _LoginFieldState();
}

class _LoginFieldState extends State<LoginField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_changed);
    widget.controller.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  /// "+90" öneki yalnız alan boşken ya da numara yazılırken görünür;
  /// harf veya "@" yazılınca (e-posta) kalkar.
  bool get _looksLikePhone =>
      !RegExp(r'[^0-9\s()+-]').hasMatch(widget.controller.text);

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.only(left: 18, right: 6),
      decoration: BoxDecoration(
        color: focused ? const Color(0x14FFFFFF) : LoginInk.field,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: focused
              ? LoginInk.turkuaz.withValues(alpha: 0.75)
              : LoginInk.fieldLine,
          width: focused ? 1.3 : 1,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: LoginInk.turkuaz.withValues(alpha: 0.16),
                  blurRadius: 16,
                ),
              ]
            : const [],
      ),
      child: Row(
        children: [
          LoginIcon(widget.icon, height: 20, color: LoginInk.text),
          const SizedBox(width: 14),
          if (widget.prefixText != null &&
              _looksLikePhone &&
              MediaQuery.sizeOf(context).width >= 300) ...[
            Text(
              widget.prefixText!,
              style: LoginInk.style(size: 17, weight: FontWeight.w600),
            ),
            const SizedBox(width: 12),
            Container(width: 1, height: 22, color: const Color(0x40FFFFFF)),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              obscureText: widget.obscure,
              obscuringCharacter: '•',
              keyboardType: widget.keyboardType,
              autocorrect: false,
              enableSuggestions: !widget.obscure,
              autofillHints: widget.autofillHints,
              textInputAction: widget.textInputAction,
              onSubmitted: widget.onSubmitted,
              inputFormatters: widget.inputFormatters,
              cursorColor: LoginInk.turkuaz,
              style: LoginInk.style(size: 17),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                hintText: widget.hint,
                hintStyle: LoginInk.style(
                  size: 17,
                  weight: FontWeight.w400,
                  color: LoginInk.muted,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                constraints: const BoxConstraints(minHeight: 48),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          ?widget.trailing,
        ],
      ),
    );
  }
}

/// Şifreyi göster/gizle. Görünürken göz turkuaz yanar.
class PasswordEye extends StatelessWidget {
  const PasswordEye({
    super.key,
    required this.visible,
    required this.onTap,
    required this.label,
  });

  final bool visible;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label,
      onPressed: onTap,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        child: LoginIcon(
          'sifre-goster',
          key: ValueKey(visible),
          height: 18,
          color: visible ? LoginInk.turkuaz : LoginInk.text,
        ),
      ),
    );
  }
}

/// SMS / Biyometrik / QR kutusu.
class LoginMethodTile extends StatelessWidget {
  const LoginMethodTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.iconHeight = 30,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final double iconHeight;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            splashColor: LoginInk.turkuaz.withValues(alpha: 0.10),
            highlightColor: LoginInk.turkuaz.withValues(alpha: 0.05),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              constraints: const BoxConstraints(minHeight: 104),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x14FFFFFF), Color(0x05FFFFFF)],
                ),
                border: Border.all(
                  color: selected
                      ? LoginInk.turkuaz.withValues(alpha: 0.85)
                      : LoginInk.fieldLine,
                  width: selected ? 1.4 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: LoginInk.turkuaz.withValues(alpha: 0.22),
                          blurRadius: 18,
                        ),
                      ]
                    : const [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 32,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: LoginIcon(icon, height: iconHeight),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: LoginInk.style(size: 14, weight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kare onay kutusu + etiket.
class LoginCheck extends StatelessWidget {
  const LoginCheck({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: value,
      label: label,
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onChanged(!value),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: value ? LoginInk.turkuaz : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: value
                          ? LoginInk.turkuaz
                          : LoginInk.text.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                  child: value
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: LoginInk.ground,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    label,
                    style: LoginInk.style(size: 16, weight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ortak "Giriş yap" butonu. Degrade, kenar ışığı ve dış parlama
/// teslimdeki şeffaf yüzeyde (`bilesenler/giris-yap/yuzey.png`); dokuz
/// parçalı ölçeklenir: kaynak 525×98, dokunma alanı 497×70, kesim 28 px.
class LoginCta extends StatefulWidget {
  const LoginCta({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.height = 58,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final double height;

  @override
  State<LoginCta> createState() => _LoginCtaState();
}

class _LoginCtaState extends State<LoginCta> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final h = widget.height;
    final glow = 14 * h / 70;
    final enabled = widget.onPressed != null && !widget.busy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTapDown: enabled ? (_) => setState(() => _down = true) : null,
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: enabled
              ? () {
                  HapticFeedback.lightImpact();
                  widget.onPressed!();
                }
              : null,
          child: AnimatedScale(
            scale: _down ? 0.985 : 1,
            duration: const Duration(milliseconds: 110),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: widget.onPressed == null ? 0.5 : 1,
              child: SizedBox(
                height: h,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: -glow,
                      right: -glow,
                      top: -glow,
                      bottom: -glow,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: ExactAssetImage(
                              'assets/login/giris-yap.png',
                              scale: 70 / h,
                            ),
                            centerSlice: const Rect.fromLTRB(28, 28, 497, 70),
                            fit: BoxFit.fill,
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: widget.busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.label,
                                    style: LoginInk.style(
                                      size: h * 0.36,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: h * 0.33),
                                  SvgPicture.asset(
                                    'assets/login/ok.svg',
                                    height: h * 26 / 70,
                                    excludeFromSemantics: true,
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "— 🔒 Güvenli giriş —" alt bilgisi.
class LoginSecureFooter extends StatelessWidget {
  const LoginSecureFooter({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    Widget line(bool left) => Expanded(
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: left
                ? const [Color(0x00FFFFFF), Color(0x40FFFFFF)]
                : const [Color(0x40FFFFFF), Color(0x00FFFFFF)],
          ),
        ),
      ),
    );
    return Row(
      children: [
        line(true),
        const SizedBox(width: 14),
        const LoginIcon('kilit', height: 18, color: LoginInk.text),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LoginInk.style(size: 15, weight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 14),
        line(false),
      ],
    );
  }
}

/// Koyu cam kutulu 6 haneli kod girişi.
class LoginPin extends StatelessWidget {
  const LoginPin({
    super.key,
    required this.controller,
    this.error = false,
    this.onCompleted,
  });

  final TextEditingController controller;
  final bool error;
  final ValueChanged<String>? onCompleted;

  @override
  Widget build(BuildContext context) {
    final base = PinTheme(
      width: 46,
      height: 56,
      textStyle: LoginInk.style(size: 22, weight: FontWeight.w700),
      decoration: BoxDecoration(
        color: LoginInk.field,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: error ? LoginInk.error : LoginInk.fieldLine,
          width: 1.2,
        ),
      ),
    );
    return Pinput(
      controller: controller,
      length: 6,
      obscureText: true,
      obscuringCharacter: '•',
      defaultPinTheme: base,
      focusedPinTheme: base.copyDecorationWith(
        border: Border.all(color: LoginInk.turkuaz, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: LoginInk.turkuaz.withValues(alpha: 0.2),
            blurRadius: 12,
          ),
        ],
      ),
      submittedPinTheme: base,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onCompleted: onCompleted,
      hapticFeedbackType: HapticFeedbackType.lightImpact,
      cursor: Container(width: 1.5, height: 22, color: LoginInk.turkuaz),
    );
  }
}
