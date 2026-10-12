import 'dart:async';
import 'dart:convert';

import 'api/agency_client.dart';
import 'api/agency_models.dart';
import 'api/branch_models.dart';
import 'data/outbox.dart';
import 'data/vault.dart';
import 'models.dart';
import 'scan_router.dart';
import 'screens/sube_demo.dart';
import 'zpl_printer.dart';

/// Şube/Acente rolünün çalışma durumu ve işlemleri: ana sayfa özeti,
/// gönderi/zimmet, kurye dönüşü, sayım, merkeze sevk. [SessionController]
/// bunu sahiplenir ve [onChanged] ile kendi dinleyicilerini uyarır.
///
/// Kural: sunucu teyidi gelmeden hiçbir işlem "tamamlandı" gösterilmez.
/// Okutmalar (sayım, kurye dönüşü) [OutboxStore]'a yazılır ve sırayla
/// gönderilir; atama / kurye değişikliği / sevk yalnız çevrimiçi çalışır.
class BranchWorkspace {
  BranchWorkspace({
    required this.outbox,
    required this.onChanged,
    this.api,
    this.onSessionExpired,
    this.vault,
    String Function()? newId,
    Future<void> Function(String host, String zpl)? sendZpl,
  }) : _newId = newId ?? Vault.newUuid,
       _sendZpl = sendZpl ?? sendZplToPrinter {
    router
      ..register(ScanContext.lookup, _scanLookup)
      ..register(ScanContext.assign, _scanAssign)
      ..register(ScanContext.courierReturn, _scanCourierReturn)
      ..register(ScanContext.stockIn, _scanStockIn)
      ..register(ScanContext.count, _scanCount)
      ..register(ScanContext.dispatch, _scanDispatch);
  }

  final OutboxStore outbox;
  final void Function() onChanged;
  final AgencyPortalApi? api;
  final void Function()? onSessionExpired;
  final Vault? vault;
  final String Function() _newId;
  final Future<void> Function(String host, String zpl) _sendZpl;
  final router = ScanRouter();

  static const _draftKey = 'dg.branch.dispatchDraft';
  static const _printerKey = 'dg.branch.printerHost';

  /// Demo giriş: sunucu yok, örnek veriyle çalışır. Canlı oturumda asla
  /// örnek veri gösterilmez.
  bool demo = false;

  BranchCapabilities capabilities = const BranchCapabilities();
  BranchDashboard? dashboard;
  DispatchBoard? board;
  PendingData? pending;
  CountsData? counts;
  CountDetail? count;
  OutgoingOptions? outgoing;
  IncomingTransfers? incoming;
  IncomingTransferDetail? incomingDetail;
  LabelWorkspace? labels;
  PerformanceData? performance;
  List<InboxItem>? inbox;
  int unreadNotifications = 0;
  AnnouncementsData? announcements;
  BranchShiftDay? shiftDay;
  List<LeaveRequest>? leaves;
  List<SmsTemplate>? smsTemplates;

  /// Bu oturumda üretilen, henüz basılmamış olabilecek etiketler.
  List<PrintableLabel> freshLabels = const [];

  /// Ağdaki Zebra yazıcının adresi (`ip` ya da `ip:port`).
  String printerHost = '';
  bool _restored = false;

  bool loading = false;

  /// Son yenilemede kullanıcıya gösterilecek hata; başarılı yenileme siler.
  String? error;
  DateTime? syncedAt;

  /// Zimmet için seçilen gönderi kimlikleri.
  final picked = <String>{};

  /// Merkeze sevk taslağı (henüz sunucuya gitmedi).
  final draft = <DispatchCandidate>[];

  bool countPaused = false;

  /// Bu oturumda okutulanlar, en yenisi başta.
  final recentScans = <({String code, ScanOutcome outcome})>[];

  final _actionKeys = <String, String>{};
  List<ReasonOption>? _cancelReasons;
  final _demoCounted = <String>{};

  int get pendingScans =>
      outbox.events.where((e) => e.pending && e.operation.isBranch).length;

  List<BranchShipmentRow> get rows => board?.rows ?? const [];

  List<BranchShipmentRow> get pickedRows => [
    for (final row in rows)
      if (picked.contains(row.shipmentId)) row,
  ];

