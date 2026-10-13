/// DTOs for `jetlogi-panel`'s `public/v1/courier-tasks` surface — see
/// docs/05-panel-entegrasyonu.md. Field names mirror the panel's actual
/// Prisma-backed JSON response (verified by reading
/// `src/app/api/public/v1/courier-tasks/route.ts` in the panel repo), not
/// our own `apps/api` shapes.
library;

class PanelDestinationDto {
  const PanelDestinationDto({
    this.countryCode,
    this.cityCode,
    this.districtCode,
    this.address,
    this.latitude,
    this.longitude,
  });

  final String? countryCode;
  final String? cityCode;
  final String? districtCode;
  final String? address;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory PanelDestinationDto.fromJson(Map<String, dynamic> json) =>
      PanelDestinationDto(
        countryCode: json['countryCode'] as String?,
        cityCode: json['cityCode'] as String?,
        districtCode: json['districtCode'] as String?,
        address: json['address'] as String?,
        latitude: double.tryParse('${json['latitude']}'),
        longitude: double.tryParse('${json['longitude']}'),
      );
}

/// One row of `GET courier-tasks` / `GET courier-tasks/:shipmentId`.
class PanelCourierTaskDto {
  const PanelCourierTaskDto({
    required this.id,
    required this.shipmentNumber,
    required this.statusCode,
    required this.destination,
    this.externalReference,
    this.statusReasonCode,
    this.recipientName,
    this.recipientPhone,
    this.plannedDeliveryAt,
    this.createdAt,
    this.packageCount,
    this.customerDisplayName,
    this.assignmentStatusCode,
  });

  final String id;
  final String shipmentNumber;
  final String? externalReference;

  /// Canonical `ShipmentStatusDefinition.code` — not a client-side enum,
  /// display text is resolved server-side (README §7).
  final String statusCode;
  final String? statusReasonCode;

  final String? recipientName;
  final String? recipientPhone;
  final PanelDestinationDto destination;

  final String? plannedDeliveryAt;
  final String? createdAt;
  final int? packageCount;

  final String? customerDisplayName;

  /// The courier's current `ShipmentAssignment.statusCode`, when present.
  final String? assignmentStatusCode;

  factory PanelCourierTaskDto.fromJson(Map<String, dynamic> json) {
    final destination = json['destination'] as Map?;
    final customer = json['customer'] as Map?;
    final assignment = json['assignment'] as Map?;
    return PanelCourierTaskDto(
      id: json['id'] as String? ?? '',
      shipmentNumber: json['shipmentNumber'] as String? ?? '',
      externalReference: json['externalReference'] as String?,
      statusCode: json['statusCode'] as String? ?? 'CREATED',
      statusReasonCode: json['statusReasonCode'] as String?,
      recipientName: json['recipientName'] as String?,
      recipientPhone:
          json['recipientPhone'] as String? ??
          json['recipientPhoneMasked'] as String?,
      destination: destination == null
          ? const PanelDestinationDto()
          : PanelDestinationDto.fromJson(Map<String, dynamic>.from(destination)),
      plannedDeliveryAt: json['plannedDeliveryAt'] as String?,
      createdAt: json['createdAt'] as String?,
      packageCount: (json['packageCount'] as num?)?.toInt(),
      customerDisplayName: customer == null
          ? null
          : customer['displayName'] as String?,
      assignmentStatusCode: assignment == null
          ? null
          : assignment['statusCode'] as String?,
    );
  }
}

class PanelCourierTaskSummaryDto {
  const PanelCourierTaskSummaryDto({
    required this.total,
    required this.created,
    required this.planned,
    required this.today,
  });

  final int total;
  final int created;
  final int planned;
  final int today;

  static const empty = PanelCourierTaskSummaryDto(
    total: 0,
    created: 0,
    planned: 0,
    today: 0,
  );

  factory PanelCourierTaskSummaryDto.fromJson(Map<String, dynamic> json) =>
      PanelCourierTaskSummaryDto(
        total: (json['total'] as num?)?.toInt() ?? 0,
        created: (json['created'] as num?)?.toInt() ?? 0,
        planned: (json['planned'] as num?)?.toInt() ?? 0,
        today: (json['today'] as num?)?.toInt() ?? 0,
      );
}

/// `GET courier-tasks` response envelope (`data` object).
class PanelCourierTaskListDto {
  const PanelCourierTaskListDto({
    required this.tasks,
    required this.summary,
  });

  final List<PanelCourierTaskDto> tasks;
  final PanelCourierTaskSummaryDto summary;

  static const empty = PanelCourierTaskListDto(
    tasks: [],
    summary: PanelCourierTaskSummaryDto.empty,
  );

  factory PanelCourierTaskListDto.fromJson(Map<String, dynamic> json) {
    final raw = json['tasks'] as List? ?? const [];
    final summary = json['summary'] as Map?;
    return PanelCourierTaskListDto(
      tasks: [
        for (final row in raw)
          if (row is Map)
            PanelCourierTaskDto.fromJson(Map<String, dynamic>.from(row)),
      ],
      summary: summary == null
          ? PanelCourierTaskSummaryDto.empty
          : PanelCourierTaskSummaryDto.fromJson(
              Map<String, dynamic>.from(summary),
            ),
    );
  }
}

