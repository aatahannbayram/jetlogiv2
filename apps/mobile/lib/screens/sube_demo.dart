import '../api/branch_models.dart';

/// Demo şube girişinin (`sube@dijigoo.test`) örnek verisi. Yalnız
/// `BranchWorkspace.demo` açıkken kullanılır; canlı oturumda sunucu boş
/// dönerse ekran boş kalır, bu veriye düşülmez.

const _ali = CourierRef(id: 'demo-c1', name: 'Ali Can', code: 'KRY-001');

const kSubeDemoDashboard = BranchDashboard(
  branchName: 'Güney Acente',
  branchCode: 'DNZ-014',
  couriersActive: 3,
  couriersTotal: 4,
  todayToDeliver: 7,
  deliveredToday: 19,
  cancelledToday: 3,
  pending: 4,
  returnToCenter: 2,
  urgent: 1,
  approvalsHandover: 1,
  approvalsReturns: 1,
  courierList: [
    BranchCourierLive(
      id: 'demo-c1',
      name: 'Ali Can',
      code: 'KRY-001',
      phone: '+905000000101',
      liveStatus: 'ACTIVE',
      holdingCount: 12,
      overdueCount: 1,
      latitude: 37.7830,
      longitude: 29.0963,
    ),
    BranchCourierLive(
      id: 'demo-c2',
      name: 'Mert Demir',
      code: 'KRY-002',
      phone: '+905000000102',
      liveStatus: 'ACTIVE',
      holdingCount: 9,
      latitude: 37.7765,
      longitude: 29.0864,
    ),
    BranchCourierLive(
      id: 'demo-c3',
      name: 'Ece Yılmaz',
      code: 'KRY-003',
      phone: '+905000000103',
      liveStatus: 'BREAK',
      holdingCount: 7,
      latitude: 37.7701,
      longitude: 29.1012,
    ),
    BranchCourierLive(id: 'demo-c4', name: 'Barış Arslan', code: 'KRY-004'),
  ],
);

final kSubeDemoBoard = DispatchBoard(
  capabilities: BranchCapabilities.all,
  kpis: const DispatchKpis(
    total: 7,
    assigned: 3,
    unassigned: 4,
    late: 1,
    priority: 1,
    dispatchedToday: 2,
  ),
  rows: [
    const BranchShipmentRow(
      shipmentId: 'demo-s1',
      shipmentNumber: 'JL100238546',
      recipientName: 'Ahmet Yılmaz',
      district: 'Merkezefendi',
      neighborhood: 'Sırakapılar',
      city: 'Denizli',
      addressLine: 'Sırakapılar Mah. 1520 Sk. No: 12',
      product: 'POS cihazı',
      productCode: 'POS-A920',
      packageCount: 1,
    ),
    const BranchShipmentRow(
      shipmentId: 'demo-s2',
      shipmentNumber: 'JL100238547',
      recipientName: 'Ayşe Demir',
      district: 'Pamukkale',
      city: 'Denizli',
      addressLine: 'Kınıklı Mah. Hüseyin Yılmaz Cd. No: 4',
      product: 'Kredi kartı',
      productCode: 'CARD-STD',
      packageCount: 1,
      dispatches: 1,
      maxDispatches: 3,
      stage: BranchStage.inDistribution,
      courier: _ali,
    ),
    const BranchShipmentRow(
      shipmentId: 'demo-s3',
      shipmentNumber: 'JL100238548',
      recipientName: 'Mehmet Kaya',
      district: 'Merkezefendi',
      city: 'Denizli',
      addressLine: 'Bahçelievler Mah. 2040 Sk. No: 7',
      product: 'SIM kart',
      productCode: 'SIM-5G',
      packageCount: 1,
      highPriority: true,
      late: true,
    ),
    const BranchShipmentRow(
      shipmentId: 'demo-s4',
      shipmentNumber: 'JL100238549',
      recipientName: 'Zeynep Arslan',
      district: 'Pamukkale',
      city: 'Denizli',
      addressLine: 'Kınıklı Mah. 6001 Sk. No: 18',
      product: 'Kart okuyucu',
      productCode: 'RDR-01',
      packageCount: 2,
      stage: BranchStage.inQueue,
      pendingCourierName: 'Mert Demir',
    ),
    const BranchShipmentRow(
      shipmentId: 'demo-s5',
      shipmentNumber: 'JL100238550',
      recipientName: 'Elif Koç',
      district: 'Honaz',
      city: 'Denizli',
      addressLine: 'Cumhuriyet Mah. Atatürk Cd. No: 3',
      product: 'POS cihazı',
      productCode: 'POS-A920',
      packageCount: 1,
    ),
    BranchShipmentRow(
      shipmentId: 'demo-s6',
      shipmentNumber: 'JL100238551',
      recipientName: 'Fatma Şahin',
      district: 'Merkezefendi',
      city: 'Denizli',
      addressLine: 'Saraylar Mah. İstiklal Cd. No: 21',
      product: 'Kredi kartı',
      productCode: 'CARD-STD',
      packageCount: 1,
      windowStart: DateTime(2026, 1, 1, 14),
      windowEnd: DateTime(2026, 1, 1, 16),
    ),
    const BranchShipmentRow(
      shipmentId: 'demo-s7',
      shipmentNumber: 'JL100238552',
      recipientName: 'Can Yıldız',
      district: 'Pamukkale',
      city: 'Denizli',
      addressLine: 'Zeytinköy Mah. 3010 Sk. No: 9',
      product: 'SIM kart',
      productCode: 'SIM-5G',
      packageCount: 1,
      dispatches: 2,
      maxDispatches: 3,
      stage: BranchStage.inDistribution,
      courier: _ali,
    ),
  ],
);

