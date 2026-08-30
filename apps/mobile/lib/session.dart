import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/client.dart';
import 'api/models.dart';
import 'data/outbox.dart';
import 'data/vault.dart';
import 'models.dart';
import 'theme.dart';

final sessionProvider = ChangeNotifierProvider<SessionController>((ref) {
  return SessionController();
});

enum AppPhase { onboard, splash, activation, permissions, shift, main }

class SessionController extends ChangeNotifier {
  SessionController({
    OutboxStore? outbox,
    this.api,
    this.vault,
    this.waitForConfig = false,
    AppPhase? initialPhase,
  })  : outbox = outbox ?? OutboxStore(),
        phase = initialPhase ?? AppPhase.onboard {
    configReady = !waitForConfig;
    this.outbox.seedQueued(
      OutboxEvent(
        clientEventId: '00000000-0000-4000-a000-000000000001',
        operation: SyncOperation.taskTransition,
        subjectId: 't4',
        occurredAt: DateTime.utc(2026, 8, 25, 10, 12),
        sequence: 1,
        payload: const {'reason': 'ALICI_YOK', 'note': 'Alıcı yoktu'},
      ),
    );
  }

  final OutboxStore outbox;
  final MobileApi? api;
  final Vault? vault;
  final bool waitForConfig;

  AppConfig config = AppConfig.demo;
  bool configReady = true;
  bool liveApi = false;
  RoutePlanDto? routePlan;
  bool routeLoading = false;
  bool cipherOn = false;
  String? challengeId;

  AppPhase phase;
  bool demo = true;
  bool online = true;
  bool shiftOpen = false;
  bool shiftPhotoTaken = false;
  DateTime? shiftStartedAt;

  void setShiftOpen(bool value) {
    shiftOpen = value;
    if (value) shiftStartedAt = DateTime.now();
    notifyListeners();
  }