  void reset() {
    demo = false;
    capabilities = const BranchCapabilities();
    dashboard = null;
    board = null;
    pending = null;
    counts = null;
    count = null;
    outgoing = null;
    incoming = null;
    incomingDetail = null;
    labels = null;
    performance = null;
    inbox = null;
    unreadNotifications = 0;
    announcements = null;
    shiftDay = null;
    leaves = null;
    smsTemplates = null;
    freshLabels = const [];
    _restored = false;
    error = null;
    syncedAt = null;
    countPaused = false;
    picked.clear();
    draft.clear();
    recentScans.clear();
    _actionKeys.clear();
    _cancelReasons = null;
    _demoCounted.clear();
  }

  /// Çıkışta cihazda saklanan taslağı da siler (başka kullanıcıya kalmasın).
  Future<void> clearStored() async {
    await vault?.deleteSecret(_draftKey);
  }

  /// Uygulama kapanıp açılınca merkeze sevk taslağı ve yazıcı adresi geri
  /// gelir. Taslak yalnız okutulmuş adaylardır; sunucuya gitmiş bir şey
  /// burada tutulmaz.
  Future<void> _restore() async {
    if (_restored) return;
    _restored = true;
    final store = vault;
    if (store == null) return;
    try {
      printerHost = await store.readSecret(_printerKey) ?? '';
      final raw = await store.readSecret(_draftKey);
      if (raw != null && raw.isNotEmpty && draft.isEmpty) {
        for (final row in jsonDecode(raw) as List) {
          if (row is Map) {
            draft.add(
              DispatchCandidate.fromJson(Map<String, dynamic>.from(row)),
            );
          }
        }
      }
    } catch (_) {
      // Bozuk kayıt taslağı engellemesin; boş taslakla devam edilir.
    }
  }

  void _saveDraft() {
    final store = vault;
    if (store == null) return;
    unawaited(
      draft.isEmpty
          ? store.deleteSecret(_draftKey)
          : store.writeSecret(
              _draftKey,
              jsonEncode([for (final c in draft) c.toJson()]),
            ),
    );
  }

  // ── Yükleme ────────────────────────────────────────────────────────────

  /// Ana sayfa + gönderiler + bekleyen işlemler. Biri düşerse diğerleri
  /// yine gösterilir, hata [error]'a yazılır.
  Future<void> refresh() async {
    await _restore();
    if (demo) {
      dashboard ??= kSubeDemoDashboard;
      board ??= kSubeDemoBoard;
      pending ??= kSubeDemoPending;
      capabilities = BranchCapabilities.all;
      syncedAt = DateTime.now();
      onChanged();
      return;
    }
    final client = api;
    if (client == null) return;
    loading = true;
    onChanged();
    String? failure;
    var expired = false;
    Future<void> load(Future<void> Function() call) async {
      try {
        await call();
      } catch (e) {
        if (e is AgencyApiException && e.unauthenticated) expired = true;
        failure ??= describeError(e);
      }
    }

    await Future.wait([
      load(() async => dashboard = await client.fetchDashboard()),
      load(() async {
        final next = await client.fetchDispatchBoard();
        board = next;
        capabilities = next.capabilities;
        picked.removeWhere(
          (id) => !next.rows.any(
            (r) => r.shipmentId == id && r.stage == BranchStage.awaitingCourier,
          ),
        );
      }),
      load(() async => pending = await client.fetchPending()),
    ]);
    loading = false;
    if (expired) {
      onSessionExpired?.call();
      return;
    }
    error = failure;
    if (failure == null) syncedAt = DateTime.now();
    onChanged();
    unawaited(flush());
  }

  Future<void> loadCounts() async {
    if (demo) {
      counts ??= kSubeDemoCounts;
      onChanged();
      return;
    }
    await _run(() async {
      final next = await api!.fetchCounts();
      counts = next;
      final open = next.openCount;
      if (open != null) {
        count = await api!.fetchCount(open.id);
      } else {
        count = null;
      }
    });
  }

  Future<void> refreshCount() async {
    final id = count?.count.id;
    if (id == null || demo) return;
    await _run(() async => count = await api!.fetchCount(id));
  }

  Future<void> loadOutgoing() async {
    await _restore();
    if (demo) {
      outgoing ??= kSubeDemoOutgoing;
      onChanged();
      return;
    }
    await _run(() async => outgoing = await api!.fetchOutgoing());
  }

  Future<void> loadIncoming() async {
    if (demo) {
      incoming ??= const IncomingTransfers();
      onChanged();
      return;
    }
    await _run(() async => incoming = await api!.fetchIncoming());
  }

  Future<void> openIncoming(String transferId) async {
    if (demo) return;
    if (incomingDetail?.transfer.id != transferId) incomingDetail = null;
    await _run(
      () async => incomingDetail = await api!.fetchIncomingDetail(transferId),
    );
  }

