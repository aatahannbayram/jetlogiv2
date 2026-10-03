import 'package:dio/dio.dart';

import '../data/vault.dart';
import 'jetdiji_branch_models.dart';
import 'jetdiji_http.dart';

/// JetDiji şube mobil API. branch.yaml'daki 48 uç, bir metot bir yol.
class JetDijiBranchApi {
  JetDijiBranchApi(this.http);

  final JetDijiHttp http;

  static JetDijiBranchApi create({Vault? vault}) {
    return JetDijiBranchApi(
      JetDijiHttp(
        dio: JetDijiHttp.buildDio(),
        tokens: JetDijiTokenStore(vault: vault, role: 'branch'),
      ),
    );
  }

  static JetDijiBranchApi forTest(Dio dio) {
    return JetDijiBranchApi(
      JetDijiHttp(dio: dio, tokens: JetDijiTokenStore(role: 'branch')),
    );
  }

  Future<bool> get hasToken async {
    final token = await http.tokens.read();
    return token != null && token.isNotEmpty;
  }

  Future<JetDijiBranchLogin> login({
    required String email,
    required String password,
    String? agencyId,
  }) async {
    final data = jetdijiMap(
      await http.post(
        '/api/portal/v1/agency-auth/login',
        auth: false,
        body: {
          'email': email,
          'password': password,
          if (agencyId != null) 'agencyId': agencyId,
        },
      ),
    );
    final login = JetDijiBranchLogin.fromJson(data);
    if (login.accessToken.isNotEmpty) {
      await http.tokens.save(login.accessToken, login.expiresAt);
    }
    return login;
  }

  Future<JetDijiBranchUser> session() async {
    return JetDijiBranchUser.fromSession(
      jetdijiMap(await http.get('/api/portal/v1/agency-auth/session')),
    );
  }

  Future<void> logout() async {
    await http.post('/api/portal/v1/agency-auth/logout', body: const {});
    await http.tokens.clear();
  }

  Future<JetDijiBranchDashboard> dashboard() async {
    return JetDijiBranchDashboard.fromJson(
      jetdijiMap(await http.get('/api/portal/v1/branch/dashboard')),
    );
  }

  Future<Map<String, dynamic>> preparation() async {
    return jetdijiMap(await http.get('/api/portal/v1/branch/preparation'));
  }

  Future<Map<String, dynamic>> printRows(List<String> shipmentIds) async {
    return jetdijiMap(
      await http.post(
        '/api/portal/v1/branch/preparation/print-rows',
        write: false,
        body: {'shipmentIds': shipmentIds},
      ),
    );
  }

  Future<Map<String, dynamic>> dispatchOptions({String? shipmentId}) async {
    return jetdijiMap(
      await http.get(
        '/api/portal/v1/branch/dispatch/options',
        query: {if (shipmentId != null) 'shipmentId': shipmentId},
      ),
    );
  }

  Future<Map<String, dynamic>> handover({
    required String courierId,
    required List<String> shipmentIds,
    String? idempotencyKey,
  }) async {
    return jetdijiMap(
      await http.post(
        '/api/portal/v1/branch/dispatch/handover',
        idempotencyKey: idempotencyKey,
        body: {'courierId': courierId, 'shipmentIds': shipmentIds},
      ),
    );
  }

  Future<Map<String, dynamic>> changeHandover({
    required String courierId,
    required List<String> shipmentIds,
    String? idempotencyKey,
  }) async {
    return jetdijiMap(
      await http.post(
        '/api/portal/v1/branch/dispatch/handover/change',
        idempotencyKey: idempotencyKey,
        body: {'courierId': courierId, 'shipmentIds': shipmentIds},
      ),
    );
  }

  Future<Map<String, dynamic>> reassignOptions(String shipmentId) async {
    return jetdijiMap(
      await http.get(
        '/api/portal/v1/branch/dispatch/reassign',
        query: {'shipmentId': shipmentId},
      ),
    );
  }

  Future<Map<String, dynamic>> reassign({
    required String shipmentId,
    required String courierId,
    String? note,
    String? idempotencyKey,
  }) async {
    return jetdijiMap(
      await http.post(
        '/api/portal/v1/branch/dispatch/reassign',
        idempotencyKey: idempotencyKey,
        body: {
          'shipmentId': shipmentId,
          'courierId': courierId,
          if (note != null) 'note': note,
        },
      ),
    );
  }

