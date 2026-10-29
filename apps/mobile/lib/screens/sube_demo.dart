import '../api/branch_models.dart';
import '../training_port.dart';

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
  counts: [
    StockCount(
      id: 'demo-count-r',
      number: 'SAY-DEMO-0042',
      statusCode: 'REVIEW',
      warehouseName: 'Şube Deposu',
      varianceLineCount: 2,
    ),
    StockCount(
      id: 'demo-count-p',
      number: 'SAY-DEMO-0039',
      statusCode: 'POSTED',
      warehouseName: 'Şube Deposu',
    ),
    StockCount(
      id: 'demo-count-c',
      number: 'SAY-DEMO-0035',
      statusCode: 'CANCELLED',
      warehouseName: 'Şube Deposu',
      varianceLineCount: 1,
    ),
  ],
);

/// Demo geçmiş sayım satırları (mutabakat ekranı).
const kSubeDemoCountDetails = {
  'demo-count-r': CountDetail(
    capabilities: BranchCapabilities.all,
    count: StockCount(
      id: 'demo-count-r',
      number: 'SAY-DEMO-0042',
      statusCode: 'REVIEW',
      warehouseName: 'Şube Deposu',
      varianceLineCount: 2,
    ),
    lines: [
      CountLine(
        id: 'r1',
        name: 'POS cihazı',
        expected: 10,
        counted: 9,
        reasonCode: 'DAMAGE',
      ),
      CountLine(id: 'r2', name: 'SIM kart', expected: 30, counted: 31),
      CountLine(id: 'r3', name: 'Kart okuyucu', expected: 5, counted: 5),
    ],
  ),
  'demo-count-p': CountDetail(
    capabilities: BranchCapabilities.all,
    count: StockCount(
      id: 'demo-count-p',
      number: 'SAY-DEMO-0039',
      statusCode: 'POSTED',
      warehouseName: 'Şube Deposu',
    ),
    lines: [CountLine(id: 'p1', name: 'POS cihazı', expected: 12, counted: 12)],
  ),
};

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
    editable: true,
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

const _demoBranchTrainings = [
  LearnerTraining(
    id: 'demo-lt1',
    title: 'Şube açılış kontrol listesi',
    summary: 'Güne başlamadan önce yapılacak 8 kontrol.',
    primaryType: 'VIDEO',
    category: 'OPERATION',
    mandatory: true,
    lessonCount: 3,
    lessonTypes: ['VIDEO'],
    durationSeconds: 600,
    status: 'IN_PROGRESS',
    progressPercent: 60,
  ),
  LearnerTraining(
    id: 'demo-lt2',
    title: 'Kart teslimatında kimlik doğrulama',
    summary: 'Alıcıyı doğrulama adımları ve sık hatalar.',
    primaryType: 'VIDEO',
    category: 'COMPLIANCE',
    mandatory: true,
    lessonCount: 2,
    lessonTypes: ['VIDEO', 'QUIZ'],
    durationSeconds: 420,
    overdue: true,
  ),
  LearnerTraining(
    id: 'demo-lt3',
    title: 'KVKK ve müşteri verisi',
    summary: 'Şubede kişisel veriyle çalışma kuralları.',
    primaryType: 'PDF',
    category: 'COMPLIANCE',
    lessonCount: 1,
    lessonTypes: ['PDF'],
    durationSeconds: 300,
    status: 'COMPLETED',
    progressPercent: 100,
  ),
  LearnerTraining(
    id: 'demo-lt5',
    title: 'Zimmet ve teslim akışı',
    summary: 'Üç kısa ders ve bir sınav.',
    primaryType: 'VIDEO',
    category: 'OPERATION',
    lessonCount: 3,
    lessonTypes: ['VIDEO', 'TEXT', 'QUIZ'],
    durationSeconds: 540,
    sequentialLessons: true,
  ),
  LearnerTraining(
    id: 'demo-lt4',
    title: 'Haftalık operasyon toplantısı',
    summary: 'Bölge müdürüyle canlı oturum.',
    primaryType: 'LIVE',
    category: 'OPERATION',
    lessonCount: 1,
    lessonTypes: ['LIVE'],
    durationSeconds: 1800,
  ),
];

