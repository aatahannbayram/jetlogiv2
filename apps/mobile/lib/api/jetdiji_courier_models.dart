import '../models.dart';

double? jetdijiDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

int? jetdijiInt(dynamic value) => (value as num?)?.toInt();

class JetDijiCourierProfile {
  const JetDijiCourierProfile({
    required this.id,
    required this.courierCode,
    required this.fullName,
    this.email,
    this.phone,
  });

  final String id;
  final String courierCode;
  final String fullName;
  final String? email;
  final String? phone;

  factory JetDijiCourierProfile.fromJson(Map<String, dynamic> json) {
    return JetDijiCourierProfile(
      id: '${json['id'] ?? json['courierId'] ?? ''}',
      courierCode: json['courierCode'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
    );
  }
}

class JetDijiCourierLogin {
  const JetDijiCourierLogin({
    required this.accessToken,
    this.expiresAt,
    this.courier,
  });

  final String accessToken;
  final String? expiresAt;
  final JetDijiCourierProfile? courier;

  factory JetDijiCourierLogin.fromJson(Map<String, dynamic> json) {
    final nested = json['courier'];
    final profileJson = nested is Map
        ? Map<String, dynamic>.from(nested)
        : json;
    final hasProfile =
        profileJson['fullName'] != null ||
        profileJson['courierCode'] != null ||
        profileJson['id'] != null;
    return JetDijiCourierLogin(
      accessToken: json['accessToken'] as String? ?? '',
      expiresAt: json['expiresAt'] as String?,
      courier: hasProfile ? JetDijiCourierProfile.fromJson(profileJson) : null,
    );
  }
}

class JetDijiDashboardCounts {
  const JetDijiDashboardCounts({
    this.awaitingDelivery = 0,
    this.appointment = 0,
    this.outForDelivery = 0,
    this.overdue = 0,
    this.deliveredToday = 0,
    this.failedToday = 0,
    this.toReturnToBranch = 0,
    this.pendingCustody = 0,
  });

  final int awaitingDelivery;
  final int appointment;
  final int outForDelivery;
  final int overdue;
  final int deliveredToday;
  final int failedToday;
  final int toReturnToBranch;
  final int pendingCustody;

  factory JetDijiDashboardCounts.fromJson(Map<String, dynamic> json) {
    int n(String key) => jetdijiInt(json[key]) ?? 0;
    return JetDijiDashboardCounts(
      awaitingDelivery: n('awaitingDelivery'),
      appointment: n('appointment'),
      outForDelivery: n('outForDelivery'),
      overdue: n('overdue'),
      deliveredToday: n('deliveredToday'),
      failedToday: n('failedToday'),
      toReturnToBranch: n('toReturnToBranch'),
      pendingCustody: n('pendingCustody'),
    );
  }
}

class JetDijiDashboard {
  const JetDijiDashboard({required this.counts, this.generatedAt});

  final JetDijiDashboardCounts counts;
  final String? generatedAt;

  factory JetDijiDashboard.fromJson(Map<String, dynamic> json) {
    final counts = json['counts'];
    return JetDijiDashboard(
      counts: counts is Map
          ? JetDijiDashboardCounts.fromJson(Map<String, dynamic>.from(counts))
          : const JetDijiDashboardCounts(),
      generatedAt: json['generatedAt'] as String?,
    );
  }
}

class JetDijiDestination {
  const JetDijiDestination({
    this.address,
    this.latitude,
    this.longitude,
    this.districtName,
    this.usableForProximity = true,
  });

  final String? address;
  final String? latitude;
  final String? longitude;
  final String? districtName;
  final bool usableForProximity;

  factory JetDijiDestination.fromJson(Map<String, dynamic> json) {
    return JetDijiDestination(
      address: json['address'] as String?,
      latitude: json['latitude']?.toString(),
      longitude: json['longitude']?.toString(),
      districtName: json['districtName'] as String?,
      usableForProximity: json['usableForProximity'] as bool? ?? true,
    );
  }
}

class JetDijiTaskItem {
  const JetDijiTaskItem({
    required this.id,
    required this.shipmentNumber,
    required this.statusCode,
    this.externalReference,
    this.statusReasonCode,
    this.recipientName,
    this.recipientPhoneMasked,
    this.destination = const JetDijiDestination(),
    this.plannedDeliveryAt,
    this.createdAt,
    this.packageCount,
    this.customerDisplayName,
    this.inventoryTrackingCode,
    this.assignmentStatusCode,
  });

  final String id;
  final String shipmentNumber;
  final String? externalReference;
  final String statusCode;
  final String? statusReasonCode;
  final String? recipientName;
  final String? recipientPhoneMasked;
  final JetDijiDestination destination;
  final String? plannedDeliveryAt;
  final String? createdAt;
  final int? packageCount;
  final String? customerDisplayName;
  final String? inventoryTrackingCode;
  final String? assignmentStatusCode;

