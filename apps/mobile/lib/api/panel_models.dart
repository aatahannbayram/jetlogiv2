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
      recipientPhone: json['recipientPhone'] as String?,
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
        courierId: json['id'] as String? ?? '',
        courierCode: json['courierCode'] as String? ?? '',
        fullName: json['fullName'] as String? ?? '',
      );
}

/// Thrown for a non-2xx panel response so callers can branch on `code`
/// (the panel's canonical error codes, e.g. `COURIER_TASK_NOT_FOUND`,
/// `WORKFLOW_SHIPMENT_STATUS_REASON_REQUIRED`) without parsing Dio internals.
class PanelApiException implements Exception {
  PanelApiException(this.code, {this.statusCode, this.message});

  final String code;
  final int? statusCode;
  final String? message;

  @override
  String toString() => 'PanelApiException($code, status: $statusCode)';
}
