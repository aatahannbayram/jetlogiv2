/// DTOs for the "Şube Mobil API" (`portal/v1/branch/*`, `portal/v1/agency/*`).
/// Field names mirror `swagger/branch.yaml` (v1.4.0) on
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

/// Türkiye takvimi (UTC+3, yaz saati yok).
DateTime istanbulClock([DateTime? now]) =>
    (now ?? DateTime.now()).toUtc().add(const Duration(hours: 3));

String istanbulYmd([DateTime? now]) => ymdOf(istanbulClock(now));

String ymdOf(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

/// `YYYY-MM-DD` veya ISO tarih-saatın takvim günü. Saat dilimi kaydırılmaz;
/// sunucunun yazdığı gün öneki olduğu gibi kalır.
String? dayPrefix(Object? value) {
  if (value is! String || value.length < 10) return null;
  final head = value.substring(0, 10);
  return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(head) ? head : null;
}

enum CustomRangeIssue { none, order, future, tooLong, invalid }

/// `from`/`to` dahil, en fazla 92 gün, bugünden ileri yok.
CustomRangeIssue checkCustomRange(String from, String to, {DateTime? now}) {
  if (dayPrefix(from) != from || dayPrefix(to) != to) {
    return CustomRangeIssue.invalid;
  }
  final today = istanbulYmd(now);
  if (from.compareTo(today) > 0 || to.compareTo(today) > 0) {
    return CustomRangeIssue.future;
  }
  if (from.compareTo(to) > 0) return CustomRangeIssue.order;
  final days = DateTime.parse(to).difference(DateTime.parse(from)).inDays + 1;
  if (days > 92) return CustomRangeIssue.tooLong;
  return CustomRangeIssue.none;
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
  });

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
      );
}

