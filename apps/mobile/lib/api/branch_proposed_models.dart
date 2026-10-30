/// Şube ekranlarının JetDiji'de HENÜZ OLMAYAN uçları için önerilen şekiller
/// (branch.yaml 1.2.0'da yok). Sözleşme: docs/15-onerilen-sube-uclari.md.
/// Uç yayımlanınca alan adları Swagger'la karşılaştırılır, farklıysa yalnız
/// buradaki `fromJson`'lar düzeltilir; ekranlar bu sınıfları kullanır.
library;

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};

List<Map<String, dynamic>> _list(Object? v) => [
  for (final row in v is List ? v : const [])
    if (row is Map) Map<String, dynamic>.from(row),
];

String _str(Map<String, dynamic> j, String key) {
  final v = j[key];
  return v == null ? '' : '$v'.trim();
}

String? _strOrNull(Map<String, dynamic> j, String key) {
  final v = _str(j, key);
  return v.isEmpty ? null : v;
}

int _int(Map<String, dynamic> j, String key) =>
    (j[key] is num) ? (j[key] as num).toInt() : int.tryParse('${j[key]}') ?? 0;

num _num(Map<String, dynamic> j, String key) =>
    (j[key] is num) ? j[key] as num : num.tryParse('${j[key]}') ?? 0;

DateTime? _date(Map<String, dynamic> j, String key) {
  final v = j[key];
  return v is String ? DateTime.tryParse(v) : null;
}