  Future<void> loadLabels() async {
    await _restore();
    if (demo) {
      labels ??= kSubeDemoLabels;
      onChanged();
      return;
    }
    await _run(() async => labels = await api!.fetchLabels());
  }

  /// [range]: today | 7d | 30d.
  Future<void> loadPerformance(String range) async {
    if (demo) {
      performance = kSubeDemoPerformance(range);
      onChanged();
      return;
    }
    await _run(() async => performance = await api!.fetchPerformance(range));
  }

  // ── Bildirim, duyuru, vardiya, SMS ─────────────────────────────────────

  Future<void> loadInbox() async {
    if (demo) {
      inbox ??= kSubeDemoInbox;
      announcements ??= const AnnouncementsData();
      onChanged();
      return;
    }
    await _run(() async {
      final box = await api!.fetchNotifications();
      inbox = box.items;
      unreadNotifications = box.unread;
      announcements = await api!.fetchAnnouncements();
    });
  }

  Future<void> markRead(InboxItem item) async {
    if (item.read) return;
    inbox = [
      for (final i in inbox ?? const <InboxItem>[])
        i.id == item.id
            ? InboxItem(
                id: i.id,
                category: i.category,
                severity: i.severity,
                body: i.body,
                read: true,
                createdAt: i.createdAt,
              )
            : i,
    ];
    if (unreadNotifications > 0) unreadNotifications--;
    onChanged();
    if (demo) return;
    try {
      await api!.markNotificationRead(item.id);
    } catch (_) {
      // Okundu işareti bir sonraki yüklemede sunucudaki hâliyle gelir.
    }
  }

  Future<void> loadShifts() async {
    if (demo) {
      shiftDay ??= kSubeDemoShiftDay;
      leaves ??= kSubeDemoLeaves;
      onChanged();
      return;
    }
    await _run(() async {
      shiftDay = await api!.fetchCourierShifts();
      leaves = await api!.fetchLeaveRequests();
    });
  }

  /// İzin isteğini onaylar / reddeder (yetki: `manage`; redde not zorunlu).
  Future<String?> reviewLeave(
    LeaveRequest request, {
    required bool approve,
    String? note,
  }) {
    if (!approve && (note == null || note.trim().isEmpty)) {
      return Future.value('Ret için neden yazın.');
    }
    return _action('leave|${request.id}|$approve', (key) async {
      if (demo) {
        leaves = [
          for (final l in leaves ?? const <LeaveRequest>[])
            l.id == request.id
                ? LeaveRequest(
                    id: l.id,
                    courierName: l.courierName,
                    date: l.date,
                    type: l.type,
                    note: l.note,
                    approvalStatus: approve ? 'APPROVED' : 'REJECTED',
                  )
                : l,
        ];
        return;
      }
      await api!.reviewLeave(
        id: request.id,
        approve: approve,
        note: note?.trim(),
        idempotencyKey: key,
      );
      leaves = await api!.fetchLeaveRequests();
    }, refreshAfter: false);
  }

  Future<void> loadSmsTemplates() async {
    if (demo) {
      smsTemplates ??= kSubeDemoSmsTemplates;
      onChanged();
      return;
    }
    await _run(() async => smsTemplates = await api!.fetchSmsTemplates());
  }

  Future<List<SmsTarget>> smsTargets(String type, {String? query}) async {
    if (demo) {
      return type == 'COURIERS'
          ? [
              for (final c in kSubeDemoDashboard.courierList)
                SmsTarget(id: c.id, title: c.name, subtitle: c.code),
            ]
          : [
              for (final r in kSubeDemoBoard.rows)
                SmsTarget(
                  id: r.shipmentId,
                  title: r.shipmentNumber,
                  subtitle: r.recipientName,
                ),
            ];
    }
    return api!.fetchSmsTargets(type: type, query: query);
  }

  Future<SmsPreview> previewSms({
    required String targetType,
    required List<String> targetIds,
    required SmsTemplate template,
    Map<String, String> variables = const {},
  }) async {
    if (demo) {
      return SmsPreview(
        rendered: template.body,
        recipientCount: targetIds.length,
        reachableCount: targetIds.length,
      );
    }
    return api!.previewSms(
      targetType: targetType,
      targetIds: targetIds,
      templateKey: template.key,
      variables: variables,
    );
  }

