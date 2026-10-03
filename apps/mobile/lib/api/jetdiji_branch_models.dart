class JetDijiBranchUser {
  const JetDijiBranchUser({
    required this.id,
    required this.fullName,
    this.email,
    this.agencyId,
    this.agencyName,
    this.operate = false,
    this.manage = false,
  });

  final String id;
  final String fullName;
  final String? email;
  final String? agencyId;
  final String? agencyName;
  final bool operate;
  final bool manage;

  factory JetDijiBranchUser.fromLogin(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : const <String, dynamic>{};
    final agency = json['agency'] is Map
        ? Map<String, dynamic>.from(json['agency'] as Map)
        : const <String, dynamic>{};
    final first = user['firstName'] as String? ?? '';
    final last = user['lastName'] as String? ?? '';
    return JetDijiBranchUser(
      id: '${user['id'] ?? ''}',
      fullName: ('$first $last').trim(),
      email: user['email'] as String?,
      agencyId: agency['id']?.toString(),
      agencyName: agency['name'] as String?,
    );
  }

  factory JetDijiBranchUser.fromSession(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : json;
    final agency = user['agency'] is Map
        ? Map<String, dynamic>.from(user['agency'] as Map)
        : const <String, dynamic>{};
    final caps = user['capabilities'] is Map
        ? Map<String, dynamic>.from(user['capabilities'] as Map)
        : const <String, dynamic>{};
    final name = user['fullName'] as String?;
    final first = user['firstName'] as String? ?? '';
    final last = user['lastName'] as String? ?? '';
    return JetDijiBranchUser(
      id: '${user['id'] ?? ''}',
      fullName: (name ?? '$first $last').trim(),
      email: user['email'] as String?,
      agencyId: agency['id']?.toString(),
      agencyName: agency['name'] as String?,
      operate: caps['operate'] == true,
      manage: caps['manage'] == true,
    );
  }
}

class JetDijiBranchLogin {
  const JetDijiBranchLogin({
    required this.accessToken,
    this.expiresAt,
    required this.user,
  });

  final String accessToken;
  final String? expiresAt;
  final JetDijiBranchUser user;

  factory JetDijiBranchLogin.fromJson(Map<String, dynamic> json) {
    return JetDijiBranchLogin(
      accessToken: json['accessToken'] as String? ?? '',
      expiresAt: json['expiresAt'] as String?,
      user: JetDijiBranchUser.fromLogin(json),
    );
  }
}

class JetDijiBranchKpis {
  const JetDijiBranchKpis({
    this.todayToDeliver = 0,
    this.deliveredToday = 0,
    this.cancelledToday = 0,
    this.pending = 0,
    this.returnToCenter = 0,
    this.urgent = 0,
    this.activeCouriers = 0,
    this.assigned = 0,
    this.unassigned = 0,
    this.inDistribution = 0,
  });

  final int todayToDeliver;
  final int deliveredToday;
  final int cancelledToday;
  final int pending;
  final int returnToCenter;
  final int urgent;
  final int activeCouriers;
  final int assigned;
  final int unassigned;
  final int inDistribution;

  /// Şube stok adedi bu API'de yok.
  static const stockLabel = '—';
}

class JetDijiBranchDashboard {
  const JetDijiBranchDashboard({
    required this.kpis,
    this.branchName,
    this.courierList = const [],
  });

  final JetDijiBranchKpis kpis;
  final String? branchName;
  final List<Map<String, dynamic>> courierList;

  factory JetDijiBranchDashboard.fromJson(Map<String, dynamic> json) {
    final kpis = json['kpis'] is Map
        ? Map<String, dynamic>.from(json['kpis'] as Map)
        : const <String, dynamic>{};
    final couriers = json['couriers'] is Map
        ? Map<String, dynamic>.from(json['couriers'] as Map)
        : const <String, dynamic>{};
    int n(String key) => (kpis[key] as num?)?.toInt() ?? 0;
    final list = json['courierList'];
    return JetDijiBranchDashboard(
      branchName: json['branch'] is Map
          ? (json['branch'] as Map)['name'] as String?
          : null,
      kpis: JetDijiBranchKpis(
        todayToDeliver: n('todayToDeliver'),
        deliveredToday: n('deliveredToday'),
        cancelledToday: n('cancelledToday'),
        pending: n('pending'),
        returnToCenter: n('returnToCenter'),
        urgent: n('urgent'),
        activeCouriers: (couriers['active'] as num?)?.toInt() ?? 0,
      ),
      courierList: [
        for (final row in list is List ? list : const [])
          if (row is Map) Map<String, dynamic>.from(row),
      ],
    );
  }

