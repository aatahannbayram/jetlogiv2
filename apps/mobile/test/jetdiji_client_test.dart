import 'package:dijigoo_kurye/api/jetdiji_branch_client.dart';
import 'package:dijigoo_kurye/api/jetdiji_branch_models.dart';
import 'package:dijigoo_kurye/api/jetdiji_courier_client.dart';
import 'package:dijigoo_kurye/api/jetdiji_courier_models.dart';
import 'package:dijigoo_kurye/api/jetdiji_http.dart';
import 'package:dijigoo_kurye/models.dart';
import 'package:dijigoo_kurye/session.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hata kodu yalnız error.code', () {
    expect(
      () => unwrapJetdijiBody({
        'success': false,
        'code': 'LEGACY_TOP',
        'error': {'code': 'UNAUTHENTICATED', 'message': 'Oturum yok'},
      }, 401),
      throwsA(
        isA<JetDijiException>().having((e) => e.code, 'code', 'UNAUTHENTICATED'),
      ),
    );
  });

  test('409 acente listesi error.agencies', () {
    try {
      unwrapJetdijiBody({
        'success': false,
        'data': {
          'agencies': [
            {'id': 'eski', 'name': 'Eski'},
          ],
        },
        'error': {
          'code': 'AGENCY_SELECTION_REQUIRED',
          'agencies': [
            {'id': 'ag1', 'name': 'Güney', 'code': 'GNY', 'tenantId': 't1'},
          ],
        },
      }, 409);
      fail('exception');
    } on JetDijiException catch (e) {
      expect(e.code, 'AGENCY_SELECTION_REQUIRED');
      expect(e.agencies, hasLength(1));
      expect(e.agencies.single.id, 'ag1');
      expect(e.agencies.single.name, 'Güney');
    }
  });

  test('eksik kanıt missing listesini taşır', () {
    try {
      unwrapJetdijiBody({
        'success': false,
        'error': {
          'code': 'DELIVERY_REQUIREMENTS_MISSING',
          'missing': [
            {'type': 'PHOTO', 'code': 'DOOR', 'required': 1, 'actual': 0},
          ],
        },
      }, 422);
      fail('exception');
    } on JetDijiException catch (e) {
      expect(e.missing.single.type, 'PHOTO');
      expect(e.missing.single.code, 'DOOR');
      expect(e.missing.single.requiredCount, 1);
    }
  });

  test('sayısal statü, maskeli telefon ve string koordinat', () {
    final task = deliveryTaskFromJetdiji(
      JetDijiTaskItem.fromJson({
        'id': 'shp-1',
        'shipmentNumber': 'DGO-100',
        'statusCode': '4020',
        'recipientName': 'Ayşe',
        'recipientPhoneMasked': '+90 532 ••• •• 26',
        'destination': {
          'address': 'Kayalık Mah. No:1',
          'latitude': '38.151200',
          'longitude': '29.061400',
          'usableForProximity': true,
        },
        'plannedDeliveryAt': '2026-10-03T18:00:00Z',
        'packageCount': 2,
        'customer': {'displayName': 'Jet Market'},
        'product': {'inventoryTrackingCode': 'PRD-9'},
      }),
    );
    expect(task.status, TaskStatus.inProgress);
    expect(task.phone, '+90 532 ••• •• 26');
    expect(task.phone, isNot(contains('532111')));
    expect(task.lat, closeTo(38.1512, 0.0001));
    expect(task.lng, closeTo(29.0614, 0.0001));
    expect(task.merchantName, 'Jet Market');
    expect(task.custodyRef, 'PRD-9');
    expect(task.custodyCount, 2);
    expect(task.groupKey, 'kayalık mah. no:1');
  });

  test('usableForProximity false haritaya konmaz', () {
    final task = deliveryTaskFromJetdiji(
      JetDijiTaskItem.fromJson({
        'id': 'shp-2',
        'shipmentNumber': 'DGO-101',
        'statusCode': '4010',
        'destination': {
          'address': 'X',
          'latitude': '38.1',
          'longitude': '29.1',
          'usableForProximity': false,
        },
      }),
    );
    expect(task.status, TaskStatus.assigned);
    expect(task.usableForProximity, isFalse);
    expect(task.lat, 0);
    expect(task.lng, 0);
  });

  test('statü kodları', () {
    expect(taskStatusFromJetdiji('5010'), TaskStatus.delivered);
    expect(taskStatusFromJetdiji('5110'), TaskStatus.failed);
    expect(taskStatusFromJetdiji('6010'), TaskStatus.queued);
    expect(taskStatusFromJetdiji('8010'), TaskStatus.cancelled);
    expect(taskStatusFromJetdiji('8030'), TaskStatus.cancelled);
    expect(taskStatusFromJetdiji('CREATED'), TaskStatus.assigned);
  });

  test('schemaReady false sahte duyuru üretmez', () {
    final json = {
      'schemaReady': false,
      'announcements': [
        {'title': 'sahte'},
      ],
      'operationalAlerts': [
        {'title': 'gerçek'},
      ],
    };
    expect(readyItems(json, 'announcements'), isEmpty);
    expect(readyItems(json, 'operationalAlerts'), hasLength(1));
  });

  test('kurye 51 uç, başlıklar ve teslim gövdesi', () async {
    final tape = _Tape();
    final api = JetDijiCourierApi.forTest(tape.dio);
    final login = await api.login(identifier: 'K1', password: 'secret');
    expect(login.accessToken, 'courier-token');
    expect(login.courier?.fullName, 'Ruken Turhan');

    await api.logout();
    await api.http.tokens.save('courier-token', null);
    await api.session();
    await api.activatePreview('act');
    await api.activate(
      token: 'act',
      password: 'a',
      passwordConfirmation: 'a',
    );
    await api.changePassword(
      currentPassword: 'a',
      password: 'b',
      passwordConfirmation: 'b',
    );
    await api.dashboard();
    final tasks = await api.tasks();
    expect(tasks.tasks.single.recipientPhoneMasked, contains('•••'));
    await api.deliveryReasons();
    await api.taskDetail('shp-1', locale: 'tr');
    await api.callRecipient('shp-1');
    await api.acceptTask('shp-1');
    await api.startTask('shp-1', latitude: 1, longitude: 2);
    await expectLater(
      api.sendLocation(
        'shp-1',
        latitude: 1,
        longitude: 2,
        purposeCode: 'ACTIVE_TASK',
        capturedAt: DateTime.utc(2020).toIso8601String(),
      ),
      throwsA(
        isA<JetDijiException>().having(
          (e) => e.code,
          'code',
          'LOCATION_NOT_FRESH',
        ),
      ),
    );
    await api.sendLocation(
      'shp-1',
      latitude: 1,
      longitude: 2,
      purposeCode: 'ACTIVE_TASK',
    );
    await api.requirements('shp-1');
    final otp = await api.sendOtp('shp-1');
    expect(otp.devCode, '111111');
    final verified = await api.verifyOtp(
      'shp-1',
      challengeId: otp.challengeId,
      code: '111111',
    );
    expect(verified.evidenceId, 'ev1');
    await api.saveForm('shp-1', formVersionId: 'fv', status: 'SUBMITTED');
    try {
      await api.finalize('shp-1', resultCode: 'DELIVERED');
    } on JetDijiException catch (e) {
      expect(e.code, 'DELIVERY_REQUIREMENTS_MISSING');
    }
    await api.listEvidence('shp-1');
    await api.uploadEvidence('shp-1', textValue: 'not', evidenceType: 'NOTE');
    await api.voidEvidence('shp-1', 'ev1');
    expect(await api.downloadEvidenceFile('shp-1', 'ev1'), [9, 9]);
    await api.listReports('shp-1');
    await api.createReport(
      'shp-1',
      body: const {'category': 'DAMAGE', 'note': 'kutu'},
    );
    await api.custodyPending();
    await api.acceptCustody(scanCode: 'DGO-1', scanType: 'BARCODE');
    await api.custodyOverview();
    await api.returnCustody(scannedValues: const ['DGO-1']);
    await api.custodyHistory();
    await api.profile();
    await api.saveIban('TR00');
    await api.profileSummary();
    await api.changeRequests();
    await api.createChangeRequest(const {'field': 'phone'});
    await api.cancelChangeRequest('req-1');
    await api.supportCases();
    await api.createSupportCase(const {'topic': 'x'});
    await api.availability();
    await api.saveAvailability(const {'status': 'AVAILABLE'});
    await api.contracts();
    await api.documents();
    await api.application();
    await api.consents();
    await api.checkPhone('+905320000026');
    await api.submitApplication(const {'phone': '+905320000026'});
    await api.documentPack('pub-1');
    await api.uploadApplicationDocument(
      publicId: 'pub-1',
      documentRequestId: 'doc-1',
      bytes: const [1],
      filename: 'a.jpg',
    );
    await api.submitDocuments('pub-1');
    final cities = await api.cities();
    expect(cities.single.name, 'Denizli');
    final districts = await api.districts(20);
    expect(districts.single.code, isNull);

    expect(tape.calls.map((c) => '${c.method} ${c.uri.path}').toSet(), hasLength(51));
    final loginCall = tape.calls.first;
    expect(loginCall.headers['X-Client-Type'], 'mobile');
    expect(loginCall.headers['Authorization'], isNull);
    final sessionCall = tape.calls.firstWhere((c) => c.path.endsWith('/session'));
    expect(sessionCall.headers['Authorization'], 'Bearer courier-token');
    final citiesCall = tape.calls.firstWhere((c) => c.path.endsWith('/cities'));
    expect(citiesCall.headers['Authorization'], isNull);
    final finalize = tape.calls.firstWhere((c) => c.path.endsWith('/finalize'));
    expect(finalize.headers['Idempotency-Key'], isNotEmpty);
    final body = finalize.data as Map;
    expect(body['resultCode'], 'DELIVERED');
    expect(body.containsKey('outcome'), isFalse);
    expect(body.containsKey('receivedBy'), isFalse);
    expect(
      tape.paths.where((p) => p.endsWith('/location')),
      hasLength(1),
    );
  });

  test('şube 48 uç, 409, zimmet, harita ve kurye listesi', () async {
    final tape = _Tape();
    final api = JetDijiBranchApi.forTest(tape.dio);
    await expectLater(
      api.login(email: 'a@b.c', password: 'pw'),
      throwsA(
        isA<JetDijiException>()
            .having((e) => e.code, 'code', 'AGENCY_SELECTION_REQUIRED')
            .having((e) => e.agencies.single.id, 'agency', 'ag1'),
      ),
    );
    final login = await api.login(
      email: 'a@b.c',
      password: 'pw',
      agencyId: 'ag1',
    );
    expect(login.accessToken, 'branch-token');
    await api.session();
    await api.dashboard();
    await api.preparation();
    await api.printRows(const ['shp-1']);
    await api.dispatchOptions();
    final handover = await api.handover(
      courierId: 'c-9',
      shipmentIds: const ['shp-1'],
    );
    expect(handover['replayed'], isTrue);
    await api.changeHandover(courierId: 'c-9', shipmentIds: const ['shp-1']);
    await api.reassignOptions('shp-1');
    await api.reassign(shipmentId: 'shp-1', courierId: 'c-9');
    await api.dispatchBoard();
    await api.courierJobs();
    await api.cancelHandover(shipmentId: 'shp-1', reasonCode: 'CHANGED');
    final map = await api.courierMap();
    expect(map.couriers.single.liveStatus, 'ACTIVE');
    expect(map.couriers.single.latitude, 38.15);
    expect(map.total, 1);
    await api.pending();
    await api.scanCourierReturn(scanCode: 'DGO-1');
    await api.incomingTransfers();
    await api.incomingTransfer('tr-1');
    await api.scanIncoming(scanCode: 'DGO-1');
    await api.acceptIncoming('tr-1');
    await api.confirmIncoming('tr-1');
    await api.outgoingOptions();
    await api.sendOutgoing(const {
      'transferType': 'TO_CENTER',
      'destinationWarehouseId': 'wh-1',
      'lines': [
        {'shipmentId': 'shp-1', 'barcodes': ['DGO-1']},
      ],
    });
    await api.resolveOutgoing(scanCode: 'DGO-1');
    await api.labels();
    await api.labelAction(const {'action': 'print'});
    await api.counts();
    await api.startCount();
    await api.countDetail('cnt-1');
    await api.countAction('cnt-1', const {'action': 'scan', 'barcode': 'DGO-1'});
    await api.smsTemplates();
    await api.smsTargets();
    await api.smsPreview(const {'templateId': 't'});
    await api.smsSend(const {'templateId': 't'}, idempotencyKey: 'sms-1');
    await api.smsHistory();
    final announcements = await api.announcements();
    expect(readyItems(announcements, 'announcements'), isEmpty);
    await api.training();
    await api.performance();
    final invoices = await api.invoices();
    expect(readyItems(invoices, 'invoices'), isEmpty);
    expect(readyItems(invoices, 'supportCases'), hasLength(1));
    await api.invoiceSupport(const {'invoiceId': 'i'});
    final compliance = await api.compliance();
    expect(readyItems(compliance, 'contracts'), isEmpty);
    await api.createCard(const {'holder': 'A'});
    await api.verifyCard('tok');
    final couriers = await api.couriers();
    expect(couriers.single.assignmentId, 'asg-1');
    expect(couriers.single.courierId, 'c-9');
    expect(couriers.single.fullName, 'Ali Kaya');
    expect(couriers.single.shipmentCount, 3);
    await api.regions();
    await api.warehouses();
    await api.overview();
    await api.logout();

    expect(tape.calls.map((c) => '${c.method} ${c.uri.path}').toSet(), hasLength(48));
    final handoverCall = tape.calls.firstWhere(
      (c) => c.path.endsWith('/handover') && c.method == 'POST',
    );
    expect(handoverCall.data, {
      'courierId': 'c-9',
      'shipmentIds': ['shp-1'],
    });
    expect(handoverCall.headers['X-Client-Type'], 'mobile');
    expect(handoverCall.headers['Idempotency-Key'], isNotEmpty);
    expect(handoverCall.headers['Authorization'], 'Bearer branch-token');
  });

  test('oturum teslimi resultCode ile gider, eksikte durum değişmez', () async {
    final tape = _Tape();
    final api = JetDijiCourierApi.forTest(tape.dio);
    await api.http.tokens.save('courier-token', null);
    final session = SessionController(jetdiji: api)
      ..jetdijiCourier = true
      ..demo = false;
    session.tasks.add(
      DeliveryTask(
        id: 'shp-1',
        ref: 'DGO-100',
        recipient: 'Ayşe',
        address: 'X',
        window: '—',
        kind: TaskKind.delivery,
        status: TaskStatus.inProgress,
      ),
    );
    final missing = await session.deliverTask(
      'shp-1',
      receivedBy: 'Ayşe',
      receiverType: 'SELF',
    );
    expect(missing, isFalse);
    expect(session.taskById('shp-1').status, TaskStatus.inProgress);
    expect(session.lastJetdijiError, 'DELIVERY_REQUIREMENTS_MISSING');

    tape.mode = _Mode.ok;
    final ok = await session.deliverTask(
      'shp-1',
      receivedBy: 'Ayşe',
      receiverType: 'SELF',
      receivedRelationCode: 'SELF',
    );
    expect(ok, isTrue);
    expect(session.taskById('shp-1').status, TaskStatus.delivered);
    final bodies = tape.calls
        .where((c) => c.path.endsWith('/finalize'))
        .map((c) => c.data as Map)
        .toList();
    expect(bodies.last['resultCode'], 'DELIVERED');
    expect(bodies.last.containsKey('outcome'), isFalse);
    expect(bodies.first['Idempotency-Key'] ?? bodies, isNotNull);
    expect(
      tape.calls
          .where((c) => c.path.endsWith('/finalize'))
          .map((c) => c.headers['Idempotency-Key'])
          .toSet(),
      hasLength(2),
    );
  });
}

