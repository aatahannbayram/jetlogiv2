import 'package:dio/dio.dart';

import '../data/vault.dart';
import 'jetdiji_courier_models.dart';
import 'jetdiji_http.dart';

/// JetDiji kurye mobil API. courier.yaml'daki 51 uç, bir metot bir yol.
class JetDijiCourierApi {
  JetDijiCourierApi(this.http);

  final JetDijiHttp http;

  static JetDijiCourierApi create({Vault? vault}) {
    return JetDijiCourierApi(
      JetDijiHttp(
        dio: JetDijiHttp.buildDio(),
        tokens: JetDijiTokenStore(vault: vault, role: 'courier'),
      ),
    );
  }

  static JetDijiCourierApi forTest(Dio dio) {
    return JetDijiCourierApi(
      JetDijiHttp(dio: dio, tokens: JetDijiTokenStore(role: 'courier')),
    );
  }

  Future<bool> get hasToken async {
    final token = await http.tokens.read();
    return token != null && token.isNotEmpty;
  }

  Future<JetDijiCourierLogin> login({
    required String identifier,
    required String password,
  }) async {
    final data = jetdijiMap(
      await http.post(
        '/api/public/v1/courier-auth/login',
        auth: false,
        body: {'identifier': identifier, 'password': password},
      ),
    );
    final login = JetDijiCourierLogin.fromJson(data);
    if (login.accessToken.isNotEmpty) {
      await http.tokens.save(login.accessToken, login.expiresAt);
    }
    return login;
  }

  Future<void> logout() async {
    await http.post('/api/public/v1/courier-auth/logout', body: const {});
    await http.tokens.clear();
  }

  Future<Map<String, dynamic>> session() async {
    return jetdijiMap(await http.get('/api/public/v1/courier-auth/session'));
  }

  Future<Map<String, dynamic>> activatePreview(String token) async {
    return jetdijiMap(
      await http.get(
        '/api/public/v1/courier-auth/activate',
        query: {'token': token},
        auth: false,
      ),
    );
  }

  Future<Map<String, dynamic>> activate({
    required String token,
    required String password,
    required String passwordConfirmation,
  }) async {
    return jetdijiMap(
      await http.post(
        '/api/public/v1/courier-auth/activate',
        auth: false,
        body: {
          'token': token,
          'password': password,
          'passwordConfirmation': passwordConfirmation,
        },
      ),
    );
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    return jetdijiMap(
      await http.post(
        '/api/public/v1/courier-auth/change-password',
        body: {
          'currentPassword': currentPassword,
          'password': password,
          'passwordConfirmation': passwordConfirmation,
        },
      ),
    );
  }

  Future<JetDijiDashboard> dashboard() async {
    return JetDijiDashboard.fromJson(
      jetdijiMap(await http.get('/api/public/v1/courier-dashboard')),
    );
  }

  Future<JetDijiTaskList> tasks({
    int page = 1,
    int pageSize = 500,
    String? status,
    String? search,
  }) async {
    return JetDijiTaskList.fromJson(
      jetdijiMap(
        await http.get(
          '/api/public/v1/courier-tasks',
          query: {
            'page': page,
            'pageSize': pageSize,
            if (status != null) 'status': status,
            if (search != null) 'search': search,
          },
        ),
      ),
    );
  }

