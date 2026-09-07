import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// OTP / şifre ekranlarında ekran görüntüsü ve kayıt koruması.
///
/// Android: `FLAG_SECURE`. iOS: yakalanan ekranda içeriği gizler.
/// Kanal yoksa (test / masaüstü) sessizce geçer.
class ScreenPrivacy {
  ScreenPrivacy._();

  static const _channel = MethodChannel('dijigoo/privacy');

  static Future<void> set(bool on) async {
    try {
      await _channel.invokeMethod<void>('setSecure', {'on': on});
    } on MissingPluginException {
      // Widget test / masaüstü.
    } catch (_) {}
  }
}

/// [active] iken native korumayı açar; widget ağaçtan çıkınca kapatır.
class PrivacyGate extends StatefulWidget {
  const PrivacyGate({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<PrivacyGate> createState() => _PrivacyGateState();
}

class _PrivacyGateState extends State<PrivacyGate> {
  @override
  void initState() {
    super.initState();
    if (widget.active) ScreenPrivacy.set(true);
  }

  @override
  void didUpdateWidget(covariant PrivacyGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      ScreenPrivacy.set(widget.active);
    }
  }

  @override
  void dispose() {
    if (widget.active) ScreenPrivacy.set(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
