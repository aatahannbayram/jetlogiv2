import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/client.dart';
import 'api/jetdiji_branch_client.dart';
import 'api/jetdiji_branch_models.dart';
import 'api/jetdiji_courier_client.dart';
import 'api/jetdiji_courier_models.dart';
import 'api/jetdiji_http.dart';
import 'api/models.dart';
import 'data/outbox.dart';
import 'data/pluxee_store.dart';
import 'data/vault.dart';
import 'pluxee/draft.dart';
import 'pluxee/submit.dart';
import 'models.dart';
import 'theme.dart';

List<DeliveryTask> demoDeliveryTasks() {
  return [
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
      custodyCount: 2,
      custodyRef: 'PRD-11207',
      slaMinutesLeft: 72,
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
      custodyCount: 1,
      slaMinutesLeft: 118,
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
}

String? jetdijiReceiverType(String? key) {
  return switch (key) {
    'recipient' => 'SELF',
    'relative' => 'RELATIVE',
    'neighbor' => 'AUTHORIZED',
    'workplace' => 'SECRETARY',
    _ => null,
  };
}

final sessionProvider = ChangeNotifierProvider<SessionController>((ref) {
  return SessionController();
});

enum AppPhase { onboard, splash, activation, permissions, shift, main, branch }

class SessionController extends ChangeNotifier {
  SessionController({
    OutboxStore? outbox,
    this.api,
    this.vault,
    this.jetdiji,
    this.branchApi,
    this.pluxee,
    this.waitForConfig = false,
    AppPhase? initialPhase,
  }) : outbox = outbox ?? OutboxStore(),
       phase = initialPhase ?? AppPhase.onboard {
    tasks.addAll(demoDeliveryTasks());
    configReady = !waitForConfig;
    // Sabit demo-tohumu: gerçek enqueue() id'lerinin izlediği
    // 00000000-0000-4000-a000-{sequence} kalıbından bilinçli olarak farklı,
    // yoksa uygulamanın ilk gerçek enqueue()'u (sequence=1) bu id ile çakışır.
    this.outbox.seedQueued(
      OutboxEvent(
        clientEventId: 'demo-seed-t4-0001',
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
  final JetDijiCourierApi? jetdiji;
  final JetDijiBranchApi? branchApi;
  final PluxeeDraftStore? pluxee;
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
  bool jetdijiCourier = false;
  bool jetdijiBranch = false;
  String? lastJetdijiError;
  JetDijiDashboardCounts? jetdijiCounts;
  JetDijiDeliveryReasons? deliveryReasons;
  final Map<String, JetDijiRequirements?> requirementsByTask = {};
  final Map<String, String> otpChallengeByTask = {};
  final Map<String, String?> otpDevCodeByTask = {};
  final Map<String, String> otpEvidenceByTask = {};
  final Map<String, String> finalizeKeys = {};
  final Map<String, String> finalizeFingerprints = {};
  final Set<String> calledTaskIds = {};

  JetDijiBranchUser? branchUser;
  JetDijiBranchDashboard? branchDashboard;
  List<JetDijiShipmentRow> branchShipments = [];
  List<JetDijiAgencyCourier> branchCouriers = [];
  JetDijiCourierMap? branchMap;
  Map<String, dynamic> branchPending = const {};
  List<Map<String, dynamic>> branchCounts = [];
  Map<String, dynamic> branchOutgoing = const {};
  bool branchLoading = false;
  String? branchError;

  bool get usesJetdijiCourier => jetdijiCourier && !demo;
  bool get branchCanOperate => branchUser?.operate == true;
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

  /// Vardiyanın açıldığı saat — "05:12  08:40'tan beri" gibi gösterimler
  /// için (home_screen.dart).
  String get shiftStartLabel {
    final started = shiftStartedAt;
    if (started == null) return '--:--';
    return '${started.hour.toString().padLeft(2, '0')}:${started.minute.toString().padLeft(2, '0')}';
  }

  // Menü / new-screens demo state (local only, no backend — see docs/plan).
  String plate = '20 KR 841';

  final Set<int> _readNotifications = {};
  final notifications = <AppNotification>[
    AppNotification(
      title: 'Yeni durak atandı',
      body: 'DGO-8844 · Cumhuriyet Mah. 1. Sk. No:3',
      time: '14:41',
      icon: LucideIcons.truck,
      tint: Dg.greenBg,
      ink: Dg.green,
    ),
    AppNotification(
      title: 'Zimmet onaylandı',
      body: 'Şube zimmetinden 6 gönderi üstüne alındı.',
      time: '13:58',
      icon: LucideIcons.package,
      tint: Dg.violetBg,
      ink: Dg.violet,
    ),
    AppNotification(
      title: 'Gönderim başarısız',
      body: 'DGO-8839 senkron edilemedi, kuyrukta bekliyor.',
      time: '12:20',
      icon: LucideIcons.circleAlert,
      tint: Dg.redBg,
      ink: Dg.red,
    ),
    AppNotification(
      title: 'Prim güncellendi',
      body: 'Bu hafta 40 teslim primine 6 teslim kaldı.',
      time: '09:05',
      icon: LucideIcons.wallet,
      tint: Dg.amberBg,
      ink: Dg.amber,
    ),
    AppNotification(
      title: 'Vardiya hatırlatması',
      body: 'Yarın 09:00 vardiyası atanmıştır.',
      time: 'Dün',
      icon: LucideIcons.clock,
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
    DepotOption(
      name: 'Merkez Depo',
      meta: 'Sanayi Mah. 3. Cd. No:22',
      count: 18,
    ),
    DepotOption(name: 'Güney Şube', meta: 'Kayalık Mah. No:4', count: 7),
    DepotOption(
      name: 'Çamlık Aktarma',
      meta: 'Çamlık Mah. Depo Blok B',
      count: 3,
    ),
  ];
  int? selectedDepot;
  static const _depotParcels = [
    DepotParcel(code: 'DGO-9012', name: 'Selin Uçar', weight: '1,2 kg'),
    DepotParcel(code: 'DGO-9013', name: 'Kerem Baş', weight: '0,4 kg'),
    DepotParcel(code: 'DGO-9014', name: 'Nazlı Ekin', weight: '3,8 kg'),
  ];
  List<DepotParcel> get depotPreview =>
      selectedDepot == null ? const [] : _depotParcels;

  void pickDepot(int i) {
    selectedDepot = i;
    notifyListeners();
  }

  void confirmDepotPickup() {
    inventory.insertAll(
      0,
      _depotParcels.map(
        (p) => InventoryItem(
          code: p.code,
          name: p.name,
          state: 'Bekleyen',
          done: false,
        ),
      ),
    );
    selectedDepot = null;
    notifyListeners();
  }

  final inventory = <InventoryItem>[
    const InventoryItem(
      code: 'DGO-8841',
      name: 'Ahmet Yılmaz',
      state: 'Bekleyen',
      done: false,
    ),
    const InventoryItem(
      code: 'DGO-8842',
      name: 'Elif Koç',
      state: 'Bekleyen',
      done: false,
    ),
    const InventoryItem(
      code: 'DGO-8838',
      name: 'Burak Sarı',
      state: 'Teslim',
      done: true,
    ),
  ];

  int get inventoryPending => inventory.where((p) => !p.done).length;
  int get inventoryDone => inventory.where((p) => p.done).length;

  void addInventoryByCode(String code) {
    final v = code.trim();
    if (v.isEmpty) return;
    inventory.insert(
      0,
      InventoryItem(
        code: v,
        name: 'Yeni kayıt',
        state: 'Bekleyen',
        done: false,
      ),
    );
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
    zimmetScans.insert(0, (
      code: label,
      time:
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
    ));
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
    if (usesJetdijiCourier && zimmetMode == 'kurye' && jetdiji != null) {
      try {
        for (final scan in List.of(zimmetScans)) {
          await jetdiji!.acceptCustody(
            scanCode: scan.code,
            scanType: 'BARCODE',
          );
        }
        zimmetScans.clear();
        lastJetdijiError = null;
        return true;
      } on JetDijiException catch (e) {
        lastJetdijiError = e.code;
        return false;
      } finally {
        notifyListeners();
      }
    }
    if (jetdijiBranch && zimmetMode == 'sube' && branchApi != null) {
      try {
        for (final scan in List.of(zimmetScans)) {
          await branchApi!.scanCourierReturn(scanCode: scan.code);
        }
        zimmetScans.clear();
        lastJetdijiError = null;
        return true;
      } on JetDijiException catch (e) {
        lastJetdijiError = e.code;
        return false;
      } finally {
        notifyListeners();
      }
    }
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
      final result = await api!.handoverToBranch(
        itemIds: itemIds,
        branchName: 'Şube',
      );
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
  // Koyu tema artık markanın birincil görünümü (bkz. theme.dart) —
  // varsayılan true, "Açık tema" ayarlardan seçilebilen alternatif.
  bool darkModeUi = true;

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
    KycDocOption(label: 'Yeni kimlik ön yüz', icon: LucideIcons.idCard),
    KycDocOption(label: 'Yeni kimlik arka yüz', icon: LucideIcons.idCard),
    KycDocOption(label: 'Eski kimlik', icon: LucideIcons.fileText),
    KycDocOption(label: 'Pasaport', icon: LucideIcons.fileText),
    KycDocOption(label: 'Yabancı kimlik', icon: LucideIcons.idCard),
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
      if (t.status == TaskStatus.inProgress || t.status == TaskStatus.assigned)
        return t;
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
    compensationType: CompensationType.fixedMonthly,
  );

  CourierDocumentListDto documents = const CourierDocumentListDto(
    items: [],
    completedCount: 2,
    requiredCount: 2,
  );

  String get documentsSummary =>
      documents.items.isEmpty ? 'Kimlik ve ehliyet tamam' : documents.summary;

  final tasks = <DeliveryTask>[];

  int get openCount => tasks
      .where(
        (t) =>
            t.status == TaskStatus.assigned ||
            t.status == TaskStatus.inProgress,
      )
      .length;

  int get doneCount => tasks
      .where(
        (t) =>
            t.status == TaskStatus.delivered || t.status == TaskStatus.failed,
      )
      .length;

  int get deliveredCount =>
      tasks.where((t) => t.status == TaskStatus.delivered).length;
  int get returnCount =>
      tasks.where((t) => t.status == TaskStatus.failed).length;

  DeliveryTask taskById(String id) => tasks.firstWhere((t) => t.id == id);

  Future<void> bootstrap() async {
    if (!configReady || waitForConfig) {
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
    }
    await restoreJetdiji();
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
    shiftStartedAt = DateTime.now().subtract(
      const Duration(hours: 5, minutes: 12),
    );
    notifyListeners();
    unawaited(_seedDemoTokenThenIdentity());
  }

  void finishSplash() {
    phase = AppPhase.activation;
    notifyListeners();
  }

  /// Clears stored auth + resets in-memory shift/session state, dropping
  /// back to splash (which re-offers "Vardiyaya başla" / activation).
  Future<void> logout() async {
    try {
      await jetdiji?.logout();
    } catch (_) {
      await vault?.clearJetdijiToken('courier');
      await jetdiji?.http.tokens.clear();
    }
    try {
      await branchApi?.logout();
    } catch (_) {
      await vault?.clearJetdijiToken('branch');
      await branchApi?.http.tokens.clear();
    }
    await vault?.clearTokens();
    shiftOpen = false;
    shiftPhotoTaken = false;
    shiftStartedAt = null;
    demo = true;
    jetdijiCourier = false;
    jetdijiBranch = false;
    branchUser = null;
    branchDashboard = null;
    branchShipments = [];
    lastJetdijiError = null;
    liveApi = false;
    routePlan = null;
    tasks
      ..clear()
      ..addAll(demoDeliveryTasks());
    phase = AppPhase.splash;
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
      final tokens = await api!.verifyActivation(
        challengeId: id,
        code: code,
        installationId: install,
      );
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
    if (existing != null && existing.isNotEmpty && existing != 'demo-access')
      return;
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
    if (c.affiliation == CourierAffiliation.independent &&
        c.compensationType == CompensationType.pieceRate) {
      courier = c.copyWith(compensationType: CompensationType.fixedMonthly);
    } else if (c.affiliation == CourierAffiliation.independent) {
      courier = c.copyWith(affiliation: CourierAffiliation.agency);
    } else {
      courier = c.copyWith(
        affiliation: CourierAffiliation.independent,
        compensationType: CompensationType.pieceRate,
      );
    }
    notifyListeners();
  }

  void updateProfile({
    required String fullName,
    required String phone,
    required String plateValue,
  }) {
    courier = courier.copyWith(fullName: fullName, phone: phone);
    plate = plateValue;
    notifyListeners();
  }

  void startTask(String id) {
    final t = taskById(id);
    t.status = TaskStatus.inProgress;
    notifyListeners();
    if (usesJetdijiCourier) unawaited(_acceptJetdijiTask(id));
  }

  Future<void> _acceptJetdijiTask(String id) async {
    final client = jetdiji;
    if (client == null) return;
    try {
      await client.acceptTask(id);
      lastJetdijiError = null;
    } on JetDijiException catch (e) {
      lastJetdijiError = e.code;
      notifyListeners();
    }
  }

  Future<bool> deliverTask(
    String id, {
    String? receivedBy,
    String? receiverType,
    String? receivedRelationCode,
    String? otpEvidenceId,
    List<String> evidenceIds = const [],
  }) async {
    final t = taskById(id);
    if (!usesJetdijiCourier) {
      t.status = TaskStatus.delivered;
      t.receivedBy = receivedBy;
      final event = outbox.enqueue(
        operation: SyncOperation.taskFinalize,
        subjectId: id,
        payload: {'receivedBy': receivedBy, 'outcome': 'DELIVERED'},
      );
      if (online) {
        if (api == null) {
          event.status = 'applied';
        } else {
          unawaited(_flushOutbox());
        }
      }
      notifyListeners();
      return true;
    }

    final fingerprint = [
      'DELIVERED',
      receiverType,
      receivedBy,
      receivedRelationCode,
      otpEvidenceId,
      evidenceIds.join(','),
    ].join('|');
    final key = _finalizeKey(id, fingerprint);
    final capturedAt = DateTime.now().toUtc().toIso8601String();
    final payload = <String, Object?>{
      'jetdiji': true,
      'resultCode': 'DELIVERED',
      'idempotencyKey': key,
      'capturedAt': capturedAt,
      if (receiverType != null) 'receiverType': receiverType,
      if (receivedBy != null) 'receivedByName': receivedBy,
      if (receivedRelationCode != null)
        'receivedRelationCode': receivedRelationCode,
      if (otpEvidenceId != null) 'otpEvidenceId': otpEvidenceId,
      'evidenceIds': evidenceIds,
      if (t.usableForProximity) 'latitude': t.lat,
      if (t.usableForProximity) 'longitude': t.lng,
    };

    if (!online) {
      _enqueueJetdijiFinalize(id, payload);
      t.status = TaskStatus.delivered;
      t.receivedBy = receivedBy;
      notifyListeners();
      return true;
    }

    try {
      await jetdiji!.finalize(
        id,
        resultCode: 'DELIVERED',
        receiverType: receiverType,
        receivedByName: receivedBy,
        receivedRelationCode: receivedRelationCode,
        otpEvidenceId: otpEvidenceId,
        evidenceIds: evidenceIds,
        latitude: t.usableForProximity ? t.lat : null,
        longitude: t.usableForProximity ? t.lng : null,
        capturedAt: capturedAt,
        idempotencyKey: key,
      );
      t.status = TaskStatus.delivered;
      t.receivedBy = receivedBy;
      lastJetdijiError = null;
      notifyListeners();
      return true;
    } on JetDijiException catch (e) {
      lastJetdijiError = e.code;
      if (e.code == 'NETWORK') {
        _enqueueJetdijiFinalize(id, payload);
        t.status = TaskStatus.delivered;
        t.receivedBy = receivedBy;
        notifyListeners();
        return true;
      }
      notifyListeners();
      return false;
    }
  }

  Future<bool> returnTask(
    String id, {
    required String reason,
    String? reasonCode,
    String? note,
  }) async {
    final t = taskById(id);
    if (!usesJetdijiCourier) {
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
      return true;
    }

    final trimmed = note?.trim() ?? '';
    if (trimmed.isEmpty || (reasonCode == null || reasonCode.isEmpty)) {
      lastJetdijiError = 'NOTE_REQUIRED';
      notifyListeners();
      return false;
    }
    final fingerprint = 'DELIVERY_FAILED|$reasonCode|$trimmed';
    final key = _finalizeKey(id, fingerprint);
    final capturedAt = DateTime.now().toUtc().toIso8601String();
    final payload = <String, Object?>{
      'jetdiji': true,
      'resultCode': 'DELIVERY_FAILED',
      'reasonCode': reasonCode,
      'note': trimmed,
      'idempotencyKey': key,
      'capturedAt': capturedAt,
      'evidenceIds': const <String>[],
      if (t.usableForProximity) 'latitude': t.lat,
      if (t.usableForProximity) 'longitude': t.lng,
    };
    if (!online) {
      _enqueueJetdijiFinalize(id, payload);
      t.status = TaskStatus.failed;
      notifyListeners();
      return true;
    }
    try {
      await jetdiji!.finalize(
        id,
        resultCode: 'DELIVERY_FAILED',
        reasonCode: reasonCode,
        note: trimmed,
        latitude: t.usableForProximity ? t.lat : null,
        longitude: t.usableForProximity ? t.lng : null,
        capturedAt: capturedAt,
        idempotencyKey: key,
      );
      t.status = TaskStatus.failed;
      lastJetdijiError = null;
      notifyListeners();
      return true;
    } on JetDijiException catch (e) {
      lastJetdijiError = e.code;
      if (e.code == 'NETWORK') {
        _enqueueJetdijiFinalize(id, payload);
        t.status = TaskStatus.failed;
        notifyListeners();
        return true;
      }
      notifyListeners();
      return false;
    }
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
    await _flushJetdijiOutbox();
    final pending = outbox.events
        .where((e) => e.pending && e.payload['jetdiji'] != true)
        .toList();
    if (pending.isEmpty) return;
    final client = api;
    final store = vault;
    if (client == null || store == null) {
      for (final event in pending) {
        event.status = 'applied';
      }
      notifyListeners();
      return;
    }
    try {
      final install = await store.installationId();
      final results = await client.syncBatch(
        installationId: install,
        events: pending,
      );
      liveApi = client.lastWasLive;
      await outbox.applyResults([
        for (final r in results) (id: r.clientEventId, status: r.status),
      ]);
    } catch (_) {
      // Ağ/istek hatası: "kapalı ortamda" (sinyal yokken) beklenen durum tam
      // olarak bu. Öğeleri applied say(drain) diye işaretlersek gönderilmemiş
      // teslimatları sessizce kaybederiz — pending bırak, bir sonraki
      // pushSyncQueue()/online geçişinde tekrar denensin.
      liveApi = false;
    }
    notifyListeners();
  }

  bool verifyDeliveryOtp(String code, {String? taskId}) {
    if (!usesJetdijiCourier || taskId == null) return code == '482913';
    return false;
  }

  Future<bool> verifyDeliveryOtpAsync(String code, {String? taskId}) async {
    if (!usesJetdijiCourier || taskId == null) return code == '482913';
    final challengeId = otpChallengeByTask[taskId];
    final client = jetdiji;
    if (challengeId == null || client == null) return false;
    try {
      final verified = await client.verifyOtp(
        taskId,
        challengeId: challengeId,
        code: code,
      );
      if (verified.evidenceId != null) {
        otpEvidenceByTask[taskId] = verified.evidenceId!;
      }
      lastJetdijiError = null;
      return verified.verified;
    } on JetDijiException catch (e) {
      lastJetdijiError = e.code;
      notifyListeners();
      return false;
    }
  }

  String _finalizeKey(String id, String fingerprint) {
    if (finalizeFingerprints[id] != fingerprint) {
      finalizeFingerprints[id] = fingerprint;
      finalizeKeys[id] = Vault.newUuid();
    }
    return finalizeKeys[id]!;
  }

  void _enqueueJetdijiFinalize(String id, Map<String, Object?> payload) {
    outbox.enqueue(
      operation: SyncOperation.taskFinalize,
      subjectId: id,
      payload: payload,
    );
  }

  Future<void> _flushJetdijiOutbox() async {
    final client = jetdiji;
    final pending = outbox.events
        .where((e) => e.pending && e.payload['jetdiji'] == true)
        .toList();
    for (final event in pending) {
      if (event.payload['kind'] == 'location') {
        final captured = DateTime.tryParse('${event.payload['capturedAt']}');
        if (captured != null &&
            DateTime.now().toUtc().difference(captured.toUtc()) >
                const Duration(minutes: 5)) {
          event.status = 'rejected';
          continue;
        }
        if (client == null || event.subjectId == null) continue;
        try {
          await client.sendLocation(
            event.subjectId!,
            latitude: (event.payload['latitude'] as num).toDouble(),
            longitude: (event.payload['longitude'] as num).toDouble(),
            purposeCode: '${event.payload['purposeCode'] ?? 'ACTIVE_TASK'}',
            capturedAt: event.payload['capturedAt'] as String?,
          );
          event.status = 'applied';
        } on JetDijiException catch (e) {
          if (e.code == 'LOCATION_NOT_FRESH') event.status = 'rejected';
          lastJetdijiError = e.code;
        }
        continue;
      }
      if (client == null || event.subjectId == null) continue;
      if (event.payload['resultCode'] is! String) continue;
      final ids = event.payload['evidenceIds'];
      try {
        await client.finalize(
          event.subjectId!,
          resultCode: event.payload['resultCode'] as String,
          reasonCode: event.payload['reasonCode'] as String?,
          receiverType: event.payload['receiverType'] as String?,
          receivedByName: event.payload['receivedByName'] as String?,
          receivedRelationCode:
              event.payload['receivedRelationCode'] as String?,
          note: event.payload['note'] as String?,
          latitude: (event.payload['latitude'] as num?)?.toDouble(),
          longitude: (event.payload['longitude'] as num?)?.toDouble(),
          capturedAt: event.payload['capturedAt'] as String?,
          otpEvidenceId: event.payload['otpEvidenceId'] as String?,
          evidenceIds: [for (final id in ids is List ? ids : const []) '$id'],
          idempotencyKey: event.payload['idempotencyKey'] as String?,
        );
        event.status = 'applied';
      } on JetDijiException catch (e) {
        lastJetdijiError = e.code;
      }
    }
  }

  Future<void> restoreJetdiji() async {
    if (await jetdiji?.hasToken == true) jetdijiCourier = true;
    if (await branchApi?.hasToken == true) {
      jetdijiBranch = true;
      try {
        branchUser = await branchApi!.session();
      } on JetDijiException catch (e) {
        lastJetdijiError = e.code;
      }
    }
  }

  Future<bool> loginWithJetdiji({
    required String identifier,
    required String password,
  }) async {
    final client = jetdiji;
    if (client == null) return false;
    try {
      final login = await client.login(
        identifier: identifier,
        password: password,
      );
      final profile = login.courier;
      if (profile != null) {
        courier = courier.copyWith(
          fullName: profile.fullName.isEmpty ? null : profile.fullName,
          code: profile.courierCode.isEmpty ? null : profile.courierCode,
          phone: profile.phone,
        );
      }
      await enterCourierHome();
      return true;
    } on JetDijiException catch (e) {
      lastJetdijiError = e.code;
      notifyListeners();
      return false;
    }
  }

  Future<void> enterCourierHome() async {
    jetdijiCourier = true;
    demo = false;
    shiftOpen = true;
    shiftPhotoTaken = true;
    shiftStartedAt ??= DateTime.now();
    phase = AppPhase.main;
    notifyListeners();
    await loadJetdijiTasks();
  }

  Future<void> loadJetdijiTasks() async {
    final client = jetdiji;
    if (client == null || !jetdijiCourier) return;
    try {
      final list = await client.tasks();
      final dash = await client.dashboard();
      deliveryReasons ??= await client.deliveryReasons();
      tasks
        ..clear()
        ..addAll(list.tasks.map(deliveryTaskFromJetdiji));
      jetdijiCounts = dash.counts;
      lastJetdijiError = null;
    } on JetDijiException catch (e) {
      lastJetdijiError = e.code;
    }
    notifyListeners();
  }

  Future<void> ensureDeliveryReasons() async {
    if (deliveryReasons != null || jetdiji == null || !usesJetdijiCourier) {
      return;
    }
    try {
      deliveryReasons = await jetdiji!.deliveryReasons();
      lastJetdijiError = null;
    } on JetDijiException catch (e) {
      lastJetdijiError = e.code;
    }
    notifyListeners();
  }

  Future<JetDijiRequirements?> loadTaskRequirements(String id) async {
    final client = jetdiji;
    if (client == null) return null;
    try {
      final detail = await client.taskDetail(id);
      if (lastCallFromDetail(detail) != null) calledTaskIds.add(id);
      final fromDetail = requirementsFromDetail(detail);
      final req = fromDetail ?? await client.requirements(id);
      requirementsByTask[id] = req;
      lastJetdijiError = null;
      notifyListeners();
      return req;
    } on JetDijiException catch (e) {
      lastJetdijiError = e.code;
      notifyListeners();
      return requirementsByTask[id];
    }
  }

  Future<String?> sendDeliveryOtp(
    String id, {
    required String receiverType,
  }) async {
    final client = jetdiji;
    if (client == null) return null;
    try {
      final challenge = await client.sendOtp(id, receiverType: receiverType);
      otpChallengeByTask[id] = challenge.challengeId;
      otpDevCodeByTask[id] = challenge.devCode;
      lastJetdijiError = null;
      notifyListeners();
      return challenge.devCode;
    } on JetDijiException catch (e) {
      lastJetdijiError = e.code;
      notifyListeners();
      return null;
    }
  }

  /// Pluxee anketi. Kargo finalize edilmez. Form sürümü yoksa taslak bekler.
  Future<PluxeeSubmitResult> submitPluxeeVisit(PluxeeDraft draft) async {
    String? version;
    final client = jetdiji;
    if (client != null && usesJetdijiCourier) {
      final req = await loadTaskRequirements(draft.taskId);
      version = req?.formVersionId;
    }
    final result = await const PluxeeSubmitter().run(
      draft: draft,
      formVersionId: version,
      now: DateTime.now(),
      newKey: Vault.newUuid,
      upload: (photo, key) async {
        if (client == null) throw StateError('JetDiji yok');
        final body = await client.uploadEvidence(
          draft.taskId,
          fileBytes: photo.bytes,
          filename: '${photo.slot}.jpg',
          requirementCode: photo.slot,
          idempotencyKey: key,
        );
        final id = body['evidenceId'] ?? body['id'];
        return id == null ? null : '$id';
      },
      saveForm: (formVersionId, values, key) async {
        if (client == null) throw StateError('JetDiji yok');
        await client.saveForm(
          draft.taskId,
          formVersionId: formVersionId,
          status: 'SUBMITTED',
          values: values,
          idempotencyKey: key,
        );
      },
    );
    await pluxee?.save(draft);
    notifyListeners();
    return result;
  }

  Future<bool> submitDeliveryForm(String id) async {
    final client = jetdiji;
    final version = requirementsByTask[id]?.formVersionId;
    if (client == null || version == null) return true;
    try {
      await client.saveForm(id, formVersionId: version, status: 'SUBMITTED');
      return true;
    } on JetDijiException catch (e) {
      lastJetdijiError = e.code;
      notifyListeners();
      return false;
    }
  }

  /// `telUri` döner ve saklanmaz.
  Future<String?> revealCallUri(String id) async {
    final client = jetdiji;
    if (client == null) return null;
    try {
      final data = await client.callRecipient(id);
      calledTaskIds.add(id);
      lastJetdijiError = null;
      notifyListeners();
      final tel = data['telUri'];
      return tel is String && tel.isNotEmpty ? tel : null;
    } on JetDijiException catch (e) {
      lastJetdijiError = e.code;
      notifyListeners();
      return null;
    }
  }

  Future<JetDijiBranchLoginResult> loginWithBranch({
    required String email,
    required String password,
    String? agencyId,
  }) async {
    final client = branchApi;
    if (client == null) {
      return const JetDijiBranchLoginResult(ok: false, errorCode: 'NO_CLIENT');
    }
    try {
      final login = await client.login(
        email: email,
        password: password,
        agencyId: agencyId,
      );
      branchUser = login.user;
      try {
        branchUser = await client.session();
      } on JetDijiException {
        // yetki okunamazsa operate kapalı kalır
      }
      jetdijiBranch = true;
      phase = AppPhase.branch;
      branchError = null;
      notifyListeners();
      await loadBranchHome();
      return const JetDijiBranchLoginResult(ok: true);
    } on JetDijiException catch (e) {
      lastJetdijiError = e.code;
      branchError = e.code;
      notifyListeners();
      if (e.code == 'AGENCY_SELECTION_REQUIRED') {
        return JetDijiBranchLoginResult(ok: false, agencies: e.agencies);
      }
      return JetDijiBranchLoginResult(ok: false, errorCode: e.code);
    }
  }

  Future<void> openBranchShell() async {
    if (await branchApi?.hasToken != true) return;
    jetdijiBranch = true;
    phase = AppPhase.branch;
    notifyListeners();
    await loadBranchHome();
  }

  Future<void> loadBranchHome() async {
    final client = branchApi;
    if (client == null) return;
    branchLoading = true;
    notifyListeners();
    try {
      final dash = await client.dashboard();
      final board = await client.dispatchBoard();
      branchDashboard = dash.withDispatch(board);
      branchError = null;
    } on JetDijiException catch (e) {
      branchError = e.code;
    } finally {
      branchLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadBranchShipments() async {
    final client = branchApi;
    if (client == null) return;
    branchLoading = true;
    notifyListeners();
    try {
      final prep = await client.preparation();
      final board = await client.dispatchBoard();
      final rows = <JetDijiShipmentRow>[
        ...shipmentRowsOf(prep),
        ...shipmentRowsOf(board),
      ];
      final seen = <String>{};
      branchShipments = [
        for (final row in rows)
          if (seen.add(row.shipmentId)) row,
      ];
      branchError = null;
    } on JetDijiException catch (e) {
      branchError = e.code;
    } finally {
      branchLoading = false;
      notifyListeners();
    }
  }

  Future<bool> handoverShipments({
    required String courierId,
    required List<String> shipmentIds,
  }) async {
    if (!branchCanOperate) return false;
    final client = branchApi;
    if (client == null || shipmentIds.isEmpty) return false;
    try {
      await client.handover(courierId: courierId, shipmentIds: shipmentIds);
      await loadBranchShipments();
      return true;
    } on JetDijiException catch (e) {
      branchError = e.code;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadBranchCouriers() async {
    final client = branchApi;
    if (client == null) return;
    branchLoading = true;
    notifyListeners();
    try {
      branchCouriers = await client.couriers();
      branchMap = await client.courierMap();
      branchError = null;
    } on JetDijiException catch (e) {
      branchError = e.code;
    } finally {
      branchLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadBranchCounts() async {
    final client = branchApi;
    if (client == null) return;
    try {
      final data = await client.counts();
      final raw = data['counts'] ?? data['items'] ?? data['rows'];
      branchCounts = [
        for (final row in raw is List ? raw : const [])
          if (row is Map) Map<String, dynamic>.from(row),
      ];
      branchError = null;
    } on JetDijiException catch (e) {
      branchError = e.code;
    }
    notifyListeners();
  }

  Future<String?> startBranchCount() async {
    if (!branchCanOperate) return null;
    try {
      final data = await branchApi!.startCount();
      final id = data['id'] ?? data['countId'];
      await loadBranchCounts();
      return id?.toString();
    } on JetDijiException catch (e) {
      branchError = e.code;
      notifyListeners();
      return null;
    }
  }

  Future<bool> scanBranchCount(String countId, String barcode) async {
    if (!branchCanOperate) return false;
    try {
      await branchApi!.countAction(countId, {
        'action': 'scan',
        'barcode': barcode,
      });
      return true;
    } on JetDijiException catch (e) {
      branchError = e.code;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadBranchPending() async {
    final client = branchApi;
    if (client == null) return;
    try {
      branchPending = await client.pending();
      branchError = null;
    } on JetDijiException catch (e) {
      branchError = e.code;
    }
    notifyListeners();
  }

  Future<bool> scanBranchReturn(String scanCode) async {
    if (!branchCanOperate) return false;
    try {
      await branchApi!.scanCourierReturn(scanCode: scanCode);
      await loadBranchPending();
      return true;
    } on JetDijiException catch (e) {
      branchError = e.code;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadBranchOutgoing() async {
    final client = branchApi;
    if (client == null) return;
    try {
      branchOutgoing = await client.outgoingOptions();
      branchError = null;
    } on JetDijiException catch (e) {
      branchError = e.code;
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>?> resolveOutgoingScan(String scanCode) async {
    try {
      final data = await branchApi!.resolveOutgoing(scanCode: scanCode);
      return data;
    } on JetDijiException catch (e) {
      branchError = e.code;
      notifyListeners();
      return null;
    }
  }

  Future<bool> sendOutgoingShipment({
    required String shipmentId,
    required String destinationWarehouseId,
    required String transferType,
    List<String> barcodes = const [],
  }) async {
    if (!branchCanOperate || shipmentId.isEmpty) return false;
    try {
      await branchApi!.sendOutgoing({
        'transferType': transferType,
        'destinationWarehouseId': destinationWarehouseId,
        'lines': [
          {'shipmentId': shipmentId, 'barcodes': barcodes},
        ],
      });
      await loadBranchOutgoing();
      return true;
    } on JetDijiException catch (e) {
      branchError = e.code;
      notifyListeners();
      return false;
    }
  }
}

class JetDijiBranchLoginResult {
  const JetDijiBranchLoginResult({
    required this.ok,
    this.agencies = const [],
    this.errorCode,
  });

  final bool ok;
  final List<JetDijiAgencyOption> agencies;
  final String? errorCode;
}
