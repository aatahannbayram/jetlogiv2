import 'package:dijigoo_kurye/api/panel_client.dart';
import 'package:dijigoo_kurye/api/panel_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixture shaped exactly like jetlogi-panel's real `GET courier-tasks`
/// response (verified by reading `courier-tasks/route.ts` in the panel
/// repo) — not our own `apps/api` `/v1/tasks` shape, see
/// docs/05-panel-entegrasyonu.md.
Map<String, dynamic> _taskRow({
  String id = 's-1',
  String statusCode = 'COURIER_ASSIGNED',
}) => {
  'id': id,
  'shipmentNumber': 'JLG-1001',
  'externalReference': 'EXT-1',
  'statusCode': statusCode,
  'statusReasonCode': null,
  'recipientName': 'Ahmet Yılmaz',
  'recipientPhone': '+905551112233',
  'destination': {
    'countryCode': 'TR',
    'cityCode': '20',
    'districtCode': '2001',
    'address': 'Cumhuriyet Cd. 1 · Güney · 20000',
    'latitude': '38.100000',
    'longitude': '29.000000',
    'geoPrecision': 'ROOFTOP',
    'usableForProximity': true,
  },
  'plannedDeliveryAt': '2026-09-06T12:00:00.000Z',
  'createdAt': '2026-09-05T09:00:00.000Z',
  'packageCount': 2,
  'totalWeight': '3.5',
  'order': {'id': 'o-1', 'orderNumber': 'ORD-1', 'customerReference': null},
  'customer': {'code': 'CUST-1', 'displayName': 'Borusan'},
  'service': {'code': 'STD', 'name': 'Standart'},
  'product': {
    'code': 'PRD-STD',
    'name': 'Standart Teslimat',
    'inventoryTrackingCode': null,
  },
  'assignment': {
    'typeCode': 'PRIMARY',
    'statusCode': 'ACCEPTED',
    'assignedAt': '2026-09-05T09:05:00.000Z',
  },
};

Dio _mockDio(
  Map<String, dynamic> Function(RequestOptions options) respond, {
  int statusCode = 200,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://panel.test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: statusCode,
            data: respond(options),
          ),
        );
      },
    ),
  );
  return dio;
}

