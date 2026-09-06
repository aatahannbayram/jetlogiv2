import 'package:dijigoo_kurye/api/client.dart';
import 'package:dijigoo_kurye/api/courier_tasks.dart';
import 'package:dijigoo_kurye/api/models.dart';
import 'package:dijigoo_kurye/api/panel_client.dart';
import 'package:dijigoo_kurye/api/panel_models.dart';
import 'package:dijigoo_kurye/models.dart';
import 'package:dijigoo_kurye/session.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TaskSummary → DeliveryTask (isim, adres, cancelled, rowVersion)', () {
    final task = deliveryTaskFromSummary({
      'id': '9f1c2f8a-7d1e-4f6b-9a3c-2b5d4e6f7a81',
      'reference': 'DJG-1',
      'type': 'DELIVERY',
      'status': 'CANCELLED',
      'sequence': 2,
      'address': {
        'line1': 'Cumhuriyet Cd. 1',
        'district': 'Güney',
        'city': 'Denizli',
        'coordinates': {'lat': 38.1, 'lng': 29.0},
      },
      'contact': {'name': 'Ayşe'},
      'slotStartAt': '2026-08-25T14:30:00.000Z',
      'slotEndAt': '2026-08-25T15:00:00.000Z',
      'itemCount': 3,
      'codAmount': 40,
      'rowVersion': 4,
      'workflow': {'version': 2},
    });
    expect(task.ref, 'DJG-1');
    expect(task.recipient, 'Ayşe');
    expect(task.address, contains('Cumhuriyet'));
    expect(task.address, contains('Güney / Denizli'));
    expect(task.status, TaskStatus.cancelled);
    expect(task.isOpen, isFalse);
    expect(task.rowVersion, 4);
    expect(task.workflowVersion, 2);
    expect(task.cod, 40);
    expect(task.custodyCount, 3);
    expect(task.lat, 38.1);
    expect(task.phone, isNull);
  });

  test('Contact phone ve maskedPhone DeliveryTask.phone olur', () {
    final raw = deliveryTaskFromSummary({
      'id': '9f1c2f8a-7d1e-4f6b-9a3c-2b5d4e6f7a81',
      'reference': 'DJG-2',
      'type': 'DELIVERY',
      'status': 'ASSIGNED',
      'sequence': 1,
      'address': {'line1': 'A', 'city': 'Denizli'},
      'contact': {'name': 'Bora', 'phone': '+905321110026'},
      'rowVersion': 0,
    });
    expect(raw.phone, '+905321110026');
    final masked = deliveryTaskFromSummary({
      'id': '9f1c2f8a-7d1e-4f6b-9a3c-2b5d4e6f7a82',
      'reference': 'DJG-3',
      'type': 'DELIVERY',
      'status': 'ASSIGNED',
      'sequence': 1,
      'address': {'line1': 'A', 'city': 'Denizli'},
      'contact': {'name': 'Ada', 'maskedPhone': '+90532***0026'},
      'rowVersion': 0,
    });
    expect(masked.phone, '+90532***0026');
  });

  test('demo GET /v1/tasks tohumu Ahmet Yılmaz’ı döner', () {
    final payload = mockPayload('/v1/tasks', RequestOptions(path: '/v1/tasks'));
    final items = (payload['items'] as List).cast<Map<String, dynamic>>();
    expect(items, hasLength(4));
    final mapped = [for (final row in items) deliveryTaskFromSummary(row)];
    expect(mapped.first.recipient, 'Ahmet Yılmaz');
    expect(mapped.first.ref, 'DGO-8841');
    expect(mapped.map((t) => t.id), ['t1', 't2', 't3', 't4']);
    expect(mapped.first.phone, '+905321110026');
  });

  test('POST /v1/tasks/:id/call mock dialNumber döner', () async {
    final payload = mockPayload(
      '/v1/tasks/t1/call',
      RequestOptions(path: '/v1/tasks/t1/call'),
    );
    expect(payload['dialNumber'], '+905321110026');
    expect(payload['sessionId'], isNotEmpty);
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              extra: const {'demo': true},
              data: payload,
            ),
          );
        },
      ),
    );
    final call = await MobileApi(dio: dio).startMaskedCall('t1');
    expect(call.dialNumber, '+905321110026');
  });

  test('FailScreen gerekçesi kanonik outcomeCode’a düşer', () {
    expect(failureOutcomeCode('Alıcı adreste yok'), 'RECIPIENT_ABSENT');
    expect(failureOutcomeCode('Adres bulunamadı'), 'ADDRESS_NOT_FOUND');
    expect(failureOutcomeCode('Alıcı teslim almadı'), 'REFUSED');
    expect(failureOutcomeCode('Ödeme alınamadı'), 'REFUSED');
    expect(photoRequiredForFailure('Alıcı adreste yok'), isTrue);
    expect(photoRequiredForFailure('Adres bulunamadı'), isTrue);
    expect(photoRequiredForFailure('Alıcı teslim almadı'), isFalse);
  });

  test('submitStep STEP_SUBMIT kuyruğa yazar', () {
    final s = SessionController();
    s.online = false;
    s.submitStep(
      taskId: 't1',
      stepKey: 'alici_kim',
      value: {'teslim_alan': 'recipient'},
    );
    final last = s.outbox.events.last;
    expect(last.operation, SyncOperation.stepSubmit);
    expect(last.payload['stepKey'], 'alici_kim');
    expect(s.stepAnswers['t1']!.single['stepKey'], 'alici_kim');
  });

  test('iade TASK_FINALIZE + RECIPIENT_ABSENT yazar', () {
    final s = SessionController();
    s.returnTask('t1', reason: 'Alıcı adreste yok', note: 'zile basıldı');
    final last = s.outbox.events.last;
    expect(last.operation, SyncOperation.taskFinalize);
    expect(last.payload['outcomeCode'], 'RECIPIENT_ABSENT');
    expect(last.payload['workflowVersion'], 1);
    expect(last.payload['clientEventId'], last.clientEventId);
    expect(last.payload['occurredAt'], isNotNull);
    expect(last.payload['location'], isA<Map>());
    expect(s.taskById('t1').status, TaskStatus.failed);
  });

  test('start zinciri ACCEPTED…IN_PROGRESS ve rowVersion artırır', () {
    expect(
      startTransitions(
        wireStatus: 'ASSIGNED',
        rowVersion: 2,
      ).map((s) => (s.to, s.rowVersion)),
      [('ACCEPTED', 2), ('EN_ROUTE', 3), ('ARRIVED', 4), ('IN_PROGRESS', 5)],
    );
    expect(startTransitions(wireStatus: 'IN_PROGRESS', rowVersion: 7), isEmpty);
    expect(
      startTransitions(wireStatus: 'ARRIVED', rowVersion: 1).single.to,
      'IN_PROGRESS',
    );
  });

  test(
    'startTask dört geçiş kuyruklar; finalize sonraki rowVersion kullanır',
    () {
      final s = SessionController();
      s.startTask('t1');
      final startEvents = s.outbox.events
          .where(
            (e) =>
                e.subjectId == 't1' &&
                e.operation == SyncOperation.taskTransition,
          )
          .toList();
      expect(startEvents.map((e) => e.payload['to']), [
        'ACCEPTED',
        'EN_ROUTE',
        'ARRIVED',
        'IN_PROGRESS',
      ]);
      expect(startEvents.map((e) => e.payload['rowVersion']), [0, 1, 2, 3]);
      expect(s.taskById('t1').rowVersion, 4);
      expect(s.taskById('t1').wireStatus, 'IN_PROGRESS');
      s.deliverTask('t1', receivedBy: 'Alıcının kendisi');
      expect(s.outbox.events.last.payload['rowVersion'], 4);
    },
  );

  test('destek talebi SUPPORT_TICKET_CREATE kuyruğa yazar', () {
    final s = SessionController();
    s.createSupportTicket(
      category: 'ADDRESS_PROBLEM',
      subject: 'Kapı yok',
      body: 'Numara görünmüyor',
      taskId: 't1',
    );
    final last = s.outbox.events.last;
    expect(last.operation, SyncOperation.supportTicketCreate);
    expect(last.payload['category'], 'ADDRESS_PROBLEM');
    expect(last.payload['subject'], 'Kapı yok');
    expect(last.payload['body'], 'Numara görünmüyor');
    expect(last.payload['taskId'], 't1');
    expect(last.payload['clientEventId'], last.clientEventId);
    expect(s.tickets.first.subject, 'Kapı yok');
    expect(s.tickets.first.status, 'open');
  });

  test('Panel courier-tasks satırı DeliveryTask’a düşer', () {
    final row = PanelCourierTaskDto.fromJson({
      'id': 's-1',
      'shipmentNumber': 'JLG-1001',
      'statusCode': 'OUT_FOR_DELIVERY',
      'statusReasonCode': null,
      'recipientName': 'Ahmet Yılmaz',
      'destination': {
        'address': 'Cumhuriyet Cd. 1 · Güney',
        'latitude': '38.1',
        'longitude': '29.0',
      },
      'plannedDeliveryAt': '2026-09-06T12:00:00.000Z',
      'packageCount': 2,
    });
    final task = deliveryTaskFromPanel(row);
    expect(task.id, 's-1');
    expect(task.ref, 'JLG-1001');
    expect(task.recipient, 'Ahmet Yılmaz');
    expect(task.address, contains('Cumhuriyet'));
    expect(task.status, TaskStatus.inProgress);
    expect(task.custodyCount, 2);
    expect(task.lat, closeTo(38.1, 0.0001));
    expect(task.wireStatus, 'OUT_FOR_DELIVERY');
    expect(taskStatusFromPanel('DELIVERED'), TaskStatus.delivered);
    expect(taskStatusFromPanel('FAILED'), TaskStatus.failed);
    expect(taskStatusFromPanel('REDELIVERY'), TaskStatus.assigned);
    expect(taskStatusFromPanel('CANCELLED'), TaskStatus.cancelled);
    expect(
      startTransitions(wireStatus: task.wireStatus, rowVersion: 0),
      isEmpty,
    );
  });

  test('GET /v1/tasks cursor sayfalarını birleştirir', () async {
    Map<String, Object?> summary(String id, String name) => {
      'id': id,
      'reference': 'DJG-$id',
      'type': 'DELIVERY',
      'status': 'ASSIGNED',
      'sequence': 1,
      'address': {
        'line1': 'Cumhuriyet Cd. 1',
        'district': 'Güney',
        'city': 'Denizli',
        'coordinates': {'lat': 38.1, 'lng': 29.0},
      },
      'contact': {'name': name},
    };
    final dio = Dio(BaseOptions(baseUrl: 'http://tasks.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final cursor = options.queryParameters['cursor'];
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: cursor == 'p2'
                  ? {
                      'items': [summary('b', 'Bora')],
                      'nextCursor': null,
                    }
                  : {
                      'items': [summary('a', 'Ada')],
                      'nextCursor': 'p2',
                    },
            ),
          );
        },
      ),
    );
    final tasks = await MobileApi(dio: dio).fetchTasks();
    expect(tasks.map((t) => t.id), ['a', 'b']);
    expect(tasks.map((t) => t.recipient), ['Ada', 'Bora']);
  });

  test('bekleyen yerel talep sunucu listesiyle silinmez', () {
    final s = SessionController();
    s.online = false;
    s.createSupportTicket(
      category: 'OTHER',
      subject: 'Yerel',
      body: 'kuyrukta',
    );
    final localId = s.tickets.first.id;
    s.replaceTickets([
      SupportTicketDto(
        id: 'srv-1',
        reference: 'DST-SERVER',
        category: 'OTHER',
        subject: 'Sunucu',
        body: 'uzak',
        status: 'open',
        priority: 'normal',
        createdAt: '2026-08-25T09:00:00.000Z',
      ),
    ]);
    expect(s.tickets.map((t) => t.subject), containsAll(['Sunucu', 'Yerel']));
    expect(s.tickets.any((t) => t.id == localId), isTrue);

    s.outbox.events.last.status = 'applied';
    s.replaceTickets([
      SupportTicketDto(
        id: 'srv-1',
        reference: 'DST-SERVER',
        category: 'OTHER',
        subject: 'Sunucu',
        body: 'uzak',
        status: 'open',
        priority: 'normal',
        createdAt: '2026-08-25T09:00:00.000Z',
      ),
    ]);
    expect(s.tickets.map((t) => t.subject), ['Sunucu']);
  });

  test('GET /v1/support/tickets cursor sayfalarını birleştirir', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://tickets.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final cursor = options.queryParameters['cursor'];
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: cursor == 'p2'
                  ? {
                      'items': [
                        {
                          'id': 'b',
                          'reference': 'DST-B',
                          'category': 'OTHER',
                          'subject': 'İkinci',
                          'body': '',
                          'status': 'open',
                          'priority': 'normal',
                          'createdAt': '2026-08-25T10:00:00.000Z',
                        },
                      ],
                      'nextCursor': null,
                    }
                  : {
                      'items': [
                        {
                          'id': 'a',
                          'reference': 'DST-A',
                          'category': 'OTHER',
                          'subject': 'Birinci',
                          'body': '',
                          'status': 'open',
                          'priority': 'normal',
                          'createdAt': '2026-08-25T09:00:00.000Z',
                        },
                      ],
                      'nextCursor': 'p2',
                    },
            ),
          );
        },
      ),
    );
    final tickets = await MobileApi(dio: dio).fetchSupportTickets();
    expect(tickets.map((t) => t.id), ['a', 'b']);
    expect(tickets.map((t) => t.subject), ['Birinci', 'İkinci']);
  });

  test('demo destek listesi sözleşmeyi doldurur', () {
    final payload = mockPayload(
      '/v1/support/tickets',
      RequestOptions(path: '/v1/support/tickets'),
    );
    final items = (payload['items'] as List).cast<Map<String, dynamic>>();
    expect(items, isNotEmpty);
    final ticket = SupportTicketDto.fromJson(items.first);
    expect(ticket.reference, startsWith('DST-'));
    expect(ticket.categoryLabel, 'Adres');
  });

  test('delta iptali uygular, atananı siler, bekleyen outbox’ı ezmez', () {
    final s = SessionController();
    s.online = false;
    s.returnTask('t3', reason: 'Alıcı adreste yok');
    expect(s.taskById('t3').status, TaskStatus.failed);
    s.applyTaskDelta(
      changed: [
        DeliveryTask(
          id: 't1',
          ref: 'DGO-8841',
          recipient: 'Ahmet Yılmaz',
          address: 'x',
          window: '—',
          kind: TaskKind.delivery,
          status: TaskStatus.cancelled,
        ),
        DeliveryTask(
          id: 't3',
          ref: 'DGO-8843',
          recipient: 'Mehmet Aydın',
          address: 'x',
          window: '—',
          kind: TaskKind.delivery,
          status: TaskStatus.assigned,
        ),
      ],
      removedIds: const ['t2'],
    );
    expect(s.taskById('t1').status, TaskStatus.cancelled);
    expect(s.tasks.any((t) => t.id == 't2'), isFalse);
    expect(s.taskById('t3').status, TaskStatus.failed);
    expect(s.notifications.first.title, 'Durak iptal');
    expect(
      s.notifications.where((n) => n.title == 'Durak çekildi'),
      isNotEmpty,
    );
  });

  test('GET /v1/sync/changes sayfalarını birleştirir', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://sync.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final cursor = options.queryParameters['cursor'];
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: cursor == 'p2'
                  ? {
                      'tasks': [
                        {
                          'id': 'b',
                          'reference': 'DJG-B',
                          'type': 'DELIVERY',
                          'status': 'ASSIGNED',
                          'address': {
                            'line1': 'B',
                            'city': 'Denizli',
                            'coordinates': {'lat': 38.1, 'lng': 29.0},
                          },
                          'contact': {'name': 'Bora'},
                        },
                      ],
                      'removedTaskIds': <String>[],
                      'nextCursor': null,
                      'syncedAt': '2026-09-06T18:00:00.000Z',
                      'resyncRequired': false,
                    }
                  : {
                      'tasks': [
                        {
                          'id': 'a',
                          'reference': 'DJG-A',
                          'type': 'DELIVERY',
                          'status': 'CANCELLED',
                          'address': {
                            'line1': 'A',
                            'city': 'Denizli',
                            'coordinates': {'lat': 38.1, 'lng': 29.0},
                          },
                          'contact': {'name': 'Ada'},
                        },
                      ],
                      'removedTaskIds': ['gone'],
                      'nextCursor': 'p2',
                      'syncedAt': '2026-09-06T17:00:00.000Z',
                      'resyncRequired': false,
                    },
            ),
          );
        },
      ),
    );
    final delta = await MobileApi(dio: dio)
        .fetchChanges(since: '2026-09-06T16:00:00.000Z');
    expect(delta.tasks.map((t) => t.id), ['a', 'b']);
    expect(delta.tasks.first.status, TaskStatus.cancelled);
    expect(delta.removedTaskIds, ['gone']);
    expect(delta.syncedAt, '2026-09-06T18:00:00.000Z');
  });

  test('yeni atanan durak bildirim açar', () {
    final s = SessionController();
    s.applyTaskDelta(
      changed: [
        DeliveryTask(
          id: 't-new',
          ref: 'DGO-9001',
          recipient: 'Yeni Kişi',
          address: 'x',
          window: '—',
          kind: TaskKind.delivery,
          status: TaskStatus.assigned,
        ),
      ],
      removedIds: const [],
    );
    expect(s.taskById('t-new').recipient, 'Yeni Kişi');
    expect(s.notifications.first.title, 'Yeni durak atandı');
  });

  test('loginWithPanel Fastify outbox’a yazmaz, görev çekmez', () async {
    var taskGets = 0;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.contains('/courier-auth/login')) {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': {
                    'courier': {
                      'id': 'c-1',
                      'courierCode': 'DGC-1',
                      'fullName': 'Ayşe Kurye',
                    },
                  },
                },
              ),
            );
            return;
          }
          if (options.path.contains('/v1/tasks')) taskGets += 1;
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: const {'items': <dynamic>[]},
            ),
          );
        },
      ),
    );
    final s = SessionController(
      panel: PanelApi(dio),
      api: MobileApi(dio: dio),
    );
    final before = s.outbox.events.length;
    final ok = await s.loginWithPanel(identifier: 'a@b.com', password: 'x');
    expect(ok, isTrue);
    expect(s.panelLoggedIn, isTrue);
    expect(s.courier.fullName, 'Ayşe Kurye');
    expect(s.outbox.events.length, before);
    expect(taskGets, 0);
    expect(s.phase, AppPhase.onboard);
  });

  test('loginWithPanel panel yokken yalnız demo çiftle açılır', () async {
    final s = SessionController();
    expect(await s.loginWithPanel(identifier: 'x', password: 'y'), isFalse);
    expect(s.lastPanelError, 'PANEL_UNAVAILABLE');
    expect(s.panelLoggedIn, isFalse);
    expect(
      await s.loginWithPanel(
        identifier: SessionController.panelDemoIdentifier,
        password: SessionController.panelDemoPassword,
      ),
      isTrue,
    );
    expect(s.panelLoggedIn, isTrue);
  });

  test('hydratePanelSession görev çekmez, isim günceller', () async {
    var taskGets = 0;
    var sessionGets = 0;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.contains('/courier-auth/session')) {
            sessionGets += 1;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': {
                    'courier': {
                      'id': 'c-1',
                      'courierCode': 'DGC-1',
                      'fullName': 'Ayşe Kurye',
                    },
                  },
                },
              ),
            );
            return;
          }
          if (options.path.contains('/v1/tasks')) taskGets += 1;
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: const {'items': <dynamic>[]},
            ),
          );
        },
      ),
    );
    final s = SessionController(
      panel: PanelApi(dio),
      api: MobileApi(dio: dio),
    );
    await s.hydratePanelSession();
    expect(s.panelLoggedIn, isTrue);
    expect(s.courier.fullName, 'Ayşe Kurye');
    expect(s.lastPanelError, isNull);
    expect(sessionGets, 1);
    expect(taskGets, 0);
  });

  test('hydratePanelSession 401 oturumu kapatır, görev çekmez', () async {
    var taskGets = 0;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.contains('/courier-auth/session')) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 401,
                ),
                type: DioExceptionType.badResponse,
              ),
            );
            return;
          }
          if (options.path.contains('/v1/tasks')) taskGets += 1;
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: const {'items': <dynamic>[]},
            ),
          );
        },
      ),
    );
    final s = SessionController(
      panel: PanelApi(dio),
      api: MobileApi(dio: dio),
    );
    s.panelLoggedIn = true;
    await s.hydratePanelSession();
    expect(s.panelLoggedIn, isFalse);
    expect(s.lastPanelError, SessionController.panelSessionExpired);
    expect(taskGets, 0);
  });

  test('restorePanelSession cookie yokken ağ çağırmaz', () async {
    var hits = 0;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          hits += 1;
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: const {},
            ),
          );
        },
      ),
    );
    final s = SessionController(panel: PanelApi(dio));
    await s.restorePanelSession();
    expect(hits, 0);
    expect(s.panelLoggedIn, isFalse);
  });

  test('OTP 123456 hâlâ demo token yazar', () async {
    final s = SessionController();
    expect(await s.verifyLoginOtp('123456'), isTrue);
    expect(s.demo, isTrue);
  });

  test('vardiya aç/kapa SHIFT_START ve SHIFT_END yazar', () {
    final s = SessionController();
    s.online = false;
    s.takeShiftPhoto();
    s.openShift();
    expect(s.outbox.events.last.operation, SyncOperation.shiftStart);
    final start = s.outbox.events.last.payload;
    expect(start['location'], isA<Map>());
    expect((start['location'] as Map)['lat'], isNotNull);
    expect(start['permissions'], isA<Map>());
    expect((start['permissions'] as Map)['locationAlways'], isFalse);
    s.setShiftOpen(false);
    expect(s.outbox.events.last.operation, SyncOperation.shiftEnd);
  });

  test('ShiftDto active/paused açık, closed kapalı', () {
    expect(
      ShiftDto.fromJson({
        'id': 's1',
        'status': 'active',
        'startedAt': '2026-09-06T07:00:00.000Z',
        'vehiclePlate': '20 DGO 26',
      }).isOpen,
      isTrue,
    );
    expect(
      ShiftDto.fromJson({
        'id': 's1',
        'status': 'paused',
        'startedAt': '2026-09-06T07:00:00.000Z',
      }).isOpen,
      isTrue,
    );
    expect(
      ShiftDto.fromJson({
        'id': 's1',
        'status': 'closed',
        'startedAt': '2026-09-06T07:00:00.000Z',
      }).isOpen,
      isFalse,
    );
  });

  test('demo GET /v1/shifts/current sahte açık vardiya dönmez', () {
    final payload = mockPayload(
      '/v1/shifts/current',
      RequestOptions(path: '/v1/shifts/current'),
    );
    expect(payload, isEmpty);
  });

  test('canlı açık vardiya splash’tan ana ekrana alır', () {
    final s = SessionController(initialPhase: AppPhase.splash);
    s.applyOpenShift(
      const ShiftDto(
        id: 'shift-1',
        status: 'active',
        startedAt: '2026-09-06T07:12:00.000Z',
        vehiclePlate: '20 ABC 123',
      ),
    );
    expect(s.shiftOpen, isTrue);
    expect(s.shiftPhotoTaken, isTrue);
    expect(s.phase, AppPhase.main);
    expect(s.currentShiftId, 'shift-1');
    expect(s.plate, '20 ABC 123');
  });

  test('onboard’da açık vardiya fazı değiştirmez', () {
    final s = SessionController(initialPhase: AppPhase.onboard);
    s.applyOpenShift(
      const ShiftDto(
        id: 'shift-1',
        status: 'active',
        startedAt: '2026-09-06T07:12:00.000Z',
      ),
    );
    expect(s.phase, AppPhase.onboard);
    expect(s.shiftOpen, isTrue);
  });

  test('restoreOpenShift yalnız canlı açık vardiyada atlar', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.contains('/v1/shifts/current')) {
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'id': 'shift-live',
                  'status': 'active',
                  'startedAt': '2026-09-06T07:00:00.000Z',
                  'vehiclePlate': '20 DGO 01',
                },
              ),
            );
            return;
          }
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: const {'items': <dynamic>[], 'nextCursor': null},
            ),
          );
        },
      ),
    );
    final s = SessionController(
      api: MobileApi(dio: dio),
      initialPhase: AppPhase.splash,
    );
    await s.restoreOpenShift();
    expect(s.phase, AppPhase.main);
    expect(s.currentShiftId, 'shift-live');
    expect(s.shiftPhotoTaken, isTrue);
  });

  test('demo fallback current restore etmez', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              extra: const {'demo': true},
              data: <String, dynamic>{},
            ),
          );
        },
      ),
    );
    final s = SessionController(
      api: MobileApi(dio: dio),
      initialPhase: AppPhase.splash,
    );
    await s.restoreOpenShift();
    expect(s.phase, AppPhase.splash);
    expect(s.currentShiftId, isNull);
  });

  test('zimmet taraması boş ve tekrar kodu yutmaz', () {
    final s = SessionController();
    s.addZimmetScan('');
    s.addZimmetScan('  ');
    expect(s.zimmetScans, isEmpty);
    s.addZimmetScan('DGO-9107');
    s.addZimmetScan('DGO-9107');
    expect(s.zimmetScans.map((e) => e.code), ['DGO-9107']);
    s.removeZimmetScan('DGO-9107');
    expect(s.zimmetScans, isEmpty);
  });

  test('iptal açık sayaçta ve nextStop’ta yok', () {
    final s = SessionController();
    s.taskById('t1').status = TaskStatus.cancelled;
    expect(s.openCount, 4);
    expect(s.nextStop?.id, isNot('t1'));
    expect(s.nextStop?.id, s.orderedOpenTasks.first.id);
    expect(s.returnCount, 1);
    expect(s.remainingStops.map((t) => t.id), isNot(contains('t1')));
    expect(s.taskById('t1').isClosed, isTrue);
  });

  test('remainingStops gün rotası sırasını izler', () async {
    final s = SessionController();
    await s.ensureDayRoute();
    final ordered = s.orderedOpenTasks.map((t) => t.id).toList();
    expect(ordered, isNotEmpty);
    expect(s.nextStop?.id, ordered.first);
    expect(s.remainingStops.map((t) => t.id).toList(), ordered.skip(1).toList());
  });

  test(
    'reddedilen senkron olayı gerçek "Gönderim başarısız" bildirimi üretir',
    () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/v1/sync/batch')) {
              final events = (options.data as Map)['events'] as List;
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'results': [
                      for (final e in events)
                        {
                          'clientEventId': (e as Map)['clientEventId'],
                          'status': 'rejected',
                        },
                    ],
                  },
                ),
              );
              return;
            }
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: const {'items': <dynamic>[]},
              ),
            );
          },
        ),
      );
      final s = SessionController(api: MobileApi(dio: dio));
      // returnTask'ın kendi unawaited flush'ıyla yarışmaması için online'ı
      // geçici kapatıp tek, belirlenimci bir pushSyncQueue() ile akıtıyoruz.
      s.online = false;
      s.returnTask('t1', reason: 'Alıcı adreste yok');
      s.online = true;
      await s.pushSyncQueue();
      expect(s.notifications.first.title, 'Gönderim başarısız');
      expect(s.notifications.first.kind, NotifKind.syncFail);
      expect(s.notifications.first.taskId, 't1');
    },
  );

  test('şube zimmet devri başarılı olunca gerçek "Zimmet onaylandı" bildirimi üretir', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.contains('/v1/custody/handover')) {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'handoverId': 'h-1',
                  'remaining': <dynamic>[],
                  'appliedAt': DateTime.now().toUtc().toIso8601String(),
                },
              ),
            );
            return;
          }
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: const {'items': <dynamic>[]},
            ),
          );
        },
      ),
    );
    final s = SessionController(api: MobileApi(dio: dio));
    s.custodyItems = const [
      CustodyItemDto(
        id: 'ci-1',
        type: 'parcel',
        description: 'Koli',
        quantity: 1,
        acquiredAt: '2026-09-01T00:00:00.000Z',
        barcode: 'DGO-9107',
      ),
    ];
    s.zimmetMode = 'sube';
    s.addZimmetScan('DGO-9107');
    final ok = await s.completeZimmet();
    expect(ok, isTrue);
    expect(s.notifications.first.title, 'Zimmet onaylandı');
    expect(s.notifications.first.kind, NotifKind.custody);
  });

  test('kurye zimmeti barkodla takeover çağırır', () async {
    final calls = <String>[];
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          calls.add('${options.method} ${options.path}');
          if (options.path.contains('/v1/custody/handover')) {
            expect(options.data['direction'], 'takeover');
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'handoverId': 'h-2',
                  'remaining': [
                    {
                      'id': 'ci-2',
                      'type': 'parcel',
                      'description': 'Koli',
                      'quantity': 1,
                      'acquiredAt': DateTime.now().toUtc().toIso8601String(),
                      'barcode': 'DGO-2201',
                    },
                  ],
                  'appliedAt': DateTime.now().toUtc().toIso8601String(),
                },
              ),
            );
            return;
          }
          if (options.path.contains('/v1/custody')) {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'items': [
                    {
                      'id': 'ci-2',
                      'type': 'parcel',
                      'description': 'Koli',
                      'quantity': 1,
                      'acquiredAt': DateTime.now().toUtc().toIso8601String(),
                      'barcode': 'DGO-2201',
                    },
                  ],
                },
              ),
            );
            return;
          }
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: const {},
            ),
          );
        },
      ),
    );
    final s = SessionController(api: MobileApi(dio: dio));
    s.zimmetMode = 'kurye';
    s.addZimmetScan('DGO-2201');
    final ok = await s.completeZimmet();
    expect(ok, isTrue);
    expect(s.notifications.first.title, 'Zimmet alındı');
    expect(calls.any((c) => c.contains('/v1/custody/handover')), isTrue);
  });

  test('destek listesi hatası canlı API bayrağını düşürmez', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 404,
              ),
            ),
          );
        },
      ),
    );
    final s = SessionController(api: MobileApi(dio: dio));
    s.liveApi = true;
    await s.loadTickets();
    expect(s.liveApi, isTrue);
  });

  test('öne gelince demo oturumunda ağ çağırmaz', () async {
    var hits = 0;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          hits++;
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
            ),
          );
        },
      ),
    );
    final s = SessionController(
      api: MobileApi(dio: dio),
      initialPhase: AppPhase.main,
    );
    s.liveApi = false;
    await s.onForeground();
    expect(hits, 0);
  });
}
