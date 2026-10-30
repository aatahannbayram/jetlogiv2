import 'package:dijigoo_kurye/api/agency_client.dart';
import 'package:dijigoo_kurye/api/branch_models.dart';
import 'package:dijigoo_kurye/api/branch_proposed_models.dart';
import 'package:dijigoo_kurye/branch_workspace.dart';
import 'package:dijigoo_kurye/data/outbox.dart';
import 'package:dijigoo_kurye/l10n.dart';
import 'package:dijigoo_kurye/screens/sube_eod_screen.dart';
import 'package:dijigoo_kurye/screens/sube_partner_screens.dart';
import 'package:dijigoo_kurye/session.dart';
import 'package:dijigoo_kurye/theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Swagger'da olmayan, docs/15'te önerilen uçlar: şekil, istek gövdesi ve
/// bayrak kapalıyken canlıda hiç istek gitmemesi.

final _requests = <RequestOptions>[];

AgencyPortalApi _api([Object? Function(RequestOptions o)? respond]) {
  final dio = Dio(BaseOptions(baseUrl: 'http://branch.test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        _requests.add(options);
        handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': respond?.call(options) ?? <String, Object>{},
            },
          ),
        );
      },
    ),
  );
  return AgencyPortalApi(dio);
}

BranchWorkspace _workspace({bool demo = false, AgencyPortalApi? api}) {
  var n = 0;
  return BranchWorkspace(
    outbox: OutboxStore(),
    api: api ?? _api(),
    onChanged: () {},
    newId: () => 'id-${++n}',
  )..demo = demo;
}

