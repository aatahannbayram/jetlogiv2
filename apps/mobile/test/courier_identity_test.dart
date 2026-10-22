import 'dart:io' show Cookie;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dijigoo_kurye/api/panel_client.dart';
import 'package:dijigoo_kurye/models.dart';
import 'package:dijigoo_kurye/session.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// `courier-profile` yanıtı JetDiji preprod'daki biçimle aynı.
PanelApi _server({CookieJar? jar}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://panel.test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        Object data = <String, Object>{};
        if (options.path == '/courier-profile') {
          data = {
            'courier': {
              'courierCode': 'DGC-2026-BC2058ED',
              'fullName': 'Demo Kurye Keçiören',
              'phone': '+905000000612',
              'vehicleType': 'MOTORCYCLE',
              'workModel': 'FULL_TIME',
              'status': 'ASSIGNED',
              'city': {'id': 7, 'name': 'Ankara'},
              'district': {'id': 83, 'name': 'Keçiören'},
            },
          };
        } else if (options.path == '/courier-auth/session') {
          data = {
            'courier': {
              'courierCode': 'DGC-2026-BC2058ED',
              'fullName': 'Demo Kurye Keçiören',
            },
          };
        } else if (options.path == '/courier-my-documents') {
          data = {'items': <Object>[]};
        }
        handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': data},
          ),
        );
      },
    ),
  );
  return PanelApi(dio, jar);
}

void main() {
  test('girişten önce kimsenin adı görünmez', () {
    // Uygulamadaki kurulum (main.dart): demo tohumu yok.
    final s = SessionController(waitForConfig: true);
    expect(s.courier.fullName, isEmpty);
    expect(s.courier.phone, isEmpty);
    expect(s.courier.district, isEmpty);
  });

  test('profil giren kuryenin JetDiji kaydından gelir', () async {
    final s = SessionController(panel: _server())..panelLoggedIn = true;
    await s.loadIdentity();
    expect(s.courier.fullName, 'Demo Kurye Keçiören');
    expect(s.courier.code, 'DGC-2026-BC2058ED');
    expect(s.courier.phone, '+90 500 000 06 12');
    expect(s.courier.district, 'Keçiören');
    expect(s.courier.city, 'Ankara');
    expect(s.courier.vehicle, 'MOTORCYCLE');
    expect(s.courier.employment, 'FULL_TIME');
  });

  test('çıkışta profil temizlenir, sonraki kişi öncekini görmez', () async {
    final s = SessionController(panel: _server())..panelLoggedIn = true;
    await s.loadIdentity();
    await s.logout();
    expect(s.courier.fullName, isEmpty);
    expect(s.courier.phone, isEmpty);
  });

  test('örnek kurye yalnız demo sahada görünür', () {
    final s = SessionController();
    s.skipToDemo(allow: true);
    expect(s.courier.fullName, Courier.demo.fullName);
  });

  test('vardiya açıkken soğuk açılışta oturum ve ad sunucudan gelir', () async {
    final jar = CookieJar();
    await jar.saveFromResponse(Uri.parse('http://panel.test'), [
      Cookie('dijigoo_courier_session', 'x'),
    ]);
    // Uygulamadaki gibi: demo tohumu yok, vardiya açık → doğrudan ana sayfa.
    final s = SessionController(
      panel: _server(jar: jar),
      waitForConfig: true,
      initialPhase: AppPhase.main,
    );
    await s.onForeground();
    expect(s.panelLoggedIn, isTrue);
    expect(s.courier.fullName, 'Demo Kurye Keçiören');
  });

  test('telefon okunur biçimde yazılır', () {
    expect(formatTrPhone('+905000000612'), '+90 500 000 06 12');
    expect(formatTrPhone('12345'), '12345');
  });
}