  /// SMS'i kuyruğa alır. Aynı gönderim yeniden denenirse aynı anahtar
  /// gider; alıcıya iki kez mesaj çıkmaz.
  Future<String?> sendSms({
    required String targetType,
    required List<String> targetIds,
    required SmsTemplate template,
    Map<String, String> variables = const {},
  }) {
    final ids = [...targetIds]..sort();
    final vars = [for (final e in variables.entries) '${e.key}=${e.value}']
      ..sort();
    return _action(
      'sms|$targetType|${template.key}|${ids.join(',')}|${vars.join('&')}',
      (key) async {
        if (demo) return;
        await api!.sendSms(
          targetType: targetType,
          targetIds: ids,
          templateKey: template.key,
          variables: variables,
          idempotencyKey: key,
        );
      },
      refreshAfter: false,
    );
  }

  // ── Etiket ─────────────────────────────────────────────────────────────

  void setPrinterHost(String host) {
    printerHost = host.trim();
    unawaited(vault?.writeSecret(_printerKey, printerHost));
    onChanged();
  }

  /// Koli / paket etiketi üretir. Barkodsuz evrak ya da materyal için de
  /// sistem iç barkodu bu yolla üretilir.
  Future<String?> generateLabels({
    required String typeCode,
    required int quantity,
    required String warehouseId,
    String? shipmentReference,
  }) {
    return _action(
      'label|$typeCode|$quantity|$warehouseId|${shipmentReference ?? ''}',
      (key) async {
        if (demo) {
          freshLabels = [
            for (var i = 0; i < quantity; i++)
              PrintableLabel(
                id: _newId(),
                barcode: 'DEMO-${_newId().substring(0, 8).toUpperCase()}',
                typeCode: typeCode,
              ),
          ];
          return;
        }
        freshLabels = await api!.generateLabels(
          labelTypeCode: typeCode,
          quantity: quantity,
          warehouseId: warehouseId,
          shipmentReference: shipmentReference,
          idempotencyKey: key,
        );
        labels = await api!.fetchLabels();
      },
      refreshAfter: false,
    );
  }

  /// ZPL'i yazıcıya gönderir; yalnız baskı başarılıysa sunucuda "basıldı"
  /// işaretler. Yazıcıya ulaşılamazsa hiçbir etiket basılmış sayılmaz.
  Future<String?> printLabels(List<PrintableLabel> items) async {
    if (items.isEmpty) return null;
    if (printerHost.isEmpty) return 'Önce yazıcı adresini girin.';
    if (!demo) {
      try {
        for (final label in items) {
          if (label.zpl.isEmpty) return 'Etiketin baskı verisi yok.';
          await _sendZpl(printerHost, label.zpl);
        }
      } catch (_) {
        return 'Yazıcıya ulaşılamadı ($printerHost). '
            'Aynı ağda olduğunuzu ve adresi kontrol edin.';
      }
    }
    final ids = [for (final l in items) l.id]..sort();
    return _action('label-printed|${ids.join(',')}', (key) async {
      if (demo) return;
      await api!.markLabelsPrinted(
        labelIds: ids,
        printer: printerHost,
        idempotencyKey: key,
      );
      labels = await api!.fetchLabels();
    }, refreshAfter: false);
  }

  // ── Zimmet ─────────────────────────────────────────────────────────────

  void togglePick(String shipmentId) {
    if (!picked.remove(shipmentId)) picked.add(shipmentId);
    onChanged();
  }

  void clearPicked() {
    picked.clear();
    onChanged();
  }

  /// Atama (`awaitingCourier`) ve "Değiştir" (`inQueue`) için kurye listesi.
  Future<DispatchOptions> courierOptions(String shipmentId) async {
    if (demo) return kSubeDemoOptions;
    return api!.fetchDispatchOptions(shipmentId);
  }

  /// Dağıtımdaki gönderi için kurye listesi (mevcut kurye hariç).
  Future<List<CourierOption>> reassignOptions(String shipmentId) async {
    if (demo) return kSubeDemoOptions.couriers;
    return api!.fetchReassignOptions(shipmentId);
  }

  Future<List<ReasonOption>> cancelReasons() async {
    if (demo) return kSubeDemoCancelReasons;
    return _cancelReasons ??= await api!.fetchCancelReasons();
  }

