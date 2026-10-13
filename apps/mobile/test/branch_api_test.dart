import 'package:dijigoo_kurye/api/agency_client.dart';
import 'package:dijigoo_kurye/api/agency_models.dart';
import 'package:dijigoo_kurye/api/branch_models.dart';
import 'package:dijigoo_kurye/scan_router.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DTO parsing (swagger/branch.yaml şekli)', () {
    test('BranchDashboard KPI ve kurye listesini okur', () {
      final d = BranchDashboard.fromJson({
        'branch': {'id': 'b1', 'name': 'Kadıköy Şube'},
        'couriers': {
          'active': 3,
          'total': 5,
          'byStatus': {'ACTIVE': 3, 'BREAK': 1, 'OFFLINE': 1},
        },
        'kpis': {
          'todayToDeliver': 42,
          'deliveredToday': 19,
          'cancelledToday': 2,
          'pending': 6,
          'returnToCenter': 3,
          'urgent': 1,
        },
        'approvals': {'handover': 4, 'returns': 2},
        'courierList': [
          {
            'id': 'c1',
            'name': 'Ali Can',
            'code': 'KRY-1',
            'liveStatus': 'BREAK',
            'lastSeenAt': '2026-10-12T09:30:00.000Z',
            'holdingCount': 12,
            'overdueCount': 2,
          },
        ],
        'generatedAt': '2026-10-12T10:00:00.000Z',
      });
      expect(d.branchName, 'Kadıköy Şube');
      expect(d.todayToDeliver, 42);
      expect(d.deliveredToday, 19);
      expect(d.returnToCenter, 3);
      expect(d.couriersActive, 3);
      expect(d.couriersTotal, 5);
      expect(d.approvalsHandover, 4);
      expect(d.courierList.single.liveStatus, 'BREAK');
      expect(d.courierList.single.overdueCount, 2);
      expect(d.generatedAt, isNotNull);
    });

    test('BranchShipmentRow aşama, kabul bekleyen kurye ve randevuyu okur', () {
      final queued = BranchShipmentRow.fromJson({
        'shipmentId': 's1',
        'shipmentNumber': 'JD1',
        'stage': 'IN_QUEUE',
        'priority': 'HIGH',
        'late': true,
        'courier': null,
        'handover': {'courierName': 'Mert Demir', 'kind': 'HANDOVER'},
        'window': {'start': '2026-10-12T11:00:00.000Z', 'end': null},
      });
      expect(queued.stage, BranchStage.inQueue);
      expect(queued.highPriority, isTrue);
      expect(queued.late, isTrue);
      expect(queued.courierName, 'Mert Demir');
      expect(queued.booked, isTrue);

      final field = BranchShipmentRow.fromJson({
        'shipmentId': 's2',
        'shipmentNumber': 'JD2',
        'stage': 'IN_DISTRIBUTION',
        'courier': {'id': 'c1', 'name': 'Ali Can', 'code': 'K1'},
        'handover': null,
        'window': null,
      });
      expect(field.stage, BranchStage.inDistribution);
      expect(field.courierName, 'Ali Can');
      expect(field.booked, isFalse);
    });

    test('CountsData açık sayımı ve yetkiyi okur', () {
      final data = CountsData.fromJson({
        'capabilities': {'operate': true, 'manage': false},
        'reasonCodes': ['MISCOUNT', 'LOSS'],
        'warehouses': [
          {'id': 'w1', 'code': 'DP', 'name': 'Depo'},
        ],
        'openCount': {
          'id': 'k1',
          'number': 'SAY-1',
          'statusCode': 'REVIEW',
          'warehouse': {'id': 'w1', 'name': 'Depo'},
        },
        'counts': <Object>[],
      });
      expect(data.capabilities.operate, isTrue);
      expect(data.capabilities.manage, isFalse);
      expect(data.reasonCodes, ['MISCOUNT', 'LOSS']);
      expect(data.openCount?.open, isTrue);
      expect(data.openCount?.scannable, isFalse);
    });

    test('CountLine farkı hesaplar; adet yoksa sayı uydurmaz', () {
      final short = CountLine.fromJson({
        'id': 'l1',
        'productName': 'POS',
        'expectedQuantity': '12',
        'countedQuantity': 10,
      });
      expect(short.difference, -2);
      final unknown = CountLine.fromJson({'id': 'l2', 'name': 'SIM'});
      expect(unknown.expected, isNull);
      expect(unknown.difference, isNull);
    });

    test('yetki alanı gelmezse düğmeler kapalı kalır', () {
      final c = BranchCapabilities.fromJson(null);
      expect(c.operate, isFalse);
      expect(c.manage, isFalse);
    });
  });

  group('ScanRouter', () {
    test('kodu kırpar ve bağlamın işlemine yönlendirir', () async {
      final router = ScanRouter();
      final seen = <String>[];
      router
        ..register(ScanContext.count, (code) async {
          seen.add('count:$code');
          return const ScanOutcome.ok('Sayıldı');
        })
        ..register(ScanContext.dispatch, (code) async {
          seen.add('dispatch:$code');
          return const ScanOutcome.ok('Eklendi');
        });
      expect((await router.handle(ScanContext.count, '  ABC \n')).ok, isTrue);
      await router.handle(ScanContext.dispatch, 'XYZ');
      expect(seen, ['count:ABC', 'dispatch:XYZ']);
    });

    test('boş kod ve kayıtsız bağlam reddedilir', () async {
      final router = ScanRouter();
      expect(
        (await router.handle(ScanContext.count, '   ')).tone,
        ScanTone.bad,
      );
      expect((await router.handle(ScanContext.count, 'A')).tone, ScanTone.bad);
    });

    test('sunucu reddi ve ağ hatası fırlamaz, sonuç olarak döner', () async {
      final router = ScanRouter()
        ..register(ScanContext.stockIn, (_) async {
          throw AgencyApiException(
            'SHIPMENT_NOT_FOUND',
            statusCode: 404,
            serverMessage: 'Gönderi bulunamadı.',
          );
        })
        ..register(ScanContext.lookup, (_) async => throw StateError('ağ'));
      final rejected = await router.handle(ScanContext.stockIn, 'A');
      expect(rejected.tone, ScanTone.bad);
      expect(rejected.title, 'Gönderi bulunamadı.');
      expect((await router.handle(ScanContext.lookup, 'A')).tone, ScanTone.bad);
    });
  });

  group('AgencyPortalApi (branch-guide)', () {
    test('kurye eğitimleri targetType=COURIER ile istenir', () async {
      Map<String, dynamic>? query;
      final dio = Dio(BaseOptions(baseUrl: 'http://agency.test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            query = options.queryParameters;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': {
                    'targetType': 'COURIER',
                    'trainings': [
                      {
                        'id': 't1',
                        'title': 'Kart teslim kuralları',
                        'isMandatory': true,
                        'status': 'PUBLISHED',
                        'editable': true,
                        'stats': {'learners': 8, 'completed': 5},
                      },
                    ],
                  },
                },
              ),
            );
          },
        ),
      );
      final rows = await AgencyPortalApi(dio).fetchManagedTrainings();
      expect(query?['targetType'], 'COURIER');
      expect(rows.single.learners, 8);
      expect(rows.single.completed, 5);
    });

    test('bildirim okundu Idempotency-Key ile gider', () async {
      String? key;
      final dio = Dio(BaseOptions(baseUrl: 'http://agency.test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            key = options.headers['Idempotency-Key'] as String?;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {'success': true, 'data': <String, dynamic>{}},
              ),
            );
          },
        ),
      );
      await AgencyPortalApi(dio).markNotificationRead('n1');
      expect(key?.length, greaterThanOrEqualTo(8));
    });

    test('girişte kalan deneme ve kilit süresi error içinden okunur', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://agency.test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 423,
                  data: {
                    'success': false,
                    'error': {
                      'code': 'ACCOUNT_TEMPORARILY_LOCKED',
                      'remainingAttempts': 0,
                      'lockedUntil': '2026-10-13T09:15:00.000Z',
                    },
                  },
                ),
                type: DioExceptionType.badResponse,
              ),
            );
          },
        ),
      );
      AgencyApiException? error;
      try {
        await AgencyPortalApi(dio).login(email: 'a@b.co', password: 'x');
      } on AgencyApiException catch (e) {
        error = e;
      }
      expect(error?.code, 'ACCOUNT_TEMPORARILY_LOCKED');
      expect(error?.remainingAttempts, 0);
      expect(error?.lockedUntil, DateTime.utc(2026, 10, 13, 9, 15));
    });
  });
}