  String get shiftElapsedLabel {
    final started = shiftStartedAt;
    if (started == null) return '00:00';
    final d = DateTime.now().difference(started);
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  // Menü / new-screens demo state (local only, no backend — see docs/plan).
  String plate = '20 KR 841';

  final Set<int> _readNotifications = {};
  final notifications = <AppNotification>[
    AppNotification(
      title: 'Yeni durak atandı',
      body: 'DGO-8844 · Cumhuriyet Mah. 1. Sk. No:3',
      time: '14:41',
      icon: Icons.local_shipping_outlined,
      tint: Dg.greenBg,
      ink: Dg.green,
    ),
    AppNotification(
      title: 'Zimmet onaylandı',
      body: 'Şube zimmetinden 6 gönderi üstüne alındı.',
      time: '13:58',
      icon: Icons.inventory_2_outlined,
      tint: Dg.violetBg,
      ink: Dg.violet,
    ),
    AppNotification(
      title: 'Gönderim başarısız',
      body: 'DGO-8839 senkron edilemedi, kuyrukta bekliyor.',
      time: '12:20',
      icon: Icons.error_outline_rounded,
      tint: Dg.redBg,
      ink: Dg.red,
    ),
    AppNotification(
      title: 'Prim güncellendi',
      body: 'Bu hafta 40 teslim primine 6 teslim kaldı.',
      time: '09:05',
      icon: Icons.account_balance_wallet_outlined,
      tint: Dg.amberBg,
      ink: Dg.amber,
    ),
    AppNotification(
      title: 'Vardiya hatırlatması',
      body: 'Yarın 09:00 vardiyası atanmıştır.',
      time: 'Dün',
      icon: Icons.schedule_outlined,
      tint: Dg.blueBg,
      ink: Dg.blue,
    ),
  ];

  int get unreadNotifCount => notifications.length - _readNotifications.length;
  bool isNotifRead(int i) => _readNotifications.contains(i);
  void markNotificationRead(int i) {
    _readNotifications.add(i);
    notifyListeners();
  }

  void markAllNotificationsRead() {
    _readNotifications.addAll(List.generate(notifications.length, (i) => i));
    notifyListeners();
  }

  final depots = const [
    DepotOption(name: 'Merkez Depo', meta: 'Sanayi Mah. 3. Cd. No:22', count: 18),
    DepotOption(name: 'Güney Şube', meta: 'Kayalık Mah. No:4', count: 7),
    DepotOption(name: 'Çamlık Aktarma', meta: 'Çamlık Mah. Depo Blok B', count: 3),
  ];
  int? selectedDepot;
  static const _depotParcels = [
    DepotParcel(code: 'DGO-9012', name: 'Selin Uçar', weight: '1,2 kg'),
    DepotParcel(code: 'DGO-9013', name: 'Kerem Baş', weight: '0,4 kg'),
    DepotParcel(code: 'DGO-9014', name: 'Nazlı Ekin', weight: '3,8 kg'),
  ];
  List<DepotParcel> get depotPreview => selectedDepot == null ? const [] : _depotParcels;

  void pickDepot(int i) {
    selectedDepot = i;
    notifyListeners();
  }

  void confirmDepotPickup() {
    inventory.insertAll(
      0,
      _depotParcels.map((p) => InventoryItem(code: p.code, name: p.name, state: 'Bekleyen', done: false)),
    );
    selectedDepot = null;
    notifyListeners();
  }

  final inventory = <InventoryItem>[
    const InventoryItem(code: 'DGO-8841', name: 'Ahmet Yılmaz', state: 'Bekleyen', done: false),
    const InventoryItem(code: 'DGO-8842', name: 'Elif Koç', state: 'Bekleyen', done: false),
    const InventoryItem(code: 'DGO-8838', name: 'Burak Sarı', state: 'Teslim', done: true),
  ];

  int get inventoryPending => inventory.where((p) => !p.done).length;
  int get inventoryDone => inventory.where((p) => p.done).length;

  void addInventoryByCode(String code) {
    final v = code.trim();
    if (v.isEmpty) return;
    inventory.insert(0, InventoryItem(code: v, name: 'Yeni kayıt', state: 'Bekleyen', done: false));
    notifyListeners();
  }

  String zimmetMode = 'kurye';
  final zimmetScans = <({String code, String time})>[];

  List<CustodyItemDto> custodyItems = const [];
  bool custodyLoading = false;
  bool custodyHandoverPending = false;

  void setZimmetMode(String mode) {
    zimmetMode = mode;
    notifyListeners();
    if (mode == 'sube' && custodyItems.isEmpty) unawaited(loadCustody());
  }

  void addZimmetScan([String? code]) {
    final v = (code ?? '').trim();
    final label = v.isEmpty ? 'DGO-${9100 + zimmetScans.length * 7}' : v;
    final now = DateTime.now();
    zimmetScans.insert(0, (code: label, time: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}'));
    notifyListeners();
  }

  /// Kuryenin şu an elinde ne var (apps/api `GET /v1/custody`) — "Şube" modunda
  /// taranan barkodu gerçek bir zimmet kalemine eşlemek için gerekiyor.
  Future<void> loadCustody() async {
    final client = api;
    if (client == null || custodyLoading) return;
    custodyLoading = true;
    notifyListeners();
    try {
      custodyItems = await client.fetchCustody(type: 'parcel');
      liveApi = client.lastWasLive;
    } catch (_) {
      // elimizdeki listeyi koru, ekran son bilinen haliyle kalsın
    } finally {
      custodyLoading = false;
      notifyListeners();
    }
  }

  CustodyItemDto? _custodyItemByBarcode(String code) {
    for (final item in custodyItems) {
      if (item.barcode == code) return item;
    }
    return null;
  }

  /// Şube modunda gerçek devir API'sini çağırır (Kurye → Acente teslim,
  /// Madde 9). Kurye modu bilerek yerel kalıyor — backend'de bir zimmet
  /// kalemini barkoddan ilk kez oluşturan bir uç yok, bkz. proje notu
  /// (Hande'nin netleştirmesi bekleniyor). Dönüş değeri devrin (kısmen de
  /// olsa) başarılı olup olmadığını söyler; ekran buna göre hata gösterir.
  Future<bool> completeZimmet() async {
    if (zimmetMode != 'sube' || api == null) {
      zimmetScans.clear();
      notifyListeners();
      return true;
    }

    final itemIds = <String>[
      for (final scan in zimmetScans)
        if (_custodyItemByBarcode(scan.code) case final item?) item.id,
    ];
    if (itemIds.isEmpty) {
      // Taranan hiçbir kod bilinen bir zimmet kalemiyle eşleşmedi (demo
      // kodları) — kuryeyi burada bloklamak yerine yerel taramayı bitir.
      zimmetScans.clear();
      notifyListeners();
      return true;
    }

    custodyHandoverPending = true;
    notifyListeners();
    try {
      final result = await api!.handoverToBranch(itemIds: itemIds, branchName: 'Şube');
      custodyItems = result.remaining;
      liveApi = api!.lastWasLive;
      zimmetScans.clear();
      return true;
    } catch (_) {
      return false;
    } finally {
      custodyHandoverPending = false;
      notifyListeners();
    }
  }

  bool beepEnabled = true;
  bool notifyEnabled = true;
  bool workerEnabled = true;
  bool darkModeUi = false;

  void toggleBeep() {
    beepEnabled = !beepEnabled;
    notifyListeners();
  }

  void toggleNotifyPref() {
    notifyEnabled = !notifyEnabled;
    notifyListeners();
  }

  void toggleWorker() {
    workerEnabled = !workerEnabled;
    notifyListeners();
  }

  void toggleDarkModeUi() {
    darkModeUi = !darkModeUi;
    notifyListeners();
  }

  static const todayEarn = '₺842';
  static const earnDelta = '+₺97 dünden fazla';
  static const weekEarn = '₺4.318';
  final weeklyBars = const [
    WeeklyBar(label: 'Pzt', value: 0.55),
    WeeklyBar(label: 'Sal', value: 0.72),
    WeeklyBar(label: 'Çar', value: 0.44),
    WeeklyBar(label: 'Per', value: 0.86),
    WeeklyBar(label: 'Cum', value: 1),
    WeeklyBar(label: 'Cmt', value: 0.62),
    WeeklyBar(label: 'Paz', value: 0.18),
  ];
  final bonuses = const [
    BonusProgress(
      label: 'Haftalık 40 teslim',
      amount: '₺750',
      pct: 0.85,
      meta: '34 / 40 teslim',
      color: Dg.purpleDeep,
    ),
    BonusProgress(
      label: 'Yoğun saat primi',
      amount: '₺240',
      pct: 0.60,
      meta: '17:00–20:00 arası 6 teslim',
      color: Dg.amber,
    ),
    BonusProgress(
      label: 'Sıfır iade primi',
      amount: '₺400',
      pct: 0.40,
      meta: 'Bu hafta 1 iade kaydı var',
      color: Dg.blue,
    ),
  ];

  final kycDocs = const [
    KycDocOption(label: 'Yeni kimlik ön yüz', icon: Icons.badge_outlined),
    KycDocOption(label: 'Yeni kimlik arka yüz', icon: Icons.badge_outlined),
    KycDocOption(label: 'Eski kimlik', icon: Icons.description_outlined),
    KycDocOption(label: 'Pasaport', icon: Icons.description_outlined),
    KycDocOption(label: 'Yabancı kimlik', icon: Icons.badge_outlined),
  ];
  bool nfcRead = false;
  String mrzDoc = 'T12345678';
  String mrzDob = '900101';

  void setMrzDoc(String v) {
    mrzDoc = v;
    notifyListeners();
  }

  void setMrzDob(String v) {
    mrzDob = v;
    notifyListeners();
  }

  void readNfc() {
    nfcRead = true;
    notifyListeners();
  }

  bool pushingSync = false;

  Future<void> pushSyncQueue() async {
    if (outbox.events.where((e) => e.pending).isEmpty || pushingSync) return;
    pushingSync = true;
    notifyListeners();
    await _flushOutbox();
    pushingSync = false;
    notifyListeners();
  }

  int get pendingSync => outbox.pendingCount;
  bool get forceUpdate => config.forceUpdate;

  DeliveryTask? get nextStop {
    for (final t in tasks) {
      if (t.status == TaskStatus.inProgress || t.status == TaskStatus.assigned) return t;
    }
    return null;
  }

  List<DeliveryTask> get remainingStops =>
      tasks.where((t) => t.id != nextStop?.id).toList();

  Courier courier = const Courier(
    fullName: 'Ruken Turhan',
    code: 'DGC-2026-9CF4875F',
    phone: '+90 532 ••• •• 26',
    city: 'Denizli',
    district: 'Güney',
    vehicle: 'Otomobil',
    employment: 'Yarı zamanlı',
    availability: 'Müsait',
    hours: 'Pzt–Cum 09:00–18:00',
  );

  CourierDocumentListDto documents = const CourierDocumentListDto(
    items: [],
    completedCount: 2,
    requiredCount: 2,
  );

  String get documentsSummary =>
      documents.items.isEmpty ? 'Kimlik ve ehliyet tamam' : documents.summary;

  final tasks = <DeliveryTask>[
    DeliveryTask(
      id: 't1',
      ref: 'DGO-8841',
      recipient: 'Ahmet Yılmaz',
      address: 'Kayalık Mah. Cumhuriyet Cd. No:14, Güney / Denizli',
      window: '14:30–15:00',
      kind: TaskKind.delivery,
      status: TaskStatus.assigned,
      otpRequired: true,
      sequence: 1,
      etaMinutes: 6,
      lat: 38.1512,
      lng: 29.0614,
    ),
    DeliveryTask(
      id: 't2',
      ref: 'DGO-8842',
      recipient: 'Elif Koç',
      address: 'İstiklal Cd. No:8 D:3, Güney / Denizli',
      window: '15:00–15:30',
      kind: TaskKind.document,
      status: TaskStatus.assigned,
      sequence: 2,
      etaMinutes: 11,
      lat: 38.1481,
      lng: 29.0558,
    ),
    DeliveryTask(
      id: 't3',
      ref: 'DGO-8843',
      recipient: 'Mehmet Aydın',
      address: 'Atatürk Mah. 7. Sk. No:22, Güney / Denizli',
      window: '15:45–16:15',
      kind: TaskKind.delivery,
      status: TaskStatus.assigned,
      cod: 185,
      sequence: 3,
      etaMinutes: 18,
      lat: 38.1554,
      lng: 29.0692,
    ),
    DeliveryTask(
      id: 't4',
      ref: 'DGO-8844',
      recipient: 'Fatma Şahin',
      address: 'Yeni Mah. Okul Sk. No:4, Güney / Denizli',
      window: '13:00–13:30',
      kind: TaskKind.delivery,
      status: TaskStatus.queued,
      note: 'Alıcı yoktu · kapı fotoğrafı kuyrukta',
      sequence: 4,
      lat: 38.1460,
      lng: 29.0488,
    ),
  ];

  int get openCount =>
      tasks.where((t) => t.status == TaskStatus.assigned || t.status == TaskStatus.inProgress).length;

  int get doneCount =>
      tasks.where((t) => t.status == TaskStatus.delivered || t.status == TaskStatus.failed).length;

  int get deliveredCount => tasks.where((t) => t.status == TaskStatus.delivered).length;
  int get returnCount => tasks.where((t) => t.status == TaskStatus.failed).length;

  DeliveryTask taskById(String id) => tasks.firstWhere((t) => t.id == id);

  Future<void> bootstrap() async {
    if (configReady && !waitForConfig) return;
    try {
      final remote = await api?.fetchConfig();
      if (remote != null) {
        config = remote;
        liveApi = api?.lastWasLive ?? false;
      }
    } catch (_) {
      config = AppConfig.demo;
      liveApi = false;
    }
    configReady = true;
    notifyListeners();
  }

  void finishOnboard() {
    unawaited(vault?.markOnboardSeen());
    phase = AppPhase.splash;
    notifyListeners();
  }

  void skipToDemo() {
    demo = true;
    phase = AppPhase.main;
    shiftOpen = true;
    shiftPhotoTaken = true;
    shiftStartedAt = DateTime.now().subtract(const Duration(hours: 5, minutes: 12));
    notifyListeners();
    unawaited(_seedDemoTokenThenIdentity());
  }

  void finishSplash() {
    phase = AppPhase.activation;
    notifyListeners();
  }

  Future<void> requestActivationCode(String phone) async {
    final install = await vault?.installationId() ?? Vault.newUuid();
    try {
      final res = await api?.startActivation(phone, install);
      challengeId = res?['challengeId'] as String?;
      liveApi = api?.lastWasLive ?? false;
    } catch (_) {
      challengeId = Vault.newUuid();
      liveApi = false;
    }
    notifyListeners();
  }

  Future<bool> verifyLoginOtp(String code) async {
    if (code == '123456') {
      demo = true;
      await _saveDemoTokens();
      return true;
    }
    final install = await vault?.installationId() ?? Vault.newUuid();
    final id = challengeId;
    if (api == null || id == null) return false;
    try {
      final tokens = await api!.verifyActivation(challengeId: id, code: code, installationId: install);
      await vault?.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        accessExpiresAt: tokens.accessExpiresAt,
        refreshExpiresAt: tokens.refreshExpiresAt,
      );
      liveApi = api?.lastWasLive ?? false;
      demo = !liveApi;
      return true;
    } catch (_) {
      return false;
    }
  }

  void completeActivation() {
    phase = AppPhase.permissions;
    notifyListeners();
  }

  void completePermissions() {
    phase = AppPhase.shift;
    notifyListeners();
  }

  void takeShiftPhoto() {
    shiftPhotoTaken = true;
    notifyListeners();
  }

  void openShift() {
    if (!shiftPhotoTaken) return;
    shiftOpen = true;
    shiftStartedAt = DateTime.now();
    phase = AppPhase.main;
    notifyListeners();
    unawaited(loadIdentity());
    unawaited(loadRoute());
  }

  Future<void> _seedDemoTokenThenIdentity() async {
    await _saveDemoTokens();
    await loadIdentity();
    await loadRoute();
  }

  Future<void> _saveDemoTokens() async {
    final store = vault;
    if (store == null) return;
    final existing = await store.accessToken;
    if (existing != null && existing.isNotEmpty && existing != 'demo-access') return;
    final now = DateTime.now().toUtc();
    await store.saveTokens(
      accessToken: 'demo-access',
      refreshToken: 'demo-refresh',
      accessExpiresAt: now.add(const Duration(minutes: 15)),
      refreshExpiresAt: now.add(const Duration(days: 30)),
    );
  }

  /// Panel cookie is never used. Token BFF fills city, hours, documents.
  Future<void> loadIdentity() async {
    final client = api;
    if (client == null) return;
    try {
      final availability = await client.fetchAvailability();
      final docs = await client.fetchDocuments();
      courier = courier.copyWith(
        city: availability.city,
        district: availability.district ?? courier.district,
        vehicle: availability.vehicleLabel,
        employment: availability.employmentLabel,
        availability: availability.statusLabel,
        hours: availability.hoursLabel,
      );
      documents = docs;
      liveApi = client.lastWasLive;
    } catch (_) {
      liveApi = false;
    }
    notifyListeners();
  }

  /// Faz 2 route: real road-network geometry and, past 2 stops, an
  /// optimizer-reordered sequence (apps/api `GET /v1/routes/current`).
  /// Failures are silent by design — [RouteScreen] falls back to the
  /// straight-line demo drawing when [routePlan] stays null.
  Future<void> loadRoute() async {
    final client = api;
    if (client == null || routeLoading) return;
    routeLoading = true;
    notifyListeners();
    try {
      routePlan = await client.fetchRoute();
      liveApi = client.lastWasLive;
    } catch (_) {
      // keep whatever routePlan we had; the screen just shows the fallback
    } finally {
      routeLoading = false;
      notifyListeners();
    }
  }

  void cyclePricingVisibility() {
    final c = courier;
    if (c.affiliation == CourierAffiliation.independent && c.compensationType == CompensationType.pieceRate) {
      courier = c.copyWith(compensationType: CompensationType.fixedMonthly);
    } else if (c.affiliation == CourierAffiliation.independent) {
      courier = c.copyWith(affiliation: CourierAffiliation.agency);
    } else {
      courier = c.copyWith(affiliation: CourierAffiliation.independent, compensationType: CompensationType.pieceRate);
    }
    notifyListeners();
  }

  void updateProfile({required String fullName, required String phone, required String plateValue}) {
    courier = courier.copyWith(fullName: fullName, phone: phone);
    plate = plateValue;
    notifyListeners();
  }

  void startTask(String id) {
    final t = taskById(id);
    t.status = TaskStatus.inProgress;
    notifyListeners();
  }

  void deliverTask(String id, {String? receivedBy}) {
    final t = taskById(id);
    t.status = TaskStatus.delivered;
    t.receivedBy = receivedBy;
    final event = outbox.enqueue(
      operation: SyncOperation.taskFinalize,
      subjectId: id,
      payload: {
        'receivedBy': receivedBy,
        'outcome': 'DELIVERED',
      },
    );
    if (online) {
      if (api == null) {
        event.status = 'applied';
      } else {
        unawaited(_flushOutbox());
      }
    }
    notifyListeners();
  }

  void returnTask(String id, {required String reason, String? note}) {
    final t = taskById(id);
    t.status = TaskStatus.failed;
    final event = outbox.enqueue(
      operation: SyncOperation.taskTransition,
      subjectId: id,
      payload: {
        'outcome': 'RETURNED',
        'reason': reason,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    if (online) {
      if (api == null) {
        event.status = 'applied';
      } else {
        unawaited(_flushOutbox());
      }
    }
    notifyListeners();
  }

  void failTask(String id) {
    final t = taskById(id);
    t.status = TaskStatus.queued;
    online = false;
    outbox.enqueue(
      operation: SyncOperation.taskTransition,
      subjectId: id,
      payload: const {'outcome': 'FAILED', 'reason': 'TESLIM_EDILEMEDI'},
    );
    notifyListeners();
  }

  void toggleOnline() {
    online = !online;
    if (online) {
      unawaited(_flushOutbox());
      for (final t in tasks) {
        if (t.status == TaskStatus.queued && t.note != null) {
          t.status = TaskStatus.failed;
        }
      }
    }
    notifyListeners();
  }

  Future<void> _flushOutbox() async {
    final pending = outbox.events.where((e) => e.pending).toList();
    if (pending.isEmpty) return;
    final client = api;
    final store = vault;
    if (client == null || store == null) {
      outbox.drain();
      notifyListeners();
      return;
    }
    try {
      final install = await store.installationId();
      final results = await client.syncBatch(installationId: install, events: pending);
      liveApi = client.lastWasLive;
      await outbox.applyResults([
        for (final r in results) (id: r.clientEventId, status: r.status),
      ]);
    } catch (_) {
      outbox.drain();
    }
    notifyListeners();
  }

  bool verifyDeliveryOtp(String code) => code == '482913';
}
