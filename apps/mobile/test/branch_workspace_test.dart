import 'package:dijigoo_kurye/api/agency_client.dart';
import 'package:dijigoo_kurye/api/agency_models.dart';
import 'package:dijigoo_kurye/api/branch_models.dart';
import 'package:dijigoo_kurye/branch_workspace.dart';
import 'package:dijigoo_kurye/data/outbox.dart';
import 'package:dijigoo_kurye/models.dart';
import 'package:dijigoo_kurye/scan_router.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Call = ({String method, String path, Map body, String? key});

/// Şube Mobil API'sinin (`swagger/branch.yaml`) zarfıyla konuşan sahte sunucu.
/// [respond] bir `data` gövdesi döner; [AgencyApiException] fırlatırsa aynı
/// kod/HTTP durumu ile hata zarfı üretilir, `offline` iken bağlantı kopar.
class _Server {
  _Server(this.respond);

  Object? Function(_Call call) respond;
  bool offline = false;
  final calls = <_Call>[];

  List<_Call> to(String suffix) => [
    for (final c in calls)
      if (c.path.endsWith(suffix)) c,
  ];

  AgencyPortalApi get api {
    final dio = Dio(BaseOptions(baseUrl: 'http://branch.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final call = (
            method: options.method,
            path: options.path,
            body: options.data is Map ? options.data as Map : const {},
            key: options.headers['Idempotency-Key'] as String?,
          );
          calls.add(call);
          if (offline) {
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              ),
            );
          }
          try {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {'success': true, 'data': respond(call)},
              ),
            );
          } on AgencyApiException catch (e) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: e.statusCode,
                  data: {
                    'success': false,
                    'code': e.code,
                    'error': {
                      'code': e.code,
                      'message': ?e.serverMessage,
                      'shipmentNumber': ?e.shipmentNumber,
                    },
                  },
                ),
              ),
            );
          }
        },
      ),
    );
    return AgencyPortalApi(dio);
  }
}

Map<String, dynamic> _row(String id, String number, String stage) => {
  'shipmentId': id,
  'shipmentNumber': number,
  'stage': stage,
  'recipientName': 'Alıcı $id',
};

const _openCount = {
  'count': {
    'id': 'count-1',
    'number': 'SAY-1',
    'statusCode': 'IN_PROGRESS',
    'warehouse': {'name': 'Depo'},
  },
  'lines': <Object>[],
};

Object? _defaults(_Call c) {
  if (c.path.endsWith('/branch/dashboard')) {
    return {
      'branch': {'name': 'Kadıköy Şube'},
      'kpis': {'todayToDeliver': 4},
    };
  }
  if (c.path.endsWith('/branch/dispatch')) {
    return {
      'capabilities': {'operate': true, 'manage': false},
      'rows': [
        _row('s1', 'JD100', 'AWAITING_COURIER'),
        _row('s2', 'JD200', 'IN_DISTRIBUTION'),
      ],
    };
  }
  if (c.path.endsWith('/branch/pending')) return <String, Object>{};
  if (c.path.endsWith('/branch/counts')) {
    return {'openCount': _openCount['count'], 'warehouses': <Object>[]};
  }
  if (c.path.endsWith('/branch/counts/count-1')) {
    if (c.method == 'GET') return _openCount;
    return {'resultCode': 'OK', 'scanId': 'scan'};
  }
  return <String, Object>{};
}

({BranchWorkspace branch, OutboxStore outbox, _Server server}) _setup([
  Object? Function(_Call call)? respond,
]) {
  final server = _Server(respond ?? _defaults);
  final outbox = OutboxStore();
  var n = 0;
  final branch = BranchWorkspace(
    outbox: outbox,
    api: server.api,
    onChanged: () {},
    newId: () => 'id-${++n}',
  );
  return (branch: branch, outbox: outbox, server: server);
}

