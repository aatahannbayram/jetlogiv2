import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dijigoo_kurye/api/client.dart';
import 'package:dijigoo_kurye/api/panel_client.dart';
import 'package:dijigoo_kurye/l10n.dart';
import 'package:dijigoo_kurye/screens/account_more_screens.dart';
import 'package:dijigoo_kurye/screens/account_screens.dart';
import 'package:dijigoo_kurye/screens/custody_history_screen.dart';
import 'package:dijigoo_kurye/screens/join_screens.dart';
import 'package:dijigoo_kurye/screens/mistakes_screen.dart';
import 'package:dijigoo_kurye/screens/report_screen.dart';
import 'package:dijigoo_kurye/screens/result_screen.dart';
import 'package:dijigoo_kurye/screens/return_screen.dart';
import 'package:dijigoo_kurye/screens/wizard_screen.dart';
import 'package:dijigoo_kurye/session.dart';
import 'package:dijigoo_kurye/theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _writes = <RequestOptions>[];

Dio _dio() {
  final requirements =
      (jsonDecode(
            File('test/fixtures/pluxee_requirements.json').readAsStringSync(),
          ) as Map)['data']
          as Map;
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        void ok(Map data) => handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': data},
          ),
        );
        final path = options.path;
        if (options.method != 'GET' && !path.contains('/courier-auth/')) {
          _writes.add(options);
        }
        if (path.contains('/courier-auth/login')) {
          return ok({
            'courier': {'id': 'c-1', 'courierCode': 'DGC-1', 'fullName': 'A'},
          });
        }
        if (path.endsWith('/requirements')) return ok(requirements);
        if (path.endsWith('/courier-consents')) {
          return ok({
            'items': [
              {
                'definitionId': 'def-1',
                'versionId': 'ver-1',
                'code': 'KVKK_AYDINLATMA',
                'mode': 'ACKNOWLEDGEMENT',
                'isRequired': true,
                'title': 'KVKK Aydınlatma Metni',
                'content': 'Kişisel verileriniz başvurunuz için işlenir.',
                'version': '1.0',
                'contentHash': 'a' * 64,
              },
            ],
          });
        }
        if (path.endsWith('/check-phone')) return ok({'canApply': true});
        if (path.endsWith('/courier-applications')) {
          return ok({'applicationNumber': 'DGO-20261013-TEST'});
        }
        if (path.startsWith('/courier-documents/') && options.method == 'GET') {
          return ok({
            'documentPackage': {
              'documents': [
                {
                  'id': 'd-1',
                  'titleTr': 'Kimlik',
                  'instructionsTr': 'Kimliğin iki yüzünü de çek.',
                  'isRequired': true,
                  'status': 'PENDING',
                  'definition': {'captureMode': 'FRONT_BACK'},
                  'parts': [],
                },
                {
                  'id': 'd-2',
                  'titleTr': 'Ehliyet',
                  'isRequired': false,
                  'status': 'APPROVED',
                  'definition': {'captureMode': 'SINGLE_FILE'},
                },
              ],
            },
          });
        }
        if (path.endsWith('/courier-profile/summary')) {
          return ok({
            'courier': {
              'fullName': 'Demo Kurye Çankaya',
              'courierCode': 'DGC-2026-E60C2E4E',
              'tier': 'BRONZE',
            },
            'stats': {
              'totalDelivered': 42,
              'successRate': 87.5,
              'last30Delivered': 30,
              'last30Failed': 4,
            },
            'badges': [
              {
                'code': 'ON_TIME',
                'earned': false,
                'progress': 30,
                'target': 50,
              },
              {
                'code': 'DOCUMENT_ACCURACY',
                'earned': true,
                'progress': 50,
                'target': 50,
              },
              {
                'code': 'TRAINING_LEADER',
                'earned': false,
                'progress': 0,
                'target': 5,
              },
            ],
          });
        }
        if (path.endsWith('/courier-profile/change-requests') &&
            options.method == 'GET') {
          return ok({
            'requests': [
              {
                'id': 'q-1',
                'changeType': 'VEHICLE',
                'status': 'APPROVED',
                'createdAt': '2026-10-12T09:00:00.000Z',
              },
            ],
          });
        }
        if (path.endsWith('/courier-profile')) {
          return ok({
            'courier': {
              'vehicleType': 'MOTORCYCLE',
              'workModel': 'FULL_TIME',
              'companyStatus': 'NO_COMPANY',
              'city': {'id': 7, 'name': 'Ankara'},
              'district': {'id': 71, 'name': 'Çankaya'},
            },
          });
        }
        if (path.endsWith('/courier-shifts')) {
          return ok({
            'items': [
              {
                'status': 'CLOSED',
                'startedAt': '2026-10-12T06:00:00.000Z',
                'endedAt': '2026-10-12T15:10:00.000Z',
                'workedMinutes': 505,
                'breakMinutes': 45,
              },
            ],
            'summary': {'shiftCount': 1, 'workedMinutes': 505},
          });
        }
        if (path.endsWith('/courier-my-contracts')) {
          return ok({
            'consents': [
              {
                'code': 'KVKK',
                'titleTr': 'KVKK Aydınlatma Metni',
                'contentTr': 'Kişisel verileriniz…',
                'decision': 'ACKNOWLEDGED',
                'accepted': true,
              },
            ],
          });
        }
        if (path.endsWith('/evidence') && options.method == 'GET') {
          return ok({
            'evidences': [
              {
                'id': 'e-9',
                'evidenceType': 'PHOTO',
                'mimeType': 'image/jpeg',
                'capturedAt': '2026-10-13T09:00:00.000Z',
                'deliveryAttemptId': null,
              },
              {
                'id': 'e-8',
                'evidenceType': 'SIGNATURE',
                'mimeType': 'image/png',
                'capturedAt': '2026-10-13T08:50:00.000Z',
                'deliveryAttemptId': 'a-1',
              },
            ],
          });
        }
        if (path.endsWith('/courier-availability')) {
          return ok({
            'days': [
              for (final i in [1, 2, 3, 4, 5])
                {
                  'dayIndex': i,
                  'enabled': true,
                  'ranges': [
                    {'start': '09:00', 'end': '18:00'},
                  ],
                },
            ],
            'exceptions': [],
          });
        }
        if (path.endsWith('/courier-custody/history')) {
          return ok({
            'items': [
              {
                'direction': 'IN',
                'shipmentNumber': '334',
                'recipientName': 'Ulus Kafe',
                'counterparty': {'name': 'DEMO-ANKARA Acentesi'},
                'status': 'ACCEPTED',
                'completedAt': '2026-10-13T11:10:00.000Z',
              },
              {
                'direction': 'OUT',
                'shipmentNumber': '342',
                'recipientName': 'Seğmenler Köfteci',
                'counterparty': {'name': 'DEMO-ANKARA Acentesi'},
                'status': 'PENDING',
                'updatedAt': '2026-10-13T10:53:00.000Z',
              },
            ],
          });
        }
        if (path.endsWith('/reports') && options.method == 'GET') {
          return ok({
            'reports': [
              {
                'id': 'r-1',
                'reportType': 'DAMAGE',
                'note': 'Koli ezik teslim alındı.',
                'submittedAt': '2026-10-13T09:30:00.000Z',
                'counterpartSignature': {'signerName': 'Bora Kaya'},
              },
            ],
          });
        }
        if (path.contains('delivery-reasons')) {
          return ok({
            'failed': [
              {'code': '9330', 'name': 'Sticker Asılmasını Kabul Etmiyor'},
              {'code': '9335', 'name': 'Kalıcı Olarak Kapalı'},
            ],
          });
        }
        if (path.endsWith('/courier-mistakes')) {
          return ok({
            'items': [
              {
                'evidenceId': 'e-1',
                'shipmentNumber': '323',
                'requirementLabel': 'İşletme dış cephe ve tabela',
                'requirementHint': 'İşletme adı okunacak şekilde çekin.',
                'reasonCode': 'SIGN_NOT_VISIBLE',
                'reason': 'Tabela kadrajda yok.',
                'capturedAt': '2026-10-13T09:00:00.000Z',
                'acknowledgedAt': null,
              },
            ],
            'unacknowledged': 1,
            'score': {
              'photos': 24,
              'rejected': 1,
              'score': 91.7,
              'band': 'WATCH',
              'minPhotos': 10,
              'windowDays': 30,
            },
          });
        }
        if (options.method == 'GET' && path.endsWith('/courier-tasks')) {
          return ok({
            'tasks': [
              {
                'id': 's-9',
                'shipmentNumber': '323',
                'statusCode': '4020',
                'recipientName': 'Atakule Pide Lahmacun',
                'destination': {
                  'address': 'Oran Mah. Demo Test Sok. No:8',
                  'latitude': '39.91',
                  'longitude': '32.859',
                },
              },
            ],
            'summary': {'total': 1, 'created': 0, 'planned': 1, 'today': 1},
          });
        }
        ok(const {});
      },
    ),
  );
  return dio;
}

