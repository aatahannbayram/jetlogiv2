import 'package:dijigoo_kurye/api/client.dart';
import 'package:dijigoo_kurye/app.dart';
import 'package:dijigoo_kurye/road.dart';
import 'package:dijigoo_kurye/secure.dart';
import 'package:dijigoo_kurye/session.dart';
import 'package:dijigoo_kurye/tls_pinning.dart';
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

  test('SPKI çıkarımı Android pin-set ile aynı base64 üretir', () {
    const pem = '''
-----BEGIN CERTIFICATE-----
MIIBezCCASGgAwIBAgIUMP6thXQX+iDAW/k4Z/4Iw52FPbAwCgYIKoZIzj0EAwIw
EzERMA8GA1UEAwwIcGluLnRlc3QwHhcNMjYwOTA3MTEyNDQ5WhcNMzYwOTA0MTEy
NDQ5WjATMREwDwYDVQQDDAhwaW4udGVzdDBZMBMGByqGSM49AgEGCCqGSM49AwEH
A0IABDHGo6XVP2Zf8cE0U9+7HAQHwbAatMhdtKbVjBd679shGjhQyw+p85QqyNGx
mkCsxjaCDEUkrFpwb8Zfg49RzGKjUzBRMB0GA1UdDgQWBBTQPFvrPXQE3sM7zGft
mZ4iVSL6pzAfBgNVHSMEGDAWgBTQPFvrPXQE3sM7zGftmZ4iVSL6pzAPBgNVHRMB
Af8EBTADAQH/MAoGCCqGSM49BAMCA0gAMEUCIG5OrGenFRfYhE8df+f6U3sNUmLR
2OG98h7cXjqh7CLLAiEAyKf0e5DYoQxnVgvumeN+QbAPAs09JSwJQGM5g2sNr+o=
-----END CERTIFICATE-----
''';
    expect(spkiSha256Base64(pemToDer(pem)), 'CSg26u1uWjiZra4lONRo1PyYAwM31d19fPbD3vnHaws=');
  });

  test('birinci taraf host GTS ailesi veya yaprak pin ister', () {
    expect(isFirstPartyHost('kurye.dijigoo.com'), isTrue);
    expect(isFirstPartyHost('api.mapbox.com'), isFalse);
    expect(
      tlsHostAllowed(
        host: 'server.arcgisonline.com',
        issuer: 'CN=Let\'s Encrypt',
        spkiBase64: 'nope',
        release: true,
      ),
      isTrue,
    );
    expect(
      tlsHostAllowed(
        host: 'kurye.dijigoo.com',
        issuer: 'CN=WE1, O=Google Trust Services, C=US',
        spkiBase64: 'rotated-leaf',
        release: true,
      ),
      isTrue,
    );
    expect(
      tlsHostAllowed(
        host: 'kurye.dijigoo.com',
        issuer: 'CN=R10, O=Let\'s Encrypt',
        spkiBase64: 'mitm',
        release: true,
      ),
      isFalse,
    );
    expect(
      tlsHostAllowed(
        host: 'kurye.dijigoo.com',
        issuer: 'CN=R10, O=Let\'s Encrypt',
        spkiBase64: kDijigooLeafSpki,
        release: true,
      ),
      isTrue,
    );
    expect(
      tlsHostAllowed(
        host: 'kurye.dijigoo.com',
        issuer: 'CN=R10',
        spkiBase64: 'mitm',
        release: false,
      ),
      isTrue,
    );
  });

  test('TLS_PINS sözdizimi host|pin;host|pin', () {
    final parsed = parseTlsPins(
      'osrm.dijigoo.internal|abc123;kurye.dijigoo.com|RoH/tTkvQyCBlabxTx57QdBhf05SP5K2Hb5J9zzMX6I=',
    );
    expect(parsed['osrm.dijigoo.internal'], {'abc123'});
    expect(kGtsCaPins, hasLength(4));
    expect(kGtsCaPins.toSet(), hasLength(4));
  });
}