  /// Seçili gönderileri kuryeye zimmetler. Başarıda null, aksi halde
  /// gösterilecek hata metni döner. Zimmet, kurye kendi uygulamasında
  /// okutup kabul edene kadar kesinleşmez (çift taraflı).
  Future<String?> assignPicked(CourierOption courier) {
    final ids = picked.toList()..sort();
    return _action('handover|${courier.id}|${ids.join(',')}', (key) async {
      if (demo) {
        _demoMove(ids, BranchStage.inQueue, courier);
      } else {
        await api!.handoverToCourier(
          courierId: courier.id,
          shipmentIds: ids,
          idempotencyKey: key,
        );
      }
      picked.clear();
    });
  }

  /// Kurye henüz kabul etmediyse zimmeti çevirir, kabul ettiyse (dağıtımda)
  /// yeni kuryeye devir açar; ikincisinde [note] denetim kaydına yazılır.
  Future<String?> changeCourier(
    BranchShipmentRow row,
    CourierOption courier, {
    String? note,
  }) {
    final inField = row.stage == BranchStage.inDistribution;
    return _action(
      '${inField ? 'reassign' : 'change'}|${row.shipmentId}|${courier.id}',
      (key) async {
        if (demo) {
          _demoMove([row.shipmentId], row.stage, courier);
        } else if (inField) {
          await api!.reassign(
            shipmentId: row.shipmentId,
            courierId: courier.id,
            note: note,
            idempotencyKey: key,
          );
        } else {
          await api!.changeHandover(
            courierId: courier.id,
            shipmentIds: [row.shipmentId],
            idempotencyKey: key,
          );
        }
      },
    );
  }

  /// Kabul bekleyen zimmeti geri alır; gönderi şubede kalır.
  Future<String?> cancelHandover(BranchShipmentRow row, String reasonCode) {
    return _action('cancel|${row.shipmentId}|$reasonCode', (key) async {
      if (demo) {
        _demoMove([row.shipmentId], BranchStage.awaitingCourier, null);
      } else {
        await api!.cancelHandover(
          shipmentId: row.shipmentId,
          reasonCode: reasonCode,
          idempotencyKey: key,
        );
      }
    });
  }

  // ── Sayım ──────────────────────────────────────────────────────────────

  Future<String?> startCount(String warehouseId) {
    return _action('count-start|$warehouseId', (key) async {
      if (demo) {
        count = kSubeDemoCount;
        _demoCounted.clear();
      } else {
        final id = await api!.startCount(
          warehouseId: warehouseId,
          idempotencyKey: key,
        );
        count = await api!.fetchCount(id);
      }
      countPaused = false;
      recentScans.clear();
    }, refreshAfter: false);
  }

  void setCountPaused(bool paused) {
    countPaused = paused;
    onChanged();
    if (paused) unawaited(refreshCount());
  }

  /// "Sayımı Tamamla": bekleyen okutmalar gitmeden kapatılmaz.
  Future<String?> closeCount({bool uncountedAsZero = false}) async {
    final current = count;
    if (current == null) return 'Açık sayım yok';
    await flush();
    if (pendingScans > 0) {
      return 'Gönderilmeyi bekleyen $pendingScans okutma var. '
          'Bağlantı gelince tekrar deneyin.';
    }
    return _action('count-close|${current.count.id}|$uncountedAsZero', (
      key,
    ) async {
      if (demo) {
        count = CountDetail(
          count: StockCount(
            id: current.count.id,
            number: current.count.number,
            statusCode: 'REVIEW',
            warehouseName: current.count.warehouseName,
          ),
          lines: current.lines,
          capabilities: current.capabilities,
        );
      } else {
        await api!.closeCount(
          countId: current.count.id,
          uncountedAsZero: uncountedAsZero,
          idempotencyKey: key,
        );
        count = await api!.fetchCount(current.count.id);
      }
    }, refreshAfter: false);
  }

  Future<String?> setLineReason(CountLine line, String reasonCode) {
    final id = count?.count.id;
    if (id == null) return Future.value('Açık sayım yok');
    return _action('count-reason|$id|${line.id}|$reasonCode', (key) async {
      if (demo) return;
      await api!.setCountLineReason(
        countId: id,
        lineId: line.id,
        reasonCode: reasonCode,
        idempotencyKey: key,
      );
      count = await api!.fetchCount(id);
    }, refreshAfter: false);
  }

  // ── Merkeze sevk ───────────────────────────────────────────────────────

  void removeFromDraft(String barcode) {
    draft.removeWhere((c) => c.barcode == barcode);
    _saveDraft();
    onChanged();
  }

