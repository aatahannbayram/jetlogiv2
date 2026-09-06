import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/vault.dart';
import '../models.dart';
import 'courier_tasks.dart';
import 'models.dart';

const kApiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://kurye.dijigoo.com/api/mobile',
);

const kAppVersion = '1.0.0';
const kAppBuild = 42;

String clientInfoHeader() {
  final os = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  return 'dijigoo-courier/$kAppVersion ($os; build $kAppBuild)';
}

String e164(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('90') && digits.length >= 12) return '+$digits';
  if (digits.startsWith('0') && digits.length >= 11)
    return '+90${digits.substring(1)}';
  if (digits.length == 10) return '+90$digits';
  return '+90$digits';
}

class InboxItemDto {
  const InboxItemDto({required this.item, required this.read});

  final AppNotification item;
  final bool read;
}

class SyncChangesDto {
  const SyncChangesDto({
    required this.tasks,
    required this.removedTaskIds,
    required this.syncedAt,
    this.custody,
    this.notifications = const [],
    this.resyncRequired = false,
  });

  final List<DeliveryTask> tasks;
  final List<String> removedTaskIds;
  final String syncedAt;
  final List<CustodyItemDto>? custody;
  final List<InboxItemDto> notifications;
  final bool resyncRequired;
}

class MobileApi {
  MobileApi({required this.dio, this.vault}) : tasks = CourierTaskClient(dio);

  final Dio dio;
  final Vault? vault;
  final CourierTaskClient tasks;
  bool lastWasLive = false;
  bool lastPullRequired = false;
  String? lastSyncedAt;

