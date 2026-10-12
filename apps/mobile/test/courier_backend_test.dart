import 'package:dijigoo_kurye/api/panel_client.dart';
import 'package:dijigoo_kurye/models.dart';
import 'package:dijigoo_kurye/session.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Call = ({String method, String path, Map body, String? key});

({PanelApi api, List<_Call> calls, Map<String, Object?> state}) _server() {
  final calls = <_Call>[];
  final state = <String, Object?>{'offline': false, 'shiftError': null};
  final dio = Dio(BaseOptions(baseUrl: 'http://panel.test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        calls.add((
          method: options.method,
          path: options.path,
          body: options.data is Map ? options.data as Map : const {},
          key: options.headers['Idempotency-Key'] as String?,
        ));
        if (state['offline'] == true) {
          return handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
            ),
          );
        }
        final shiftError = state['shiftError'] as String?;
        if (shiftError != null && options.path.contains('/courier-shifts/')) {
          return handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 409,
                data: {
                  'success': false,
                  'error': {'code': shiftError},
                },
              ),
            ),
          );
        }
        Object data = <String, Object>{};
        if (options.path == '/courier-dashboard') {
          data = {
            'counts': {
              'awaitingDelivery': 3,
              'outForDelivery': 2,
              'deliveredToday': 5,
              'failedToday': 1,
              'pendingCustody': 4,
            },
          };
        } else if (options.path == '/courier-shifts/current') {
          data = {'shift': null, 'pendingMandatoryTrainings': 2};
        } else if (options.path == '/courier-trainings') {
          data = {
            'items': [
              {
                'id': 'tr1',
                'title': 'Trafik',
                'isMandatory': true,
                'status': 'NOT_STARTED',
              },
              {'id': 'tr2', 'title': 'KVKK', 'status': 'COMPLETED'},
            ],
          };
        } else if (options.path == '/courier-notifications') {
          data = {
            'items': [
              {
                'id': 'n1',
                'category': 'ANNOUNCEMENT',
                'severity': 'INFO',
                'body': 'Yarın depo 08:00\'de açılır.',
                'read': false,
                'createdAt': '2026-10-13T08:00:00.000Z',
              },
              {
                'id': 'n2',
                'category': 'SLA',
                'severity': 'CRITICAL',
                'body': 'JD-9 gecikiyor',
                'read': true,
              },
            ],
          };
        } else if (options.path == '/courier-trainings/tr1') {
          data = {'contentBody': 'Kask takın.'};
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
  return (api: PanelApi(dio), calls: calls, state: state);
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 80));

SessionController _session(PanelApi api) {
  final s = SessionController(panel: api)..panelLoggedIn = true;
  // Demo tohum kaydı panel kuyruğunu ilgilendirmez.
  s.outbox.events.clear();
  return s;
}

