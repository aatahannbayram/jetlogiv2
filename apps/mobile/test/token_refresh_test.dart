import 'dart:convert';
import 'dart:typed_data';

import 'package:dijigoo_kurye/api/agency_client.dart';
import 'package:dijigoo_kurye/api/panel_client.dart';
import 'package:dijigoo_kurye/data/vault.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Reply = ({int status, Object body});

/// Sunucuyu taklit eden HTTP katmanı. Interceptor zinciri (Bearer ekleme,
/// 401'de yenileme, tekrar) gerçek haliyle çalışır.
class _Server implements HttpClientAdapter {
  _Server(this.handle);

  final _Reply Function(RequestOptions options) handle;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    // Eşzamanlı istekler gerçekten üst üste binsin.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final reply = handle(options);
    return ResponseBody.fromString(
      jsonEncode(reply.body),
      reply.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _unauthorized = (
  status: 401,
  body: {'success': false, 'code': 'UNAUTHENTICATED'},
);

_Reply _ok(Object data) => (status: 200, body: {'success': true, 'data': data});

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('kurye oturumu', () {
    test('401 → refresh → istek yeni tokenla bir kez tekrarlanır', () async {
      final vault = Vault();
      await vault.writeSecret(kPanelRefreshKey, 'rt-1');
      var refreshes = 0;
      final server = _Server((o) {
        if (o.path.endsWith('/courier-auth/refresh')) {
          refreshes++;
          // Yenileme ucuna Bearer gitmez; refresh tokenı gövdededir.
          expect(o.headers['Authorization'], isNull);
          expect((o.data as Map)['refreshToken'], 'rt-1');
          return _ok({'accessToken': 'new', 'refreshToken': 'rt-2'});
        }
        return o.headers['Authorization'] == 'Bearer new'
            ? _ok({'awaitingDelivery': 3})
            : _unauthorized;
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/public/v1'))
        ..httpClientAdapter = server;
      final api = PanelApi(dio, null, vault);

      // Üç istek aynı anda 401 alır; tek kullanımlık token tek kez yenilenir.
      final results = await Future.wait([
        for (var i = 0; i < 3; i++)
          api.dio.get<Map<String, dynamic>>('/courier-dashboard'),
      ]);
      expect(results.every((r) => r.statusCode == 200), isTrue);
      expect(refreshes, 1);
      expect(await vault.readSecret(kPanelBearerKey), 'new');
      expect(await vault.readSecret(kPanelRefreshKey), 'rt-2');
    });

    test('refresh reddedilirse tokenlar silinir, 401 döner', () async {
      final vault = Vault();
      await vault.writeSecret(kPanelBearerKey, 'old');
      await vault.writeSecret(kPanelRefreshKey, 'rt-used');
      final server = _Server((o) {
        if (o.path.endsWith('/courier-auth/refresh')) {
          return (
            status: 401,
            body: {'success': false, 'code': 'REFRESH_TOKEN_INVALID'},
          );
        }
        return _unauthorized;
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/public/v1'))
        ..httpClientAdapter = server;
      final api = PanelApi(dio, null, vault);
      await expectLater(
        api.dio.get<Map<String, dynamic>>('/courier-dashboard'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            401,
          ),
        ),
      );
      expect(await vault.readSecret(kPanelBearerKey), isNull);
      expect(await vault.readSecret(kPanelRefreshKey), isNull);
    });

    test('giriş refresh tokenını saklar, çıkış onu gövdede gönderir', () async {
      final vault = Vault();
      final server = _Server((o) {
        if (o.path.endsWith('/courier-auth/login')) {
          return _ok({
            'accessToken': 'a1',
            'refreshToken': 'rt-login',
            'courier': {'id': 'c1', 'fullName': 'Ali'},
          });
        }
        if (o.path.endsWith('/courier-auth/logout')) {
          expect((o.data as Map)['refreshToken'], 'rt-login');
          return _ok({});
        }
        return _unauthorized;
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/public/v1'))
        ..httpClientAdapter = server;
      final api = PanelApi(dio, null, vault);
      await api.login(identifier: 'ali@test', password: 'x');
      expect(await vault.readSecret(kPanelRefreshKey), 'rt-login');
      await api.logout();
      expect(await vault.readSecret(kPanelRefreshKey), isNull);
      expect(
        server.requests.where((r) => r.path.endsWith('/logout')),
        hasLength(1),
      );
    });

    test('girişin 401\'i yenileme tetiklemez', () async {
      final vault = Vault();
      await vault.writeSecret(kPanelRefreshKey, 'rt-1');
      final server = _Server((o) => _unauthorized);
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/public/v1'))
        ..httpClientAdapter = server;
      final api = PanelApi(dio, null, vault);
      await expectLater(
        api.login(identifier: 'ali@test', password: 'yanlis'),
        throwsA(anything),
      );
      expect(
        server.requests.where((r) => r.path.endsWith('/courier-auth/refresh')),
        isEmpty,
      );
      expect(await vault.readSecret(kPanelRefreshKey), 'rt-1');
    });
  });

  group('şube oturumu', () {
    test('401 → agency-auth/refresh → istek tekrarlanır', () async {
      final vault = Vault();
      await vault.writeSecret(kAgencyRefreshKey, 'rt-a');
      var refreshes = 0;
      final server = _Server((o) {
        if (o.path.endsWith('/agency-auth/refresh')) {
          refreshes++;
          expect(o.headers['Authorization'], isNull);
          return _ok({'accessToken': 'b2', 'refreshToken': 'rt-b'});
        }
        return o.headers['Authorization'] == 'Bearer b2'
            ? _ok({
                'branch': {'name': 'Kadıköy'},
              })
            : _unauthorized;
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/portal/v1'))
        ..httpClientAdapter = server;
      final api = AgencyPortalApi(dio, null, vault);
      final dashboard = await api.fetchDashboard();
      expect(dashboard.branchName, 'Kadıköy');
      expect(refreshes, 1);
      expect(await vault.readSecret(kAgencyBearerKey), 'b2');
      expect(await vault.readSecret(kAgencyRefreshKey), 'rt-b');
    });
  });
}
