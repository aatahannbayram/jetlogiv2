import '../api/branch_models.dart';

/// Demo şube girişinin (`sube@dijigoo.test`) örnek verisi. Yalnız
/// `BranchWorkspace.demo` açıkken kullanılır; canlı oturumda sunucu boş
/// dönerse ekran boş kalır, bu veriye düşülmez.

const _ali = CourierRef(id: 'demo-c1', name: 'Ali Can', code: 'KRY-001');

const kSubeDemoDashboard = BranchDashboard(
  branchName: 'Güney Acente',
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
      liveStatus: 'ACTIVE',
      holdingCount: 9,
      latitude: 37.7765,
      longitude: 29.0864,
    ),
    BranchCourierLive(
      id: 'demo-c3',
      name: 'Ece Yılmaz',
      code: 'KRY-003',
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
    ),
    const BranchShipmentRow(
      shipmentId: 'demo-s2',
      shipmentNumber: 'JL100238547',
      recipientName: 'Ayşe Demir',
      district: 'Pamukkale',
      stage: BranchStage.inDistribution,
      courier: _ali,
    ),
    const BranchShipmentRow(
      shipmentId: 'demo-s3',
      shipmentNumber: 'JL100238548',
      recipientName: 'Mehmet Kaya',
      district: 'Merkezefendi',
      highPriority: true,
      late: true,
    ),
    const BranchShipmentRow(
      shipmentId: 'demo-s4',
      shipmentNumber: 'JL100238549',
      recipientName: 'Zeynep Arslan',
      district: 'Pamukkale',
      stage: BranchStage.inQueue,
      pendingCourierName: 'Mert Demir',
    ),
    const BranchShipmentRow(
      shipmentId: 'demo-s5',
      shipmentNumber: 'JL100238550',
      recipientName: 'Elif Koç',
      district: 'Honaz',
    ),
    BranchShipmentRow(
      shipmentId: 'demo-s6',
      shipmentNumber: 'JL100238551',
      recipientName: 'Fatma Şahin',
      district: 'Merkezefendi',
      windowStart: DateTime(2026, 1, 1, 14),
      windowEnd: DateTime(2026, 1, 1, 16),
    ),
    const BranchShipmentRow(
      shipmentId: 'demo-s7',
      shipmentNumber: 'JL100238552',
      recipientName: 'Can Yıldız',
      district: 'Pamukkale',
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
  attemptedShipments: 124,
  deliveredShipments: 109,
  failedAttempts: 21,
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
    documentStatus: 'COMPLETE',
    operationReady: true,
  ),
  CourierCompliance(
    id: 'demo-c2',
    name: 'Mert Demir',
    documentStatus: 'MISSING',
    missing: 2,
  ),
];
