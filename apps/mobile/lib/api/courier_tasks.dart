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
TaskStatus taskStatusFromPanel(
  String? raw, {
  String? assignmentStatusCode,
}) {
  final fromShipment = switch (raw) {
    // JetDiji durum kodları sayısal metindir; eski adlar yedek olarak gelir.
    'DELIVERED' || '5010' || '5020' => TaskStatus.delivered,
    'FAILED' ||
    'RETURN_PROCESS' ||
    'RETURNED' ||
    '5110' ||
    '6010' ||
    '7010' ||
    '7020' ||
    '7030' => TaskStatus.failed,
    'CANCELLED' || '8010' || '8030' => TaskStatus.cancelled,
    'OUT_FOR_DELIVERY' ||
    'IN_PROGRESS' ||
    'EN_ROUTE' ||
    'ARRIVED' ||
    '4020' => TaskStatus.inProgress,
    'REDELIVERY' => TaskStatus.assigned,
    _ => TaskStatus.assigned,
  };
  if (fromShipment != TaskStatus.assigned) return fromShipment;
  return switch (assignmentStatusCode) {
    'IN_PROGRESS' || 'ACCEPTED' || 'OUT_FOR_DELIVERY' => TaskStatus.inProgress,
    _ => fromShipment,
  };
}

TaskKind taskKindFromWire(String? raw) => switch (raw) {
  'PICKUP' => TaskKind.pickup,
  'DOCUMENT' => TaskKind.document,
  _ => TaskKind.delivery,
};

/// ReturnScreen'in "Teslim Edilemedi" sekmesindeki Türkçe etiket → workflow
/// outcome (standart-teslimat.v3).
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
  // "Ödeme alınamadı"/"no_payment" kasıtlı olarak yok — COD tamamen kaldırıldı.
  'Alıcı teslim almadı' || 'refused' || 'Recipient refused' => 'REFUSED',
  'Alıcı adreste yok' ||
  'recipient_absent' ||
  'Recipient not home' =>
    'RECIPIENT_ABSENT',
  _ => 'RECIPIENT_ABSENT',
};

/// JetDiji 5110 neden kodları. Panel teslim sonucu bunları ister.
String panelFailureReasonCode(String reason) => switch (failureOutcomeCode(reason)) {
  'ADDRESS_NOT_FOUND' => '9304',
  'REFUSED' => '9303',
  'RECIPIENT_ABSENT' => '9302',
  _ => '9301',
};

/// Panel listesinden seçilen nedenin kendi kodu. Ad eşleşirse panel kodu
/// aynen gider; yalnız yerel (panelsiz) listede ad → 93xx eşlemesi yapılır.
String panelReasonCodeFor(
  String reason,
  List<({String code, String name})> panelReasons,
) {
  for (final row in panelReasons) {
    if (row.name == reason && row.code.trim().isNotEmpty) return row.code;
  }
  return panelFailureReasonCode(reason);
}

String _fold(String raw) => raw
    .toLowerCase()
    .replaceAll('ı', 'i')
    .replaceAll('İ', 'i')
    .replaceAll('ş', 's')
    .replaceAll('ğ', 'g')
    .replaceAll('ü', 'u')
    .replaceAll('ö', 'o')
    .replaceAll('ç', 'c');