/// `POST courier-tasks/:id/accept` and `/start` share this response shape:
/// `{ already*: bool, ...timestamps }`. We only need the idempotency flag
/// and, for `start`, the resulting workflow state.
class PanelTaskActionResultDto {
  const PanelTaskActionResultDto({
    required this.already,
    this.workflowState,
  });

  final bool already;
  final String? workflowState;

  factory PanelTaskActionResultDto.fromJson(Map<String, dynamic> json) {
    return PanelTaskActionResultDto(
      already:
          json['alreadyAccepted'] == true ||
          json['alreadyStarted'] == true ||
          json['alreadyFinalized'] == true,
      workflowState: json['workflowState'] as String?,
    );
  }
}

/// `POST courier-tasks/:id/finalize` — contract as specified to the panel
/// team (docs/05-panel-entegrasyonu.md §2); that endpoint is being built in
/// parallel and hadn't shipped when this client was written, so treat the
/// response shape here as provisional until verified against the real one.
class PanelFinalizeResultDto {
  const PanelFinalizeResultDto({required this.already, this.currentStateCode});

  final bool already;
  final String? currentStateCode;

  factory PanelFinalizeResultDto.fromJson(Map<String, dynamic> json) =>
      PanelFinalizeResultDto(
        already: json['alreadyFinalized'] == true,
        currentStateCode: json['currentStateCode'] as String?,
      );
}

class PanelCustodyActionResultDto {
  const PanelCustodyActionResultDto({
    required this.already,
    this.statusCode,
    this.warehouseId,
  });

  final bool already;
  final String? statusCode;
  final String? warehouseId;

  factory PanelCustodyActionResultDto.fromJson(Map<String, dynamic> json) =>
      PanelCustodyActionResultDto(
        already:
            json['alreadyReturned'] == true || json['alreadyReported'] == true,
        statusCode: json['statusCode'] as String?,
        warehouseId: json['warehouseId'] as String?,
      );
}

class PanelCourierProfileDto {
  const PanelCourierProfileDto({
    required this.courierId,
    required this.courierCode,
    required this.fullName,
  });

  final String courierId;
  final String courierCode;
  final String fullName;

  factory PanelCourierProfileDto.fromJson(Map<String, dynamic> json) =>
      PanelCourierProfileDto(
        courierId: json['id'] as String? ?? json['courierId'] as String? ?? '',
        courierCode: json['courierCode'] as String? ?? '',
        fullName: json['fullName'] as String? ?? '',
      );
}

/// Thrown for a non-2xx panel response so callers can branch on `code`
/// (the panel's canonical error codes, e.g. `COURIER_TASK_NOT_FOUND`,
/// `WORKFLOW_SHIPMENT_STATUS_REASON_REQUIRED`) without parsing Dio internals.
class PanelApiException implements Exception {
  PanelApiException(
    this.code, {
    this.statusCode,
    this.message,
    this.serverMessage,
    this.remainingAttempts,
    this.lockedUntil,
    this.missing = const [],
  });

  final String code;
  final int? statusCode;
  final String? message;

  /// Sunucunun `error.message` metni (çoğunlukla Türkçe); her hatada gelmez.
  final String? serverMessage;

  /// Giriş ve OTP hatalarında kalan deneme hakkı.
  final int? remainingAttempts;

  /// 423 `ACCOUNT_TEMPORARILY_LOCKED`: kilidin açılacağı an.
  final DateTime? lockedUntil;

  /// 422 `DELIVERY_REQUIREMENTS_MISSING`: PHOTO | SIGNATURE | OTP | FORM |
  /// LOCATION.
  final List<String> missing;

  /// Ağ, zaman aşımı, 408/429 ve 5xx — kuyrukta bırakıp tekrar dene.
  /// 401 ayrı ele alınır (oturum düşer); diğer 4xx kalıcı reddir.
  bool get isRetryable {
    final s = statusCode;
    if (s == null) return true;
    if (s == 408 || s == 429) return true;
    return s >= 500;
  }

  @override
  String toString() => 'PanelApiException($code, status: $statusCode)';
}

/// Kontrolde reddedilen bir fotoğraf ("Hatalarım" satırı).
class PhotoMistakeDto {
  const PhotoMistakeDto({
    required this.evidenceId,
    this.shipmentNumber = '',
    this.requirementLabel = '',
    this.requirementHint,
    this.reasonCode,
    this.reason,
    this.capturedAt,
    this.acknowledgedAt,
  });

  factory PhotoMistakeDto.fromJson(Map<String, dynamic> j) => PhotoMistakeDto(
    evidenceId: j['evidenceId'] as String? ?? '',
    shipmentNumber: j['shipmentNumber'] as String? ?? '',
    requirementLabel: j['requirementLabel'] as String? ?? '',
    requirementHint: j['requirementHint'] as String?,
    reasonCode: j['reasonCode'] as String?,
    reason: j['reason'] as String?,
    capturedAt: DateTime.tryParse(j['capturedAt'] as String? ?? ''),
    acknowledgedAt: DateTime.tryParse(j['acknowledgedAt'] as String? ?? ''),
  );

