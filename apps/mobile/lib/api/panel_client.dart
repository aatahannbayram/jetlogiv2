import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import '../data/vault.dart';
import '../secure.dart';
import '../tls_pinning.dart';
import 'models.dart';
import 'panel_models.dart';

/// jetlogi-panel (`dijigoo-ops`) default local dev address per its own
/// README §17 — there is no known staging/production domain yet (bkz.
/// docs/05-panel-entegrasyonu.md, Açık Karar #1). Override with
/// `--dart-define=PANEL_API_BASE=...` once one exists.
const kPanelApiBase = String.fromEnvironment(
  'PANEL_API_BASE',
  defaultValue: 'http://localhost:3000/api/public/v1',
);

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
  PanelApi(this.dio, [this._cookieJar]);

  final Dio dio;
  final CookieJar? _cookieJar;

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
    return PanelApi(dio, cookieJar);
  }

  /// True once a login has produced a session cookie for [kPanelApiBase].
  /// Cheap, local-only check — does not itself confirm the session is still
  /// valid server-side (the 8h expiry in `courier-auth.ts` can have passed).
  /// Call [fetchSession] to confirm. Always false when constructed without
  /// a cookie jar (e.g. in tests).
  Future<bool> get hasStoredSession async {
    final jar = _cookieJar;
    if (jar == null) return false;
    final uri = Uri.parse(dio.options.baseUrl);
    final cookies = await jar.loadForRequest(uri);
    return cookies.any((c) => c.name == 'dijigoo_courier_session');
  }

  Future<PanelCourierProfileDto> login({
    required String identifier,
    required String password,
  }) async {
    final res = await _post('/courier-auth/login', {
      'identifier': identifier,
      'password': password,
    });
    final courier = (res.data?['data'] as Map?)?['courier'] as Map?;
    return PanelCourierProfileDto.fromJson(
      Map<String, dynamic>.from(courier ?? const {}),
    );
  }

  Future<void> logout() async {
    await _post('/courier-auth/logout', const {});
    await _cookieJar?.deleteAll();
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
  }) async {
    final res = await _post('/courier-tasks/$shipmentId/finalize', {
      'outcome': outcome,
      if (reasonCode != null) 'reasonCode': reasonCode,
      if (receivedBy != null) 'receivedBy': receivedBy,
    });
    return PanelFinalizeResultDto.fromJson(
      Map<String, dynamic>.from(res.data?['data'] as Map? ?? const {}),
    );
  }

  Future<List<CustodyItemDto>> fetchCustody() async {
    final res = await _get('/courier-custody');
    final raw = (res.data?['data'] as Map?)?['items'] as List? ?? const [];
    return [
      for (final row in raw)
        if (row is Map)
          CustodyItemDto.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<PanelCustodyActionResultDto> returnCustodyUnit(
    String unitId, {
    required String warehouseId,
    String? note,
  }) async {
    final res = await _post('/courier-custody/$unitId/return', {
      'warehouseId': warehouseId,
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
    final res = await _post('/courier-custody/$unitId/report-issue', {
      'kind': kind,
      if (note != null) 'note': note,
    });
    return PanelCustodyActionResultDto.fromJson(
      Map<String, dynamic>.from(res.data?['data'] as Map? ?? const {}),
    );
  }

  Future<List<SupportTicketDto>> fetchTickets() async {
    final items = <SupportTicketDto>[];
    var page = 1;
    while (page <= 20) {
      final res = await _get(
        '/courier-tickets',
        queryParameters: {'page': '$page', 'pageSize': '50'},
      );
      final data = Map<String, dynamic>.from(
        res.data?['data'] as Map? ?? const {},
      );
      final raw = data['items'] as List? ?? const [];
      for (final row in raw) {
        if (row is Map) {
          items.add(
            SupportTicketDto.fromJson(Map<String, dynamic>.from(row)),
          );
        }
      }
      final total = (data['total'] as num?)?.toInt();
      if (raw.length < 50 || (total != null && items.length >= total)) {
        break;
      }
      page += 1;
    }
    return items;
  }

  Future<SupportTicketDto> createTicket({
    required String clientEventId,
    required String category,
    required String subject,
    required String body,
    String? taskId,
  }) async {
    final res = await _post('/courier-tickets', {
      'clientEventId': clientEventId,
      'category': category,
      'subject': subject,
      'body': body,
      if (taskId != null) 'taskId': taskId,
    });
    final data = Map<String, dynamic>.from(
      res.data?['data'] as Map? ?? const {},
    );
    final ticket = data['ticket'] as Map? ?? data;
    return SupportTicketDto.fromJson(Map<String, dynamic>.from(ticket));
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

/// Panel oturum çerezi düz dosya yerine Keychain / Keystore'da.
class VaultCookieStorage implements Storage {
  VaultCookieStorage(this._vault);

  final Vault _vault;
  static const _prefix = 'dg.panel.ck.';
  static const _index = 'dg.panel.ck.index';

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