final _boundary = GlobalKey();

Future<void> _shot(WidgetTester tester, String name) async {
  final out = Platform.environment['JETLOGI_SCREENSHOTS'];
  if (out == null) return;
  await tester.runAsync(() async {
    final render =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(out).create(recursive: true);
    await File('$out/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<SessionController> _open(
  WidgetTester tester,
  Widget screen, {
  bool dark = true,
}) async {
  tester.view.physicalSize = const Size(390, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  _writes.clear();
  final dio = _dio();
  final session = SessionController(
    panel: PanelApi(dio),
    api: MobileApi(dio: dio),
  );
  await tester.runAsync(
    () => session.loginWithPanel(identifier: 'a@b.com', password: 'x'),
  );
  session.darkModeUi = dark;
  Dg.dark = dark;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sessionProvider.overrideWith((ref) => session)],
      child: L10nScope(
        l10n: const L10n('tr'),
        child: MaterialApp(
          theme: Dg.theme(),
          locale: const Locale('tr'),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('tr')],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: RepaintBoundary(key: _boundary, child: child!),
          ),
          home: screen,
        ),
      ),
    ),
  );
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return session;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Map<String, dynamic> _body(String suffix) => Map<String, dynamic>.from(
  _writes.lastWhere((o) => o.path.endsWith(suffix)).data as Map,
);