  factory MobileApi.create({Vault? vault}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: kApiBase,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'x-client-info': clientInfoHeader(),
          'accept': 'application/json',
        },
      ),
    );
    final refreshDio = Dio(
      BaseOptions(
        baseUrl: kApiBase,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'x-client-info': clientInfoHeader(),
          'accept': 'application/json',
        },
      ),
    );
    dio.interceptors.add(_AuthInterceptor(vault));
    dio.interceptors.add(
      _RefreshInterceptor(vault: vault, refreshDio: refreshDio, dio: dio),
    );
    if (!kReleaseMode) {
      dio.interceptors.add(DemoFallbackInterceptor());
    }
    return MobileApi(dio: dio, vault: vault);
  }

  Future<List<DeliveryTask>> fetchTasks({String? updatedSince}) async {
    final items = <DeliveryTask>[];
    String? cursor;
    var pages = 0;
    do {
      final res = await tasks.list(updatedSince: updatedSince, cursor: cursor);
      lastWasLive = res.extra['demo'] != true;
      final raw = (res.data?['items'] as List?) ?? const [];
      for (final row in raw) {
        if (row is Map) {
          items.add(deliveryTaskFromSummary(Map<String, dynamic>.from(row)));
        }
      }
      final next = res.data?['nextCursor'];
      cursor = next is String && next.isNotEmpty ? next : null;
      final synced = res.data?['syncedAt'];
      if (synced is String && synced.isNotEmpty) lastSyncedAt = synced;
      pages += 1;
    } while (cursor != null && pages < 20);
    return items;
  }

  Future<SyncChangesDto> fetchChanges({String? since}) async {
    final items = <DeliveryTask>[];
    final removed = <String>{};
    List<CustodyItemDto>? custody;
    String? cursor;
    var pages = 0;
    var resyncRequired = false;
    String syncedAt = lastSyncedAt ?? DateTime.now().toUtc().toIso8601String();
    do {
      final res = await dio.get<Map<String, dynamic>>(
        '/v1/sync/changes',
        queryParameters: {
          if (since != null) 'since': since,
          if (cursor != null) 'cursor': cursor,
        },
      );
      lastWasLive = res.extra['demo'] != true;
      final raw = (res.data?['tasks'] as List?) ?? const [];
      for (final row in raw) {
        if (row is Map) {
          items.add(deliveryTaskFromSummary(Map<String, dynamic>.from(row)));
        }
      }
      final gone = (res.data?['removedTaskIds'] as List?) ?? const [];
      for (final id in gone) {
        if (id is String && id.isNotEmpty) removed.add(id);
      }
      if (res.data?['resyncRequired'] == true) resyncRequired = true;
      final rawCustody = res.data?['custody'] as List?;
      if (rawCustody != null) {
        custody = [
          for (final row in rawCustody)
            if (row is Map)
              CustodyItemDto.fromJson(Map<String, dynamic>.from(row)),
        ];
      }
      final synced = res.data?['syncedAt'];
      if (synced is String && synced.isNotEmpty) {
        syncedAt = synced;
        lastSyncedAt = synced;
      }
      final next = res.data?['nextCursor'];
      cursor = next is String && next.isNotEmpty ? next : null;
      pages += 1;
    } while (cursor != null && pages < 20 && !resyncRequired);
    return SyncChangesDto(
      tasks: items,
      removedTaskIds: removed.toList(),
      syncedAt: syncedAt,
      custody: custody,
      resyncRequired: resyncRequired,
    );
  }

  Future<List<SupportTicketDto>> fetchSupportTickets() async {
    final items = <SupportTicketDto>[];
    String? cursor;
    var pages = 0;
    do {
      final res = await dio.get<Map<String, dynamic>>(
        '/v1/support/tickets',
        queryParameters: {if (cursor != null) 'cursor': cursor},
      );
      lastWasLive = res.extra['demo'] != true;
      final raw = (res.data?['items'] as List?) ?? const [];
      for (final row in raw) {
        if (row is Map) {
          items.add(SupportTicketDto.fromJson(Map<String, dynamic>.from(row)));
        }
      }
      final next = res.data?['nextCursor'];
      cursor = next is String && next.isNotEmpty ? next : null;
      pages += 1;
    } while (cursor != null && pages < 20);
    return items;
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

  Future<Map<String, dynamic>> startActivation(
    String phone,
    String installationId,
  ) async {
    final res = await dio.post<Map<String, dynamic>>(
      '/v1/auth/activation/start',
      data: {'phone': e164(phone), 'device': _device(installationId)},
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
    final tokens = Map<String, dynamic>.from(
      res.data?['tokens'] as Map? ?? const {},
    );
    return TokenPair(
      accessToken: tokens['accessToken'] as String? ?? 'demo-access',
      refreshToken: tokens['refreshToken'] as String? ?? 'demo-refresh',
      accessExpiresAt:
          DateTime.tryParse(tokens['accessTokenExpiresAt'] as String? ?? '') ??
          DateTime.now().toUtc().add(const Duration(minutes: 15)),
      refreshExpiresAt:
          DateTime.tryParse(tokens['refreshTokenExpiresAt'] as String? ?? '') ??
          DateTime.now().toUtc().add(const Duration(days: 30)),
    );
  }

  Future<ShiftDto?> fetchCurrentShift() async {
    final res = await dio.get<dynamic>('/v1/shifts/current');
    lastWasLive = res.extra['demo'] != true;
    final data = res.data;
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    if (map.isEmpty) return null;
    final id = map['id'] as String?;
    if (id == null || id.isEmpty) return null;
    return ShiftDto.fromJson(map);
  }

  Future<MaskedCallDto> startMaskedCall(
    String taskId, {
    String target = 'recipient',
  }) async {
    final res = await dio.post<Map<String, dynamic>>(
      '/v1/tasks/$taskId/call',
      data: {'target': target},
    );
    lastWasLive = res.extra['demo'] != true;
    return MaskedCallDto.fromJson(res.data ?? const {});
  }

  Future<PresignResult> presignMedia({
    required String mediaId,
    required String kind,
    required String contentType,
    required int byteSize,
    required String sha256,
    String? taskId,
    String? stepKey,
    double? lat,
    double? lng,
  }) async {
    final res = await dio.post<Map<String, dynamic>>(
      '/v1/media/presign',
      data: {
        'mediaId': mediaId,
        'kind': kind,
        'contentType': contentType,
        'byteSize': byteSize,
        'sha256': sha256,
        if (taskId != null && taskId.contains('-')) 'taskId': taskId,
        if (stepKey != null) 'stepKey': stepKey,
        'capturedAt': DateTime.now().toUtc().toIso8601String(),
        if (lat != null && lng != null)
          'capturedAt_location': {
            'lat': lat,
            'lng': lng,
            'accuracy': 25,
            'capturedAt': DateTime.now().toUtc().toIso8601String(),
            'isMocked': false,
          },
      },
    );
    lastWasLive = res.extra['demo'] != true;
    return PresignResult.fromJson(res.data ?? const {});
  }

  Future<void> confirmMedia(String mediaId) async {
    await dio.post<Map<String, dynamic>>('/v1/media/$mediaId/confirm');
    lastWasLive = true;
  }

  Future<Map<String, dynamic>> sendTaskOtp({
    required String taskId,
    required String stepKey,
    String channel = 'sms',
  }) async {
    final res = await dio.post<Map<String, dynamic>>(
      '/v1/tasks/$taskId/otp/send',
      data: {'stepKey': stepKey, 'channel': channel},
    );
    lastWasLive = res.extra['demo'] != true;
    return res.data ?? const {};
  }

  Future<Map<String, dynamic>> verifyTaskOtp({
    required String taskId,
    required String challengeId,
    required String code,
  }) async {
    final res = await dio.post<Map<String, dynamic>>(
      '/v1/tasks/$taskId/otp/verify',
      data: {'challengeId': challengeId, 'code': code},
    );
    lastWasLive = res.extra['demo'] != true;
    return res.data ?? const {};
  }

  /// Today's optimized stop order (apps/api `GET /v1/routes/current`) — real
  /// road-network distances/geometry and, past 2 stops, a reordered sequence
  /// (see apps/api/src/services/optimizer.ts). Null on 204 (no open shift or
  /// no geocoded stops yet), matching the API contract rather than throwing.
  Future<RoutePlanDto?> fetchRoute({double? lat, double? lng}) async {
    final res = await dio.get<Map<String, dynamic>>(
      '/v1/routes/current',
      queryParameters: {
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      },
    );
    lastWasLive = res.extra['demo'] != true;
    if (res.statusCode == 204 || res.data == null || res.data!.isEmpty)
      return null;
    return RoutePlanDto.fromJson(res.data!);
  }

  /// What the courier currently holds (apps/api `GET /v1/custody`).
  /// [barcode] looks up a tenant item for takeover, not only items already held.
  Future<List<CustodyItemDto>> fetchCustody({String? type, String? barcode}) async {
    final res = await dio.get<Map<String, dynamic>>(
      '/v1/custody',
      queryParameters: {
        if (type != null) 'type': type,
        if (barcode != null && barcode.isNotEmpty) 'barcode': barcode,
      },
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

  Future<CustodyHandoverResultDto> takeoverFromBranch({
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
        'direction': 'takeover',
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
    lastPullRequired = res.data?['pullRequired'] == true;
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
    final ios =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
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
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await vault?.accessToken;
      if (token != null && token.isNotEmpty) {
        options.headers['authorization'] = 'Bearer $token';
      }
      handler.next(options);
    } catch (e, st) {
      handler.reject(
        DioException(requestOptions: options, error: e, stackTrace: st),
      );
    }
  }
}

/// 401 → `/v1/auth/token/refresh` on a bare dio so this interceptor cannot loop.
class _RefreshInterceptor extends QueuedInterceptor {
  _RefreshInterceptor({
    required this.vault,
    required this.refreshDio,
    required this.dio,
  });

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
    if (store == null ||
        refresh == null ||
        refresh.isEmpty ||
        refresh == 'demo-refresh') {
      handler.next(err);
      return;
    }
    try {
      final install = await store.installationId();
      final res = await refreshDio.post<Map<String, dynamic>>(
        '/v1/auth/token/refresh',
        data: {'refreshToken': refresh, 'installationId': install},
      );
      final tokens = Map<String, dynamic>.from(
        res.data?['tokens'] as Map? ?? const {},
      );
      final access = tokens['accessToken'] as String?;
      final nextRefresh = tokens['refreshToken'] as String?;
      if (access == null || nextRefresh == null) {
        handler.next(err);
        return;
      }
      await store.saveTokens(
        accessToken: access,
        refreshToken: nextRefresh,
        accessExpiresAt:
            DateTime.tryParse(
              tokens['accessTokenExpiresAt'] as String? ?? '',
            ) ??
            DateTime.now().toUtc().add(const Duration(minutes: 15)),
        refreshExpiresAt:
            DateTime.tryParse(
              tokens['refreshTokenExpiresAt'] as String? ?? '',
            ) ??
            DateTime.now().toUtc().add(const Duration(days: 30)),
      );
      err.requestOptions.headers['authorization'] = 'Bearer $access';
      err.requestOptions.extra['authRetry'] = true;
      handler.resolve(
        await dio.fetch<Map<String, dynamic>>(err.requestOptions),
      );
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
    final mockable =
        path.contains('/me/availability') ||
        path.contains('/me/documents') ||
        path.contains('/v1/routes/current') ||
        path.contains('/v1/tasks') ||
        path.contains('/v1/support/tickets') ||
        path.contains('/v1/sync/changes') ||
        path.contains('/v1/shifts');
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

Map<String, Object?> _demoTask({
  required String id,
  required String reference,
  required String name,
  required String line1,
  required String district,
  required int sequence,
  required String status,
  required double lat,
  required double lng,
  String type = 'DELIVERY',
  double? slotHour,
  int? itemCount,
  double? codAmount,
  String? note,
}) {
  final day = DateTime.utc(2026, 8, 25, 14);
  final start = day.add(Duration(minutes: ((slotHour ?? 14.5) * 60).round() - 14 * 60));
  return {
    'id': id,
    'reference': reference,
    'type': type,
    'status': status,
    'sequence': sequence,
    'address': {
      'line1': line1,
      'district': district,
      'city': 'Denizli',
      'countryCode': 'TR',
      'coordinates': {'lat': lat, 'lng': lng},
    },
    'contact': {
      'name': name,
      'maskedPhone': '+905321110026',
      'hasReachablePhone': true,
    },
    'slotStartAt': start.toIso8601String(),
    'slotEndAt': start.add(const Duration(minutes: 30)).toIso8601String(),
    'priority': 'normal',
    'itemCount': itemCount ?? 1,
    'codAmount': codAmount,
    'updatedAt': '2026-08-25T10:00:00.000Z',
    'rowVersion': 0,
    'notes': note,
    'workflow': {'version': 1},
  };
}

final _demoTaskSummaries = [
  _demoTask(
    id: 't1',
    reference: 'DGO-8841',
    name: 'Ahmet Yılmaz',
    line1: 'Kayalık Mah. Cumhuriyet Cd. No:14',
    district: 'Güney',
    sequence: 1,
    status: 'ASSIGNED',
    lat: 38.1512,
    lng: 29.0614,
    itemCount: 2,
    slotHour: 14.5,
  ),
  _demoTask(
    id: 't2',
    reference: 'DGO-8842',
    name: 'Elif Koç',
    line1: 'İstiklal Cd. No:8 D:3',
    district: 'Güney',
    sequence: 2,
    status: 'ASSIGNED',
    lat: 38.1481,
    lng: 29.0558,
    type: 'DOCUMENT',
    slotHour: 15,
  ),
  _demoTask(
    id: 't3',
    reference: 'DGO-8843',
    name: 'Mehmet Aydın',
    line1: 'Atatürk Mah. 7. Sk. No:22',
    district: 'Güney',
    sequence: 3,
    status: 'ASSIGNED',
    lat: 38.1554,
    lng: 29.0692,
    itemCount: 1,
    codAmount: 185,
    slotHour: 15.75,
  ),
  _demoTask(
    id: 't4',
    reference: 'DGO-8844',
    name: 'Fatma Şahin',
    line1: 'Yeni Mah. Okul Sk. No:4',
    district: 'Güney',
    sequence: 4,
    status: 'ASSIGNED',
    lat: 38.1460,
    lng: 29.0488,
    note: 'Alıcı yoktu · kapı fotoğrafı kuyrukta',
    slotHour: 13,
  ),
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
        'maskedCall': true,
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
      'resendAvailableAt': now
          .add(const Duration(seconds: 60))
          .toIso8601String(),
      'attemptsRemaining': 5,
      'integrityNonce': 'demo-nonce',
    };
  }
  if (path.contains('/auth/token/refresh')) {
    final now = DateTime.now().toUtc();
    return {
      'tokens': {
        'accessToken': 'demo-access',
        'accessTokenExpiresAt': now
            .add(const Duration(minutes: 15))
            .toIso8601String(),
        'refreshToken': 'demo-refresh',
        'refreshTokenExpiresAt': now
            .add(const Duration(days: 30))
            .toIso8601String(),
      },
      'familyRevoked': false,
    };
  }
  if (path.contains('/activation/verify')) {
    final now = DateTime.now().toUtc();
    return {
      'tokens': {
        'accessToken': 'demo-access',
        'accessTokenExpiresAt': now
            .add(const Duration(minutes: 15))
            .toIso8601String(),
        'refreshToken': 'demo-refresh',
        'refreshTokenExpiresAt': now
            .add(const Duration(days: 30))
            .toIso8601String(),
      },
      'courier': {
        'id': '00000000-0000-4000-a000-000000000026',
        'fullName': 'Ruken Turhan',
        'phone': '+905321110026',
        'employeeCode': 'DGC-2026-9CF4875F',
        'status': 'active',
        'capabilities': ['DELIVER', 'CASH_COLLECT'],
      },
      'requiredPermissions': [
        'LOCATION_WHEN_IN_USE',
        'CAMERA',
        'NOTIFICATIONS',
      ],
    };
  }
  if (path.contains('/sync/batch')) {
    final body = options.data;
    final events = body is Map
        ? (body['events'] as List? ?? const [])
        : const [];
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
  if (path.contains('/v1/shifts/current')) {
    return <String, dynamic>{};
  }
  if (path.contains('/v1/shifts/start') || path.contains('/v1/shifts/end')) {
    final now = DateTime.now().toUtc().toIso8601String();
    return {
      'id': Vault.newUuid(),
      'courierId': '00000000-0000-4000-a000-000000000026',
      'status': path.contains('/end') ? 'closed' : 'active',
      'startedAt': now,
      'endedAt': path.contains('/end') ? now : null,
      'taskCount': 0,
      'completedCount': 0,
    };
  }
  if (path.contains('/v1/sync/changes')) {
    return {
      'tasks': _demoTaskSummaries,
      'removedTaskIds': const <String>[],
      'custody': _demoCustodyItems,
      'removedCustodyIds': const <String>[],
      'shift': null,
      'workflows': const [],
      'nextCursor': null,
      'syncedAt': DateTime.now().toUtc().toIso8601String(),
      'resyncRequired': false,
    };
  }
  if (path.contains('/v1/support/tickets')) {
    if (options.method == 'POST' ||
        (options.data is Map && (options.data as Map).containsKey('subject'))) {
      final body = options.data is Map
          ? Map<String, dynamic>.from(options.data as Map)
          : const <String, dynamic>{};
      return {
        'id': Vault.newUuid(),
        'reference': 'DST-DEMO-1',
        'category': body['category'] ?? 'OTHER',
        'subject': body['subject'] ?? 'Destek',
        'body': body['body'] ?? '',
        'status': 'open',
        'priority': 'normal',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'media': const [],
      };
    }
    return {
      'items': [
        {
          'id': '20000000-0000-4000-a000-000000000001',
          'reference': 'DST-20260825-DEMO',
          'category': 'ADDRESS_PROBLEM',
          'subject': 'Kapı numarası görünmüyor',
          'body': 'DGO-8841 adresinde bina girişi karanlık.',
          'status': 'open',
          'priority': 'high',
          'taskId': 't1',
          'createdAt': '2026-08-25T09:00:00.000Z',
          'updatedAt': '2026-08-25T09:00:00.000Z',
          'media': const [],
        },
      ],
      'nextCursor': null,
      'syncedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }
  if (path.contains('/media/presign')) {
    return {
      'mediaId': (options.data is Map ? (options.data as Map)['mediaId'] : null) ??
          Vault.newUuid(),
      'uploadUrl': 'about:blank',
      'method': 'PUT',
      'headers': <String, String>{},
      'expiresAt': DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 10))
          .toIso8601String(),
      'alreadyUploaded': true,
    };
  }
  if (path.contains('/otp/send')) {
    return {
      'challengeId': Vault.newUuid(),
      'maskedPhone': '+90 532 *** ** 26',
      'expiresAt': DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 5))
          .toIso8601String(),
      'resendAvailableAt': DateTime.now()
          .toUtc()
          .add(const Duration(seconds: 30))
          .toIso8601String(),
      'attemptsRemaining': 5,
    };
  }
  if (path.contains('/otp/verify')) {
    return {
      'verified': true,
      'verificationToken': 'demo-otp-token',
      'attemptsRemaining': 4,
    };
  }
  if (path.contains('/call')) {
    return {
      'dialNumber': '+905321110026',
      'sessionId': Vault.newUuid(),
      'expiresAt': DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 10))
          .toIso8601String(),
    };
  }
  if (path.contains('/v1/tasks') &&
      !path.contains('/finalize') &&
      !path.contains('/transition') &&
      !path.contains('/steps') &&
      !path.contains('/call') &&
      !path.contains('/otp')) {
    return {
      'items': _demoTaskSummaries,
      'nextCursor': null,
      'syncedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }
  if (path.contains('/v1/routes/current')) {
    // Real osrm-routed output captured for this exact stop cluster (see
    // apps/api/test/optimizer.test.ts) — not synthetic numbers. Faz 2 found
    // t1-t2-t4-t3 shorter than the t1-t2-t3-t4 dispatch order: 820s/6801m
    // vs. 1127s/9872m on the real road network.
    final now = DateTime.now().toUtc();
    final plan = RoutePlanDto.demo(now: now);
    return {
      'id': plan.id,
      'shiftId': Vault.newUuid(),
      'mode': plan.mode,
      'computedAt': plan.computedAt,
      'geometry': plan.geometry,
      'stops': [
        for (final s in plan.stops)
          {
            'taskId': s.taskId,
            'sequence': s.sequence,
            'etaAt': s.etaAt,
            'distanceMeters': s.distanceMeters,
            'durationSeconds': s.durationSeconds,
          },
      ],
    };
  }
  if (path.contains('/v1/custody/handover')) {
    final body = options.data;
    final itemIds = body is Map
        ? ((body['itemIds'] as List?)?.cast<String>() ?? const [])
        : const <String>[];
    final remaining = _demoCustodyItems
        .where((item) => !itemIds.contains(item['id']))
        .toList();
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
        for (var d = 1; d <= 5; d++)
          {'weekday': d, 'start': '09:00', 'end': '18:00'},
      ],
      'updatedAt': '2026-08-25T17:00:00.000Z',
    };
  }
  if (path.contains('/me/documents')) {
    return {
      'items': [
        {
          'id': Vault.newUuid(),
          'type': 'IDENTITY',
          'label': 'Kimlik',
          'status': 'COMPLETED',
        },
        {
          'id': Vault.newUuid(),
          'type': 'DRIVING_LICENSE',
          'label': 'Ehliyet',
          'status': 'COMPLETED',
        },
      ],
      'completedCount': 2,
      'requiredCount': 2,
    };
  }
  return <String, dynamic>{};
}
