import 'package:dijigoo_kurye/api/panel_client.dart';
import 'package:dijigoo_kurye/api/panel_models.dart';
import 'package:dijigoo_kurye/data/vault.dart';
import 'package:dijigoo_kurye/models.dart';
import 'package:dijigoo_kurye/session.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Call = ({
  String method,
  String path,
  Map body,
  String? key,
  Map query,
});

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
          query: options.queryParameters,
        ));
        if (state['offline'] == true) {
          return handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
            ),
          );
        }
        if (state['ibanInvalid'] == true &&
            options.method == 'PUT' &&
            options.path == '/courier-profile') {
          return handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 400,
                data: {
                  'success': false,
                  'error': {
                    'code': 'VALIDATION_ERROR',
                    'fieldErrors': {'iban': 'IBAN geçersiz.'},
                  },
                },
              ),
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
        } else if (options.path == '/courier-custody/disputes') {
          final d = {
            'id': 'd1',
            'ticketNumber': 'TKT-1',
            'statusCode': 'NEW',
            'typeCode': 'EXCESS',
            'scanCode': 'JD-1',
          };
          data = options.method == 'POST'
              ? {'dispute': d}
              : {
                  'disputes': [d],
                };
        } else if (options.path == '/courier-profile') {
          data = {
            'courier': {'fullName': 'Ali Can'},
            'bankAccount': {
              'accountHolderName': 'Ali Can',
              'maskedIban': 'TR** **** **** **** **** **12 34',
              'status': options.method == 'PUT'
                  ? 'PENDING_VERIFICATION'
                  : 'VERIFIED',
            },
            'verifiedBankAccount': {
              'maskedIban': 'TR** **** **** **** **** **99 00',
            },
          };
        } else if (options.path == '/courier-sync/changes') {
          data =
              state['sync'] as Map<String, Object?>? ??
              {
                'serverTime': '2026-10-29T10:00:00.000Z',
                'full': true,
                'tasks': {'activeIds': <String>[], 'items': <Object>[]},
              };
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

  test('zimmet uyuşmazlığı kendi ucuna anahtar ve kodla gider', () async {
    final t = _server();
    final s = _session(t.api);
    final out = await s.reportCustodyDispute(
      typeCode: 'EXCESS',
      idempotencyKey: 'dispute-key-1',
      scanCode: 'JD-1',
      note: '  1 koli fazla  ',
    );
    expect(out.error, isNull);
    expect(out.ticket, 'TKT-1');
    final sent = t.calls.singleWhere(
      (c) => c.method == 'POST' && c.path == '/courier-custody/disputes',
    );
    expect(sent.key, 'dispute-key-1');
    expect(sent.body['typeCode'], 'EXCESS');
    expect(sent.body['scanCode'], 'JD-1');
    expect(sent.body['note'], '1 koli fazla');
    expect(sent.body.containsKey('transferItemId'), isFalse);
    expect(s.custodyDisputes.single.ticketNumber, 'TKT-1');
    expect(t.calls.where((c) => c.path == '/courier-support/cases'), isEmpty);
  });

  test('IBAN temizlenip gönderilir; alan hatası alana düşer', () async {
    final t = _server();
    final saved = await t.api.saveBankAccount(
      accountHolderName: ' Ali Can ',
      iban: 'tr12 0006 2000 0000 0000 0000 01',
    );
    final put = t.calls.singleWhere((c) => c.method == 'PUT');
    expect(put.path, '/courier-profile');
    expect(put.body['iban'], 'TR120006200000000000000001');
    expect(put.body['accountHolderName'], 'Ali Can');
    expect(saved?.status, 'PENDING_VERIFICATION');
    expect(saved?.verifiedMaskedIban, 'TR** **** **** **** **** **99 00');

    t.state['ibanInvalid'] = true;
    await expectLater(
      t.api.saveBankAccount(accountHolderName: 'Ali Can', iban: 'TR00'),
      throwsA(
        isA<PanelApiException>().having(
          (e) => e.fieldErrors['iban'],
          'iban',
          'IBAN geçersiz.',
        ),
      ),
    );
  });

  test('çıkışta cihaz kaydı oturum kapanmadan kapatılır', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final t = _server();
    final s = SessionController(panel: t.api, vault: Vault())
      ..panelLoggedIn = true;
    await s.logout();
    final paths = [for (final c in t.calls) '${c.method} ${c.path}'];
    final close = paths.indexOf('DELETE /courier-devices');
    expect(close, isNonNegative);
    expect(close, lessThan(paths.indexOf('POST /courier-auth/logout')));
    final deviceId = t.calls[close].query['deviceId'] as String?;
    expect(deviceId, isNotNull);
    expect(deviceId, await Vault().installationId());
  });

  test(
    'senkron paketi değişiklik yoksa görev listesini yeniden çekmez',
    () async {
      final t = _server();
      final s = _session(t.api);
      await s.pullTasks();
      int taskLoads() =>
          t.calls.where((c) => c.path == '/courier-tasks').length;
      expect(taskLoads(), 1);
      expect(
        t.calls.where((c) => c.path == '/courier-sync/changes').single.query,
        isNot(contains('since')),
      );

      t.state['sync'] = {
        'serverTime': '2026-10-29T10:05:00.000Z',
        'full': false,
        'tasks': {'activeIds': <String>[], 'items': <Object>[]},
        'custody': {
          'items': [
            {
              'itemId': 'ti-1',
              'shipmentId': 's-1',
              'shipmentNumber': 'JD-7',
              'transferNumber': 'TRF-1',
            },
          ],
        },
      };
      await s.pullTasks();
      final second = t.calls.where((c) => c.path == '/courier-sync/changes');
      expect(second.last.query['since'], '2026-10-29T10:00:00.000Z');
      expect(taskLoads(), 1);
      expect(s.custodyItems.single.transferItemId, 'ti-1');
      expect(s.disputableCustody.single.barcode, 'JD-7');

      t.state['sync'] = {
        'serverTime': '2026-10-29T10:10:00.000Z',
        'full': false,
        'tasks': {
          'activeIds': ['s-9'],
          'items': <Object>[],
        },
      };
      await s.pullTasks();
      expect(taskLoads(), 2);
    },
  );

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