const _demoCustomerTrainings = [
  LearnerTraining(
    id: 'demo-lc1',
    title: 'Banka kartı teslim süreci',
    summary: 'Müşteriye özel teslim ve iade kuralları.',
    primaryType: 'PDF',
    category: 'CUSTOMER_PROCESS',
    lessonCount: 1,
    lessonTypes: ['PDF'],
    durationSeconds: 480,
  ),
];

/// Demo Eğitim Merkezi sekmesi.
TrainingCenterData kSubeDemoTrainingCenter(String targetType) {
  if (targetType == 'COURIER') {
    return const TrainingCenterData(
      targetType: 'COURIER',
      managed: kSubeDemoTrainings,
    );
  }
  final list = [
    for (final t
        in targetType == 'CUSTOMER_PROCESS'
            ? _demoCustomerTrainings
            : _demoBranchTrainings)
      // Dersli örnek yalnız oynatıcı açıkken (bkz. trainingPlayerEnabled).
      if (trainingPlayerEnabled || t.id != 'demo-lt5') t,
  ];
  return TrainingCenterData(
    targetType: targetType,
    learner: list,
    hasSummary: true,
    total: list.length,
    completed: list.where((t) => t.completed).length,
    mandatoryPending: list.where((t) => t.mandatory && !t.completed).length,
    overdue: list.where((t) => t.overdue).length,
  );
}

/// Demo eğitim detayı: içerik metni (demo'da bağlantı yok). Dersli
/// eğitimde [doneLessons] tamamlanan dersleri işaretler; sıralı derste
/// önceki zorunlu ders bitmeden sonraki kilitlidir.
LearnerTraining? kSubeDemoTrainingDetail(
  String id, {
  Set<String> doneLessons = const {},
  bool preview = false,
}) {
  final managed = kSubeDemoTrainings.where((t) => t.id == id).firstOrNull;
  if (managed != null) {
    return LearnerTraining(
      id: managed.id,
      title: managed.title,
      mandatory: managed.mandatory,
      preview: true,
      contentBody:
          'Bu demo kurye eğitimidir. Kurye uygulamasında bu metin ve '
          'içerik bağlantısı görünür.',
    );
  }
  final t = [
    ..._demoBranchTrainings,
    ..._demoCustomerTrainings,
  ].where((x) => x.id == id).firstOrNull;
  if (t == null) return null;
  final lessons = id == 'demo-lt5'
      ? _demoLessons(doneLessons)
      : const <TrainingLesson>[];
  final allDone =
      lessons.isNotEmpty &&
      lessons.where((l) => l.required).every((l) => l.completed);
  return LearnerTraining(
    id: t.id,
    title: t.title,
    summary: t.summary,
    description: t.summary,
    primaryType: t.primaryType,
    category: t.category,
    mandatory: t.mandatory,
    lessonCount: t.lessonCount,
    lessonTypes: t.lessonTypes,
    durationSeconds: t.durationSeconds,
    dueAt: t.dueAt,
    overdue: t.overdue,
    status: allDone ? 'COMPLETED' : t.status,
    progressPercent: t.progressPercent,
    sequentialLessons: t.sequentialLessons,
    lessons: lessons,
    preview: preview,
    acknowledgementText: 'Eğitimi okudum/izledim ve anladım.',
    contentBody: lessons.isNotEmpty
        ? null
        : 'Bu demo eğitimidir. Canlıda içerik (video, PDF ya da canlı oturum '
              'bağlantısı) burada açılır.',
  );
}

