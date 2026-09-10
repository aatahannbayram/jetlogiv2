import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../data/vault.dart';
import '../secure.dart';
import '../tls_pinning.dart';
import 'agency_models.dart';
import 'panel_client.dart' show VaultCookieStorage;

/// dijigoo-ops default local dev address — same base host as [kPanelApiBase]
/// but the `portal/v1` surface rather than `public/v1` (see
/// docs/08-sube-acente-entegrasyonu.md). Override with
/// `--dart-define=AGENCY_API_BASE=...` once a staging/production domain
/// exists.
const kAgencyApiBase = String.fromEnvironment(
  'AGENCY_API_BASE',
  defaultValue: 'http://localhost:3000/api/portal/v1',
);

/// Client for dijigoo-ops's "Acente Portalı" (agency portal) — the backend
/// for the Şube/Acente app role. Same shape as [PanelApi] on purpose (dio +
/// persisted cookie jar, no bearer token): `agency-portal-auth.ts` uses an
/// httpOnly cookie session (`jetdiji_agency_session`) exactly like
/// `courier-auth.ts` does for the courier side, so the same integration
/// pattern applies unchanged. Kept as a separate client/cookie-jar from
/// [PanelApi] because a device could plausibly run both roles' sessions
/// side by side, and the two portals' sessions must not be mixed.
class AgencyPortalApi {
  AgencyPortalApi(this.dio, [this._cookieJar]);

  final Dio dio;
  final CookieJar? _cookieJar;

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
    return AgencyPortalApi(dio, cookieJar);
  }

  /// Cheap, local-only check — mirrors [PanelApi.hasStoredSession]. Does not
  /// confirm the session is still valid server-side; call [fetchSession] for
  /// that.
  Future<bool> get hasStoredSession async {
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
    final data = Map<String, dynamic>.from(res.data?['data'] as Map? ?? const {});
    final agency = AgencyDto.fromJson(
      Map<String, dynamic>.from(data['agency'] as Map? ?? const {}),
    );
    return AgencyPortalUserDto.fromJson(
      Map<String, dynamic>.from(data['user'] as Map? ?? const {}),
      agency,
    );
  }

  Future<void> logout() async {
    await _post('/agency-auth/logout', const {});
    await _cookieJar?.deleteAll();
  }

  /// `GET agency-auth/session` — confirms the stored cookie is still
  /// accepted server-side. Returns null on 401 rather than throwing.
  Future<AgencyPortalUserDto?> fetchSession() async {
    try {
      final res = await dio.get<Map<String, dynamic>>('/agency-auth/session');
      final data = Map<String, dynamic>.from(res.data?['data'] as Map? ?? const {});
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
    Map<String, Object?> data,
  ) async {
    try {
      return await dio.post<Map<String, dynamic>>(path, data: data);
    } on DioException catch (e) {
      throw _agencyException(e);
    }
  }

  AgencyApiException _agencyException(DioException e) {
    final body = e.response?.data;
    final code = body is Map ? body['code'] as String? : null;
    final nested = body is Map ? body['data'] as Map? : null;
    final agenciesRaw = nested?['agencies'] as List?;
    return AgencyApiException(
      code ?? 'AGENCY_REQUEST_FAILED',
      statusCode: e.response?.statusCode,
      message: e.message,
      agencies: [
        for (final row in agenciesRaw ?? const [])
          if (row is Map) AgencyDto.fromJson(Map<String, dynamic>.from(row)),
      ],
    );
  }
}
