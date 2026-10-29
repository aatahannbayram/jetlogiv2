/// DTOs for the "Şube Mobil API" (`portal/v1/branch/*`, `portal/v1/agency/*`).
/// Field names mirror `swagger/branch.yaml` (v1.2.0) on
/// api-mobile.preprod.jetdiji.com one to one — nothing here is guessed from
/// a response shape, so a missing key means the server didn't send it.
library;

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};

List<Map<String, dynamic>> _list(Object? v) => [
  if (v is List)
    for (final row in v)
      if (row is Map) Map<String, dynamic>.from(row),
];

String _str(Map<String, dynamic> j, String key) {
  final v = j[key];
  return v is String ? v : '';
}

String? _strOrNull(Map<String, dynamic> j, String key) {
  final v = j[key];
  return v is String && v.isNotEmpty ? v : null;
}

int _int(Map<String, dynamic> j, String key) {
  final v = j[key];
  if (v is num) return v.toInt();
  if (v is String) return num.tryParse(v)?.toInt() ?? 0;
  return 0;
}

num? _numOrNull(Object? v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v);
  return null;
}

bool _bool(Map<String, dynamic> j, String key) => j[key] == true;

DateTime? _date(Map<String, dynamic> j, String key) {
  final v = j[key];
  return v is String ? DateTime.tryParse(v) : null;
}

/// `operate` = günlük operasyon, `manage` = yönetim. Düğmeler buna göre
/// açılır; sunucu yetkisiz istekte yine 403 `FORBIDDEN` döner.
class BranchCapabilities {
  const BranchCapabilities({this.operate = false, this.manage = false});

  final bool operate;
  final bool manage;

  static const all = BranchCapabilities(operate: true, manage: true);

  factory BranchCapabilities.fromJson(Object? json) {
    final j = _map(json);
    return BranchCapabilities(
      operate: _bool(j, 'operate'),
      manage: _bool(j, 'manage'),
    );
  }
}

class CourierRef {
  const CourierRef({required this.id, required this.name, this.code = ''});

  final String id;
  final String name;
  final String code;

  static CourierRef? fromJson(Object? json) {
    if (json is! Map) return null;
    final j = _map(json);
    final id = _str(j, 'id');
    if (id.isEmpty) return null;
    return CourierRef(id: id, name: _str(j, 'name'), code: _str(j, 'code'));
  }
}

/// `liveStatus`: ACTIVE | BREAK | OFFLINE.
class BranchCourierLive {
  const BranchCourierLive({
    required this.id,
    required this.name,
    this.code = '',
    this.vehicleType = '',
    this.liveStatus = 'OFFLINE',
    this.lastSeenAt,
    this.holdingCount = 0,
    this.overdueCount = 0,
    this.latitude,
    this.longitude,
    this.phone,
    this.poolStatus = '',
  });

  /// Kurye telefonu (maskesiz; courier-map ve dashboard).
  final String? phone;

  /// Havuz durumu (AVAILABLE, WORKING …).
  final String poolStatus;

  /// Kuryenin telefonundan gelen son konum; hiç gelmediyse null.
  final double? latitude;
  final double? longitude;
  bool get located => latitude != null && longitude != null;

  final String id;
  final String name;
  final String code;
  final String vehicleType;
  final String liveStatus;
  final DateTime? lastSeenAt;
  final int holdingCount;
  final int overdueCount;

  factory BranchCourierLive.fromJson(Map<String, dynamic> j) =>
      BranchCourierLive(
        id: _str(j, 'id'),
        name: _str(j, 'name'),
        code: _str(j, 'code'),
        vehicleType: _str(j, 'vehicleType'),
        liveStatus: _strOrNull(j, 'liveStatus') ?? 'OFFLINE',
        lastSeenAt: _date(j, 'lastSeenAt'),
        holdingCount: _int(j, 'holdingCount'),
        overdueCount: _int(j, 'overdueCount'),
        latitude: _coord(j['location'], 'latitude'),
        longitude: _coord(j['location'], 'longitude'),
        phone: _strOrNull(j, 'phone'),
        poolStatus: _str(j, 'poolStatus'),
      );
}

/// Kurye haritasında kuryenin elindeki gönderi.
class MapShipment {
  const MapShipment({
    required this.shipmentId,
    required this.shipmentNumber,
    this.statusCode = '',
    this.recipientName = '',
    this.product = '',
    this.district = '',
    this.since,
    this.resultMissing = false,
    this.overdue = false,
  });

  final String shipmentId;
  final String shipmentNumber;
  final String statusCode;
  final String recipientName;
  final String product;
  final String district;
  final DateTime? since;
  final bool resultMissing;
  final bool overdue;

  factory MapShipment.fromJson(Map<String, dynamic> j) => MapShipment(
    shipmentId: _str(j, 'shipmentId'),
    shipmentNumber: _str(j, 'shipmentNumber'),
    statusCode: _str(j, 'statusCode'),
    recipientName: _str(j, 'recipientName'),
    product: _str(j, 'product'),
    district: _str(j, 'district'),
    since: _date(j, 'since'),
    resultMissing: _bool(j, 'resultMissing'),
    overdue: _bool(j, 'overdue'),
  );
}

/// GET branch/courier-map: son 24 saatte konum veren kuryeler ve ellerindeki
/// gönderiler. `liveStatus` konum yaşıdır (BREAK = 10-60 dk), gerçek mola
/// değildir; mola vardiya verisinden okunur.
class CourierMapData {
  const CourierMapData({this.couriers = const [], this.generatedAt});

  final List<({BranchCourierLive courier, List<MapShipment> shipments})>
  couriers;
  final DateTime? generatedAt;

  factory CourierMapData.fromJson(Map<String, dynamic> j) => CourierMapData(
    couriers: [
      for (final row in _list(j['couriers']))
        (
          courier: BranchCourierLive.fromJson(row),
          shipments: [
            for (final s in _list(row['shipments'])) MapShipment.fromJson(s),
          ],
        ),
    ],
    generatedAt: _date(j, 'generatedAt'),
  );
}

/// Kurye önerisi (courier-jobs detail.suggestions): bölge uyumu, aktif iş,
/// tahmini varış.
class CourierSuggestion {
  const CourierSuggestion({
    required this.id,
    required this.name,
    this.code = '',
    this.status = '',
    this.vehicleType = '',
    this.area = '',
    this.regionFit = 'NONE',
    this.activeJobs = 0,
    this.todayJobs = 0,
    this.etaMinutes,
    this.overdueHoldings = 0,
  });

  final String id;
  final String name;
  final String code;
  final String status;
  final String vehicleType;
  final String area;
  final String regionFit;
  final int activeJobs;
  final int todayJobs;
  final int? etaMinutes;
  final int overdueHoldings;

  factory CourierSuggestion.fromJson(Map<String, dynamic> j) =>
      CourierSuggestion(
        id: _str(j, 'id'),
        name: _str(j, 'name'),
        code: _str(j, 'code'),
        status: _str(j, 'status'),
        vehicleType: _str(j, 'vehicleType'),
        area: _str(j, 'area'),
        regionFit: _strOrNull(j, 'regionFit') ?? 'NONE',
        activeJobs: _int(j, 'activeJobs'),
        todayJobs: _int(j, 'todayJobs'),
        etaMinutes: j['etaMinutes'] is num
            ? (j['etaMinutes'] as num).toInt()
            : null,
        overdueHoldings: _int(j, 'overdueHoldings'),
      );
}

/// Gönderi olayı ya da şube paneli audit kaydı (en fazla 12).
class ShipmentEvent {
  const ShipmentEvent({
    required this.code,
    this.statusCode,
    this.reasonCode,
    this.source,
    this.actor,
    this.at,
  });

  final String code;
  final String? statusCode;
  final String? reasonCode;
  final String? source;
  final String? actor;
  final DateTime? at;