void main() {
  test('vardiya başlat/bitir backend\'e konum ve anahtarla gider', () async {
    final t = _server();
    final s = _session(t.api)..shiftOpen = false;
    s.setShiftOpen(true);
    await _settle();
    final start = t.calls.singleWhere((c) => c.path == '/courier-shifts/start');
    expect(start.body['latitude'], isA<double>());
    expect(start.body['longitude'], isA<double>());
    expect(start.body['occurredAt'], isNotNull);
    expect(start.key, isNotNull);
    expect(s.outbox.events.single.operation, SyncOperation.panelShiftStart);
    expect(s.outbox.events.single.status, 'applied');

    s.setShiftOpen(false);
    await _settle();
    expect(t.calls.where((c) => c.path == '/courier-shifts/end'), hasLength(1));
    expect(s.outbox.pendingCount, 0);
  });

  test(
    'çevrimdışı vardiya kuyrukta bekler, aynı anahtarla yeniden gider',
    () async {
      final t = _server();
      final s = _session(t.api)..shiftOpen = false;
      t.state['offline'] = true;
      s.setShiftOpen(true);
      await _settle();
      expect(s.outbox.pendingCount, 1);

      t.state['offline'] = false;
      await s.pushSyncQueue();
      final sent = [
        for (final c in t.calls)
          if (c.path == '/courier-shifts/start') c.key,
      ];
      expect(sent.length, greaterThanOrEqualTo(2));
      expect(sent.toSet(), hasLength(1));
      expect(s.outbox.pendingCount, 0);
    },
  );

  test('sunucu zaten o durumdaysa vardiya kaydı tamam sayılır', () async {
    final t = _server();
    final s = _session(t.api)..shiftOpen = false;
    t.state['shiftError'] = 'SHIFT_ALREADY_OPEN';
    s.setShiftOpen(true);
    await _settle();
    expect(s.outbox.events.single.status, 'applied');

    t.state['shiftError'] = 'NO_OPEN_SHIFT';
    s.setShiftOpen(false);
    await _settle();
    expect(s.outbox.pendingCount, 0);
  });

  test('bekleyen kayıt varken vardiya kapanmaz', () async {
    final t = _server();
    final s = _session(t.api);
    expect(s.shiftOpen, isTrue);
    t.state['offline'] = true;
    s.createSupportTicket(category: 'OTHER', subject: 'x', body: 'y');
    final blocked = await s.closeShiftChecked();
    expect(blocked, contains('1 kayıt'));
    expect(s.shiftOpen, isTrue);
    expect(t.calls.any((c) => c.path == '/courier-shifts/end'), isFalse);

    t.state['offline'] = false;
    expect(await s.closeShiftChecked(), isNull);
    expect(s.shiftOpen, isFalse);
  });

  test('sayaçlar ve zorunlu eğitim uyarısı backend\'den gelir', () async {
    final t = _server();
    final s = _session(t.api);
    await s.loadCourierDashboard();
    expect(s.courierCounts['awaitingDelivery'], 3);
    expect(s.courierCounts['pendingCustody'], 4);
    expect(s.pendingMandatoryTrainings, 2);
  });

  test('eğitimler backend\'den gelir, örnek eğitim gösterilmez', () async {
    final t = _server();
    final s = _session(t.api);
    await s.loadTrainingModules();
    expect([for (final m in s.trainingModules) m.id], ['tr1', 'tr2']);
    expect(s.trainingModules.first.mandatory, isTrue);
    expect(s.trainingModules.last.completed, isTrue);
    expect(s.pendingMandatoryTrainings, 1);

    await s.loadTrainingBody('tr1');
    expect(s.trainingModules.first.body, 'Kask takın.');

    await s.completeTrainingModule('tr1');
    final done = t.calls.singleWhere(
      (c) => c.path == '/courier-trainings/tr1/complete',
    );
    expect(done.body['acknowledged'], isTrue);
  });

  test('zimmet uyuşmazlığı okutulanlarla destek kaydı olarak gider', () async {
    final t = _server();
    final s = _session(t.api);
    s.zimmetScans.add((code: 'JD-1', time: '10:00'));
    s.reportCustodyDiscrepancy('1 koli eksik');
    await _settle();
    final sent = t.calls.singleWhere(
      (c) => c.method == 'POST' && c.path == '/courier-support/cases',
    );
    expect('${sent.body}', contains('1 koli eksik'));
    expect('${sent.body}', contains('JD-1'));
  });

  test('bildirim kutusu backend\'den gelir, okundu geri yazılır', () async {
    final t = _server();
    final s = _session(t.api);
    await s.loadCourierNotifications();
    final ids = [for (final n in s.notifications) n.id];
    expect(ids, containsAll(['srv-n1', 'srv-n2']));
    expect(ids.any((id) => id.startsWith('demo-')), isFalse);
    expect(s.isNotifRead('srv-n2'), isTrue);
    expect(s.isNotifRead('srv-n1'), isFalse);
    expect(s.notificationById('srv-n1')?.title, 'Duyuru');

    s.markNotificationRead('srv-n1');
    await _settle();
    expect(
      t.calls.any((c) => c.path == '/courier-notifications/n1/read'),
      isTrue,
    );
  });

  test('mola backend\'e bildirilir; vardiya yoksa durum değişmez', () async {
    final t = _server();
    final s = _session(t.api);
    expect(await s.toggleBreak(), isNull);
    expect(s.onBreak, isTrue);
    final start = t.calls.singleWhere(
      (c) => c.path == '/courier-shifts/breaks/start',
    );
    expect(start.key, isNotNull);
    expect(await s.toggleBreak(), isNull);
    expect(s.onBreak, isFalse);
    expect(
      t.calls.where((c) => c.path == '/courier-shifts/breaks/end'),
      hasLength(1),
    );

    t.state['shiftError'] = 'NO_OPEN_SHIFT';
    expect(await s.toggleBreak(), contains('vardiyayı başlatın'));
    expect(s.onBreak, isFalse);
  });
}