  final String evidenceId;
  final String shipmentNumber;
  final String requirementLabel;
  final String? requirementHint;

  /// WRONG_SUBJECT, WRONG_PLACE, SIGN_NOT_VISIBLE, STICKER_NOT_VISIBLE,
  /// NOT_READABLE, BLURRY, TOO_DARK, PAGE_MISSING, SIGNATURE_MISSING, OTHER.
  final String? reasonCode;
  final String? reason;
  final DateTime? capturedAt;
  final DateTime? acknowledgedAt;

  PhotoMistakeDto acknowledged(DateTime at) => PhotoMistakeDto(
    evidenceId: evidenceId,
    shipmentNumber: shipmentNumber,
    requirementLabel: requirementLabel,
    requirementHint: requirementHint,
    reasonCode: reasonCode,
    reason: reason,
    capturedAt: capturedAt,
    acknowledgedAt: acknowledgedAt ?? at,
  );
}

/// `courier-mistakes` ve `courier-mistakes/count` yanıtı. Puan, [minPhotos]
/// fotoğraftan sonra hesaplanır; öncesinde [score] null, [band] `UNRATED`.
class PhotoMistakesDto {
  const PhotoMistakesDto({
    this.items = const [],
    this.unacknowledged = 0,
    this.score,
    this.band = 'UNRATED',
    this.photos = 0,
    this.rejected = 0,
    this.minPhotos = 10,
    this.windowDays = 30,
  });

  factory PhotoMistakesDto.fromJson(Map<String, dynamic> j) {
    final score = j['score'] is Map ? j['score'] as Map : const {};
    return PhotoMistakesDto(
      items: [
        for (final row in j['items'] as List? ?? const [])
          if (row is Map)
            PhotoMistakeDto.fromJson(Map<String, dynamic>.from(row)),
      ],
      unacknowledged: (j['unacknowledged'] as num?)?.toInt() ?? 0,
      score: (score['score'] as num?)?.toDouble(),
      band: score['band'] as String? ?? 'UNRATED',
      photos: (score['photos'] as num?)?.toInt() ?? 0,
      rejected: (score['rejected'] as num?)?.toInt() ?? 0,
      minPhotos: (score['minPhotos'] as num?)?.toInt() ?? 10,
      windowDays: (score['windowDays'] as num?)?.toInt() ?? 30,
    );
  }

  final List<PhotoMistakeDto> items;
  final int unacknowledged;
  final double? score;

  /// GOOD, WATCH, RISK, UNRATED.
  final String band;
  final int photos;
  final int rejected;
  final int minPhotos;
  final int windowDays;
}

/// Zimmet geçmişi satırı: kuryeye gelen (IN) ya da kuryeden çıkan (OUT) kalem.
class CustodyMoveDto {
  const CustodyMoveDto({
    required this.incoming,
    this.shipmentNumber = '',
    this.recipientName = '',
    this.counterparty = '',
    this.status = '',
    this.at,
  });

  factory CustodyMoveDto.fromJson(Map<String, dynamic> j) => CustodyMoveDto(
    incoming: j['direction'] != 'OUT',
    shipmentNumber: j['shipmentNumber'] as String? ?? '',
    recipientName: j['recipientName'] as String? ?? '',
    counterparty: (j['counterparty'] as Map?)?['name'] as String? ?? '',
    status: j['status'] as String? ?? '',
    at: DateTime.tryParse(
      (j['completedAt'] ?? j['updatedAt'] ?? j['createdAt']) as String? ?? '',
    ),
  );

  final bool incoming;
  final String shipmentNumber;
  final String recipientName;

  /// Karşı taraf: depo, şube ya da kurye adı.
  final String counterparty;

  /// PENDING, ACCEPTED, ACCEPTED_DAMAGED, REJECTED …
  final String status;
  final DateTime? at;
}

/// Gönderiye yazılmış dijital tutanak.
class TaskReportDto {
  const TaskReportDto({
    required this.id,
    this.reportType = 'OTHER',
    this.note,
    this.counterpartName = '',
    this.createdAt,
  });

  factory TaskReportDto.fromJson(Map<String, dynamic> j) => TaskReportDto(
    id: j['id'] as String? ?? '',
    reportType: j['reportType'] as String? ?? 'OTHER',
    note: j['note'] as String?,
    counterpartName:
        (j['counterpartSignature'] as Map?)?['signerName'] as String? ?? '',
    createdAt: DateTime.tryParse(
      (j['submittedAt'] ?? j['createdAt']) as String? ?? '',
    ),
  );

  final String id;

  /// PICKUP, DELIVERY, DAMAGE, OTHER.
  final String reportType;
  final String? note;
  final String counterpartName;
  final DateTime? createdAt;
}

