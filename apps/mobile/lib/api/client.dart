import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/vault.dart';
import '../models.dart';
import 'models.dart';

const kApiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://kurye.dijigoo.com/api/mobile',
);

const kAppVersion = '1.0.0';
const kAppBuild = 1;

String clientInfoHeader() {
  final os = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  return 'dijigoo-courier/$kAppVersion ($os; build $kAppBuild)';
}

String e164(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('90') && digits.length >= 12) return '+$digits';
  if (digits.startsWith('0') && digits.length >= 11) return '+90${digits.substring(1)}';
  if (digits.length == 10) return '+90$digits';
  return '+90$digits';
}

class MobileApi {
  MobileApi({required this.dio, this.vault});

  final Dio dio;
  final Vault? vault;
  bool lastWasLive = false;

  factory MobileApi.create({Vault? vault}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: kApiBase,
        connectTimeout: const Duration(seconds: 2),
        receiveTimeout: const Duration(seconds: 4),
        headers: {
          'x-client-info': clientInfoHeader(),
          'accept': 'application/json',
        },
      ),
    );
    final refreshDio = Dio(
      BaseOptions(
        baseUrl: kApiBase,
        connectTimeout: const Duration(seconds: 2),
        receiveTimeout: const Duration(seconds: 4),
        headers: {
          'x-client-info': clientInfoHeader(),
          'accept': 'application/json',
        },
      ),
    );
    dio.interceptors.add(_AuthInterceptor(vault));
    dio.interceptors.add(_RefreshInterceptor(vault: vault, refreshDio: refreshDio, dio: dio));
    dio.interceptors.add(DemoFallbackInterceptor());
    return MobileApi(dio: dio, vault: vault);
  }

  Future<CourierAvailabilityDto> fetchAvailability() async {
    final res = await dio.get<Map<String, dynamic>>('/v1/me/availability');
    lastWasLive = res.extra['demo'] != true;
    return CourierAvailabilityDto.fromJson(res.data ?? const {});
  }

  Future<CourierDocumentListDto> fetchDocuments() async {
    final res = await dio.get<Map<String, dynamic>>('/v1/me/documents');
    lastWasLive = res.extra['demo'] != true;
    return CourierDocumentListDto.fromJson(res.data ?? const {});
  }

  Future<AppConfig> fetchConfig() async {
    final res = await dio.get<Map<String, dynamic>>('/v1/config');
    lastWasLive = res.extra['demo'] != true;
    return AppConfig.fromJson(res.data ?? const {});
  }

  Future<Map<String, dynamic>> startActivation(String phone, String installationId) async {
    final res = await dio.post<Map<String, dynamic>>(
      '/v1/auth/activation/start',
      data: {
        'phone': e164(phone),
        'device': _device(installationId),
      },
    );
    lastWasLive = res.extra['demo'] != true;
    return res.data ?? const {};
  }

  Future<TokenPair> verifyActivation({
    required String challengeId,
    required String code,
    required String installationId,
  }) async {
    final res = await dio.post<Map<String, dynamic>>(
      '/v1/auth/activation/verify',
      data: {
        'challengeId': challengeId,
        'code': code,
        'device': _device(installationId),
      },
    );
    lastWasLive = res.extra['demo'] != true;
    final tokens = Map<String, dynamic>.from(res.data?['tokens'] as Map? ?? const {});
    return TokenPair(
      accessToken: tokens['accessToken'] as String? ?? 'demo-access',
      refreshToken: tokens['refreshToken'] as String? ?? 'demo-refresh',
      accessExpiresAt: DateTime.tryParse(tokens['accessTokenExpiresAt'] as String? ?? '') ??
          DateTime.now().toUtc().add(const Duration(minutes: 15)),
      refreshExpiresAt: DateTime.tryParse(tokens['refreshTokenExpiresAt'] as String? ?? '') ??
          DateTime.now().toUtc().add(const Duration(days: 30)),
    );
  }

  /// Today's optimized stop order (apps/api `GET /v1/routes/current`) — real
  /// road-network distances/geometry and, past 2 stops, a reordered sequence
  /// (see apps/api/src/services/optimizer.ts). Null on 204 (no open shift or
  /// no geocoded stops yet), matching the API contract rather than throwing.
  Future<RoutePlanDto?> fetchRoute() async {
    final res = await dio.get<Map<String, dynamic>>('/v1/routes/current');
    lastWasLive = res.extra['demo'] != true;
    if (res.statusCode == 204 || res.data == null || res.data!.isEmpty) return null;
    return RoutePlanDto.fromJson(res.data!);
  }

  /// What the courier currently holds (apps/api `GET /v1/custody`).
  Future<List<CustodyItemDto>> fetchCustody({String? type}) async {
    final res = await dio.get<Map<String, dynamic>>(
      '/v1/custody',
      queryParameters: type == null ? null : {'type': type},
    );
    lastWasLive = res.extra['demo'] != true;
    final raw = (res.data?['items'] as List?) ?? const [];
    return [
      for (final row in raw)
        if (row is Map) CustodyItemDto.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// Şube (branch) devri — kurye zaten elindeki kalemleri acenteye teslim
  /// eder (Madde 9: "barkod okuyarak acenteye teslim"). Bilerek yalnız bu
  /// yön: backend'de bir zimmet kalemini barkoddan ilk kez oluşturan bir uç
  /// yok (`apps/api/src/routes/custody.ts`), o yüzden "kurye" tarafı burada
  /// değil — bkz. proje notu (Hande'nin netleştirmesi bekleniyor).
  Future<CustodyHandoverResultDto> handoverToBranch({
    required List<String> itemIds,
    required String branchName,
    String? branchId,
    String? note,
  }) async {
    final res = await dio.post<Map<String, dynamic>>(
      '/v1/custody/handover',
      options: Options(headers: {'idempotency-key': Vault.newUuid()}),
      data: {
        'clientEventId': Vault.newUuid(),
        'occurredAt': DateTime.now().toUtc().toIso8601String(),
        'direction': 'handover',
        'counterparty': {'kind': 'branch', 'id': branchId, 'name': branchName},
        'itemIds': itemIds,
        'photoMediaIds': const [],
        if (note != null) 'note': note,
      },
    );
    lastWasLive = res.extra['demo'] != true;
    return CustodyHandoverResultDto.fromJson(res.data ?? const {});
  }

  Future<List<SyncBatchResult>> syncBatch({
    required String installationId,
    required List<OutboxEvent> events,
  }) async {
    if (events.isEmpty) return const [];
    final res = await dio.post<Map<String, dynamic>>(
      '/v1/sync/batch',
      data: {
        'installationId': installationId,
        'events': [
          for (final e in events)
            {
              'clientEventId': e.clientEventId,
              'operation': e.operation.wire,
              'subjectId': e.subjectId,
              'occurredAt': e.occurredAt.toUtc().toIso8601String(),
              'sequence': e.sequence,
              'payload': e.payload,
            },
        ],
      },
    );
    lastWasLive = res.extra['demo'] != true;
    final results = (res.data?['results'] as List?) ?? const [];
    return [
      for (final r in results)
        SyncBatchResult(
          clientEventId: (r as Map)['clientEventId'] as String,
          status: r['status'] as String? ?? 'deferred',
        ),
    ];
  }

  Map<String, Object?> _device(String installationId) {
    final ios = defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;
    return {
      'installationId': installationId,
      'platform': ios ? 'ios' : 'android',
      'osVersion': ios ? '18.2' : '14',
      'model': ios ? 'iPhone' : 'Pixel',
      'manufacturer': ios ? 'Apple' : 'Google',
      'appVersion': kAppVersion,
      'appBuild': kAppBuild,
    };
  }
}

class _AuthInterceptor extends QueuedInterceptor {
  _AuthInterceptor(this.vault);
  final Vault? vault;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final token = await vault?.accessToken;
      if (token != null && token.isNotEmpty) {
        options.headers['authorization'] = 'Bearer $token';
      }
      handler.next(options);
    } catch (e, st) {
      handler.reject(DioException(requestOptions: options, error: e, stackTrace: st));
    }
  }
}