List<TrainingLesson> _demoLessons(Set<String> done) {
  const base = [
    TrainingLesson(
      id: 'demo-ls1',
      order: 1,
      title: 'Zimmetin iki tarafı',
      contentType: 'VIDEO',
      durationSeconds: 240,
      required: true,
      contentBody:
          'Şube gönderiyi kuryeye atar; zimmet, kurye gönderi numarasını '
          'okutup kabul edince kesinleşir. Demo videosu yerine bu özet '
          'gösterilir.',
    ),
    TrainingLesson(
      id: 'demo-ls2',
      order: 2,
      title: 'Teslimde fotoğraf kuralları',
      contentType: 'TEXT',
      durationSeconds: 120,
      required: true,
      contentBody:
          'Başarılı ziyarette 3 fotoğraf, konum ve ziyaret anketi gerekir. '
          'Fotoğraflar yalnız kamerayla çekilir; galeri kapalıdır.',
    ),
    TrainingLesson(
      id: 'demo-ls3',
      order: 3,
      title: 'Kısa sınav',
      contentType: 'QUIZ',
      durationSeconds: 180,
      required: true,
      passingScore: 70,
      quiz: TrainingQuiz(
        questions: [
          (
            id: 'q1',
            text: 'Zimmet ne zaman kesinleşir?',
            multiple: false,
            options: [
              (id: 'a', text: 'Şube kuryeyi atayınca'),
              (id: 'b', text: 'Kurye gönderiyi okutup kabul edince'),
              (id: 'c', text: 'Gün sonunda'),
            ],
          ),
          (
            id: 'q2',
            text: 'Başarılı ziyarette hangileri gerekir?',
            multiple: true,
            options: [
              (id: 'a', text: '3 fotoğraf'),
              (id: 'b', text: 'Galeriden seçilmiş fotoğraf'),
              (id: 'c', text: 'Konum ve ziyaret anketi'),
            ],
          ),
        ],
      ),
    ),
  ];
  var previousDone = true;
  return [
    for (final l in base)
      () {
        final completed = done.contains(l.id);
        final lesson = TrainingLesson(
          id: l.id,
          order: l.order,
          title: l.title,
          contentType: l.contentType,
          durationSeconds: l.durationSeconds,
          required: l.required,
          passingScore: l.passingScore,
          contentBody: l.contentBody,
          quiz: l.quiz,
          completed: completed,
          locked: !previousDone,
        );
        previousDone = previousDone && completed;
        return lesson;
      }(),
  ];
}

/// Demo sınav puanı (canlıda puan sunucuda hesaplanır). Doğru cevaplar ve
/// açıklama yalnız geçilince döner.
QuizResult kSubeDemoGradeQuiz(
  String lessonId,
  Map<String, List<String>> answers,
) {
  const key = {
    'q1': ['b'],
    'q2': ['a', 'c'],
  };
  var correct = 0;
  final results = <({String questionId, bool correct, String? explanation})>[];
  for (final e in key.entries) {
    final given = [...?answers[e.key]]..sort();
    final ok = given.join(',') == e.value.join(',');
    if (ok) correct++;
    results.add((questionId: e.key, correct: ok, explanation: null));
  }
  final score = (correct * 100 / key.length).round();
  final passed = score >= 70;
  return QuizResult(
    score: score,
    passingScore: 70,
    passed: passed,
    bestScore: score,
    attempts: 1,
    results: [
      for (final r in results)
        (
          questionId: r.questionId,
          correct: r.correct,
          explanation: passed
              ? (r.questionId == 'q1'
                    ? 'Zimmet çift taraflıdır: kurye kabul edene kadar kesinleşmez.'
                    : 'Galeri kapalıdır; fotoğraf yalnız kamerayla çekilir.')
              : null,
        ),
    ],
  );
}

