import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dijigoo_kurye/api/agency_client.dart';
import 'package:dijigoo_kurye/l10n.dart';
import 'package:dijigoo_kurye/screens/sube_more_screens.dart';
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

Map<String, Object?> _shipment(String no, String name, String district) => {
  'shipmentId': 'id-$no',
  'shipmentNumber': no,
  'stage': 'AWAITING_COURIER',
  'status': '4010',
  'recipientName': name,
  'district': district,
  'addressLine': 'Demo Test Sok. No:$no',
  'product': 'Pluxee Sticker Dağıtımı',
};

Map<String, Object?> _courier(String id, String name, String district) => {
  'shipmentCount': 8,
  'courier': {
    'id': id,
    'fullName': name,
    'districtName': district,
    'vehicleType': 'MOTORCYCLE',
  },
};

/// Yanıt biçimleri 2026-10-13'te preprod'dan alınanlarla aynı.
Dio _dio() {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        void ok(Object data) => handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': data},
          ),
        );
        final path = options.path;
        if (options.method != 'GET') _writes.add(options);
        if (path.endsWith('/branch/preparation')) {
          return ok({
            'kpis': {
              'awaitingCourier': 2,
              'preparedToday': 30,
              'dispatchedToday': 1,
            },
            'rows': [
              _shipment('324', 'Ulus Kafe', 'Çankaya'),
              _shipment('325', 'Çubuk Pizza', 'Çankaya'),
            ],
          });
        }
        if (path.endsWith('/print-rows')) {
          return ok([
            {
              'primaryBarcode': '324',
              'recipientName': 'Ulus Kafe',
              'customer': {'name': 'PLUXEE'},
              'destination': {'districtName': 'Çankaya', 'cityName': 'Ankara'},
            },
          ]);
        }
        if (path.endsWith('/agency/couriers')) {
          return ok({
            'items': [
              _courier('c-1', 'Demo Kurye Çankaya', 'Çankaya'),
              _courier('c-2', 'Demo Kurye Keçiören', 'Keçiören'),
            ],
          });
        }
        if (path.endsWith('/agency/regions')) {
          return ok({
            'items': [
              for (final d in ['Altındağ', 'Çankaya', 'Keçiören'])
                {
                  'region': {
                    'name': 'DEMO Ankara / $d',
                    'geography': {
                      'districts': [d],
                    },
                  },
                },
            ],
          });
        }
        if (path.endsWith('/agency/warehouses')) return ok({'items': []});
        if (path.endsWith('/compliance/cards')) {
          return ok({
            'card': {
              'token': 'JDC1.payload.imza',
              'expiresAt': '2027-10-13T00:00:00.000Z',
            },
            'replayed': false,
          });
        }
        if (path.endsWith('/branch/courier-shifts')) {
          return ok({
            'couriers': [
              {
                'courier': {'id': 'c-1', 'fullName': 'Demo Kurye Çankaya'},
                'shifts': [
                  {
                    'id': 'sh-1',
                    'startedAt': '2026-10-13T06:00:00.000Z',
                    'endedAt': null,
                  },
                ],
              },
            ],
          });
        }
        if (path.endsWith('/branch/announcements')) {
          return ok({
            'announcements': [
              {
                'id': 'n-1',
                'title': 'Yeni çekim kuralı',
                'body': 'Tabela kadrajda olsun.',
                'announcement': {
                  'id': 'a-1',
                  'requiresAck': true,
                  'acknowledgedAt': null,
                },
              },
            ],
            'published': [
              {
                'id': 'a-9',
                'title': 'Cumartesi mesaisi',
                'status': 'PUBLISHED',
                'publishedAt': '2026-10-12T09:00:00.000Z',
                'stats': {'recipients': 3, 'read': 2, 'acknowledged': 1},
              },
            ],
          });
        }
        ok(const <String, Object?>{});
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

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
}

Future<SessionController> _open(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  _writes.clear();
  final session = SessionController(agency: AgencyPortalApi(_dio()));
  session.darkModeUi = true;
  Dg.dark = true;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sessionProvider.overrideWith((ref) => session)],
      child: L10nScope(
        l10n: const L10n('tr'),
        child: MaterialApp(
          key: ValueKey(screen.runtimeType),
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
  await _settle(tester);
  return session;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await _settle(tester);
}

void main() {
  setUpAll(() async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json'))
            as List<dynamic>;
    for (final entry in manifest) {
      final loader = FontLoader(entry['family'] as String);
      for (final font in entry['fonts'] as List<dynamic>) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });

  testWidgets('hazırlık listesi: seçilenler için yazdır düğmesi çıkar', (
    tester,
  ) async {
    await _open(tester, const SubePrepScreen());
    expect(find.text('324 · Ulus Kafe'), findsOneWidget);
    expect(find.textContaining('etiket yazdır'), findsNothing);
    await _tap(tester, find.text('324 · Ulus Kafe'));
    expect(find.text('1 etiket yazdır'), findsOneWidget);
    await _shot(tester, 'sube-prep');
    // Yazıcı adresi yokken sunucuya da gidilmez.
    await _tap(tester, find.text('1 etiket yazdır'));
    expect(
      find.text('Önce Etiket ekranından yazıcı adresini gir.'),
      findsOneWidget,
    );
    expect(_writes, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('duyuru yönetimi: okudum ve arşivle', (tester) async {
    await _open(tester, const SubeAnnouncementsScreen());
    expect(find.text('Yeni çekim kuralı'), findsOneWidget);
    expect(find.text('3 kişi · 2 okudu · 1 onayladı'), findsOneWidget);
    await _shot(tester, 'sube-announcements');
    await _tap(tester, find.text('Okudum, anladım'));
    expect(_writes.last.path, '/branch/announcements/a-1/ack');
    await _tap(tester, find.text('Arşivle'));
    expect(_writes.last.path, '/branch/announcements/a-9/archive');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('vardiya düzeltme nedensiz kaydedilmez', (tester) async {
    await _open(tester, const SubeShiftFixScreen());
    await _tap(tester, find.text('Demo Kurye Çankaya'));
    expect(find.text('Neden düzeltiyorsun?'), findsOneWidget);
    await _shot(tester, 'sube-shift-fix');
    await _tap(tester, find.text('Kaydet'));
    expect(find.text('Nedenini yaz.'), findsOneWidget);
    expect(_writes, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('kartlar ve acente bilgileri', (tester) async {
    await _open(tester, const SubeCardsScreen());
    expect(find.text('Kart okut ve doğrula'), findsOneWidget);
    await _tap(tester, find.text('Demo Kurye Keçiören'));
    expect(find.text('13.10 tarihine kadar geçerli'), findsOneWidget);
    expect(_writes.single.data, {'ownerType': 'COURIER', 'ownerId': 'c-2'});
    await _shot(tester, 'sube-card');

    await _open(tester, const SubeAgencyInfoScreen());
    expect(find.text('Hizmet bölgeleri'), findsOneWidget);
    expect(find.text('Altındağ'), findsOneWidget);
    expect(find.text('Tanımlı depo yok.'), findsOneWidget);
    await _shot(tester, 'sube-agency');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
  });
}
