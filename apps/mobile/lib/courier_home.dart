/// Ana sayfa sayaçları, kart işi ve maskeli arama için saf yardımcılar.
library;

import 'dart:math' as math;

double _sin2(double x) => math.pow(math.sin(x), 2).toDouble();
double _cos(double x) => math.cos(x);
double _asin(double x) => math.asin(x.clamp(-1.0, 1.0));
double _sqrt(double x) => math.sqrt(x);

/// Uzak sayaç varsa onu, yoksa yerel görevi kullan.
int dashCount(Map<String, int> remote, String key, int local) {
  if (!remote.containsKey(key)) return local;
  return remote[key] ?? local;
}

/// Panel satırındaki ürün / hizmet / müşteri kodu kart teslimatı mı.
/// Sodexo yemek işi kart sayılmaz. İşaret yoksa false.
bool isCardMarker({
  String? productCode,
  String? serviceType,
  String? customerCode,
}) {
  const markers = {
    'card',
    'kart',
    'kyc',
    'carddelivery',
    'kartteslim',
    'kartteslimat',
    'bankcard',
    'debitcard',
    'creditcard',
    'bankakart',
    'bankakarti',
  };
  final raw = [
    productCode,
    serviceType,
    customerCode,
  ].whereType<String>().join(' ').toLowerCase();
  if (raw.trim().isEmpty) return false;
  final tokens = raw
      .split(RegExp(r'[^a-z0-9]+'))
      .where((t) => t.isNotEmpty && !t.contains('sodexo'));
  for (final t in tokens) {
    if (markers.contains(t)) return true;
  }
  return false;
}

/// Komşuya bırakma seçeneği. Kart tesliminde kapanır.
bool isNeighborDropOff(String code, String label) {
  final blob = '$code $label'
      .toLowerCase()
      .replaceAll('ş', 's')
      .replaceAll('ı', 'i')
      .replaceAll('ö', 'o')
      .replaceAll('ü', 'u')
      .replaceAll('ğ', 'g')
      .replaceAll('ç', 'c');
  return blob.contains('neighbor') ||
      blob.contains('neighbour') ||
      blob.contains('komsu');
}

String _digits(String? raw) => (raw ?? '').replaceAll(RegExp(r'\D'), '');

/// Son 10 hane aynıysa aynı hat.
bool sameMsisdn(String? a, String? b) {
  final da = _digits(a);
  final db = _digits(b);
  if (da.length < 10 || db.length < 10) return false;
  return da.substring(da.length - 10) == db.substring(db.length - 10);
}

/// Santralin verdiği köprü numara. Alıcının kendi hattı veya boş yanıt null.
String? bridgeDial({
  required String phone,
  required String telUri,
  String? recipient,
}) {
  final raw = phone.trim().isNotEmpty ? phone : telUri.trim();
  if (_digits(raw).length < 7) return null;
  if (sameMsisdn(raw, recipient)) return null;
  return raw;
}

/// `POST courier-tasks/{id}/call` kararı.
///
/// `ORIGINATED`: santral önce kuryenin hattını çaldırır, çevirici açılmaz.
/// Numara dönerse santral başlatmamıştır; arama `tel:` ile açılır.
class CallPlan {
  const CallPlan.pbx([this.notice]) : target = null, blocked = false;

  const CallPlan.dial(String this.target) : notice = null, blocked = false;

  /// Panel köprü yerine alıcının numarasını döndü; arama yapılmaz.
  const CallPlan.blocked() : target = null, notice = null, blocked = true;

  final String? notice;
  final String? target;
  final bool blocked;

  bool get ringsViaPbx => target == null && !blocked;
}

CallPlan planPanelCall({
  String? mode,
  String? message,
  String? phone,
  String? telUri,
  String? recipientPhone,
  bool requireExchange = false,
}) {
  final notice = (message ?? '').trim();
  if ((mode ?? '').trim().toUpperCase() == 'ORIGINATED') {
    return CallPlan.pbx(notice.isEmpty ? null : notice);
  }
  final raw = (telUri ?? '').trim().isNotEmpty
      ? telUri!.trim()
      : (phone ?? '').trim();
  if (raw.contains('*') || _digits(raw).length < 7) {
    return CallPlan.pbx(notice.isEmpty ? null : notice);
  }
  // JetDiji kurye API v1.6: `mode` yoksa dönen numara alıcının gerçek
  // numarasıdır (geçiş dönemi). Santral zorunluyken çevirici açılmaz.
  if (requireExchange) return const CallPlan.blocked();
  // Santral köprüsü değil, alıcının kendi hattı: numara kuryeye açılmaz.
  if (sameMsisdn(raw, recipientPhone)) return const CallPlan.blocked();
  return CallPlan.dial(raw);
}

