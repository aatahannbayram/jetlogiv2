import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/client.dart';
import 'api/courier_tasks.dart';
import 'api/models.dart';
import 'api/panel_client.dart';
import 'api/panel_models.dart';
import 'data/outbox.dart';
import 'data/vault.dart';
import 'l10n.dart';
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
    this.panel,
    this.vault,
    this.waitForConfig = false,
    AppPhase? initialPhase,
  }) : outbox = outbox ?? OutboxStore(),
       phase = initialPhase ?? AppPhase.onboard {
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
  final PanelApi? panel;
  final Vault? vault;
  final bool waitForConfig;

  /// Panel cookie-session opened via [loginWithPanel]. Does not switch
  /// task/finalize/outbox off [api] (Fastify).
  bool panelLoggedIn = false;
  String? lastPanelError;

  static const panelDemoIdentifier = 'kurye@dijigoo.test';
  static const panelDemoPassword = 'demo';
  static const panelSessionExpired = 'PANEL_SESSION_EXPIRED';

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
  String? currentShiftId;

  void setShiftOpen(bool value) {
    if (shiftOpen == value) return;
    shiftOpen = value;
    if (value) {
      shiftStartedAt = DateTime.now();
      _enqueueShift(start: true);
    } else {
      currentShiftId = null;
      _enqueueShift(start: false);
    }
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
    if (v.isEmpty) return;
    if (zimmetScans.any((e) => e.code == v)) return;
    final now = DateTime.now();
    zimmetScans.insert(0, (
      code: v,
      time:
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
    ));
    notifyListeners();
  }

  void removeZimmetScan(String code) {
    zimmetScans.removeWhere((e) => e.code == code);
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
  // Koyu tema varsayılan; açık tema ve dil ayarlardan değişir.
  bool darkModeUi = true;
  String localeCode = 'tr';

  L10n get l10n => L10n(localeCode);

  void setLocale(String code) {
    localeCode = code == 'en' ? 'en' : 'tr';
    unawaited(vault?.saveLocale(localeCode));
    notifyListeners();
  }

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
    unawaited(vault?.saveDarkMode(darkModeUi));
    notifyListeners();
  }

  Future<void> restoreUiPrefs() async {
    final stored = await vault?.locale;
    if (stored == 'en' || stored == 'tr') localeCode = stored!;
    final dark = await vault?.darkMode;
    if (dark != null) darkModeUi = dark;
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
      if (t.isOpen) return t;
    }
    return null;
  }

  List<DeliveryTask> get remainingStops =>
      tasks.where((t) => t.isOpen && t.id != nextStop?.id).toList();

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

  final tickets = <SupportTicketDto>[];

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

  int get openCount => tasks.where((t) => t.isOpen).length;

  int get doneCount =>
      tasks.where((t) => t.status == TaskStatus.delivered || t.status == TaskStatus.failed).length;

  int get deliveredCount =>
      tasks.where((t) => t.status == TaskStatus.delivered).length;
  int get returnCount => tasks
      .where(
        (t) =>
            t.status == TaskStatus.failed || t.status == TaskStatus.cancelled,
      )
      .length;

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
    taskWatermark ??= await vault?.taskWatermark;
    await restoreUiPrefs();
    await restorePanelSession();
    await restoreOpenShift();
    notifyListeners();
  }

  /// Cookie jar’da panel oturumu varsa profili geri yükle. Görev çekmez.
  Future<void> restorePanelSession() async {
    final client = panel;
    if (client == null) return;
    if (!await client.hasStoredSession) return;
    await hydratePanelSession();
  }

  Future<void> hydratePanelSession() async {
    final client = panel;
    if (client == null) return;
    try {
      final profile = await client.fetchSession();
      if (profile == null) {
        expirePanelSession();
        return;
      }
      applyPanelProfile(profile);
    } catch (_) {
      panelLoggedIn = false;
      lastPanelError = 'PANEL_REQUEST_FAILED';
      notifyListeners();
    }
  }

  void expirePanelSession() {
    panelLoggedIn = false;
    lastPanelError = panelSessionExpired;
    notifyListeners();
  }

  void applyPanelProfile(PanelCourierProfileDto profile) {
    panelLoggedIn = true;
    lastPanelError = null;
    if (profile.fullName.isNotEmpty) {
      courier = courier.copyWith(fullName: profile.fullName);
    }
    notifyListeners();
  }

  /// Sunucuda açık vardiya varsa selfie’yi atla (crash / process kill).
  Future<void> restoreOpenShift() async {
    final client = api;
    if (client == null) return;
    try {
      final remote = await client.fetchCurrentShift();
      liveApi = client.lastWasLive;
      if (remote == null || !remote.isOpen || !liveApi) return;
      applyOpenShift(remote);
      unawaited(loadIdentity());
      unawaited(loadTasks());
      unawaited(loadTickets());
      unawaited(loadRoute());
    } catch (_) {
      liveApi = false;
    }
  }

  void applyOpenShift(ShiftDto shift) {
    if (!shift.isOpen) return;
    currentShiftId = shift.id;
    shiftOpen = true;
    shiftPhotoTaken = true;
    shiftStartedAt = DateTime.tryParse(shift.startedAt)?.toLocal();
    final p = shift.vehiclePlate;
    if (p != null && p.isNotEmpty) plate = p;
    if (phase == AppPhase.splash || phase == AppPhase.shift) {
      phase = AppPhase.main;
    }
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
    await vault?.clearTokens();
    await vault?.saveTaskWatermark(null);
    taskWatermark = null;
    shiftOpen = false;
    shiftPhotoTaken = false;
    shiftStartedAt = null;
    currentShiftId = null;
    demo = true;
    liveApi = false;
    routePlan = null;
    panelLoggedIn = false;
    lastPanelError = null;
    phase = AppPhase.splash;
    try {
      await panel?.logout();
    } catch (_) {}
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

  /// Panel `courier-auth/login` (cookie). Never writes Fastify JWT / vault
  /// tokens and never calls `fetchTasks` / `finalize`.
  Future<bool> loginWithPanel({
    required String identifier,
    required String password,
  }) async {
    lastPanelError = null;
    final id = identifier.trim();
    final client = panel;
    if (client == null) {
      if (id == panelDemoIdentifier && password == panelDemoPassword) {
        panelLoggedIn = true;
        notifyListeners();
        return true;
      }
      lastPanelError = 'PANEL_UNAVAILABLE';
      notifyListeners();
      return false;
    }
    try {
      final profile = await client.login(identifier: id, password: password);
      panelLoggedIn = true;
      if (profile.fullName.isNotEmpty) {
        courier = courier.copyWith(fullName: profile.fullName);
      }
      notifyListeners();
      return true;
    } on PanelApiException catch (e) {
      lastPanelError = e.code;
      notifyListeners();
      return false;
    } catch (_) {
      lastPanelError = 'PANEL_REQUEST_FAILED';
      notifyListeners();
      return false;
    }
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
    _enqueueShift(start: true);
    notifyListeners();
    unawaited(loadIdentity());
    unawaited(loadRoute());
    unawaited(loadTasks());
    unawaited(loadTickets());
  }

  Map<String, Object?> _shiftFix() {
    final t = nextStop;
    return {
      'lat': t?.lat ?? 38.1512,
      'lng': t?.lng ?? 29.0614,
      'accuracy': 25,
      'capturedAt': DateTime.now().toUtc().toIso8601String(),
      'isMocked': false,
    };
  }

  void _enqueueShift({required bool start}) {
    final event = outbox.enqueue(
      operation: start ? SyncOperation.shiftStart : SyncOperation.shiftEnd,
      payload: start
          ? {
              'location': _shiftFix(),
              'vehiclePlate': plate,
              'permissions': {
                'locationAlways': false,
                'notifications': notifyEnabled,
                'camera': true,
              },
            }
          : {'location': _shiftFix()},
    );
    if (online) {
      if (api == null) {
        event.status = 'applied';
      } else {
        unawaited(_flushOutbox());
      }
    }
  }

  Future<void> _seedDemoTokenThenIdentity() async {
    await _saveDemoTokens();
    await loadIdentity();
    await loadRoute();
    await loadTasks();
    await loadTickets();
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

  /// Live `GET /v1/tasks`. Demo interceptor aynı tohumu TaskSummary olarak
  /// döner; live boş/401'de mevcut liste kalır (test + offline).
  String? taskWatermark;

  Future<void> loadTasks() async {
    final client = api;
    if (client == null) return;
    try {
      final remote = await client.fetchTasks();
      liveApi = client.lastWasLive;
      if (remote.isEmpty && !liveApi) return;
      tasks
        ..clear()
        ..addAll(remote);
      if (liveApi) unawaited(_rememberWatermark(client.lastSyncedAt));
    } catch (_) {
      liveApi = false;
    }
    notifyListeners();
  }

  /// Watermark varsa `GET /v1/sync/changes` (çıkarılan id'ler dahil).
  /// Yoksa veya `resyncRequired` ise tam [loadTasks].
  Future<void> pullTasks() async {
    final client = api;
    if (client == null) return;
    final since = taskWatermark;
    if (since == null) {
      await loadTasks();
      return;
    }
    try {
      final delta = await client.fetchChanges(since: since);
      liveApi = client.lastWasLive;
      if (!liveApi) return;
      if (delta.resyncRequired) {
        await loadTasks();
        return;
      }
      applyTaskDelta(
        changed: delta.tasks,
        removedIds: delta.removedTaskIds,
      );
      if (delta.custody != null) custodyItems = delta.custody!;
      unawaited(_rememberWatermark(delta.syncedAt));
    } catch (_) {
      await loadTasks();
    }
    notifyListeners();
  }

  void applyTaskDelta({
    required List<DeliveryTask> changed,
    required Iterable<String> removedIds,
  }) {
    final previous = {for (final t in tasks) t.id: t};
    final pending = {
      for (final e in outbox.events)
        if (e.pending && e.subjectId != null) e.subjectId!,
    };
    tasks.removeWhere((t) => removedIds.contains(t.id));
    for (final incoming in changed) {
      if (pending.contains(incoming.id)) continue;
      final i = tasks.indexWhere((t) => t.id == incoming.id);
      if (i >= 0) {
        tasks[i] = incoming;
      } else {
        tasks.add(incoming);
      }
    }
    for (final id in removedIds) {
      final was = previous[id];
      if (was != null && was.isOpen) {
        _prependNotification(
          title: 'Durak çekildi',
          body: '${was.ref} · başka kuryeye verildi.',
          icon: LucideIcons.truck,
          tint: Dg.amberBg,
          ink: Dg.amber,
        );
      }
    }
    for (final incoming in changed) {
      final was = previous[incoming.id];
      if (was == null && incoming.isOpen) {
        _prependNotification(
          title: 'Yeni durak atandı',
          body: '${incoming.ref} · ${incoming.recipient}',
          icon: LucideIcons.truck,
          tint: Dg.greenBg,
          ink: Dg.green,
        );
      } else if (incoming.status == TaskStatus.cancelled &&
          was != null &&
          was.status != TaskStatus.cancelled) {
        _prependNotification(
          title: 'Durak iptal',
          body:
              '${incoming.ref.isEmpty ? was.ref : incoming.ref} · ${incoming.recipient.isEmpty ? was.recipient : incoming.recipient}',
          icon: LucideIcons.circleX,
          tint: Dg.redBg,
          ink: Dg.red,
        );
      }
    }
  }

  Future<void> _rememberWatermark(String? value) async {
    if (value == null || value.isEmpty) return;
    taskWatermark = value;
    await vault?.saveTaskWatermark(value);
  }

  void _prependNotification({
    required String title,
    required String body,
    required IconData icon,
    required Color tint,
    required Color ink,
  }) {
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final shifted = {for (final i in _readNotifications) i + 1};
    _readNotifications
      ..clear()
      ..addAll(shifted);
    notifications.insert(
      0,
      AppNotification(
        title: title,
        body: body,
        time: time,
        icon: icon,
        tint: tint,
        ink: ink,
      ),
    );
  }

  Future<void> refreshField() async {
    await Future.wait([pullTasks(), loadTickets(), loadRoute()]);
  }

  Future<void> loadTickets() async {
    final client = api;
    if (client == null) return;
    try {
      final remote = await client.fetchSupportTickets();
      liveApi = client.lastWasLive;
      replaceTickets(remote);
    } catch (_) {
      liveApi = false;
    }
    notifyListeners();
  }

  /// Sunucu listesi gelince bekleyen (henüz sync olmamış) yerel talepleri tut.
  void replaceTickets(List<SupportTicketDto> remote) {
    final pendingIds = {
      for (final e in outbox.events)
        if (e.pending && e.operation == SyncOperation.supportTicketCreate)
          e.clientEventId,
    };
    final keep = [
      for (final t in tickets)
        if (pendingIds.contains(t.id) && !remote.any((r) => r.id == t.id)) t,
    ];
    tickets
      ..clear()
      ..addAll(remote)
      ..addAll(keep);
  }

  void createSupportTicket({
    required String category,
    required String subject,
    required String body,
    String? taskId,
  }) {
    final event = outbox.enqueue(
      operation: SyncOperation.supportTicketCreate,
      subjectId: taskId,
      payload: {
        'category': category,
        'subject': subject,
        'body': body,
        if (taskId != null) 'taskId': taskId,
        'mediaIds': const <String>[],
        'attachDiagnostics': false,
      },
    );
    tickets.insert(
      0,
      SupportTicketDto(
        id: event.clientEventId,
        reference: 'DST-LOCAL',
        category: category,
        subject: subject,
        body: body,
        status: 'open',
        priority: 'normal',
        createdAt: event.occurredAt.toIso8601String(),
        taskId: taskId,
      ),
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
    final steps = startTransitions(
      wireStatus: t.wireStatus,
      rowVersion: t.rowVersion,
    );
    OutboxEvent? last;
    for (final step in steps) {
      last = outbox.enqueue(
        operation: SyncOperation.taskTransition,
        subjectId: id,
        payload: {
          'rowVersion': step.rowVersion,
          'to': step.to,
        },
      );
      if (online && api == null) last.status = 'applied';
    }
    if (steps.isNotEmpty) {
      t.rowVersion += steps.length;
      t.wireStatus = 'IN_PROGRESS';
    }
    if (online && api != null && last != null) {
      unawaited(_flushOutbox());
    }
    notifyListeners();
  }

  Map<String, Object?> _finalizePayload(
    DeliveryTask t, {
    required String outcomeCode,
    String? note,
  }) {
    return {
      'rowVersion': t.rowVersion,
      'workflowVersion': t.workflowVersion,
      'outcomeCode': outcomeCode,
      'answers': const <Map<String, Object?>>[],
      if (note != null && note.isNotEmpty) 'note': note,
    };
  }

  void deliverTask(String id, {String? receivedBy}) {
    final t = taskById(id);
    t.status = TaskStatus.delivered;
    t.receivedBy = receivedBy;
    final event = outbox.enqueue(
      operation: SyncOperation.taskFinalize,
      subjectId: id,
      payload: _finalizePayload(t, outcomeCode: 'DELIVERED', note: receivedBy),
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
      operation: SyncOperation.taskFinalize,
      subjectId: id,
      payload: _finalizePayload(
        t,
        outcomeCode: failureOutcomeCode(reason),
        note: note == null || note.isEmpty ? reason : '$reason · $note',
      ),
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
      final results = await client.syncBatch(
        installationId: install,
        events: pending,
      );
      liveApi = client.lastWasLive;
      await outbox.applyResults([
        for (final r in results) (id: r.clientEventId, status: r.status),
      ]);
      if (liveApi) {
        await Future.wait([pullTasks(), loadTickets()]);
      }
    } catch (_) {
      // Ağ/istek hatası: "kapalı ortamda" (sinyal yokken) beklenen durum tam
      // olarak bu. Öğeleri applied say(drain) diye işaretlersek gönderilmemiş
      // teslimatları sessizce kaybederiz — pending bırak, bir sonraki
      // pushSyncQueue()/online geçişinde tekrar denensin.
      liveApi = false;
    }
    notifyListeners();
  }

  bool verifyDeliveryOtp(String code) => code == '482913';
}
