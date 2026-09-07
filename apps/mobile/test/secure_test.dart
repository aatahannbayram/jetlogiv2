import 'package:dijigoo_kurye/api/client.dart';
import 'package:dijigoo_kurye/app.dart';
import 'package:dijigoo_kurye/road.dart';
import 'package:dijigoo_kurye/secure.dart';
import 'package:dijigoo_kurye/session.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('redactForLog üretimde koordinat ve demo sırlarını kırpar', () {
    const raw =
        'osrm miss 38.1476,29.0702 demo-access 482913 kurye@dijigoo.test';
    expect(redactForLog(raw, release: false), raw);
    final cut = redactForLog(raw, release: true);
    expect(cut, isNot(contains('38.1476')));
    expect(cut, isNot(contains('demo-access')));
    expect(cut, isNot(contains('482913')));
    expect(cut, isNot(contains('kurye@dijigoo.test')));
  });

  test('isHttpsUrl yalnız https kabul eder', () {
    expect(isHttpsUrl('https://kurye.dijigoo.com/api/mobile'), isTrue);
    expect(isHttpsUrl('http://localhost:3000/api'), isFalse);
    expect(isHttpsUrl('not-a-url'), isFalse);
  });

  test('osrmHosts üretimde public demo ucunu ve HTTP’yi çıkarır', () {
    final debugHosts = osrmHosts(release: false);
    expect(debugHosts, contains(kPublicOsrm));
    final prod = osrmHosts(release: true);
    expect(prod.every(isHttpsUrl), isTrue);
    if (kOsrmUrl == kPublicOsrm) {
      expect(prod, isEmpty);
    } else {
      expect(prod, isNot(contains(kPublicOsrm)));
    }
  });

  test('depo kilitliyken pull ve push yutulur', () async {
    final s = SessionController()..storageOk = false;
    final before = s.tasks.length;
    await s.pullTasks();
    s.ingestPushData({'kind': 'TASK_ASSIGNED', 'taskId': 't-new'});
    await s.registerPushToken('tok');
    expect(s.tasks.length, before);
    expect(s.tasks.any((t) => t.id == 't-new'), isFalse);
  });

  test('verifyActivation token yokken debug’da demo çifti yazar', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {'tokens': <String, dynamic>{}},
            ),
          );
        },
      ),
    );
    final tokens = await MobileApi(dio: dio).verifyActivation(
      challengeId: 'c1',
      code: '000000',
      installationId: '11111111-1111-4111-8111-111111111111',
    );
    expect(tokens.accessToken, 'demo-access');
    expect(tokens.refreshToken, 'demo-refresh');
  });

  test('teslim OTP debug kodu ile geçer', () async {
    final s = SessionController();
    expect(await s.sendDeliveryOtp('t1'), isTrue);
    expect(await s.verifyDeliveryOtp('t1', '000000'), isFalse);
    expect(await s.verifyDeliveryOtp('t1', '482913'), isTrue);
  });

  testWidgets('şifreli depo kilitliyken saha açılmaz', (tester) async {
    final session = SessionController()..storageOk = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith((ref) => session)],
        child: const DijigooApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Güvenli depo açılamadı'), findsOneWidget);
    expect(find.text('Atla'), findsNothing);
  });
}
