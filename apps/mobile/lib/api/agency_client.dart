import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../data/vault.dart';
import '../secure.dart';
import '../tls_pinning.dart';
import 'agency_models.dart';
import 'branch_models.dart';
import 'panel_client.dart' show VaultCookieStorage;

/// dijigoo-ops default local dev address — same base host as [kPanelApiBase]
/// but the `portal/v1` surface rather than `public/v1` (see
/// docs/08-sube-acente-entegrasyonu.md). Override with
/// `--dart-define=AGENCY_API_BASE=...` once a staging/production domain
/// exists.
const kAgencyApiBase = String.fromEnvironment(
  'AGENCY_API_BASE',
  defaultValue: 'https://api-mobile.preprod.jetdiji.com/api/portal/v1',
);

const kAgencyBearerKey = 'dg.jetdiji.agency.token';

/// Client for dijigoo-ops's "Acente Portalı" (agency portal) — the backend
/// for the Şube/Acente app role. Same shape as [PanelApi] on purpose (dio +
/// persisted cookie jar, no bearer token): `agency-portal-auth.ts` uses an
/// httpOnly cookie session (`jetdiji_agency_session`) exactly like
/// `courier-auth.ts` does for the courier side, so the same integration
/// pattern applies unchanged. Kept as a separate client/cookie-jar from
/// [PanelApi] because a device could plausibly run both roles' sessions
/// side by side, and the two portals' sessions must not be mixed.
class AgencyPortalApi {
  AgencyPortalApi(this.dio, [this._cookieJar, this._vault]) {
    dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['X-Client-Type'] = 'mobile';
          final token = _accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio dio;
  final CookieJar? _cookieJar;
  final Vault? _vault;
  String? _accessToken;

  static Future<AgencyPortalApi> create({required Vault vault}) async {
    assertHttpsInRelease(kAgencyApiBase, 'AGENCY_API_BASE');
    final dio = Dio(
      BaseOptions(
        baseUrl: kAgencyApiBase,
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 8),
        headers: const {'accept': 'application/json'},
      ),
    );
    final cookieJar = PersistCookieJar(
      storage: VaultCookieStorage(vault, prefix: 'dg.agency.ck.'),
    );
    dio.interceptors.add(CookieManager(cookieJar));
    attachTlsPinning(dio);
    final api = AgencyPortalApi(dio, cookieJar, vault);
    final saved = await vault.readSecret(kAgencyBearerKey);
    if (saved != null && saved.isNotEmpty) api._accessToken = saved;
    return api;
  }

  /// Cheap, local-only check — mirrors [PanelApi.hasStoredSession]. Does not
  /// confirm the session is still valid server-side; call [fetchSession] for
  /// that.
  Future<bool> get hasStoredSession async {
    if (_accessToken != null && _accessToken!.isNotEmpty) return true;
    final saved = await _vault?.readSecret(kAgencyBearerKey);
    if (saved != null && saved.isNotEmpty) {
      _accessToken = saved;
      return true;
    }
    final jar = _cookieJar;
    if (jar == null) return false;
    final uri = Uri.parse(dio.options.baseUrl);
    final cookies = await jar.loadForRequest(uri);
    return cookies.any((c) => c.name == 'jetdiji_agency_session');
  }

  /// Throws [AgencyApiException] with `code == 'AGENCY_SELECTION_REQUIRED'`
  /// and a populated `agencies` list when the account belongs to more than
  /// one agency — retry with `agencyId` set to the user's chosen one.
  Future<AgencyPortalUserDto> login({
    required String email,
    required String password,
    String? agencyId,
  }) async {
    final res = await _post('/agency-auth/login', {
      'email': email,
      'password': password,
      if (agencyId != null) 'agencyId': agencyId,
    });
    final token = (res.data?['data'] as Map?)?['accessToken'] as String?;
    if (token != null && token.isNotEmpty) {
      _accessToken = token;
      await _vault?.writeSecret(kAgencyBearerKey, token);
    }
    final data = Map<String, dynamic>.from(
      res.data?['data'] as Map? ?? const {},
    );
    final agency = AgencyDto.fromJson(
      Map<String, dynamic>.from(data['agency'] as Map? ?? const {}),
    );
    return AgencyPortalUserDto.fromJson(
      Map<String, dynamic>.from(data['user'] as Map? ?? const {}),
      agency,
    );
  }