const kSubeDemoPending = PendingData(
  total: 4,
  handovers: [
    PendingItem(
      shipmentId: 'demo-s4',
      shipmentNumber: 'JL100238549',
      recipientName: 'Zeynep Arslan',
      courierName: 'Mert Demir',
    ),
  ],
  returns: [
    PendingItem(
      shipmentId: 'demo-s8',
      shipmentNumber: 'JL100238553',
      recipientName: 'Deniz Aksoy',
      courierName: 'Ali Can',
    ),
  ],
  endOfDay: [
    PendingItem(
      shipmentId: 'demo-s2',
      shipmentNumber: 'JL100238547',
      recipientName: 'Ayşe Demir',
      courierName: 'Ali Can',
      resultMissing: true,
    ),
  ],
  overdue: [
    PendingItem(
      shipmentId: 'demo-s3',
      shipmentNumber: 'JL100238548',
      recipientName: 'Mehmet Kaya',
      overdue: true,
    ),
  ],
);

const kSubeDemoOptions = DispatchOptions(
  couriers: [
    CourierOption(id: 'demo-c1', name: 'Ali Can', code: 'KRY-001'),
    CourierOption(id: 'demo-c2', name: 'Mert Demir', code: 'KRY-002'),
    CourierOption(
      id: 'demo-c3',
      name: 'Ece Yılmaz',
      code: 'KRY-003',
      eligible: false,
    ),
  ],
);

const kSubeDemoCancelReasons = [
  ReasonOption(code: 'WRONG_COURIER', name: 'Yanlış kuryeye verildi'),
  ReasonOption(code: 'COURIER_UNAVAILABLE', name: 'Kurye müsait değil'),
];

const _demoWarehouse = BranchWarehouse(
  id: 'demo-w1',
  name: 'Şube Deposu',
  code: 'DP-01',
);

const kSubeDemoCounts = CountsData(
  warehouses: [_demoWarehouse],
  capabilities: BranchCapabilities.all,
  reasonCodes: ['MISCOUNT', 'DAMAGE', 'LOSS', 'FOUND', 'OTHER'],
);

const kSubeDemoCount = CountDetail(
  capabilities: BranchCapabilities.all,
  count: StockCount(
    id: 'demo-count',
    number: 'SAY-DEMO-001',
    statusCode: 'IN_PROGRESS',
    warehouseName: 'Şube Deposu',
  ),
  lines: [
    CountLine(id: 'demo-l1', name: 'POS cihazı', expected: 12, counted: 11),
    CountLine(id: 'demo-l2', name: 'SIM kart', expected: 40, counted: 40),
    CountLine(id: 'demo-l3', name: 'Kart okuyucu', expected: 6, counted: 7),
  ],
);

const kSubeDemoOutgoing = OutgoingOptions(
  transferTypes: ['RETURN', 'PHYSICAL_DOCUMENT', 'EQUIPMENT'],
  centers: [TransferCenter(id: 'demo-hq', name: 'Merkez Depo', code: 'MRK-01')],
  recent: [
    BranchTransfer(
      id: 'demo-t1',
      transferNumber: 'TRF-DEMO-001',
      statusCode: 'DISPATCHED',
      type: 'RETURN',
      partyName: 'Merkez Depo',
      itemCount: 38,
    ),
  ],
);