void main() {
  setUpAll(() async {
    final manifest = jsonDecode(
      await rootBundle.loadString('FontManifest.json'),
    ) as List<dynamic>;
    for (final entry in manifest) {
      final loader = FontLoader(entry['family'] as String);
      for (final font in entry['fonts'] as List<dynamic>) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });

  testWidgets('ziyaret: 3 fotoğraf kontrol listesiyle, anket, gönder', (
    tester,
  ) async {
    await _open(tester, const WizardScreen(taskId: 's-9'));
    expect(find.text('İşletme dış cephe ve tabela'), findsOneWidget);
    expect(find.text('Adım 1/4  ·  Atakule Pide Lahmacun'), findsOneWidget);
    await _shot(tester, 'visit-photo-empty');

    // Fotoğraf çekilmeden ilerlenmez.
    await _tap(tester, find.text('Devam'));
    expect(find.text('Önce fotoğrafı çek.'), findsOneWidget);

    await _tap(tester, find.text('Fotoğraf çek'));
    expect(find.text('İşletme adı / tabela okunuyor'), findsOneWidget);
    // Kontrol listesi işaretlenmeden gönderilmez.
    await _tap(tester, find.text('Devam'));
    expect(find.text('Listedeki her maddeyi işaretle.'), findsOneWidget);
    expect(_writes, isEmpty);

    for (final item in [
      'İşletme adı / tabela okunuyor',
      'Fotoğraf doğru işletmenin önünde çekildi',
      'Görüntü net ve aydınlık',
    ]) {
      await _tap(tester, find.text(item));
    }
    await _shot(tester, 'visit-photo-checked');
    await _tap(tester, find.text('Devam'));
    expect(find.text('Yapıştırılan sticker (yakın plan)'), findsOneWidget);

    for (final items in [
      [
        'Sticker\'ın tamamı kadrajda',
        'Pluxee logosu okunuyor',
        'Sticker düz, kabarcıksız yapıştırıldı',
      ],
      [
        'Sticker\'ın yeri (kapı / kasa) görünüyor',
        'İşletme ve sticker aynı karede',
        'Sticker dışarıdan görünür konumda',
      ],
    ]) {
      await _tap(tester, find.text('Fotoğraf çek'));
      for (final item in items) {
        await _tap(tester, find.text(item));
      }
      await _tap(tester, find.text('Devam'));
    }

    expect(find.text('Pluxee Ziyaret Anketi'), findsOneWidget);
    expect(find.text('İptal nedeni'), findsNothing);
    await _shot(tester, 'visit-survey');
    // "Sticker yapıştırıldı mı?" beşinci evet/hayır sorusu.
    await _tap(tester, find.text('Hayır').at(4));
    expect(find.text('İptal nedeni'), findsOneWidget);
    await _tap(tester, find.text('Evet').at(4));
    expect(find.text('İptal nedeni'), findsNothing);

    // Tamamlanan ziyarette her soru yanıtlanmadan anket gönderilmez.
    await _tap(tester, find.text('Ziyareti gönder'));
    expect(find.text('Zorunlu soruların hepsini yanıtla.'), findsOneWidget);
    expect(_writes.where((o) => o.path.endsWith('/form')), isEmpty);
    await _tap(tester, find.text('Evet').at(0));
    await _tap(tester, find.text('Hayır').at(1));
    await _tap(tester, find.text('Evet').at(2));
    await _tap(tester, find.text('Hayır').at(3));

    await _tap(tester, find.text('Ziyareti gönder'));
    expect(find.byType(DeliveryResultScreen), findsOneWidget);
    expect(_body('/form')['values'], {
      'PLUXEE_MEMBER': true,
      'OTHER_MEAL_CARD': false,
      'APPLICATION_DONE': true,
      'STICKER_EXISTS': false,
      'STICKER_APPLIED': true,
    });
    expect(_body('/form')['status'], 'SUBMITTED');
    expect(_body('/finalize')['resultCode'], 'DELIVERED');
    expect(_body('/finalize').containsKey('reasonCode'), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('yapamadım: neden, tek fotoğraf, neden ankete taşınır', (
    tester,
  ) async {
    await _open(tester, const WizardScreen(taskId: 's-9'), dark: false);
    await _tap(tester, find.text('Ziyareti yapamadım'));
    expect(find.text('Neden yapamadın?'), findsOneWidget);
    await _tap(tester, find.text('Devam'));
    expect(find.text('Bir neden seç.'), findsOneWidget);
    await _tap(tester, find.text('Kalıcı Olarak Kapalı'));
    await _shot(tester, 'visit-fail-reason');
    await _tap(tester, find.text('Devam'));

    expect(
      find.text('Ziyaret kanıtı (işletme / kapalı kepenk)'),
      findsOneWidget,
    );
    await _tap(tester, find.text('Fotoğraf çek'));
    await _tap(
      tester,
      find.text('İşletme cephesi ya da kapalı kepenk görünüyor'),
    );
    await _tap(tester, find.text('Tabela veya kapı numarası okunuyor'));
    await _tap(tester, find.text('Devam'));

    // Neden ankette hazır seçili gelir.
    expect(find.text('İptal nedeni'), findsOneWidget);
    await _shot(tester, 'visit-fail-survey');
    await _tap(tester, find.text('Ziyareti gönder'));
    expect(find.byType(DeliveryResultScreen), findsOneWidget);
    expect(_body('/form')['values'], {
      'STICKER_APPLIED': false,
      'CANCEL_REASON': 'PERMANENTLY_CLOSED',
    });
    expect(_body('/finalize')['resultCode'], 'DELIVERY_FAILED');
    expect(_body('/finalize')['reasonCode'], '9335');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('"teslim edilemedi" girişi de ziyaret akışını nedenle açar', (
    tester,
  ) async {
    await _open(tester, const ReturnScreen(taskId: 's-9'));
    expect(find.text('Neden yapamadın?'), findsOneWidget);
    // Nedenler ekran açıldıktan sonra yüklenir.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Kalıcı Olarak Kapalı'), findsOneWidget);
    expect(find.text('Ziyareti yapabildim'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('müsaitlik: gün kapatılıp kaydedilir', (tester) async {
    await _open(tester, const AvailabilityScreen());
    expect(find.text('Pazartesi'), findsOneWidget);
    expect(find.text('Çalışmıyorum'), findsNWidgets(2));
    await _shot(tester, 'availability');
    // Cumartesi açılır, varsayılan saat gelir.
    await _tap(tester, find.byType(Switch).at(5));
    expect(find.text('Çalışmıyorum'), findsOneWidget);
    await _tap(tester, find.text('Kaydet'));
    final days = _body('/courier-availability')['days'] as List;
    expect(days, hasLength(7));
    expect(days[6], {
      'dayIndex': 6,
      'enabled': true,
      'ranges': [
        {'start': '09:00', 'end': '18:00'},
      ],
    });
    expect((days[0] as Map)['enabled'], isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('tutanak, zimmet geçmişi ve şifre ekranları açılır', (
    tester,
  ) async {
    await _open(tester, const ReportScreen(taskId: 's-9'));
    expect(find.text('Önceki tutanaklar'), findsOneWidget);
    // İmzasız ve adsız gönderilmez.
    await _tap(tester, find.text('Tutanağı gönder'));
    expect(find.text('Karşı tarafın adını yaz.'), findsOneWidget);
    await _shot(tester, 'report');

    await _open(tester, const CustodyHistoryScreen());
    expect(find.text('Aldın · 334'), findsOneWidget);
    expect(find.text('Verdin · 342'), findsOneWidget);
    await _shot(tester, 'custody-history');

    await _open(tester, const PasswordScreen());
    await _tap(tester, find.text('Şifreyi değiştir').last);
    expect(_writes, isEmpty);
    await _shot(tester, 'password');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('hesap ekranları: durum, bilgi güncelleme, vardiya, sözleşme', (
    tester,
  ) async {
    await _open(tester, const ProfileSummaryScreen());
    expect(find.text('Bronz'), findsOneWidget);
    expect(find.text('%87,5'), findsOneWidget);
    // Eğitim rozeti gösterilmez.
    expect(find.text('Eğitim'), findsNothing);
    await _shot(tester, 'summary');

    await _open(tester, const ShiftHistoryScreen());
    expect(find.text('8 sa 25 dk'), findsOneWidget);
    await _shot(tester, 'shift-history');

    await _open(tester, const ContractsScreen());
    expect(find.text('KVKK Aydınlatma Metni'), findsOneWidget);
    expect(find.text('Okudun'), findsOneWidget);

    await _open(tester, const ProfileChangeScreen());
    expect(find.text('Önceki taleplerim'), findsOneWidget);
    await _shot(tester, 'edit-info');
    await _tap(tester, find.text('Otomobil'));
    await _tap(tester, find.text('Kaydet').first);
    expect(_body('/change-requests'), {
      'changeType': 'VEHICLE',
      'requestedData': {'vehicleType': 'CAR'},
    });
    // Adres eksikken gönderilmez.
    await _tap(tester, find.text('Kaydet').last);
    expect(find.text('İl, ilçe seç ve adresi yaz.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('görev fotoğrafları: yalnız bağlanmamış olan silinebilir', (
    tester,
  ) async {
    await _open(tester, const TaskEvidenceScreen(taskId: 's-9'));
    expect(find.text('Sil'), findsOneWidget);
    await _shot(tester, 'task-photos');
    await _tap(tester, find.text('Sil'));
    expect(_writes.single.method, 'DELETE');
    expect(_writes.single.path, '/courier-tasks/s-9/evidence/e-9');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('evrak yükleme: bağlantı, ön yüz fotoğrafı, gönder', (
    tester,
  ) async {
    await _open(tester, const DocumentPortalScreen());
    await _tap(tester, find.text('Devam'));
    expect(
      find.text(
        'Bağlantı tanınmadı. E-postadaki bağlantının tamamını yapıştır.',
      ),
      findsOneWidget,
    );
    await tester.enterText(
      find.byType(TextField),
      'https://jetdiji.com/kurye-belgeleri/pub_1?token=tok',
    );
    await _tap(tester, find.text('Devam'));
    expect(find.text('Kimlik'), findsOneWidget);
    expect(find.text('Ön yüz · Bekleniyor'), findsOneWidget);
    expect(find.text('Arka yüz · Bekleniyor'), findsOneWidget);
    // Onaylanmış belge yeniden yüklenemez.
    expect(find.text('Fotoğrafını çek'), findsNWidgets(2));
    await _shot(tester, 'docs');
    await _tap(tester, find.text('Fotoğrafını çek').first);
    final upload = _writes.single;
    expect(upload.path, '/courier-documents/pub_1/requests/d-1/upload');
    expect(upload.queryParameters['side'], 'FRONT');
    await _tap(tester, find.text('Evrakları gönder'));
    expect(_writes.last.path, '/courier-documents/pub_1/submit');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('başvuru: zorunlu metin okunmadan gönderilmez', (tester) async {
    await _open(tester, const ApplicationScreen());
    await _shot(tester, 'apply');
    // Onay metinleri uzun formun en altında.
    await tester.scrollUntilVisible(
      find.text('KVKK Aydınlatma Metni'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await _tap(tester, find.text('Başvuruyu gönder'));
    expect(find.text('Boş alanları doldur ve seçimleri yap.'), findsOneWidget);
    // Metin açılır; kısa olduğu için sonu görünür, "Okudum" açılır.
    await _tap(tester, find.text('Oku'));
    expect(find.text('Okudum'), findsOneWidget);
    await _tap(tester, find.text('Okudum'));
    expect(find.text('KVKK Aydınlatma Metni'), findsOneWidget);
    expect(_writes, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('Hatalarım: neden, doğrusu ve Okudum', (tester) async {
    await _open(tester, const MistakesScreen());
    expect(find.text('Tabela görünmüyor'), findsOneWidget);
    expect(find.text('Tabela kadrajda yok.'), findsOneWidget);
    expect(find.text('92'), findsOneWidget);
    expect(find.text('Dikkat'), findsOneWidget);
    await _shot(tester, 'mistakes');
    await _tap(tester, find.text('Okudum'));
    expect(find.text('Okundu'), findsOneWidget);
    expect(_writes.single.path, '/courier-mistakes/e-1/acknowledge');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
  });
}