void main() {
  group('yükleme', () {
    test(
      'canlıda sunucu verisi gelir, yetki gönderi listesinden okunur',
      () async {
        final t = _setup();
        await t.branch.refresh();
        expect(t.branch.dashboard?.branchName, 'Kadıköy Şube');
        expect(t.branch.dashboard?.todayToDeliver, 4);
        expect(t.branch.rows, hasLength(2));
        expect(t.branch.capabilities.operate, isTrue);
        expect(t.branch.error, isNull);
        expect(t.branch.syncedAt, isNotNull);
      },
    );

    test('sunucu düşerse örnek veriye düşülmez, hata gösterilir', () async {
      final t = _setup();
      t.server.offline = true;
      await t.branch.refresh();
      expect(t.branch.dashboard, isNull);
      expect(t.branch.rows, isEmpty);
      expect(t.branch.error, isNotNull);
      expect(t.branch.syncedAt, isNull);
    });

    test('demo girişte örnek veri sunucuya gitmeden yüklenir', () async {
      final t = _setup();
      t.branch.demo = true;
      await t.branch.refresh();
      expect(t.branch.dashboard?.branchName, 'Güney Acente');
      expect(t.server.calls, isEmpty);
    });
  });

  group('sayım okutması (offline kuyruk)', () {
    test('çevrimdışı okutmalar sırayla kuyruklanır ve aynı kimlikle gider', () async {
      final t = _setup();
      await t.branch.loadCounts();
      expect(t.branch.count?.count.scannable, isTrue);

      t.server.offline = true;
      final a = await t.branch.scan(ScanContext.count, 'BARKOD-A');
      final b = await t.branch.scan(ScanContext.count, 'BARKOD-B');
      expect(a.tone, ScanTone.warn);
      expect(b.tone, ScanTone.warn);
      expect(t.branch.pendingScans, 2);
      // A gitmeden B denenmez: sıra bozulmaz.
      final offlineScans = [
        for (final c in t.server.to('/branch/counts/count-1'))
          if (c.method == 'POST') c.body['barcode'],
      ];
      expect(offlineScans, everyElement('BARKOD-A'));

      t.server
        ..offline = false
        ..calls.clear();
      await t.branch.flush();
      final sent = t.server.to('/branch/counts/count-1');
      expect(
        [for (final c in sent) c.body['barcode']],
        ['BARKOD-A', 'BARKOD-B'],
      );
      // Yeniden denemede aynı clientScanId + Idempotency-Key: çift sayım olmaz.
      expect([for (final c in sent) c.body['clientScanId']], ['id-1', 'id-2']);
      expect([for (final c in sent) c.key], ['id-1', 'id-2']);
      expect(t.branch.pendingScans, 0);
      expect(t.outbox.events.every((e) => e.status == 'applied'), isTrue);
      expect(
        t.outbox.events.every(
          (e) => e.operation == SyncOperation.branchCountScan,
        ),
        isTrue,
      );
    });

    test('mükerrer seri "Daha önce sayıldı" olarak döner', () async {
      final t = _setup((c) {
        if (c.method == 'POST' && c.path.endsWith('/counts/count-1')) {
          return {'resultCode': 'DUPLICATE_SERIAL', 'scanId': 'x'};
        }
        return _defaults(c);
      });
      await t.branch.loadCounts();
      final outcome = await t.branch.scan(ScanContext.count, 'SERI-1');
      expect(outcome.tone, ScanTone.warn);
      expect(outcome.title, 'Daha önce sayıldı');
      expect(t.branch.pendingScans, 0);
    });

    test('kalıcı ret kuyrukta beklemez, yeniden gönderilmez', () async {
      final t = _setup((c) {
        if (c.method == 'POST' && c.path.endsWith('/counts/count-1')) {
          throw AgencyApiException(
            'COUNT_OPERATION_REJECTED',
            statusCode: 409,
            serverMessage: 'Sayım kapatılmış.',
          );
        }
        return _defaults(c);
      });
      await t.branch.loadCounts();
      final outcome = await t.branch.scan(ScanContext.count, 'X');
      expect(outcome.tone, ScanTone.bad);
      expect(outcome.title, 'Sayım kapatılmış.');
      expect(t.outbox.events.single.status, 'rejected');
      t.server.calls.clear();
      await t.branch.flush();
      expect(t.server.calls, isEmpty);
    });

    test('bekleyen okutma varken sayım tamamlanamaz', () async {
      final t = _setup();
      await t.branch.loadCounts();
      t.server.offline = true;
      await t.branch.scan(ScanContext.count, 'BARKOD-A');
      final error = await t.branch.closeCount();
      expect(error, contains('1 okutma'));
      expect(t.server.calls.any((c) => c.body['action'] == 'close'), isFalse);
    });

    test('duraklatılmış sayım okutma kabul etmez', () async {
      final t = _setup();
      await t.branch.loadCounts();
      t.branch.setCountPaused(true);
      final outcome = await t.branch.scan(ScanContext.count, 'X');
      expect(outcome.tone, ScanTone.warn);
      expect(t.outbox.events, isEmpty);
    });

    test('açık sayım yokken okutma reddedilir', () async {
      final t = _setup();
      final outcome = await t.branch.scan(ScanContext.count, 'X');
      expect(outcome.tone, ScanTone.bad);
      expect(t.outbox.events, isEmpty);
    });
  });

  group('zimmet', () {
    test('okutma yalnız zimmet bekleyen gönderiyi seçer', () async {
      final t = _setup();
      await t.branch.refresh();
      expect((await t.branch.scan(ScanContext.assign, ' jd100 ')).ok, isTrue);
      expect(t.branch.picked, {'s1'});
      // İkinci okutma mükerrer.
      expect(
        (await t.branch.scan(ScanContext.assign, 'JD100')).tone,
        ScanTone.warn,
      );
      // Dağıtımdaki gönderi zimmete eklenemez.
      expect(
        (await t.branch.scan(ScanContext.assign, 'JD200')).tone,
        ScanTone.warn,
      );
      // Başka şubenin / listede olmayan barkod.
      expect(
        (await t.branch.scan(ScanContext.assign, 'YOK')).tone,
        ScanTone.bad,
      );
      expect(t.branch.picked, {'s1'});
    });

    test('atama geçici hatada aynı anahtarla yeniden denenir', () async {
      final t = _setup();
      await t.branch.refresh();
      t.branch.togglePick('s1');
      const courier = CourierOption(id: 'c1', name: 'Ali');

      t.server.offline = true;
      expect(await t.branch.assignPicked(courier), isNotNull);
      expect(t.branch.picked, {
        's1',
      }, reason: 'başarısız atamada seçim korunur');

      t.server.offline = false;
      expect(await t.branch.assignPicked(courier), isNull);
      final sent = t.server.to('/branch/dispatch/handover');
      expect(sent, hasLength(2));
      expect(sent[0].key, isNotNull);
      expect(sent[1].key, sent[0].key);
      expect(sent[1].body['shipmentIds'], ['s1']);
      expect(t.branch.picked, isEmpty);
    });

    test('sunucu reddi Türkçe mesajı ve gönderi numarasını taşır', () async {
      final t = _setup((c) {
        if (c.path.endsWith('/dispatch/handover')) {
          throw AgencyApiException(
            'HANDOVER_ALREADY_PENDING',
            statusCode: 409,
            serverMessage: 'Gönderi zaten kabul bekliyor.',
            shipmentNumber: 'JD100',
          );
        }
        return _defaults(c);
      });
      await t.branch.refresh();
      t.branch.togglePick('s1');
      final error = await t.branch.assignPicked(
        const CourierOption(id: 'c1', name: 'Ali'),
      );
      expect(error, 'Gönderi zaten kabul bekliyor. (JD100)');
    });

    test(
      'dağıtımdaki gönderide reassign, kabul bekleyende change çağrılır',
      () async {
        final t = _setup();
        const courier = CourierOption(id: 'c2', name: 'Mert');
        await t.branch.changeCourier(
          const BranchShipmentRow(
            shipmentId: 's2',
            shipmentNumber: 'JD200',
            stage: BranchStage.inDistribution,
          ),
          courier,
          note: 'Araç arızası',
        );
        await t.branch.changeCourier(
          const BranchShipmentRow(
            shipmentId: 's3',
            shipmentNumber: 'JD300',
            stage: BranchStage.inQueue,
          ),
          courier,
        );
        final reassign = t.server.to('/dispatch/reassign').single;
        expect(reassign.body, {
          'shipmentId': 's2',
          'courierId': 'c2',
          'note': 'Araç arızası',
        });
        final change = t.server.to('/dispatch/handover/change').single;
        expect(change.body['shipmentIds'], ['s3']);
      },
    );
  });

  group('merkeze sevk', () {
    Object? resolve(_Call c) {
      if (c.path.endsWith('/outgoing/resolve')) {
        final code = c.body['scannedValue'] as String;
        if (code.startsWith('KOLI')) {
          return {'kind': 'PACKAGE', 'barcode': code, 'labelTypeCode': 'CASE'};
        }
        return {
          'kind': 'SHIPMENT',
          'barcode': code,
          'sourceKey': code.startsWith('B-') ? 'kaynak-b' : 'kaynak-a',
          'shipment': {'id': 'ship-$code', 'shipmentNumber': code},
        };
      }
      if (c.path.endsWith('/transfers/outgoing') && c.method == 'POST') {
        return {'transferNumber': 'TRF-1', 'itemCount': 1, 'packageCount': 1};
      }
      return _defaults(c);
    }

    test(
      'taslak gönderi + koliyle toplanır, tek transfer olarak gider',
      () async {
        final t = _setup(resolve);
        expect((await t.branch.scan(ScanContext.dispatch, 'A-1')).ok, isTrue);
        expect(
          (await t.branch.scan(ScanContext.dispatch, 'KOLI-9')).ok,
          isTrue,
        );
        expect(
          (await t.branch.scan(ScanContext.dispatch, 'A-1')).tone,
          ScanTone.warn,
          reason: 'mükerrer okutma',
        );
        expect(
          (await t.branch.scan(ScanContext.dispatch, 'B-1')).tone,
          ScanTone.bad,
          reason: 'farklı zimmet kaynağı aynı transfere girmez',
        );
        expect(t.branch.draft, hasLength(2));

        final error = await t.branch.sendDraft(
          transferType: 'RETURN',
          centerId: 'hq',
        );
        expect(error, isNull);
        final sent = t.server.calls.singleWhere(
          (c) => c.method == 'POST' && c.path.endsWith('/transfers/outgoing'),
        );
        expect(sent.key, isNotNull);
        expect(sent.body['transferType'], 'RETURN');
        expect(sent.body['destinationWarehouseId'], 'hq');
        expect(sent.body['lines'], [
          {
            'shipmentId': 'ship-A-1',
            'barcodes': ['A-1'],
          },
        ]);
        expect(sent.body['packageBarcodes'], ['KOLI-9']);
        expect(t.branch.draft, isEmpty);
      },
    );

    test('yalnız koliyle transfer gönderilmez', () async {
      final t = _setup(resolve);
      await t.branch.scan(ScanContext.dispatch, 'KOLI-1');
      final error = await t.branch.sendDraft(
        transferType: 'RETURN',
        centerId: 'hq',
      );
      expect(error, isNotNull);
      expect(t.branch.draft, hasLength(1));
    });
  });

  test('kurye dönüşü okutması kuyruktan gider ve listeyi yeniler', () async {
    final t = _setup((c) {
      if (c.path.endsWith('/courier-return-scan')) {
        return {
          'shipmentNumber': 'JD500',
          'redelivery': {'applied': true},
        };
      }
      return _defaults(c);
    });
    final outcome = await t.branch.scan(ScanContext.courierReturn, 'JD500');
    expect(outcome.ok, isTrue);
    expect(outcome.detail, contains('yeniden dağıtıma'));
    final sent = t.server.to('/courier-return-scan').single;
    expect(sent.body['scanCode'], 'JD500');
    expect(sent.key, 'id-1');
    expect(t.outbox.events.single.operation, SyncOperation.branchReturnScan);
    expect(t.server.to('/branch/pending'), hasLength(1));
  });

  group('etiket', () {
    Object? labels(_Call c) {
      if (c.path.endsWith('/branch/labels') && c.method == 'POST') {
        if (c.body['action'] == 'generate') {
          return {
            'labels': [
              {
                'id': 'l1',
                'barcode': 'KL-1',
                'labelTypeCode': 'CASE',
                'zpl': '^XA1^XZ',
              },
              {
                'id': 'l2',
                'barcode': 'KL-2',
                'labelTypeCode': 'CASE',
                'zpl': '^XA2^XZ',
              },
            ],
          };
        }
        return {'printed': 2};
      }
      return _defaults(c);
    }

    test('üretilen etiket yazıcıya gider, sonra basıldı işaretlenir', () async {
      final server = _Server(labels);
      final sent = <String>[];
      final branch = BranchWorkspace(
        outbox: OutboxStore(),
        api: server.api,
        onChanged: () {},
        sendZpl: (host, zpl) async => sent.add('$host|$zpl'),
      );
      expect(
        await branch.generateLabels(
          typeCode: 'CASE',
          quantity: 2,
          warehouseId: 'w1',
        ),
        isNull,
      );
      expect(branch.freshLabels, hasLength(2));
      final generate = server.calls.firstWhere(
        (c) => c.body['action'] == 'generate',
      );
      expect(generate.key, isNotNull);
      expect(generate.body.containsKey('shipmentReference'), isFalse);

      expect(
        await branch.printLabels(branch.freshLabels),
        contains('yazıcı adresini'),
      );
      branch.setPrinterHost(' 10.0.0.9 ');
      expect(await branch.printLabels(branch.freshLabels), isNull);
      expect(sent, ['10.0.0.9|^XA1^XZ', '10.0.0.9|^XA2^XZ']);
      final printed = server.calls.singleWhere(
        (c) => c.body['action'] == 'printed',
      );
      expect(printed.body['labelIds'], ['l1', 'l2']);
      expect(printed.body['printer'], '10.0.0.9');
    });

    test('yazıcıya ulaşılamazsa etiket basılmış sayılmaz', () async {
      final server = _Server(labels);
      final branch = BranchWorkspace(
        outbox: OutboxStore(),
        api: server.api,
        onChanged: () {},
        sendZpl: (host, zpl) async => throw StateError('bağlantı yok'),
      )..setPrinterHost('10.0.0.9');
      await branch.generateLabels(
        typeCode: 'CASE',
        quantity: 2,
        warehouseId: 'w1',
      );
      expect(
        await branch.printLabels(branch.freshLabels),
        contains('ulaşılamadı'),
      );
      expect(server.calls.any((c) => c.body['action'] == 'printed'), isFalse);
    });
  });

  test('gelen transfer: okut → içeri al → onayla', () async {
    Map<String, Object> detail(int scanned, int pending) => {
      'transfer': {
        'id': 't1',
        'transferNumber': 'TRF-9',
        'statusCode': 'ACCEPTANCE_PENDING',
        'itemCount': 2,
      },
      'lines': [
        {
          'id': 'a',
          'shipmentNumber': 'JD1',
          'state': scanned > 0 ? 'SCANNED' : 'PENDING',
        },
        {'id': 'b', 'shipmentNumber': 'JD2', 'state': 'PENDING'},
      ],
      'pendingScannedCount': scanned,
      'pendingCount': pending,
    };
    var scanned = 0;
    final t = _setup((c) {
      if (c.path.endsWith('/incoming/scan')) {
        scanned = 1;
        return {
          'action': 'SCANNED',
          'transferId': 't1',
          'transferNumber': 'TRF-9',
          'item': {'shipmentNumber': 'JD1'},
        };
      }
      if (c.path.endsWith('/incoming/t1')) return detail(scanned, 2 - scanned);
      if (c.path.endsWith('/t1/accept'))
        return {'accepted': 1, 'failed': <Object>[]};
      if (c.path.endsWith('/t1/confirm')) return {'accepted': 0, 'missing': 1};
      return _defaults(c);
    });
    await t.branch.openIncoming('t1');
    expect(t.branch.incomingDetail?.pendingScannedCount, 0);
    expect((await t.branch.scan(ScanContext.stockIn, 'JD1')).ok, isTrue);
    expect(t.branch.incomingDetail?.pendingScannedCount, 1);
    expect(t.branch.incomingDetail?.lines.first.state, 'SCANNED');

    final transfer = t.branch.incomingDetail!.transfer;
    expect(await t.branch.acceptIncoming(transfer), isNull);
    expect(await t.branch.confirmIncoming(transfer), isNull);
    expect(t.server.to('/t1/accept').single.key, isNotNull);
    expect(t.server.to('/t1/confirm').single.key, isNotNull);
  });

  test('performans seçilen aralıkla istenir, boş payda null kalır', () async {
    final t = _setup((c) {
      if (c.path.endsWith('/branch/performance')) {
        return {
          'range': '30d',
          'totals': {'attemptedShipments': 10, 'deliveredShipments': 8},
          'kpis': {
            'deliveryRate': {'value': 80.0, 'basis': 10},
            'slaCompliance': {'value': null, 'basis': 0},
          },
          'couriers': [
            {
              'courierId': 'c1',
              'fullName': 'Ali',
              'delivered': 8,
              'deliveryRate': 80,
            },
          ],
        };
      }
      return _defaults(c);
    });
    await t.branch.loadPerformance('30d');
    final p = t.branch.performance!;
    expect(p.range, '30d');
    expect(p.deliveryRate, 80.0);
    expect(p.slaCompliance, isNull);
    expect(p.couriers.single.name, 'Ali');
  });

  test('SMS önizlenir, aynı gönderim aynı anahtarla tekrar denenir', () async {
    final t = _setup((c) {
      if (c.path.endsWith('/sms/preview')) {
        return {
          'rendered': 'Merhaba',
          'recipientCount': 2,
          'reachableCount': 1,
        };
      }
      if (c.path.endsWith('/sms/send')) return {'recipientCount': 2};
      return _defaults(c);
    });
    const template = SmsTemplate(key: 'TPL', name: 'Şablon');
    final preview = await t.branch.previewSms(
      targetType: 'COURIERS',
      targetIds: ['c2', 'c1'],
      template: template,
    );
    expect(preview.rendered, 'Merhaba');
    expect(preview.reachableCount, 1);
    expect(t.server.to('/sms/preview').single.key, isNull);

    t.server.offline = true;
    expect(
      await t.branch.sendSms(
        targetType: 'COURIERS',
        targetIds: ['c2', 'c1'],
        template: template,
      ),
      isNotNull,
    );
    t.server.offline = false;
    expect(
      await t.branch.sendSms(
        targetType: 'COURIERS',
        targetIds: ['c1', 'c2'],
        template: template,
      ),
      isNull,
    );
    final sent = t.server.to('/sms/send');
    expect(sent, hasLength(2));
    expect(sent[1].key, sent[0].key, reason: 'alıcıya iki kez SMS çıkmaz');
    expect(sent[1].body['channel'], 'SMS');
    expect(sent[1].body['targetIds'], ['c1', 'c2']);
  });

  test('izin reddi neden ister; onay backend\'e karar olarak gider', () async {
    final t = _setup((c) {
      if (c.path.endsWith('/courier-leave-requests')) return <String, Object>{};
      return _defaults(c);
    });
    const request = LeaveRequest(id: 'lv1', courierName: 'Ece');
    expect(await t.branch.reviewLeave(request, approve: false), isNotNull);
    expect(t.server.calls, isEmpty);
    expect(
      await t.branch.reviewLeave(request, approve: false, note: 'Yoğun gün'),
      isNull,
    );
    final sent = t.server.to('/courier-leave-requests/lv1/review').single;
    expect(sent.body, {'decision': 'REJECT', 'note': 'Yoğun gün'});
    expect(sent.key, isNotNull);
  });

  test('duyuru başlık ve metinle yayımlanır', () async {
    final t = _setup();
    expect(
      await t.branch.publishAnnouncement(title: ' ', body: 'x'),
      isNotNull,
    );
    expect(t.server.calls, isEmpty);
    expect(
      await t.branch.publishAnnouncement(
        title: 'Depo',
        body: 'Yarın 08:00',
        requiresAck: true,
      ),
      isNull,
    );
    final sent = t.server.calls.firstWhere((c) => c.method == 'POST');
    expect(sent.path, endsWith('/branch/announcements'));
    expect(sent.body['title'], 'Depo');
    expect(sent.body['requiresAck'], isTrue);
    expect(sent.body['publish'], isTrue);
    expect(sent.key, isNotNull);
  });

  test(
    'sayım yönetici işlemleri: elle giriş neden ister, onay sayımı kapatır',
    () async {
      var posted = false;
      final t = _setup((c) {
        if (c.method == 'POST' && c.path.endsWith('/counts/count-1')) {
          if (c.body['action'] == 'post') posted = true;
          return {'result': null};
        }
        if (c.path.endsWith('/branch/counts') && posted) {
          return {'openCount': null, 'warehouses': <Object>[]};
        }
        return _defaults(c);
      });
      await t.branch.loadCounts();
      expect(
        await t.branch.countManual(barcode: 'B1', quantity: 5, reasonNote: 'x'),
        isNotNull,
      );
      expect(
        await t.branch.countManual(
          barcode: 'B1',
          quantity: 5,
          reasonNote: 'Etiket okunmuyor',
        ),
        isNull,
      );
      final manual = t.server.calls.firstWhere(
        (c) => c.body['action'] == 'manual',
      );
      expect(manual.body['quantity'], 5);
      expect(manual.body['reasonNote'], 'Etiket okunmuyor');
      expect(manual.body['clientScanId'], isNotNull);

      expect(await t.branch.postCount(), isNull);
      expect(t.branch.count, isNull);
    },
  );

  test('401 oturumu kapatır', () async {
    var expired = 0;
    final server = _Server((c) {
      throw AgencyApiException('UNAUTHENTICATED', statusCode: 401);
    });
    final branch = BranchWorkspace(
      outbox: OutboxStore(),
      api: server.api,
      onChanged: () {},
      onSessionExpired: () => expired++,
    );
    await branch.loadCounts();
    expect(expired, 1);
  });
}
