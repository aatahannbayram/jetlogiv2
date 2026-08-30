class FieldFlags {
  const FieldFlags({
    required this.maskedCall,
    required this.cashCollect,
    required this.documentScan,
    required this.custody,
    required this.shiftFaceMatch,
    required this.offlineSync,
  });

  final bool maskedCall;
  final bool cashCollect;
  final bool documentScan;
  final bool custody;
  final bool shiftFaceMatch;
  final bool offlineSync;

  factory FieldFlags.fromJson(Map<String, dynamic> json) => FieldFlags(
        maskedCall: json['maskedCall'] == true,
        cashCollect: json['cashCollect'] == true,
        documentScan: json['documentScan'] == true,
        custody: json['custody'] == true,
        shiftFaceMatch: json['shiftFaceMatch'] == true,
        offlineSync: json['offlineSync'] == true,
      );
}

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.minAndroidBuild,
    required this.minIosBuild,
    required this.forceUpdate,
    required this.featureFlags,
    required this.publishedAt,
    this.storeUrlAndroid,
    this.storeUrlIos,
    this.supportPhone,
    this.opsPhone,
    this.geofenceDefaultRadiusMeters = 200,
    this.geofenceMaxAccuracyMeters = 100,
  });

  final String environment;
  final int minAndroidBuild;
  final int minIosBuild;
  final bool forceUpdate;
  final String? storeUrlAndroid;
  final String? storeUrlIos;
  final String? supportPhone;
  final String? opsPhone;
  final int geofenceDefaultRadiusMeters;
  final int geofenceMaxAccuracyMeters;
  final FieldFlags featureFlags;
  final String publishedAt;

  static const demo = AppConfig(
    environment: 'demo',
    minAndroidBuild: 1,
    minIosBuild: 1,
    forceUpdate: false,
    supportPhone: '+902124440026',
    opsPhone: '+902124440026',
    featureFlags: FieldFlags(
      maskedCall: false,
      cashCollect: true,
      documentScan: false,
      custody: false,
      shiftFaceMatch: false,
      offlineSync: true,
    ),
    publishedAt: '2026-08-25T17:00:00.000Z',
  );

  bool get isDemo => environment == 'demo';

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      environment: json['environment'] as String? ?? 'demo',
      minAndroidBuild: (json['minAndroidBuild'] as num?)?.toInt() ?? 1,
      minIosBuild: (json['minIosBuild'] as num?)?.toInt() ?? 1,
      forceUpdate: json['forceUpdate'] == true,
      storeUrlAndroid: json['storeUrlAndroid'] as String?,
      storeUrlIos: json['storeUrlIos'] as String?,
      supportPhone: json['supportPhone'] as String?,
      opsPhone: json['opsPhone'] as String?,
      geofenceDefaultRadiusMeters: (json['geofenceDefaultRadiusMeters'] as num?)?.toInt() ?? 200,
      geofenceMaxAccuracyMeters: (json['geofenceMaxAccuracyMeters'] as num?)?.toInt() ?? 100,
      featureFlags: FieldFlags.fromJson(Map<String, dynamic>.from(json['featureFlags'] as Map? ?? const {})),
      publishedAt: json['publishedAt'] as String? ?? DateTime.now().toUtc().toIso8601String(),
    );
  }
}

class SyncBatchResult {
  const SyncBatchResult({required this.clientEventId, required this.status});
  final String clientEventId;
  final String status;
}

class TokenPair {
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
    required this.refreshExpiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime accessExpiresAt;
  final DateTime refreshExpiresAt;
}

class WeekWindow {
  const WeekWindow({required this.weekday, required this.start, required this.end});

  final int weekday;
  final String start;
  final String end;

  factory WeekWindow.fromJson(Map<String, dynamic> json) => WeekWindow(
        weekday: (json['weekday'] as num?)?.toInt() ?? 1,
        start: json['start'] as String? ?? '09:00',
        end: json['end'] as String? ?? '18:00',
      );
}