/// `YYYY-MM-DD`, Türkiye günü (istemci yerel saatiyle).
String isoDay(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

// ── Fatura & hakediş (GET branch/invoices, schemaReady: true) ────────────

typedef BranchInvoice = ({
  String id,
  String number,
  String period,
  num amount,
  num vat,
  String status,
  DateTime due,
  String? pdfUrl,
  List<({String label, int quantity, num amount})> lines,
});

/// `schemaReady` false ya da liste yoksa boş döner.
List<BranchInvoice> parseInvoices(Map<String, dynamic> data) {
  if (data['schemaReady'] != true) return const [];
  return [
    for (final r in _list(data['invoices']))
      if (_str(r, 'id').isNotEmpty)
        (
          id: _str(r, 'id'),
          number: _str(r, 'number'),
          period: _str(r, 'period'),
          amount: _num(r, 'amount'),
          vat: _num(r, 'vat'),
          status: _str(r, 'status'),
          due: _date(r, 'dueAt') ?? DateTime.now(),
          pdfUrl: _strOrNull(r, 'pdfUrl'),
          lines: [
            for (final l in _list(r['lines']))
              (
                label: _str(l, 'label'),
                quantity: _int(l, 'quantity'),
                amount: _num(l, 'amount'),
              ),
          ],
        ),
  ];
}

// ── Gün sonu (GET branch/end-of-day, POST branch/end-of-day/close) ───────

class EodBlocker {
  const EodBlocker(this.code, this.count);

  /// RESULT_MISSING | RETURN_NOT_SCANNED | HANDOVER_PENDING | COUNT_OPEN.
  final String code;
  final int count;
}

class EndOfDayStatus {
  const EndOfDayStatus({
    required this.date,
    this.closed = false,
    this.canClose = false,
    this.closedAt,
    this.closedByName,
    this.blockers = const [],
  });

  final String date;
  final bool closed;
  final bool canClose;
  final DateTime? closedAt;
  final String? closedByName;
  final List<EodBlocker> blockers;

  factory EndOfDayStatus.fromJson(Map<String, dynamic> j) => EndOfDayStatus(
    date: _str(j, 'date'),
    closed: _str(j, 'status') == 'CLOSED',
    canClose: j['canClose'] == true,
    closedAt: _date(j, 'closedAt'),
    closedByName: _strOrNull(j, 'closedByName'),
    blockers: [
      for (final b in _list(j['blockers']))
        if (_int(b, 'count') > 0) EodBlocker(_str(b, 'code'), _int(b, 'count')),
    ],
  );
}

// ── Şube stok sayaçları (GET branch/stock-summary) ───────────────────────

class StockSummary {
  const StockSummary({
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

  factory StockSummary.fromJson(Map<String, dynamic> j) => StockSummary(
    inWarehouse: _int(j, 'inWarehouse'),
    atCourier: _int(j, 'atCourier'),
    inTransit: _int(j, 'inTransit'),
    returnPending: _int(j, 'returnPending'),
    generatedAt: _date(j, 'generatedAt'),
  );
}

// ── Dağıtım planlama talebi (GET/POST branch/distribution-plans) ─────────

class DistributionPlan {
  const DistributionPlan({
    required this.id,
    required this.date,
    this.district = '',
    this.expectedVolume = 0,
    this.status = '',
    this.note = '',
    this.createdAt,
  });

  final String id;

  /// `YYYY-MM-DD`.
  final String date;
  final String district;
  final int expectedVolume;

  /// REQUESTED | APPROVED | REJECTED | SCHEDULED.
  final String status;
  final String note;
  final DateTime? createdAt;

  factory DistributionPlan.fromJson(Map<String, dynamic> j) => DistributionPlan(
    id: _str(j, 'id'),
    date: _str(j, 'date'),
    district: _str(j, 'district'),
    expectedVolume: _int(j, 'expectedVolume'),
    status: _str(j, 'status'),
    note: _str(j, 'note'),
    createdAt: _date(j, 'createdAt'),
  );

  static List<DistributionPlan> listFrom(Map<String, dynamic> data) => [
    for (final r in _list(data['items']))
      if (_str(r, 'id').isNotEmpty) DistributionPlan.fromJson(r),
  ];
}

// ── Kurye detayı ve cihaz (GET agency/couriers/{courierId}) ──────────────

class CourierDevice {
  const CourierDevice({
    this.model = '',
    this.os = '',
    this.appVersion = '',
    this.lastSeenAt,
    this.permissions = const {},
  });

  final String model;
  final String os;
  final String appVersion;
  final DateTime? lastSeenAt;

  /// location | backgroundLocation | camera | notifications → izin var mı.
  final Map<String, bool> permissions;

  factory CourierDevice.fromJson(Map<String, dynamic> j) => CourierDevice(
    model: _str(j, 'model'),
    os: _str(j, 'os'),
    appVersion: _str(j, 'appVersion'),
    lastSeenAt: _date(j, 'lastSeenAt'),
    permissions: {
      for (final e in _map(j['permissions']).entries)
        if (e.value is bool) e.key: e.value as bool,
    },
  );
}

class CourierProfile {
  const CourierProfile({
    required this.courierId,
    this.plate = '',
    this.vehicleType = '',
    this.vehicleModel = '',
    this.device,
  });

  final String courierId;
  final String plate;
  final String vehicleType;
  final String vehicleModel;

  /// Kurye hiç giriş yapmadıysa null.
  final CourierDevice? device;

  factory CourierProfile.fromJson(Map<String, dynamic> j) {
    final device = j['device'];
    return CourierProfile(
      courierId: _str(j, 'courierId'),
      plate: _str(j, 'plate'),
      vehicleType: _str(j, 'vehicleType'),
      vehicleModel: _str(j, 'vehicleModel'),
      device: device is Map
          ? CourierDevice.fromJson(Map<String, dynamic>.from(device))
          : null,
    );
  }
}

// ── Toplu ürün eşleştirme (POST branch/shipments/product-match) ──────────

class ProductMatchResult {
  const ProductMatchResult({this.matched = 0, this.failed = const []});

  final int matched;
  final List<({String shipmentId, String code})> failed;

  factory ProductMatchResult.fromJson(Map<String, dynamic> j) =>
      ProductMatchResult(
        matched: _int(j, 'matched'),
        failed: [
          for (final f in _list(j['failed']))
            (shipmentId: _str(f, 'shipmentId'), code: _str(f, 'code')),
        ],
      );
}
