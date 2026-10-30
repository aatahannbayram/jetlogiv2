import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';

import '../data/vault.dart';
import '../secure.dart';
import '../tls_pinning.dart';
import 'models.dart';
import 'panel_models.dart';
import 'branch_models.dart'
    show CustodyDispute, LearnerTraining, QuizResult, TrainingFaq;
import 'token_refresh.dart';

/// JetDiji kurye mobil API (preprod). Canlı host `api-mobile.jetdiji.com`.
/// Override: `--dart-define=PANEL_API_BASE=...`
const kPanelApiBase = String.fromEnvironment(
  'PANEL_API_BASE',
  defaultValue: 'https://api-mobile.preprod.jetdiji.com/api/public/v1',
);

const kPanelBearerKey = 'dg.jetdiji.courier.token';

/// Tek kullanımlık refresh tokenı (30 güne kadar); her yenilemede değişir.
const kPanelRefreshKey = 'dg.jetdiji.courier.refresh';

/// Web: tarayıcıda açık kurye oturumu olduğunu hatırlatan işaret (sır değil).
const kPanelWebSessionKey = 'dg.jetdiji.courier.web';

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
          if (options.extra[kNoAuthExtra] == true) {
            options.headers.remove('Authorization');
          } else if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
    dio.interceptors.add(
      TokenRefresher(
        dio: dio,
        refreshPath: '/courier-auth/refresh',
        authPaths: const [
          '/courier-auth/login',
          '/courier-auth/sms/request',
          '/courier-auth/sms/verify',
          '/courier-auth/logout',
        ],
        readRefreshToken: () async => _vault?.readSecret(kPanelRefreshKey),
        onRefreshed: (access, refresh) async {
          _accessToken = access;
          await _vault?.writeSecret(kPanelBearerKey, access);
          if (refresh != null && refresh.isNotEmpty) {
            await _vault?.writeSecret(kPanelRefreshKey, refresh);
          }
        },
        onRejected: () async {
          _accessToken = null;
          await _vault?.deleteSecret(kPanelBearerKey);
          await _vault?.deleteSecret(kPanelRefreshKey);
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
    final base = resolveApiBase(kPanelApiBase);
    assertHttpsInRelease(base, 'PANEL_API_BASE');
    final dio = Dio(
      BaseOptions(
        baseUrl: base,
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 8),
        headers: const {'accept': 'application/json'},
      ),
    );
    final cookieJar = PersistCookieJar(storage: VaultCookieStorage(vault));
    // Tarayıcı çerezi kendisi yönetir; Cookie başlığını elle yazmaya izin vermez.
    if (!kIsWeb) dio.interceptors.add(CookieManager(cookieJar));
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
    // Web'de oturum çerezi HttpOnly: uygulama göremez, tarayıcı taşır.
    // Girişte bırakılan işarete bakılır; geçerliliği [fetchSession] söyler.
    if (kIsWeb) return await _vault?.readSecret(kPanelWebSessionKey) == '1';
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
    if (kIsWeb) await _vault?.writeSecret(kPanelWebSessionKey, '1');
    final token = data?['accessToken'] as String?;
    if (token != null && token.isNotEmpty) {
      _accessToken = token;
      await _vault?.writeSecret(kPanelBearerKey, token);
    }
    await _keepRefresh(data);
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
    final data = res.data?['data'] as Map?;
    final token = data?['accessToken'] as String?;
    if (token != null && token.isNotEmpty) {
      _accessToken = token;
      await _vault?.writeSecret(kPanelBearerKey, token);
    }
    await _keepRefresh(data);
  }

  /// Girişte / şifre değişiminde dönen refresh tokenı saklanır (eskisi
  /// geçersiz olur).
  Future<void> _keepRefresh(Map? data) async {
    final refresh = data?['refreshToken'] as String?;
    if (refresh != null && refresh.isNotEmpty) {
      await _vault?.writeSecret(kPanelRefreshKey, refresh);
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
      _uploadedEvidence[shipmentId]?.remove(evidenceId);
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
  Future<({String? challengeId, int resendAfterSeconds, String? maskedPhone})>
  requestSmsLogin(String identifier) async {
    final res = await _post('/courier-auth/sms/request', {
      'identifier': identifier,
    });
    final data = res.data?['data'] as Map? ?? const {};
    return (
      challengeId: data['challengeId'] as String?,
      resendAfterSeconds: (data['resendAfterSeconds'] as num?)?.toInt() ?? 60,
      // Hesap yoksa JetDiji yine 200 döner ama SMS göndermez; tek ipucu bu alanın boş olması.
      maskedPhone: data['maskedPhone'] as String?,
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
      // Erişim tokenı bitmiş olsa da oturum refresh tokenıyla kapanır.
      final refresh = await _vault?.readSecret(kPanelRefreshKey);
      await _post('/courier-auth/logout', {
        if (refresh != null && refresh.isNotEmpty) 'refreshToken': refresh,
      });
    } finally {
      _accessToken = null;
      await _vault?.deleteSecret(kPanelBearerKey);
      await _vault?.deleteSecret(kPanelRefreshKey);
      await _vault?.deleteSecret(kPanelWebSessionKey);
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
      if (e.response?.statusCode == 401) {
        await _vault?.deleteSecret(kPanelWebSessionKey);
        return null;
      }
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
    double? accuracy,
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
        'accuracy': ?accuracy,
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
    final id =
        (evidence is Map ? evidence['id'] as String? : null) ??
        data['evidenceId'] as String? ??
        data['id'] as String?;
    if (id != null) (_uploadedEvidence[shipmentId] ??= {}).add(id);
    return id;
  }

  /// Bu ziyarette yüklenen kanıtlar, gönderi bazında. `finalize` bunları
  /// `evidenceIds` olarak gönderir; gönderilmezse kayıt kontrol ekranına
  /// düşmez (JetDiji entegrasyon notu, madde 4).
  final _uploadedEvidence = <String, Set<String>>{};

  /// Bellekte bilinen kanıt id'leri (çevrimdışı kuyruğa yazmak için).
  List<String> knownEvidenceIds(String shipmentId) => [
    ...?_uploadedEvidence[shipmentId],
  ];

  /// Finalize için kanıt id'leri: önce bu oturumda yüklenenler; uygulama
  /// yeniden açıldıysa sunucudaki geçerli kanıt listesi.
  Future<List<String>> evidenceIdsForFinalize(String shipmentId) async {
    final known = knownEvidenceIds(shipmentId);
    if (known.isNotEmpty) return known;
    try {
      return [
        for (final e in await fetchTaskEvidence(shipmentId))
          if (e['id'] is String) e['id'] as String,
      ];
    } catch (_) {
      return const [];
    }
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

  Future<
    ({
      String? fullName,
      String? code,
      String? phone,
      String? city,
      String? district,
      String? vehicle,
      String? workModel,
      String? status,
    })
  >
  fetchCourierProfile() async {
    final res = await _get('/courier-profile');
    final courier = (res.data?['data'] as Map?)?['courier'] as Map? ?? const {};
    final city = courier['city'];
    final district = courier['district'];
    String? text(String key) {
      final v = courier[key];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    return (
      fullName: text('fullName'),
      code: text('courierCode'),
      phone: text('phone'),
      city: city is Map ? city['name'] as String? : null,
      district: district is Map ? district['name'] as String? : null,
      vehicle: text('vehicleType'),
      workModel: text('workModel'),
      status: text('status'),
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
    List<String>? evidenceIds,
  }) async {
    final ids = evidenceIds ?? await evidenceIdsForFinalize(shipmentId);
    final res = await _post(
      '/courier-tasks/$shipmentId/finalize',
      finalizeBody(
        outcome: outcome,
        reasonCode: reasonCode,
        receivedBy: receivedBy,
        otpEvidenceId: otpEvidenceId,
        note: note,
        latitude: latitude,
        longitude: longitude,
        capturedAt: capturedAt,
        evidenceIds: ids,
      ),
      idempotencyKey: idempotencyKey,
    );
    _uploadedEvidence.remove(shipmentId);
    return PanelFinalizeResultDto.fromJson(
      Map<String, dynamic>.from(res.data?['data'] as Map? ?? const {}),
    );
  }

  /// `finalize` gövdesi; tekil istek ve toplu gönderim aynısını kullanır.
  static Map<String, Object?> finalizeBody({
    required String outcome,
    String? reasonCode,
    String? receivedBy,
    String? otpEvidenceId,
    String? note,
    double? latitude,
    double? longitude,
    DateTime? capturedAt,
    List<String>? evidenceIds,
  }) {
    final delivered = outcome != 'FAILED' && outcome != 'DELIVERY_FAILED';
    return {
      'resultCode': delivered ? 'DELIVERED' : 'DELIVERY_FAILED',
      if (!delivered && reasonCode != null) 'reasonCode': reasonCode,
      if (delivered && receivedBy != null) 'receivedByName': receivedBy,
      if (delivered && otpEvidenceId != null) 'otpEvidenceId': otpEvidenceId,
      if (note != null && note.isNotEmpty) 'note': note,
      if (evidenceIds != null && evidenceIds.isNotEmpty)
        'evidenceIds': evidenceIds,
      if (latitude != null && longitude != null) ...{
        'latitude': latitude,
        'longitude': longitude,
        if (capturedAt != null)
          'capturedAt': capturedAt.toUtc().toIso8601String(),
      },
    };
  }

  /// Bekleyen kayıtları tek istekte gönderir (en fazla 50). Dış yanıt hep
  /// 200'dür; her kaydın sonucu [SyncBatchResultDto] olarak döner. Sonucu
  /// dönmeyen kayıt gönderilmemiş sayılır.
  Future<List<SyncBatchResultDto>> syncBatch(
    List<Map<String, Object?>> operations, {
    int pendingAfter = 0,
  }) async {
    final res = await _post('/courier-sync/batch', {
      'batchId': Vault.newUuid(),
      'pendingOperationCount': pendingAfter,
      'operations': operations,
    });
    final data = res.data?['data'];
    return [
      for (final row
          in data is Map ? data['results'] as List? ?? const [] : const [])
        if (row is Map)
          SyncBatchResultDto.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<List<CustodyItemDto>> fetchCustody() async =>
      custodyFrom(_map((await _get('/courier-custody/pending')).data?['data']));

  /// `courier-custody/pending` `data` alanı (değişiklik paketindeki
  /// `custody` de aynı yapıda): kabul bekleyen kalemler ve eldekiler.
  List<CustodyItemDto> custodyFrom(Map<String, dynamic> data) {
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

  /// Tek dokunuşla destek isteği: `CALL_REQUEST` (beni arayın), `LIVE_CHAT`
  /// (canlı destek) ya da `SOS` (acil). Konum verilirse talebe eklenir.
  Future<void> requestSupport({
    required String category,
    String? shipmentId,
    double? latitude,
    double? longitude,
  }) async {
    await _post('/courier-support/cases', {
      'category': category,
      'idempotencyKey': Vault.newUuid(),
      'shipmentId': ?shipmentId,
      if (latitude != null && longitude != null) ...{
        'latitude': latitude,
        'longitude': longitude,
      },
    });
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
      transferItemId: json['itemId'] as String?,
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

  /// Görev dışı konum: açık vardiyada, görev başlamamışken 2–5 dk'da bir
  /// (şube haritası bunu kullanır). Kuyruğa alınmaz; sunucu 5 dk'dan eski
  /// konumu `422 LOCATION_TOO_OLD` ile, kapalı vardiyayı `409 NO_OPEN_SHIFT`
  /// ile reddeder. Sırası karışan istekte daha yeni konum ezilmez.
  Future<void> sendShiftLocation({
    required double latitude,
    required double longitude,
    double? accuracy,
    DateTime? capturedAt,
  }) async {
    await _post('/courier-shifts/location', {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': ?accuracy,
      if (capturedAt != null)
        'capturedAt': capturedAt.toUtc().toIso8601String(),
    });
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

  /// "Okudum/izledim ve anladım" onayıyla tamamlar. En kısa izleme süresi
  /// dolmadıysa sunucu `409 TRAINING_MIN_VIEW_NOT_REACHED` döner; son
  /// [viewedSeconds] (kümülatif) bu istekte de gönderilebilir.
  Future<void> completeTraining(String trainingId, {int? viewedSeconds}) async {
    await _post('/courier-trainings/$trainingId/complete', {
      'acknowledged': true,
      'viewedSeconds': ?viewedSeconds,
      'occurredAt': DateTime.now().toUtc().toIso8601String(),
    }, idempotencyKey: Vault.newUuid());
  }

  /// Eğitim detayı: içerik bağlantısı / metni, dersler, sınav, ilerleme.
  Future<LearnerTraining> fetchTrainingDetail(String trainingId) async {
    final res = await _get('/courier-trainings/$trainingId');
    return LearnerTraining.fromJson(
      Map<String, dynamic>.from(res.data?['data'] as Map? ?? const {}),
    );
  }

  /// İzleme ilerlemesi: [viewedSeconds] kümülatif (geri gitmez). 15–30 sn'de
  /// bir ya da ekrandan çıkarken.
  Future<void> recordTrainingProgress(
    String trainingId, {
    required int viewedSeconds,
    int? percent,
  }) async {
    await _post('/courier-trainings/$trainingId/progress', {
      'viewedSeconds': viewedSeconds,
      'progressPercent': ?percent,
      'occurredAt': DateTime.now().toUtc().toIso8601String(),
    }, idempotencyKey: Vault.newUuid());
  }

  /// Dersli eğitimde ders ilerlemesi; [completed] ve en kısa süre dolmuşsa
  /// ders tamamlanır. Canlı derste katılım = tamamlama.
  Future<void> recordLessonProgress(
    String trainingId,
    String lessonId, {
    required int viewedSeconds,
    int? positionSeconds,
    bool completed = false,
  }) async {
    await _post('/courier-trainings/$trainingId/lessons/$lessonId/progress', {
      'viewedSeconds': viewedSeconds,
      'positionSeconds': ?positionSeconds,
      if (completed) 'completed': true,
      'occurredAt': DateTime.now().toUtc().toIso8601String(),
    }, idempotencyKey: Vault.newUuid());
  }

  /// Sınav: soru kimliği → seçilen seçenek kimlikleri. Puan sunucuda.
  Future<QuizResult> submitLessonQuiz(
    String trainingId,
    String lessonId,
    Map<String, List<String>> answers,
  ) async {
    final res = await _post(
      '/courier-trainings/$trainingId/lessons/$lessonId/quiz',
      {
        'answers': answers,
        'occurredAt': DateTime.now().toUtc().toIso8601String(),
      },
      idempotencyKey: Vault.newUuid(),
    );
    return QuizResult.fromJson(
      Map<String, dynamic>.from(res.data?['data'] as Map? ?? const {}),
    );
  }

  /// Eğitim Merkezi SSS (kurye kitlesi, yayındakiler, sırasıyla).
  Future<List<TrainingFaq>> fetchTrainingFaq() async {
    final res = await _get('/courier-trainings/faq');
    final rows = res.data?['data'];
    return [
      for (final r in rows is List ? rows : const [])
        if (r is Map)
          (question: '${r['question'] ?? ''}', answer: '${r['answer'] ?? ''}'),
    ];
  }

  /// Zimmet uyuşmazlığı bildirimlerim (yeniden eskiye, en fazla 50).
  Future<List<CustodyDispute>> fetchCustodyDisputes() async =>
      CustodyDispute.listFrom(
        (await _get('/courier-custody/disputes')).data?['data'],
      );

  /// Zimmet uyuşmazlığı bildirir; operasyona yüksek öncelikli talep açılır,
  /// zimmeti veren şube kendi listesinde görür. Kurallar: MISSING / DAMAGED
  /// → [transferItemId]; EXCESS → [scanCode]; WRONG_ITEM → ikisi; OTHER →
  /// [note]. Aynı [idempotencyKey] ile tekrar aynı kaydı döner.
  Future<CustodyDispute> createCustodyDispute({
    required String typeCode,
    required String idempotencyKey,
    String? transferItemId,
    String? scanCode,
    String? note,
    double? latitude,
    double? longitude,
    double? accuracy,
  }) async {
    final res = await _post('/courier-custody/disputes', {
      'typeCode': typeCode,
      'transferItemId': ?transferItemId,
      'scanCode': ?scanCode,
      'note': ?note,
      'latitude': ?latitude,
      'longitude': ?longitude,
      'accuracy': ?accuracy,
    }, idempotencyKey: idempotencyKey);
    final data = res.data?['data'];
    final dispute = data is Map ? data['dispute'] : null;
    return CustodyDispute.fromJson(
      Map<String, dynamic>.from(dispute is Map ? dispute : const {}),
    );
  }

  /// Ödeme bilgisi (`GET courier-profile` → `bankAccount`): bekleyen ya da
  /// reddedilen kayıt varsa o, yoksa doğrulanmış hesap. IBAN maskelidir.
  Future<CourierBankAccount?> fetchBankAccount() async =>
      CourierBankAccount.from(
        _map((await _get('/courier-profile')).data?['data']),
      );

  /// Yeni IBAN'ı doğrulamaya gönderir (`PENDING_VERIFICATION`). Alan
  /// hataları `VALIDATION_ERROR` + [PanelApiException.fieldErrors].
  Future<CourierBankAccount?> saveBankAccount({
    required String accountHolderName,
    required String iban,
  }) async {
    try {
      final res = await dio.put<Map<String, dynamic>>(
        '/courier-profile',
        data: {
          'accountHolderName': accountHolderName.trim(),
          'iban': iban.replaceAll(RegExp(r'\s'), '').toUpperCase(),
        },
      );
      return CourierBankAccount.from(_map(res.data?['data']));
    } on DioException catch (e) {
      throw _panelException(e);
    }
  }

  /// Çıkışta cihaz kaydını kapatır: push token silinir, merkez cihazı
  /// pasif görür. Oturum kapanmadan önce çağrılır (Bearer gerekir).
  Future<void> unregisterDevice(String deviceId) async {
    try {
      await dio.delete<Map<String, dynamic>>(
        '/courier-devices',
        queryParameters: {'deviceId': deviceId},
      );
    } on DioException catch (e) {
      throw _panelException(e);
    }
  }

  /// Açılış / ön plana gelme senkronu: görevler, zimmet, vardiya, eğitim ve
  /// yeni bildirimler tek pakette. İlk çağrıda [since] yok (tam paket);
  /// sonra önceki yanıttaki `serverTime`.
  Future<SyncChangesDto> fetchSyncChanges({
    String? since,
    String? deviceId,
  }) async {
    try {
      final res = await dio.get<Map<String, dynamic>>(
        '/courier-sync/changes',
        queryParameters: {'since': ?since},
        options: deviceId == null
            ? null
            : Options(headers: {'X-Device-Id': deviceId}),
      );
      return SyncChangesDto.fromJson(_map(res.data?['data']));
    } on DioException catch (e) {
      throw _panelException(e);
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
      retryAfterSeconds:
          (error['retryAfterSeconds'] as num?)?.toInt() ??
          int.tryParse(e.response?.headers.value('retry-after') ?? ''),
      fieldErrors: {
        if (error['fieldErrors'] case final Map fields)
          for (final e in fields.entries)
            if (e.value != null)
              '${e.key}': e.value is List
                  ? (e.value as List).join(' ')
                  : '${e.value}',
      },
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