const kSubeDemoLabels = LabelWorkspace(
  warehouses: [_demoWarehouse],
  labelTypes: ['CASE', 'PACKAGE', 'ITEM'],
);

PerformanceData kSubeDemoPerformance(String range) => PerformanceData(
  range: range,
  attemptedShipments: range == 'today' ? 22 : 124,
  deliveredShipments: range == 'today' ? 19 : 109,
  failedAttempts: range == 'today' ? 3 : 21,
  activeCouriers: 4,
  deliveryRate: 87.9,
  firstAttemptRate: 81.4,
  averageDeliveryMinutes: 34,
  slaCompliance: 92.5,
  couriers: const [
    CourierPerformance(
      courierId: 'demo-c1',
      name: 'Ali Can',
      shipments: 48,
      delivered: 44,
      failed: 6,
      deliveryRate: 91.7,
      firstAttemptRate: 85.4,
    ),
    CourierPerformance(
      courierId: 'demo-c2',
      name: 'Mert Demir',
      shipments: 41,
      delivered: 35,
      failed: 8,
      deliveryRate: 85.4,
      firstAttemptRate: 78.0,
    ),
  ],
  daily: const [
    (day: '2026-01-01', delivered: 18, failed: 3),
    (day: '2026-01-02', delivered: 16, failed: 4),
    (day: '2026-01-03', delivered: 21, failed: 2),
  ],
);

const kSubeDemoInbox = [
  InboxItem(
    id: 'demo-n1',
    category: 'HANDOVER',
    severity: 'WARNING',
    body: 'Mert Demir zimmeti henüz kabul etmedi (JL100238549).',
  ),
  InboxItem(
    id: 'demo-n2',
    category: 'COUNT',
    body: 'Merkez yeni bir sayım emri açtı.',
    read: true,
  ),
];

const kSubeDemoShiftDay = BranchShiftDay(
  courierCount: 4,
  plannedCount: 3,
  onShiftNow: 2,
  plannedNotStarted: 1,
  onLeave: 1,
  couriers: [
    ShiftCourierRow(
      courierId: 'demo-c1',
      name: 'Ali Can',
      planStatus: 'PLANNED',
      ranges: '09:00–18:00',
      onShiftNow: true,
    ),
    ShiftCourierRow(
      courierId: 'demo-c2',
      name: 'Mert Demir',
      planStatus: 'PLANNED',
      ranges: '09:00–18:00',
      flags: ['PLANNED_NOT_STARTED'],
    ),
    ShiftCourierRow(
      courierId: 'demo-c3',
      name: 'Ece Yılmaz',
      planStatus: 'PLANNED',
      ranges: '10:00–19:00',
      onShiftNow: true,
      onBreak: true,
    ),
    ShiftCourierRow(
      courierId: 'demo-c4',
      name: 'Barış Arslan',
      planStatus: 'ON_LEAVE',
    ),
  ],
);

const kSubeDemoLeaves = [
  LeaveRequest(
    id: 'demo-lv1',
    courierName: 'Ece Yılmaz',
    date: '2026-01-05',
    note: 'Doktor randevusu',
  ),
];

const kSubeDemoSmsTemplates = [
  SmsTemplate(
    key: 'DELIVERY_TODAY',
    name: 'Bugün teslimat',
    body: 'Gönderiniz bugün dağıtımda. Dijigoo',
  ),
];

const kSubeDemoTrainings = [
  ManagedTraining(
    id: 'demo-tr1',
    title: 'Teslimatta kimlik kontrolü',
    mandatory: true,
    learners: 4,
    completed: 3,
  ),
];

