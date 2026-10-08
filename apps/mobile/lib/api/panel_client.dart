import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import '../data/vault.dart';
import '../secure.dart';
import '../tls_pinning.dart';
import 'models.dart';
import 'panel_models.dart';

/// JetDiji kurye mobil API (preprod). Canlı host `api-mobile.jetdiji.com`.
/// Override: `--dart-define=PANEL_API_BASE=...`
const kPanelApiBase = String.fromEnvironment(
  'PANEL_API_BASE',
  defaultValue: 'https://api-mobile.preprod.jetdiji.com/api/public/v1',
);

const kPanelBearerKey = 'dg.jetdiji.courier.token';

/// Client for jetlogi-panel's courier-facing `public/v1/courier-*` API.
///
/// Deliberately separate from [MobileApi] (`api/client.dart`): the panel
/// uses an httpOnly cookie session (`dijigoo_courier_session`, set by
/// `POST courier-auth/login` — see
/// `src/infrastructure/auth/courier-auth.ts` in the panel repo) rather than
/// our own bearer-token model, so it needs its own `Dio` instance with a
/// persisted cookie jar instead of the `Authorization` header interceptor.
/// Config/activation/vardiya hâlâ [MobileApi] (`apps/api`). Zimmet ve
/// kurye destek ticket'ı panel oturumunda bu istemciden gider.
class PanelApi {
  /// Plain constructor for tests — inject a `Dio` with a mock interceptor
  /// (see `test/panel_client_test.dart`) and skip the cookie jar entirely,
  /// same pattern as `MobileApi(dio: dio)` / `CourierTaskClient(dio)`.
  PanelApi(this.dio, [this._cookieJar, this._vault]) {
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

  /// Production factory — session cookie Keychain/Keystore'da.
  /// Release'de `PANEL_API_BASE` HTTPS olmak zorunda.
  static Future<PanelApi> create({required Vault vault}) async {
    assertHttpsInRelease(kPanelApiBase, 'PANEL_API_BASE');
    final dio = Dio(
      BaseOptions(
        baseUrl: kPanelApiBase,
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 8),
        headers: const {'accept': 'application/json'},
      ),
    );
    final cookieJar = PersistCookieJar(
      storage: VaultCookieStorage(vault),
    );
    dio.interceptors.add(CookieManager(cookieJar));
    attachTlsPinning(dio);
    final api = PanelApi(dio, cookieJar, vault);
    final saved = await vault.readSecret(kPanelBearerKey);
    if (saved != null && saved.isNotEmpty) api._accessToken = saved;
    return api;
  }

  /// True once a login has stored a Bearer or a session cookie.
  /// Call [fetchSession] to confirm the server still accepts it.
  Future<bool> get hasStoredSession async {
    if (_accessToken != null && _accessToken!.isNotEmpty) return true;
    final saved = await _vault?.readSecret(kPanelBearerKey);
    if (saved != null && saved.isNotEmpty) {
      _accessToken = saved;
      return true;
    }
    final jar = _cookieJar;
    if (jar == null) return false;
    final uri = Uri.parse(dio.options.baseUrl);
    final cookies = await jar.loadForRequest(uri);
    return cookies.any(
      (c) =>
          c.name == 'dijigoo_courier_session' ||
          c.name == 'jetdiji_courier_session',
    );
  }

  Future<PanelCourierProfileDto> login({
    required String identifier,
    required String password,
  }) async {
    final res = await _post('/courier-auth/login', {
      'identifier': identifier,
      'password': password,
    });
    final data = res.data?['data'] as Map?;
    final token = data?['accessToken'] as String?;
    if (token != null && token.isNotEmpty) {
      _accessToken = token;
      await _vault?.writeSecret(kPanelBearerKey, token);
    }
    final courier = data?['courier'] as Map?;
    return PanelCourierProfileDto.fromJson(
      Map<String, dynamic>.from(courier ?? const {}),
    );
  }

  Future<void> logout() async {
    try {
      await _post('/courier-auth/logout', const {});
    } finally {
      _accessToken = null;
      await _vault?.deleteSecret(kPanelBearerKey);
      await _cookieJar?.deleteAll();
    }
  }