  Future<Map<String, dynamic>> dispatchBoard() async {
    return jetdijiMap(await http.get('/api/portal/v1/branch/dispatch'));
  }

  Future<Map<String, dynamic>> courierJobs({
    String? shipmentId,
    String locale = 'tr',
  }) async {
    return jetdijiMap(
      await http.get(
        '/api/portal/v1/branch/courier-jobs',
        query: {
          if (shipmentId != null) 'shipmentId': shipmentId,
          'locale': locale,
        },
      ),
    );
  }

  Future<Map<String, dynamic>> cancelHandover({
    required String shipmentId,
    required String reasonCode,
    String? idempotencyKey,
  }) async {
    return jetdijiMap(
      await http.post(
        '/api/portal/v1/branch/dispatch/handover/cancel',
        idempotencyKey: idempotencyKey,
        body: {'shipmentId': shipmentId, 'reasonCode': reasonCode},
      ),
    );
  }

  Future<JetDijiCourierMap> courierMap() async {
    return JetDijiCourierMap.fromJson(
      jetdijiMap(await http.get('/api/portal/v1/branch/courier-map')),
    );
  }

  Future<Map<String, dynamic>> pending() async {
    return jetdijiMap(await http.get('/api/portal/v1/branch/pending'));
  }

  Future<Map<String, dynamic>> scanCourierReturn({
    required String scanCode,
    String? idempotencyKey,
  }) async {
    return jetdijiMap(
      await http.post(
        '/api/portal/v1/branch/pending/courier-return-scan',
        idempotencyKey: idempotencyKey,
        body: {'scanCode': scanCode},
      ),
    );
  }

  Future<Map<String, dynamic>> incomingTransfers() async {
    return jetdijiMap(
      await http.get('/api/portal/v1/branch/transfers/incoming'),
    );
  }

  Future<Map<String, dynamic>> incomingTransfer(String transferId) async {
    return jetdijiMap(
      await http.get('/api/portal/v1/branch/transfers/incoming/$transferId'),
    );
  }

  Future<Map<String, dynamic>> scanIncoming({
    required String scanCode,
    String? transferId,
    String? idempotencyKey,
  }) async {
    return jetdijiMap(
      await http.post(
        '/api/portal/v1/branch/transfers/incoming/scan',
        idempotencyKey: idempotencyKey,
        body: {
          'scanCode': scanCode,
          if (transferId != null) 'transferId': transferId,
        },
      ),
    );
  }

  Future<Map<String, dynamic>> acceptIncoming(
    String transferId, {
    String? idempotencyKey,
  }) async {
    return jetdijiMap(
      await http.post(
        '/api/portal/v1/branch/transfers/incoming/$transferId/accept',
        idempotencyKey: idempotencyKey,
        body: const {},
      ),
    );
  }

  Future<Map<String, dynamic>> confirmIncoming(
    String transferId, {
    String? idempotencyKey,
  }) async {
    return jetdijiMap(
      await http.post(
        '/api/portal/v1/branch/transfers/incoming/$transferId/confirm',
        idempotencyKey: idempotencyKey,
        body: const {},
      ),
    );
  }

  Future<Map<String, dynamic>> outgoingOptions() async {
    return jetdijiMap(
      await http.get('/api/portal/v1/branch/transfers/outgoing'),
    );
  }

  Future<Map<String, dynamic>> sendOutgoing(
    Map<String, dynamic> body, {
    String? idempotencyKey,
  }) async {
    return jetdijiMap(
      await http.post(
        '/api/portal/v1/branch/transfers/outgoing',
        idempotencyKey: idempotencyKey,
        body: body,
      ),
    );
  }

  Future<Map<String, dynamic>> resolveOutgoing({
    required String scanCode,
    String? idempotencyKey,
  }) async {
    return jetdijiMap(
      await http.post(
        '/api/portal/v1/branch/transfers/outgoing/resolve',
        idempotencyKey: idempotencyKey,
        body: {'scanCode': scanCode},
      ),
    );
  }

  Future<Map<String, dynamic>> labels() async {
    return jetdijiMap(await http.get('/api/portal/v1/branch/labels'));
  }

  Future<Map<String, dynamic>> labelAction(
    Map<String, dynamic> body, {
    String? idempotencyKey,
  }) async {
    return jetdijiMap(
      await http.post(
        '/api/portal/v1/branch/labels',
        idempotencyKey: idempotencyKey,
        body: body,
      ),
    );
  }