/// 401 → `/v1/auth/token/refresh` on a bare dio so this interceptor cannot loop.
class _RefreshInterceptor extends QueuedInterceptor {
  _RefreshInterceptor({required this.vault, required this.refreshDio, required this.dio});

  final Vault? vault;
  final Dio refreshDio;
  final Dio dio;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 ||
        err.requestOptions.extra['authRetry'] == true ||
        err.requestOptions.path.contains('/auth/token/refresh')) {
      handler.next(err);
      return;
    }
    final store = vault;
    final refresh = await store?.refreshToken;
    if (store == null || refresh == null || refresh.isEmpty || refresh == 'demo-refresh') {
      handler.next(err);
      return;
    }
    try {
      final install = await store.installationId();
      final res = await refreshDio.post<Map<String, dynamic>>(
        '/v1/auth/token/refresh',
        data: {'refreshToken': refresh, 'installationId': install},
      );
      final tokens = Map<String, dynamic>.from(res.data?['tokens'] as Map? ?? const {});
      final access = tokens['accessToken'] as String?;
      final nextRefresh = tokens['refreshToken'] as String?;
      if (access == null || nextRefresh == null) {
        handler.next(err);
        return;
      }
      await store.saveTokens(
        accessToken: access,
        refreshToken: nextRefresh,
        accessExpiresAt: DateTime.tryParse(tokens['accessTokenExpiresAt'] as String? ?? '') ??
            DateTime.now().toUtc().add(const Duration(minutes: 15)),
        refreshExpiresAt: DateTime.tryParse(tokens['refreshTokenExpiresAt'] as String? ?? '') ??
            DateTime.now().toUtc().add(const Duration(days: 30)),
      );
      err.requestOptions.headers['authorization'] = 'Bearer $access';
      err.requestOptions.extra['authRetry'] = true;
      handler.resolve(await dio.fetch<Map<String, dynamic>>(err.requestOptions));
    } catch (_) {
      handler.next(err);
    }
  }
}