  JetDijiBranchDashboard withDispatch(Map<String, dynamic> dispatch) {
    final kpis = dispatch['kpis'] is Map
        ? Map<String, dynamic>.from(dispatch['kpis'] as Map)
        : const <String, dynamic>{};
    final rows = dispatch['rows'];
    var inDistribution = 0;
    if (rows is List) {
      for (final row in rows) {
        if (row is Map && row['stage'] == 'IN_DISTRIBUTION') inDistribution++;
      }
    }
    return JetDijiBranchDashboard(
      branchName: branchName,
      courierList: courierList,
      kpis: JetDijiBranchKpis(
        todayToDeliver: this.kpis.todayToDeliver,
        deliveredToday: this.kpis.deliveredToday,
        cancelledToday: this.kpis.cancelledToday,
        pending: this.kpis.pending,
        returnToCenter: this.kpis.returnToCenter,
        urgent: this.kpis.urgent,
        activeCouriers: this.kpis.activeCouriers,
        assigned: (kpis['assigned'] as num?)?.toInt() ?? 0,
        unassigned: (kpis['unassigned'] as num?)?.toInt() ?? 0,
        inDistribution: inDistribution,
      ),
    );
  }
}

class JetDijiShipmentRow {
  const JetDijiShipmentRow({
    required this.shipmentId,
    required this.shipmentNumber,
    this.stage,
    this.status,
    this.recipientName,
    this.late = false,
    this.priority,
    this.hasWindow = false,
    this.courierId,
    this.courierName,
  });

  final String shipmentId;
  final String shipmentNumber;
  final String? stage;
  final String? status;
  final String? recipientName;
  final bool late;
  final String? priority;
  final bool hasWindow;
  final String? courierId;
  final String? courierName;

  factory JetDijiShipmentRow.fromJson(Map<String, dynamic> json) {
    final courier = json['courier'];
    final window = json['window'];
    return JetDijiShipmentRow(
      shipmentId: '${json['shipmentId'] ?? ''}',
      shipmentNumber: json['shipmentNumber'] as String? ?? '',
      stage: json['stage'] as String?,
      status: json['status']?.toString(),
      recipientName: json['recipientName'] as String?,
      late: json['late'] == true,
      priority: json['priority'] as String?,
      hasWindow: window is Map,
      courierId: courier is Map ? courier['id']?.toString() : null,
      courierName: courier is Map ? courier['name'] as String? : null,
    );
  }
}

class JetDijiAgencyCourier {
  const JetDijiAgencyCourier({
    required this.assignmentId,
    required this.shipmentCount,
    required this.courierId,
    required this.fullName,
    this.courierCode,
    this.phone,
    this.email,
    this.status,
    this.workModel,
    this.vehicleType,
    this.cityName,
    this.districtName,
    this.isPrimary = false,
    this.assignmentTypeCode,
    this.statusCode,
    this.validFrom,
  });

  final String assignmentId;
  final int shipmentCount;
  final String courierId;
  final String fullName;
  final String? courierCode;
  final String? phone;
  final String? email;
  final String? status;
  final String? workModel;
  final String? vehicleType;
  final String? cityName;
  final String? districtName;
  final bool isPrimary;
  final String? assignmentTypeCode;
  final String? statusCode;
  final String? validFrom;

  factory JetDijiAgencyCourier.fromJson(Map<String, dynamic> json) {
    final courier = json['courier'] is Map
        ? Map<String, dynamic>.from(json['courier'] as Map)
        : const <String, dynamic>{};
    return JetDijiAgencyCourier(
      assignmentId: '${json['id'] ?? ''}',
      shipmentCount: (json['shipmentCount'] as num?)?.toInt() ?? 0,
      assignmentTypeCode: json['assignmentTypeCode'] as String?,
      isPrimary: json['isPrimary'] == true,
      statusCode: json['statusCode'] as String?,
      validFrom: json['validFrom'] as String?,
      courierId: '${courier['id'] ?? ''}',
      courierCode: courier['courierCode'] as String?,
      fullName: courier['fullName'] as String? ?? '',
      phone: courier['phone'] as String?,
      email: courier['email'] as String?,
      status: courier['status'] as String?,
      workModel: courier['workModel'] as String?,
      vehicleType: courier['vehicleType'] as String?,
      cityName: courier['cityName'] as String?,
      districtName: courier['districtName'] as String?,
    );
  }
}