const kSubeDemoCompliance = [
  CourierCompliance(
    id: 'demo-c1',
    name: 'Ali Can',
    code: 'KRY-001',
    status: 'WORKING',
    vehicleType: 'MOTORCYCLE',
    documentStatus: 'COMPLETE',
    required: 4,
    approved: 4,
    consentsTotal: 2,
    consentsAccepted: 2,
    operationReady: true,
    documents: [
      ComplianceDoc(
        code: 'IDENTITY',
        titleTr: 'Kimlik',
        titleEn: 'ID card',
        status: 'APPROVED',
        required: true,
      ),
      ComplianceDoc(
        code: 'DRIVING_LICENSE',
        titleTr: 'Ehliyet',
        titleEn: 'Driving licence',
        status: 'APPROVED',
        required: true,
      ),
      ComplianceDoc(
        code: 'CRIMINAL_RECORD',
        titleTr: 'Adli sicil kaydı',
        titleEn: 'Criminal record',
        status: 'APPROVED',
        required: true,
      ),
      ComplianceDoc(
        code: 'VEHICLE_REGISTRATION',
        titleTr: 'Araç ruhsatı',
        titleEn: 'Vehicle registration',
        status: 'APPROVED',
        required: true,
      ),
    ],
  ),
  CourierCompliance(
    id: 'demo-c2',
    name: 'Mert Demir',
    code: 'KRY-002',
    status: 'WORKING',
    vehicleType: 'MOTORCYCLE',
    documentStatus: 'MISSING',
    required: 4,
    approved: 2,
    missing: 2,
    consentsTotal: 2,
    consentsAccepted: 1,
    documents: [
      ComplianceDoc(
        code: 'IDENTITY',
        titleTr: 'Kimlik',
        titleEn: 'ID card',
        status: 'APPROVED',
        required: true,
      ),
      ComplianceDoc(
        code: 'DRIVING_LICENSE',
        titleTr: 'Ehliyet',
        titleEn: 'Driving licence',
        status: 'EXPIRED',
        required: true,
      ),
      ComplianceDoc(
        code: 'CRIMINAL_RECORD',
        titleTr: 'Adli sicil kaydı',
        titleEn: 'Criminal record',
        status: 'MISSING',
        required: true,
      ),
      ComplianceDoc(
        code: 'VEHICLE_REGISTRATION',
        titleTr: 'Araç ruhsatı',
        titleEn: 'Vehicle registration',
        status: 'APPROVED',
        required: true,
      ),
    ],
  ),
];

/// Demo kurye listesi (agency/couriers biçiminde). Selin pasif örnektir.
const kSubeDemoRoster = [
  BranchCourier(
    id: 'demo-c1',
    name: 'Ali Can',
    code: 'KRY-001',
    phone: '+905000000101',
    status: 'WORKING',
    workModel: 'FULL_TIME',
    vehicleType: 'MOTORCYCLE',
    city: 'Denizli',
    district: 'Merkezefendi',
    primary: true,
    shipmentCount: 12,
  ),
  BranchCourier(
    id: 'demo-c2',
    name: 'Mert Demir',
    code: 'KRY-002',
    phone: '+905000000102',
    status: 'WORKING',
    workModel: 'FULL_TIME',
    vehicleType: 'MOTORCYCLE',
    city: 'Denizli',
    district: 'Pamukkale',
    primary: true,
    shipmentCount: 9,
  ),
  BranchCourier(
    id: 'demo-c3',
    name: 'Ece Yılmaz',
    code: 'KRY-003',
    phone: '+905000000103',
    status: 'WORKING',
    workModel: 'PART_TIME',
    vehicleType: 'CAR',
    city: 'Denizli',
    district: 'Honaz',
    shipmentCount: 7,
  ),
  BranchCourier(
    id: 'demo-c4',
    name: 'Barış Arslan',
    code: 'KRY-004',
    phone: '+905000000104',
    status: 'AVAILABLE',
    workModel: 'FULL_TIME',
    vehicleType: 'MOTORCYCLE',
    city: 'Denizli',
    district: 'Merkezefendi',
  ),
  BranchCourier(
    id: 'demo-c5',
    name: 'Selin Kara',
    code: 'KRY-005',
    status: 'PASSIVE',
    workModel: 'PART_TIME',
    vehicleType: 'BICYCLE',
    city: 'Denizli',
    district: 'Pamukkale',
  ),
];

/// Demo kurye kartı; belirteç örnektir, doğrulamadan geçmez.
PartnerCard kSubeDemoCard(String id, String name, String code) => PartnerCard(
  token: 'JDC1.demo-$id.ornek',
  displayName: name,
  code: code,
  branchName: 'Güney Acente',
  statusCode: 'ACTIVE',
  complianceStatus: 'COMPLETE',
  active: true,
  issuedAt: DateTime(2026, 1, 1),
  expiresAt: DateTime(2027, 1, 1),
);

