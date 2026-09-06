import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:latlong2/latlong.dart';

import 'alerts.dart';
import 'api/client.dart';
import 'notif.dart';
import 'push.dart';
import 'api/courier_tasks.dart';
import 'api/models.dart';
import 'api/panel_client.dart';
import 'api/panel_models.dart';
import 'data/outbox.dart';
import 'data/vault.dart';
import 'geo.dart';
import 'l10n.dart';
import 'launchers.dart';
import 'locate.dart';
import 'log.dart';
import 'media_upload.dart';
import 'models.dart';
import 'road.dart';
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
    Future<PushPermit> Function()? requestPush,
    Future<PushPermit> Function()? readPush,
  }) : outbox = outbox ?? OutboxStore(),
       phase = initialPhase ?? AppPhase.onboard,
       requestPush = requestPush ?? requestPushPermit,
       readPush = readPush ?? readPushPermit {
    configReady = !waitForConfig;
    if (!kReleaseMode && !waitForConfig) {
      tasks.addAll(_buildDemoTasks());
      notifications.addAll(_buildDemoNotifications());
    } else {
      demo = false;
      routePlan = null;
    }
    // Sabit demo-tohumu: gerçek enqueue() id'lerinin izlediği
    // 00000000-0000-4000-a000-{sequence} kalıbından bilinçli olarak farklı,
    // yoksa uygulamanın ilk gerçek enqueue()'u (sequence=1) bu id ile çakışır.
    if (!kReleaseMode && !waitForConfig) {
      this.outbox.seedQueued(
        OutboxEvent(
          clientEventId: 'demo-seed-t4-0001',
          operation: SyncOperation.taskTransition,
          subjectId: 't4',
          occurredAt: DateTime.utc(2026, 8, 25, 10, 12),
          sequence: 1,
          payload: const {
            'to': 'FAILED',
            'reason': 'ALICI_YOK',
            'note': 'Alıcı yoktu',
          },
        ),
      );
    }
  }

  final OutboxStore outbox;
  final MobileApi? api;
  final PanelApi? panel;
  final Vault? vault;
  final bool waitForConfig;
  final Future<PushPermit> Function() requestPush;
  final Future<PushPermit> Function() readPush;

  /// Panel cookie-session opened via [loginWithPanel]. Does not switch
  /// task/finalize/outbox off [api] (Fastify).
  bool panelLoggedIn = false;
  String? lastPanelError;
  String? lastActivationError;
  DateTime? otpResendAt;
  bool activationBusy = false;

  static const panelDemoIdentifier = 'kurye@dijigoo.test';
  static const panelDemoPassword = 'demo';
  static const panelSessionExpired = 'PANEL_SESSION_EXPIRED';

  AppConfig config = AppConfig.demo;
  bool configReady = true;
  bool liveApi = false;
  RoutePlanDto? routePlan = RoutePlanDto.demo();
  double selfLat = 38.1476;
  double selfLng = 29.0702;
  bool showFleet = false;

  /// OSRM bacakları — görünen durak için yol çizgisi. Tam gün geometrisi
  /// tek durakta "şaşırmış" görünmesin diye ayrı tutulur.
  final Map<String, RoadLeg> _roadLegs = {};
  final Map<String, Future<RoadLeg?>> _roadInflight = {};

  /// Kurye konumu + kalan duraklar: SLA-ağırlıklı sıra + yol ağı çizgisi.
  DayRoute? dayRoute;
  String? _dayRouteKey;
  final Map<String, Future<DayRoute>> _dayInflight = {};

  bool get dayRouteLoading => _dayInflight.isNotEmpty;

  RoadSlice? roadToTask(String taskId) => dayRoute?.legFor(taskId);

  RoadLeg? roadBetween(List<LatLng> points) => _roadLegs[roadCacheKey(points)];

  List<RouteStopInput> get _openRouteStops => [
    for (final t in tasks.where((t) => t.isOpen))
      RouteStopInput(id: t.id, at: LatLng(t.lat, t.lng), urgency: _urgencyOf(t)),
  ];

  double _urgencyOf(DeliveryTask t) {
    if (t.status == TaskStatus.inProgress) return 1;
    final sla = t.slaMinutesLeft;
    if (sla != null) return (1 - sla / 180).clamp(0.0, 1.0);
    if (t.status == TaskStatus.queued) return 0.45;
    return 0;
  }

  /// Açık görevler: gün rotasının ziyaret sırası, yoksa API planı, yoksa
  /// liste sırası. Aynı kapı grupları bitişik kalır.
  List<DeliveryTask> get orderedOpenTasks {
    final open = tasks.where((t) => t.isOpen).toList();
    final ids = dayRoute?.stopTaskIds;
    if (ids != null && ids.isNotEmpty) {
      final byId = {for (final t in open) t.id: t};
      final out = <DeliveryTask>[];
      final seen = <String>{};
      for (final id in ids) {
        final t = byId[id];
        if (t != null && seen.add(t.id)) out.add(t);
      }
      for (final t in open) {
        if (seen.add(t.id)) out.add(t);
      }
      return out;
    }
    return _tasksInPlanOrder(open, routePlan);
  }

  Future<void> ensureRoad(List<LatLng> points) async {
    if (points.length < 2) return;
    final key = roadCacheKey(points);
    if (_roadLegs.containsKey(key)) return;
    final pending = _roadInflight[key];
    if (pending != null) {
      await pending;
      return;
    }
    final future = fetchRoadLeg(points);
    _roadInflight[key] = future;
    try {
      final leg = await future;
      if (leg != null) {
        _roadLegs[key] = leg;
        DgLog.i(LogLayer.route, 'osrm ${leg.meters}m ${leg.minutes}dk');
        notifyListeners();
      } else {
        DgLog.w(LogLayer.route, 'osrm miss $key');
      }
    } finally {
      _roadInflight.remove(key);
    }
  }

  bool get _skipLiveRouteHttp {
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains(
        'TestWidgetsFlutterBinding',
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> ensureDayRoute({String? pinFirstId}) async {
    final origin = LatLng(selfLat, selfLng);
    final stops = _openRouteStops;
    final pin = pinFirstId ?? nextStop?.id;
    final key = dayRouteCacheKey(origin, stops, pinFirstId: pin);
    if (_dayRouteKey == key && dayRoute != null && dayRoute!.fromLiveEngine) {
      return;
    }
    if (_dayRouteKey != key || dayRoute == null) {
      dayRoute = planDayRouteLocal(origin, stops, pinFirstId: pin);
      _dayRouteKey = key;
      notifyListeners();
    }
    if (_skipLiveRouteHttp) return;
    final pending = _dayInflight[key];
    if (pending != null) {
      await pending;
      return;
    }
    final future = planDayRoute(origin, stops, pinFirstId: pin);
    _dayInflight[key] = future;
    try {
      final next = await future;
      if (_dayRouteKey == key) {
        dayRoute = next;
        DgLog.i(
          LogLayer.route,
          '${next.provider} ${next.meters}m ${next.minutes}dk est=${next.estimated}',
        );
        notifyListeners();
      }
    } finally {
      _dayInflight.remove(key);
    }
  }

  List<FleetCourier> get fleet {
    return [
      FleetCourier(
        id: courier.code,
        name: courier.fullName,
        lat: selfLat,
        lng: selfLng,
        self: true,
        status: shiftOpen ? 'on' : 'off',
        photoUrl: courier.photoUrl,
      ),
      FleetCourier(
        id: 'c-mehmet',
        name: 'Mehmet Aydın',
        lat: 38.1551,
        lng: 29.0528,
        status: 'on',
        photoUrl: personPhotoAsset('Mehmet Aydın'),
      ),
      FleetCourier(
        id: 'c-elif',
        name: 'Elif Koç',
        lat: 38.1422,
        lng: 29.0744,
        status: 'break',
        photoUrl: personPhotoAsset('Elif Koç'),
      ),
    ];
  }

  List<FleetCourier> get visibleFleet =>
      showFleet ? fleet : fleet.where((c) => c.self).toList();

  void toggleFleet() {
    showFleet = !showFleet;
    notifyListeners();
  }

  bool routeLoading = false;
  bool cipherOn = false;
  String? challengeId;
  String? deliveryChallengeId;
  String? deliveryOtpToken;
  String? startPhotoMediaId;
  final stepAnswers = <String, List<Map<String, Object?>>>{};

  AppPhase phase;
  bool demo = true;
  bool online = true;
  bool shiftOpen = true;
  bool shiftPhotoTaken = true;
  DateTime? shiftStartedAt = DateTime.now();
  String? currentShiftId;

  /// Yalnız demo oturumu (widget test / "Demoyu aç"). Canlıda selfie + API.
  bool get bypassShiftGate => !kReleaseMode && demo;

  void ensureOpenForTest() {
    if (!bypassShiftGate || shiftOpen) return;
    setShiftOpen(true);
  }

  void setShiftOpen(bool value) {
    if (shiftOpen == value) return;
    shiftOpen = value;
    if (value) {
      shiftStartedAt = DateTime.now();
      shiftPhotoTaken = true;
      _enqueueShift(start: true);
      DgLog.i(LogLayer.shift, 'open');
    } else {
      currentShiftId = null;
      _enqueueShift(start: false);
      DgLog.i(LogLayer.shift, 'close');
    }
    unawaited(_persistShift());
    resyncAlerts();
    notifyListeners();
    if (value) unawaited(ensureDayRoute());
  }

  Future<void> _persistShift() async {
    await vault?.saveShift(open: shiftOpen, startedAt: shiftStartedAt);
  }

  Future<void> restoreLocalShift() async {
    if (bypassShiftGate) {
      prepareTestLaunch();
      return;
    }
    final open = await vault?.shiftIsOpen ?? false;
    if (!open) {
      shiftOpen = false;
      shiftPhotoTaken = false;
      return;
    }
    shiftOpen = true;
    shiftPhotoTaken = true;
    shiftStartedAt = await vault?.shiftStartedAt ?? DateTime.now();
    if (phase == AppPhase.splash ||
        phase == AppPhase.shift ||
        phase == AppPhase.onboard) {
      phase = AppPhase.main;
    }
  }

  /// Debug/demo: splash'ten başla, selfie yapılmış varsay.
  void prepareTestLaunch() {
    if (!bypassShiftGate) return;
    shiftPhotoTaken = true;
    shiftOpen = true;
    shiftStartedAt ??= DateTime.now().subtract(
      const Duration(hours: 5, minutes: 12),
    );
    if (phase == AppPhase.shift) phase = AppPhase.splash;
    DgLog.i(LogLayer.boot, 'test launch · selfie skipped · shift armed');
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

  final Set<String> _readNotificationIds = {};
  final Set<String> _dismissedNotificationIds = {};
  int _notifSeq = 0;

  final notifications = <AppNotification>[];

  List<AppNotification> get visibleNotifications => [
    for (final n in notifications)
      if (!_dismissedNotificationIds.contains(n.id)) n,
  ];

  int get unreadNotifCount => visibleNotifications
      .where((n) => !_readNotificationIds.contains(n.id))
      .length;

  bool isNotifRead(String id) => _readNotificationIds.contains(id);

  AppNotification? notificationById(String id) {
    for (final n in visibleNotifications) {
      if (n.id == id) return n;
    }
    return null;
  }

  void markNotificationRead(String id) {
    if (!_readNotificationIds.add(id)) return;
    _persistNotifState();
    unawaited(FieldAlerts.dismissInbox(id));
    _syncNotifBadge();
    if (liveApi) {
      unawaited(api?.markNotificationsRead(ids: [id]));
    }
    notifyListeners();
  }

  void markNotificationUnread(String id) {
    if (_dismissedNotificationIds.contains(id)) return;
    if (!_readNotificationIds.remove(id)) return;
    _persistNotifState();
    _syncNotifBadge();
    notifyListeners();
  }

  void markAllNotificationsRead() {
    final before = _readNotificationIds.length;
    final ids = [for (final n in visibleNotifications) n.id];
    for (final id in ids) {
      _readNotificationIds.add(id);
    }
    if (_readNotificationIds.length == before) return;
    _persistNotifState();
    for (final id in ids) {
      unawaited(FieldAlerts.dismissInbox(id));
    }
    _syncNotifBadge();
    if (liveApi) unawaited(api?.markNotificationsRead(all: true));
    notifyListeners();
  }

  void dismissNotification(String id) {
    if (!_dismissedNotificationIds.add(id)) return;
    _readNotificationIds.add(id);
    _persistNotifState();
    unawaited(FieldAlerts.dismissInbox(id));
    _syncNotifBadge();
    notifyListeners();
  }

  void restoreNotification(String id) {
    if (!_dismissedNotificationIds.remove(id)) return;
    _persistNotifState();
    _syncNotifBadge();
    notifyListeners();
  }

  void _syncNotifBadge() {
    if (!notifyEnabled || notifyOsBlocked) return;
    unawaited(FieldAlerts.syncBadge(unreadNotifCount));
  }

  void _persistNotifState() {
    unawaited(
      vault?.saveNotificationState(
        readIds: _readNotificationIds,
        dismissedIds: _dismissedNotificationIds,
      ),
    );
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

  /// Şube: eldeki kalemleri acenteye bırakır. Kurye: barkodla tenant
  /// kalemini bulup `takeover` ile üzerine alır.
  Future<bool> completeZimmet() async {
    if (api == null) {
      zimmetScans.clear();
      notifyListeners();
      return true;
    }
    if (zimmetMode == 'kurye') return _completeZimmetTakeover();
    if (zimmetMode != 'sube') {
      zimmetScans.clear();
      notifyListeners();
      return true;
    }

    final itemIds = <String>[
      for (final scan in zimmetScans)
        if (_custodyItemByBarcode(scan.code) case final item?) item.id,
    ];
    if (itemIds.isEmpty) {
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
      _prependNotification(
        kind: NotifKind.custody,
        title: 'Zimmet onaylandı',
        body: 'Şube zimmetinden ${itemIds.length} gönderi üstüne alındı.',
        icon: LucideIcons.package,
        tint: Dg.violetBg,
        ink: Dg.violet,
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      custodyHandoverPending = false;
      notifyListeners();
    }
  }

  Future<bool> _completeZimmetTakeover() async {
    for (final scan in List.of(zimmetScans)) {
      if (_custodyItemByBarcode(scan.code) != null) continue;
      try {
        final found = await api!.fetchCustody(barcode: scan.code);
        for (final item in found) {
          if (custodyItems.every((row) => row.id != item.id)) {
            custodyItems = [...custodyItems, item];
          }
        }
      } catch (_) {}
    }

    final itemIds = <String>[
      for (final scan in zimmetScans)
        if (_custodyItemByBarcode(scan.code) case final item?) item.id,
    ];
    if (itemIds.isEmpty) {
      zimmetScans.clear();
      notifyListeners();
      return true;
    }

    custodyHandoverPending = true;
    notifyListeners();
    try {
      final result = await api!.takeoverFromBranch(
        itemIds: itemIds,
        branchName: 'Şube',
      );
      custodyItems = result.remaining;
      liveApi = api!.lastWasLive;
      zimmetScans.clear();
      _prependNotification(
        kind: NotifKind.custody,
        title: 'Zimmet alındı',
        body: 'Şubeden ${itemIds.length} gönderi üzerine alındı.',
        icon: LucideIcons.package,
        tint: Dg.violetBg,
        ink: Dg.violet,
      );
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
  bool notifyOsBlocked = false;
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

  Future<PushPermit?> toggleNotifyPref() async {
    if (notifyEnabled) {
      notifyEnabled = false;
      unawaited(vault?.saveNotifyEnabled(false));
      unawaited(FieldAlerts.cancelAll());
      notifyListeners();
      return null;
    }
    return _enableNotify();
  }

  Future<PushPermit> _enableNotify() async {
    final permit = await requestPush();
    notifyOsBlocked = permit == PushPermit.blocked;
    if (permit != PushPermit.granted) {
      notifyListeners();
      return permit;
    }
    notifyEnabled = true;
    unawaited(vault?.saveNotifyEnabled(true));
    resyncAlerts();
    unawaited(FieldPush.attach(requestOs: true).then((_) => registerPushToken()));
    notifyListeners();
    return permit;
  }

  Future<void> reconcilePushPermit() async {
    final permit = await readPush();
    final blocked = permit != PushPermit.granted;
    if (notifyOsBlocked == blocked) {
      if (notifyEnabled && !blocked) resyncAlerts();
      return;
    }
    notifyOsBlocked = blocked;
    if (blocked) {
      unawaited(FieldAlerts.cancelAll());
    } else if (notifyEnabled) {
      resyncAlerts();
    }
    notifyListeners();
  }

  /// Arka plandan dönüş: izin + canlı görev/destek/rota. FCM yoksa bile
  /// dispatcher ataması bir sonraki öne gelişte görünür.
  Future<void> onForeground() async {
    await reconcilePushPermit();
    if (!liveApi || phase != AppPhase.main) return;
    unawaited(registerPushToken());
    await refreshField();
  }

  void resyncAlerts() {
    if (!notifyEnabled || notifyOsBlocked) {
      unawaited(FieldAlerts.cancelAll());
      return;
    }
    _syncNotifBadge();
    if (!shiftOpen) {
      unawaited(FieldAlerts.cancelShiftReminder());
      return;
    }
    unawaited(
      FieldAlerts.scheduleShiftReminder(
        title: l10n.notifShift,
        body: l10n.notifShiftBody,
      ),
    );
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
    _readNotificationIds.addAll(await vault?.readNotificationIds ?? const {});
    _dismissedNotificationIds.addAll(
      await vault?.dismissedNotificationIds ?? const {},
    );
    final notify = await vault?.notifyEnabled;
    if (notify != null) notifyEnabled = notify;
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
    KycDocOption(
      label: 'Yeni kimlik arka yüz',
      icon: LucideIcons.rectangleEllipsis,
    ),
    KycDocOption(label: 'Eski kimlik', icon: LucideIcons.contact),
    KycDocOption(label: 'Pasaport', icon: LucideIcons.bookOpen),
    KycDocOption(label: 'Yabancı kimlik', icon: LucideIcons.globe),
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
      if (t.status == TaskStatus.inProgress) return t;
    }
    final ordered = orderedOpenTasks;
    if (ordered.isNotEmpty) return ordered.first;
    return null;
  }

  List<DeliveryTask> get remainingStops {
    final next = nextStop?.id;
    return [
      for (final t in orderedOpenTasks)
        if (t.id != next) t,
    ];
  }

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

  final tasks = <DeliveryTask>[];

  int get openCount => tasks.where((t) => t.isOpen).length;

  int get doneCount => tasks
      .where(
        (t) =>
            t.status == TaskStatus.delivered || t.status == TaskStatus.failed,
      )
      .length;

  int get deliveredCount =>
      tasks.where((t) => t.status == TaskStatus.delivered).length;
  int get returnCount => tasks
      .where(
        (t) =>
            t.status == TaskStatus.failed || t.status == TaskStatus.cancelled,
      )
      .length;

  DeliveryTask taskById(String id) => tasks.firstWhere((t) => t.id == id);

  String _taskName(String? id) {
    if (id == null) return 'Kayıt';
    for (final t in tasks) {
      if (t.id == id) return t.recipient;
    }
    return id;
  }

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
    await restoreLocalShift();
    await restorePanelSession();
    await restoreOpenShift();
    DgLog.i(
      LogLayer.boot,
      'bootstrap live=$liveApi demo=$demo phase=${phase.name}',
    );
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
    unawaited(_persistShift());
    notifyListeners();
  }

  void finishOnboard() {
    unawaited(vault?.markOnboardSeen());
    phase = AppPhase.splash;
    notifyListeners();
  }

  void skipToDemo() {
    demo = true;
    if (tasks.isEmpty) {
      tasks.addAll(_buildDemoTasks());
    }
    if (notifications.every((n) => !n.id.startsWith('demo-'))) {
      notifications.insertAll(0, _buildDemoNotifications());
    }
    routePlan = RoutePlanDto.demo();
    phase = AppPhase.main;
    shiftOpen = true;
    shiftPhotoTaken = true;
    shiftStartedAt = DateTime.now().subtract(
      const Duration(hours: 5, minutes: 12),
    );
    unawaited(_persistShift());
    dayRoute = planDayRouteLocal(
      LatLng(selfLat, selfLng),
      _openRouteStops,
      pinFirstId: 't1',
    );
    _dayRouteKey = dayRouteCacheKey(
      LatLng(selfLat, selfLng),
      _openRouteStops,
      pinFirstId: 't1',
    );
    DgLog.i(LogLayer.session, 'skipToDemo · selfie assumed · main');
    notifyListeners();
    unawaited(ensureDayRoute(pinFirstId: 't1'));
    unawaited(_seedDemoTokenThenIdentity());
  }

  /// Canlı giriş: sahte durak yok. Token varsa vardiya/izin, yoksa OTP.
  Future<void> enterField() async {
    _stripDemoField();
    notifyListeners();
    final token = await vault?.accessToken;
    final real =
        token != null && token.isNotEmpty && token != 'demo-access';
    if (real) {
      await restoreOpenShift();
      if (phase == AppPhase.main) {
        unawaited(refreshSelfPosition());
        unawaited(loadIdentity());
        unawaited(loadTasks());
        unawaited(loadTickets());
        return;
      }
      completeActivation();
      return;
    }
    finishSplash();
  }

  static const _kDemoTaskIds = {'t1', 't2', 't3', 't4', 't5'};

  void _stripDemoField() {
    demo = false;
    routePlan = null;
    dayRoute = null;
    _dayRouteKey = null;
    tasks.removeWhere((t) => _kDemoTaskIds.contains(t.id));
    notifications.removeWhere((n) => n.id.startsWith('demo-'));
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
    unawaited(vault?.saveShift(open: false));
    currentShiftId = null;
    demo = false;
    liveApi = false;
    routePlan = null;
    panelLoggedIn = false;
    lastPanelError = null;
    phase = AppPhase.splash;
    DgLog.i(LogLayer.session, 'logout');
    try {
      await panel?.logout();
    } catch (_) {}
    notifyListeners();
  }

  Future<bool> requestActivationCode(String phone) async {
    lastActivationError = null;
    activationBusy = true;
    notifyListeners();
    final install = await vault?.installationId() ?? Vault.newUuid();
    try {
      final res = await api?.startActivation(phone, install);
      challengeId = res?['challengeId'] as String?;
      liveApi = api?.lastWasLive ?? false;
      final rawResend = res?['resendAvailableAt'] as String?;
      otpResendAt = rawResend == null ? null : DateTime.tryParse(rawResend);
      if (challengeId == null) {
        if (kReleaseMode) {
          lastActivationError = 'NO_CHALLENGE';
          return false;
        }
        challengeId = Vault.newUuid();
        liveApi = false;
      }
      return true;
    } catch (e) {
      lastActivationError = _dioMessage(e) ?? 'REQUEST_FAILED';
      if (kReleaseMode) return false;
      challengeId = Vault.newUuid();
      liveApi = false;
      return true;
    } finally {
      activationBusy = false;
      notifyListeners();
    }
  }

  String? _dioMessage(Object e) {
    if (e is! DioException) return null;
    final data = e.response?.data;
    if (data is Map) {
      final message = data['message'] as String?;
      if (message != null && message.trim().isNotEmpty) return message.trim();
      final code = data['code'] as String?;
      if (code != null && code.isNotEmpty) return code;
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return 'NETWORK';
      default:
        return null;
    }
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
    if (!kReleaseMode && code == '123456') {
      demo = true;
      await _saveDemoTokens();
      return true;
    }
    final install = await vault?.installationId() ?? Vault.newUuid();
    final id = challengeId;
    if (api == null || id == null) return false;
    lastActivationError = null;
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
    } catch (e) {
      lastActivationError = _dioMessage(e) ?? 'VERIFY_FAILED';
      return false;
    }
  }

  void completeActivation() {
    phase = AppPhase.permissions;
    notifyListeners();
  }

  void completePermissions() {
    unawaited(refreshSelfPosition());
    if (bypassShiftGate) {
      shiftPhotoTaken = true;
      DgLog.i(LogLayer.shift, 'permissions done · selfie skipped');
      openShift();
      return;
    }
    phase = AppPhase.shift;
    notifyListeners();
  }

  Future<void> takeShiftPhoto([String? path]) async {
    if (!kReleaseMode && (path == null || path.isEmpty || path.startsWith('test://'))) {
      shiftPhotoTaken = true;
      notifyListeners();
      unawaited(_storeShiftPhoto(path));
      return;
    }
    shiftPhotoTaken = true;
    notifyListeners();
    final id = await _storeShiftPhoto(path);
    if (id == null && kReleaseMode) {
      shiftPhotoTaken = false;
      startPhotoMediaId = null;
      notifyListeners();
    }
  }

  Future<String?> _storeShiftPhoto(String? path) async {
    final id = await uploadFileEvidence(
      api: api,
      path: path,
      kind: 'photo',
      stepKey: 'shift_start',
    );
    if (id == null) return null;
    startPhotoMediaId = id;
    notifyListeners();
    return id;
  }

  void openShift() {
    if (!shiftPhotoTaken && !bypassShiftGate) return;
    shiftOpen = true;
    shiftStartedAt = DateTime.now();
    phase = AppPhase.main;
    _enqueueShift(start: true);
    unawaited(_persistShift());
    notifyListeners();
    unawaited(refreshSelfPosition());
    unawaited(loadIdentity());
    unawaited(loadRoute());
    unawaited(loadTasks());
    unawaited(loadTickets());
  }

  Map<String, Object?> _shiftFix() {
    return {
      'lat': selfLat,
      'lng': selfLng,
      'accuracy': 25,
      'capturedAt': DateTime.now().toUtc().toIso8601String(),
      'isMocked': false,
    };
  }

  Future<void> refreshSelfPosition() async {
    final here = await readDeviceLocation();
    if (here == null) return;
    final moved = haversineMeters(
      LatLng(selfLat, selfLng),
      LatLng(here.lat, here.lng),
    );
    selfLat = here.lat;
    selfLng = here.lng;
    notifyListeners();
    if (moved > 40) unawaited(ensureDayRoute());
  }

  Future<void> callTask(BuildContext context, DeliveryTask task) async {
    var number = task.phone;
    if (liveApi) {
      try {
        final session = await api?.startMaskedCall(task.id);
        if (session != null && session.dialNumber.isNotEmpty) {
          number = session.dialNumber;
        }
      } catch (_) {}
    }
    if (!context.mounted) return;
    await dialNumber(context, number);
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
              if (startPhotoMediaId != null)
                'startPhotoMediaId': startPhotoMediaId,
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
  /// Failures are silent by design — [ensureDayRoute] already has a local
  /// order + road line; this only overlays the server plan when it exists.
  Future<void> loadRoute() async {
    final client = api;
    if (client == null || routeLoading) return;
    routeLoading = true;
    notifyListeners();
    try {
      final next = await client.fetchRoute(lat: selfLat, lng: selfLng);
      if (next != null) {
        routePlan = next;
      } else if (client.lastWasLive) {
        // Live 204/null'da demo geometriyi bırakma — harita t1'den başlar.
        routePlan = null;
      }
      liveApi = client.lastWasLive;
      DgLog.i(
        LogLayer.route,
        next == null
            ? 'plan empty live=$liveApi'
            : 'plan ${next.stops.length} stops',
      );
    } catch (e) {
      DgLog.w(LogLayer.route, 'loadRoute $e');
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
      if (liveApi) {
        _dropDemoInbox();
        unawaited(_rememberWatermark(client.lastSyncedAt));
        final inbox = await client.fetchNotifications();
        ingestServerNotifications(inbox);
        unawaited(registerPushToken());
      }
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
      applyTaskDelta(changed: delta.tasks, removedIds: delta.removedTaskIds);
      if (delta.custody != null) custodyItems = delta.custody!;
      ingestServerNotifications(delta.notifications);
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
          kind: NotifKind.stopPulled,
          title: 'Durak çekildi',
          body: '${was.ref} · başka kuryeye verildi.',
          icon: LucideIcons.truck,
          tint: Dg.amberBg,
          ink: Dg.amber,
          taskId: was.id,
        );
      }
    }
    for (final incoming in changed) {
      final was = previous[incoming.id];
      if (was == null && incoming.isOpen) {
        _prependNotification(
          kind: NotifKind.stopAssigned,
          title: 'Yeni durak atandı',
          body: '${incoming.ref} · ${incoming.recipient}',
          icon: LucideIcons.truck,
          tint: Dg.greenBg,
          ink: Dg.green,
          taskId: incoming.id,
        );
      } else if (incoming.status == TaskStatus.cancelled &&
          was != null &&
          was.status != TaskStatus.cancelled) {
        _prependNotification(
          kind: NotifKind.stopCancelled,
          title: 'Durak iptal',
          body:
              '${incoming.ref.isEmpty ? was.ref : incoming.ref} · ${incoming.recipient.isEmpty ? was.recipient : incoming.recipient}',
          icon: LucideIcons.circleX,
          tint: Dg.redBg,
          ink: Dg.red,
          taskId: incoming.id,
        );
      }
    }
  }

  void _dropDemoInbox() {
    notifications.removeWhere((n) => n.id.startsWith('demo-'));
  }

  void ingestServerNotifications(List<InboxItemDto> rows) {
    if (rows.isEmpty) return;
    _dropDemoInbox();
    for (final row in rows) {
      final n = row.item;
      if (n.id.isEmpty) continue;
      final existing = notifications.indexWhere((e) => e.id == n.id);
      if (existing >= 0) {
        notifications[existing] = n;
      } else {
        final dup = n.taskId == null
            ? -1
            : notifications.indexWhere(
                (e) => e.kind == n.kind && e.taskId == n.taskId,
              );
        if (dup >= 0) {
          notifications[dup] = n;
        } else {
          notifications.insert(0, n);
        }
      }
      if (row.read) {
        _readNotificationIds.add(n.id);
      }
    }
    while (notifications.length > _inboxCap) {
      notifications.removeLast();
    }
    _persistNotifState();
    _syncNotifBadge();
  }

  Future<void> registerPushToken([String? token]) async {
    if (!notifyEnabled || notifyOsBlocked || !liveApi) return;
    final client = api;
    final store = vault;
    if (client == null || store == null) return;
    final value = token ?? FieldPush.token;
    if (value == null || value.isEmpty) return;
    try {
      await client.registerPushToken(
        installationId: await store.installationId(),
        token: value,
      );
    } catch (_) {}
  }

  static const _pullPushKinds = {
    'SYNC_HINT',
    'TASK_ASSIGNED',
    'TASK_UPDATED',
    'TASK_CANCELLED',
    'TASK_PULLED',
    'ROUTE_RECALCULATED',
    'SLA_AT_RISK',
    'CUSTODY_TAKEN',
  };

  void ingestPushData(Map<String, String> data) {
    final nextToken = data['token'];
    if (nextToken != null && data.length == 1) {
      unawaited(registerPushToken(nextToken));
      return;
    }
    final kind = data['kind'];
    if (kind != null && _pullPushKinds.contains(kind)) {
      unawaited(pullTasks());
    }
    if (kind == 'SYNC_HINT') return;
    final id = data['id'];
    if (id == null || id.isEmpty) return;
    ingestServerNotifications([
      InboxItemDto(
        item: appNotificationFromInbox({
          ...data,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'subjectId': data['taskId'] ?? data['subjectId'],
        }),
        read: false,
      ),
    ]);
    notifyListeners();
  }

  Future<void> _rememberWatermark(String? value) async {
    if (value == null || value.isEmpty) return;
    taskWatermark = value;
    await vault?.saveTaskWatermark(value);
  }

  void _prependNotification({
    required NotifKind kind,
    required String title,
    required String body,
    required IconData icon,
    required Color tint,
    required Color ink,
    String? taskId,
  }) {
    if (taskId != null) {
      final dup = notifications.any(
        (n) =>
            n.kind == kind &&
            n.taskId == taskId &&
            !_dismissedNotificationIds.contains(n.id) &&
            !_readNotificationIds.contains(n.id),
      );
      if (dup) return;
    }
    _notifSeq += 1;
    final item = AppNotification(
      id: 'n-$_notifSeq',
      kind: kind,
      title: title,
      body: body,
      createdAt: DateTime.now(),
      icon: icon,
      tint: tint,
      ink: ink,
      taskId: taskId,
    );
    notifications.insert(0, item);
    while (notifications.length > _inboxCap) {
      final dropped = notifications.removeLast();
      _readNotificationIds.remove(dropped.id);
      _dismissedNotificationIds.remove(dropped.id);
      unawaited(FieldAlerts.dismissInbox(dropped.id));
    }
    if (notifyEnabled && !notifyOsBlocked) {
      unawaited(
        FieldAlerts.announce(
          item,
          title: l10n.notifTitle(title),
          unread: unreadNotifCount,
        ),
      );
      _syncNotifBadge();
    }
  }

  static const _inboxCap = 40;

  Future<void> refreshField() async {
    await Future.wait([
      refreshSelfPosition(),
      pullTasks(),
      loadTickets(),
      loadRoute(),
    ]);
    await ensureDayRoute();
  }

  Future<void> loadTickets() async {
    final client = api;
    if (client == null) return;
    try {
      final remote = await client.fetchSupportTickets();
      liveApi = client.lastWasLive;
      replaceTickets(remote);
    } catch (_) {
      // Destek listesi 404/ağ hatası görev API'sini demo'ya düşürmez.
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
        payload: {'rowVersion': step.rowVersion, 'to': step.to},
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
    unawaited(ensureDayRoute());
  }

  Map<String, Object?> _finalizePayload(
    DeliveryTask t, {
    required String outcomeCode,
    String? note,
    Map<String, Object?>? proof,
  }) {
    return {
      'rowVersion': t.rowVersion,
      'workflowVersion': t.workflowVersion,
      'outcomeCode': outcomeCode,
      'answers': [
        for (final a in stepAnswers[t.id] ?? const <Map<String, Object?>>[])
          a,
      ],
      if (note != null && note.isNotEmpty) 'note': note,
      if (proof != null) 'proof': proof,
      'location': _shiftFix(),
    };
  }

  void deliverTask(
    String id, {
    String? receivedBy,
    Map<String, Object?>? proof,
  }) {
    final t = taskById(id);
    t.status = TaskStatus.delivered;
    t.receivedBy = receivedBy;
    t.signed = proof?['type'] == 'RECIPIENT_SIGNATURE';
    final event = outbox.enqueue(
      operation: SyncOperation.taskFinalize,
      subjectId: id,
      payload: _finalizePayload(
        t,
        outcomeCode: 'DELIVERED',
        note: receivedBy,
        proof: proof,
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
    unawaited(ensureDayRoute());
  }

  void returnTask(String id, {required String reason, String? note, String? photoMediaId}) {
    final t = taskById(id);
    t.status = TaskStatus.failed;
    final code = failureOutcomeCode(reason);
    final detail = note == null || note.isEmpty ? reason : note;
    if (code == 'RECIPIENT_ABSENT') {
      submitStep(
        taskId: id,
        stepKey: 'yok_notu',
        value: {'aciklama': detail, 'kapi_notu_birakildi': false},
      );
      if (photoMediaId != null) {
        submitStep(taskId: id, stepKey: 'yok_kanit_fotografi', mediaIds: [photoMediaId]);
      }
    } else if (code == 'ADDRESS_NOT_FOUND') {
      if (photoMediaId != null) {
        submitStep(taskId: id, stepKey: 'adres_kanit_fotografi', mediaIds: [photoMediaId]);
      }
    } else if (code == 'REFUSED') {
      submitStep(
        taskId: id,
        stepKey: 'ret_nedeni',
        value: {'neden': 'other', 'aciklama': detail},
      );
    }
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
    unawaited(ensureDayRoute());
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
    unawaited(ensureDayRoute());
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
    if (client == null) {
      outbox.drain();
      notifyListeners();
      return;
    }
    try {
      final install = await vault?.installationId() ?? Vault.newUuid();
      final results = await client.syncBatch(
        installationId: install,
        events: pending,
      );
      liveApi = client.lastWasLive;
      final wasPending = {for (final e in pending) e.clientEventId: e};
      await outbox.applyResults([
        for (final r in results) (id: r.clientEventId, status: r.status),
      ]);
      if (liveApi) {
        await Future.wait([pullTasks(), loadTickets()]);
      }
      for (final r in results) {
        if (r.status != 'rejected') continue;
        final event = wasPending[r.clientEventId];
        if (event == null) continue;
        _prependNotification(
          kind: NotifKind.syncFail,
          title: 'Gönderim başarısız',
          body: event.subjectId == null
              ? 'Bir kayıt senkron edilemedi, kuyrukta bekliyor.'
              : '${_taskName(event.subjectId)} senkron edilemedi, kuyrukta bekliyor.',
          icon: LucideIcons.circleAlert,
          tint: Dg.redBg,
          ink: Dg.red,
          taskId: event.subjectId,
        );
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

  void submitStep({
    required String taskId,
    required String stepKey,
    String status = 'completed',
    Map<String, Object?>? value,
    List<String> mediaIds = const [],
    String? skipReasonCode,
  }) {
    final t = taskById(taskId);
    final answer = <String, Object?>{
      'stepKey': stepKey,
      'workflowVersion': t.workflowVersion,
      'status': status,
      if (value != null) 'value': value,
      'mediaIds': mediaIds,
      if (skipReasonCode != null) 'skipReasonCode': skipReasonCode,
      'location': _shiftFix(),
    };
    final list = stepAnswers.putIfAbsent(taskId, () => []);
    list.removeWhere((a) => a['stepKey'] == stepKey);
    list.add(answer);
    final event = outbox.enqueue(
      operation: SyncOperation.stepSubmit,
      subjectId: taskId,
      payload: {
        ...answer,
        'rowVersion': t.rowVersion,
      },
    );
    if (online) {
      if (api == null) {
        event.status = 'applied';
      } else {
        unawaited(_flushOutbox());
      }
    }
  }

  Future<bool> sendDeliveryOtp(String taskId) async {
    if (!liveApi) {
      deliveryChallengeId = 'demo-challenge';
      return true;
    }
    try {
      final res = await api!.sendTaskOtp(
        taskId: taskId,
        stepKey: 'otp_dogrula',
      );
      liveApi = api?.lastWasLive ?? liveApi;
      deliveryChallengeId = res['challengeId'] as String?;
      return deliveryChallengeId != null && deliveryChallengeId!.isNotEmpty;
    } catch (_) {
      if (!kReleaseMode) {
        deliveryChallengeId = 'demo-challenge';
        return true;
      }
      return false;
    }
  }

  Future<bool> verifyDeliveryOtp(String taskId, String code) async {
    if ((!liveApi || !kReleaseMode) && code == '482913') {
      deliveryOtpToken = 'demo-otp-token';
      return true;
    }
    final id = deliveryChallengeId;
    if (api == null || id == null) return false;
    try {
      final res = await api!.verifyTaskOtp(
        taskId: taskId,
        challengeId: id,
        code: code,
      );
      liveApi = api?.lastWasLive ?? liveApi;
      deliveryOtpToken = res['verificationToken'] as String?;
      return res['verified'] == true;
    } catch (_) {
      return false;
    }
  }
}

List<DeliveryTask> _tasksInPlanOrder(
  List<DeliveryTask> tasks,
  RoutePlanDto? plan,
) {
  if (plan == null || plan.stops.isEmpty) return tasks;
  final byId = {for (final t in tasks) t.id: t};
  final ordered = <DeliveryTask>[
    for (final stop in plan.stops) ?byId[stop.taskId],
  ];
  final seen = ordered.map((t) => t.id).toSet();
  ordered.addAll(tasks.where((t) => !seen.contains(t.id)));
  return ordered;
}

List<DeliveryTask> _buildDemoTasks() => [
  DeliveryTask(
    id: 't1',
    ref: 'DGO-8841',
    recipient: 'Ahmet Yılmaz',
    phone: '+905321110026',
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
    phone: '+905321110027',
    address: 'İstiklal Cd. No:8 D:3, Güney / Denizli',
    window: '15:00–15:30',
    kind: TaskKind.document,
    status: TaskStatus.assigned,
    sequence: 2,
    etaMinutes: 11,
    lat: 38.1481,
    lng: 29.0558,
    groupKey: 'istiklal-8',
  ),
  DeliveryTask(
    id: 't5',
    ref: 'DGO-8845',
    recipient: 'Zeynep Arslan',
    phone: '+905321110028',
    address: 'İstiklal Cd. No:8 D:7, Güney / Denizli',
    window: '15:00–15:30',
    kind: TaskKind.delivery,
    status: TaskStatus.assigned,
    sequence: 2,
    etaMinutes: 11,
    lat: 38.1481,
    lng: 29.0558,
    groupKey: 'istiklal-8',
  ),
  DeliveryTask(
    id: 't3',
    ref: 'DGO-8843',
    recipient: 'Mehmet Aydın',
    phone: '+905321110029',
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
    phone: '+905321110030',
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

List<AppNotification> _buildDemoNotifications() {
  final now = DateTime.now();
  return [
    AppNotification(
      id: 'demo-stop',
      kind: NotifKind.stopAssigned,
      title: 'Yeni durak atandı',
      body: 'DGO-8844 · Cumhuriyet Mah. 1. Sk. No:3',
      createdAt: now.subtract(const Duration(hours: 1, minutes: 18)),
      icon: LucideIcons.truck,
      tint: Dg.greenBg,
      ink: Dg.green,
      taskId: 't4',
    ),
    AppNotification(
      id: 'demo-custody',
      kind: NotifKind.custody,
      title: 'Zimmet onaylandı',
      body: 'Şube zimmetinden 6 gönderi üstüne alındı.',
      createdAt: now.subtract(const Duration(hours: 2, minutes: 1)),
      icon: LucideIcons.package,
      tint: Dg.violetBg,
      ink: Dg.violet,
    ),
    AppNotification(
      id: 'demo-sync',
      kind: NotifKind.syncFail,
      title: 'Gönderim başarısız',
      body: 'DGO-8839 senkron edilemedi, kuyrukta bekliyor.',
      createdAt: now.subtract(const Duration(hours: 3, minutes: 39)),
      icon: LucideIcons.circleAlert,
      tint: Dg.redBg,
      ink: Dg.red,
    ),
    AppNotification(
      id: 'demo-bonus',
      kind: NotifKind.bonus,
      title: 'Prim güncellendi',
      body: 'Bu hafta 40 teslim primine 6 teslim kaldı.',
      createdAt: now.subtract(const Duration(hours: 6, minutes: 54)),
      icon: LucideIcons.wallet,
      tint: Dg.amberBg,
      ink: Dg.amber,
    ),
    AppNotification(
      id: 'demo-shift',
      kind: NotifKind.shift,
      title: 'Vardiya hatırlatması',
      body: 'Yarın 09:00 vardiyası atanmıştır.',
      createdAt: now.subtract(const Duration(days: 1, hours: 3)),
      icon: LucideIcons.clock,
      tint: Dg.blueBg,
      ink: Dg.blue,
    ),
  ];
}
