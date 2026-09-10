import 'package:flutter/foundation.dart';

/// Release'de sahte OTP (123456), mühendis paneli ve panel demo şifresi
/// kapalıdır. Yerel demo saha (skipToDemo) [kAllowDemo] / [demoFieldAllowed]
/// ile ayrı kapıdan geçer.
bool get kAllowDebugBypass => !kReleaseMode;

/// Sideload / mağaza ayrımı: `--dart-define=ALLOW_DEMO=true` ile açılır.
/// Debug ve widget testlerinde kapı varsayılan açık kalır.
const kAllowDemo = bool.fromEnvironment('ALLOW_DEMO', defaultValue: false);

bool demoFieldAllowed({bool? release}) {
  if (kAllowDemo) return true;
  return !(release ?? kReleaseMode);
}

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

/// Günlük satırındaki koordinat, token ve telefonu kırpar.
String redactForLog(String message, {bool? release}) {
  if (!(release ?? kReleaseMode)) return message;
  var out = message.replaceAllMapped(
    RegExp(r'-?\d{1,3}\.\d{2,}'),
    (_) => '*.*',
  );
  out = out.replaceAll(
    RegExp(r'Bearer\s+[A-Za-z0-9._\-+=]+', caseSensitive: false),
    'Bearer ***',
  );
  out = out.replaceAll(
    RegExp(r'eyJ[A-Za-z0-9_\-]+=*\.[A-Za-z0-9_\-]+=*\.[A-Za-z0-9_\-+=]+'),
    '***',
  );
  out = out.replaceAll(
    RegExp(r'(?:\+90|0)?5\d{9}\b'),
    '***',
  );
  return out.replaceAll(
    RegExp(r'demo-access|demo-refresh|482913|123456|kurye@dijigoo\.test'),
    '***',
  );
}