  /// Taslağı merkeze sevk eder. Aynı taslak yeniden denenirse aynı
  /// idempotency anahtarı gider; çift transfer oluşmaz.
  Future<String?> sendDraft({
    required String transferType,
    required String centerId,
  }) {
    if (!draft.any((c) => !c.isPackage)) {
      return Future.value('Transfere en az bir gönderi okutun.');
    }
    final signature = [for (final c in draft) c.barcode].join(',');
    return _action('dispatch|$transferType|$centerId|$signature', (key) async {
      if (!demo) {
        await api!.dispatchOutgoing(
          transferType: transferType,
          destinationWarehouseId: centerId,
          candidates: List.of(draft),
          idempotencyKey: key,
        );
        outgoing = await api!.fetchOutgoing();
      }
      draft.clear();
      _saveDraft();
    }, refreshAfter: false);
  }

  /// "İçeri Al": okutulmuş kalemleri kabul eder; transfer açık kalır.
  Future<String?> acceptIncoming(BranchTransfer transfer) {
    // Her "İçeri Al" yeni bir kullanıcı eylemidir (arada yeni okutmalar
    // olabilir); anahtar okutulmuş kalem sayısına bağlanır.
    final scanned = incomingDetail?.pendingScannedCount ?? 0;
    return _action('incoming-accept|${transfer.id}|$scanned|${_newId()}', (
      key,
    ) async {
      if (demo) return;
      await api!.acceptIncoming(transferId: transfer.id, idempotencyKey: key);
      incomingDetail = await api!.fetchIncomingDetail(transfer.id);
      incoming = await api!.fetchIncoming();
    }, refreshAfter: false);
  }

  /// Okutulanları içeri alır, kalan kalemleri EKSİK olarak kapatır.
  Future<String?> confirmIncoming(BranchTransfer transfer) {
    return _action('incoming-confirm|${transfer.id}', (key) async {
      if (demo) return;
      await api!.confirmIncoming(transferId: transfer.id, idempotencyKey: key);
      incoming = await api!.fetchIncoming();
      if (incomingDetail?.transfer.id == transfer.id) {
        incomingDetail = await api!.fetchIncomingDetail(transfer.id);
      }
    }, refreshAfter: false);
  }

  // ── Okutma ─────────────────────────────────────────────────────────────

  /// Okutulanı aktif bağlamın işlemine yönlendirir ve sonucu
  /// [recentScans]'e ekler.
  Future<ScanOutcome> scan(ScanContext context, String code) async {
    final outcome = await router.handle(context, code);
    recentScans.insert(0, (code: code.trim(), outcome: outcome));
    if (recentScans.length > 30) recentScans.removeLast();
    onChanged();
    return outcome;
  }

  /// Bekleyen şube okutmalarını okutma sırasıyla gönderir. Geçici bir
  /// hatada durur (sıra bozulmaz); kalıcı ret o kaydı `rejected` yapar.
  Future<Map<String, ScanOutcome>> flush() async {
    final out = <String, ScanOutcome>{};
    final queue = [
      for (final e in outbox.events)
        if (e.pending && e.operation.isBranch) e,
    ]..sort((a, b) => a.sequence.compareTo(b.sequence));
    for (final event in queue) {
      try {
        out[event.clientEventId] = await _send(event);
        await outbox.applyResults([
          (id: event.clientEventId, status: 'applied'),
        ]);
      } on AgencyApiException catch (e) {
        if (e.unauthenticated) {
          onSessionExpired?.call();
          break;
        }
        if (e.isRetryable) break;
        await outbox.applyResults([
          (id: event.clientEventId, status: 'rejected'),
        ]);
        out[event.clientEventId] = ScanOutcome.bad(
          e.serverMessage ?? scanErrorText(e.code),
        );
      } catch (_) {
        break;
      }
    }
    if (queue.isNotEmpty) onChanged();
    return out;
  }

  Future<ScanOutcome> _send(OutboxEvent event) async {
    final code = event.payload['barcode'] as String? ?? '';
    final scanId = event.payload['scanId'] as String? ?? event.clientEventId;
    switch (event.operation) {
      case SyncOperation.branchCountScan:
        if (demo) {
          return _demoCounted.add(code)
              ? ScanOutcome.ok('Sayıldı', code)
              : ScanOutcome.warn('Daha önce sayıldı', code);
        }
        final result = await api!.scanCount(
          countId: event.subjectId ?? '',
          barcode: code,
          clientScanId: scanId,
        );
        return _countOutcome(result, code);
      case SyncOperation.branchReturnScan:
        if (demo) return ScanOutcome.ok('Şubeye teslim alındı', code);
        final result = await api!.scanCourierReturn(
          code: code,
          idempotencyKey: scanId,
        );
        return ScanOutcome.ok(
          'Şubeye teslim alındı',
          result.redeliveryApplied
              ? '${result.shipmentNumber} · yeniden dağıtıma alındı'
              : result.shipmentNumber,
        );
      default:
        throw StateError('Şube kuyruğu dışı işlem: ${event.operation}');
    }
  }

