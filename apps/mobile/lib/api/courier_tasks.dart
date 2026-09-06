import 'package:dio/dio.dart';

import '../data/vault.dart';
import '../models.dart';
import 'panel_models.dart';

/// HTTP for the courier task surface.
///
/// Today: Fastify `/v1/tasks` ([apps/api](apps/api)).
/// Later: panel ` /api/public/v1/courier-tasks` — change [listPath] / [itemPath]
/// only. Screens keep talking [DeliveryTask].
class CourierTaskClient {
  CourierTaskClient(this.dio);

  final Dio dio;

  static const listPath = '/v1/tasks';

  static String itemPath(String taskId) => '/v1/tasks/$taskId';

  Future<Response<Map<String, dynamic>>> list({
    String? updatedSince,
    String? cursor,
  }) {
    return dio.get<Map<String, dynamic>>(
      listPath,
      queryParameters: {
        if (updatedSince != null) 'updatedSince': updatedSince,
        if (cursor != null) 'cursor': cursor,
      },
    );
  }

  Future<Response<Map<String, dynamic>>> detail(String taskId) {
    return dio.get<Map<String, dynamic>>(itemPath(taskId));
  }

  Future<Response<Map<String, dynamic>>> transition({
    required String taskId,
    required Map<String, Object?> body,
    required String idempotencyKey,
  }) {
    return dio.post<Map<String, dynamic>>(
      '${itemPath(taskId)}/transition',
      options: Options(headers: {'idempotency-key': idempotencyKey}),
      data: body,
    );
  }

  Future<Response<Map<String, dynamic>>> finalize({
    required String taskId,
    required Map<String, Object?> body,
    required String idempotencyKey,
  }) {
    return dio.post<Map<String, dynamic>>(
      '${itemPath(taskId)}/finalize',
      options: Options(headers: {'idempotency-key': idempotencyKey}),
      data: body,
    );
  }
}

/// ASSIGNED → … → IN_PROGRESS. Finalize (DELIVERED) yalnız son adımı kabul eder.
const kStartChain = ['ASSIGNED', 'ACCEPTED', 'EN_ROUTE', 'ARRIVED', 'IN_PROGRESS'];

List<({String to, int rowVersion})> startTransitions({
  required String wireStatus,
  required int rowVersion,
}) {
  final i = kStartChain.indexOf(wireStatus);
  if (i < 0 || i >= kStartChain.length - 1) return const [];
  final next = kStartChain.sublist(i + 1);
  return [
    for (var k = 0; k < next.length; k++)
      (to: next[k], rowVersion: rowVersion + k),
  ];
}

String defaultWireStatus(TaskStatus status) => switch (status) {
  TaskStatus.delivered => 'COMPLETED',
  TaskStatus.failed => 'FAILED',
  TaskStatus.cancelled => 'CANCELLED',
  TaskStatus.inProgress => 'IN_PROGRESS',
  TaskStatus.assigned || TaskStatus.queued => 'ASSIGNED',
};

TaskStatus taskStatusFromWire(String? raw) => switch (raw) {
  'COMPLETED' => TaskStatus.delivered,
  'FAILED' => TaskStatus.failed,
  'CANCELLED' => TaskStatus.cancelled,
  'IN_PROGRESS' || 'EN_ROUTE' || 'ARRIVED' => TaskStatus.inProgress,
  'ASSIGNED' || 'ACCEPTED' => TaskStatus.assigned,
  _ => TaskStatus.assigned,
};

/// Panel `ShipmentStatusDefinition.code` → ekran enum.
/// `startTransitions` Fastify zinciridir; panel `wireStatus` ile çağrılmaz.
TaskStatus taskStatusFromPanel(String? raw) => switch (raw) {
  'DELIVERED' => TaskStatus.delivered,
  'FAILED' || 'RETURN_PROCESS' || 'RETURNED' => TaskStatus.failed,
  'CANCELLED' => TaskStatus.cancelled,
  'OUT_FOR_DELIVERY' || 'IN_PROGRESS' || 'EN_ROUTE' || 'ARRIVED' =>
    TaskStatus.inProgress,
  _ => TaskStatus.assigned,
};

TaskKind taskKindFromWire(String? raw) => switch (raw) {
  'PICKUP' => TaskKind.pickup,
  'DOCUMENT' => TaskKind.document,
  _ => TaskKind.delivery,
};