  factory ShipmentEvent.fromJson(Map<String, dynamic> j) => ShipmentEvent(
    code: _str(j, 'code'),
    statusCode: _strOrNull(j, 'statusCode'),
    reasonCode: _strOrNull(j, 'reasonCode'),
    source: _strOrNull(j, 'source'),
    actor: _strOrNull(j, 'actor'),
    at: _date(j, 'at'),
  );
}

/// GET branch/courier-jobs?shipmentId=: tek gönderinin detayı, açık
/// aksiyonlar, kurye önerileri ve son hareketler. Alıcı telefonu, müşteri,
/// not ve SLA bu uçta yok.
class ShipmentDetail {
  const ShipmentDetail({
    required this.row,
    this.weightKg,
    this.packageType,
    this.dispatchReady = false,
    this.canAssign = false,
    this.canChange = false,
    this.canCancel = false,
    this.suggestions = const [],
    this.recent = const [],
  });

  final BranchShipmentRow row;
  final num? weightKg;
  final String? packageType;
  final bool dispatchReady;
  final bool canAssign;
  final bool canChange;
  final bool canCancel;
  final List<CourierSuggestion> suggestions;
  final List<ShipmentEvent> recent;

  static ShipmentDetail? fromJson(Map<String, dynamic> data) {
    final detail = _map(data['detail']);
    final shipment = _map(detail['shipment']);
    if (shipment.isEmpty) return null;
    final actions = _map(detail['actions']);
    return ShipmentDetail(
      row: BranchShipmentRow.fromJson(shipment),
      weightKg: _numOrNull(shipment['weightKg']),
      packageType: _strOrNull(shipment, 'packageType'),
      dispatchReady: _bool(shipment, 'dispatchReady'),
      canAssign: _bool(actions, 'assign'),
      canChange: _bool(actions, 'change'),
      canCancel: _bool(actions, 'cancel'),
      suggestions: [
        for (final row in _list(detail['suggestions']))
          CourierSuggestion.fromJson(row),
      ],
      recent: [
        for (final row in _list(data['recent'] ?? detail['recent']))
          ShipmentEvent.fromJson(row),
      ],
    );
  }
}