  Future<ScanOutcome> _queued(
    SyncOperation operation,
    String code, {
    String? subjectId,
  }) async {
    final event = outbox.enqueue(
      operation: operation,
      subjectId: subjectId,
      // Kuyruğun kendi olay kimliği cihaz içi sıra numarasından türer;
      // sayım servisi tekrar korumasını `clientScanId` ile yaptığı için
      // iki cihazın çakışmaması adına gerçek bir UUID taşınır.
      payload: {'barcode': code, 'scanId': _newId()},
    );
    final results = await flush();
    return results[event.clientEventId] ??
        const ScanOutcome.warn(
          'Kuyruğa alındı',
          'Bağlantı gelince sırayla gönderilecek',
        );
  }

  Future<ScanOutcome> _scanCount(String code) async {
    final current = count;
    if (current == null || !current.count.scannable) {
      return const ScanOutcome.bad('Açık sayım yok', 'Önce sayımı başlatın');
    }
    if (countPaused) {
      return const ScanOutcome.warn(
        'Sayım duraklatıldı',
        'Devam edince okutun',
      );
    }
    return _queued(
      SyncOperation.branchCountScan,
      code,
      subjectId: current.count.id,
    );
  }

  Future<ScanOutcome> _scanCourierReturn(String code) async {
    final outcome = await _queued(SyncOperation.branchReturnScan, code);
    if (outcome.ok && !demo) {
      try {
        pending = await api!.fetchPending();
      } catch (_) {
        // Okutma kabul edildi; liste bir sonraki yenilemede güncellenir.
      }
    }
    return outcome;
  }

  ScanOutcome _countOutcome(CountScanResult r, String code) {
    final label = r.itemName.isEmpty ? code : r.itemName;
    if (r.counted) return ScanOutcome.ok('Sayıldı', label);
    if (r.duplicate) return ScanOutcome.warn('Daha önce sayıldı', label);
    return ScanOutcome.bad(switch (r.resultCode) {
      'UNKNOWN_BARCODE' => 'Barkod tanınmadı',
      'OUT_OF_SCOPE' => 'Sayım kapsamında değil',
      'NOT_IN_STOCK' => 'Şube stoğunda görünmüyor',
      'WRONG_WAREHOUSE' => 'Başka depoya ait',
      'CONTAINER_MISMATCH' => 'Koli içeriği uyuşmuyor',
      _ => 'Sayılmadı (${r.resultCode})',
    }, label);
  }

  BranchShipmentRow? _findRow(String code) {
    final wanted = _norm(code);
    for (final row in rows) {
      if (_norm(row.shipmentNumber) == wanted) return row;
    }
    return null;
  }

  Future<ScanOutcome> _scanLookup(String code) async {
    final row = _findRow(code);
    if (row == null) {
      return ScanOutcome.bad('Bugünkü listede yok', code);
    }
    final where = switch (row.stage) {
      BranchStage.incoming => 'Şubeye geliyor',
      BranchStage.awaitingCourier => 'Zimmet bekliyor',
      BranchStage.inQueue => 'Kurye kabulü bekleniyor · ${row.courierName}',
      BranchStage.inDistribution => 'Dağıtımda · ${row.courierName}',
    };
    return ScanOutcome.ok(row.shipmentNumber, '${row.recipientName} · $where');
  }

  Future<ScanOutcome> _scanAssign(String code) async {
    final row = _findRow(code);
    if (row == null) return ScanOutcome.bad('Bugünkü listede yok', code);
    if (row.stage != BranchStage.awaitingCourier) {
      return ScanOutcome.warn(
        'Zimmete uygun değil',
        row.courierName.isEmpty
            ? row.shipmentNumber
            : '${row.shipmentNumber} · ${row.courierName}',
      );
    }
    if (!picked.add(row.shipmentId)) {
      return ScanOutcome.warn('Zaten seçili', row.shipmentNumber);
    }
    return ScanOutcome.ok('Zimmete eklendi', row.shipmentNumber);
  }

