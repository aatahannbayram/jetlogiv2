import 'package:dijigoo_kurye/api/client.dart';
import 'package:dijigoo_kurye/api/models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('E.164 telefon normalizasyonu', () {
    expect(e164('0532 000 00 26'), '+905320000026');
    expect(e164('+90 532 111 00 26'), '+905321110026');
  });

  test('demo config sözleşmeyi doldurur', () {
    final cfg = AppConfig.fromJson(mockPayload('/v1/config', RequestOptions(path: '/v1/config')));
    expect(cfg.environment, 'demo');
    expect(cfg.forceUpdate, isFalse);
    expect(cfg.featureFlags.shiftFaceMatch, isFalse);
    expect(cfg.featureFlags.offlineSync, isTrue);
    expect(cfg.geofenceDefaultRadiusMeters, 200);
  });

  test('demo müsaitlik sözleşmeyi doldurur', () {
    final av = CourierAvailabilityDto.fromJson(
      mockPayload('/v1/me/availability', RequestOptions(path: '/v1/me/availability')),
    );
    expect(av.city, 'Denizli');
    expect(av.district, 'Güney');
    expect(av.vehicleLabel, 'Otomobil');
    expect(av.employmentLabel, 'Yarı zamanlı');
    expect(av.statusLabel, 'Müsait');
    expect(av.hoursLabel, contains('Pzt'));
    expect(av.hoursLabel, contains('09:00'));
  });

  test('demo rota gerçek OSRM çıktısıyla optimize sırayı (t1-t2-t4-t3) döner', () {
    final route = RoutePlanDto.fromJson(
      mockPayload('/v1/routes/current', RequestOptions(path: '/v1/routes/current')),
    );
    expect(route.mode, 'distance_optimized');
    expect(route.hasRealGeometry, isTrue);
    expect(route.stops.map((s) => s.taskId), ['t1', 't2', 't4', 't3']);
    expect(route.stops.first.distanceMeters, isNull, reason: 'ilk durağın bacak mesafesi yok');
    expect(route.totalDistanceMeters, 1185 + 2799 + 2817);
    expect(route.totalDurationSeconds, 145 + 383 + 292);
  });

  test('demo zimmet listesi Şube devri için barkodlu 3 parsel döner', () {
    final payload = mockPayload('/v1/custody', RequestOptions(path: '/v1/custody'));
    final items = (payload['items'] as List).cast<Map<String, dynamic>>();
    expect(items, hasLength(3));
    expect(items.map((e) => e['barcode']), containsAll(['DGO-9107', 'DGO-9114', 'DGO-9121']));
  });

  test('demo zimmet devri: devredilen kalemler kalan listeden düşer', () {
    final payload = mockPayload(
      '/v1/custody/handover',
      RequestOptions(
        path: '/v1/custody/handover',
        data: {
          'itemIds': ['10000000-0000-4000-a000-000000000001', '10000000-0000-4000-a000-000000000002'],
        },
      ),
    );
    final remaining = (payload['remaining'] as List).cast<Map<String, dynamic>>();
    expect(remaining, hasLength(1));
    expect(remaining.single['barcode'], 'DGO-9121');
    expect(payload['handoverId'], isNotEmpty);
  });

  test('demo belgeler APPROVED yerine COMPLETED gelir', () {
    final docs = CourierDocumentListDto.fromJson(
      mockPayload('/v1/me/documents', RequestOptions(path: '/v1/me/documents')),
    );
    expect(docs.completedCount, 2);
    expect(docs.items.map((e) => e.type), ['IDENTITY', 'DRIVING_LICENSE']);
    expect(docs.summary, contains('tamam'));
  });
}
