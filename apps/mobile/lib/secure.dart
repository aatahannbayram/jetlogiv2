import 'package:flutter/foundation.dart';

/// Release derlemesinde demo OTP, mühendis paneli, public OSRM ve
/// düz-metin disk günlüğü kapalıdır. Debug / widget testleri etkilenmez.
bool get kAllowDebugBypass => !kReleaseMode;

bool isHttpsUrl(String url) {
  final uri = Uri.tryParse(url);
  return uri != null && uri.scheme == 'https';
}

/// Üretimde token veya konumun düz HTTP ile çıkmasını engeller.
void assertHttpsInRelease(String url, String name) {
  if (kReleaseMode && !isHttpsUrl(url)) {
    throw StateError('$name must use https in release');
  }
}

/// Günlük satırındaki koordinat ve demo sırlarını kırpar.
String redactForLog(String message, {bool? release}) {
  if (!(release ?? kReleaseMode)) return message;
  var out = message.replaceAllMapped(
    RegExp(r'-?\d{1,3}\.\d{2,}'),
    (_) => '*.*',
  );
  return out.replaceAll(
    RegExp(r'demo-access|demo-refresh|482913|123456|kurye@dijigoo\.test'),
    '***',
  );
}