/// V3 §4.1 neden grubu kanıtı.
/// Vefat: fotoğraf/belge istenmez, açıklama zorunlu.
/// Hasarlı/sorunlu: fotoğraf ve açıklama zorunlu.
/// Mücbir/operasyonel ve kimlik/OTP: fotoğraf zorlanmaz.
/// Diğer/merkez desteği: açıklama zorunlu.
/// Adres/taşınmış/kapalı ve ulaşılamadı: fotoğraf.
({bool photo, bool note}) failureEvidence(String reason) {
  final r = _fold(reason);
  bool has(List<String> keys) => keys.any(r.contains);
  if (has(['vefat', 'deceased', 'death'])) return (photo: false, note: true);
  if (has(['hasar', 'sorunlu', 'damage'])) return (photo: true, note: true);
  if (has(['mucbir', 'operasyonel', 'force majeure', 'guvenlik'])) {
    return (photo: false, note: false);
  }
  if (has(['kimlik', 'otp', 'identity'])) return (photo: false, note: false);
  if (has(['diger', 'merkez', 'other'])) return (photo: false, note: true);
  if (has(['tasinmis', 'taninmiyor', 'kapali', 'moved', 'closed'])) {
    return (photo: true, note: false);
  }
  final code = failureOutcomeCode(reason);
  return (
    photo: code == 'RECIPIENT_ABSENT' || code == 'ADDRESS_NOT_FOUND',
    note: false,
  );
}

bool photoRequiredForFailure(String reason) => failureEvidence(reason).photo;

/// V3 §4.1: ulaşılamadı / kabul etmedi / randevu nedenlerinde önce
/// maskeli arama denemesi gerekir.
bool callRequiredForFailure(String reason) {
  final r = _fold(reason);
  return [
    'ulasilamadi',
    'adreste yok',
    'kabul etmedi',
    'teslim almadi',
    'randevu',
    'ileri tarih',
    'unreachable',
    'not home',
    'refused',
  ].any(r.contains);
}

DeliveryTask deliveryTaskFromSummary(Map<String, dynamic> json) {
  final address = Map<String, dynamic>.from(json['address'] as Map? ?? const {});
  final contact = Map<String, dynamic>.from(json['contact'] as Map? ?? const {});
  final attributes = Map<String, dynamic>.from(json['attributes'] as Map? ?? const {});
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
    merchantName: attributes['merchantName'] as String?,
  );
}

/// Panel `GET courier-tasks` satırı → aynı ekran DTO.
/// Panel oturumu açıkken [SessionController] bu eşlemeyi kullanır.
DeliveryTask deliveryTaskFromPanel(PanelCourierTaskDto row) {
  final dest = row.destination;
  final ref = row.shipmentNumber.isNotEmpty
      ? row.shipmentNumber
      : (row.externalReference ?? '');
  final address = dest.address?.trim() ?? '';
  final status = taskStatusFromPanel(
    row.statusCode,
    assignmentStatusCode: row.assignmentStatusCode,
  );
  return DeliveryTask(
    id: row.id,
    ref: ref,
    recipient: row.recipientName ?? '',
    phone: row.recipientPhone,
    address: address,
    window: _slotWindow(row.plannedDeliveryAt, null),
    kind: TaskKind.delivery,
    status: status,
    // Ham durum kodu ("4021") kuryeye not olarak gösterilmez.
    sequence: 0,
    etaMinutes: _etaMinutes(row.plannedDeliveryAt),
    // Eksi değer = planlanan saat geçti; listede "Gecikti" görünür.
    slaMinutesLeft: DateTime.tryParse(
      row.plannedDeliveryAt ?? '',
    )?.difference(DateTime.now()).inMinutes,
    lat: dest.latitude ?? 0,
    lng: dest.longitude ?? 0,
    custodyCount: row.packageCount,
    groupKey: address.isNotEmpty ? address.toLowerCase() : 'id:${row.id}',
    wireStatus: row.statusCode,
    merchantName: row.customerDisplayName,
    isCard: row.isCardDelivery,
    serviceName: row.serviceName ?? row.productName,
    plannedAt: DateTime.tryParse(row.plannedDeliveryAt ?? '')?.toLocal(),
    isVisit: isVisitMarker(row.productCode, row.serviceType),
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

/// Ürün/hizmet kodu ziyaret işi mi (gereksinimler yüklenmeden de bilinir).
bool isVisitMarker(String? productCode, String? serviceType) {
  final raw = '${productCode ?? ''} ${serviceType ?? ''}'.toUpperCase();
  return raw.contains('STICKER') || raw.contains('VISIT');
}
