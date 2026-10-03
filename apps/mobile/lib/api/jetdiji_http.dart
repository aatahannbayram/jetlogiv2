import 'package:dio/dio.dart';

import '../data/vault.dart';

/// Preprod taban. Canlı için `--dart-define=JETDIJI_API_BASE=https://api-mobile.jetdiji.com`.
const kJetdijiApiBase = String.fromEnvironment(
  'JETDIJI_API_BASE',
  defaultValue: 'https://api-mobile.preprod.jetdiji.com',
);

class JetDijiAgencyOption {
  const JetDijiAgencyOption({
    required this.id,
    required this.name,
    this.code,
    this.tenantId,
  });

  final String id;
  final String name;
  final String? code;
  final String? tenantId;

  factory JetDijiAgencyOption.fromJson(Map<String, dynamic> json) {
    return JetDijiAgencyOption(
      id: '${json['id'] ?? ''}',
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      tenantId: json['tenantId'] as String?,
    );
  }
}

class JetDijiMissingRequirement {
  const JetDijiMissingRequirement({
    required this.type,
    this.code,
    this.requiredCount,
    this.actual,
  });

  final String type;
  final String? code;
  final int? requiredCount;
  final int? actual;

  factory JetDijiMissingRequirement.fromJson(Map<String, dynamic> json) {
    return JetDijiMissingRequirement(
      type: json['type'] as String? ?? '',
      code: json['code'] as String?,
      requiredCount: (json['required'] as num?)?.toInt(),
      actual: (json['actual'] as num?)?.toInt(),
    );
  }
}

/// Hata kodu yalnız `error.code`. Üst seviye `code` okunmaz.
class JetDijiException implements Exception {
  JetDijiException(
    this.code, {
    this.statusCode,
    this.message,
    this.field,
    this.missing = const [],
    this.agencies = const [],
    this.remainingAttempts,
    this.lockedUntil,
  });

  final String code;
  final int? statusCode;
  final String? message;
  final String? field;
  final List<JetDijiMissingRequirement> missing;
  final List<JetDijiAgencyOption> agencies;
  final int? remainingAttempts;
  final String? lockedUntil;

  @override
  String toString() => 'JetDijiException($code, status: $statusCode)';
}

class JetDijiTokenStore {
  JetDijiTokenStore({this.vault, required this.role});

  final Vault? vault;
  final String role;
  String? memory;

  Future<String?> read() async {
    if (memory != null && memory!.isNotEmpty) return memory;
    return vault?.readJetdijiToken(role);
  }

  Future<void> save(String token, String? expiresAt) async {
    memory = token;
    await vault?.saveJetdijiToken(role, token, expiresAt);
  }

  Future<void> clear() async {
    memory = null;
    await vault?.clearJetdijiToken(role);
  }
}

Map<String, dynamic> jetdijiMap(dynamic data) {
  if (data is Map) return Map<String, dynamic>.from(data);
  return const {};
}

List<dynamic> jetdijiList(dynamic data) {
  if (data is List) return data;
  return const [];
}

/// `success` + `data` zarfını açar. Başarısız yanıtta [JetDijiException].
dynamic unwrapJetdijiBody(dynamic body, int? status) {
  if (body is! Map) {
    if (status != null && status >= 400) {
      throw JetDijiException('HTTP_$status', statusCode: status);
    }
    return body;
  }
  final map = Map<String, dynamic>.from(body);
  final failed = map['success'] == false || (status != null && status >= 400);
  if (!failed) {
    if (map.containsKey('data')) return map['data'];
    return map;
  }
  final err = map['error'];
  final errMap = err is Map
      ? Map<String, dynamic>.from(err)
      : const <String, dynamic>{};
  final code = errMap['code'] as String? ?? 'HTTP_${status ?? 0}';
  final missingRaw = errMap['missing'];
  final agenciesRaw = errMap['agencies'];
  throw JetDijiException(
    code,
    statusCode: status,
    message: errMap['message'] as String?,
    field: errMap['field'] as String?,
    remainingAttempts: (errMap['remainingAttempts'] as num?)?.toInt(),
    lockedUntil: errMap['lockedUntil'] as String?,
    missing: [
      for (final row in missingRaw is List ? missingRaw : const [])
        if (row is Map)
          JetDijiMissingRequirement.fromJson(Map<String, dynamic>.from(row)),
    ],
    agencies: [
      for (final row in agenciesRaw is List ? agenciesRaw : const [])
        if (row is Map)
          JetDijiAgencyOption.fromJson(Map<String, dynamic>.from(row)),
    ],
  );
}

class JetDijiHttp {
  JetDijiHttp({required this.dio, required this.tokens});

  final Dio dio;
  final JetDijiTokenStore tokens;

  static Dio buildDio() {
    return Dio(
      BaseOptions(
        baseUrl: kJetdijiApiBase,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 20),
        headers: const {'accept': 'application/json'},
      ),
    );
  }

  Future<dynamic> request(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool auth = true,
    bool write = false,
    String? idempotencyKey,
    bool bytes = false,
  }) async {
    final headers = <String, dynamic>{'X-Client-Type': 'mobile'};
    if (auth) {
      final token = await tokens.read();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    if (write) {
      headers['Idempotency-Key'] = idempotencyKey ?? Vault.newUuid();
    }
    try {
      final res = await dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(
          method: method,
          headers: headers,
          responseType: bytes ? ResponseType.bytes : ResponseType.json,
          validateStatus: (code) => code != null && code < 600,
        ),
      );
      if (bytes && res.data is List<int>) {
        if ((res.statusCode ?? 0) >= 400) {
          throw JetDijiException(
            'HTTP_${res.statusCode}',
            statusCode: res.statusCode,
          );
        }
        return res.data;
      }
      return unwrapJetdijiBody(res.data, res.statusCode);
    } on JetDijiException {
      rethrow;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data != null) {
        return unwrapJetdijiBody(data, e.response?.statusCode);
      }
      throw JetDijiException('NETWORK', message: e.message);
    }
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) {
    return request('GET', path, query: query, auth: auth);
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool auth = true,
    bool write = true,
    String? idempotencyKey,
  }) {
    return request(
      'POST',
      path,
      body: body,
      query: query,
      auth: auth,
      write: write,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<dynamic> put(
    String path, {
    Object? body,
    bool auth = true,
    String? idempotencyKey,
  }) {
    return request(
      'PUT',
      path,
      body: body,
      auth: auth,
      write: true,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<dynamic> delete(
    String path, {
    bool auth = true,
    String? idempotencyKey,
  }) {
    return request(
      'DELETE',
      path,
      auth: auth,
      write: true,
      idempotencyKey: idempotencyKey,
    );
  }
}
