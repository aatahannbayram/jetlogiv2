import 'dart:convert';

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
    final cookieJar = PersistCookieJar(storage: VaultCookieStorage(vault));
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
    return _openSession(res.data?['data'] as Map?);
  }

  Future<PanelCourierProfileDto> _openSession(Map? data) async {
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

  /// Şifreyi değiştirir. Sunucu tüm eski oturumları kapatır ve yeni token
  /// döner; token hemen güvenli depoya yazılır.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final res = await _post('/courier-auth/change-password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
      'newPasswordConfirmation': newPassword,
    });
    final token = (res.data?['data'] as Map?)?['accessToken'] as String?;
    if (token != null && token.isNotEmpty) {
      _accessToken = token;
      await _vault?.writeSecret(kPanelBearerKey, token);
    }
  }

  Future<AvailabilityDto> fetchAvailability() async {
    final res = await _get('/courier-availability');
    return AvailabilityDto.fromJson(
      Map<String, dynamic>.from(res.data?['data'] as Map? ?? const {}),
    );
  }

  /// Haftalık planı tümüyle yeniler; gönderilmeyen istisna silinir, bu yüzden
  /// okunan istisnalar aynen geri gönderilir.
  Future<void> saveAvailability(AvailabilityDto plan) async {
    try {
      await dio.put<Map<String, dynamic>>(
        '/courier-availability',
        data: plan.toJson(),
      );
    } on DioException catch (e) {
      throw _panelException(e);
    }
  }

  Map<String, dynamic> _map(Object? raw) =>
      raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

  List<Map<String, dynamic>> _maps(Object? raw) => [
    for (final row in raw is List ? raw : const [])
      if (row is Map) Map<String, dynamic>.from(row),
  ];

  /// Seviye, teslim istatistiği ve rozetler.
  Future<Map<String, dynamic>> fetchProfileSummary() async =>
      _map((await _get('/courier-profile/summary')).data?['data']);

  /// Profilin ham `courier` nesnesi (araç, çalışma şekli, il/ilçe).
  Future<Map<String, dynamic>> fetchProfileRaw() async =>
      _map(_map((await _get('/courier-profile')).data?['data'])['courier']);

  Future<List<Map<String, dynamic>>> fetchProfileChangeRequests() async =>
      _maps(
        _map(
          (await _get('/courier-profile/change-requests')).data?['data'],
        )['requests'],
      );

  /// [changeType]: ADDRESS, VEHICLE ya da WORK. Değişiklik hemen uygulanır;
  /// bilgiler aynıysa `NO_CHANGE` döner.
  Future<void> createProfileChangeRequest({
    required String changeType,
    required Map<String, Object?> requestedData,
    String? note,
  }) async {
    await _post('/courier-profile/change-requests', {
      'changeType': changeType,
      'requestedData': requestedData,
      if (note != null && note.isNotEmpty) 'courierNote': note,
    });
  }

  Future<void> cancelProfileChangeRequest(String requestId) async {
    await _post('/courier-profile/change-requests/$requestId/cancel', const {});
  }

  Future<List<({int id, String name})>> fetchCities() async => [
    for (final row in _maps((await _get('/geography/cities')).data?['data']))
      if (row['id'] is num)
        (id: (row['id'] as num).toInt(), name: row['name'] as String? ?? ''),
  ]..sort((a, b) => a.name.compareTo(b.name));

  Future<List<({int id, String name})>> fetchDistricts(int cityId) async => [
    for (final row in _maps(
      (await _get('/geography/cities/$cityId/districts')).data?['data'],
    ))
      if (row['id'] is num)
        (id: (row['id'] as num).toInt(), name: row['name'] as String? ?? ''),
  ]..sort((a, b) => a.name.compareTo(b.name));

  /// Başvuruda verilen onaylar ve sözleşmeler.
  Future<Map<String, dynamic>> fetchMyContracts() async =>
      _map((await _get('/courier-my-contracts')).data?['data']);

  /// Kuryenin kendi başvurusu: numara, durum, belge özeti.
  Future<Map<String, dynamic>> fetchMyApplication() async => _map(
    _map((await _get('/courier-application')).data?['data'])['application'],
  );

  /// Kuryenin üzerindeki gönderiler; `overdue` 24 saati geçenleri işaretler.
  Future<List<Map<String, dynamic>>> fetchCustodyOnCourier() async => _maps(
    _map((await _get('/courier-custody/overview')).data?['data'])['onCourier'],
  );

  /// Son 7 günün vardiyaları ve toplamları.
  Future<Map<String, dynamic>> fetchShiftHistory() async =>
      _map((await _get('/courier-shifts')).data?['data']);

  /// Gönderinin geçerli kanıtları (fotoğraf, imza, belge), yeniden eskiye.
  Future<List<Map<String, dynamic>>> fetchTaskEvidence(
    String shipmentId,
  ) async => _maps(
    _map(
      (await _get('/courier-tasks/$shipmentId/evidence')).data?['data'],
    )['evidences'],
  );

  Future<List<int>> fetchTaskEvidenceFile(
    String shipmentId,
    String evidenceId,
  ) async {
    try {
      final res = await dio.get<List<int>>(
        '/courier-tasks/$shipmentId/evidence/$evidenceId/file',
        options: Options(responseType: ResponseType.bytes),
      );
      return res.data ?? const [];
    } on DioException catch (e) {
      throw _panelException(e);
    }
  }

  /// Yalnız kuryenin yüklediği ve kapatılmış denemeye bağlanmamış kanıt
  /// silinir; diğerlerinde `EVIDENCE_NOT_DELETABLE` / `EVIDENCE_LOCKED`.
  Future<void> deleteTaskEvidence(String shipmentId, String evidenceId) async {
    try {
      await dio.delete<Map<String, dynamic>>(
        '/courier-tasks/$shipmentId/evidence/$evidenceId',
        options: Options(headers: {'Idempotency-Key': Vault.newUuid()}),
      );
    } on DioException catch (e) {
      throw _panelException(e);
    }
  }

  Future<int> fetchUnreadNotificationCount() async =>
      (_map(
                (await _get('/courier-notifications/unread-count'))
                    .data?['data'],
              )['total']
              as num?)
          ?.toInt() ??
      0;

  // ---- Giriş öncesi: başvuru, hesap açma, aday evrakları (oturum gerekmez)

  /// false ise bu telefonla başvuru zaten var.
  Future<bool> checkApplicationPhone(String phone) async =>
      _map(
        (await _get(
          '/courier-applications/check-phone',
          queryParameters: {'phone': phone},
        )).data?['data'],
      )['canApply'] !=
      false;

  /// Başvuruda gösterilecek güncel onay metinleri.
  Future<List<Map<String, dynamic>>> fetchApplicationConsents() async => _maps(
    _map(
      (await _get(
        '/courier-consents',
        queryParameters: {'locale': 'tr'},
      )).data?['data'],
    )['items'],
  );

  /// Başvuru numarasını döner.
  Future<String> submitApplication(Map<String, Object?> body) async =>
      '${_map((await _post('/courier-applications', body)).data?['data'])['applicationNumber'] ?? ''}';

  /// E-postadaki aktivasyon bağlantısını doğrular; hesap özetini döner.
  Future<Map<String, dynamic>> validateActivation(String token) async => _map(
    _map(
      (await _get(
        '/courier-auth/activate',
        queryParameters: {'token': token},
      )).data?['data'],
    )['account'],
  );

  /// İlk şifreyi belirler. Oturum açılmaz; ardından giriş yapılır.
  Future<void> activateAccount({
    required String token,
    required String password,
  }) async {
    await _post('/courier-auth/activate', {
      'token': token,
      'password': password,
      'passwordConfirmation': password,
    });
  }

  Future<Map<String, dynamic>> fetchDocumentPortal({
    required String publicId,
    required String token,
  }) async => _map(
    (await _get(
      '/courier-documents/$publicId',
      queryParameters: {'token': token},
    )).data?['data'],
  );

  /// [side]: SINGLE, FRONT ya da BACK. [expiresAt] `YYYY-MM-DD`.
  Future<void> uploadPortalDocument({
    required String publicId,
    required String token,
    required String documentRequestId,
    required String side,
    required List<int> bytes,
    String filename = 'belge.jpg',
    String contentType = 'image/jpeg',
    String? expiresAt,
  }) async {
    try {
      await dio.post<Map<String, dynamic>>(
        '/courier-documents/$publicId/requests/$documentRequestId/upload',
        queryParameters: {'token': token, 'side': side},
        data: FormData.fromMap({
          'expiresAt': ?expiresAt,
          'file': MultipartFile.fromBytes(
            bytes,
            filename: filename,
            contentType: DioMediaType.parse(contentType),
          ),
        }),
      );
    } on DioException catch (e) {
      throw _panelException(e);
    }
  }

  Future<void> submitPortalDocuments({
    required String publicId,
    required String token,
  }) async {
    try {
      await dio.post<Map<String, dynamic>>(
        '/courier-documents/$publicId/submit',
        queryParameters: {'token': token},
      );
    } on DioException catch (e) {
      throw _panelException(e);
    }
  }

  /// SMS ile giriş, 1. adım: kayıtlı telefona 6 haneli kod gönderir. Hesap
  /// bulunamasa da yanıt aynıdır. Kod 5 dk geçerli, 60 sn'de bir istenir.
  Future<({String? challengeId, int resendAfterSeconds})> requestSmsLogin(
    String identifier,
  ) async {
    final res = await _post('/courier-auth/sms/request', {
      'identifier': identifier,
    });
    final data = res.data?['data'] as Map? ?? const {};
    return (
      challengeId: data['challengeId'] as String?,
      resendAfterSeconds: (data['resendAfterSeconds'] as num?)?.toInt() ?? 60,
    );
  }

  /// SMS ile giriş, 2. adım: şifreli girişle aynı oturumu açar.
  Future<PanelCourierProfileDto> verifySmsLogin({
    required String challengeId,
    required String code,
  }) async {
    final res = await _post('/courier-auth/sms/verify', {
      'challengeId': challengeId,
      'code': code,
    });
    return _openSession(res.data?['data'] as Map?);
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
    final res = await _get(
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
    final res = await _get('/courier-tasks/$shipmentId');
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

  Future<({String phone, String telUri})> callRecipient(
    String shipmentId,
  ) async {
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

  /// [shipmentId] verilirse liste o gönderinin ürününe göre süzülür (ör.
  /// Pluxee ziyaretinde yalnız ziyaret nedenleri döner).
  Future<List<({String code, String name})>> fetchDeliveryReasons({
    String? shipmentId,
  }) async {
    final res = await _get(
      '/courier-tasks/delivery-reasons',
      queryParameters: {'locale': 'tr', 'shipmentId': ?shipmentId},
    );
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
    String? category,
    Map<String, Object?>? captureCheck,
    double? latitude,
    double? longitude,
    DateTime? capturedAt,
  }) async {
    final key = Vault.newUuid();
    final form = FormData.fromMap({
      'evidenceType': evidenceType,
      'idempotencyKey': key,
      if (requirementCode != null) 'requirementCode': requirementCode,
      'category': ?category,
      // Çekim anı kontrolleri JSON metni olarak gider.
      if (captureCheck != null) 'captureCheck': jsonEncode(captureCheck),
      if (latitude != null && longitude != null) ...{
        'latitude': latitude,
        'longitude': longitude,
      },
      if (capturedAt != null)
        'capturedAt': capturedAt.toUtc().toIso8601String(),
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: DioMediaType.parse(contentType),
      ),
    });
    final Response<Map<String, dynamic>> res;
    try {
      res = await dio.post<Map<String, dynamic>>(
        '/courier-tasks/$shipmentId/evidence',
        data: form,
        options: Options(headers: {'Idempotency-Key': key}),
      );
    } on DioException catch (e) {
      throw _panelException(e);
    }
    final data = res.data?['data'] as Map? ?? const {};
    final evidence = data['evidence'];
    return (evidence is Map ? evidence['id'] as String? : null) ??
        data['evidenceId'] as String? ??
        data['id'] as String?;
  }

  /// Ziyaret anketini kaydeder. [submitted] false ise taslak kalır.
  Future<void> saveTaskForm(
    String shipmentId, {
    required String formVersionId,
    required Map<String, Object?> values,
    bool submitted = true,
  }) async {
    try {
      await dio.put<Map<String, dynamic>>(
        '/courier-tasks/$shipmentId/form',
        data: {
          'formVersionId': formVersionId,
          'status': submitted ? 'SUBMITTED' : 'DRAFT',
          'values': values,
        },
        options: Options(headers: {'Idempotency-Key': Vault.newUuid()}),
      );
    } on DioException catch (e) {
      throw _panelException(e);
    }
  }

  /// Duyuru için "okudum, anladım" onayı; bildirimi de okundu yapar.
  Future<void> acknowledgeAnnouncement(String announcementId) async {
    await _post(
      '/courier-notifications/announcements/$announcementId/ack',
      const {},
      idempotencyKey: Vault.newUuid(),
    );
  }

  /// Kuryeye gelen ve kuryeden çıkan zimmet hareketleri, yeniden eskiye.
  Future<List<CustodyMoveDto>> fetchCustodyHistory({int limit = 50}) async {
    final res = await _get(
      '/courier-custody/history',
      queryParameters: {'limit': limit},
    );
    final items = (res.data?['data'] as Map?)?['items'] as List? ?? const [];
    return [
      for (final row in items)
        if (row is Map) CustodyMoveDto.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<List<TaskReportDto>> fetchReports(String shipmentId) async {
    final res = await _get('/courier-tasks/$shipmentId/reports');
    final rows = (res.data?['data'] as Map?)?['reports'] as List? ?? const [];
    return [
      for (final row in rows)
        if (row is Map) TaskReportDto.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// İki imzalı dijital tutanak. İmzalar PNG data URL'dir.
  Future<void> createReport(
    String shipmentId, {
    required String reportType,
    required String courierSignature,
    required String courierName,
    required String counterpartSignature,
    required String counterpartName,
    String? counterpartRole,
    String? note,
    double? latitude,
    double? longitude,
    required String idempotencyKey,
  }) async {
    await _post('/courier-tasks/$shipmentId/reports', {
      'reportType': reportType,
      'status': 'SUBMITTED',
      if (note != null && note.isNotEmpty) 'note': note,
      'courierSignature': {
        'dataUrl': courierSignature,
        'signerName': courierName,
      },
      'counterpartSignature': {
        'dataUrl': counterpartSignature,
        'signerName': counterpartName,
        if (counterpartRole != null && counterpartRole.isNotEmpty)
          'signerRole': counterpartRole,
      },
      if (latitude != null && longitude != null) ...{
        'latitude': latitude,
        'longitude': longitude,
      },
    }, idempotencyKey: idempotencyKey);
  }

  /// Hatalarım: kontrolde reddedilen fotoğraflar ve fotoğraf puanı.
  Future<PhotoMistakesDto> fetchPhotoMistakes() async {
    final res = await _get('/courier-mistakes');
    return PhotoMistakesDto.fromJson(
      Map<String, dynamic>.from(res.data?['data'] as Map? ?? const {}),
    );
  }

  /// Ana sayfa kartı için: okunmamış hata sayısı ve puan.
  Future<PhotoMistakesDto> fetchPhotoMistakeCount() async {
    final res = await _get('/courier-mistakes/count');
    return PhotoMistakesDto.fromJson(
      Map<String, dynamic>.from(res.data?['data'] as Map? ?? const {}),
    );
  }

  Future<void> acknowledgePhotoMistake(String evidenceId) async {
    await _post('/courier-mistakes/$evidenceId/acknowledge', const {});
  }

  Future<List<int>> fetchPhotoMistakeFile(String evidenceId) async {
    try {
      final res = await dio.get<List<int>>(
        '/courier-mistakes/$evidenceId/file',
        options: Options(responseType: ResponseType.bytes),
      );
      return res.data ?? const [];
    } on DioException catch (e) {
      throw _panelException(e);
    }
  }

  Future<({String? city, String? district, String? vehicle, String? status})>
  fetchCourierProfile() async {
    final res = await _get('/courier-profile');
    final courier = (res.data?['data'] as Map?)?['courier'] as Map? ?? const {};
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
    final summary = (res.data?['data'] as Map?)?['summary'] as Map? ?? const {};
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
    double? heading,
    double? speed,
    DateTime? capturedAt,
  }) async {
    await _post('/courier-tasks/$shipmentId/location', {
      'purposeCode': purposeCode,
      'latitude': latitude,
      'longitude': longitude,
      if (accuracy != null) 'accuracy': accuracy,
      if (heading != null) 'heading': heading,
      if (speed != null) 'speed': speed,
      'capturedAt': (capturedAt ?? DateTime.now()).toUtc().toIso8601String(),
    });
  }

  /// `outcome`: `DELIVERED` ya da `FAILED`. Teslim edilemedi'de [reasonCode]
  /// zorunlu ve `delivery-reasons` listesinden olmalı. `Idempotency-Key`
  /// zorunlu (8–200); kuyruktan yeniden denemede aynı anahtar gider, gövde
  /// değiştiyse (eksik gereksinim giderildi) yeni anahtar gerekir.
  Future<PanelFinalizeResultDto> finalizeTask(
    String shipmentId, {
    required String outcome,
    required String idempotencyKey,
    String? reasonCode,
    String? receivedBy,
    String? otpEvidenceId,
    String? note,
    double? latitude,
    double? longitude,
    DateTime? capturedAt,
  }) async {
    final delivered = outcome != 'FAILED' && outcome != 'DELIVERY_FAILED';
    final res = await _post('/courier-tasks/$shipmentId/finalize', {
      'resultCode': delivered ? 'DELIVERED' : 'DELIVERY_FAILED',
      if (!delivered && reasonCode != null) 'reasonCode': reasonCode,
      if (delivered && receivedBy != null) 'receivedByName': receivedBy,
      if (delivered && otpEvidenceId != null) 'otpEvidenceId': otpEvidenceId,
      if (note != null && note.isNotEmpty) 'note': note,
      if (latitude != null && longitude != null) ...{
        'latitude': latitude,
        'longitude': longitude,
        if (capturedAt != null)
          'capturedAt': capturedAt.toUtc().toIso8601String(),
      },
    }, idempotencyKey: idempotencyKey);
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
      id:
          json['itemId'] as String? ??
          json['id'] as String? ??
          json['shipmentId'] as String? ??
          '',
      type: json['type'] as String? ?? 'parcel',
      barcode: json['barcode'] as String? ?? json['shipmentNumber'] as String?,
      description:
          json['recipientName'] as String? ??
          json['description'] as String? ??
          '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      taskId: json['shipmentId'] as String? ?? json['taskId'] as String?,
      acquiredAt:
          json['since'] as String? ?? json['acquiredAt'] as String? ?? '',
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

  /// Bildirim kutusu (duyurular dahil), yeniden eskiye.
  Future<
    List<
      ({
        String id,
        String category,
        String severity,
        String title,
        String body,
        bool read,
        DateTime? createdAt,
        String? announcementId,
        bool needsAck,
      })
    >
  >
  fetchNotifications() async {
    final res = await _get('/courier-notifications');
    final items = (res.data?['data'] as Map?)?['items'] as List? ?? const [];
    return [
      for (final row in items)
        if (row is Map)
          (
            id: row['id'] as String? ?? '',
            category: row['category'] as String? ?? '',
            severity: row['severity'] as String? ?? 'INFO',
            title: row['title'] as String? ?? '',
            body: row['body'] as String? ?? '',
            read: row['read'] == true,
            createdAt: DateTime.tryParse(row['createdAt'] as String? ?? ''),
            announcementId: (row['announcement'] as Map?)?['id'] as String?,
            needsAck:
                (row['announcement'] as Map?)?['requiresAck'] == true &&
                (row['announcement'] as Map?)?['acknowledgedAt'] == null,
          ),
    ];
  }

  Future<void> markNotificationRead(String id) async {
    await _post(
      '/courier-notifications/$id/read',
      const {},
      idempotencyKey: Vault.newUuid(),
    );
  }

  Future<void> markAllNotificationsRead() async {
    await _post(
      '/courier-notifications/read-all',
      const {},
      idempotencyKey: Vault.newUuid(),
    );
  }

  /// Cihaz kaydı: push token ve bekleyen işlem sayısı (merkezin senkron
  /// izlemesi için). İdempotent; girişte ve token yenilenince çağrılır.
  Future<void> registerDevice({
    required String deviceId,
    required String platform,
    required String appVersion,
    String? pushToken,
    int pendingOperationCount = 0,
  }) async {
    try {
      await dio.put<Map<String, dynamic>>(
        '/courier-devices',
        data: {
          'deviceId': deviceId,
          'platform': platform,
          'appVersion': appVersion,
          if (pushToken != null && pushToken.isNotEmpty) ...{
            'pushProvider': 'FCM',
            'pushToken': pushToken,
          },
          'pendingOperationCount': pendingOperationCount,
        },
      );
    } on DioException catch (e) {
      throw _panelException(e);
    }
  }

  /// `GET courier-dashboard` sayaçları: awaitingDelivery, appointment,
  /// outForDelivery, overdue, deliveredToday, failedToday, toReturnToBranch,
  /// pendingCustody.
  Future<Map<String, int>> fetchDashboardCounts() async {
    final res = await _get('/courier-dashboard');
    final counts = (res.data?['data'] as Map?)?['counts'] as Map? ?? const {};
    return {
      for (final e in counts.entries)
        if (e.value is num) '${e.key}': (e.value as num).toInt(),
    };
  }

  /// Açık vardiya var mı ve bekleyen zorunlu eğitim sayısı.
  Future<({bool open, int pendingMandatoryTrainings})>
  fetchCurrentShift() async {
    final res = await _get('/courier-shifts/current');
    final data = res.data?['data'] as Map? ?? const {};
    return (
      open: data['shift'] is Map,
      pendingMandatoryTrainings:
          (data['pendingMandatoryTrainings'] as num?)?.toInt() ?? 0,
    );
  }

  /// Konum zorunlu. [idempotencyKey] yeniden denemede aynı kalmalı.
  Future<void> startShift({
    required double latitude,
    required double longitude,
    required String idempotencyKey,
    DateTime? occurredAt,
  }) => _shift('start', latitude, longitude, idempotencyKey, occurredAt);

  Future<void> endShift({
    required double latitude,
    required double longitude,
    required String idempotencyKey,
    DateTime? occurredAt,
  }) => _shift('end', latitude, longitude, idempotencyKey, occurredAt);

  Future<void> _shift(
    String action,
    double latitude,
    double longitude,
    String idempotencyKey,
    DateTime? occurredAt,
  ) async {
    await _post('/courier-shifts/$action', {
      'latitude': latitude,
      'longitude': longitude,
      if (occurredAt != null)
        'occurredAt': occurredAt.toUtc().toIso8601String(),
    }, idempotencyKey: idempotencyKey);
  }

  /// Mola başlat / bitir. Açık vardiya gerekir; aynı anda tek mola.
  Future<void> setBreak({
    required bool start,
    required String idempotencyKey,
  }) async {
    await _post(
      '/courier-shifts/breaks/${start ? 'start' : 'end'}',
      const {},
      idempotencyKey: idempotencyKey,
    );
  }

  /// `GET courier-trainings` — zorunlular en üstte gelir.
  Future<List<TrainingModuleDto>> fetchTrainings() async {
    final res = await _get('/courier-trainings');
    final items = (res.data?['data'] as Map?)?['items'] as List? ?? const [];
    var order = 0;
    return [
      for (final row in items)
        if (row is Map)
          TrainingModuleDto(
            id: row['id'] as String? ?? '',
            title: row['title'] as String? ?? '',
            summary: row['summary'] as String? ?? row['description'] as String?,
            body: row['contentBody'] as String? ?? '',
            sortOrder: order++,
            completed: row['status'] == 'COMPLETED',
            completedAt: (row['progress'] as Map?)?['completedAt'] as String?,
            mandatory: row['isMandatory'] == true,
            overdue: row['overdue'] == true,
          ),
    ];
  }

  /// Eğitim metni yalnız detayda gelir.
  Future<String> fetchTrainingBody(String trainingId) async {
    final res = await _get('/courier-trainings/$trainingId');
    final data = res.data?['data'] as Map? ?? const {};
    return data['contentBody'] as String? ?? '';
  }

  /// "Okudum/izledim ve anladım" onayıyla tamamlar.
  Future<void> completeTraining(String trainingId) async {
    await _post('/courier-trainings/$trainingId/complete', {
      'acknowledged': true,
      'occurredAt': DateTime.now().toUtc().toIso8601String(),
    }, idempotencyKey: Vault.newUuid());
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
      throw _panelException(e);
    }
  }

  PanelApiException _panelException(DioException e) {
    final body = e.response?.data;
    final error = body is Map && body['error'] is Map
        ? body['error'] as Map
        : const {};
    final locked = error['lockedUntil'];
    return PanelApiException(
      error['code'] as String? ?? 'PANEL_REQUEST_FAILED',
      statusCode: e.response?.statusCode,
      message: e.message,
      serverMessage: error['message'] as String?,
      remainingAttempts: (error['remainingAttempts'] as num?)?.toInt(),
      lockedUntil: locked is String ? DateTime.tryParse(locked) : null,
      missing: [
        for (final row in error['missing'] as List? ?? const [])
          if (row is Map && row['type'] is String) row['type'] as String,
      ],
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
    return {
      for (final line in raw.split('\n'))
        if (line.isNotEmpty) line,
    };
  }
}