  Future<ScanOutcome> _scanStockIn(String code) async {
    if (demo) return ScanOutcome.ok('Şubeye kabul edildi', code);
    final result = await api!.scanIncoming(code: code, clientEventId: _newId());
    final label = result.shipmentNumber.isEmpty ? code : result.shipmentNumber;
    if (result.alreadyIn) return ScanOutcome.warn('Zaten içeri alınmış', label);
    try {
      incoming = await api!.fetchIncoming();
      final open = incomingDetail?.transfer.id;
      if (open != null) incomingDetail = await api!.fetchIncomingDetail(open);
    } catch (_) {
      // Okutma kabul edildi; liste bir sonraki yenilemede güncellenir.
    }
    return ScanOutcome.ok('Okutuldu', '$label · ${result.transferNumber}');
  }

  Future<ScanOutcome> _scanDispatch(String code) async {
    final candidate = demo
        ? DispatchCandidate(
            barcode: code,
            shipmentId: code,
            shipmentNumber: code,
            sourceKey: 'demo',
          )
        : await api!.resolveOutgoing(code);
    if (draft.any((c) => c.barcode == candidate.barcode)) {
      return ScanOutcome.warn('Zaten taslakta', candidate.barcode);
    }
    if (!candidate.isPackage) {
      final source = draft
          .where((c) => !c.isPackage)
          .map((c) => c.sourceKey)
          .firstOrNull;
      if (source != null && source != candidate.sourceKey) {
        return ScanOutcome.bad(
          'Farklı zimmet kaynağı',
          'Bu gönderi ayrı bir transferle gönderilmeli',
        );
      }
    }
    draft.add(candidate);
    _saveDraft();
    return candidate.isPackage
        ? ScanOutcome.ok('Koli eklendi', candidate.barcode)
        : ScanOutcome.ok('Gönderi eklendi', candidate.shipmentNumber);
  }

  // ── Yardımcılar ────────────────────────────────────────────────────────

  /// Yazma işlemi: anahtarını [signature] başına bir kez üretir, geçici
  /// hatada saklar (yeniden deneme aynı anahtarla gider), sonuç kesinleşince
  /// bırakır.
  Future<String?> _action(
    String signature,
    Future<void> Function(String key) run, {
    bool refreshAfter = true,
  }) async {
    final key = _actionKeys[signature] ??= _newId();
    try {
      await run(key);
      _actionKeys.remove(signature);
      onChanged();
      if (refreshAfter) await refresh();
      return null;
    } on AgencyApiException catch (e) {
      if (e.unauthenticated) onSessionExpired?.call();
      if (!e.isRetryable) {
        _actionKeys.remove(signature);
        // 409'da sunucu "ekranı yenileyin" der: liste eskimiş olabilir.
        if (refreshAfter && !demo) unawaited(refresh());
      }
      return describeError(e);
    } catch (e) {
      return describeError(e);
    }
  }

  Future<void> _run(Future<void> Function() call) async {
    if (api == null) return;
    loading = true;
    onChanged();
    try {
      await call();
      error = null;
    } catch (e) {
      if (e is AgencyApiException && e.unauthenticated) {
        onSessionExpired?.call();
      }
      error = describeError(e);
    } finally {
      loading = false;
      onChanged();
    }
  }

  void _demoMove(List<String> ids, BranchStage stage, CourierOption? courier) {
    final current = board ?? kSubeDemoBoard;
    board = DispatchBoard(
      kpis: current.kpis,
      capabilities: current.capabilities,
      rows: [
        for (final row in current.rows)
          if (ids.contains(row.shipmentId))
            BranchShipmentRow(
              shipmentId: row.shipmentId,
              shipmentNumber: row.shipmentNumber,
              stage: stage,
              recipientName: row.recipientName,
              district: row.district,
              highPriority: row.highPriority,
              late: row.late,
              windowStart: row.windowStart,
              courier: stage == BranchStage.inDistribution && courier != null
                  ? CourierRef(id: courier.id, name: courier.name)
                  : null,
              pendingCourierName: stage == BranchStage.inQueue
                  ? courier?.name
                  : null,
            )
          else
            row,
      ],
    );
  }

  static String _norm(String code) =>
      code.replaceAll(RegExp(r'\s+'), '').toUpperCase();

  static String describeError(Object e) {
    if (e is AgencyApiException) {
      final message = e.serverMessage;
      if (message != null && message.isNotEmpty) {
        final number = e.shipmentNumber;
        return number == null ? message : '$message ($number)';
      }
      if (e.statusCode == null) return 'Bağlantı kurulamadı. Tekrar deneyin.';
      return scanErrorText(e.code);
    }
    return 'Beklenmeyen bir hata oluştu.';
  }
}
