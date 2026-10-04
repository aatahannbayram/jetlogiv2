import 'dart:convert';

import 'package:flutter/services.dart';

/// Metinler eşleme anahtarıdır. İstemci bu listenin dışına seçenek eklemez.
const pluxeeCatalogVersion = 'pluxee-iptal-2026-10';

/// Kanıt yokken otomatik başarı verilmeyen katalog maddeleri.
const pluxeeOpsHoldDetails = <String>{
  'Fotoğraf izni yok',
  'Güvenlik giriş izni vermiyor',
};

class PluxeeReasonGroup {
  const PluxeeReasonGroup({required this.reason, required this.details});

  final String reason;
  final List<String> details;
}

class PluxeeCatalog {
  const PluxeeCatalog(this.groups);

  final List<PluxeeReasonGroup> groups;

  int get detailCount =>
      groups.fold<int>(0, (count, group) => count + group.details.length);

  List<String> detailsFor(String reason) {
    for (final group in groups) {
      if (group.reason == reason) return List.unmodifiable(group.details);
    }
    return const [];
  }

  bool containsDetail(String reason, String detail) =>
      detailsFor(reason).contains(detail);

  static PluxeeCatalog parse(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Pluxee katalog nesne olmalı.');
    }
    return PluxeeCatalog([
      for (final entry in decoded.entries)
        if (entry.value is List)
          PluxeeReasonGroup(
            reason: '${entry.key}',
            details: [for (final item in entry.value as List) '$item'],
          ),
    ]);
  }

  static Future<PluxeeCatalog> load() async {
    final raw = await rootBundle.loadString(
      'assets/pluxee/iptal_secenekleri.json',
    );
    return parse(raw);
  }
}