  factory JetDijiTaskItem.fromJson(Map<String, dynamic> json) {
    final dest = json['destination'];
    final customer = json['customer'];
    final product = json['product'];
    final assignment = json['assignment'];
    return JetDijiTaskItem(
      id: '${json['id'] ?? ''}',
      shipmentNumber: json['shipmentNumber'] as String? ?? '',
      externalReference: json['externalReference'] as String?,
      statusCode: json['statusCode'] as String? ?? '',
      statusReasonCode: json['statusReasonCode'] as String?,
      recipientName: json['recipientName'] as String?,
      recipientPhoneMasked: json['recipientPhoneMasked'] as String?,
      destination: dest is Map
          ? JetDijiDestination.fromJson(Map<String, dynamic>.from(dest))
          : const JetDijiDestination(),
      plannedDeliveryAt: json['plannedDeliveryAt'] as String?,
      createdAt: json['createdAt'] as String?,
      packageCount: jetdijiInt(json['packageCount']),
      customerDisplayName: customer is Map
          ? customer['displayName'] as String?
          : null,
      inventoryTrackingCode: product is Map
          ? product['inventoryTrackingCode'] as String?
          : null,
      assignmentStatusCode: assignment is Map
          ? assignment['statusCode'] as String?
          : null,
    );
  }
}

class JetDijiTaskList {
  const JetDijiTaskList({required this.tasks, this.statuses = const []});

  final List<JetDijiTaskItem> tasks;
  final List<String> statuses;

  factory JetDijiTaskList.fromJson(Map<String, dynamic> json) {
    final raw = json['tasks'];
    return JetDijiTaskList(
      tasks: [
        for (final row in raw is List ? raw : const [])
          if (row is Map)
            JetDijiTaskItem.fromJson(Map<String, dynamic>.from(row)),
      ],
      statuses: [
        for (final code in json['statuses'] is List ? json['statuses'] as List : const [])
          '$code',
      ],
    );
  }
}

class JetDijiReasonOption {
  const JetDijiReasonOption({required this.code, required this.name});

  final String code;
  final String name;

  factory JetDijiReasonOption.fromJson(Map<String, dynamic> json) {
    return JetDijiReasonOption(
      code: '${json['code'] ?? ''}',
      name: json['name'] as String? ?? '',
    );
  }
}

class JetDijiDeliveryReasons {
  const JetDijiDeliveryReasons({
    this.delivered = const [],
    this.failed = const [],
  });

  final List<JetDijiReasonOption> delivered;
  final List<JetDijiReasonOption> failed;

  factory JetDijiDeliveryReasons.fromJson(Map<String, dynamic> json) {
    List<JetDijiReasonOption> read(String key) {
      final raw = json[key];
      return [
        for (final row in raw is List ? raw : const [])
          if (row is Map)
            JetDijiReasonOption.fromJson(Map<String, dynamic>.from(row)),
      ];
    }

    return JetDijiDeliveryReasons(
      delivered: read('delivered'),
      failed: read('failed'),
    );
  }
}

class JetDijiPhotoRequirement {
  const JetDijiPhotoRequirement({
    required this.code,
    this.minCount = 1,
    this.label,
  });

  final String code;
  final int minCount;
  final String? label;

  factory JetDijiPhotoRequirement.fromJson(Map<String, dynamic> json) {
    return JetDijiPhotoRequirement(
      code: json['code'] as String? ?? '',
      minCount: jetdijiInt(json['minCount']) ?? 1,
      label: json['label'] as String?,
    );
  }
}

class JetDijiRequirements {
  const JetDijiRequirements({
    this.photos = const [],
    this.signatureRequired = false,
    this.otpRequired = false,
    this.formVersionId,
    this.formRequired = false,
  });

  final List<JetDijiPhotoRequirement> photos;
  final bool signatureRequired;
  final bool otpRequired;
  final String? formVersionId;
  final bool formRequired;

  factory JetDijiRequirements.fromJson(Map<String, dynamic> json) {
    final photos = json['photos'];
    final form = json['form'];
    return JetDijiRequirements(
      photos: [
        for (final row in photos is List ? photos : const [])
          if (row is Map)
            JetDijiPhotoRequirement.fromJson(Map<String, dynamic>.from(row)),
      ],
      signatureRequired: json['signatureRequired'] == true,
      otpRequired: json['otpRequired'] == true,
      formVersionId: form is Map ? form['formVersionId'] as String? : null,
      formRequired: form is Map && form['required'] == true,
    );
  }
}

class JetDijiOtpChallenge {
  const JetDijiOtpChallenge({
    required this.challengeId,
    this.devCode,
    this.channel,
    this.maskedPhone,
  });

  final String challengeId;
  final String? devCode;
  final String? channel;
  final String? maskedPhone;

  factory JetDijiOtpChallenge.fromJson(Map<String, dynamic> json) {
    return JetDijiOtpChallenge(
      challengeId: '${json['challengeId'] ?? ''}',
      devCode: json['devCode'] as String?,
      channel: json['channel'] as String?,
      maskedPhone: json['maskedPhone'] as String?,
    );
  }
}

class JetDijiOtpVerified {
  const JetDijiOtpVerified({required this.verified, this.evidenceId});