const List<TrainingFaq> kSubeDemoFaq = [
  (
    question: 'Zorunlu eğitimi bitirmezsem ne olur?',
    answer:
        'Hiçbir işlem kilitlenmez; panelde uyarı görünür ve son tarih '
        'geçince geciken olarak işaretlenir.',
  ),
  (
    question: 'Eğitim neden tamamlanmadı görünüyor?',
    answer:
        'Her eğitimin en kısa izleme süresi vardır. Süre dolmadan '
        'tamamlanmış sayılmaz.',
  ),
  (
    question: 'Kuryelere eğitim nasıl gönderilir?',
    answer:
        'Kurye sekmesinde "Yeni eğitim" ile metin eğitimi yayımlanır; '
        'kuryelere bildirim gider.',
  ),
];

/// Demo şube sözleşme / evrak durumu (canlıda uç NOT_AVAILABLE döner).
const kSubeDemoBranchDocs = BranchDocs(
  schemaReady: true,
  contracts: [
    (type: 'PARTNERSHIP', status: 'SIGNED'),
    (type: 'KVKK', status: 'SIGNED'),
    (type: 'SLA', status: 'PENDING'),
  ],
  documents: [
    (type: 'IDENTITY', status: 'APPROVED'),
    (type: 'TAX_PLATE', status: 'APPROVED'),
    (type: 'AUTHORIZATION', status: 'IN_REVIEW'),
    (type: 'SIGNATURE_CIRCULAR', status: 'MISSING'),
    (type: 'BRANCH_PHOTO', status: 'APPROVED'),
  ],
);

/// Demo fatura (canlı uçta fatura modeli yok: `schemaReady: false`).
typedef DemoInvoice = ({
  String id,
  String number,
  String period,
  num amount,
  num vat,
  String status,
  DateTime due,
  List<({String label, int quantity, num amount})> lines,
});

final List<DemoInvoice> kSubeDemoInvoices = [
  (
    id: 'demo-inv-10',
    number: 'DGF-2026-0010',
    period: '2026-10',
    amount: 18450,
    vat: 3690,
    status: 'PENDING',
    due: DateTime(2026, 11, 15),
    lines: const [
      (label: 'Kart teslimatı', quantity: 410, amount: 14350),
      (label: 'POS teslimatı', quantity: 82, amount: 4100),
    ],
  ),
  (
    id: 'demo-inv-09',
    number: 'DGF-2026-0009',
    period: '2026-09',
    amount: 17120,
    vat: 3424,
    status: 'PAID',
    due: DateTime(2026, 10, 15),
    lines: const [
      (label: 'Kart teslimatı', quantity: 388, amount: 13580),
      (label: 'POS teslimatı', quantity: 71, amount: 3540),
    ],
  ),
];

/// Demo: kuryelerin bildirdiği zimmet uyuşmazlıkları.
final List<CustodyDispute> kSubeDemoCustodyDisputes = [
  CustodyDispute(
    id: 'demo-cd1',
    typeCode: 'MISSING',
    statusCode: 'NEW',
    ticketNumber: 'TKT-261029-4F2A91C0',
    shipmentNumber: 'JD2026102900311',
    transferNumber: 'TRF-2610-0142',
    note: 'Listede var, rafta bulamadım.',
    courierName: 'Mert Kaya',
    createdAt: DateTime.now().subtract(const Duration(minutes: 40)),
  ),
  CustodyDispute(
    id: 'demo-cd2',
    typeCode: 'DAMAGED',
    statusCode: 'IN_PROGRESS',
    ticketNumber: 'TKT-261029-91BD07E2',
    shipmentNumber: 'JD2026102900287',
    transferNumber: 'TRF-2610-0139',
    note: 'Koli ezik, içerik kontrol edilmeli.',
    courierName: 'Ayşe Demir',
    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
  ),
  CustodyDispute(
    id: 'demo-cd3',
    typeCode: 'EXCESS',
    statusCode: 'RESOLVED',
    ticketNumber: 'TKT-261028-0C55E1AA',
    scanCode: 'JD2026102800954',
    courierName: 'Mert Kaya',
    createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
    resolvedAt: DateTime.now().subtract(const Duration(hours: 20)),
  ),
];