void main() {
  group('DTO parsing (courier-tasks/route.ts şekli)', () {
    test('PanelCourierTaskDto tüm alanları okur', () {
      final task = PanelCourierTaskDto.fromJson(_taskRow());
      expect(task.id, 's-1');
      expect(task.shipmentNumber, 'JLG-1001');
      expect(task.statusCode, 'COURIER_ASSIGNED');
      expect(task.recipientName, 'Ahmet Yılmaz');
      expect(task.destination.address, contains('Cumhuriyet'));
      expect(task.destination.hasCoordinates, isTrue);
      expect(task.destination.latitude, closeTo(38.1, 0.0001));
      expect(task.customerDisplayName, 'Borusan');
      expect(task.assignmentStatusCode, 'ACCEPTED');
      expect(task.packageCount, 2);
    });

    test('eksik destination/customer/assignment kırmadan boş döner', () {
      final task = PanelCourierTaskDto.fromJson({
        'id': 's-2',
        'shipmentNumber': 'JLG-1002',
        'statusCode': 'CREATED',
      });
      expect(task.destination.hasCoordinates, isFalse);
      expect(task.customerDisplayName, isNull);
      expect(task.assignmentStatusCode, isNull);
    });

    test('PanelCourierTaskListDto summary + tasks birlikte parse eder', () {
      final list = PanelCourierTaskListDto.fromJson({
        'tasks': [_taskRow(id: 's-1'), _taskRow(id: 's-2')],
        'summary': {'total': 2, 'created': 0, 'planned': 2, 'today': 1},
      });
      expect(list.tasks.map((t) => t.id), ['s-1', 's-2']);
      expect(list.summary.total, 2);
      expect(list.summary.today, 1);
    });

    test('PanelTaskActionResultDto accept/start/finalize bayraklarını ayırt eder', () {
      expect(
        PanelTaskActionResultDto.fromJson({'alreadyAccepted': true}).already,
        isTrue,
      );
      expect(
        PanelTaskActionResultDto.fromJson({
          'alreadyStarted': false,
          'workflowState': 'OUT_FOR_DELIVERY',
        }).workflowState,
        'OUT_FOR_DELIVERY',
      );
    });
  });

  group('PanelApi istekleri', () {
    test('fetchTasks doğru query parametreleriyle GET atar', () async {
      late Uri seen;
      final dio = _mockDio((options) {
        seen = options.uri;
        return {
          'success': true,
          'data': {
            'tasks': [_taskRow()],
            'summary': {'total': 1, 'created': 0, 'planned': 1, 'today': 0},
          },
        };
      });
      final api = PanelApi(dio);
      final result = await api.fetchTasks(page: 2, pageSize: 10, status: 'COURIER_ASSIGNED');
      expect(seen.path, '/courier-tasks');
      expect(seen.queryParameters['page'], '2');
      expect(seen.queryParameters['pageSize'], '10');
      expect(seen.queryParameters['status'], 'COURIER_ASSIGNED');
      expect(result.tasks.single.shipmentNumber, 'JLG-1001');
    });

    test('acceptTask POST atar ve alreadyAccepted döner', () async {
      String? seenPath;
      final dio = _mockDio((options) {
        seenPath = options.path;
        return {
          'success': true,
          'data': {'alreadyAccepted': false},
        };
      });
      final result = await PanelApi(dio).acceptTask('s-1');
      expect(seenPath, '/courier-tasks/s-1/accept');
      expect(result.already, isFalse);
    });

    test('startTask body\'e latitude/longitude/capturedAt koyar', () async {
      Map<String, dynamic>? seenBody;
      final dio = _mockDio((options) {
        seenBody = Map<String, dynamic>.from(options.data as Map);
        return {
          'success': true,
          'data': {'alreadyStarted': false, 'workflowState': 'OUT_FOR_DELIVERY'},
        };
      });
      final result = await PanelApi(
        dio,
      ).startTask('s-1', latitude: 38.1, longitude: 29.0, accuracy: 12);
      expect(seenBody!['latitude'], 38.1);
      expect(seenBody!['longitude'], 29.0);
      expect(seenBody!['accuracy'], 12);
      expect(seenBody!['capturedAt'], isNotNull);
      expect(result.workflowState, 'OUT_FOR_DELIVERY');
    });

    test('finalizeTask FAILED için reasonCode gönderir', () async {
      Map<String, dynamic>? seenBody;
      final dio = _mockDio((options) {
        seenBody = Map<String, dynamic>.from(options.data as Map);
        return {
          'success': true,
          'data': {'alreadyFinalized': false, 'currentStateCode': 'REDELIVERY'},
        };
      });
      final result = await PanelApi(dio).finalizeTask(
        's-1',
        outcome: 'FAILED',
        reasonCode: 'RECIPIENT_NOT_AT_ADDRESS',
      );
      expect(seenBody!['outcome'], 'FAILED');
      expect(seenBody!['reasonCode'], 'RECIPIENT_NOT_AT_ADDRESS');
      // FAILED terminal değil — motor REDELIVERY'ye düşürebilir (bkz. §2).
      expect(result.currentStateCode, 'REDELIVERY');
    });

    test('canonical hata kodu PanelApiException olarak fırlatılır', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://panel.test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 409,
                  data: {
                    'success': false,
                    'error': {'code': 'CURRENT_ASSIGNMENT_NOT_FOUND'},
                  },
                ),
                type: DioExceptionType.badResponse,
              ),
            );
          },
        ),
      );
      await expectLater(
        () => PanelApi(dio).acceptTask('s-1'),
        throwsA(
          isA<PanelApiException>().having(
            (e) => e.code,
            'code',
            'CURRENT_ASSIGNMENT_NOT_FOUND',
          ),
        ),
      );
    });

    test('fetchSession 401\'de null döner (throw etmez)', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://panel.test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(requestOptions: options, statusCode: 401),
                type: DioExceptionType.badResponse,
              ),
            );
          },
        ),
      );
      final session = await PanelApi(dio).fetchSession();
      expect(session, isNull);
    });

    test('login identifier/password ile POST courier-auth/login atar', () async {
      String? seenPath;
      Map<String, dynamic>? seenBody;
      final dio = _mockDio((options) {
        seenPath = options.path;
        seenBody = Map<String, dynamic>.from(options.data as Map);
        return {
          'success': true,
          'data': {
            'courier': {
              'id': 'c-1',
              'courierCode': 'DGC-1',
              'fullName': 'Ayşe Kurye',
            },
          },
        };
      });
      final profile = await PanelApi(dio).login(
        identifier: 'kurye@dijigoo.test',
        password: 'secret',
      );
      expect(seenPath, '/courier-auth/login');
      expect(seenBody!['identifier'], 'kurye@dijigoo.test');
      expect(seenBody!['password'], 'secret');
      expect(profile.fullName, 'Ayşe Kurye');
      expect(profile.courierCode, 'DGC-1');
    });

    test('hasStoredSession cookie jar\'sız her zaman false', () async {
      final api = PanelApi(Dio());
      expect(await api.hasStoredSession, isFalse);
    });
  });
}