  Future<void> logout() async {
    try {
      await _post('/agency-auth/logout', const {});
    } finally {
      _accessToken = null;
      await _vault?.deleteSecret(kAgencyBearerKey);
      await _cookieJar?.deleteAll();
    }
  }

  /// `GET agency-auth/session` — confirms the stored cookie is still
  /// accepted server-side. Returns null on 401 rather than throwing.
  Future<AgencyPortalUserDto?> fetchSession() async {
    try {
      final res = await dio.get<Map<String, dynamic>>('/agency-auth/session');
      final data = Map<String, dynamic>.from(
        res.data?['data'] as Map? ?? const {},
      );
      final user = data['user'] as Map?;
      if (user == null) return null;
      final userMap = Map<String, dynamic>.from(user);
      final agency = AgencyDto.fromJson(
        Map<String, dynamic>.from(userMap['agency'] as Map? ?? const {}),
      );
      return AgencyPortalUserDto.fromJson(userMap, agency);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return null;
      rethrow;
    }
  }

  /// `GET agency/overview` — today the only real data endpoint beyond auth;
  /// only counts (see docs/08-sube-acente-entegrasyonu.md §3), no lists.
  Future<AgencyOverviewDto> fetchOverview() async {
    final res = await _get('/agency/overview');
    return AgencyOverviewDto.fromJson(
      Map<String, dynamic>.from(res.data?['data'] as Map? ?? const {}),
    );
  }

  Future<BranchDashboard> fetchDashboard() async =>
      BranchDashboard.fromJson(await _data(_get('/branch/dashboard')));

  /// `GET branch/dispatch` — birimdeki 4010 + 4020 gönderiler (en fazla 500).
  Future<DispatchBoard> fetchDispatchBoard() async =>
      DispatchBoard.fromJson(await _data(_get('/branch/dispatch')));

  /// Çoklu seçimde ilk seçili gönderinin kimliği gönderilir (web de böyle).
  Future<DispatchOptions> fetchDispatchOptions(String shipmentId) async =>
      DispatchOptions.fromJson(
        await _data(
          _get(
            '/branch/dispatch/options',
            queryParameters: {'shipmentId': shipmentId},
          ),
        ),
      );

  /// Gönderi 4010'da kalır; kurye kendi uygulamasında okutup kabul edince
  /// zimmet kesinleşir. [idempotencyKey] yeniden denemede aynı kalmalı.
  Future<HandoverResult> handoverToCourier({
    required String courierId,
    required List<String> shipmentIds,
    required String idempotencyKey,
  }) async => HandoverResult.fromJson(
    await _data(
      _post('/branch/dispatch/handover', {
        'courierId': courierId,
        'shipmentIds': shipmentIds,
      }, idempotencyKey: idempotencyKey),
    ),
  );

  /// Kuryenin henüz okutmadığı zimmeti (`IN_QUEUE`) başka kuryeye çevirir.
  Future<void> changeHandover({
    required String courierId,
    required List<String> shipmentIds,
    required String idempotencyKey,
  }) async {
    await _post('/branch/dispatch/handover/change', {
      'courierId': courierId,
      'shipmentIds': shipmentIds,
    }, idempotencyKey: idempotencyKey);
  }

  /// [reasonCode], [fetchCancelReasons] kataloğundan olmalı.
  Future<void> cancelHandover({
    required String shipmentId,
    required String reasonCode,
    required String idempotencyKey,
  }) async {
    await _post('/branch/dispatch/handover/cancel', {
      'shipmentId': shipmentId,
      'reasonCode': reasonCode,
    }, idempotencyKey: idempotencyKey);
  }