class JetDijiMapShipment {
  const JetDijiMapShipment({
    required this.shipmentId,
    required this.shipmentNumber,
    this.statusCode,
    this.recipientName,
    this.overdue = false,
    this.resultMissing = false,
  });

  final String shipmentId;
  final String shipmentNumber;
  final String? statusCode;
  final String? recipientName;
  final bool overdue;
  final bool resultMissing;

  factory JetDijiMapShipment.fromJson(Map<String, dynamic> json) {
    return JetDijiMapShipment(
      shipmentId: '${json['shipmentId'] ?? ''}',
      shipmentNumber: json['shipmentNumber'] as String? ?? '',
      statusCode: json['statusCode'] as String?,
      recipientName: json['recipientName'] as String?,
      overdue: json['overdue'] == true,
      resultMissing: json['resultMissing'] == true,
    );
  }
}

class JetDijiMapCourier {
  const JetDijiMapCourier({
    required this.id,
    required this.name,
    this.code,
    this.phone,
    this.vehicleType,
    this.poolStatus,
    this.liveStatus,
    this.latitude,
    this.longitude,
    this.holdingCount = 0,
    this.overdueCount = 0,
    this.shipments = const [],
  });

  final String id;
  final String name;
  final String? code;
  final String? phone;
  final String? vehicleType;
  final String? poolStatus;
  final String? liveStatus;
  final double? latitude;
  final double? longitude;
  final int holdingCount;
  final int overdueCount;
  final List<JetDijiMapShipment> shipments;

  factory JetDijiMapCourier.fromJson(Map<String, dynamic> json) {
    final loc = json['location'];
    final shipments = json['shipments'];
    return JetDijiMapCourier(
      id: '${json['id'] ?? ''}',
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      phone: json['phone'] as String?,
      vehicleType: json['vehicleType'] as String?,
      poolStatus: json['poolStatus'] as String?,
      liveStatus: json['liveStatus'] as String?,
      latitude: loc is Map ? (loc['latitude'] as num?)?.toDouble() : null,
      longitude: loc is Map ? (loc['longitude'] as num?)?.toDouble() : null,
      holdingCount: (json['holdingCount'] as num?)?.toInt() ?? 0,
      overdueCount: (json['overdueCount'] as num?)?.toInt() ?? 0,
      shipments: [
        for (final row in shipments is List ? shipments : const [])
          if (row is Map)
            JetDijiMapShipment.fromJson(Map<String, dynamic>.from(row)),
      ],
    );
  }
}

class JetDijiCourierMap {
  const JetDijiCourierMap({
    this.couriers = const [],
    this.total = 0,
    this.withLocation = 0,
    this.shipmentsInHand = 0,
    this.overdue = 0,
  });

  final List<JetDijiMapCourier> couriers;
  final int total;
  final int withLocation;
  final int shipmentsInHand;
  final int overdue;

  factory JetDijiCourierMap.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] is Map
        ? Map<String, dynamic>.from(json['summary'] as Map)
        : const <String, dynamic>{};
    final couriers = json['couriers'];
    return JetDijiCourierMap(
      couriers: [
        for (final row in couriers is List ? couriers : const [])
          if (row is Map)
            JetDijiMapCourier.fromJson(Map<String, dynamic>.from(row)),
      ],
      total: (summary['total'] as num?)?.toInt() ?? 0,
      withLocation: (summary['withLocation'] as num?)?.toInt() ?? 0,
      shipmentsInHand: (summary['shipmentsInHand'] as num?)?.toInt() ?? 0,
      overdue: (summary['overdue'] as num?)?.toInt() ?? 0,
    );
  }
}

List<JetDijiShipmentRow> shipmentRowsOf(Map<String, dynamic> json) {
  final raw = json['rows'];
  return [
    for (final row in raw is List ? raw : const [])
      if (row is Map) JetDijiShipmentRow.fromJson(Map<String, dynamic>.from(row)),
  ];
}

/// `schemaReady: false` listeleri sahte kayıtla doldurulmaz.
List<Map<String, dynamic>> readyItems(Map<String, dynamic> json, String key) {
  if (json['schemaReady'] == false && key != 'operationalAlerts' && key != 'supportCases') {
    return const [];
  }
  final raw = json[key];
  return [
    for (final row in raw is List ? raw : const [])
      if (row is Map) Map<String, dynamic>.from(row),
  ];
}