  final bool verified;
  final String? evidenceId;

  factory JetDijiOtpVerified.fromJson(Map<String, dynamic> json) {
    return JetDijiOtpVerified(
      verified: json['verified'] == true,
      evidenceId: json['evidenceId'] as String?,
    );
  }
}

class JetDijiFinalizeResult {
  const JetDijiFinalizeResult({
    required this.alreadyFinalized,
    this.resultCode,
    this.shipmentId,
  });

  final bool alreadyFinalized;
  final String? resultCode;
  final String? shipmentId;

  factory JetDijiFinalizeResult.fromJson(Map<String, dynamic> json) {
    return JetDijiFinalizeResult(
      alreadyFinalized: json['alreadyFinalized'] == true,
      resultCode: json['resultCode'] as String?,
      shipmentId: json['shipmentId'] as String?,
    );
  }
}

class JetDijiCity {
  const JetDijiCity({required this.id, required this.code, required this.name});

  final int id;
  final String code;
  final String name;

  factory JetDijiCity.fromJson(Map<String, dynamic> json) {
    return JetDijiCity(
      id: jetdijiInt(json['id']) ?? 0,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

class JetDijiDistrict {
  const JetDijiDistrict({
    required this.id,
    required this.cityId,
    required this.name,
    this.code,
  });

  final int id;
  final int cityId;
  final String name;
  final String? code;

  factory JetDijiDistrict.fromJson(Map<String, dynamic> json) {
    return JetDijiDistrict(
      id: jetdijiInt(json['id']) ?? 0,
      cityId: jetdijiInt(json['cityId']) ?? 0,
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
    );
  }
}

/// Sayısal gönderi kodu → saha durumu. Eski metin kodları yedek.
TaskStatus taskStatusFromJetdiji(String? code) {
  switch (code) {
    case '4010':
    case 'CREATED':
    case 'ASSIGNED':
    case 'PLANNED':
      return TaskStatus.assigned;
    case '4020':
    case '4021':
    case '4022':
    case 'OUT_FOR_DELIVERY':
    case 'IN_PROGRESS':
    case 'DELIVERY_STARTED':
      return TaskStatus.inProgress;
    case '5010':
    case '5020':
    case 'DELIVERED':
    case 'COMPLETED':
      return TaskStatus.delivered;
    case '5110':
    case 'FAILED':
    case 'DELIVERY_FAILED':
      return TaskStatus.failed;
    case '6010':
      return TaskStatus.queued;
    case '8010':
    case '8030':
    case 'CANCELLED':
      return TaskStatus.cancelled;
    default:
      if (code != null && code.startsWith('40')) return TaskStatus.assigned;
      if (code != null && code.startsWith('50')) return TaskStatus.delivered;
      if (code != null && code.startsWith('80')) return TaskStatus.cancelled;
      return TaskStatus.assigned;
  }
}

String _windowLabel(String? iso) {
  final t = DateTime.tryParse(iso ?? '');
  if (t == null) return '—';
  final local = t.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

int? _minutesUntil(String? iso) {
  final t = DateTime.tryParse(iso ?? '');
  if (t == null) return null;
  return t.difference(DateTime.now()).inMinutes;
}

DeliveryTask deliveryTaskFromJetdiji(JetDijiTaskItem row) {
  final dest = row.destination;
  final usable = dest.usableForProximity;
  final address = dest.address?.trim() ?? '';
  final ref = row.shipmentNumber.isNotEmpty
      ? row.shipmentNumber
      : (row.externalReference ?? '');
  return DeliveryTask(
    id: row.id,
    ref: ref,
    recipient: row.recipientName ?? '',
    address: address,
    window: _windowLabel(row.plannedDeliveryAt),
    kind: TaskKind.delivery,
    status: taskStatusFromJetdiji(row.statusCode),
    note: row.statusReasonCode,
    phone: row.recipientPhoneMasked,
    lat: usable ? (jetdijiDouble(dest.latitude) ?? 0) : 0,
    lng: usable ? (jetdijiDouble(dest.longitude) ?? 0) : 0,
    usableForProximity: usable,
    custodyCount: row.packageCount,
    custodyRef: row.inventoryTrackingCode,
    slaMinutesLeft: _minutesUntil(row.plannedDeliveryAt),
    groupKey: address.isNotEmpty ? address.toLowerCase() : 'id:${row.id}',
    wireStatus: row.statusCode,
    merchantName: row.customerDisplayName,
  );
}

JetDijiRequirements? requirementsFromDetail(Map<String, dynamic> detail) {
  final raw = detail['deliveryRequirements'];
  if (raw is! Map) return null;
  return JetDijiRequirements.fromJson(Map<String, dynamic>.from(raw));
}

String? lastCallFromDetail(Map<String, dynamic> detail) {
  final value = detail['lastRecipientCallAt'];
  if (value is String && value.isNotEmpty) return value;
  return null;
}