  Future<JetDijiDeliveryReasons> deliveryReasons({String locale = 'tr'}) async {
    return JetDijiDeliveryReasons.fromJson(
      jetdijiMap(
        await http.get(
          '/api/public/v1/courier-tasks/delivery-reasons',
          query: {'locale': locale},
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> taskDetail(
    String shipmentId, {
    String? locale,
  }) async {
    return jetdijiMap(
      await http.get(
        '/api/public/v1/courier-tasks/$shipmentId',
        query: {if (locale != null) 'locale': locale},
      ),
    );
  }

  Future<Map<String, dynamic>> callRecipient(String shipmentId) async {
    return jetdijiMap(
      await http.post(
        '/api/public/v1/courier-tasks/$shipmentId/call',
        body: const {},
        write: false,
      ),
    );
  }

  Future<Map<String, dynamic>> acceptTask(String shipmentId) async {
    return jetdijiMap(
      await http.post(
        '/api/public/v1/courier-tasks/$shipmentId/accept',
        body: const {},
        write: false,
      ),
    );
  }

  Future<Map<String, dynamic>> startTask(
    String shipmentId, {
    required double latitude,
    required double longitude,
    double? accuracy,
    String? capturedAt,
  }) async {
    return jetdijiMap(
      await http.post(
        '/api/public/v1/courier-tasks/$shipmentId/start',
        body: {
          'latitude': latitude,
          'longitude': longitude,
          if (accuracy != null) 'accuracy': accuracy,
          'capturedAt': capturedAt ?? DateTime.now().toUtc().toIso8601String(),
        },
      ),
    );
  }

  Future<Map<String, dynamic>> sendLocation(
    String shipmentId, {
    required double latitude,
    required double longitude,
    required String purposeCode,
    double? accuracy,
    String? capturedAt,
  }) async {
    final captured = DateTime.tryParse(capturedAt ?? '');
    if (captured != null &&
        DateTime.now().toUtc().difference(captured.toUtc()) >
            const Duration(minutes: 5)) {
      throw JetDijiException('LOCATION_NOT_FRESH');
    }
    return jetdijiMap(
      await http.post(
        '/api/public/v1/courier-tasks/$shipmentId/location',
        body: {
          'latitude': latitude,
          'longitude': longitude,
          'purposeCode': purposeCode,
          if (accuracy != null) 'accuracy': accuracy,
          'capturedAt': capturedAt ?? DateTime.now().toUtc().toIso8601String(),
        },
      ),
    );
  }

  Future<JetDijiRequirements?> requirements(
    String shipmentId, {
    String locale = 'tr',
  }) async {
    final data = await http.get(
      '/api/public/v1/courier-tasks/$shipmentId/requirements',
      query: {'locale': locale},
    );
    if (data == null) return null;
    if (data is! Map) return null;
    return JetDijiRequirements.fromJson(Map<String, dynamic>.from(data));
  }

  Future<JetDijiOtpChallenge> sendOtp(
    String shipmentId, {
    String receiverType = 'SELF',
    String? idempotencyKey,
  }) async {
    return JetDijiOtpChallenge.fromJson(
      jetdijiMap(
        await http.post(
          '/api/public/v1/courier-tasks/$shipmentId/otp',
          idempotencyKey: idempotencyKey,
          body: {'receiverType': receiverType},
        ),
      ),
    );
  }

  Future<JetDijiOtpVerified> verifyOtp(
    String shipmentId, {
    required String challengeId,
    required String code,
  }) async {
    return JetDijiOtpVerified.fromJson(
      jetdijiMap(
        await http.post(
          '/api/public/v1/courier-tasks/$shipmentId/otp/verify',
          write: false,
          body: {'challengeId': challengeId, 'code': code},
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> saveForm(
    String shipmentId, {
    required String formVersionId,
    required String status,
    Map<String, dynamic> values = const {},
    String? idempotencyKey,
  }) async {
    return jetdijiMap(
      await http.put(
        '/api/public/v1/courier-tasks/$shipmentId/form',
        idempotencyKey: idempotencyKey,
        body: {
          'formVersionId': formVersionId,
          'status': status,
          'values': values,
        },
      ),
    );
  }

  Future<JetDijiFinalizeResult> finalize(
    String shipmentId, {
    required String resultCode,
    String? reasonCode,
    String? receiverType,
    String? receivedByName,
    String? receivedRelationCode,
    String? note,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? capturedAt,
    String? otpEvidenceId,
    List<String> evidenceIds = const [],
    String? idempotencyKey,
  }) async {
    return JetDijiFinalizeResult.fromJson(
      jetdijiMap(
        await http.post(
          '/api/public/v1/courier-tasks/$shipmentId/finalize',
          idempotencyKey: idempotencyKey,
          body: {
            'resultCode': resultCode,
            if (reasonCode != null) 'reasonCode': reasonCode,
            if (receiverType != null) 'receiverType': receiverType,
            if (receivedByName != null) 'receivedByName': receivedByName,
            if (receivedRelationCode != null)
              'receivedRelationCode': receivedRelationCode,
            if (note != null) 'note': note,
            if (latitude != null) 'latitude': latitude,
            if (longitude != null) 'longitude': longitude,
            if (accuracy != null) 'accuracy': accuracy,
            if (capturedAt != null) 'capturedAt': capturedAt,
            if (otpEvidenceId != null) 'otpEvidenceId': otpEvidenceId,
            'evidenceIds': evidenceIds,
          },
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> listEvidence(String shipmentId) async {
    return jetdijiMap(
      await http.get('/api/public/v1/courier-tasks/$shipmentId/evidence'),
    );
  }

  Future<Map<String, dynamic>> uploadEvidence(
    String shipmentId, {
    List<int>? fileBytes,
    String? filename,
    String evidenceType = 'PHOTO',
    String? requirementCode,
    String? textValue,
    String? category,
    String? note,
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? Vault.newUuid();
    if (fileBytes != null) {
      final form = FormData.fromMap({
        'evidenceType': evidenceType,
        if (requirementCode != null) 'requirementCode': requirementCode,
        if (category != null) 'category': category,
        if (note != null) 'note': note,
        'file': MultipartFile.fromBytes(
          fileBytes,
          filename: filename ?? 'evidence.jpg',
        ),
      });
      return jetdijiMap(
        await http.post(
          '/api/public/v1/courier-tasks/$shipmentId/evidence',
          body: form,
          idempotencyKey: key,
        ),
      );
    }
    return jetdijiMap(
      await http.post(
        '/api/public/v1/courier-tasks/$shipmentId/evidence',
        idempotencyKey: key,
        body: {
          'evidenceType': evidenceType,
          if (textValue != null) 'textValue': textValue,
          if (category != null) 'category': category,
          if (note != null) 'note': note,
        },
      ),
    );
  }

  Future<Map<String, dynamic>> voidEvidence(
    String shipmentId,
    String evidenceId,
  ) async {
    return jetdijiMap(
      await http.delete(
        '/api/public/v1/courier-tasks/$shipmentId/evidence/$evidenceId',
      ),
    );
  }

  Future<List<int>> downloadEvidenceFile(
    String shipmentId,
    String evidenceId,
  ) async {
    final data = await http.request(
      'GET',
      '/api/public/v1/courier-tasks/$shipmentId/evidence/$evidenceId/file',
      bytes: true,
    );
    if (data is List<int>) return data;
    return const [];
  }

  Future<Map<String, dynamic>> listReports(String shipmentId) async {
    return jetdijiMap(
      await http.get('/api/public/v1/courier-tasks/$shipmentId/reports'),
    );
  }

  Future<Map<String, dynamic>> createReport(
    String shipmentId, {
    Map<String, dynamic> body = const {},
    String? idempotencyKey,
  }) async {
    return jetdijiMap(
      await http.post(
        '/api/public/v1/courier-tasks/$shipmentId/reports',
        body: body,
        idempotencyKey: idempotencyKey,
      ),
    );
  }

  Future<Map<String, dynamic>> custodyPending() async {
    return jetdijiMap(await http.get('/api/public/v1/courier-custody/pending'));
  }

  Future<Map<String, dynamic>> acceptCustody({
    required String scanCode,
    String scanType = 'AUTO',
    String? idempotencyKey,
  }) async {
    return jetdijiMap(
      await http.post(
        '/api/public/v1/courier-custody/accept',
        idempotencyKey: idempotencyKey,
        body: {'scanCode': scanCode, 'scanType': scanType},
      ),
    );
  }

  Future<Map<String, dynamic>> custodyOverview() async {
    return jetdijiMap(
      await http.get('/api/public/v1/courier-custody/overview'),
    );
  }

  Future<Map<String, dynamic>> returnCustody({
    List<String> shipmentIds = const [],
    List<String> scannedValues = const [],
    String? targetUnitId,
    String? idempotencyKey,
  }) async {
    return jetdijiMap(
      await http.post(
        '/api/public/v1/courier-custody/return',
        idempotencyKey: idempotencyKey,
        body: {
          if (shipmentIds.isNotEmpty) 'shipmentIds': shipmentIds,
          if (scannedValues.isNotEmpty) 'scannedValues': scannedValues,
          if (targetUnitId != null) 'targetUnitId': targetUnitId,
        },
      ),
    );
  }

  Future<Map<String, dynamic>> custodyHistory({int limit = 50}) async {
    return jetdijiMap(
      await http.get(
        '/api/public/v1/courier-custody/history',
        query: {'limit': limit},
      ),
    );
  }

  Future<Map<String, dynamic>> profile() async {
    return jetdijiMap(await http.get('/api/public/v1/courier-profile'));
  }

  Future<Map<String, dynamic>> saveIban(String iban) async {
    return jetdijiMap(
      await http.put('/api/public/v1/courier-profile', body: {'iban': iban}),
    );
  }

  Future<Map<String, dynamic>> profileSummary() async {
    return jetdijiMap(
      await http.get('/api/public/v1/courier-profile/summary'),
    );
  }

  Future<Map<String, dynamic>> changeRequests() async {
    return jetdijiMap(
      await http.get('/api/public/v1/courier-profile/change-requests'),
    );
  }

  Future<Map<String, dynamic>> createChangeRequest(
    Map<String, dynamic> body,
  ) async {
    return jetdijiMap(
      await http.post(
        '/api/public/v1/courier-profile/change-requests',
        body: body,
      ),
    );
  }

  Future<Map<String, dynamic>> cancelChangeRequest(String requestId) async {
    return jetdijiMap(
      await http.post(
        '/api/public/v1/courier-profile/change-requests/$requestId/cancel',
        body: const {},
      ),
    );
  }

  Future<Map<String, dynamic>> supportCases() async {
    return jetdijiMap(await http.get('/api/public/v1/courier-support/cases'));
  }

  Future<Map<String, dynamic>> createSupportCase(
    Map<String, dynamic> body,
  ) async {
    return jetdijiMap(
      await http.post('/api/public/v1/courier-support/cases', body: body),
    );
  }

  Future<Map<String, dynamic>> availability() async {
    return jetdijiMap(await http.get('/api/public/v1/courier-availability'));
  }

  Future<Map<String, dynamic>> saveAvailability(Map<String, dynamic> body) async {
    return jetdijiMap(
      await http.put('/api/public/v1/courier-availability', body: body),
    );
  }

  Future<Map<String, dynamic>> contracts() async {
    return jetdijiMap(await http.get('/api/public/v1/courier-my-contracts'));
  }

  Future<Map<String, dynamic>> documents() async {
    return jetdijiMap(await http.get('/api/public/v1/courier-my-documents'));
  }

  Future<Map<String, dynamic>> application() async {
    return jetdijiMap(await http.get('/api/public/v1/courier-application'));
  }

  Future<Map<String, dynamic>> consents() async {
    return jetdijiMap(
      await http.get('/api/public/v1/courier-consents', auth: false),
    );
  }

  Future<Map<String, dynamic>> checkPhone(String phone) async {
    return jetdijiMap(
      await http.get(
        '/api/public/v1/courier-applications/check-phone',
        query: {'phone': phone},
        auth: false,
      ),
    );
  }

  Future<Map<String, dynamic>> submitApplication(Map<String, dynamic> body) async {
    return jetdijiMap(
      await http.post(
        '/api/public/v1/courier-applications',
        auth: false,
        body: body,
      ),
    );
  }

  Future<Map<String, dynamic>> documentPack(String publicId) async {
    return jetdijiMap(
      await http.get(
        '/api/public/v1/courier-documents/$publicId',
        auth: false,
      ),
    );
  }

  Future<Map<String, dynamic>> uploadApplicationDocument({
    required String publicId,
    required String documentRequestId,
    required List<int> bytes,
    String filename = 'belge.jpg',
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    return jetdijiMap(
      await http.post(
        '/api/public/v1/courier-documents/$publicId/requests/$documentRequestId/upload',
        auth: false,
        body: form,
      ),
    );
  }

  Future<Map<String, dynamic>> submitDocuments(String publicId) async {
    return jetdijiMap(
      await http.post(
        '/api/public/v1/courier-documents/$publicId/submit',
        auth: false,
        body: const {},
      ),
    );
  }

  Future<List<JetDijiCity>> cities() async {
    final data = await http.get('/api/public/v1/geography/cities', auth: false);
    return [
      for (final row in jetdijiList(data))
        if (row is Map) JetDijiCity.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<List<JetDijiDistrict>> districts(int cityId) async {
    final data = await http.get(
      '/api/public/v1/geography/cities/$cityId/districts',
      auth: false,
    );
    return [
      for (final row in jetdijiList(data))
        if (row is Map)
          JetDijiDistrict.fromJson(Map<String, dynamic>.from(row)),
    ];
  }
}