/// Demo kurye haritası: panodaki kuryeler ve ellerindeki gönderiler.
final kSubeDemoCourierMap = CourierMapData(
  generatedAt: DateTime(2026, 1, 1, 11, 40),
  couriers: [
    for (final c in kSubeDemoDashboard.courierList)
      (
        courier: c,
        shipments: switch (c.id) {
          'demo-c1' => const [
            MapShipment(
              shipmentId: 'demo-s2',
              shipmentNumber: 'JL100238547',
              statusCode: '4020',
              recipientName: 'Ayşe Demir',
              product: 'Kredi kartı',
              district: 'Pamukkale',
            ),
            MapShipment(
              shipmentId: 'demo-s7',
              shipmentNumber: 'JL100238552',
              statusCode: '4020',
              recipientName: 'Can Yıldız',
              product: 'SIM kart',
              district: 'Pamukkale',
              overdue: true,
            ),
          ],
          'demo-c2' => const [
            MapShipment(
              shipmentId: 'demo-s9',
              shipmentNumber: 'JL100238554',
              statusCode: '4020',
              recipientName: 'Selin Öztürk',
              product: 'POS cihazı',
              district: 'Merkezefendi',
            ),
          ],
          _ => const <MapShipment>[],
        },
      ),
  ],
);

/// Demo gönderi detayı: satırın kendisi, kurye önerileri ve son hareketler.
ShipmentDetail kSubeDemoShipmentDetail(BranchShipmentRow row) {
  final at = DateTime(2026, 1, 1, 9, 12);
  return ShipmentDetail(
    row: row,
    weightKg: 0.4,
    packageType: 'Zarf',
    dispatchReady: true,
    canAssign: row.stage == BranchStage.awaitingCourier,
    canChange:
        row.stage == BranchStage.inQueue ||
        row.stage == BranchStage.inDistribution,
    canCancel: row.stage == BranchStage.inQueue,
    suggestions: const [
      CourierSuggestion(
        id: 'demo-c1',
        name: 'Ali Can',
        code: 'KRY-001',
        status: 'ACTIVE',
        vehicleType: 'MOTORCYCLE',
        area: 'Merkezefendi, Denizli',
        regionFit: 'MATCH',
        activeJobs: 12,
        todayJobs: 19,
        etaMinutes: 14,
      ),
      CourierSuggestion(
        id: 'demo-c2',
        name: 'Mert Demir',
        code: 'KRY-002',
        status: 'ACTIVE',
        vehicleType: 'MOTORCYCLE',
        area: 'Pamukkale, Denizli',
        regionFit: 'PARTIAL',
        activeJobs: 9,
        todayJobs: 15,
        etaMinutes: 22,
      ),
      CourierSuggestion(
        id: 'demo-c3',
        name: 'Ece Yılmaz',
        code: 'KRY-003',
        status: 'ACTIVE',
        vehicleType: 'CAR',
        area: 'Honaz, Denizli',
        activeJobs: 7,
        todayJobs: 11,
      ),
    ],
    recent: [
      ShipmentEvent(
        code: 'BRANCH_RECEIVED',
        source: 'BRANCH',
        actor: 'Güney Acente',
        at: at,
      ),
      if (row.stage != BranchStage.awaitingCourier)
        ShipmentEvent(
          code: 'BRANCH_COURIER_HANDOVER_REQUESTED',
          source: 'BRANCH',
          actor: 'Güney Acente',
          at: at.add(const Duration(minutes: 48)),
        ),
      if (row.stage == BranchStage.inDistribution)
        ShipmentEvent(
          code: 'BRANCH_COURIER_HANDOVER_ACCEPTED',
          statusCode: '4020',
          source: 'COURIER',
          actor: row.courierName,
          at: at.add(const Duration(hours: 1, minutes: 5)),
        ),
    ],
  );
}

/// Demo etiket satırı (print-rows biçiminde). Müşteri adı örnektir.
Map<String, dynamic> kSubeDemoPrintRow(BranchShipmentRow row) => {
  'id': row.shipmentId,
  'shipmentNumber': row.shipmentNumber,
  'primaryBarcode': row.shipmentNumber,
  'orderNumber': 'SP-${row.shipmentNumber.substring(6)}',
  'referenceNo': null,
  'customer': {'name': 'Demo Müşteri A.Ş.'},
  'contractName': 'Kart dağıtım sözleşmesi',
  'serviceCode': 'STANDART',
  'slaStatusCode': row.late ? 'BREACHED' : 'ON_TIME',
  'recipientName': row.recipientName,
  'packageCount': row.packageCount,
  'destination': {
    'neighborhood': row.neighborhood,
    'districtName': row.district,
    'cityName': row.city,
    'addressLine': row.addressLine,
  },
};