void main() {
  setUp(_requests.clear);

  group('önerilen şekiller (docs/15)', () {
    test('fatura: schemaReady false iken boş, true iken alanlar okunur', () {
      expect(
        parseInvoices({
          'schemaReady': false,
          'invoices': [
            {'id': 'x'},
          ],
        }),
        isEmpty,
      );
      final list = parseInvoices({
        'schemaReady': true,
        'invoices': [
          {
            'id': 'inv-1',
            'number': 'DGF-1',
            'period': '2026-10',
            'amount': 100,
            'vat': 20,
            'status': 'PAID',
            'dueAt': '2026-11-15T00:00:00Z',
            'pdfUrl': 'https://x.test/a.pdf',
            'lines': [
              {'label': 'Kart', 'quantity': 3, 'amount': 100},
            ],
          },
        ],
      });
      expect(list.single.number, 'DGF-1');
      expect(list.single.vat, 20);
      expect(list.single.pdfUrl, 'https://x.test/a.pdf');
      expect(list.single.lines.single.quantity, 3);
    });

    test('evrak kalemi geçerlilik ve dosya bağlantısını okur', () {
      final docs = BranchDocs.fromJson({
        'schemaReady': true,
        'contracts': [
          {
            'type': 'PARTNERSHIP',
            'status': 'SIGNED',
            'expiresAt': '2027-03-01T00:00:00Z',
            'fileUrl': 'https://x.test/p.pdf',
          },
        ],
        'documents': [
          {'type': 'IDENTITY', 'status': 'NOT_AVAILABLE'},
        ],
      });
      expect(docs.contracts.single.expiresAt, isNotNull);
      expect(docs.contracts.single.fileUrl, 'https://x.test/p.pdf');
      expect(docs.documents.single.fileUrl, isNull);
    });

    test('gün sonu: kapalı durum ve sıfır olmayan engeller', () {
      final eod = EndOfDayStatus.fromJson({
        'date': '2026-10-30',
        'status': 'OPEN',
        'canClose': false,
        'blockers': [
          {'code': 'RESULT_MISSING', 'count': 3},
          {'code': 'COUNT_OPEN', 'count': 0},
        ],
      });
      expect(eod.closed, isFalse);
      expect(eod.blockers.single.code, 'RESULT_MISSING');
      expect(EndOfDayStatus.fromJson({'status': 'CLOSED'}).closed, isTrue);
    });

    test('kurye profili: plaka, cihaz ve izinler; cihaz yoksa null', () {
      final p = CourierProfile.fromJson({
        'courierId': 'c-1',
        'plate': '06 ABC 123',
        'device': {
          'model': 'Pixel 8',
          'permissions': {'location': true, 'camera': false, 'x': 'y'},
        },
      });
      expect(p.plate, '06 ABC 123');
      expect(p.device!.permissions, {'location': true, 'camera': false});
      expect(
        CourierProfile.fromJson({'courierId': 'c-2', 'device': null}).device,
        isNull,
      );
    });

    test('stok, dağıtım planı ve ürün eşleştirme sonucu', () {
      expect(StockSummary.fromJson({'atCourier': 46}).atCourier, 46);
      final plans = DistributionPlan.listFrom({
        'items': [
          {'id': 'dp-1', 'date': '2026-11-02', 'expectedVolume': '120'},
          {'date': 'kimliksiz'},
        ],
      });
      expect(plans.single.expectedVolume, 120);
      final r = ProductMatchResult.fromJson({
        'matched': 2,
        'failed': [
          {'shipmentId': 's-2', 'code': 'PRODUCT_ALREADY_MATCHED'},
        ],
      });
      expect(r.failed.single.code, 'PRODUCT_ALREADY_MATCHED');
    });
  });

  group('istek şekli', () {
    test('gün ve serbest aralık sorgu parametresi olarak gider', () async {
      final api = _api();
      await api.fetchDispatchBoard(day: DateTime(2026, 11, 2));
      await api.fetchDispatchBoard();
      await api.fetchPerformance(
        '7d',
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 15),
      );
      expect(_requests[0].queryParameters, {'date': '2026-11-02'});
      expect(_requests[1].queryParameters, isEmpty);
      expect(_requests[2].queryParameters, {
        'range': 'custom',
        'from': '2026-10-01',
        'to': '2026-10-15',
      });
    });

    test('yazma uçları gövde ve Idempotency-Key ile gider', () async {
      final api = _api();
      await api.closeEndOfDay(date: '2026-10-30', idempotencyKey: 'k1');
      await api.revokeCard(
        ownerType: 'COURIER',
        ownerId: 'c-1',
        reason: 'LOST',
        idempotencyKey: 'k2',
      );
      await api.renewCard(
        ownerType: 'COURIER',
        ownerId: 'c-1',
        idempotencyKey: 'k3',
      );
      await api.matchProducts(
        barcodeByShipment: {'s-1': 'PLX1'},
        idempotencyKey: 'k4',
      );
      expect(_requests.map((r) => r.path), [
        '/branch/end-of-day/close',
        '/branch/compliance/cards/revoke',
        '/branch/compliance/cards',
        '/branch/shipments/product-match',
      ]);
      expect(_requests[0].data, {'date': '2026-10-30'});
      expect(_requests[2].data, {
        'ownerType': 'COURIER',
        'ownerId': 'c-1',
        'renew': true,
      });
      expect(_requests[3].data, {
        'items': [
          {'shipmentId': 's-1', 'productBarcode': 'PLX1'},
        ],
      });
      expect(_requests.map((r) => r.headers['Idempotency-Key']), [
        'k1',
        'k2',
        'k3',
        'k4',
      ]);
    });

    test('davet: telefon +90 biçimine, plaka büyük harfe çevrilir', () async {
      final b = _workspace();
      expect(
        await b.inviteCourier(
          fullName: 'Ayşe Yılmaz',
          phone: '0 (555) 111 22 33',
          vehicleType: 'MOTORCYCLE',
          plate: '06 abc 123',
        ),
        isNull,
      );
      expect(_requests.single.path, '/agency/couriers/invitations');
      expect(_requests.single.data, {
        'fullName': 'Ayşe Yılmaz',
        'phone': '+905551112233',
        'vehicleType': 'MOTORCYCLE',
        'plate': '06 ABC 123',
      });
      expect(
        await b.inviteCourier(fullName: '', phone: '555', vehicleType: 'CAR'),
        isNotNull,
      );
      expect(_requests, hasLength(1));
    });
  });

  group('bayrak kapalı (canlı)', () {
    test('önerilen yükleyiciler canlıda istek atmaz', () async {
      final b = _workspace();
      expect(b.proposed(false), isFalse);
      await b.loadEndOfDay();
      await b.loadStockSummary();
      await b.loadDistributionPlans();
      await b.loadCourierProfile('c-1');
      await b.loadPerformance('7d', from: DateTime(2026), to: DateTime(2026));
      await b.setBoardDay(DateTime(2026, 1, 1));
      expect(_requests, isEmpty);
      expect(b.endOfDay, isNull);
      expect(b.stockSummary, isNull);
    });

    test('fatura listesi schemaReady false iken boş kalır', () async {
      final b = _workspace(
        api: _api((o) => {'schemaReady': false, 'invoices': <Object>[]}),
      );
      await b.loadInvoices();
      expect(_requests.single.path, '/branch/invoices');
      expect(b.invoices, isEmpty);
    });
  });

  group('demo', () {
    test('gün kapatılır, plan eklenir, eşleştirme sayılır', () async {
      final b = _workspace(demo: true);
      expect(b.proposed(false), isTrue);
      await b.loadEndOfDay();
      expect(b.endOfDay!.canClose, isTrue);
      expect(await b.closeEndOfDay(), isNull);
      expect(b.endOfDay!.closed, isTrue);

      await b.loadDistributionPlans();
      expect(
        await b.createDistributionPlan(
          date: DateTime(2026, 11, 3),
          district: '',
          expectedVolume: 10,
        ),
        isNotNull,
      );
      expect(
        await b.createDistributionPlan(
          date: DateTime(2026, 11, 3),
          district: 'Çankaya',
          expectedVolume: 40,
        ),
        isNull,
      );
      expect(b.distributionPlans!.first.district, 'Çankaya');
      expect(b.distributionPlans!.first.status, 'REQUESTED');

      expect(await b.matchProducts({'s-1': ' plx1 ', 's-2': ''}), isNull);
      expect(b.lastProductMatch!.matched, 1);
      expect(_requests, isEmpty);
    });
  });

  group('ekran', () {
    Future<void> open(WidgetTester tester, Widget screen) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = SessionController(agency: _api());
      session.branch.demo = true;
      await session.branch.refresh();
      Dg.dark = true;
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
                child: child!,
              ),
              home: screen,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('gün sonu: onaydan sonra gün kapandı görünür', (tester) async {
      await open(tester, const SubeEodScreen());
      await tester.scrollUntilVisible(
        find.byKey(const Key('eod-close')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('eod-close')));
      await tester.pumpAndSettle();
      expect(find.text('Gün kapatılsın mı?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('eod-close-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Gün kapatıldı'), findsOneWidget);
      expect(find.byKey(const Key('eod-close')), findsNothing);
      expect(_requests, isEmpty);
    });

    testWidgets('evrak ve dağıtım planlama: talep listeye düşer', (
      tester,
    ) async {
      await open(tester, const SubePartnerDocsScreen());
      expect(find.text('Merkez bağlantısı bekleniyor'), findsNothing);
      expect(find.textContaining('01.03.2027 tarihine kadar'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('plan-new')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Keçiören'), findsOneWidget);
      await tester.tap(find.byKey(const Key('plan-new')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('plan-district')), 'Mamak');
      await tester.enterText(find.byKey(const Key('plan-volume')), '75');
      await tester.tap(find.byKey(const Key('plan-send')));
      await tester.pumpAndSettle();
      expect(find.text('Talep gönderildi.'), findsOneWidget);
      expect(find.textContaining('Mamak'), findsOneWidget);
    });
  });
}