/// Ekranda gösterilecek maskeli numara: "+90 5** *** 34 27".
/// Numara yoksa ya da kısaysa null.
String? maskPhone(String? raw) {
  final t = (raw ?? '').trim();
  // Panel zaten maskeli verdiyse (`recipientPhoneMasked`) olduğu gibi.
  if (t.contains('*')) return t;
  final d = _digits(raw);
  if (d.length < 10) return null;
  final last10 = d.substring(d.length - 10);
  return '+90 ${last10[0]}** *** ${last10.substring(6, 8)} ${last10.substring(8)}';
}

const _digitWords = {
  'sıfır': '0',
  'sifir': '0',
  'zero': '0',
  'bir': '1',
  'one': '1',
  'iki': '2',
  'two': '2',
  'üç': '3',
  'uc': '3',
  'three': '3',
  'dört': '4',
  'dort': '4',
  'four': '4',
  'beş': '5',
  'bes': '5',
  'five': '5',
  'altı': '6',
  'alti': '6',
  'six': '6',
  'yedi': '7',
  'seven': '7',
  'sekiz': '8',
  'eight': '8',
  'dokuz': '9',
  'nine': '9',
};

const _tensWords = {
  'on': 1,
  'yirmi': 2,
  'otuz': 3,
  'kırk': 4,
  'kirk': 4,
  'elli': 5,
  'altmış': 6,
  'altmis': 6,
  'yetmiş': 7,
  'yetmis': 7,
  'seksen': 8,
  'doksan': 9,
};

/// Konuşmadan barkod. Rakam kelimeleri çevrilir ("seksen sekiz" → 88,
/// "on" → 10); kurye alanı görüp onaylar.
String barcodeFromSpeech(String spoken) {
  final normalized = spoken.toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9çğıöşü\s]'),
    ' ',
  );
  final words = [
    for (final w in normalized.split(RegExp(r'\s+')))
      if (w.isNotEmpty) w,
  ];
  final out = StringBuffer();
  for (var i = 0; i < words.length; i++) {
    final raw = words[i];
    final tens = _tensWords[raw];
    if (tens != null) {
      final next = i + 1 < words.length ? _digitWords[words[i + 1]] : null;
      if (next != null && next != '0') {
        out.write('$tens$next');
        i++;
      } else {
        out.write('${tens}0');
      }
      continue;
    }
    final word = _digitWords[raw];
    if (word != null) {
      out.write(word);
      continue;
    }
    final chunk = raw.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (chunk.isEmpty) continue;
    if (chunk == 'barkod' ||
        chunk == 'barcode' ||
        chunk == 'kod' ||
        chunk == 'code') {
      continue;
    }
    out.write(chunk);
  }
  return out.toString().toUpperCase();
}

/// Panel form alanı barkod / kargo kodu istiyor mu (sesle dikte için).
bool isBarcodeField(String code, String label) {
  final blob = '$code $label'.toLowerCase();
  return blob.contains('barkod') ||
      blob.contains('barcode') ||
      blob.contains('kargo kodu') ||
      blob.contains('cargo_code') ||
      blob.contains('takip no') ||
      blob.contains('tracking');
}

/// V3 §6 varsayılan geofence yarıçapı. Panel proje bazında değiştirebilir.
const kDefaultGeofenceMeters = 500.0;

/// Kurye konumu biliniyorsa durağa uzaklık; bilinmiyorsa null.
/// Durak koordinatı yoksa da null döner, sahte "uygun" gösterilmez.
double? geofenceDistance({
  required bool located,
  required double selfLat,
  required double selfLng,
  required double stopLat,
  required double stopLng,
  required bool stopHasCoordinates,
}) {
  if (!located || !stopHasCoordinates) return null;
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(stopLat - selfLat);
  final dLng = rad(stopLng - selfLng);
  final a =
      _sin2(dLat / 2) +
      _cos(rad(selfLat)) * _cos(rad(stopLat)) * _sin2(dLng / 2);
  return 2 * r * _asin(_sqrt(a));
}

/// "2 sa 15 dk" / "45 dk" biçimi.
String etaLabel(int minutes, {String hour = 'sa', String minute = 'dk'}) {
  final m = minutes < 0 ? 0 : minutes;
  if (m < 60) return '$m $minute';
  final h = m ~/ 60;
  final rest = m % 60;
  return rest == 0 ? '$h $hour' : '$h $hour $rest $minute';
}

/// "450 m" / "18,4 km".
String distanceLabel(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
}
