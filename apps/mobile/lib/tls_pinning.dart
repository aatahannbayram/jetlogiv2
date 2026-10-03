import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

/// Ek yaprak pin'leri: `host|base64;host|base64`
/// Örnek: `--dart-define=TLS_PINS=kurye.dijigoo.com|AAAA...`
const kTlsExtraPins = String.fromEnvironment('TLS_PINS');

/// Güncel yaprak (dijigoo.com / kurye.dijigoo.com, GTS WE1, ~14 Eki 2026).
const kDijigooLeafSpki = 'RoH/tTkvQyCBlabxTx57QdBhf05SP5K2Hb5J9zzMX6I=';

/// GTS ara CA — yaprak yenilenince zincirde kalır (Android/iOS pin-set).
const kGtsCaPins = [
  'kIdp6NNEd8wsugYyyIYFsi1ylMCED3hZbSR8ZFsa/A4=', // WE1
  'vh78KSg1Ry4NaqGDV10w/cTb9VH3BQUZoCWNa93W/EY=', // WE2
  'yDu9og255NN5GEf+Bwa9rTrqFQ0EydZ0r1FCh9TdAW4=', // WR1
  'YPtHaftLw6/0vnc2BnNKGF54xiCA28WFcccjkA4ypCM=', // WR2
];

const _gtsIssuerNeedles = [
  'WE1',
  'WE2',
  'WR1',
  'WR2',
  'Google Trust Services',
];

bool isFirstPartyHost(String host) {
  final h = host.toLowerCase();
  return h == 'dijigoo.com' || h.endsWith('.dijigoo.com');
}

Map<String, Set<String>> parseTlsPins(String raw) {
  final out = <String, Set<String>>{};
  if (raw.trim().isEmpty) return out;
  for (final part in raw.split(';')) {
    final bit = part.trim();
    if (bit.isEmpty) continue;
    final split = bit.indexOf('|');
    if (split <= 0 || split == bit.length - 1) continue;
    final host = bit.substring(0, split).trim().toLowerCase();
    final pin = bit.substring(split + 1).trim();
    out.putIfAbsent(host, () => {}).add(pin);
  }
  return out;
}

Set<String> leafPinsForHost(String host) {
  final h = host.toLowerCase();
  final out = <String>{};
  if (isFirstPartyHost(h)) out.add(kDijigooLeafSpki);
  final extra = parseTlsPins(kTlsExtraPins);
  out.addAll(extra[h] ?? const {});
  return out;
}

bool issuerLooksLikeGts(String issuer) {
  return _gtsIssuerNeedles.any(issuer.contains);
}

/// Sistem CA doğrulamasından sonra çağrılır. Birinci taraf host'ta
/// yaprak pin veya GTS ara-CA ailesi gerekir (Let's Encrypt ile MITM olmasın).
bool tlsHostAllowed({
  required String host,
  required String issuer,
  required String spkiBase64,
  bool? release,
}) {
  if (!(release ?? kReleaseMode)) return true;
  if (!isFirstPartyHost(host)) {
    final extra = parseTlsPins(kTlsExtraPins)[host.toLowerCase()];
    if (extra == null || extra.isEmpty) return true;
    return extra.contains(spkiBase64);
  }
  if (leafPinsForHost(host).contains(spkiBase64)) return true;
  return issuerLooksLikeGts(issuer);
}

String spkiSha256Base64(List<int> der) {
  final spki = extractSubjectPublicKeyInfo(der);
  return base64Encode(sha256.convert(spki).bytes);
}

/// X.509 `subjectPublicKeyInfo` DER (SEQUENCE), Android pin-set ile aynı girdi.
List<int> extractSubjectPublicKeyInfo(List<int> der) {
  final cert = _readTlv(der, 0);
  if (cert.tag != 0x30) {
    throw const FormatException('certificate is not a SEQUENCE');
  }
  final tbs = _readTlv(cert.body, 0);
  if (tbs.tag != 0x30) {
    throw const FormatException('tbsCertificate is not a SEQUENCE');
  }
  var offset = 0;
  final fields = <_Tlv>[];
  while (offset < tbs.body.length) {
    final field = _readTlv(tbs.body, offset);
    fields.add(field);
    offset += field.total;
  }
  var i = 0;
  if (fields.isNotEmpty && fields[0].tag == 0xA0) i = 1;
  // serial, signature, issuer, validity, subject, spki
  i += 5;
  if (i >= fields.length) {
    throw const FormatException('subjectPublicKeyInfo missing');
  }
  return fields[i].raw;
}

void attachTlsPinning(Dio dio) {
  dio.httpClientAdapter = IOHttpClientAdapter(
    validateCertificate: (cert, host, port) {
      if (cert == null) return !kReleaseMode;
      return tlsHostAllowed(
        host: host,
        issuer: cert.issuer,
        spkiBase64: spkiSha256Base64(cert.der),
      );
    },
  );
}

class _Tlv {
  const _Tlv({
    required this.tag,
    required this.body,
    required this.raw,
    required this.total,
  });
  final int tag;
  final List<int> body;
  final List<int> raw;
  final int total;
}

_Tlv _readTlv(List<int> bytes, int offset) {
  if (offset >= bytes.length) {
    throw const FormatException('truncated DER');
  }
  final start = offset;
  final tag = bytes[offset++];
  if (offset >= bytes.length) {
    throw const FormatException('truncated DER length');
  }
  var len = bytes[offset++];
  if (len & 0x80 != 0) {
    final n = len & 0x7f;
    if (n == 0 || n > 4 || offset + n > bytes.length) {
      throw const FormatException('bad DER length');
    }
    len = 0;
    for (var i = 0; i < n; i++) {
      len = (len << 8) | bytes[offset++];
    }
  }
  if (offset + len > bytes.length) {
    throw const FormatException('DER body overruns buffer');
  }
  final body = bytes.sublist(offset, offset + len);
  final end = offset + len;
  return _Tlv(
    tag: tag,
    body: body,
    raw: bytes.sublist(start, end),
    total: end - start,
  );
}

Uint8List pemToDer(String pem) {
  final b64 = pem
      .replaceAll(RegExp(r'-----BEGIN [^-]+-----'), '')
      .replaceAll(RegExp(r'-----END [^-]+-----'), '')
      .replaceAll(RegExp(r'\s'), '');
  return base64Decode(b64);
}