enum _Mode { missingThenOk, ok }

class _Tape {
  _Tape() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          calls.add(options);
          final status = _status(options);
          if (options.path.endsWith('/finalize') && status == 422) {
            finalizeCount = 1;
          }
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: status,
              data: _body(options, status),
            ),
          );
        },
      ),
    );
  }

  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api-mobile.preprod.jetdiji.com',
      validateStatus: (code) => code != null && code < 600,
    ),
  );
  final calls = <RequestOptions>[];
  var mode = _Mode.missingThenOk;
  var finalizeCount = 0;

  List<String> get paths => calls.map((c) => c.uri.path).toList();

  int _status(RequestOptions options) {
    if (options.path.endsWith('/agency-auth/login') && options.data is Map) {
      final body = options.data as Map;
      if (body['agencyId'] == null) return 409;
    }
    if (options.path.endsWith('/finalize') &&
        mode == _Mode.missingThenOk &&
        finalizeCount == 0) {
      return 422;
    }
    return 200;
  }

  Object? _body(RequestOptions options, int status) {
    final path = options.uri.path;
    if (path.endsWith('/file')) return <int>[9, 9];
    if (path.endsWith('/agency-auth/login') && status == 409) {
      return {
        'success': false,
        'code': 'LEGACY',
        'error': {
          'code': 'AGENCY_SELECTION_REQUIRED',
          'agencies': [
            {'id': 'ag1', 'name': 'Güney', 'code': 'GNY'},
          ],
        },
      };
    }
    if (path.endsWith('/finalize') && status == 422) {
      return {
        'success': false,
        'error': {
          'code': 'DELIVERY_REQUIREMENTS_MISSING',
          'missing': [
            {'type': 'PHOTO', 'code': 'DOOR', 'required': 1, 'actual': 0},
          ],
        },
      };
    }
    return {
      'success': true,
      'meta': {
        'requestId': 'req',
        'timestamp': '2026-10-03T00:00:00Z',
        'apiVersion': 'v1',
      },
      'data': _data(path),
    };
  }

  Object? _data(String path) {
    if (path.endsWith('/cities')) {
      return [
        {'id': 20, 'code': '20', 'name': 'Denizli'},
      ];
    }
    if (path.endsWith('/districts')) {
      return [
        {'id': 1, 'cityId': 20, 'code': null, 'name': 'Güney'},
      ];
    }
    if (path.endsWith('/courier-auth/login')) {
      return {
        'accessToken': 'courier-token',
        'expiresAt': '2026-10-04T00:00:00Z',
        'id': 'c1',
        'courierCode': 'K1',
        'fullName': 'Ruken Turhan',
      };
    }
    if (path.endsWith('/agency-auth/login')) {
      return {
        'accessToken': 'branch-token',
        'expiresAt': '2026-10-04T00:00:00Z',
        'user': {'firstName': 'Ayşe', 'lastName': 'Demir', 'email': 'a@b.c'},
        'agency': {'id': 'ag1', 'name': 'Güney'},
      };
    }
    if (path.endsWith('/agency-auth/session')) {
      return {
        'user': {
          'id': 'u1',
          'fullName': 'Ayşe Demir',
          'agency': {'id': 'ag1', 'name': 'Güney'},
          'capabilities': {'operate': true, 'manage': false},
        },
      };
    }
    if (path.endsWith('/courier-dashboard')) {
      return {
        'counts': {'awaitingDelivery': 2, 'overdue': 1},
      };
    }
    if (path.endsWith('/courier-tasks')) {
      return {
        'tasks': [
          {
            'id': 'shp-1',
            'shipmentNumber': 'DGO-100',
            'statusCode': '4010',
            'recipientName': 'Ayşe',
            'recipientPhoneMasked': '+90 532 ••• •• 26',
            'destination': {
              'address': 'Kayalık',
              'latitude': '38.15',
              'longitude': '29.06',
              'usableForProximity': true,
            },
          },
        ],
        'statuses': ['4010'],
      };
    }
    if (path.endsWith('/delivery-reasons')) {
      return {
        'delivered': [
          {'code': 'SELF', 'name': 'Kendisi'},
        ],
        'failed': [
          {'code': 'ABSENT', 'name': 'Adreste yok'},
        ],
      };
    }
    if (path.endsWith('/otp')) {
      return {'challengeId': 'ch-1', 'devCode': '111111', 'channel': 'DEV_LOG'};
    }
    if (path.endsWith('/otp/verify')) {
      return {'verified': true, 'evidenceId': 'ev1'};
    }
    if (path.endsWith('/finalize')) {
      return {'alreadyFinalized': false, 'resultCode': 'DELIVERED'};
    }
    if (path.endsWith('/branch/dashboard')) {
      return {
        'kpis': {
          'todayToDeliver': 4,
          'deliveredToday': 1,
          'cancelledToday': 9,
          'pending': 2,
          'returnToCenter': 1,
          'urgent': 3,
        },
        'couriers': {'active': 2, 'total': 5},
      };
    }
    if (path.endsWith('/branch/dispatch')) {
      return {
        'kpis': {'assigned': 2, 'unassigned': 1},
        'rows': [
          {'shipmentId': 'shp-1', 'stage': 'IN_DISTRIBUTION'},
        ],
      };
    }
    if (path.endsWith('/handover')) {
      return {'replayed': true};
    }
    if (path.endsWith('/courier-map')) {
      return {
        'couriers': [
          {
            'id': 'c-9',
            'name': 'Ali Kaya',
            'liveStatus': 'ACTIVE',
            'location': {'latitude': 38.15, 'longitude': 29.06},
            'holdingCount': 1,
            'overdueCount': 0,
            'shipments': [
              {
                'shipmentId': 'shp-1',
                'shipmentNumber': 'DGO-100',
                'recipientName': 'Ayşe',
              },
            ],
          },
        ],
        'summary': {
          'total': 1,
          'withLocation': 1,
          'shipmentsInHand': 1,
          'overdue': 0,
        },
      };
    }
    if (path.endsWith('/agency/couriers')) {
      return {
        'summary': {'total': 1},
        'items': [
          {
            'id': 'asg-1',
            'shipmentCount': 3,
            'assignmentTypeCode': 'PRIMARY',
            'isPrimary': true,
            'statusCode': 'ACTIVE',
            'validFrom': '2026-01-01',
            'courier': {
              'id': 'c-9',
              'courierCode': 'K9',
              'fullName': 'Ali Kaya',
              'phone': '+90555',
              'status': 'AVAILABLE',
            },
          },
        ],
      };
    }
    if (path.endsWith('/announcements') || path.endsWith('/training')) {
      return {
        'schemaReady': false,
        'announcements': [
          {'title': 'sahte'},
        ],
        'operationalAlerts': [
          {'title': 'gerçek'},
        ],
      };
    }
    if (path.endsWith('/invoices')) {
      return {
        'schemaReady': false,
        'invoices': [
          {'id': 'sahte'},
        ],
        'supportCases': [
          {'id': 'case-1'},
        ],
      };
    }
    if (path.endsWith('/compliance')) {
      return {
        'schemaReady': false,
        'contracts': [
          {'status': 'NOT_AVAILABLE'},
        ],
        'documents': [
          {'status': 'NOT_AVAILABLE'},
        ],
      };
    }
    if (path.endsWith('/preparation')) {
      return {
        'rows': [
          {
            'shipmentId': 'shp-2',
            'shipmentNumber': 'DGO-200',
            'stage': 'AWAITING_COURIER',
            'recipientName': 'Ali',
          },
        ],
      };
    }
    return const <String, dynamic>{};
  }
}