/// FailScreen Türkçe etiket → workflow outcome (standart-teslimat.v3).
/// Yeni kod uydurma; listede yoksa en yakın mevcut failure.
String failureOutcomeCode(String reason) => switch (reason) {
  'Adres bulunamadı' ||
  'Adres hatalı' ||
  'Siteye giriş izni yok' ||
  'address_not_found' ||
  'wrong_address' ||
  'no_access' ||
  'Address not found' ||
  'Wrong address' ||
  'No site access' =>
    'ADDRESS_NOT_FOUND',
  'Alıcı teslim almadı' ||
  'Ödeme alınamadı' ||
  'refused' ||
  'no_payment' ||
  'Recipient refused' ||
  'Payment not collected' =>
    'REFUSED',
  'Alıcı adreste yok' ||
  'recipient_absent' ||
  'Recipient not home' =>
    'RECIPIENT_ABSENT',
  _ => 'RECIPIENT_ABSENT',
};

bool photoRequiredForFailure(String reason) {
  final code = failureOutcomeCode(reason);
  return code == 'RECIPIENT_ABSENT' || code == 'ADDRESS_NOT_FOUND';
}

DeliveryTask deliveryTaskFromSummary(Map<String, dynamic> json) {
  final address = Map<String, dynamic>.from(json['address'] as Map? ?? const {});
  final contact = Map<String, dynamic>.from(json['contact'] as Map? ?? const {});
  final coords = address['coordinates'] is Map
      ? Map<String, dynamic>.from(address['coordinates'] as Map)
      : const <String, dynamic>{};
  final line1 = address['line1'] as String? ?? '';
  final district = address['district'] as String?;
  final city = address['city'] as String? ?? '';
  final line2 = address['line2'] as String?;
  final composed = [
    line1,
    if (line2 != null && line2.isNotEmpty) line2,
    if (district != null && district.isNotEmpty && city.isNotEmpty)
      '$district / $city'
    else if (city.isNotEmpty)
      city,
  ].where((p) => p.isNotEmpty).join(', ');

  final workflow = json['workflow'] is Map
      ? Map<String, dynamic>.from(json['workflow'] as Map)
      : const <String, dynamic>{};

  return DeliveryTask(
    id: json['id'] as String? ?? Vault.newUuid(),
    ref: json['reference'] as String? ?? '',
    recipient: contact['name'] as String? ?? '',
    phone: contact['phone'] as String? ?? contact['maskedPhone'] as String?,
    address: composed,
    window: _slotWindow(json['slotStartAt'] as String?, json['slotEndAt'] as String?),
    kind: taskKindFromWire(json['type'] as String?),
    status: taskStatusFromWire(json['status'] as String?),
    note: json['notes'] as String? ?? json['previousFailureReason'] as String?,
    cod: (json['codAmount'] as num?)?.round(),
    sequence: (json['sequence'] as num?)?.toInt() ?? 0,
    etaMinutes: _etaMinutes(json['etaAt'] as String?),
    lat: (coords['lat'] as num?)?.toDouble() ?? 38.1512,
    lng: (coords['lng'] as num?)?.toDouble() ?? 29.0614,
    custodyCount: (json['itemCount'] as num?)?.toInt(),
    rowVersion: (json['rowVersion'] as num?)?.toInt() ?? 0,
    workflowVersion: (workflow['version'] as num?)?.toInt() ?? 1,
    wireStatus: json['status'] as String? ?? 'ASSIGNED',
  );
}

/// Panel `GET courier-tasks` satırı → aynı ekran DTO.
/// Session hâlâ Fastify [CourierTaskClient] kullanır; cookie login yok (karar 1).
DeliveryTask deliveryTaskFromPanel(PanelCourierTaskDto row) {
  final dest = row.destination;
  return DeliveryTask(
    id: row.id,
    ref: row.shipmentNumber,
    recipient: row.recipientName ?? '',
    phone: row.recipientPhone,
    address: dest.address ?? '',
    window: _slotWindow(row.plannedDeliveryAt, null),
    kind: TaskKind.delivery,
    status: taskStatusFromPanel(row.statusCode),
    note: row.statusReasonCode,
    sequence: 0,
    lat: dest.latitude ?? 38.1512,
    lng: dest.longitude ?? 29.0614,
    custodyCount: row.packageCount,
    wireStatus: row.statusCode,
  );
}

String _slotWindow(String? start, String? end) {
  final a = _hhmm(start);
  final b = _hhmm(end);
  if (a == null && b == null) return '—';
  if (a != null && b != null) return '$a–$b';
  return a ?? b!;
}

String? _hhmm(String? iso) {
  final t = DateTime.tryParse(iso ?? '');
  if (t == null) return null;
  final local = t.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

int? _etaMinutes(String? iso) {
  final t = DateTime.tryParse(iso ?? '');
  if (t == null) return null;
  final m = t.difference(DateTime.now()).inMinutes;
  return m < 0 ? 0 : m;
}