  Future<Map<String, dynamic>> counts() async {
    return jetdijiMap(await http.get('/api/portal/v1/branch/counts'));
  }

  Future<Map<String, dynamic>> startCount({
    String? idempotencyKey,
    Map<String, dynamic> body = const {},
  }) async {
    return jetdijiMap(
      await http.post(
        '/api/portal/v1/branch/counts',
        idempotencyKey: idempotencyKey,
        body: body,
      ),
    );
  }

  Future<Map<String, dynamic>> countDetail(String countId) async {
    return jetdijiMap(await http.get('/api/portal/v1/branch/counts/$countId'));
  }

  Future<Map<String, dynamic>> countAction(
    String countId,
    Map<String, dynamic> body, {
    String? idempotencyKey,
  }) async {
    return jetdijiMap(
      await http.post(
        '/api/portal/v1/branch/counts/$countId',
        idempotencyKey: idempotencyKey,
        body: body,
      ),
    );
  }

  Future<Map<String, dynamic>> smsTemplates() async {
    return jetdijiMap(await http.get('/api/portal/v1/branch/sms/templates'));
  }

  Future<Map<String, dynamic>> smsTargets({String? query}) async {
    return jetdijiMap(
      await http.get(
        '/api/portal/v1/branch/sms/targets',
        query: {if (query != null) 'q': query},
      ),
    );
  }

  Future<Map<String, dynamic>> smsPreview(Map<String, dynamic> body) async {
    return jetdijiMap(
      await http.post('/api/portal/v1/branch/sms/preview', body: body),
    );
  }

  Future<Map<String, dynamic>> smsSend(
    Map<String, dynamic> body, {
    String? idempotencyKey,
  }) async {
    return jetdijiMap(
      await http.post(
        '/api/portal/v1/branch/sms/send',
        idempotencyKey: idempotencyKey,
        body: body,
      ),
    );
  }

  Future<Map<String, dynamic>> smsHistory() async {
    return jetdijiMap(await http.get('/api/portal/v1/branch/sms/history'));
  }

  Future<Map<String, dynamic>> announcements() async {
    return jetdijiMap(await http.get('/api/portal/v1/branch/announcements'));
  }

  Future<Map<String, dynamic>> training() async {
    return jetdijiMap(await http.get('/api/portal/v1/branch/training'));
  }

  Future<Map<String, dynamic>> performance({String range = 'today'}) async {
    return jetdijiMap(
      await http.get(
        '/api/portal/v1/branch/performance',
        query: {'range': range},
      ),
    );
  }

  Future<Map<String, dynamic>> invoices({String? period}) async {
    return jetdijiMap(
      await http.get(
        '/api/portal/v1/branch/invoices',
        query: {if (period != null) 'period': period},
      ),
    );
  }

  Future<Map<String, dynamic>> invoiceSupport(
    Map<String, dynamic> body, {
    String? idempotencyKey,
  }) async {
    return jetdijiMap(
      await http.post(
        '/api/portal/v1/branch/invoices/support',
        idempotencyKey: idempotencyKey,
        body: body,
      ),
    );
  }

  Future<Map<String, dynamic>> compliance() async {
    return jetdijiMap(await http.get('/api/portal/v1/branch/compliance'));
  }

  Future<Map<String, dynamic>> createCard(
    Map<String, dynamic> body, {
    String? idempotencyKey,
  }) async {
    return jetdijiMap(
      await http.post(
        '/api/portal/v1/branch/compliance/cards',
        idempotencyKey: idempotencyKey,
        body: body,
      ),
    );
  }

  Future<Map<String, dynamic>> verifyCard(String token) async {
    return jetdijiMap(
      await http.post(
        '/api/portal/v1/branch/compliance/cards/verify',
        body: {'token': token},
      ),
    );
  }

  Future<List<JetDijiAgencyCourier>> couriers() async {
    final data = jetdijiMap(await http.get('/api/portal/v1/agency/couriers'));
    final items = data['items'];
    return [
      for (final row in items is List ? items : const [])
        if (row is Map)
          JetDijiAgencyCourier.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<Map<String, dynamic>> regions() async {
    return jetdijiMap(await http.get('/api/portal/v1/agency/regions'));
  }

  Future<Map<String, dynamic>> warehouses() async {
    return jetdijiMap(await http.get('/api/portal/v1/agency/warehouses'));
  }

  Future<Map<String, dynamic>> overview() async {
    return jetdijiMap(await http.get('/api/portal/v1/agency/overview'));
  }
}