class BranchDashboard {
  const BranchDashboard({
    this.branchName = '',
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
  });

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
    this.date,
    this.readOnly = false,
    this.kpis = const DispatchKpis(),
    this.rows = const [],
    this.capabilities = const BranchCapabilities(),
  });

  /// Panonun günü (`YYYY-MM-DD`, İstanbul). Boşsa bugün.
  final String? date;

  /// Geçmiş gün: zimmet ve atama kapalı.
  final bool readOnly;
  final DispatchKpis kpis;
  final List<BranchShipmentRow> rows;
  final BranchCapabilities capabilities;

  factory DispatchBoard.fromJson(Map<String, dynamic> j) => DispatchBoard(
    date: _strOrNull(j, 'date'),
    readOnly: _bool(j, 'readOnly'),
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

/// `GET branch/performance?range=today|7d|30d|custom`. Yüzdeler payda 0 iken
/// null gelir; ekranda "—" gösterilir. `custom` için `from`/`to` dahil.
class PerformanceData {
  const PerformanceData({
    this.range = '7d',
    this.fromDay,
    this.toDay,
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

  /// `custom` aralığın günleri (`YYYY-MM-DD`).
  final String? fromDay;
  final String? toDay;
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

  /// Ekranın istediği aralıkla eşleşmezse eski cevap çizilmez.
  String get selectionKey =>
      range == 'custom' ? 'custom:${fromDay ?? ''}:${toDay ?? ''}' : range;

  PerformanceData withQuery({String? fromDay, String? toDay}) => PerformanceData(
    range: range,
    fromDay: fromDay ?? this.fromDay,
    toDay: toDay ?? this.toDay,
    truncated: truncated,
    attemptedShipments: attemptedShipments,
    deliveredShipments: deliveredShipments,
    failedAttempts: failedAttempts,
    activeCouriers: activeCouriers,
    deliveryRate: deliveryRate,
    firstAttemptRate: firstAttemptRate,
    averageDeliveryMinutes: averageDeliveryMinutes,
    slaCompliance: slaCompliance,
    couriers: couriers,
    daily: daily,
  );

  factory PerformanceData.fromJson(Map<String, dynamic> j) {
    final totals = _map(j['totals']);
    final kpis = _map(j['kpis']);
    num? kpi(String key) => _numOrNull(_map(kpis[key])['value']);
    return PerformanceData(
      range: _strOrNull(j, 'range') ?? '7d',
      fromDay: dayPrefix(j['from']),
      toDay: dayPrefix(j['to']),
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
    this.flags = const [],
  });

  final String courierId;
  final String name;
  final String planStatus;

  /// "09:00–18:00" biçiminde plan aralıkları.
  final String ranges;
  final bool onShiftNow;
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

/// Kuryenin evrak ve onay durumu. `documentStatus`: COMPLETE | IN_REVIEW |
/// MISSING | NO_PACKAGE.
class CourierCompliance {
  const CourierCompliance({
    required this.id,
    this.name = '',
    this.documentStatus = 'NO_PACKAGE',
    this.missing = 0,
    this.inReview = 0,
    this.operationReady = false,
  });

  final String id;
  final String name;
  final String documentStatus;
  final int missing;
  final int inReview;
  final bool operationReady;

  factory CourierCompliance.fromJson(Map<String, dynamic> j) {
    final docs = _map(j['documents']);
    return CourierCompliance(
      id: _str(j, 'id'),
      name: _strOrNull(j, 'fullName') ?? _str(j, 'courierCode'),
      documentStatus: _strOrNull(docs, 'status') ?? 'NO_PACKAGE',
      missing: _int(docs, 'missing'),
      inReview: _int(docs, 'inReview'),
      operationReady: _bool(j, 'operationReady'),
    );
  }
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

/// `GET branch/stock-summary`. Sayılar koli değil, gönderi adedidir.
class BranchStockSummary {
  const BranchStockSummary({
    this.inWarehouse = 0,
    this.atCourier = 0,
    this.inTransit = 0,
    this.returnPending = 0,
    this.generatedAt,
  });

  final int inWarehouse;
  final int atCourier;
  final int inTransit;
  final int returnPending;
  final DateTime? generatedAt;

  factory BranchStockSummary.fromJson(Map<String, dynamic> j) =>
      BranchStockSummary(
        inWarehouse: _int(j, 'inWarehouse'),
        atCourier: _int(j, 'atCourier'),
        inTransit: _int(j, 'inTransit'),
        returnPending: _int(j, 'returnPending'),
        generatedAt: _date(j, 'generatedAt'),
      );
}

class CourierVehicle {
  const CourierVehicle({
    this.plate = '',
    this.vehicleTypeCode = '',
    this.brand = '',
    this.model,
    this.modelYear,
    this.statusCode = '',
  });

  final String plate;
  final String vehicleTypeCode;
  final String brand;
  final String? model;
  final int? modelYear;
  final String statusCode;

  static CourierVehicle? fromJson(Object? json) {
    if (json is! Map) return null;
    final j = _map(json);
    if (j.isEmpty) return null;
    return CourierVehicle(
      plate: _str(j, 'plate'),
      vehicleTypeCode: _str(j, 'vehicleTypeCode'),
      brand: _str(j, 'brand'),
      model: _strOrNull(j, 'model'),
      modelYear: j['modelYear'] == null ? null : _int(j, 'modelYear'),
      statusCode: _str(j, 'statusCode'),
    );
  }
}

class CourierDevicePermissions {
  const CourierDevicePermissions({
    this.location,
    this.backgroundLocation,
    this.camera,
    this.notifications,
  });

  final bool? location;
  final bool? backgroundLocation;
  final bool? camera;
  final bool? notifications;

  static bool? _flag(Map<String, dynamic> j, String key) {
    final v = j[key];
    return v is bool ? v : null;
  }

  static CourierDevicePermissions? fromJson(Object? json) {
    if (json is! Map) return null;
    final j = _map(json);
    return CourierDevicePermissions(
      location: _flag(j, 'location'),
      backgroundLocation: _flag(j, 'backgroundLocation'),
      camera: _flag(j, 'camera'),
      notifications: _flag(j, 'notifications'),
    );
  }
}

class CourierDevice {
  const CourierDevice({
    this.model,
    this.platform = '',
    this.os,
    this.appVersion,
    this.lastSeenAt,
    this.permissions,
  });

  final String? model;
  final String platform;
  final String? os;
  final String? appVersion;
  final DateTime? lastSeenAt;
  final CourierDevicePermissions? permissions;

  static CourierDevice? fromJson(Object? json) {
    if (json is! Map) return null;
    final j = _map(json);
    if (j.isEmpty) return null;
    return CourierDevice(
      model: _strOrNull(j, 'model'),
      platform: _str(j, 'platform'),
      os: _strOrNull(j, 'os'),
      appVersion: _strOrNull(j, 'appVersion'),
      lastSeenAt: _date(j, 'lastSeenAt'),
      permissions: CourierDevicePermissions.fromJson(j['permissions']),
    );
  }
}

/// `GET agency/couriers/{courierId}`. Araç veya cihaz yoksa ilgili alan null.
class AgencyCourierDetail {
  const AgencyCourierDetail({
    required this.courierId,
    this.courierCode = '',
    this.fullName = '',
    this.phone,
    this.email,
    this.status = '',
    this.workModel,
    this.isPrimary = false,
    this.vehicleType,
    this.plate,
    this.vehicleModel,
    this.vehicle,
    this.device,
  });

  final String courierId;
  final String courierCode;
  final String fullName;
  final String? phone;
  final String? email;
  final String status;
  final String? workModel;
  final bool isPrimary;
  final String? vehicleType;
  final String? plate;
  final String? vehicleModel;
  final CourierVehicle? vehicle;
  final CourierDevice? device;

  factory AgencyCourierDetail.fromJson(Map<String, dynamic> j) =>
      AgencyCourierDetail(
        courierId: _str(j, 'courierId'),
        courierCode: _str(j, 'courierCode'),
        fullName: _str(j, 'fullName'),
        phone: _strOrNull(j, 'phone'),
        email: _strOrNull(j, 'email'),
        status: _str(j, 'status'),
        workModel: _strOrNull(j, 'workModel'),
        isPrimary: _bool(j, 'isPrimary'),
        vehicleType: _strOrNull(j, 'vehicleType'),
        plate: _strOrNull(j, 'plate'),
        vehicleModel: _strOrNull(j, 'vehicleModel'),
        vehicle: CourierVehicle.fromJson(j['vehicle']),
        device: CourierDevice.fromJson(j['device']),
      );
}

/// `GET branch/courier-jobs` → `recent[]`. Ad yoksa kod gösterilir.
/// "Workflow status changed" ham metin olarak çizilmez.
class JobHistoryEvent {
  const JobHistoryEvent({
    required this.id,
    this.code = '',
    this.statusCode,
    this.statusName,
    this.altStatusCode,
    this.altStatusName,
    this.reasonCode,
    this.reasonName,
    this.source,
    this.sourceName,
    this.actor,
    this.at,
  });

  final String id;
  final String code;
  final String? statusCode;
  final String? statusName;
  final String? altStatusCode;
  final String? altStatusName;
  final String? reasonCode;
  final String? reasonName;
  final String? source;
  final String? sourceName;
  final String? actor;
  final DateTime? at;

  static bool _rawWorkflow(String? value) =>
      value?.trim().toLowerCase() == 'workflow status changed';

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty || _rawWorkflow(trimmed)) return null;
    return trimmed;
  }

  /// Statü adı, yoksa alt statü adı, yoksa kod.
  String get headline =>
      _clean(statusName) ??
      _clean(altStatusName) ??
      _clean(statusCode) ??
      _clean(altStatusCode) ??
      _clean(code) ??
      '';

  String? get altLine {
    final alt = _clean(altStatusName) ?? _clean(altStatusCode);
    if (alt == null || alt == headline) return null;
    return alt;
  }

  factory JobHistoryEvent.fromJson(Map<String, dynamic> j) => JobHistoryEvent(
    id: _str(j, 'id'),
    code: _str(j, 'code'),
    statusCode: _strOrNull(j, 'statusCode'),
    statusName: _strOrNull(j, 'statusName'),
    altStatusCode: _strOrNull(j, 'altStatusCode'),
    altStatusName: _strOrNull(j, 'altStatusName'),
    reasonCode: _strOrNull(j, 'reasonCode'),
    reasonName: _strOrNull(j, 'reasonName'),
    source: _strOrNull(j, 'source'),
    sourceName: _strOrNull(j, 'sourceName'),
    actor: _strOrNull(j, 'actor'),
    at: _date(j, 'at'),
  );
}

class CourierJobsView {
  const CourierJobsView({this.recent = const []});

  final List<JobHistoryEvent> recent;

  factory CourierJobsView.fromJson(Map<String, dynamic> j) => CourierJobsView(
    recent: [
      for (final row in _list(j['recent'])) JobHistoryEvent.fromJson(row),
    ],
  );
}
