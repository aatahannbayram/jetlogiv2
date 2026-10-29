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

  group('görev dışı konum (açık vardiya)', () {
    ({Dio dio, List<Map> sent}) panel({String? rejectShiftWith}) {
      final sent = <Map>[];
      final dio = Dio(BaseOptions(baseUrl: 'http://panel.test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.endsWith('/location')) {
              sent.add({'path': options.path, ...options.data as Map});
            }
            if (rejectShiftWith != null &&
                options.path.endsWith('/courier-shifts/location')) {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.badResponse,
                  response: Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 409,
                    data: {
                      'success': false,
                      'code': rejectShiftWith,
                      'error': {'code': rejectShiftWith},
                    },
                  ),
                ),
              );
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
      return (dio: dio, sent: sent);
    }

    SessionController session(Dio dio, Stream<LiveFix> Function() fixes) {
      final s = SessionController(panel: PanelApi(dio), liveFixes: fixes);
      s.panelLoggedIn = true;
      s.demo = false;
      s.shiftOpen = true;
      for (final t in s.tasks) {
        if (t.status == TaskStatus.inProgress) t.status = TaskStatus.assigned;
      }
      return s;
    }

    test(
      'görev yokken 2,5 dk aralıkla gider, görev başlayınca göreve geçer',
      () async {
        final p = panel();
        final fixes = StreamController<LiveFix>.broadcast();
        final s = session(p.dio, () => fixes.stream);
        s.notifyListeners();
        final now = DateTime.now().toUtc();

        fixes.add(_fix(38.0, 0, base: now));
        fixes.add(_fix(38.001, 60, base: now)); // 2,5 dk dolmadı
        // Hareket olmasa da süre dolunca gider (bekleyen kurye "Aktif" kalsın).
        fixes.add(_fix(38.001, 160, base: now));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(p.sent, hasLength(2));
        expect(
          p.sent.every((m) => m['path'] == '/courier-shifts/location'),
          isTrue,
        );
        expect(p.sent.first['latitude'], 38.0);
        expect(p.sent.first['accuracy'], 8);
        expect(p.sent.first['capturedAt'], isNotNull);

        final task = s.tasks.first;
        task.status = TaskStatus.inProgress;
        s.notifyListeners();
        fixes.add(_fix(38.01, 200, base: now));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(p.sent.last['path'], '/courier-tasks/${task.id}/location');

        // Vardiya kapanınca hiç konum gitmez.
        task.status = TaskStatus.delivered;
        s.setShiftOpen(false);
        final before = p.sent.length;
        fixes.add(_fix(38.02, 500, base: now));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(p.sent, hasLength(before));
        await fixes.close();
      },
    );

    test('sunucu vardiyayı kapalı görürse gönderim durur', () async {
      final p = panel(rejectShiftWith: 'NO_OPEN_SHIFT');
      final fixes = StreamController<LiveFix>.broadcast();
      var listens = 0;
      final s = session(p.dio, () {
        listens++;
        return fixes.stream;
      });
      s.notifyListeners();
      expect(listens, 1);
      final now = DateTime.now().toUtc();
      fixes.add(_fix(38.0, 0, base: now));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      fixes.add(_fix(38.0, 400, base: now));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(p.sent, hasLength(1), reason: 'reddedildikten sonra gönderim yok');
      await fixes.close();
    });
  });
}