double? _coord(Object? location, String key) {
  if (location is! Map) return null;
  final v = location[key];
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

class BranchDashboard {
  const BranchDashboard({
    this.branchName = '',
    this.branchCode = '',
    this.couriersActive = 0,
    this.couriersTotal = 0,
    this.todayToDeliver = 0,
    this.deliveredToday = 0,
    this.cancelledToday = 0,
    this.pending = 0,
    this.returnToCenter = 0,
    this.urgent = 0,
    this.approvalsHandover = 0,
    this.approvalsReturns = 0,
    this.courierList = const [],
    this.generatedAt,
  });

  final String branchName;

  /// Şube kodu (`branch.code`); sunucu vermezse boş.
  final String branchCode;
  final int couriersActive;
  final int couriersTotal;
  final int todayToDeliver;
  final int deliveredToday;
  final int cancelledToday;
  final int pending;
  final int returnToCenter;
  final int urgent;
  final int approvalsHandover;
  final int approvalsReturns;
  final List<BranchCourierLive> courierList;
  final DateTime? generatedAt;

  factory BranchDashboard.fromJson(Map<String, dynamic> j) {
    final couriers = _map(j['couriers']);
    final kpis = _map(j['kpis']);
    final approvals = _map(j['approvals']);
    return BranchDashboard(
      branchName: _str(_map(j['branch']), 'name'),
      branchCode: _str(_map(j['branch']), 'code'),
      couriersActive: _int(couriers, 'active'),
      couriersTotal: _int(couriers, 'total'),
      todayToDeliver: _int(kpis, 'todayToDeliver'),
      deliveredToday: _int(kpis, 'deliveredToday'),
      cancelledToday: _int(kpis, 'cancelledToday'),
      pending: _int(kpis, 'pending'),
      returnToCenter: _int(kpis, 'returnToCenter'),
      urgent: _int(kpis, 'urgent'),
      approvalsHandover: _int(approvals, 'handover'),
      approvalsReturns: _int(approvals, 'returns'),
      courierList: [
        for (final row in _list(j['courierList']))
          BranchCourierLive.fromJson(row),
      ],
      generatedAt: _date(j, 'generatedAt'),
    );
  }
}

/// Şubedeki gönderinin aşaması. `inQueue` = kuryeye zimmetlendi, kurye
/// henüz okutup kabul etmedi; `inDistribution` = kurye kabul etti (4020).
enum BranchStage { incoming, awaitingCourier, inQueue, inDistribution }

BranchStage _stage(String wire) => switch (wire) {
  'INCOMING' => BranchStage.incoming,
  'IN_QUEUE' => BranchStage.inQueue,
  'IN_DISTRIBUTION' => BranchStage.inDistribution,
  _ => BranchStage.awaitingCourier,
};

class BranchShipmentRow {
  const BranchShipmentRow({
    required this.shipmentId,
    required this.shipmentNumber,
    this.stage = BranchStage.awaitingCourier,
    this.status = '',
    this.recipientName = '',
    this.district = '',
    this.addressLine = '',
    this.product = '',
    this.highPriority = false,
    this.late = false,
    this.courier,
    this.pendingCourierName,
    this.packageCount = 0,
    this.windowStart,
    this.windowEnd,
    this.city = '',
    this.neighborhood = '',
    this.productCode = '',
    this.reasonCode,
    this.dispatches = 0,
    this.maxDispatches,
    this.productMatched,
    this.plannedDeliveryAt,
  });

  final String city;
  final String neighborhood;
  final String productCode;

  /// Son durum nedeni (ör. teslim edilemedi nedeni).
  final String? reasonCode;

  /// Dağıtıma çıkış sayısı ve üst sınırı.
  final int dispatches;
  final int? maxDispatches;
  final bool? productMatched;
  final DateTime? plannedDeliveryAt;

  final String shipmentId;
  final String shipmentNumber;
  final BranchStage stage;
  final String status;
  final String recipientName;
  final String district;
  final String addressLine;
  final String product;
  final bool highPriority;
  final bool late;
  final CourierRef? courier;

  /// Kabul bekleyen zimmetin kuryesi (`handover.courierName`).
  final String? pendingCourierName;
  final int packageCount;
  final DateTime? windowStart;
  final DateTime? windowEnd;

  String get courierName => courier?.name ?? pendingCourierName ?? '';
  bool get booked => windowStart != null;

  factory BranchShipmentRow.fromJson(Map<String, dynamic> j) {
    final window = _map(j['window']);
    return BranchShipmentRow(
      shipmentId: _str(j, 'shipmentId'),
      shipmentNumber: _str(j, 'shipmentNumber'),
      stage: _stage(_str(j, 'stage')),
      status: _str(j, 'status'),
      recipientName: _str(j, 'recipientName'),
      district: _str(j, 'district'),
      addressLine: _str(j, 'addressLine'),
      product: _str(j, 'product'),
      highPriority: _str(j, 'priority') == 'HIGH',
      late: _bool(j, 'late'),
      courier: CourierRef.fromJson(j['courier']),
      pendingCourierName: _strOrNull(_map(j['handover']), 'courierName'),
      packageCount: _int(j, 'packageCount'),
      windowStart: _date(window, 'start'),
      windowEnd: _date(window, 'end'),
      city: _str(j, 'city'),
      neighborhood: _str(j, 'neighborhood'),
      productCode: _str(j, 'productCode'),
      reasonCode: _strOrNull(j, 'reasonCode'),
      dispatches: _int(j, 'dispatches'),
      maxDispatches: j['maxDispatches'] is num
          ? (j['maxDispatches'] as num).toInt()
          : null,
      productMatched: j['productMatched'] is bool
          ? j['productMatched'] as bool
          : null,
      plannedDeliveryAt: _date(j, 'plannedDeliveryAt'),
    );
  }
}

class DispatchKpis {
  const DispatchKpis({
    this.total = 0,
    this.assigned = 0,
    this.unassigned = 0,
    this.late = 0,
    this.priority = 0,
    this.dispatchedToday = 0,
    this.overdueHoldings = 0,
  });

  final int total;
  final int assigned;
  final int unassigned;
  final int late;
  final int priority;
  final int dispatchedToday;
  final int overdueHoldings;

  factory DispatchKpis.fromJson(Object? json) {
    final j = _map(json);
    return DispatchKpis(
      total: _int(j, 'total'),
      assigned: _int(j, 'assigned'),
      unassigned: _int(j, 'unassigned'),
      late: _int(j, 'late'),
      priority: _int(j, 'priority'),
      dispatchedToday: _int(j, 'dispatchedToday'),
      overdueHoldings: _int(j, 'overdueHoldings'),
    );
  }
}

class DispatchBoard {
  const DispatchBoard({
    this.kpis = const DispatchKpis(),
    this.rows = const [],
    this.capabilities = const BranchCapabilities(),
  });

  final DispatchKpis kpis;
  final List<BranchShipmentRow> rows;
  final BranchCapabilities capabilities;

  factory DispatchBoard.fromJson(Map<String, dynamic> j) => DispatchBoard(
    kpis: DispatchKpis.fromJson(j['kpis']),
    rows: [for (final row in _list(j['rows'])) BranchShipmentRow.fromJson(row)],
    capabilities: BranchCapabilities.fromJson(j['capabilities']),
  );
}

class CourierOption {
  const CourierOption({
    required this.id,
    required this.name,
    this.code = '',
    this.status = '',
    this.eligible = true,
  });

  final String id;
  final String name;
  final String code;
  final String status;

  /// Kuryenin bölgesi gönderinin ilçesine uyuyor mu. `dispatch/reassign`
  /// listesinde alan yoktur; orada hepsi seçilebilir kabul edilir.
  final bool eligible;

  factory CourierOption.fromJson(Map<String, dynamic> j) => CourierOption(
    id: _str(j, 'id'),
    name: _str(j, 'name'),
    code: _str(j, 'code'),
    status: _str(j, 'status'),
    eligible: j['eligible'] != false,
  );
}

class DispatchOptions {
  const DispatchOptions({
    this.ready = true,
    this.branchEligible = true,
    this.couriers = const [],
  });

  /// false ise atama `DISPATCH_NOT_READY` ile reddedilir.
  final bool ready;
  final bool branchEligible;
  final List<CourierOption> couriers;

  factory DispatchOptions.fromJson(Map<String, dynamic> j) => DispatchOptions(
    ready: j['ready'] != false,
    branchEligible: j['branchEligible'] != false,
    couriers: [
      for (final row in _list(j['couriers'])) CourierOption.fromJson(row),
    ],
  );
}

class ReasonOption {
  const ReasonOption({required this.code, required this.name});

  final String code;
  final String name;

  factory ReasonOption.fromJson(Map<String, dynamic> j) =>
      ReasonOption(code: _str(j, 'code'), name: _str(j, 'name'));
}

class HandoverResult {
  const HandoverResult({this.transferNumber = '', this.replayed = false});

  final String transferNumber;
  final bool replayed;

  factory HandoverResult.fromJson(Map<String, dynamic> j) => HandoverResult(
    transferNumber: _str(j, 'transferNumber'),
    replayed: _bool(j, 'replayed'),
  );
}

class PendingItem {
  const PendingItem({
    required this.shipmentId,
    required this.shipmentNumber,
    this.recipientName = '',
    this.courierName = '',
    this.since,
    this.overdue = false,
    this.resultMissing = false,
  });

  final String shipmentId;
  final String shipmentNumber;
  final String recipientName;
  final String courierName;
  final DateTime? since;
  final bool overdue;

  /// Yalnız gün sonu / geciken kuyruğunda: kurye sonuç girmemiş.
  final bool resultMissing;

  factory PendingItem.fromJson(Map<String, dynamic> j) => PendingItem(
    shipmentId: _str(j, 'shipmentId'),
    shipmentNumber: _str(j, 'shipmentNumber'),
    recipientName: _str(j, 'recipientName'),
    courierName: CourierRef.fromJson(j['courier'])?.name ?? '',
    since: _date(j, 'since'),
    overdue: _bool(j, 'overdue'),
    resultMissing: _bool(j, 'resultMissing'),
  );
}

/// `GET branch/pending` — B13 bekleyen işlem kuyrukları.
class PendingData {
  const PendingData({
    this.handovers = const [],
    this.returns = const [],
    this.endOfDay = const [],
    this.overdue = const [],
    this.total = 0,
    this.generatedAt,
  });

  /// Kuryenin kabulünü bekleyen zimmetler.
  final List<PendingItem> handovers;

  /// Kuryeden şubeye dönüşü beklenenler.
  final List<PendingItem> returns;
  final List<PendingItem> endOfDay;
  final List<PendingItem> overdue;
  final int total;
  final DateTime? generatedAt;

  factory PendingData.fromJson(Map<String, dynamic> j) {
    List<PendingItem> items(String key) => [
      for (final row in _list(j[key])) PendingItem.fromJson(row),
    ];
    return PendingData(
      handovers: items('handovers'),
      returns: items('returns'),
      endOfDay: items('endOfDay'),
      overdue: items('overdue'),
      total: _int(_map(j['counts']), 'total'),
      generatedAt: _date(j, 'generatedAt'),
    );
  }
}

class CourierReturnScanResult {
  const CourierReturnScanResult({
    this.shipmentNumber = '',
    this.redeliveryApplied = false,
    this.replayed = false,
  });

  final String shipmentNumber;

  /// true: gönderi otomatik olarak yeniden dağıtım kuyruğuna alındı.
  final bool redeliveryApplied;
  final bool replayed;

  factory CourierReturnScanResult.fromJson(Map<String, dynamic> j) =>
      CourierReturnScanResult(
        shipmentNumber: _str(j, 'shipmentNumber'),
        redeliveryApplied: _bool(_map(j['redelivery']), 'applied'),
        replayed: _bool(j, 'replayed'),
      );
}

class BranchWarehouse {
  const BranchWarehouse({required this.id, required this.name, this.code = ''});

  final String id;
  final String name;
  final String code;

  factory BranchWarehouse.fromJson(Map<String, dynamic> j) => BranchWarehouse(
    id: _str(j, 'id'),
    name: _str(j, 'name'),
    code: _str(j, 'code'),
  );
}

/// `statusCode`: DRAFT | IN_PROGRESS | REVIEW | POSTED | CANCELLED.
class StockCount {
  const StockCount({
    required this.id,
    this.number = '',
    this.typeCode = 'FULL',
    this.statusCode = '',
    this.warehouseName = '',
    this.varianceLineCount = 0,
    this.startedAt,
  });

  final String id;
  final String number;
  final String typeCode;
  final String statusCode;
  final String warehouseName;
  final int varianceLineCount;
  final DateTime? startedAt;

  /// Okutma kabul eden durum.
  bool get scannable => statusCode == 'DRAFT' || statusCode == 'IN_PROGRESS';
  bool get open => scannable || statusCode == 'REVIEW';

  factory StockCount.fromJson(Map<String, dynamic> j) => StockCount(
    id: _str(j, 'id'),
    number: _str(j, 'number'),
    typeCode: _strOrNull(j, 'countTypeCode') ?? 'FULL',
    statusCode: _str(j, 'statusCode'),
    warehouseName: _str(_map(j['warehouse']), 'name'),
    varianceLineCount: _int(j, 'varianceLineCount'),
    startedAt: _date(j, 'startedAt'),
  );
}

class CountsData {
  const CountsData({
    this.warehouses = const [],
    this.capabilities = const BranchCapabilities(),
    this.reasonCodes = const [],
    this.openCount,
    this.counts = const [],
  });

  final List<BranchWarehouse> warehouses;
  final BranchCapabilities capabilities;

  /// MISCOUNT | DAMAGE | LOSS | RECORD_ERROR | FOUND | RETURN_PENDING | OTHER.
  final List<String> reasonCodes;
  final StockCount? openCount;
  final List<StockCount> counts;

  factory CountsData.fromJson(Map<String, dynamic> j) => CountsData(
    warehouses: [
      for (final row in _list(j['warehouses'])) BranchWarehouse.fromJson(row),
    ],
    capabilities: BranchCapabilities.fromJson(j['capabilities']),
    reasonCodes: [
      for (final code in j['reasonCodes'] as List? ?? const [])
        if (code is String) code,
    ],
    openCount: j['openCount'] is Map
        ? StockCount.fromJson(_map(j['openCount']))
        : null,
    counts: [for (final row in _list(j['counts'])) StockCount.fromJson(row)],
  );
}

/// Sayım satırı: sistem stoğu / sayılan / fark. Swagger satır alanlarını
/// ayrıntılandırmıyor ("admin sayım detayıyla aynı", `additionalProperties`),
/// bu yüzden adet alanları bilinen adaylardan okunur; hiçbiri yoksa null
/// kalır ve ekranda "—" görünür — sayı uydurulmaz.
class CountLine {
  const CountLine({
    required this.id,
    this.name = '',
    this.expected,
    this.counted,
    this.variance,
    this.reasonCode,
  });

  final String id;
  final String name;
  final num? expected;
  final num? counted;
  final num? variance;
  final String? reasonCode;

  num? get difference {
    if (variance != null) return variance;
    if (expected == null || counted == null) return null;
    return counted! - expected!;
  }

  factory CountLine.fromJson(Map<String, dynamic> j) {
    num? pick(List<String> keys) {
      for (final key in keys) {
        final v = _numOrNull(j[key]);
        if (v != null) return v;
      }
      return null;
    }

    final product = _map(j['product']);
    return CountLine(
      id: _str(j, 'id'),
      name:
          _strOrNull(j, 'productName') ??
          _strOrNull(product, 'name') ??
          _strOrNull(j, 'name') ??
          _strOrNull(j, 'sku') ??
          _str(j, 'barcode'),
      expected: pick(const ['expectedQuantity', 'systemQuantity', 'expected']),
      counted: pick(const ['countedQuantity', 'physicalQuantity', 'counted']),
      variance: pick(const ['varianceQuantity', 'variance', 'difference']),
      reasonCode: _strOrNull(j, 'reasonCode'),
    );
  }
}

class CountDetail {
  const CountDetail({
    required this.count,
    this.lines = const [],
    this.capabilities = const BranchCapabilities(),
  });

  final StockCount count;
  final List<CountLine> lines;
  final BranchCapabilities capabilities;

  List<CountLine> get varianceLines => [
    for (final line in lines)
      if ((line.difference ?? 0) != 0) line,
  ];

  factory CountDetail.fromJson(Map<String, dynamic> j) => CountDetail(
    count: StockCount.fromJson(_map(j['count'])),
    lines: [for (final row in _list(j['lines'])) CountLine.fromJson(row)],
    capabilities: BranchCapabilities.fromJson(j['capabilities']),
  );
}

/// `resultCode`: OK | UNKNOWN_BARCODE | OUT_OF_SCOPE | DUPLICATE_SERIAL |
/// DUPLICATE_CONTAINER | NOT_IN_STOCK | WRONG_WAREHOUSE | CONTAINER_MISMATCH |
/// SEALED_ACCEPTED …
class CountScanResult {
  const CountScanResult({
    this.scanId = '',
    this.resultCode = 'OK',
    this.itemName = '',
    this.replayed = false,
  });

  final String scanId;
  final String resultCode;
  final String itemName;
  final bool replayed;

  bool get counted => resultCode == 'OK' || resultCode.startsWith('SEALED_');
  bool get duplicate => resultCode.startsWith('DUPLICATE_');

  factory CountScanResult.fromJson(Map<String, dynamic> j) {
    final item = _map(j['item']);
    return CountScanResult(
      scanId: _str(j, 'scanId'),
      resultCode: _strOrNull(j, 'resultCode') ?? 'OK',
      itemName:
          _strOrNull(item, 'productName') ??
          _strOrNull(item, 'name') ??
          _str(item, 'barcode'),
      replayed: _bool(j, 'replayed'),
    );
  }
}

class TransferCenter {
  const TransferCenter({required this.id, required this.name, this.code = ''});

  final String id;
  final String name;
  final String code;

  factory TransferCenter.fromJson(Map<String, dynamic> j) => TransferCenter(
    id: _str(j, 'id'),
    name: _str(j, 'name'),
    code: _str(j, 'code'),
  );
}

/// Hem merkeze giden son transferler hem gelen transferler için özet satır.
class BranchTransfer {
  const BranchTransfer({
    required this.id,
    required this.transferNumber,
    this.statusCode = '',
    this.type = '',
    this.partyName = '',
    this.itemCount = 0,
    this.acceptedItemCount = 0,
    this.dispatchedAt,
  });

  final String id;
  final String transferNumber;
  final String statusCode;
  final String type;

  /// Giden transferde hedef, gelen transferde kaynak birim.
  final String partyName;
  final int itemCount;
  final int acceptedItemCount;
  final DateTime? dispatchedAt;

  factory BranchTransfer.outgoing(Map<String, dynamic> j) => BranchTransfer(
    id: _str(j, 'id'),
    transferNumber: _str(j, 'transferNumber'),
    statusCode: _str(j, 'statusCode'),
    type: _str(j, 'branchTransferType'),
    partyName: _str(j, 'destinationName'),
    itemCount: _int(j, 'itemCount'),
    acceptedItemCount: _int(j, 'acceptedItemCount'),
    dispatchedAt: _date(j, 'dispatchedAt'),
  );

  factory BranchTransfer.incoming(Map<String, dynamic> j) => BranchTransfer(
    id: _str(j, 'id'),
    transferNumber: _str(j, 'transferNumber'),
    statusCode: _str(j, 'statusCode'),
    type: _strOrNull(j, 'branchTransferType') ?? _str(j, 'transferTypeCode'),
    partyName: _str(_map(j['origin']), 'name'),
    itemCount: _int(j, 'itemCount'),
    acceptedItemCount: _int(j, 'acceptedItemCount'),
    dispatchedAt: _date(j, 'dispatchedAt'),
  );
}

class OutgoingOptions {
  const OutgoingOptions({
    this.transferTypes = const [],
    this.centers = const [],
    this.recent = const [],
  });

  /// RETURN | EQUIPMENT | PHYSICAL_DOCUMENT | CARD_RETURN | BRANCH_TRANSFER |
  /// OTHER.
  final List<String> transferTypes;
  final List<TransferCenter> centers;
  final List<BranchTransfer> recent;

  factory OutgoingOptions.fromJson(Map<String, dynamic> j) => OutgoingOptions(
    transferTypes: [
      for (final t in j['transferTypes'] as List? ?? const [])
        if (t is String) t,
    ],
    centers: [
      for (final row in _list(j['centers'])) TransferCenter.fromJson(row),
    ],
    recent: [
      for (final row in _list(j['recent'])) BranchTransfer.outgoing(row),
    ],
  );
}

/// `transfers/outgoing/resolve` sonucu: transfere eklenebilecek gönderi
/// (`isPackage == false`) ya da koli/paket etiketi.
class DispatchCandidate {
  const DispatchCandidate({
    required this.barcode,
    this.isPackage = false,
    this.shipmentId = '',
    this.shipmentNumber = '',
    this.product = '',
    this.sourceKey = '',
  });

  final String barcode;
  final bool isPackage;
  final String shipmentId;
  final String shipmentNumber;
  final String product;

  /// Zimmet kaynağı; aynı transferdeki tüm gönderilerde aynı olmalı.
  final String sourceKey;

  /// Taslağın cihazda saklanan biçimi; [DispatchCandidate.fromJson] ile
  /// geri okunur.
  Map<String, dynamic> toJson() => {
    'kind': isPackage ? 'PACKAGE' : 'SHIPMENT',
    'barcode': barcode,
    'sourceKey': sourceKey,
    'shipment': {
      'id': shipmentId,
      'shipmentNumber': shipmentNumber,
      'product': product,
    },
  };

  factory DispatchCandidate.fromJson(Map<String, dynamic> j) {
    final shipment = _map(j['shipment']);
    return DispatchCandidate(
      barcode: _str(j, 'barcode'),
      isPackage: _str(j, 'kind') == 'PACKAGE',
      shipmentId: _str(shipment, 'id'),
      shipmentNumber: _str(shipment, 'shipmentNumber'),
      product: _str(shipment, 'product'),
      sourceKey: _str(j, 'sourceKey'),
    );
  }
}

class OutgoingDispatchResult {
  const OutgoingDispatchResult({
    this.transferNumber = '',
    this.itemCount = 0,
    this.packageCount = 0,
    this.replayed = false,
  });

  final String transferNumber;
  final int itemCount;
  final int packageCount;
  final bool replayed;

  factory OutgoingDispatchResult.fromJson(Map<String, dynamic> j) =>
      OutgoingDispatchResult(
        transferNumber: _str(j, 'transferNumber'),
        itemCount: _int(j, 'itemCount'),
        packageCount: _int(j, 'packageCount'),
        replayed: _bool(j, 'replayed'),
      );
}

class IncomingTransfers {
  const IncomingTransfers({this.openTransfers = 0, this.transfers = const []});

  final int openTransfers;
  final List<BranchTransfer> transfers;

  factory IncomingTransfers.fromJson(Map<String, dynamic> j) =>
      IncomingTransfers(
        openTransfers: _int(_map(j['summary']), 'openTransfers'),
        transfers: [
          for (final row in _list(j['transfers'])) BranchTransfer.incoming(row),
        ],
      );
}

/// `action`: AUTO_INTAKE | SCANNED | ALREADY_INTAKEN.
class TransferScanResult {
  const TransferScanResult({
    this.action = '',
    this.transferId = '',
    this.transferNumber = '',
    this.shipmentNumber = '',
  });

  final String action;
  final String transferId;
  final String transferNumber;
  final String shipmentNumber;

  bool get alreadyIn => action == 'ALREADY_INTAKEN';

  factory TransferScanResult.fromJson(Map<String, dynamic> j) =>
      TransferScanResult(
        action: _str(j, 'action'),
        transferId: _str(j, 'transferId'),
        transferNumber: _str(j, 'transferNumber'),
        shipmentNumber: _str(_map(j['item']), 'shipmentNumber'),
      );
}

class TransferAcceptResult {
  const TransferAcceptResult({
    this.accepted = 0,
    this.missing = 0,
    this.failed = 0,
  });

  final int accepted;
  final int missing;
  final int failed;

  factory TransferAcceptResult.fromJson(Map<String, dynamic> j) =>
      TransferAcceptResult(
        accepted: _int(j, 'accepted'),
        missing: _int(j, 'missing'),
        failed: (j['failed'] as List?)?.length ?? 0,
      );
}

/// `state`: IN (içeri alındı) | SCANNED (okundu, "İçeri Al" bekliyor) |
/// PENDING | MISSING | EXCEPTION.
class TransferLine {
  const TransferLine({
    required this.id,
    this.shipmentNumber = '',
    this.cargoCode = '',
    this.product = '',
    this.state = 'PENDING',
  });

  final String id;
  final String shipmentNumber;
  final String cargoCode;
  final String product;
  final String state;

  factory TransferLine.fromJson(Map<String, dynamic> j) => TransferLine(
    id: _str(j, 'id'),
    shipmentNumber: _str(j, 'shipmentNumber'),
    cargoCode: _str(j, 'cargoCode'),
    product: _str(j, 'product'),
    state: _strOrNull(j, 'state') ?? 'PENDING',
  );
}

class IncomingTransferDetail {
  const IncomingTransferDetail({
    required this.transfer,
    this.lines = const [],
    this.pendingScannedCount = 0,
    this.pendingCount = 0,
  });

  final BranchTransfer transfer;
  final List<TransferLine> lines;

  /// Okutulmuş, "İçeri Al" bekleyen kalem sayısı.
  final int pendingScannedCount;

  /// Henüz okutulmamış kalem sayısı.
  final int pendingCount;

  factory IncomingTransferDetail.fromJson(Map<String, dynamic> j) =>
      IncomingTransferDetail(
        transfer: BranchTransfer.incoming(_map(j['transfer'])),
        lines: [
          for (final row in _list(j['lines'])) TransferLine.fromJson(row),
        ],
        pendingScannedCount: _int(j, 'pendingScannedCount'),
        pendingCount: _int(j, 'pendingCount'),
      );
}

/// Etikete basılan alanlar; müşteri/alıcı bilgisi içermez. [zpl] Zebra
/// yazıcıya doğrudan gönderilir (100x100 mm, 203 dpi).
class PrintableLabel {
  const PrintableLabel({
    required this.id,
    required this.barcode,
    this.typeCode = 'PACKAGE',
    this.printCount = 0,
    this.shipmentNumber = '',
    this.zpl = '',
  });

  final String id;
  final String barcode;

  /// CASE | PACKAGE | ITEM.
  final String typeCode;
  final int printCount;
  final String shipmentNumber;
  final String zpl;

  factory PrintableLabel.fromJson(Map<String, dynamic> j) => PrintableLabel(
    id: _str(j, 'id'),
    barcode: _str(j, 'barcode'),
    typeCode: _strOrNull(j, 'labelTypeCode') ?? 'PACKAGE',
    printCount: _int(j, 'printCount'),
    shipmentNumber: _str(_map(j['shipment']), 'shipmentNumber'),
    zpl: _str(j, 'zpl'),
  );
}

class LabelWorkspace {
  const LabelWorkspace({
    this.warehouses = const [],
    this.labelTypes = const [],
    this.recentLabels = const [],
  });

  final List<BranchWarehouse> warehouses;
  final List<String> labelTypes;
  final List<PrintableLabel> recentLabels;

  factory LabelWorkspace.fromJson(Map<String, dynamic> j) => LabelWorkspace(
    warehouses: [
      for (final row in _list(j['warehouses'])) BranchWarehouse.fromJson(row),
    ],
    labelTypes: [
      for (final t in j['labelTypes'] as List? ?? const [])
        if (t is String) t,
    ],
    recentLabels: [
      for (final row in _list(j['recentLabels'])) PrintableLabel.fromJson(row),
    ],
  );
}

class CourierPerformance {
  const CourierPerformance({
    required this.courierId,
    this.name = '',
    this.shipments = 0,
    this.delivered = 0,
    this.failed = 0,
    this.deliveryRate,
    this.firstAttemptRate,
  });

  final String courierId;
  final String name;
  final int shipments;
  final int delivered;
  final int failed;
  final num? deliveryRate;
  final num? firstAttemptRate;

  factory CourierPerformance.fromJson(Map<String, dynamic> j) =>
      CourierPerformance(
        courierId: _str(j, 'courierId'),
        name: _strOrNull(j, 'fullName') ?? _str(j, 'courierCode'),
        shipments: _int(j, 'shipments'),
        delivered: _int(j, 'delivered'),
        failed: _int(j, 'failed'),
        deliveryRate: _numOrNull(j['deliveryRate']),
        firstAttemptRate: _numOrNull(j['firstAttemptRate']),
      );
}

/// `GET branch/performance?range=today|7d|30d`. Yüzdeler payda 0 iken null
/// gelir; ekranda "—" gösterilir.
class PerformanceData {
  const PerformanceData({
    this.range = '7d',
    this.truncated = false,
    this.attemptedShipments = 0,
    this.deliveredShipments = 0,
    this.failedAttempts = 0,
    this.activeCouriers = 0,
    this.deliveryRate,
    this.firstAttemptRate,
    this.averageDeliveryMinutes,
    this.slaCompliance,
    this.couriers = const [],
    this.daily = const [],
  });

  final String range;
  final bool truncated;
  final int attemptedShipments;
  final int deliveredShipments;
  final int failedAttempts;
  final int activeCouriers;
  final num? deliveryRate;
  final num? firstAttemptRate;
  final num? averageDeliveryMinutes;
  final num? slaCompliance;
  final List<CourierPerformance> couriers;
  final List<({String day, int delivered, int failed})> daily;

  factory PerformanceData.fromJson(Map<String, dynamic> j) {
    final totals = _map(j['totals']);
    final kpis = _map(j['kpis']);
    num? kpi(String key) => _numOrNull(_map(kpis[key])['value']);
    return PerformanceData(
      range: _strOrNull(j, 'range') ?? '7d',
      truncated: _bool(j, 'truncated'),
      attemptedShipments: _int(totals, 'attemptedShipments'),
      deliveredShipments: _int(totals, 'deliveredShipments'),
      failedAttempts: _int(totals, 'failedAttempts'),
      activeCouriers: _int(totals, 'activeCouriers'),
      deliveryRate: kpi('deliveryRate'),
      firstAttemptRate: kpi('firstAttemptRate'),
      averageDeliveryMinutes: kpi('averageDeliveryMinutes'),
      slaCompliance: kpi('slaCompliance'),
      couriers: [
        for (final row in _list(j['couriers']))
          CourierPerformance.fromJson(row),
      ],
      daily: [
        for (final row in _list(j['daily']))
          (
            day: _str(row, 'day'),
            delivered: _int(row, 'delivered'),
            failed: _int(row, 'failed'),
          ),
      ],
    );
  }
}

/// Bildirim kutusu satırı. `severity`: INFO | WARNING | CRITICAL.
class InboxItem {
  const InboxItem({
    required this.id,
    this.category = '',
    this.severity = 'INFO',
    this.body = '',
    this.read = false,
    this.createdAt,
  });

  final String id;
  final String category;
  final String severity;
  final String body;
  final bool read;
  final DateTime? createdAt;

  factory InboxItem.fromJson(Map<String, dynamic> j) => InboxItem(
    id: _str(j, 'id'),
    category: _str(j, 'category'),
    severity: _strOrNull(j, 'severity') ?? 'INFO',
    body: _str(j, 'body'),
    read: _bool(j, 'read'),
    createdAt: _date(j, 'createdAt'),
  );
}

/// `GET branch/announcements`: şube kullanıcısına gelen duyurular ve
/// operasyon uyarıları (SLA / operasyon).
class AnnouncementsData {
  const AnnouncementsData({
    this.announcements = const [],
    this.alerts = const [],
  });

  final List<InboxItem> announcements;
  final List<InboxItem> alerts;

  factory AnnouncementsData.fromJson(Map<String, dynamic> j) =>
      AnnouncementsData(
        announcements: [
          for (final row in _list(j['announcements'])) InboxItem.fromJson(row),
        ],
        alerts: [
          for (final row in _list(j['operationalAlerts']))
            InboxItem(
              id: _str(row, 'id'),
              category: _str(row, 'category'),
              severity: _strOrNull(row, 'severity') ?? 'WARNING',
              body: [
                _str(row, 'shipmentNumber'),
                _str(row, 'body'),
              ].where((s) => s.isNotEmpty).join(' · '),
              read: true,
              createdAt: _date(row, 'createdAt'),
            ),
        ],
      );
}

/// Bir kuryenin günlük planı ve vardiya durumu. `planStatus`: PLANNED | OFF |
/// ON_LEAVE | NO_PLAN. `flags` yalnız bilgidir, işlem engellemez.
class ShiftCourierRow {
  const ShiftCourierRow({
    required this.courierId,
    required this.name,
    this.planStatus = 'NO_PLAN',
    this.ranges = '',
    this.onShiftNow = false,
    this.onBreak = false,
    this.flags = const [],
  });

  final String courierId;
  final String name;
  final String planStatus;

  /// "09:00–18:00" biçiminde plan aralıkları.
  final String ranges;
  final bool onShiftNow;

  /// Açık vardiyada mola sürüyor (kurye `Shift.onBreak`). Haritadaki
  /// `liveStatus` BREAK yalnız konum yaşıdır; gerçek mola buradan okunur.
  final bool onBreak;
  final List<String> flags;

  factory ShiftCourierRow.fromJson(Map<String, dynamic> j) {
    final courier = _map(j['courier']);
    final plan = _map(j['plan']);
    return ShiftCourierRow(
      courierId: _str(courier, 'id'),
      name: _strOrNull(courier, 'fullName') ?? _str(courier, 'courierCode'),
      planStatus: _strOrNull(plan, 'status') ?? 'NO_PLAN',
      ranges: [
        for (final r in _list(plan['ranges']))
          '${_str(r, 'start')}–${_str(r, 'end')}',
      ].join(', '),
      onShiftNow: _bool(j, 'onShiftNow'),
      onBreak: _list(j['shifts'])
          .any((s) => s['status'] == 'OPEN' && s['onBreak'] == true),
      flags: [
        for (final f in j['flags'] as List? ?? const [])
          if (f is String) f,
      ],
    );
  }
}

class BranchShiftDay {
  const BranchShiftDay({
    this.courierCount = 0,
    this.plannedCount = 0,
    this.onShiftNow = 0,
    this.plannedNotStarted = 0,
    this.onLeave = 0,
    this.couriers = const [],
  });

  final int courierCount;
  final int plannedCount;
  final int onShiftNow;
  final int plannedNotStarted;
  final int onLeave;
  final List<ShiftCourierRow> couriers;

  factory BranchShiftDay.fromJson(Map<String, dynamic> j) {
    final s = _map(j['summary']);
    return BranchShiftDay(
      courierCount: _int(s, 'courierCount'),
      plannedCount: _int(s, 'plannedCount'),
      onShiftNow: _int(s, 'onShiftNow'),
      plannedNotStarted: _int(s, 'plannedNotStarted'),
      onLeave: _int(s, 'onLeave'),
      couriers: [
        for (final row in _list(j['couriers'])) ShiftCourierRow.fromJson(row),
      ],
    );
  }
}

/// Kuryenin izin (LEAVE) / tatil (HOLIDAY) isteği. `approvalStatus`:
/// PENDING | APPROVED | REJECTED.
class LeaveRequest {
  const LeaveRequest({
    required this.id,
    this.courierName = '',
    this.date = '',
    this.type = 'LEAVE',
    this.note = '',
    this.approvalStatus = 'PENDING',
  });

  final String id;
  final String courierName;
  final String date;
  final String type;
  final String note;
  final String approvalStatus;

  bool get pending => approvalStatus == 'PENDING';

  factory LeaveRequest.fromJson(Map<String, dynamic> j) => LeaveRequest(
    id: _str(j, 'id'),
    courierName: _str(_map(j['courier']), 'fullName'),
    date: _str(j, 'date'),
    type: _strOrNull(j, 'type') ?? 'LEAVE',
    note: _str(j, 'note'),
    approvalStatus: _strOrNull(j, 'approvalStatus') ?? 'PENDING',
  );
}

class SmsTemplate {
  const SmsTemplate({
    required this.key,
    required this.name,
    this.body = '',
    this.variables = const [],
    this.shipmentVariables = const [],
  });

  final String key;
  final String name;
  final String body;
  final List<String> variables;

  /// Gönderi olmadan doldurulamayan değişkenler; kurye hedefinde kullanıcıdan
  /// istenir.
  final List<String> shipmentVariables;

  factory SmsTemplate.fromJson(Map<String, dynamic> j) {
    List<String> strings(String key) => [
      for (final v in j[key] as List? ?? const [])
        if (v is String) v,
    ];
    return SmsTemplate(
      key: _str(j, 'templateKey'),
      name: _str(j, 'name'),
      body: _str(j, 'body'),
      variables: strings('variables'),
      shipmentVariables: strings('shipmentVariables'),
    );
  }
}

/// SMS alıcı adayı: gönderi (alıcısına gider) ya da kurye. Telefon maskeli.
class SmsTarget {
  const SmsTarget({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.hasPhone = true,
  });

  final String id;
  final String title;
  final String subtitle;
  final bool hasPhone;

  factory SmsTarget.shipment(Map<String, dynamic> j) => SmsTarget(
    id: _str(j, 'id'),
    title: _str(j, 'shipmentNumber'),
    subtitle: [
      _str(j, 'recipientName'),
      _str(j, 'maskedPhone'),
    ].where((s) => s.isNotEmpty).join(' · '),
    hasPhone: j['hasPhone'] != false,
  );

  factory SmsTarget.courier(Map<String, dynamic> j) => SmsTarget(
    id: _str(j, 'id'),
    title: _str(j, 'fullName'),
    subtitle: _str(j, 'maskedPhone'),
    hasPhone: j['hasPhone'] != false,
  );
}

class SmsPreview {
  const SmsPreview({
    this.rendered,
    this.missingVariables = const [],
    this.recipientCount = 0,
    this.reachableCount = 0,
  });

  /// Eksik değişken varsa null.
  final String? rendered;
  final List<String> missingVariables;
  final int recipientCount;
  final int reachableCount;

  factory SmsPreview.fromJson(Map<String, dynamic> j) => SmsPreview(
    rendered: _strOrNull(j, 'rendered'),
    missingVariables: [
      for (final v in j['missingVariables'] as List? ?? const [])
        if (v is String) v,
    ],
    recipientCount: _int(j, 'recipientCount'),
    reachableCount: _int(j, 'reachableCount'),
  );
}

/// Şubenin yayımladığı ya da merkezin atadığı eğitim (yönetim görünümü).
class ManagedTraining {
  const ManagedTraining({
    required this.id,
    this.title = '',
    this.mandatory = false,
    this.status = 'PUBLISHED',
    this.editable = false,
    this.learners = 0,
    this.completed = 0,
  });

  final String id;
  final String title;
  final bool mandatory;

  /// DRAFT | PUBLISHED.
  final String status;

  /// Yalnız şubenin kendi eğitimi düzenlenebilir.
  final bool editable;
  final int learners;
  final int completed;

  factory ManagedTraining.fromJson(Map<String, dynamic> j) {
    final stats = _map(j['stats']);
    return ManagedTraining(
      id: _str(j, 'id'),
      title: _strOrNull(j, 'title') ?? _str(j, 'summary'),
      mandatory: _bool(j, 'isMandatory'),
      status: _strOrNull(j, 'status') ?? 'PUBLISHED',
      editable: _bool(j, 'editable'),
      learners: _int(stats, 'learners'),
      completed: _int(stats, 'completed'),
    );
  }
}

/// Öğrenen eğitimi (targetType BRANCH / CUSTOMER_PROCESS). `status`:
/// NOT_STARTED | IN_PROGRESS | COMPLETED | EXPIRED. İçerik bağlantısı ve
/// açıklama yalnız detayda gelir.
class LearnerTraining {
  const LearnerTraining({
    required this.id,
    this.title = '',
    this.summary,
    this.description,
    this.coverUrl,
    this.primaryType = 'TEXT',
    this.category = '',
    this.mandatory = false,
    this.lessonCount = 0,
    this.lessonTypes = const [],
    this.durationSeconds,
    this.minimumViewSeconds = 0,
    this.dueAt,
    this.overdue = false,
    this.status = 'NOT_STARTED',
    this.progressPercent,
    this.contentUrl,
    this.contentBody,
  });

  final String id;
  final String title;
  final String? summary;
  final String? description;
  final String? coverUrl;
  final String primaryType;
  final String category;
  final bool mandatory;
  final int lessonCount;
  final List<String> lessonTypes;
  final int? durationSeconds;
  final int minimumViewSeconds;
  final DateTime? dueAt;
  final bool overdue;
  final String status;

  /// Sunucunun verdiği ilerleme yüzdesi; yoksa null (uydurulmaz).
  final num? progressPercent;
  final String? contentUrl;
  final String? contentBody;

  bool get completed => status == 'COMPLETED';

  factory LearnerTraining.fromJson(Map<String, dynamic> j) {
    final progress = _map(j['progress']);
    final seconds = _numOrNull(j['totalDurationSeconds']);
    final minutes = _numOrNull(j['durationMinutes']);
    return LearnerTraining(
      id: _str(j, 'id'),
      title: _str(j, 'title'),
      summary: _strOrNull(j, 'summary'),
      description: _strOrNull(j, 'description'),
      coverUrl: _strOrNull(j, 'coverUrl'),
      primaryType: _strOrNull(j, 'primaryType') ?? 'TEXT',
      category: _str(j, 'category'),
      mandatory: _bool(j, 'isMandatory'),
      lessonCount: _int(j, 'lessonCount'),
      lessonTypes: [
        for (final t in j['lessonTypes'] as List? ?? const [])
          if (t is String) t,
      ],
      durationSeconds:
          seconds?.toInt() ?? (minutes == null ? null : (minutes * 60).toInt()),
      minimumViewSeconds: _int(j, 'minimumViewSeconds'),
      dueAt: _date(j, 'dueAt'),
      overdue: _bool(j, 'overdue'),
      status: _strOrNull(j, 'status') ?? 'NOT_STARTED',
      progressPercent:
          _numOrNull(progress['progressPercent']) ??
          _numOrNull(progress['percent']),
      contentUrl: _strOrNull(j, 'contentUrl'),
      contentBody: _strOrNull(j, 'contentBody'),
    );
  }
}

/// GET branch/training?targetType=: öğrenen eğitimleri (BRANCH /
/// CUSTOMER_PROCESS, özetli) ya da kuryelere düşenler (COURIER).
class TrainingCenterData {
  const TrainingCenterData({
    required this.targetType,
    this.learner = const [],
    this.managed = const [],
    this.total = 0,
    this.completed = 0,
    this.mandatoryPending = 0,
    this.overdue = 0,
    this.hasSummary = false,
    this.targetTypes = const ['BRANCH', 'COURIER', 'CUSTOMER_PROCESS'],
  });

  final String targetType;
  final List<LearnerTraining> learner;
  final List<ManagedTraining> managed;
  final int total;
  final int completed;
  final int mandatoryPending;
  final int overdue;
  final bool hasSummary;
  final List<String> targetTypes;

  factory TrainingCenterData.fromJson(Map<String, dynamic> j) {
    final type = _strOrNull(j, 'targetType') ?? 'BRANCH';
    final rows = _list(j['trainings']);
    final summary = _map(j['summary']);
    final types = [
      for (final t in j['targetTypes'] as List? ?? const [])
        if (t is String) t,
    ];
    return TrainingCenterData(
      targetType: type,
      learner: type == 'COURIER'
          ? const []
          : [for (final r in rows) LearnerTraining.fromJson(r)],
      managed: type == 'COURIER'
          ? [for (final r in rows) ManagedTraining.fromJson(r)]
          : const [],
      total: _int(summary, 'total'),
      completed: _int(summary, 'completed'),
      mandatoryPending: _int(summary, 'mandatoryPending'),
      overdue: _int(summary, 'overdue'),
      hasSummary: summary.isNotEmpty,
      targetTypes: types.isEmpty
          ? const ['BRANCH', 'COURIER', 'CUSTOMER_PROCESS']
          : types,
    );
  }
}

typedef TrainingFaq = ({String question, String answer});

/// Şube sözleşme ve evrak kalemleri (compliance `contracts` / `documents`).
/// `schemaReady: false` iken her kalem NOT_AVAILABLE gelir.
class BranchDocs {
  const BranchDocs({
    this.schemaReady = false,
    this.contracts = const [],
    this.documents = const [],
  });

  final bool schemaReady;
  final List<({String type, String status})> contracts;
  final List<({String type, String status})> documents;

  factory BranchDocs.fromJson(Map<String, dynamic> j) => BranchDocs(
    schemaReady: _bool(j, 'schemaReady'),
    contracts: [
      for (final r in _list(j['contracts']))
        (type: _str(r, 'type'), status: _str(r, 'status')),
    ],
    documents: [
      for (final r in _list(j['documents']))
        (type: _str(r, 'type'), status: _str(r, 'status')),
    ],
  );
}

/// Kurye belgesi (başvuru evrakı). `status`: APPROVED | IN_REVIEW |
/// MISSING | REJECTED | EXPIRED (süresi geçmiş onay) …
class ComplianceDoc {
  const ComplianceDoc({
    required this.code,
    this.titleTr = '',
    this.titleEn = '',
    this.status = '',
    this.required = false,
    this.expiresAt,
  });

  final String code;
  final String titleTr;
  final String titleEn;
  final String status;
  final bool required;
  final DateTime? expiresAt;

  factory ComplianceDoc.fromJson(Map<String, dynamic> j) => ComplianceDoc(
    code: _str(j, 'code'),
    titleTr: _str(j, 'titleTr'),
    titleEn: _str(j, 'titleEn'),
    status: _str(j, 'status'),
    required: _bool(j, 'isRequired'),
    expiresAt: _date(j, 'expiresAt'),
  );
}

/// Kuryenin evrak ve onay durumu. `documentStatus`: COMPLETE | IN_REVIEW |
/// MISSING | NO_PACKAGE.
class CourierCompliance {
  const CourierCompliance({
    required this.id,
    this.name = '',
    this.code = '',
    this.status = '',
    this.vehicleType = '',
    this.activatedAt,
    this.assignedFrom,
    this.documentStatus = 'NO_PACKAGE',
    this.required = 0,
    this.approved = 0,
    this.missing = 0,
    this.inReview = 0,
    this.documents = const [],
    this.consentsTotal = 0,
    this.consentsAccepted = 0,
    this.operationReady = false,
  });

  final String id;
  final String name;
  final String code;
  final String status;
  final String vehicleType;
  final DateTime? activatedAt;
  final DateTime? assignedFrom;
  final String documentStatus;
  final int required;
  final int approved;
  final int missing;
  final int inReview;
  final List<ComplianceDoc> documents;
  final int consentsTotal;
  final int consentsAccepted;
  final bool operationReady;

  factory CourierCompliance.fromJson(Map<String, dynamic> j) {
    final docs = _map(j['documents']);
    final consents = _map(j['consents']);
    return CourierCompliance(
      id: _str(j, 'id'),
      name: _strOrNull(j, 'fullName') ?? _str(j, 'courierCode'),
      code: _str(j, 'courierCode'),
      status: _str(j, 'status'),
      vehicleType: _str(j, 'vehicleType'),
      activatedAt: _date(j, 'activatedAt'),
      assignedFrom: _date(j, 'assignedFrom'),
      documentStatus: _strOrNull(docs, 'status') ?? 'NO_PACKAGE',
      required: _int(docs, 'required'),
      approved: _int(docs, 'approved'),
      missing: _int(docs, 'missing'),
      inReview: _int(docs, 'inReview'),
      documents: [
        for (final row in _list(docs['items'])) ComplianceDoc.fromJson(row),
      ],
      consentsTotal: _int(consents, 'total'),
      consentsAccepted: _int(consents, 'accepted'),
      operationReady: _bool(j, 'operationReady'),
    );
  }
}

/// Şubeye bağlı kurye (GET agency/couriers). `status`: kurye havuz durumu
/// (AVAILABLE, WORKING …); atama yalnız ACTIVE olanlar gelir.
class BranchCourier {
  const BranchCourier({
    required this.id,
    required this.name,
    this.assignmentId = '',
    this.code = '',
    this.phone,
    this.email,
    this.status = '',
    this.workModel = '',
    this.vehicleType = '',
    this.city = '',
    this.district = '',
    this.primary = false,
    this.shipmentCount = 0,
    this.validFrom,
  });

  final String id;
  final String name;
  final String assignmentId;
  final String code;
  final String? phone;
  final String? email;
  final String status;
  final String workModel;
  final String vehicleType;
  final String city;
  final String district;
  final bool primary;

  /// Kuryedeki 40xx durumlu gönderi sayısı.
  final int shipmentCount;
  final DateTime? validFrom;

  /// Aktif: havuzda müsait ya da çalışıyor. Diğer durumlar (pasif, askıda,
  /// izinli …) "Pasif" sekmesinde.
  bool get active => const {'AVAILABLE', 'WORKING', 'ACTIVE'}.contains(status);

  static BranchCourier? fromJson(Map<String, dynamic> j) {
    final c = _map(j['courier']);
    final id = _str(c, 'id');
    if (id.isEmpty) return null;
    return BranchCourier(
      id: id,
      name: _strOrNull(c, 'fullName') ?? _str(c, 'courierCode'),
      assignmentId: _str(j, 'id'),
      code: _str(c, 'courierCode'),
      phone: _strOrNull(c, 'phone'),
      email: _strOrNull(c, 'email'),
      status: _str(c, 'status'),
      workModel: _str(c, 'workModel'),
      vehicleType: _str(c, 'vehicleType'),
      city: _str(c, 'cityName'),
      district: _str(c, 'districtName'),
      primary: _bool(j, 'isPrimary'),
      shipmentCount: _int(j, 'shipmentCount'),
      validFrom: _date(j, 'validFrom'),
    );
  }
}

/// Şube / kurye kartı (POST compliance/cards). `token` QR içeriğidir; aynı
/// gün aynı sahip için aynı belirteç, 365 gün geçerli. Kalıcı kart ya da
/// iptal kaydı yoktur.
class PartnerCard {
  const PartnerCard({
    required this.token,
    this.displayName = '',
    this.code = '',
    this.branchName = '',
    this.statusCode = '',
    this.complianceStatus = '',
    this.active = false,
    this.issuedAt,
    this.expiresAt,
  });

  final String token;
  final String displayName;
  final String code;
  final String branchName;
  final String statusCode;
  final String complianceStatus;
  final bool active;
  final DateTime? issuedAt;
  final DateTime? expiresAt;

  factory PartnerCard.fromJson(Map<String, dynamic> j) => PartnerCard(
    token: _str(j, 'token'),
    displayName: _str(j, 'displayName'),
    code: _str(j, 'code'),
    branchName: _str(j, 'branchName'),
    statusCode: _str(j, 'statusCode'),
    complianceStatus: _str(j, 'complianceStatus'),
    active: _bool(j, 'active'),
    issuedAt: _date(j, 'issuedAt'),
    expiresAt: _date(j, 'expiresAt'),
  );
}

class SmsBatch {
  const SmsBatch({
    required this.id,
    this.templateName = '',
    this.createdAt,
    this.statusCounts = const {},
  });

  final String id;
  final String templateName;
  final DateTime? createdAt;

  /// Durum → alıcı sayısı (ör. SENT, SKIPPED, FAILED).
  final Map<String, int> statusCounts;

  factory SmsBatch.fromJson(Map<String, dynamic> j) => SmsBatch(
    id: _str(j, 'batchId'),
    templateName: _strOrNull(j, 'templateName') ?? _str(j, 'templateKey'),
    createdAt: _date(j, 'createdAt'),
    statusCounts: {
      for (final e in _map(j['statusCounts']).entries)
        if (e.value is num) e.key: (e.value as num).toInt(),
    },
  );
}