  /// `GET courier-auth/session` — confirms the stored cookie is still
  /// accepted server-side. Returns null on 401 rather than throwing, so
  /// callers can treat it as a plain "am I logged in" check.
  Future<PanelCourierProfileDto?> fetchSession() async {
    try {
      final res = await dio.get<Map<String, dynamic>>('/courier-auth/session');
      final courier = (res.data?['data'] as Map?)?['courier'] as Map?;
      if (courier == null) return null;
      return PanelCourierProfileDto.fromJson(
        Map<String, dynamic>.from(courier),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return null;
      rethrow;
    }
  }

  Future<PanelCourierTaskListDto> fetchTasks({
    int page = 1,
    int pageSize = 25,
    String? status,
    String? search,
  }) async {
    final res = await dio.get<Map<String, dynamic>>(
      '/courier-tasks',
      queryParameters: {
        'page': '$page',
        'pageSize': '$pageSize',
        if (status != null) 'status': status,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    return PanelCourierTaskListDto.fromJson(
      Map<String, dynamic>.from(res.data?['data'] as Map? ?? const {}),
    );
  }

  Future<PanelCourierTaskDto> fetchTaskDetail(String shipmentId) async {
    final res = await dio.get<Map<String, dynamic>>(
      '/courier-tasks/$shipmentId',
    );
    return PanelCourierTaskDto.fromJson(
      Map<String, dynamic>.from(res.data?['data'] as Map? ?? const {}),
    );
  }

  /// Depodan alım. Okutulan gönderi no, barkod veya takip no.
  Future<void> acceptCustodyScan(String scanCode) async {
    await _post('/courier-custody/accept', {
      'scanCode': scanCode,
      'scanType': 'AUTO',
    });
  }

  Future<({String phone, String telUri})> callRecipient(String shipmentId) async {
    final res = await _post('/courier-tasks/$shipmentId/call', const {});
    final data = res.data?['data'] as Map? ?? const {};
    return (
      phone: data['phone'] as String? ?? '',
      telUri: data['telUri'] as String? ?? '',
    );
  }

  Future<String?> requestDeliveryOtp(String shipmentId) async {
    final res = await _post('/courier-tasks/$shipmentId/otp', const {});
    return (res.data?['data'] as Map?)?['challengeId'] as String?;
  }

  /// Doğrulandıysa `otpEvidenceId` olarak kullanılacak kanıt no.
  Future<String?> verifyDeliveryOtp({
    required String shipmentId,
    required String challengeId,
    required String code,
  }) async {
    final res = await _post('/courier-tasks/$shipmentId/otp/verify', {
      'challengeId': challengeId,
      'code': code,
    });
    final data = res.data?['data'] as Map? ?? const {};
    if (data['verified'] != true) return null;
    return data['evidenceId'] as String? ?? challengeId;
  }

  Future<List<({String code, String name})>> fetchDeliveryReasons() async {
    final res = await _get('/courier-tasks/delivery-reasons', queryParameters: {'locale': 'tr'});
    final failed = (res.data?['data'] as Map?)?['failed'] as List? ?? const [];
    return [
      for (final row in failed)
        if (row is Map)
          (
            code: row['code'] as String? ?? '',
            name: row['name'] as String? ?? '',
          ),
    ].where((row) => row.code.isNotEmpty && row.name.isNotEmpty).toList();
  }

  Future<Map<String, dynamic>> fetchRequirements(String shipmentId) async {
    final res = await _get('/courier-tasks/$shipmentId/requirements');
    return Map<String, dynamic>.from(res.data?['data'] as Map? ?? const {});
  }

  Future<String?> uploadTaskEvidence({
    required String shipmentId,
    required List<int> bytes,
    required String filename,
    required String evidenceType,
    String contentType = 'image/jpeg',
    String? requirementCode,
  }) async {
    final key = Vault.newUuid();
    final form = FormData.fromMap({
      'evidenceType': evidenceType,
      'idempotencyKey': key,
      if (requirementCode != null) 'requirementCode': requirementCode,
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: DioMediaType.parse(contentType),
      ),
    });
    final res = await dio.post<Map<String, dynamic>>(
      '/courier-tasks/$shipmentId/evidence',
      data: form,
      options: Options(headers: {'Idempotency-Key': key}),
    );
    final data = res.data?['data'] as Map? ?? const {};
    return data['evidenceId'] as String? ?? data['id'] as String?;
  }

  Future<({String? city, String? district, String? vehicle, String? status})>
  fetchCourierProfile() async {
    final res = await _get('/courier-profile');
    final courier =
        (res.data?['data'] as Map?)?['courier'] as Map? ?? const {};
    final city = courier['city'];
    final district = courier['district'];
    return (
      city: city is Map ? city['name'] as String? : null,
      district: district is Map ? district['name'] as String? : null,
      vehicle: courier['vehicleType'] as String?,
      status: courier['status'] as String?,
    );
  }

  Future<CourierDocumentListDto> fetchMyDocuments() async {
    final res = await _get('/courier-my-documents');
    final summary =
        (res.data?['data'] as Map?)?['summary'] as Map? ?? const {};
    return CourierDocumentListDto(
      items: const [],
      completedCount: (summary['approved'] as num?)?.toInt() ?? 0,
      requiredCount: (summary['required'] as num?)?.toInt() ?? 0,
    );
  }

  Future<PanelTaskActionResultDto> acceptTask(String shipmentId) async {
    final res = await _post('/courier-tasks/$shipmentId/accept', const {});
    return PanelTaskActionResultDto.fromJson(
      Map<String, dynamic>.from(res.data?['data'] as Map? ?? const {}),
    );
  }

  /// `location` is required by the panel's `start` route (freshness-checked
  /// server-side: max 5 min old, not more than 60s in the future — see
  /// `courier-tasks/[shipmentId]/start/route.ts`).
  Future<PanelTaskActionResultDto> startTask(
    String shipmentId, {
    required double latitude,
    required double longitude,
    double? accuracy,
    double? heading,
    double? speed,
    double? altitude,
  }) async {
    final res = await _post('/courier-tasks/$shipmentId/start', {
      'latitude': latitude,
      'longitude': longitude,
      if (accuracy != null) 'accuracy': accuracy,
      if (heading != null) 'heading': heading,
      if (speed != null) 'speed': speed,
      if (altitude != null) 'altitude': altitude,
      'capturedAt': DateTime.now().toUtc().toIso8601String(),
    });
    return PanelTaskActionResultDto.fromJson(
      Map<String, dynamic>.from(res.data?['data'] as Map? ?? const {}),
    );
  }

  /// `purposeCode`: `ACTIVE_TASK` or `ARRIVAL` (the two values the panel's
  /// `location` route accepts).
  Future<void> sendLocation(
    String shipmentId, {
    required String purposeCode,
    required double latitude,
    required double longitude,
    double? accuracy,
  }) async {
    await _post('/courier-tasks/$shipmentId/location', {
      'purposeCode': purposeCode,
      'latitude': latitude,
      'longitude': longitude,
      if (accuracy != null) 'accuracy': accuracy,
      'capturedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// PROVISIONAL — `finalize` is being built on the panel side in parallel
  /// (docs/05-panel-entegrasyonu.md §2). `outcome` must be `DELIVERED` or
  /// `FAILED`; `reasonCode` is required by the panel when `FAILED` (it
  /// validates against `ShipmentReasonDefinition`, not a fixed client-side
  /// list — an invalid or missing code comes back as
  /// `WORKFLOW_SHIPMENT_STATUS_REASON_REQUIRED` /
  /// `WORKFLOW_SHIPMENT_STATUS_REASON_INVALID`). A `FAILED` result is not
  /// necessarily terminal — read `currentStateCode` in the response rather
  /// than assuming the shipment is closed.
  Future<PanelFinalizeResultDto> finalizeTask(
    String shipmentId, {
    required String outcome,
    String? reasonCode,
    String? receivedBy,
    String? otpEvidenceId,
  }) async {
    final delivered = outcome != 'FAILED' && outcome != 'DELIVERY_FAILED';
    final res = await _post('/courier-tasks/$shipmentId/finalize', {
      'resultCode': delivered ? 'DELIVERED' : 'DELIVERY_FAILED',
      'outcome': delivered ? 'DELIVERED' : 'FAILED',
      if (!delivered && reasonCode != null) 'reasonCode': reasonCode,
      if (delivered && receivedBy != null) 'receivedByName': receivedBy,
      if (delivered && otpEvidenceId != null) 'otpEvidenceId': otpEvidenceId,
    });
    return PanelFinalizeResultDto.fromJson(
      Map<String, dynamic>.from(res.data?['data'] as Map? ?? const {}),
    );
  }

  Future<List<CustodyItemDto>> fetchCustody() async {
    final res = await _get('/courier-custody/pending');
    final data = res.data?['data'] as Map? ?? const {};
    final raw = <dynamic>[
      ...((data['items'] as List?) ?? const []),
      ...((data['held'] as List?) ?? const []),
    ];
    return [
      for (final row in raw)
        if (row is Map) _custodyItem(Map<String, dynamic>.from(row)),
    ];
  }

  Future<PanelCustodyActionResultDto> returnCustodyUnit(
    String unitId, {
    required String warehouseId,
    String? note,
  }) async {
    final res = await _post('/courier-custody/return', {
      'shipmentIds': [unitId],
      if (warehouseId.isNotEmpty) 'targetUnitId': warehouseId,
      if (note != null) 'note': note,
    });
    return PanelCustodyActionResultDto.fromJson(
      Map<String, dynamic>.from(res.data?['data'] as Map? ?? const {}),
    );
  }

  Future<PanelCustodyActionResultDto> reportCustodyIssue(
    String unitId, {
    required String kind,
    String? note,
  }) async {
    final res = await _post('/courier-support/cases', {
      'category': 'TICKET',
      'subject': kind,
      if (note != null) 'message': note,
      'shipmentId': unitId,
    });
    return PanelCustodyActionResultDto.fromJson(
      Map<String, dynamic>.from(res.data?['data'] as Map? ?? const {}),
    );
  }

  Future<List<SupportTicketDto>> fetchTickets() async {
    final res = await _get('/courier-support/cases');
    final data = Map<String, dynamic>.from(
      res.data?['data'] as Map? ?? const {},
    );
    final raw = data['cases'] as List? ?? data['items'] as List? ?? const [];
    return [
      for (final row in raw)
        if (row is Map)
          SupportTicketDto.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<SupportTicketDto> createTicket({
    required String clientEventId,
    required String category,
    required String subject,
    required String body,
    String? taskId,
  }) async {
    final res = await _post('/courier-support/cases', {
      'category': _supportCategory(category),
      'subject': subject,
      'message': body,
      'idempotencyKey': clientEventId,
      if (taskId != null) 'shipmentId': taskId,
    });
    final data = Map<String, dynamic>.from(
      res.data?['data'] as Map? ?? const {},
    );
    final ticket = data['ticket'] as Map? ?? data;
    return SupportTicketDto.fromJson(Map<String, dynamic>.from(ticket));
  }

  CustodyItemDto _custodyItem(Map<String, dynamic> json) {
    return CustodyItemDto(
      id: json['itemId'] as String? ??
          json['id'] as String? ??
          json['shipmentId'] as String? ??
          '',
      type: json['type'] as String? ?? 'parcel',
      barcode: json['barcode'] as String? ?? json['shipmentNumber'] as String?,
      description: json['recipientName'] as String? ??
          json['description'] as String? ??
          '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      taskId: json['shipmentId'] as String? ?? json['taskId'] as String?,
      acquiredAt: json['since'] as String? ?? json['acquiredAt'] as String? ?? '',
      warehouseId: json['warehouseId'] as String?,
    );
  }

  String _supportCategory(String category) {
    switch (category) {
      case 'CALL_REQUEST':
      case 'TICKET':
      case 'LIVE_CHAT':
      case 'SOS':
        return category;
      default:
        return 'TICKET';
    }
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
      throw _panelException(e);
    }
  }

  Future<Response<Map<String, dynamic>>> _post(
    String path,
    Map<String, Object?> data,
  ) async {
    try {
      return await dio.post<Map<String, dynamic>>(path, data: data);
    } on DioException catch (e) {
      throw _panelException(e);
    }
  }

  PanelApiException _panelException(DioException e) {
    final code =
        (e.response?.data is Map
            ? (e.response?.data as Map)['error']
            : null)
        is Map
        ? ((e.response?.data as Map)['error'] as Map)['code'] as String?
        : null;
    return PanelApiException(
      code ?? 'PANEL_REQUEST_FAILED',
      statusCode: e.response?.statusCode,
      message: e.message,
    );
  }
}

/// Panel/acente oturum çerezi düz dosya yerine Keychain / Keystore'da.
/// `prefix` her portal için ayrı bir anahtar alanı verir — [PanelApi] ve
/// `AgencyPortalApi` (bkz. `agency_client.dart`) aynı cihazda aynı anda oturum
/// tutabilir, çerezleri karışmaz.
class VaultCookieStorage implements Storage {
  VaultCookieStorage(this._vault, {this._prefix = 'dg.panel.ck.'});

  final Vault _vault;
  final String _prefix;
  String get _index => '${_prefix}index';

  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {}

  @override
  Future<String?> read(String key) => _vault.readSecret('$_prefix$key');

  @override
  Future<void> write(String key, String value) async {
    await _vault.writeSecret('$_prefix$key', value);
    final keys = await _keys();
    if (keys.add(key)) {
      await _vault.writeSecret(_index, keys.join('\n'));
    }
  }

  @override
  Future<void> delete(String key) async {
    await _vault.deleteSecret('$_prefix$key');
    final keys = await _keys();
    if (keys.remove(key)) {
      await _vault.writeSecret(_index, keys.join('\n'));
    }
  }

  @override
  Future<void> deleteAll(List<String> keys) async {
    final known = keys.isEmpty ? await _keys() : keys.toSet();
    for (final key in known) {
      await _vault.deleteSecret('$_prefix$key');
    }
    await _vault.deleteSecret(_index);
  }

  Future<Set<String>> _keys() async {
    final raw = await _vault.readSecret(_index);
    if (raw == null || raw.isEmpty) return {};
    return {for (final line in raw.split('\n')) if (line.isNotEmpty) line};
  }
}