/// Unreachable live API → contract-shaped demo payload. Splash still proceeds.
class DemoFallbackInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!_shouldMock(err)) {
      handler.next(err);
      return;
    }
    final path = err.requestOptions.path;
    handler.resolve(
      Response<Map<String, dynamic>>(
        requestOptions: err.requestOptions,
        statusCode: 200,
        extra: const {'demo': true},
        data: mockPayload(path, err.requestOptions),
      ),
    );
  }

  bool _shouldMock(DioException err) {
    if (_isOffline(err)) return true;
    final code = err.response?.statusCode;
    final path = err.requestOptions.path;
    // A reachable-but-unauthenticated backend (real API up, but this demo
    // courier's token isn't recognized by it — e.g. a freshly migrated
    // database) should degrade the same way an unreachable one does for
    // these endpoints, not fail silently with routePlan/documents left null.
    final mockable = path.contains('/me/availability') || path.contains('/me/documents') || path.contains('/v1/routes/current');
    return mockable && (code == 401 || code == 404 || code == 501);
  }

  bool _isOffline(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.unknown;
  }
}

/// Demo parcels held for branch handover (Madde 9). Barcodes match what
/// [ZimmetScreen]'s "Şube" mode expects a courier to scan.
final _demoCustodyItems = [
  {
    'id': '10000000-0000-4000-a000-000000000001',
    'type': 'parcel',
    'barcode': 'DGO-9107',
    'description': 'Ahmet Yılmaz — Kayalık Mah.',
    'quantity': 1,
    'amount': null,
    'taskId': null,
    'acquiredAt': '2026-08-28T07:00:00.000Z',
    'rowVersion': 0,
  },
  {
    'id': '10000000-0000-4000-a000-000000000002',
    'type': 'parcel',
    'barcode': 'DGO-9114',
    'description': 'Elif Koç — İstiklal Cd.',
    'quantity': 1,
    'amount': null,
    'taskId': null,
    'acquiredAt': '2026-08-28T07:00:00.000Z',
    'rowVersion': 0,
  },
  {
    'id': '10000000-0000-4000-a000-000000000003',
    'type': 'parcel',
    'barcode': 'DGO-9121',
    'description': 'Mehmet Aydın — Atatürk Mah.',
    'quantity': 1,
    'amount': null,
    'taskId': null,
    'acquiredAt': '2026-08-28T07:00:00.000Z',
    'rowVersion': 0,
  },
];