  Future<List<ReasonOption>> fetchCancelReasons() async {
    final data = await _data(_get('/branch/courier-jobs'));
    return [
      for (final row in data['cancelReasons'] as List? ?? const [])
        if (row is Map) ReasonOption.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// Dağıtımdaki (4020) gönderi için seçilebilecek kuryeler; mevcut kurye
  /// hariç.
  Future<List<CourierOption>> fetchReassignOptions(String shipmentId) async {
    final data = await _data(
      _get(
        '/branch/dispatch/reassign',
        queryParameters: {'shipmentId': shipmentId},
      ),
    );
    return [
      for (final row in data['couriers'] as List? ?? const [])
        if (row is Map) CourierOption.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// Zimmet ve görev, yeni kurye okutarak kabul edene kadar eski kuryede
  /// kalır.
  Future<void> reassign({
    required String shipmentId,
    required String courierId,
    required String idempotencyKey,
    String? note,
  }) async {
    await _post('/branch/dispatch/reassign', {
      'shipmentId': shipmentId,
      'courierId': courierId,
      if (note != null && note.isNotEmpty) 'note': note,
    }, idempotencyKey: idempotencyKey);
  }

  Future<PendingData> fetchPending() async =>
      PendingData.fromJson(await _data(_get('/branch/pending')));

  /// Kuryeden dönen gönderiyi şubede okutarak teslim alır; zimmet birime
  /// geçer.
  Future<CourierReturnScanResult> scanCourierReturn({
    required String code,
    required String idempotencyKey,
  }) async => CourierReturnScanResult.fromJson(
    await _data(
      _post('/branch/pending/courier-return-scan', {
        'scanCode': code,
        'scanType': 'AUTO',
        'clientEventId': idempotencyKey,
      }, idempotencyKey: idempotencyKey),
    ),
  );

  Future<CountsData> fetchCounts() async =>
      CountsData.fromJson(await _data(_get('/branch/counts')));

  /// Depoda açık sayım varsa 409 `COUNT_OPERATION_REJECTED`. Dönen değer
  /// yeni sayımın kimliği.
  Future<String> startCount({
    required String warehouseId,
    required String idempotencyKey,
  }) async {
    final data = await _data(
      _post('/branch/counts', {
        'warehouseId': warehouseId,
      }, idempotencyKey: idempotencyKey),
    );
    return data['id'] as String? ?? '';
  }

  Future<CountDetail> fetchCount(String countId) async =>
      CountDetail.fromJson(await _data(_get('/branch/counts/$countId')));

  /// [clientScanId] sayım servisinin kendi tekrar korumasıdır (aynı id
  /// adedi ikinci kez eklemez); web gibi `Idempotency-Key` olarak da gider.
  Future<CountScanResult> scanCount({
    required String countId,
    required String barcode,
    required String clientScanId,
  }) async {
    final data = await _data(
      _post('/branch/counts/$countId', {
        'action': 'scan',
        'clientScanId': clientScanId,
        'barcode': barcode,
        'deviceTypeCode': 'HANDHELD',
      }, idempotencyKey: clientScanId),
    );
    final result = data['result'];
    return CountScanResult.fromJson(
      result is Map ? Map<String, dynamic>.from(result) : data,
    );
  }

  /// Yalnız kapatılmış (REVIEW) sayımın satırına fark nedeni yazar.
  Future<void> setCountLineReason({
    required String countId,
    required String lineId,
    required String reasonCode,
    required String idempotencyKey,
    String? note,
  }) async {
    await _post('/branch/counts/$countId', {
      'action': 'line-reason',
      'lineId': lineId,
      'reasonCode': reasonCode,
      if (note != null && note.isNotEmpty) 'reasonNote': note,
    }, idempotencyKey: idempotencyKey);
  }

  /// "Sayımı Tamamla" → REVIEW. [uncountedAsZero] false iken sayılmamış
  /// ürün varsa 409 döner.
  Future<void> closeCount({
    required String countId,
    required String idempotencyKey,
    bool uncountedAsZero = false,
  }) async {
    await _post('/branch/counts/$countId', {
      'action': 'close',
      'uncountedAsZero': uncountedAsZero,
    }, idempotencyKey: idempotencyKey);
  }

  Future<OutgoingOptions> fetchOutgoing() async =>
      OutgoingOptions.fromJson(await _data(_get('/branch/transfers/outgoing')));

  /// Yan etkisiz: okutulan kodu transfere eklenebilecek adaya çevirir.
  /// `PARCEL_BARCODE` sunucunun otomatik çözümleyicisine gider.
  Future<DispatchCandidate> resolveOutgoing(String code) async =>
      DispatchCandidate.fromJson(
        await _data(
          _post('/branch/transfers/outgoing/resolve', {
            'scanType': 'PARCEL_BARCODE',
            'scannedValue': code,
          }),
        ),
      );

  /// Sevk başarısızsa taslak sunucuda kalır (409 `TRANSFER_DISPATCH_FAILED`).
  Future<OutgoingDispatchResult> dispatchOutgoing({
    required String transferType,
    required String destinationWarehouseId,
    required List<DispatchCandidate> candidates,
    required String idempotencyKey,
  }) async {
    final byShipment = <String, List<String>>{};
    for (final c in candidates) {
      if (!c.isPackage) (byShipment[c.shipmentId] ??= []).add(c.barcode);
    }
    return OutgoingDispatchResult.fromJson(
      await _data(
        _post('/branch/transfers/outgoing', {
          'transferType': transferType,
          'destinationWarehouseId': destinationWarehouseId,
          'lines': [
            for (final e in byShipment.entries)
              {'shipmentId': e.key, 'barcodes': e.value},
          ],
          'packageBarcodes': [
            for (final c in candidates)
              if (c.isPackage) c.barcode,
          ],
        }, idempotencyKey: idempotencyKey),
      ),
    );
  }

  Future<IncomingTransfers> fetchIncoming() async => IncomingTransfers.fromJson(
    await _data(_get('/branch/transfers/incoming')),
  );

  Future<TransferScanResult> scanIncoming({
    required String code,
    required String clientEventId,
  }) async => TransferScanResult.fromJson(
    await _data(
      _post('/branch/transfers/incoming/scan', {
        'scanType': 'PARCEL_BARCODE',
        'scannedValue': code,
        'clientEventId': clientEventId,
      }, idempotencyKey: clientEventId),
    ),
  );

  Future<IncomingTransferDetail> fetchIncomingDetail(String transferId) async =>
      IncomingTransferDetail.fromJson(
        await _data(_get('/branch/transfers/incoming/$transferId')),
      );

  /// "İçeri Al": okutulmuş kalemleri kabul eder, transferi kapatmaz.
  Future<TransferAcceptResult> acceptIncoming({
    required String transferId,
    required String idempotencyKey,
  }) async => TransferAcceptResult.fromJson(
    await _data(
      _post(
        '/branch/transfers/incoming/$transferId/accept',
        const {},
        idempotencyKey: idempotencyKey,
      ),
    ),
  );

  Future<LabelWorkspace> fetchLabels() async =>
      LabelWorkspace.fromJson(await _data(_get('/branch/labels')));

  /// Şube deposunda [quantity] adet etiket üretir; tekrar istekte yeni
  /// etiket üretilmez.
  Future<List<PrintableLabel>> generateLabels({
    required String labelTypeCode,
    required int quantity,
    required String warehouseId,
    required String idempotencyKey,
    String? shipmentReference,
  }) async {
    final data = await _data(
      _post('/branch/labels', {
        'action': 'generate',
        'labelTypeCode': labelTypeCode,
        'quantity': quantity,
        'warehouseId': warehouseId,
        if (shipmentReference != null && shipmentReference.isNotEmpty)
          'shipmentReference': shipmentReference,
      }, idempotencyKey: idempotencyKey),
    );
    return [
      for (final row in data['labels'] as List? ?? const [])
        if (row is Map) PrintableLabel.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// Başarılı baskıdan sonra çağrılır; basım sayacını artırır.
  Future<void> markLabelsPrinted({
    required List<String> labelIds,
    required String printer,
    required String idempotencyKey,
  }) async {
    await _post('/branch/labels', {
      'action': 'printed',
      'labelIds': labelIds,
      'printer': printer,
    }, idempotencyKey: idempotencyKey);
  }

  /// [range]: today | 7d | 30d.
  Future<PerformanceData> fetchPerformance(String range) async =>
      PerformanceData.fromJson(
        await _data(
          _get('/branch/performance', queryParameters: {'range': range}),
        ),
      );

  /// Okutulan kalemleri içeri alır, kalanları EKSİK olarak kapatır.
  Future<TransferAcceptResult> confirmIncoming({
    required String transferId,
    required String idempotencyKey,
  }) async => TransferAcceptResult.fromJson(
    await _data(
      _post(
        '/branch/transfers/incoming/$transferId/confirm',
        const {},
        idempotencyKey: idempotencyKey,
      ),
    ),
  );

  Future<({List<InboxItem> items, int unread})> fetchNotifications() async {
    final data = await _data(_get('/branch/notifications'));
    final unread = data['unread'];
    return (
      items: [
        for (final row in data['items'] as List? ?? const [])
          if (row is Map) InboxItem.fromJson(Map<String, dynamic>.from(row)),
      ],
      unread: unread is Map ? (unread['total'] as num?)?.toInt() ?? 0 : 0,
    );
  }

  Future<void> markNotificationRead(String id) async {
    await _post(
      '/branch/notifications/$id/read',
      const {},
      idempotencyKey: Vault.newUuid(),
    );
  }

  Future<AnnouncementsData> fetchAnnouncements() async =>
      AnnouncementsData.fromJson(await _data(_get('/branch/announcements')));

  /// Kuryelerin bugünkü planı ve vardiyaları.
  Future<BranchShiftDay> fetchCourierShifts() async =>
      BranchShiftDay.fromJson(await _data(_get('/branch/courier-shifts')));

  Future<List<LeaveRequest>> fetchLeaveRequests() async {
    final res = await _get('/branch/courier-leave-requests');
    final rows = res.data?['data'];
    return [
      for (final row in rows is List ? rows : const [])
        if (row is Map) LeaveRequest.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// Yetki: `manage`. Redde [note] zorunlu.
  Future<void> reviewLeave({
    required String id,
    required bool approve,
    required String idempotencyKey,
    String? note,
  }) async {
    await _post('/branch/courier-leave-requests/$id/review', {
      'decision': approve ? 'APPROVE' : 'REJECT',
      if (note != null && note.isNotEmpty) 'note': note,
    }, idempotencyKey: idempotencyKey);
  }

  Future<List<SmsTemplate>> fetchSmsTemplates() async {
    final data = await _data(_get('/branch/sms/templates'));
    return [
      for (final row in data['templates'] as List? ?? const [])
        if (row is Map) SmsTemplate.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// [type]: SHIPMENTS (alıcıya gider, [query] ile aranır) | COURIERS.
  Future<List<SmsTarget>> fetchSmsTargets({
    required String type,
    String? query,
  }) async {
    final data = await _data(
      _get(
        '/branch/sms/targets',
        queryParameters: {
          'type': type,
          if (query != null && query.isNotEmpty) 'q': query,
        },
      ),
    );
    return [
      for (final row in data['items'] as List? ?? const [])
        if (row is Map)
          type == 'COURIERS'
              ? SmsTarget.courier(Map<String, dynamic>.from(row))
              : SmsTarget.shipment(Map<String, dynamic>.from(row)),
    ];
  }

  Map<String, Object?> _smsBody(
    String targetType,
    List<String> targetIds,
    String templateKey,
    Map<String, String> variables,
  ) => {
    'targetType': targetType,
    'targetIds': targetIds,
    'channel': 'SMS',
    'templateKey': templateKey,
    if (variables.isNotEmpty) 'variables': variables,
  };

  /// Yan etkisiz; eksik değişkenler `missingVariables` içinde döner.
  Future<SmsPreview> previewSms({
    required String targetType,
    required List<String> targetIds,
    required String templateKey,
    Map<String, String> variables = const {},
  }) async => SmsPreview.fromJson(
    await _data(
      _post(
        '/branch/sms/preview',
        _smsBody(targetType, targetIds, templateKey, variables),
      ),
    ),
  );

  /// Dönen değer kuyruğa alınan alıcı sayısı.
  Future<int> sendSms({
    required String targetType,
    required List<String> targetIds,
    required String templateKey,
    required String idempotencyKey,
    Map<String, String> variables = const {},
  }) async {
    final data = await _data(
      _post(
        '/branch/sms/send',
        _smsBody(targetType, targetIds, templateKey, variables),
        idempotencyKey: idempotencyKey,
      ),
    );
    return (data['recipientCount'] as num?)?.toInt() ?? targetIds.length;
  }

  /// Yetki: `manage`. Hedef her zaman kendi acentesidir; [audience]
  /// COURIER | BRANCH_USER | ALL.
  Future<void> publishAnnouncement({
    required String title,
    required String body,
    required String severity,
    required String audience,
    required bool requiresAck,
    required String idempotencyKey,
  }) async {
    await _post('/branch/announcements', {
      'title': title,
      'body': body,
      'severity': severity,
      'audience': audience,
      'requiresAck': requiresAck,
      'publish': true,
    }, idempotencyKey: idempotencyKey);
  }

  Future<List<SmsBatch>> fetchSmsHistory() async {
    final data = await _data(_get('/branch/sms/history'));
    return [
      for (final row in data['batches'] as List? ?? const [])
        if (row is Map) SmsBatch.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// Şubenin yönettiği kurye eğitimleri.
  Future<List<ManagedTraining>> fetchManagedTrainings() async {
    final data = await _data(
      _get('/branch/training', queryParameters: {'targetType': 'COURIER'}),
    );
    final rows = data['trainings'];
    return [
      for (final row in rows is List ? rows : const [])
        if (row is Map)
          ManagedTraining.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// Metin içerikli kurye eğitimi oluşturur ve yayımlar (yetki: `manage`).
  Future<void> createTraining({
    required String title,
    required String body,
    required bool mandatory,
    required String idempotencyKey,
  }) async {
    await _post('/branch/training', {
      'title': title,
      'contentType': 'TEXT',
      'contentBody': body,
      'category': 'OPERATION',
      'isMandatory': mandatory,
      'publish': true,
    }, idempotencyKey: idempotencyKey);
  }

  /// Kuryelerin evrak / onay durumu.
  Future<List<CourierCompliance>> fetchCompliance() async {
    final data = await _data(_get('/branch/compliance'));
    return [
      for (final row in data['couriers'] as List? ?? const [])
        if (row is Map)
          CourierCompliance.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// Sayım yönetici işlemleri (yetki: `manage`): `manual` (adet + neden),
  /// `post` (onay; stok hareketleri oluşur), `cancel` (neden zorunlu).
  Future<void> countManage({
    required String countId,
    required Map<String, Object?> action,
    required String idempotencyKey,
  }) async {
    await _post(
      '/branch/counts/$countId',
      action,
      idempotencyKey: idempotencyKey,
    );
  }

  List<Map<String, dynamic>> _rows(Object? raw) => [
    for (final row in raw is List ? raw : const [])
      if (row is Map) Map<String, dynamic>.from(row),
  ];

  /// Hazırlık listesi: kurye bekleyen ve sıradaki gönderiler, günün sayaçları.
  Future<({Map<String, dynamic> kpis, List<BranchShipmentRow> rows})>
  fetchPreparation() async {
    final data = await _data(_get('/branch/preparation'));
    return (
      kpis: Map<String, dynamic>.from(data['kpis'] as Map? ?? const {}),
      rows: [
        for (final row in _rows(data['rows'])) BranchShipmentRow.fromJson(row),
      ],
    );
  }

  /// Seçilen gönderilerin etiket alanları. Veri değiştirmez, ZPL döndürmez;
  /// etiket cihazda üretilir.
  Future<List<Map<String, dynamic>>> fetchPrintRows(
    List<String> shipmentIds,
  ) async {
    final res = await _post('/branch/preparation/print-rows', {
      'shipmentIds': shipmentIds,
      'locale': 'tr',
    });
    return _rows(res.data?['data']);
  }

  /// Ham duyuru verisi: `announcements` (gelen), `published` (yayımlanan).
  Future<Map<String, dynamic>> fetchAnnouncementsRaw() async =>
      _data(_get('/branch/announcements'));

  /// [action]: `ack` (okudum), `publish` (taslağı yayımla), `archive`.
  Future<void> announcementAction(
    String announcementId,
    String action, {
    required String idempotencyKey,
  }) async {
    await _post(
      '/branch/announcements/$announcementId/$action',
      const {},
      idempotencyKey: idempotencyKey,
    );
  }

  /// Şube ya da kurye kartı; `token` QR içeriğidir, 365 gün geçerli.
  Future<Map<String, dynamic>> createCard({
    required String ownerType,
    required String ownerId,
    required String idempotencyKey,
  }) async {
    final data = await _data(
      _post('/branch/compliance/cards', {
        'ownerType': ownerType,
        'ownerId': ownerId,
      }, idempotencyKey: idempotencyKey),
    );
    // Kart alanları `data.card` altında gelir.
    final card = data['card'];
    return card is Map ? Map<String, dynamic>.from(card) : data;
  }

  /// Okutulan kart QR'ını doğrular; imza bozuksa `valid: false` döner.
  Future<Map<String, dynamic>> verifyCard(String token) async =>
      _data(_post('/branch/compliance/cards/verify', {'token': token}));

  /// Ham vardiya verisi; düzeltme için vardiya kimlikleri buradadır.
  Future<Map<String, dynamic>> fetchCourierShiftsRaw() async =>
      _data(_get('/branch/courier-shifts'));

  /// Kuryenin vardiya başlangıç / bitişini düzeltir; [reason] zorunlu.
  Future<void> correctShift(
    String shiftId, {
    DateTime? startedAt,
    DateTime? endedAt,
    required String reason,
  }) async {
    try {
      await dio.patch<Map<String, dynamic>>(
        '/branch/courier-shifts/$shiftId',
        data: {
          if (startedAt != null)
            'startedAt': startedAt.toUtc().toIso8601String(),
          if (endedAt != null) 'endedAt': endedAt.toUtc().toIso8601String(),
          'reason': reason,
        },
      );
    } on DioException catch (e) {
      throw _agencyException(e);
    }
  }

  /// Fatura mutabakatı: backend'de fatura listesi henüz yok
  /// (`schemaReady: false`); talepler (`supportCases`) gerçek veridir.
  Future<Map<String, dynamic>> fetchInvoices() async =>
      _data(_get('/branch/invoices'));

  /// [category]: DISPUTE (itiraz; [reasonKey] zorunlu), REQUEST, CALL_REQUEST,
  /// LIVE_CHAT.
  Future<void> createInvoiceSupport({
    required String category,
    String? reasonKey,
    String? note,
    required String idempotencyKey,
  }) async {
    await _post('/branch/invoices/support', {
      'category': category,
      'reasonKey': ?reasonKey,
      if (note != null && note.isNotEmpty) 'note': note,
    }, idempotencyKey: idempotencyKey);
  }

  Future<List<Map<String, dynamic>>> fetchAgencyCouriers() async =>
      _rows((await _data(_get('/agency/couriers')))['items']);

  Future<List<Map<String, dynamic>>> fetchAgencyRegions() async =>
      _rows((await _data(_get('/agency/regions')))['items']);

  Future<List<Map<String, dynamic>>> fetchAgencyWarehouses() async =>
      _rows((await _data(_get('/agency/warehouses')))['items']);

  Future<Map<String, dynamic>> _data(
    Future<Response<Map<String, dynamic>>> call,
  ) async {
    final res = await call;
    return Map<String, dynamic>.from(res.data?['data'] as Map? ?? const {});
  }

  Future<Response<Map<String, dynamic>>> _get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
      );
    } on DioException catch (e) {
      throw _agencyException(e);
    }
  }

  Future<Response<Map<String, dynamic>>> _post(
    String path,
    Map<String, Object?> data, {
    String? idempotencyKey,
  }) async {
    try {
      return await dio.post<Map<String, dynamic>>(
        path,
        data: data,
        options: idempotencyKey == null
            ? null
            : Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
    } on DioException catch (e) {
      throw _agencyException(e);
    }
  }

  AgencyApiException _agencyException(DioException e) {
    final body = e.response?.data;
    final error = body is Map && body['error'] is Map
        ? body['error'] as Map
        : const {};
    final code =
        error['code'] as String? ??
        (body is Map ? body['code'] as String? : null);
    final nested = body is Map ? body['data'] as Map? : null;
    final agenciesRaw =
        error['agencies'] as List? ?? nested?['agencies'] as List?;
    return AgencyApiException(
      code ?? 'AGENCY_REQUEST_FAILED',
      statusCode: e.response?.statusCode,
      message: e.message,
      serverMessage:
          error['message'] as String? ??
          (body is Map ? body['message'] as String? : null),
      reason: error['reason'] as String?,
      shipmentNumber: error['shipmentNumber'] as String?,
      remainingAttempts: (error['remainingAttempts'] as num?)?.toInt(),
      lockedUntil: error['lockedUntil'] is String
          ? DateTime.tryParse(error['lockedUntil'] as String)
          : null,
      agencies: [
        for (final row in agenciesRaw ?? const [])
          if (row is Map) AgencyDto.fromJson(Map<String, dynamic>.from(row)),
      ],
    );
  }
}
