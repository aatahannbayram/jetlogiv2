import 'dart:async';

import 'package:dijigoo_kurye/api/panel_client.dart';
import 'package:dijigoo_kurye/live_location.dart';
import 'package:dijigoo_kurye/models.dart';
import 'package:dijigoo_kurye/session.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

LiveFix _fix(double lat, int seconds, {DateTime? base}) => LiveFix(
  lat: lat,
  lng: 29.0,
  at: (base ?? DateTime.utc(2026, 10, 13, 9)).add(Duration(seconds: seconds)),
  accuracy: 8,
);

void main() {
  group('gönderim kuralı (30 sn + ~50 m)', () {
    test('ilk ölçüm hemen gider', () {
      expect(shouldSendLiveFix(null, _fix(38.0, 0)), isTrue);
    });

    test('30 sn dolmadan gitmez', () {
      // 0.001° enlem ≈ 111 m
      expect(shouldSendLiveFix(_fix(38.0, 0), _fix(38.001, 20)), isFalse);
    });

    test('süre dolsa da 50 m hareket yoksa gitmez', () {
      expect(shouldSendLiveFix(_fix(38.0, 0), _fix(38.0001, 60)), isFalse);
    });

    test('30 sn ve 50 m sonra gider', () {
      expect(shouldSendLiveFix(_fix(38.0, 0), _fix(38.001, 31)), isTrue);
    });

    test('5 dakikadan eski ölçüm taze sayılmaz', () {
      final now = DateTime.utc(2026, 10, 13, 9, 10);
      expect(isFreshLiveFix(_fix(38.0, 0), now), isFalse);
      expect(isFreshLiveFix(_fix(38.0, 9 * 60), now), isTrue);
    });
  });

  test('başlatılmış görev varken konum panele akar, bitince durur', () async {
    final sent = <Map>[];
    final dio = Dio(BaseOptions(baseUrl: 'http://panel.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.endsWith('/location')) {
            sent.add({'path': options.path, ...options.data as Map});
          }
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {'success': true, 'data': <String, Object>{}},
            ),
          );
        },
      ),
    );
    final fixes = StreamController<LiveFix>.broadcast();
    var listens = 0;
    final s = SessionController(
      panel: PanelApi(dio),
      liveFixes: () {
        listens++;
        return fixes.stream;
      },
    );
    s.panelLoggedIn = true;
    final task = s.tasks.first;
    final now = DateTime.now().toUtc();

    // Görev başlamadan takip açılmaz.
    for (final t in s.tasks) {
      if (t.status == TaskStatus.inProgress) t.status = TaskStatus.assigned;
    }
    s.notifyListeners();
    expect(listens, 0);

    task.status = TaskStatus.inProgress;
    s.notifyListeners();
    expect(listens, 1);

    fixes.add(_fix(38.0, 0, base: now));
    fixes.add(_fix(38.001, 10, base: now)); // 30 sn dolmadı
    fixes.add(_fix(38.002, 40, base: now));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(sent, hasLength(2));
    expect(sent.first['path'], '/courier-tasks/${task.id}/location');
    expect(sent.first['purposeCode'], 'ACTIVE_TASK');
    expect(sent.first['latitude'], 38.0);
    expect(sent.first['accuracy'], 8);
    expect(sent.last['latitude'], 38.002);
    expect(s.lastLiveLocationAt, isNotNull);

    // Sahte konum sağlayıcısından gelen ölçüm panele gitmez.
    fixes.add(
      LiveFix(
        lat: 39.5,
        lng: 29.0,
        at: now.add(const Duration(seconds: 90)),
        mocked: true,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(sent, hasLength(2));
    expect(s.mockLocationDetected, isTrue);

    task.status = TaskStatus.delivered;
    s.notifyListeners();
    fixes.add(_fix(38.01, 120, base: now));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(sent, hasLength(2), reason: 'görev bitince konum gönderilmez');
    await fixes.close();
  });
}