Map<String, dynamic> mockPayload(String path, RequestOptions options) {
  if (path.endsWith('/v1/config') || path.contains('/v1/config')) {
    return {
      'environment': 'demo',
      'minAndroidBuild': 1,
      'minIosBuild': 1,
      'forceUpdate': false,
      'supportPhone': '+902124440026',
      'opsPhone': '+902124440026',
      'geofenceDefaultRadiusMeters': 200,
      'geofenceMaxAccuracyMeters': 100,
      'featureFlags': {
        'maskedCall': false,
        'cashCollect': true,
        'documentScan': false,
        'custody': false,
        'shiftFaceMatch': false,
        'offlineSync': true,
      },
      'publishedAt': '2026-08-25T17:00:00.000Z',
    };
  }
  if (path.contains('/activation/start')) {
    final now = DateTime.now().toUtc();
    return {
      'challengeId': Vault.newUuid(),
      'codeLength': 6,
      'expiresAt': now.add(const Duration(minutes: 5)).toIso8601String(),
      'resendAvailableAt': now.add(const Duration(seconds: 60)).toIso8601String(),
      'attemptsRemaining': 5,
      'integrityNonce': 'demo-nonce',
    };
  }
  if (path.contains('/auth/token/refresh')) {
    final now = DateTime.now().toUtc();
    return {
      'tokens': {
        'accessToken': 'demo-access',
        'accessTokenExpiresAt': now.add(const Duration(minutes: 15)).toIso8601String(),
        'refreshToken': 'demo-refresh',
        'refreshTokenExpiresAt': now.add(const Duration(days: 30)).toIso8601String(),
      },
      'familyRevoked': false,
    };
  }
  if (path.contains('/activation/verify')) {
    final now = DateTime.now().toUtc();
    return {
      'tokens': {
        'accessToken': 'demo-access',
        'accessTokenExpiresAt': now.add(const Duration(minutes: 15)).toIso8601String(),
        'refreshToken': 'demo-refresh',
        'refreshTokenExpiresAt': now.add(const Duration(days: 30)).toIso8601String(),
      },
      'courier': {
        'id': '00000000-0000-4000-a000-000000000026',
        'fullName': 'Ruken Turhan',
        'phone': '+905321110026',
        'employeeCode': 'DGC-2026-9CF4875F',
        'status': 'active',
        'capabilities': ['DELIVER', 'CASH_COLLECT'],
      },
      'requiredPermissions': ['LOCATION_WHEN_IN_USE', 'CAMERA', 'NOTIFICATIONS'],
    };
  }
  if (path.contains('/sync/batch')) {
    final body = options.data;
    final events = body is Map ? (body['events'] as List? ?? const []) : const [];
    return {
      'results': [
        for (final e in events)
          {
            'clientEventId': (e as Map)['clientEventId'],
            'status': 'applied',
            'appliedAt': DateTime.now().toUtc().toIso8601String(),
          },
      ],
      'serverTime': DateTime.now().toUtc().toIso8601String(),
      'pullRequired': false,
    };
  }
  if (path.contains('/v1/routes/current')) {
    // Real osrm-routed output captured for this exact stop cluster (see
    // apps/api/test/optimizer.test.ts) — not synthetic numbers. Faz 2 found
    // t1-t2-t4-t3 shorter than the t1-t2-t3-t4 dispatch order: 820s/6801m
    // vs. 1127s/9872m on the real road network.
    final now = DateTime.now().toUtc();
    var eta = now;
    Map<String, Object?> stop(String taskId, int sequence, int? distanceMeters, int? durationSeconds) {
      if (durationSeconds != null) eta = eta.add(Duration(seconds: durationSeconds));
      return {
        'taskId': taskId,
        'sequence': sequence,
        'etaAt': eta.toIso8601String(),
        'distanceMeters': distanceMeters,
        'durationSeconds': durationSeconds,
      };
    }

    return {
      'id': Vault.newUuid(),
      'shiftId': Vault.newUuid(),
      'mode': 'distance_optimized',
      'computedAt': now.toIso8601String(),
      'geometry':
          '_kzgFybkpD\\VVVPPNJNLJGFKFSB[?_@@UGWESM[SUOOIIMMQUH@TFl@DjD?@eADm@Eq@?Uv@BXHxAb@nBh@v@T^RrEnHbAfDRtD?n@i@jDFlBR|@BDTb@xAbBVd@xAhG^|Bv@zCj@nAV`Al@hECnAa@nDBnBv@hCf@~BTh@b@d@bCdArAlAvBbAdDlCfAh@rC~@x@|@|@`BJ@RJb@BzAIp@Pb@Pd@VPTLXJf@B`@L\\XTRJFN@RGVK`@CZ@RDLEMASB[Ja@FWASGOSKYUM]Ca@Kg@MYQUe@Wc@Qq@Q{AHc@CSKKA}@aBy@}@sC_AgAi@eDmCwBcAsAmAcCeAc@e@Ui@g@_CWy@_@oACoB`@oDBoAm@iEWaAk@oAw@{C_@}ByAiGWe@yAcBYi@S}@GmBh@kD?o@SuDcAgDsEoH_@Sw@UoBi@yAc@YIw@CS?cEx@eCFo@RqAx@k@^g@LWCUYIIGm@V}AV_Br@}EDWGa@CS@y@EGEKa@GEEGIMOoAcBU[mAyAq@m@KKYIMJB[@GFWTu@BM^w@@YIS?QLc@@k@BYHm@JeA[PIFIDO?C?E@EBQJWHKHi@BUDWZ_@\\[@c@Iw@S',
      'stops': [
        stop('t1', 0, null, null),
        stop('t2', 1, 1185, 145),
        stop('t4', 2, 2799, 383),
        stop('t3', 3, 2817, 292),
      ],
    };
  }
  if (path.contains('/v1/custody/handover')) {
    final body = options.data;
    final itemIds = body is Map ? ((body['itemIds'] as List?)?.cast<String>() ?? const []) : const <String>[];
    final remaining = _demoCustodyItems.where((item) => !itemIds.contains(item['id'])).toList();
    return {
      'handoverId': Vault.newUuid(),
      'remaining': remaining,
      'receipt': null,
      'appliedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }
  if (path.contains('/v1/custody')) {
    return {
      'items': _demoCustodyItems,
      'nextCursor': null,
      'syncedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }
  if (path.contains('/me/availability')) {
    return {
      'status': 'AVAILABLE',
      'vehicle': 'CAR',
      'employmentType': 'PART_TIME',
      'city': 'Denizli',
      'district': 'Güney',
      'weekly': [
        for (var d = 1; d <= 5; d++) {'weekday': d, 'start': '09:00', 'end': '18:00'},
      ],
      'updatedAt': '2026-08-25T17:00:00.000Z',
    };
  }
  if (path.contains('/me/documents')) {
    return {
      'items': [
        {'id': Vault.newUuid(), 'type': 'IDENTITY', 'label': 'Kimlik', 'status': 'COMPLETED'},
        {'id': Vault.newUuid(), 'type': 'DRIVING_LICENSE', 'label': 'Ehliyet', 'status': 'COMPLETED'},
      ],
      'completedCount': 2,
      'requiredCount': 2,
    };
  }
  return <String, dynamic>{};
}
