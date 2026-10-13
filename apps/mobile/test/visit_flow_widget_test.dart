import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dijigoo_kurye/api/client.dart';
import 'package:dijigoo_kurye/api/panel_client.dart';
import 'package:dijigoo_kurye/l10n.dart';
import 'package:dijigoo_kurye/screens/mistakes_screen.dart';
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