const _weekdays = ['', 'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

String hoursFromWeekly(List<WeekWindow> weekly) {
  if (weekly.isEmpty) return '—';
  final first = weekly.first;
  final sameHours = weekly.every((w) => w.start == first.start && w.end == first.end);
  String label(int weekday) {
    final i = weekday < 1 ? 1 : (weekday > 7 ? 7 : weekday);
    return _weekdays[i];
  }

  if (sameHours && weekly.length >= 5) {
    return '${label(weekly.first.weekday)}–${label(weekly.last.weekday)} ${first.start}–${first.end}';
  }
  return [for (final w in weekly) '${label(w.weekday)} ${w.start}–${w.end}'].join(' · ');
}

class CourierAvailabilityDto {
  const CourierAvailabilityDto({
    required this.status,
    required this.vehicle,
    required this.employmentType,
    required this.city,
    required this.weekly,
    this.district,
    this.updatedAt,
  });

  final String status;
  final String vehicle;
  final String employmentType;
  final String city;
  final String? district;
  final List<WeekWindow> weekly;
  final String? updatedAt;

  String get vehicleLabel => switch (vehicle) {
        'CAR' => 'Otomobil',
        'MOTORCYCLE' => 'Motosiklet',
        'BICYCLE' => 'Bisiklet',
        'ON_FOOT' => 'Yaya',
        'VAN' => 'Van',
        _ => vehicle,
      };

  String get employmentLabel => switch (employmentType) {
        'FULL_TIME' => 'Tam zamanlı',
        'PART_TIME' => 'Yarı zamanlı',
        'SEASONAL' => 'Sezonluk',
        _ => employmentType,
      };

  String get statusLabel => switch (status) {
        'AVAILABLE' => 'Müsait',
        'UNAVAILABLE' => 'Müsait değil',
        'ON_SHIFT' => 'Vardiyada',
        'ON_BREAK' => 'Molada',
        _ => status,
      };

  String get hoursLabel => hoursFromWeekly(weekly);

  factory CourierAvailabilityDto.fromJson(Map<String, dynamic> json) {
    final raw = json['weekly'] as List? ?? const [];
    return CourierAvailabilityDto(
      status: json['status'] as String? ?? 'AVAILABLE',
      vehicle: json['vehicle'] as String? ?? 'CAR',
      employmentType: json['employmentType'] as String? ?? 'PART_TIME',
      city: json['city'] as String? ?? 'Denizli',
      district: json['district'] as String?,
      weekly: [
        for (final row in raw)
          if (row is Map) WeekWindow.fromJson(Map<String, dynamic>.from(row)),
      ],
      updatedAt: json['updatedAt'] as String?,
    );
  }
}

class CourierDocumentDto {
  const CourierDocumentDto({
    required this.id,
    required this.type,
    required this.label,
    required this.status,
  });

  final String id;
  final String type;
  final String label;
  final String status;

  factory CourierDocumentDto.fromJson(Map<String, dynamic> json) => CourierDocumentDto(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? 'OTHER',
        label: json['label'] as String? ?? json['type'] as String? ?? 'Belge',
        status: json['status'] as String? ?? 'PENDING',
      );
}

class RouteStopDto {
  const RouteStopDto({
    required this.taskId,
    required this.sequence,
    this.etaAt,
    this.distanceMeters,
    this.durationSeconds,
  });

  final String taskId;
  final int sequence;
  final String? etaAt;
  final int? distanceMeters;
  final int? durationSeconds;

  factory RouteStopDto.fromJson(Map<String, dynamic> json) => RouteStopDto(
        taskId: json['taskId'] as String? ?? '',
        sequence: (json['sequence'] as num?)?.toInt() ?? 0,
        etaAt: json['etaAt'] as String?,
        distanceMeters: (json['distanceMeters'] as num?)?.toInt(),
        durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      );
}

/// Mirrors `Route` in packages/contracts/src/shift.ts — the response shape
/// of `GET /v1/routes/current` (apps/api/src/routes/routing.ts).
class RoutePlanDto {
  const RoutePlanDto({
    required this.id,
    required this.mode,
    required this.stops,
    this.geometry,
    this.computedAt,
  });

  final String id;
  /// `sequence_only` (no real engine), `distance_optimized` (real OSRM
  /// distances, Faz 2 reordered) or `traffic_aware` (Faz 1.5, not built).
  final String mode;
  /// Encoded polyline (see lib/geo.dart#decodePolyline); null in sequence_only mode.
  final String? geometry;
  final String? computedAt;
  final List<RouteStopDto> stops;

  int get totalDistanceMeters => stops.fold(0, (sum, s) => sum + (s.distanceMeters ?? 0));
  int get totalDurationSeconds => stops.fold(0, (sum, s) => sum + (s.durationSeconds ?? 0));

  bool get hasRealGeometry => geometry != null && geometry!.isNotEmpty;

  factory RoutePlanDto.fromJson(Map<String, dynamic> json) {
    final raw = json['stops'] as List? ?? const [];
    return RoutePlanDto(
      id: json['id'] as String? ?? '',
      mode: json['mode'] as String? ?? 'sequence_only',
      geometry: json['geometry'] as String?,
      computedAt: json['computedAt'] as String?,
      stops: [
        for (final row in raw)
          if (row is Map) RouteStopDto.fromJson(Map<String, dynamic>.from(row)),
      ],
    );
  }
}

/// Mirrors `CustodyItem` in packages/contracts/src/custody.ts.
class CustodyItemDto {
  const CustodyItemDto({
    required this.id,
    required this.type,
    required this.description,
    required this.quantity,
    required this.acquiredAt,
    this.barcode,
    this.amount,
    this.taskId,
  });

  final String id;
  final String type;
  final String? barcode;
  final String description;
  final int quantity;
  final double? amount;
  final String? taskId;
  final String acquiredAt;

  factory CustodyItemDto.fromJson(Map<String, dynamic> json) => CustodyItemDto(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? 'parcel',
        barcode: json['barcode'] as String?,
        description: json['description'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        amount: (json['amount'] as num?)?.toDouble(),
        taskId: json['taskId'] as String?,
        acquiredAt: json['acquiredAt'] as String? ?? '',
      );
}

/// Mirrors `CustodyHandoverResponse` — result of `POST /v1/custody/handover`.
class CustodyHandoverResultDto {
  const CustodyHandoverResultDto({required this.handoverId, required this.remaining, required this.appliedAt});

  final String handoverId;
  final List<CustodyItemDto> remaining;
  final String appliedAt;

  factory CustodyHandoverResultDto.fromJson(Map<String, dynamic> json) {
    final raw = json['remaining'] as List? ?? const [];
    return CustodyHandoverResultDto(
      handoverId: json['handoverId'] as String? ?? '',
      remaining: [
        for (final row in raw)
          if (row is Map) CustodyItemDto.fromJson(Map<String, dynamic>.from(row)),
      ],
      appliedAt: json['appliedAt'] as String? ?? '',
    );
  }
}

class CourierDocumentListDto {
  const CourierDocumentListDto({
    required this.items,
    required this.completedCount,
    required this.requiredCount,
  });

  final List<CourierDocumentDto> items;
  final int completedCount;
  final int requiredCount;

  String get summary {
    final done = items.where((d) => d.status == 'COMPLETED').map((d) => d.label).toList();
    if (done.isEmpty) {
      if (requiredCount <= 0) return '—';
      return '$completedCount / $requiredCount belge';
    }
    if (completedCount >= requiredCount || done.length == items.length) {
      return '${done.join(' ve ')} tamam';
    }
    return '$completedCount / $requiredCount belge';
  }

  factory CourierDocumentListDto.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List? ?? const [];
    return CourierDocumentListDto(
      items: [
        for (final row in raw)
          if (row is Map) CourierDocumentDto.fromJson(Map<String, dynamic>.from(row)),
      ],
      completedCount: (json['completedCount'] as num?)?.toInt() ?? 0,
      requiredCount: (json['requiredCount'] as num?)?.toInt() ?? 0,
    );
  }
}
