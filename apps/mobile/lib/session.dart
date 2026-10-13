import 'dart:async';
import 'dart:io';

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
import 'api/agency_client.dart';
import 'api/agency_models.dart';
import 'api/branch_models.dart';
import 'branch_workspace.dart';
import 'capture_check.dart';
import 'api/panel_client.dart';
import 'api/panel_models.dart';
import 'data/outbox.dart';
import 'data/vault.dart';
import 'geo.dart';
import 'l10n.dart';
import 'launchers.dart';
import 'live_location.dart';
import 'locate.dart';
import 'log.dart';
import 'media_upload.dart';
import 'models.dart';
import 'road.dart';
import 'scan.dart';
import 'secure.dart';
import 'signature.dart';
import 'theme.dart';
import 'visit_requirements.dart';

final sessionProvider = ChangeNotifierProvider<SessionController>((ref) {
  return SessionController();
});

enum AppPhase { onboard, splash, activation, permissions, shift, main, subeMain }

const _debugLoginId = String.fromEnvironment('DEBUG_LOGIN_ID');
const _debugLoginPw = String.fromEnvironment('DEBUG_LOGIN_PW');

/// `sube` verilirse geliştirme girişi şube (acente) hesabıyla yapılır.
const _debugLoginRole = String.fromEnvironment('DEBUG_LOGIN_ROLE');

class SessionController extends ChangeNotifier {
  SessionController({
    OutboxStore? outbox,
    this.api,
    this.panel,
    this.agency,
    this.vault,
    this.waitForConfig = false,
    AppPhase? initialPhase,
    Future<PushPermit> Function()? requestPush,
    Future<PushPermit> Function()? readPush,
    Stream<LiveFix> Function()? liveFixes,
  }) : outbox = outbox ?? OutboxStore(),
       liveFixes = liveFixes ?? liveFixStream,
       phase = initialPhase ?? AppPhase.onboard,
       requestPush = requestPush ?? requestPushPermit,
       readPush = readPush ?? readPushPermit {
    configReady = !waitForConfig;
    if (!kReleaseMode && !waitForConfig) {
      tasks.addAll(_buildDemoTasks());
      notifications.addAll(_buildDemoNotifications());
      custodyItems = _buildDemoCustodyItems();
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
  final AgencyPortalApi? agency;
  final Vault? vault;
  final bool waitForConfig;
  final Future<PushPermit> Function() requestPush;
  final Future<PushPermit> Function() readPush;
  final Stream<LiveFix> Function() liveFixes;

  bool get _usesPanelTasks => panelLoggedIn && panel != null;

  /// Panel cookie-session opened via [loginWithPanel]. When true, görev
  /// listesi ve teslim yazmaları [PanelApi] üzerindendir (Fastify değil).
  bool panelLoggedIn = false;
  String? lastPanelError;
  String? lastActivationError;
  DateTime? otpResendAt;
  bool activationBusy = false;

  static const panelDemoIdentifier = 'kurye@dijigoo.test';
  static const panelDemoPassword = 'demo';
  static const panelSessionExpired = 'PANEL_SESSION_EXPIRED';

  /// Şube/Acente rolü — dijigoo-ops'un acente portalı üzerinden ayrı bir
  /// cookie-session (bkz. docs/08-sube-acente-entegrasyonu.md). Kurye
  /// oturumundan tamamen bağımsız: aynı cihazda ikisi bir arada tutulabilir.
  AgencyPortalUserDto? agencyUser;

  /// Şube çalışma alanı: özet, gönderi/zimmet, sayım, merkeze sevk ve ortak
  /// barkod yönlendirmesi. Okutmaları kurye ile aynı [outbox]'a yazar.
  late final BranchWorkspace branch = BranchWorkspace(
    outbox: outbox,
    api: agency,
    vault: vault,
    onChanged: notifyListeners,
    onSessionExpired: _agencySessionExpired,
  );
  String? lastAgencyError;

  /// Son giriş hatasının ayrıntısı (kurye ve şube girişi ortak).
  int? loginRemainingAttempts;
  DateTime? loginLockedUntil;
  bool agencyLoginBusy = false;
  List<AgencyDto> agencySelectionOptions = const [];

  static const agencyDemoEmail = 'sube@dijigoo.test';
  static const agencyDemoPassword = 'demo';

  AppConfig config = AppConfig.demo;
  bool configReady = true;
  bool liveApi = false;
  RoutePlanDto? routePlan = RoutePlanDto.demo();
  static const _depotLat = 38.1476;
  static const _depotLng = 29.0702;
  double selfLat = _depotLat;
  double selfLng = _depotLng;

  /// Cihazdan en az bir kez fix alındı. Yoksa kart enroute + “Vardım”.
  bool selfLocated = false;
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
    for (final t in tasks.where((t) => t.isOpen && t.hasCoordinates))
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

  Iterable<LatLng> get _openStopPoints => [
    for (final t in tasks.where((t) => t.isOpen && t.hasCoordinates))
      LatLng(t.lat, t.lng),
  ];

  bool _gpsFitsStops(double lat, double lng) {
    return originNearStops(
      origin: LatLng(lat, lng),
      stops: _openStopPoints,
    );
  }

  /// Simülatör / yanlış kıta GPS'ini depo varsayılanına çeker.
  bool _resetImplausibleGps() {
    if (_gpsFitsStops(selfLat, selfLng)) return false;
    DgLog.i(
      LogLayer.route,
      'gps discarded $selfLat,$selfLng far from stops',
    );
    selfLat = _depotLat;
    selfLng = _depotLng;
    selfLocated = false;
    _dayRouteKey = null;
    dayRoute = null;
    return true;
  }

  /// Rota başlangıcı: ölçülmüş konum; ölçüm yoksa varsayılan depo. Depo
  /// duraklardan uzaksa (başka şehir) ilk durak alınır — yoksa Ankara'daki
  /// kuryeye Denizli'den 380 km'lik ilk bacak ve ülke çapında harita çıkar.
  LatLng get _routeOrigin {
    if (selfLocated && _gpsFitsStops(selfLat, selfLng)) {
      return LatLng(selfLat, selfLng);
    }
    const depot = LatLng(_depotLat, _depotLng);
    final stops = _openStopPoints;
    if (stops.isEmpty ||
        originNearStops(origin: depot, stops: stops, maxMeters: 60000)) {
      return depot;
    }
    return stops.first;
  }

  Future<void> ensureDayRoute({String? pinFirstId}) async {
    final origin = _routeOrigin;
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
  /// False when SQLCipher açılamaz; üretimde saha verisi yazılmaz.
  bool storageOk = true;
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
  bool tipsSeen = true;
  bool subeOnboardSeen = true;
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
    if (!storageOk) return;
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
    if (_usesPanelTasks && id.startsWith(_serverNotifPrefix)) {
      unawaited(
        panel
            ?.markNotificationRead(id.substring(_serverNotifPrefix.length))
            .catchError((_) {}),
      );
    }
    if (liveApi && !_usesPanelTasks) {
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
    if (_usesPanelTasks) {
      unawaited(panel?.markAllNotificationsRead().catchError((_) {}));
    }
    if (liveApi && !_usesPanelTasks) {
      unawaited(api?.markNotificationsRead(all: true));
    }
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

  /// Kuryenin şu an elinde ne var. Panel oturumunda `GET courier-custody`,
  /// aksi halde apps/api `GET /v1/custody`.
  Future<void> loadCustody() async {
    if (custodyLoading) return;
    if (_usesPanelTasks) {
      final client = panel;
      if (client == null) return;
      custodyLoading = true;
      notifyListeners();
      try {
        custodyItems = await client.fetchCustody();
      } on PanelApiException catch (e) {
        if (e.statusCode == 401) {
          expirePanelSession();
          return;
        }
      } catch (_) {
      } finally {
        custodyLoading = false;
        notifyListeners();
      }
      return;
    }
    final client = api;
    if (client == null) return;
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

  CustodyItemDto? custodyItemForTask(String taskId) {
    for (final item in custodyItems) {
      if (item.taskId == taskId) return item;
    }
    return null;
  }

  /// İade / Geri Teslim ekranının "Geri Teslim" sekmesi — teslim edilemeyen
  /// bu durağın zimmetteki kalemini doğrudan şubeye bırakır. Barkod okutmaya
  /// gerek yok: kalem zaten `taskId` ile eşleşmiş durumda, kurye sadece
  /// onaylıyor.
  List<({String code, String name})> deliveryFailReasons = const [];

  Future<void> loadDeliveryReasons() async {
    final client = panel;
    if (client == null || !_usesPanelTasks) return;
    try {
      final rows = await client.fetchDeliveryReasons();
      if (rows.isNotEmpty) deliveryFailReasons = rows;
    } catch (_) {}
    notifyListeners();
  }

  Future<bool> returnTaskToBranch(String taskId, {String branchName = 'Şube'}) async {
    if (custodyItems.isEmpty && !custodyLoading) await loadCustody();
    final item = custodyItemForTask(taskId);
    if (_usesPanelTasks) {
      final client = panel;
      if (client == null) return false;
      final shipmentId = item?.taskId ?? taskId;
      custodyHandoverPending = true;
      notifyListeners();
      try {
        await client.returnCustodyUnit(
          shipmentId,
          warehouseId: item?.warehouseId ?? '',
        );
        if (item != null) {
          custodyItems = custodyItems.where((c) => c.id != item.id).toList();
        }
        return true;
      } on PanelApiException catch (e) {
        lastPanelError = e.code;
        return false;
      } finally {
        custodyHandoverPending = false;
        notifyListeners();
      }
    }
    if (item == null) return false;
    final client = api;
    if (client == null) {
      custodyItems = custodyItems.where((c) => c.id != item.id).toList();
      notifyListeners();
      return true;
    }
    custodyHandoverPending = true;
    notifyListeners();
    try {
      await client.handoverToBranch(itemIds: [item.id], branchName: branchName);
      custodyItems = custodyItems.where((c) => c.id != item.id).toList();
      return true;
    } catch (_) {
      return false;
    } finally {
      custodyHandoverPending = false;
      notifyListeners();
    }
  }

  /// Şube: eldeki kalemleri acenteye bırakır. Kurye: barkodla tenant
  /// kalemini bulup `takeover` ile üzerine alır.
  Future<bool> completeZimmet() async {
    if (_usesPanelTasks) return _completePanelZimmet();
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

  Future<bool> _completePanelZimmet() async {
    if (zimmetMode == 'kurye') {
      return _acceptPanelCustodyScans();
    }
    if (zimmetMode != 'sube') {
      zimmetScans.clear();
      notifyListeners();
      return true;
    }

    final items = <CustodyItemDto>[
      for (final scan in zimmetScans)
        if (_custodyItemByBarcode(scan.code) case final item?) item,
    ];
    if (items.isEmpty) {
      zimmetScans.clear();
      notifyListeners();
      return true;
    }

    custodyHandoverPending = true;
    notifyListeners();
    try {
      for (final item in items) {
        if (_hasPendingPanel(item.id, SyncOperation.panelCustodyReturn)) {
          continue;
        }
        outbox.enqueue(
          operation: SyncOperation.panelCustodyReturn,
          subjectId: item.id,
          payload: {
            'warehouseId': item.warehouseId ?? '',
            'shipmentId': item.taskId ?? item.id,
          },
        );
      }

      final returned = {for (final item in items) item.id};
      custodyItems = [
        for (final item in custodyItems)
          if (!returned.contains(item.id)) item,
      ];
      zimmetScans.clear();
      _prependNotification(
        kind: NotifKind.custody,
        title: 'Zimmet onaylandı',
        body: 'Şube zimmetinden ${items.length} gönderi üstüne alındı.',
        icon: LucideIcons.package,
        tint: Dg.violetBg,
        ink: Dg.violet,
      );
      await _pushPanelQueue();
      return true;
    } finally {
      custodyHandoverPending = false;
      notifyListeners();
    }
  }

  Future<bool> _acceptPanelCustodyScans() async {
    final client = panel;
    if (client == null) return false;
    if (zimmetScans.isEmpty) return true;
    custodyHandoverPending = true;
    notifyListeners();
    try {
      for (final scan in List.of(zimmetScans)) {
        await client.acceptCustodyScan(scan.code);
      }
      zimmetScans.clear();
      await Future.wait([loadPanelTasks(), loadCustody()]);
      _prependNotification(
        kind: NotifKind.custody,
        title: 'Zimmet alındı',
        body: 'Depodan kabul edilen gönderiler görevlere düştü.',
        icon: LucideIcons.package,
        tint: Dg.violetBg,
        ink: Dg.violet,
      );
      return true;
    } on PanelApiException catch (e) {
      lastPanelError = e.code;
      notifyListeners();
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
  // Yeni kurulumda açık tema; kayıtlı tema ve dil tercihleri korunur.
  /// Varsayılan koyu tema; kurye profilden açık temaya geçebilir ve seçimi
  /// saklanır.
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
    tipsSeen = await vault?.tipsSeen ?? false;
    subeOnboardSeen = await vault?.subeOnboardSeen ?? false;
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
  final bonuses = [
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

  // Toplantı kararı: kurye ekranında eski kimlik/pasaport/yabancı kimlik
  // seçenekleri olmayacak — sadece yeni TC kimlik kabul ediliyor.
  final kycDocs = const [
    KycDocOption(label: 'Yeni kimlik ön yüz', icon: LucideIcons.idCard),
    KycDocOption(
      label: 'Yeni kimlik arka yüz',
      icon: LucideIcons.rectangleEllipsis,
    ),
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

  final trainingModules = <TrainingModuleDto>[];
  bool trainingBusy = false;

  /// Bekleyen zorunlu eğitim sayısı (backend). Hiçbir işlemi engellemez;
  /// yalnız uyarı gösterilir.
  int pendingMandatoryTrainings = 0;

  /// `courier-dashboard` sayaçları; yüklenmediyse boş.
  Map<String, int> courierCounts = const {};

  static const _serverNotifPrefix = 'srv-';

  /// Backend bildirim kutusu (duyurular dahil). Cihazda üretilen yerel
  /// uyarılar listede kalır; örnek bildirimler kaldırılır.
  Future<void> loadCourierNotifications() async {
    final client = panel;
    if (!_usesPanelTasks || client == null) return;
    try {
      final remote = await client.fetchNotifications();
      notifications.removeWhere(
        (n) => n.id.startsWith(_serverNotifPrefix) || n.id.startsWith('demo-'),
      );
      for (final item in remote.reversed) {
        final rejected = item.category == 'EVIDENCE_REJECTED';
        final urgent = rejected || item.severity != 'INFO';
        final id = '$_serverNotifPrefix${item.id}';
        notifications.insert(
          0,
          AppNotification(
            id: id,
            kind: rejected
                ? NotifKind.photoRejected
                : urgent
                ? NotifKind.slaRisk
                : NotifKind.shift,
            title: item.title.isNotEmpty
                ? item.title
                : _notifTitle(item.category),
            body: item.body,
            announcementId: item.announcementId,
            needsAck: item.needsAck,
            createdAt: item.createdAt ?? DateTime.now(),
            icon: rejected
                ? LucideIcons.cameraOff
                : urgent
                ? LucideIcons.circleAlert
                : LucideIcons.bell,
            tint: urgent ? Dg.hiBg : Dg.greenBg,
            ink: urgent ? Dg.hi : Dg.green,
          ),
        );
        if (item.read) _readNotificationIds.add(id);
      }
      _syncNotifBadge();
      notifyListeners();
    } catch (_) {
      // Kutu gelmezse mevcut liste kalır.
    }
  }

  String _notifTitle(String category) => switch (category) {
    'ANNOUNCEMENT' => 'Duyuru',
    'EVIDENCE_REJECTED' => 'Fotoğrafın kabul edilmedi',
    'HANDOVER' || 'CUSTODY' => 'Zimmet',
    'SHIFT' || 'SHIFT_AUTO_CLOSED' => 'Vardiya',
    'LEAVE_REVIEWED' || 'LEAVE' => 'İzin',
    'TRAINING' => 'Eğitim',
    'SLA' => 'Gecikme uyarısı',
    _ => 'Bildirim',
  };

  /// Cihazı backend'e kaydeder: push token ve bekleyen kayıt sayısı.
  Future<void> registerCourierDevice() async {
    final client = panel;
    if (!_usesPanelTasks || client == null) return;
    try {
      final deviceId = await vault?.installationId();
      if (deviceId == null) return;
      await client.registerDevice(
        deviceId: deviceId,
        platform: defaultTargetPlatform == TargetPlatform.iOS
            ? 'IOS'
            : 'ANDROID',
        appVersion: kAppVersion,
        pushToken: FieldPush.token,
        pendingOperationCount: outbox.pendingCount,
      );
    } catch (_) {
      // Kayıt bir sonraki girişte / yenilemede tekrar denenir.
    }
  }

  /// Ana sayfa sayaçları ve vardiya/eğitim durumu backend'den.
  Future<void> loadCourierDashboard() async {
    final client = panel;
    if (!_usesPanelTasks || client == null) return;
    unawaited(loadCourierNotifications());
    unawaited(loadPhotoMistakeCount());
    unawaited(registerCourierDevice());
    try {
      courierCounts = await client.fetchDashboardCounts();
      final shift = await client.fetchCurrentShift();
      pendingMandatoryTrainings = shift.pendingMandatoryTrainings;
      notifyListeners();
    } on PanelApiException catch (e) {
      if (e.statusCode == 401) expirePanelSession();
    } catch (_) {
      // Sayaçlar gelmezse ekran yerel sayılarla kalır.
    }
  }

  Future<void> loadTrainingModules() async {
    if (_usesPanelTasks) {
      final client = panel;
      if (client == null) return;
      trainingBusy = true;
      notifyListeners();
      try {
        final remote = await client.fetchTrainings();
        trainingModules
          ..clear()
          ..addAll(remote);
        pendingMandatoryTrainings = remote
            .where((m) => m.mandatory && !m.completed)
            .length;
      } catch (_) {
        // Ağ hatası: mevcut liste korunur; örnek eğitim gösterilmez.
      }
      trainingBusy = false;
      notifyListeners();
      return;
    }
    final client = api;
    if (client == null) {
      if (trainingModules.isEmpty) {
        trainingModules.addAll(_demoTrainingModulesSeed());
        notifyListeners();
      }
      return;
    }
    trainingBusy = true;
    notifyListeners();
    try {
      final remote = await client.fetchTrainingModules();
      trainingModules
        ..clear()
        ..addAll(remote);
    } catch (_) {
      // Ağ hatası: mevcut liste (varsa demo tohumu) korunur.
      if (trainingModules.isEmpty) {
        trainingModules.addAll(_demoTrainingModulesSeed());
      }
    }
    trainingBusy = false;
    notifyListeners();
  }

  /// Eğitim metni listede gelmez; detay açılırken backend'den alınır.
  Future<void> loadTrainingBody(String moduleId) async {
    final client = panel;
    if (!_usesPanelTasks || client == null) return;
    final i = trainingModules.indexWhere((m) => m.id == moduleId);
    if (i == -1 || trainingModules[i].body.isNotEmpty) return;
    try {
      final body = await client.fetchTrainingBody(moduleId);
      final j = trainingModules.indexWhere((m) => m.id == moduleId);
      if (j == -1 || body.isEmpty) return;
      final m = trainingModules[j];
      trainingModules[j] = TrainingModuleDto(
        id: m.id,
        title: m.title,
        summary: m.summary,
        body: body,
        sortOrder: m.sortOrder,
        completed: m.completed,
        completedAt: m.completedAt,
        mandatory: m.mandatory,
        overdue: m.overdue,
      );
      notifyListeners();
    } catch (_) {
      // Metin gelmezse başlık ve özet görünür kalır.
    }
  }

  Future<void> completeTrainingModule(String moduleId) async {
    final i = trainingModules.indexWhere((m) => m.id == moduleId);
    if (i == -1 || trainingModules[i].completed) return;
    final now = DateTime.now().toUtc().toIso8601String();
    trainingModules[i] = TrainingModuleDto(
      id: trainingModules[i].id,
      title: trainingModules[i].title,
      summary: trainingModules[i].summary,
      body: trainingModules[i].body,
      sortOrder: trainingModules[i].sortOrder,
      completed: true,
      completedAt: now,
    );
    notifyListeners();
    if (_usesPanelTasks) {
      try {
        await panel?.completeTraining(moduleId);
      } catch (_) {
        // Sunucu kabul etmediyse (ör. en kısa izleme süresi dolmadı) gerçek
        // durum geri yüklenir; tamamlandı gösterilmez.
      }
      await loadTrainingModules();
      return;
    }
    final client = api;
    if (client == null) return;
    try {
      await client.completeTrainingModule(moduleId);
    } catch (_) {
      // Optimistik güncelleme kalır; bir sonraki loadTrainingModules() gerçek
      // durumu geri getirir.
    }
  }

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

  int get remainingCount => remainingStops.length;

  int get appointmentCount => tasks
      .where((t) => t.isOpen && t.window.isNotEmpty && t.window != '—')
      .length;

  int get slaRiskCount =>
      tasks.where((t) => t.isOpen && (t.slaMinutesLeft ?? 60) < 45).length;

  /// Bugün üzerine atanan toplam durak sayısı — Kazanç ekranında para
  /// biriminin yerini alan "dağıtım adedi" metriği bunu kullanır.
  int get dispatchCount => tasks.length;
  int get returnCount => tasks
      .where(
        (t) =>
            t.status == TaskStatus.failed || t.status == TaskStatus.cancelled,
      )
      .length;

  DeliveryTask taskById(String id) => tasks.firstWhere((t) => t.id == id);

  DeliveryTask? taskOrNull(String id) {
    for (final t in tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  DeliveryTask? _maybeTask(String id) => taskOrNull(id);

  /// Dağıtım listesi / rota rozeti — panel satırlarında sequence 0 gelir.
  int visitNumber(String id) {
    final i = orderedOpenTasks.indexWhere((t) => t.id == id);
    if (i >= 0) return i + 1;
    final t = taskOrNull(id);
    if (t != null && t.sequence > 0) return t.sequence;
    return 0;
  }

  bool get showPanelFieldError =>
      panelLoggedIn &&
      lastPanelError != null &&
      lastPanelError != panelSessionExpired;

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
    await restoreAgencySession();
    await restoreOpenShift();
    final token = await vault?.accessToken;
    final liveAuth =
        token != null && token.isNotEmpty && token != 'demo-access';
    if (!liveAuth &&
        !liveApi &&
        !panelLoggedIn &&
        phase == AppPhase.splash &&
        demoFieldAllowed()) {
      skipToDemo();
      return;
    }
    DgLog.i(
      LogLayer.boot,
      'bootstrap live=$liveApi demo=$demo phase=${phase.name}',
    );
    notifyListeners();
  }

  /// Saklı şube oturumu varsa (8 saatlik bearer) sunucuda doğrular ve
  /// doğrudan şube ana sayfasını açar. Kurye oturumu açıksa ona dokunmaz.
  Future<void> restoreAgencySession() async {
    final client = agency;
    if (client == null || panelLoggedIn || agencyUser != null) return;
    try {
      if (!await client.hasStoredSession) return;
      final user = await client.fetchSession();
      if (user == null) {
        // Süresi dolmuş: saklı anahtarı temizle, giriş ekranı açılır.
        await client.logout().catchError((_) {});
        return;
      }
      agencyUser = user;
      branch.reset();
      phase = AppPhase.subeMain;
      notifyListeners();
      unawaited(branch.refresh());
    } catch (_) {
      // Ağ yoksa oturum silinmez; kullanıcı giriş ekranından devam eder.
    }
  }

  /// Cookie jar’da panel oturumu varsa profili ve görev listesini yükle.
  /// Yalnız geliştirme derlemesi: `--dart-define=DEBUG_LOGIN_ID=…` ve
  /// `DEBUG_LOGIN_PW=…` verilmişse o kurye hesabıyla girip ana sayfayı açar
  /// (simülatörde ekrana dokunmadan gerçek veriyle bakabilmek için).
  /// Vardiya yalnız ekranda açık görünür; sunucuya vardiya isteği gitmez.
  Future<bool> debugAutoLogin() async {
    if (!kDebugMode || _debugLoginId.isEmpty) return false;
    if (_debugLoginRole == 'sube') {
      final ok = await loginAsAgency(
        email: _debugLoginId,
        password: _debugLoginPw,
      );
      if (ok) configReady = true;
      return ok;
    }
    final ok = await loginWithPanel(
      identifier: _debugLoginId,
      password: _debugLoginPw,
    );
    if (!ok) return false;
    configReady = true;
    phase = AppPhase.main;
    shiftOpen = true;
    shiftPhotoTaken = true;
    shiftStartedAt ??= DateTime.now();
    notifyListeners();
    return true;
  }

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
      await loadPanelTasks();
      unawaited(loadCourierDashboard());
      await Future.wait([loadTickets(), loadCustody()]);
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
    demo = false;
    _dropDemoInbox();
    courier = courier.copyWith(
      fullName: profile.fullName.isNotEmpty ? profile.fullName : null,
      code: profile.courierCode.isNotEmpty ? profile.courierCode : null,
    );
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
      unawaited(loadTrainingModules());
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

  void markTipsSeen() {
    tipsSeen = true;
    unawaited(vault?.markTipsSeen());
    notifyListeners();
  }

  void finishSubeOnboard() {
    subeOnboardSeen = true;
    unawaited(vault?.markSubeOnboardSeen());
    notifyListeners();
  }

  /// Durak/bildirim/rota tohumlarını yazar — hem [skipToDemo]'nun anlık
  /// tam-atlama akışında hem de aktivasyon ekranındaki demo OTP'de
  /// (bkz. [verifyLoginOtp]) kullanılıyor. İkincisi kendi izin/vardiya
  /// akışını normal şekilde sürdürdüğü için faz/vardiya burada değişmez.
  void _seedDemoData() {
    if (tasks.isEmpty) {
      tasks.addAll(_buildDemoTasks());
    }
    if (notifications.every((n) => !n.id.startsWith('demo-'))) {
      notifications.insertAll(0, _buildDemoNotifications());
    }
    routePlan = RoutePlanDto.demo();
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
    unawaited(ensureDayRoute(pinFirstId: 't1'));
  }

  /// Yerel demo saha. Release'te yalnız `--dart-define=ALLOW_DEMO=true`.
  /// Sahte OTP / mühendis paneli [kAllowDebugBypass] ile ayrı durur.
  void skipToDemo({bool? allow}) {
    if (!(allow ?? demoFieldAllowed())) return;
    demo = true;
    _seedDemoData();
    phase = AppPhase.main;
    shiftOpen = true;
    shiftPhotoTaken = true;
    shiftStartedAt = DateTime.now().subtract(
      const Duration(hours: 5, minutes: 12),
    );
    unawaited(_persistShift());
    DgLog.i(LogLayer.session, 'skipToDemo · selfie assumed · main');
    notifyListeners();
    if (!kReleaseMode) {
      unawaited(_seedDemoTokenThenIdentity());
    }
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

  /// Son istenen kod JetDiji'den mi geldi (yoksa eski yerel akıştan mı).
  bool _smsLoginViaPanel = false;

  Future<bool> requestActivationCode(String phone) async {
    lastActivationError = null;
    activationBusy = true;
    notifyListeners();
    // Kod JetDiji backend'inden istenir. Geliştirmede sunucuya ulaşılamazsa
    // aşağıdaki yerel akışa düşülür ki demo kodu çalışsın.
    final client = panel;
    _smsLoginViaPanel = false;
    if (client != null) {
      try {
        final sms = await client.requestSmsLogin(phone.trim());
        if (sms.challengeId != null) {
          challengeId = sms.challengeId;
          otpResendAt = DateTime.now().add(
            Duration(seconds: sms.resendAfterSeconds),
          );
          _smsLoginViaPanel = true;
          activationBusy = false;
          notifyListeners();
          return true;
        }
      } on PanelApiException catch (e) {
        if (e.statusCode != null) {
          lastActivationError = e.code;
          activationBusy = false;
          notifyListeners();
          return false;
        }
        if (kReleaseMode) {
          lastActivationError = 'NETWORK';
          activationBusy = false;
          notifyListeners();
          return false;
        }
      }
    }
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

  /// Panel `courier-auth/login` (cookie). Fastify JWT yazmaz; görevler
  /// [loadPanelTasks] ile `GET courier-tasks` üzerinden gelir.
  Future<bool> loginWithPanel({
    required String identifier,
    required String password,
  }) async {
    lastPanelError = null;
    loginRemainingAttempts = null;
    loginLockedUntil = null;
    final id = identifier.trim();
    if (kAllowDebugBypass &&
        id == panelDemoIdentifier &&
        password == panelDemoPassword) {
      panelLoggedIn = true;
      demo = true;
      _seedDemoData();
      notifyListeners();
      return true;
    }
    final client = panel;
    if (client == null) {
      lastPanelError = 'PANEL_UNAVAILABLE';
      notifyListeners();
      return false;
    }
    try {
      final profile = await client.login(identifier: id, password: password);
      await _afterPanelLogin(profile);
      return true;
    } on PanelApiException catch (e) {
      lastPanelError = e.code;
      loginRemainingAttempts = e.remainingAttempts;
      loginLockedUntil = e.lockedUntil;
      notifyListeners();
      return false;
    } catch (_) {
      lastPanelError = 'PANEL_REQUEST_FAILED';
      notifyListeners();
      return false;
    }
  }

  /// Şifreli ve SMS'li girişten sonra ortak yükleme.
  Future<void> _afterPanelLogin(PanelCourierProfileDto profile) async {
    applyPanelProfile(profile);
    await loadPanelTasks();
    unawaited(loadCourierDashboard());
    await Future.wait([
      loadTickets(),
      loadCustody(),
      loadIdentity(),
      loadDeliveryReasons(),
    ]);
  }

  /// Şube/Acente girişi. Kullanıcı birden fazla acenteye bağlıysa
  /// [AgencyApiException]'ın `AGENCY_SELECTION_REQUIRED` kodu ile geri
  /// döner ve [agencySelectionOptions] doldurulur — arayan taraf bir seçim
  /// aldıktan sonra `agencyId` ile tekrar çağırmalı.
  Future<bool> loginAsAgency({
    required String email,
    required String password,
    String? agencyId,
  }) async {
    lastAgencyError = null;
    loginRemainingAttempts = null;
    loginLockedUntil = null;
    agencySelectionOptions = const [];
    agencyLoginBusy = true;
    notifyListeners();
    final trimmed = email.trim();
    if (kAllowDebugBypass &&
        trimmed == agencyDemoEmail &&
        password == agencyDemoPassword) {
      agencyUser = AgencyPortalUserDto(
        id: 'demo-agency-user',
        email: agencyDemoEmail,
        fullName: 'Acente Demo',
        agency: const AgencyDto(id: 'demo-agency', name: 'Güney Acente'),
        capabilities: BranchCapabilities.all,
      );
      branch
        ..reset()
        ..demo = true;
      await branch.refresh();
      agencyLoginBusy = false;
      phase = AppPhase.subeMain;
      notifyListeners();
      return true;
    }
    final client = agency;
    if (client == null) {
      agencyLoginBusy = false;
      lastAgencyError = 'AGENCY_PORTAL_UNAVAILABLE';
      notifyListeners();
      return false;
    }
    try {
      agencyUser = await client.login(
        email: trimmed,
        password: password,
        agencyId: agencyId,
      );
      branch.reset();
      // `login` yanıtı yetkileri taşımaz; düğmeler `session`'daki
      // `capabilities` ile açılır.
      try {
        agencyUser = await client.fetchSession() ?? agencyUser;
      } catch (_) {
        // Yetkiler gelmezse gönderi listesinin kendi `capabilities`'i kullanılır.
      }
      await branch.refresh();
      agencyLoginBusy = false;
      phase = AppPhase.subeMain;
      notifyListeners();
      return true;
    } on AgencyApiException catch (e) {
      agencyLoginBusy = false;
      lastAgencyError = e.code;
      loginRemainingAttempts = e.remainingAttempts;
      loginLockedUntil = e.lockedUntil;
      agencySelectionOptions = e.agencies;
      notifyListeners();
      return false;
    } catch (_) {
      agencyLoginBusy = false;
      lastAgencyError = 'AGENCY_REQUEST_FAILED';
      notifyListeners();
      return false;
    }
  }

  Future<void> logoutAgency() async {
    try {
      await agency?.logout();
    } catch (_) {
      // Çıkış isteği düşse de yerel oturum kapatılır.
    }
    agencyUser = null;
    await branch.clearStored();
    branch.reset();
    lastAgencyError = null;
    phase = AppPhase.activation;
    notifyListeners();
  }

  /// Sunucu 401 döndü: yerel oturumu kapatıp girişe döner.
  void _agencySessionExpired() {
    if (agencyUser == null) return;
    agencyUser = null;
    branch.reset();
    lastAgencyError = 'AGENCY_SESSION_EXPIRED';
    phase = AppPhase.activation;
    notifyListeners();
    unawaited(agency?.logout().catchError((_) {}));
  }

  Future<bool> verifyLoginOtp(String code) async {
    if (!kReleaseMode && code == '123456') {
      demo = true;
      _seedDemoData();
      await _saveDemoTokens();
      notifyListeners();
      return true;
    }
    final install = await vault?.installationId() ?? Vault.newUuid();
    final id = challengeId;
    final client = panel;
    if (_smsLoginViaPanel && client != null && id != null) {
      lastActivationError = null;
      loginRemainingAttempts = null;
      try {
        final profile = await client.verifySmsLogin(challengeId: id, code: code);
        await _afterPanelLogin(profile);
        return true;
      } on PanelApiException catch (e) {
        lastActivationError = e.statusCode == null ? 'NETWORK' : e.code;
        loginRemainingAttempts = e.remainingAttempts;
        notifyListeners();
        return false;
      } catch (_) {
        lastActivationError = 'VERIFY_FAILED';
        return false;
      }
    }
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
    shiftPhotoTaken = true;
    DgLog.i(LogLayer.shift, 'permissions done · auto available');
    openShift();
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
    if (_usesPanelTasks) return 'local-shift';
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
    shiftPhotoTaken = true;
    online = true;
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
    unawaited(loadTrainingModules());
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

  // ── Canlı konum ────────────────────────────────────────────────────────
  // Başlatılmış (dağıtımdaki) görev varken kuryenin konumu panele akar;
  // şube ve merkez kuryeleri haritada buradan görür. Görev bitince durur.

  StreamSubscription<LiveFix>? _liveSub;
  String? _liveTaskId;
  LiveFix? _lastLiveSent;

  /// Panelin en son kabul ettiği canlı konumun zamanı.
  DateTime? lastLiveLocationAt;

  @override
  void notifyListeners() {
    super.notifyListeners();
    _syncLiveTracking();
  }

  @override
  void dispose() {
    unawaited(_liveSub?.cancel());
    super.dispose();
  }

  void _syncLiveTracking() {
    String? target;
    if (_usesPanelTasks) {
      for (final t in tasks) {
        if (t.status == TaskStatus.inProgress) {
          target = t.id;
          break;
        }
      }
    }
    if (target == _liveTaskId) return;
    _liveTaskId = target;
    _lastLiveSent = null;
    if (target == null) {
      unawaited(_liveSub?.cancel());
      _liveSub = null;
      return;
    }
    _liveSub ??= liveFixes().listen(_onLiveFix, onError: (_) {});
  }

  Future<void> _onLiveFix(LiveFix fix) async {
    final id = _liveTaskId;
    final client = panel;
    if (id == null || client == null) return;
    if (fix.mocked) {
      // Sahte konum uygulaması: kuryenin gerçek yeri değil, gönderilmez.
      if (!mockLocationDetected) {
        mockLocationDetected = true;
        DgLog.w(LogLayer.route, 'mock location ignored');
        notifyListeners();
      }
      return;
    }
    if (!isFreshLiveFix(fix, DateTime.now())) return;
    if (!shouldSendLiveFix(_lastLiveSent, fix)) return;
    // Yanıt beklenirken gelen ölçümler aynı konumu ikinci kez göndermesin.
    _lastLiveSent = fix;
    try {
      await client.sendLocation(
        id,
        purposeCode: 'ACTIVE_TASK',
        latitude: fix.lat,
        longitude: fix.lng,
        accuracy: fix.accuracy,
        heading: fix.heading,
        speed: fix.speed,
        capturedAt: fix.at,
      );
      lastLiveLocationAt = fix.at;
    } catch (e) {
      // Kuyruğa alınmaz: sunucu eski konumu kabul etmez, sıradaki ölçüm gider.
      DgLog.w(LogLayer.route, 'live location rejected: $e');
    }
    if (_gpsFitsStops(fix.lat, fix.lng)) {
      selfLat = fix.lat;
      selfLng = fix.lng;
      selfLocated = true;
    }
  }

  Future<void> refreshSelfPosition() async {
    final here = await readDeviceLocation();
    if (here == null) return;
    if (!_gpsFitsStops(here.lat, here.lng)) {
      DgLog.i(
        LogLayer.route,
        'gps discarded ${here.lat},${here.lng} far from stops',
      );
      return;
    }
    final moved = haversineMeters(
      LatLng(selfLat, selfLng),
      LatLng(here.lat, here.lng),
    );
    selfLat = here.lat;
    selfLng = here.lng;
    selfLocated = true;
    notifyListeners();
    if (moved > 40) unawaited(ensureDayRoute());
  }

  Future<void> callTask(BuildContext context, DeliveryTask task) async {
    if (_usesPanelTasks) {
      final client = panel;
      if (client != null) {
        try {
          final dial = await client.callRecipient(task.id);
          if (!context.mounted) return;
          final number = dial.phone.isNotEmpty ? dial.phone : dial.telUri;
          await dialNumber(context, number);
          return;
        } on PanelApiException catch (_) {}
        if (!context.mounted) return;
        await dialNumber(context, task.phone);
        return;
      }
    }
    var number = task.phone;
    if (liveApi) {
      try {
        final session = await api?.startMaskedCall(task.id);
        if (session != null && session.originated) {
          if (!context.mounted) return;
          final text = session.message?.trim().isNotEmpty == true
              ? session.message!
              : context.l10n.callConnecting;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
          return;
        }
        if (session != null && session.dialNumber.isNotEmpty) {
          number = session.dialNumber;
        }
      } catch (_) {}
    }
    if (!context.mounted) return;
    await dialNumber(context, number);
  }

  void _enqueueShift({required bool start}) {
    if (_usesPanelTasks) {
      // Vardiya backend'de tutulur (`courier-shifts/start|end`); konum
      // zorunlu. Çevrimdışıysa kuyrukta bekler, olay zamanı korunur.
      outbox.enqueue(
        operation: start
            ? SyncOperation.panelShiftStart
            : SyncOperation.panelShiftEnd,
        payload: {
          'latitude': selfLat,
          'longitude': selfLng,
          'idempotencyKey': Vault.newUuid(),
        },
      );
      if (online) unawaited(_flushPanelOutbox());
      return;
    }
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
    if (!kAllowDebugBypass) return;
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

  Map<String, dynamic>? taskRequirements;
  String? _requirementsTaskId;
  bool taskRequirementsLoading = false;

  Future<void> loadTaskRequirements(String taskId) async {
    if (!_usesPanelTasks) return;
    final client = panel;
    if (client == null) return;
    if (_requirementsTaskId != taskId) taskRequirements = null;
    _requirementsTaskId = taskId;
    taskRequirementsLoading = true;
    notifyListeners();
    try {
      taskRequirements = await client.fetchRequirements(taskId);
    } catch (_) {
      taskRequirements = null;
    }
    taskRequirementsLoading = false;
    notifyListeners();
  }

  /// [taskId] için yüklenmiş gereksinimler; başka görevinkiler dönmez.
  VisitRequirements? visitRequirements(String taskId) {
    final raw = taskRequirements;
    if (raw == null || _requirementsTaskId != taskId) return null;
    return VisitRequirements.fromJson(raw);
  }

  /// Bu görevin ürününe özel "yapılamadı" nedenleri.
  Future<List<({String code, String name})>> visitFailReasons(
    String taskId,
  ) async {
    final client = panel;
    if (client == null) return const [];
    return client.fetchDeliveryReasons(shipmentId: taskId);
  }

  /// Ziyaret fotoğrafını çekim kontrolleriyle yükler. Kurye konumu biliniyorsa
  /// adrese uzaklık da gider (sunucu engellemez, yalnız işaretler).
  Future<String?> uploadVisitPhoto(
    String taskId, {
    required String? path,
    required PhotoRequirement requirement,
    required CaptureQuality? quality,
    String? overrideReason,
  }) async {
    final client = panel;
    if (client == null) throw PanelApiException('PANEL_UNAVAILABLE');
    final t = taskOrNull(taskId);
    final distance = selfLocated && t != null
        ? haversineMeters(
            LatLng(selfLat, selfLng),
            LatLng(t.lat, t.lng),
          ).round()
        : null;
    final check = captureCheckJson(
      quality: quality,
      selfChecked: true,
      overrideReason: overrideReason,
      distanceMeters: distance,
      maxDistanceMeters: requirement.maxDistanceMeters,
    );
    if (inWidgetTest && (path == null || path.startsWith('test://'))) {
      return Vault.newUuid();
    }
    if (path == null || path.isEmpty || path.startsWith('test://')) {
      throw PanelApiException('PHOTO_UNAVAILABLE');
    }
    final List<int> bytes;
    try {
      bytes = await File(path).readAsBytes();
    } catch (_) {
      throw PanelApiException('PHOTO_UNAVAILABLE');
    }
    return client.uploadTaskEvidence(
      shipmentId: taskId,
      bytes: bytes,
      filename: 'photo.jpg',
      evidenceType: 'PHOTO',
      requirementCode: requirement.code,
      category: requirement.categoryCode,
      captureCheck: check,
      latitude: selfLocated ? selfLat : null,
      longitude: selfLocated ? selfLng : null,
      capturedAt: DateTime.now(),
    );
  }

  /// Anketi (varsa) gönderir ve ziyareti kapatır. Sunucu reddederse
  /// [PanelApiException] fırlatır; görev açık kalır, kurye düzeltip yeniden
  /// gönderir.
  Future<void> finalizeVisit(
    String taskId, {
    required bool delivered,
    String? reasonCode,
    String? note,
    VisitForm? form,
    Map<String, Object?> formValues = const {},
  }) async {
    final client = panel;
    if (client == null) throw PanelApiException('PANEL_UNAVAILABLE');
    if (!selfLocated) await refreshSelfPosition();
    if (form != null) {
      try {
        await client.saveTaskForm(
          taskId,
          formVersionId: form.formVersionId,
          values: form.cleanValues(formValues),
        );
      } on PanelApiException catch (e) {
        // Aynı yanıtlarla daha önce gönderilmişse sorun yok.
        if (e.code != 'FORM_ALREADY_SUBMITTED') rethrow;
      }
    }
    final res = await client.finalizeTask(
      taskId,
      outcome: delivered ? 'DELIVERED' : 'FAILED',
      idempotencyKey: Vault.newUuid(),
      reasonCode: reasonCode,
      note: note,
      latitude: selfLocated ? selfLat : null,
      longitude: selfLocated ? selfLng : null,
      capturedAt: DateTime.now(),
    );
    final t = taskOrNull(taskId);
    if (t != null) {
      t.status = delivered ? TaskStatus.delivered : TaskStatus.failed;
      final state = res.currentStateCode;
      if (state != null && state.isNotEmpty) t.wireStatus = state;
    }
    notifyListeners();
    unawaited(ensureDayRoute());
    unawaited(loadPhotoMistakeCount());
  }

  /// Duyuruya "okudum, anladım" der; başarılıysa düğme kalkar.
  Future<bool> acknowledgeAnnouncement(String notificationId) async {
    final i = notifications.indexWhere((n) => n.id == notificationId);
    final client = panel;
    if (i < 0 || client == null) return false;
    final n = notifications[i];
    final announcementId = n.announcementId;
    if (announcementId == null) return false;
    try {
      await client.acknowledgeAnnouncement(announcementId);
    } catch (_) {
      return false;
    }
    notifications[i] = AppNotification(
      id: n.id,
      kind: n.kind,
      title: n.title,
      body: n.body,
      createdAt: n.createdAt,
      icon: n.icon,
      tint: n.tint,
      ink: n.ink,
      taskId: n.taskId,
      announcementId: announcementId,
    );
    _readNotificationIds.add(n.id);
    _syncNotifBadge();
    notifyListeners();
    return true;
  }

  /// Şifre değiştirir; sunucu reddederse [PanelApiException].
  Future<void> changePanelPassword({
    required String current,
    required String next,
  }) async {
    final client = panel;
    if (client == null) throw PanelApiException('PANEL_UNAVAILABLE');
    await client.changePassword(currentPassword: current, newPassword: next);
  }

  Future<AvailabilityDto> loadAvailability() async {
    final client = panel;
    if (client == null) throw PanelApiException('PANEL_UNAVAILABLE');
    return client.fetchAvailability();
  }

  Future<void> saveAvailability(AvailabilityDto plan) async {
    final client = panel;
    if (client == null) throw PanelApiException('PANEL_UNAVAILABLE');
    await client.saveAvailability(plan);
  }

  /// "Beni arayın", "Canlı destek" ya da "Acil" isteği açar; başarılıysa
  /// talep listesi yenilenir. Konum ölçülmüşse talebe eklenir.
  Future<bool> requestQuickSupport(String category) async {
    final client = panel;
    if (client == null || !online) return false;
    try {
      await client.requestSupport(
        category: category,
        latitude: selfLocated ? selfLat : null,
        longitude: selfLocated ? selfLng : null,
      );
    } catch (_) {
      return false;
    }
    unawaited(loadTickets());
    return true;
  }

  Future<List<CustodyMoveDto>> custodyHistory() async {
    final client = panel;
    if (client == null) return const [];
    return client.fetchCustodyHistory();
  }

  Future<List<TaskReportDto>> taskReports(String taskId) async {
    final client = panel;
    if (client == null) return const [];
    return client.fetchReports(taskId);
  }

  /// İki imzalı tutanak gönderir; sunucu reddederse [PanelApiException].
  Future<void> createTaskReport(
    String taskId, {
    required String reportType,
    required SignatureCapture courierSignature,
    required SignatureCapture counterpartSignature,
    required String counterpartName,
    String? note,
  }) async {
    final client = panel;
    if (client == null) throw PanelApiException('PANEL_UNAVAILABLE');
    Future<String> url(SignatureCapture s) async =>
        inWidgetTest ? 'data:image/png;base64,AA==' : await s.toDataUrl();
    await client.createReport(
      taskId,
      reportType: reportType,
      courierSignature: await url(courierSignature),
      courierName: courier.fullName,
      counterpartSignature: await url(counterpartSignature),
      counterpartName: counterpartName,
      note: note,
      latitude: selfLocated ? selfLat : null,
      longitude: selfLocated ? selfLng : null,
      idempotencyKey: Vault.newUuid(),
    );
  }

  /// Hatalarım: kontrolde reddedilen fotoğraflar ve fotoğraf puanı.
  PhotoMistakesDto? photoMistakes;
  bool photoMistakesLoading = false;

  Future<void> loadPhotoMistakes() async {
    final client = panel;
    if (!_usesPanelTasks || client == null) return;
    photoMistakesLoading = true;
    notifyListeners();
    try {
      photoMistakes = await client.fetchPhotoMistakes();
    } catch (_) {
      // Liste gelmezse eldeki kalır.
    }
    photoMistakesLoading = false;
    notifyListeners();
  }

  /// Ana sayfa kartı için yalnız sayaç ve puan; liste varsa korunur.
  Future<void> loadPhotoMistakeCount() async {
    final client = panel;
    if (!_usesPanelTasks || client == null) return;
    try {
      final c = await client.fetchPhotoMistakeCount();
      photoMistakes = PhotoMistakesDto(
        items: photoMistakes?.items ?? const [],
        unacknowledged: c.unacknowledged,
        score: c.score,
        band: c.band,
        photos: c.photos,
        rejected: c.rejected,
        minPhotos: c.minPhotos,
        windowDays: c.windowDays,
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> acknowledgePhotoMistake(String evidenceId) async {
    final client = panel;
    final current = photoMistakes;
    if (client == null || current == null) return false;
    try {
      await client.acknowledgePhotoMistake(evidenceId);
    } catch (_) {
      return false;
    }
    final now = DateTime.now();
    final items = [
      for (final m in current.items)
        m.evidenceId == evidenceId ? m.acknowledged(now) : m,
    ];
    photoMistakes = PhotoMistakesDto(
      items: items,
      unacknowledged: items.where((m) => m.acknowledgedAt == null).length,
      score: current.score,
      band: current.band,
      photos: current.photos,
      rejected: current.rejected,
      minPhotos: current.minPhotos,
      windowDays: current.windowDays,
    );
    notifyListeners();
    return true;
  }

  Future<List<int>> photoMistakeFile(String evidenceId) async {
    final client = panel;
    if (client == null) return const [];
    try {
      return await client.fetchPhotoMistakeFile(evidenceId);
    } catch (_) {
      return const [];
    }
  }

  /// Panel oturumunda profil JetDiji'den gelir. Eski BFF çağrılmaz.
  Future<void> loadIdentity() async {
    if (_usesPanelTasks) {
      final client = panel;
      if (client == null) return;
      try {
        final profile = await client.fetchCourierProfile();
        final docs = await client.fetchMyDocuments();
        courier = courier.copyWith(
          city: profile.city ?? courier.city,
          district: profile.district ?? courier.district,
          vehicle: profile.vehicle ?? courier.vehicle,
          availability: profile.status ?? courier.availability,
        );
        documents = docs;
        liveApi = true;
      } catch (_) {}
      notifyListeners();
      return;
    }
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
    if (_usesPanelTasks) return;
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

  /// Live `GET /v1/tasks` veya panel `GET courier-tasks`.
  String? taskWatermark;

  Future<void> loadPanelTasks() async {
    if (!storageOk) return;
    final client = panel;
    if (client == null || !panelLoggedIn) return;
    try {
      final list = await client.fetchTasks(pageSize: 500);
      lastPanelError = null;
      final pendingIds = {
        for (final e in outbox.events)
          if (e.pending && e.operation.isPanel && e.subjectId != null)
            e.subjectId!,
      };
      final previous = {for (final t in tasks) t.id: t};
      final mapped = [
        for (final row in list.tasks) deliveryTaskFromPanel(row),
      ];
      for (final incoming in mapped) {
        final old = previous[incoming.id];
        if (old == null) continue;
        if (pendingIds.contains(incoming.id) ||
            _keepLocalPanelTask(old, incoming)) {
          incoming.status = old.status;
          incoming.wireStatus = old.wireStatus;
          incoming.receivedBy = old.receivedBy;
          incoming.signed = old.signed;
        }
      }
      final extras = [
        for (final t in previous.values)
          if (pendingIds.contains(t.id) &&
              !mapped.any((m) => m.id == t.id))
            t,
      ];
      tasks
        ..clear()
        ..addAll(mapped)
        ..addAll(extras);
      demo = false;
      liveApi = true;
      _dropDemoInbox();
      _resetImplausibleGps();
      unawaited(ensureDayRoute());
    } on PanelApiException catch (e) {
      if (e.statusCode == 401) {
        expirePanelSession();
        return;
      }
      lastPanelError = e.code;
    } catch (_) {
      lastPanelError = 'PANEL_REQUEST_FAILED';
    }
    notifyListeners();
  }

  Future<void> loadTasks() async {
    if (_usesPanelTasks) {
      await loadPanelTasks();
      return;
    }
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
    if (_resetImplausibleGps()) unawaited(ensureDayRoute());
    notifyListeners();
  }

  /// Watermark varsa `GET /v1/sync/changes` (çıkarılan id'ler dahil).
  /// Yoksa veya `resyncRequired` ise tam [loadTasks].
  Future<void> pullTasks() async {
    if (!storageOk) return;
    if (_usesPanelTasks) {
      await loadPanelTasks();
      return;
    }
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

  bool _keepLocalPanelTask(DeliveryTask local, DeliveryTask incoming) {
    if (local.status == incoming.status) return false;
    if (local.status == TaskStatus.inProgress && incoming.isOpen) return true;
    if (local.isClosed && incoming.isOpen) return true;
    return false;
  }

  void _dropDemoInbox() {
    notifications.removeWhere((n) => n.id.startsWith('demo-'));
    outbox.events.removeWhere((e) => e.clientEventId.startsWith('demo-seed-'));
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
    if (!storageOk) return;
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
    if (!storageOk) return;
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
      loadCourierDashboard(),
      refreshSelfPosition(),
      pullTasks(),
      loadTickets(),
      loadRoute(),
    ]);
    await ensureDayRoute();
  }

  Future<void> loadTickets() async {
    if (_usesPanelTasks) {
      final client = panel;
      if (client == null) return;
      try {
        replaceTickets(await client.fetchTickets());
      } on PanelApiException catch (e) {
        if (e.statusCode == 401) {
          expirePanelSession();
          return;
        }
      } catch (_) {}
      notifyListeners();
      return;
    }
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
        if (e.pending &&
            (e.operation == SyncOperation.supportTicketCreate ||
                e.operation == SyncOperation.panelTicketCreate))
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

  /// Zimmet kabulünde eksik / fazla: okutulanlarla birlikte destek kaydı
  /// olarak merkeze gider (backend'de ayrı uyuşmazlık ucu yok).
  void reportCustodyDiscrepancy(String note) {
    final codes = [for (final scan in zimmetScans) scan.code];
    createSupportTicket(
      category: 'OTHER',
      subject: 'Zimmet uyuşmazlığı',
      body: [
        note.trim(),
        'Okutulan (${codes.length}): ${codes.join(', ')}',
        'Beklenen kalem: ${custodyItems.length}',
      ].where((line) => line.isNotEmpty).join('\n'),
    );
  }

  /// Kurye molada mı (backend'e bildirilir; şube vardiya ekranında görür).
  bool onBreak = false;

  /// Molaya çıkar / moladan döner. Başarıda null, aksi halde neden döner;
  /// sunucu kabul etmeden durum değişmez.
  Future<String?> toggleBreak() async {
    final client = panel;
    if (!_usesPanelTasks || client == null) {
      onBreak = !onBreak;
      notifyListeners();
      return null;
    }
    final start = !onBreak;
    try {
      await client.setBreak(start: start, idempotencyKey: Vault.newUuid());
    } on PanelApiException catch (e) {
      // Sunucu zaten istenen durumdaysa yerel durumu ona eşitle.
      final settled = start
          ? e.code == 'BREAK_ALREADY_OPEN'
          : e.code == 'NO_OPEN_BREAK';
      if (!settled) {
        return e.code == 'NO_OPEN_SHIFT'
            ? 'Mola için önce vardiyayı başlatın.'
            : 'Mola kaydedilemedi. Bağlantıyı kontrol edin.';
      }
    } catch (_) {
      return 'Mola kaydedilemedi. Bağlantıyı kontrol edin.';
    }
    onBreak = start;
    notifyListeners();
    return null;
  }

  /// Cihaz sahte (mock) konum bildirdi: bu ölçümler panele gönderilmez.
  bool mockLocationDetected = false;

  /// Vardiyayı kapatır. Önce bekleyen kayıtları göndermeyi dener; hâlâ
  /// gönderilemeyen kayıt varsa kapatmaz ve nedenini döner.
  Future<String?> closeShiftChecked() async {
    if (outbox.pendingCount > 0) await pushSyncQueue();
    final waiting = outbox.pendingCount;
    if (waiting > 0) {
      return '$waiting kayıt henüz gönderilemedi. '
          'Bağlantı gelince tekrar deneyin; vardiya açık kalır.';
    }
    setShiftOpen(false);
    return null;
  }

  void createSupportTicket({
    required String category,
    required String subject,
    required String body,
    String? taskId,
  }) {
    final operation = _usesPanelTasks
        ? SyncOperation.panelTicketCreate
        : SyncOperation.supportTicketCreate;
    final event = outbox.enqueue(
      operation: operation,
      subjectId: taskId,
      payload: {
        'category': category,
        'subject': subject,
        'body': body,
        if (taskId != null) 'taskId': taskId,
        'mediaIds': const <String>[],
        'attachDiagnostics': false,
        if (_usesPanelTasks) 'idempotencyKey': Vault.newUuid(),
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
      if (_usesPanelTasks) {
        unawaited(_pushPanelQueue());
      } else if (api == null) {
        event.status = 'applied';
      } else {
        unawaited(_flushOutbox());
      }
    }
    notifyListeners();
  }

  void cyclePricingVisibility() {
    if (!kAllowDebugBypass) return;
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

  bool _hasPendingPanel(String id, SyncOperation op) => outbox.events.any(
    (e) => e.pending && e.subjectId == id && e.operation == op,
  );

  void _enqueuePanelStart(String id) {
    if (!_hasPendingPanel(id, SyncOperation.panelAccept)) {
      outbox.enqueue(operation: SyncOperation.panelAccept, subjectId: id);
    }
    if (!_hasPendingPanel(id, SyncOperation.panelStart)) {
      outbox.enqueue(
        operation: SyncOperation.panelStart,
        subjectId: id,
        payload: {
          'latitude': selfLat,
          'longitude': selfLng,
          'capturedAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
    }
    if (!_hasPendingPanel(id, SyncOperation.panelLocation)) {
      outbox.enqueue(
        operation: SyncOperation.panelLocation,
        subjectId: id,
        payload: {
          'purposeCode': 'ACTIVE_TASK',
          'latitude': selfLat,
          'longitude': selfLng,
        },
      );
    }
  }

  void _enqueuePanelFinalize(
    String id, {
    required String outcome,
    String? reasonCode,
    String? receivedBy,
  }) {
    if (_hasPendingPanel(id, SyncOperation.panelFinalize)) return;
    outbox.enqueue(
      operation: SyncOperation.panelFinalize,
      subjectId: id,
      payload: {
        // Sıra numaralı olay kimliği yeniden kurulumda tekrar edebilir;
        // sunucu anahtarı başka gönderide görürse reddeder.
        'idempotencyKey': Vault.newUuid(),
        'outcome': outcome,
        if (reasonCode != null) 'reasonCode': reasonCode,
        if (receivedBy != null) 'receivedBy': receivedBy,
        if (outcome != 'FAILED' && deliveryOtpToken != null)
          'otpEvidenceId': deliveryOtpToken,
        // Yalnız gerçek ölçüm gider; depo varsayılanı konum sayılmaz.
        if (selfLocated) ...{
          'latitude': selfLat,
          'longitude': selfLng,
          'capturedAt': DateTime.now().toUtc().toIso8601String(),
        },
      },
    );
  }

  Future<void> _pushPanelQueue() async {
    await outbox.waitForPersistence();
    if (online) await _flushOutbox();
  }

  double? _asDouble(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  Future<void> _playPanelEvent(OutboxEvent event) async {
    final client = panel;
    if (client == null) {
      throw PanelApiException('PANEL_UNAVAILABLE');
    }
    final id = event.subjectId;
    final needsTask =
        event.operation != SyncOperation.panelTicketCreate &&
        event.operation != SyncOperation.panelShiftStart &&
        event.operation != SyncOperation.panelShiftEnd;
    if (id == null && needsTask) {
      throw PanelApiException('PANEL_UNAVAILABLE');
    }
    switch (event.operation) {
      case SyncOperation.panelShiftStart:
      case SyncOperation.panelShiftEnd:
        final start = event.operation == SyncOperation.panelShiftStart;
        final key =
            event.payload['idempotencyKey'] as String? ?? event.clientEventId;
        final lat = _asDouble(event.payload['latitude']) ?? selfLat;
        final lng = _asDouble(event.payload['longitude']) ?? selfLng;
        try {
          if (start) {
            await client.startShift(
              latitude: lat,
              longitude: lng,
              idempotencyKey: key,
              occurredAt: event.occurredAt,
            );
          } else {
            await client.endShift(
              latitude: lat,
              longitude: lng,
              idempotencyKey: key,
              occurredAt: event.occurredAt,
            );
          }
        } on PanelApiException catch (e) {
          // Sunucu zaten istenen durumda (açık vardiya var / otomatik
          // kapanmış): yeniden denemenin anlamı yok, kayıt tamam sayılır.
          final settled = start
              ? e.code == 'SHIFT_ALREADY_OPEN'
              : e.code == 'NO_OPEN_SHIFT';
          if (!settled) rethrow;
        }
      case SyncOperation.panelAccept:
        await client.acceptTask(id!);
      case SyncOperation.panelStart:
        var lat = _asDouble(event.payload['latitude']) ?? selfLat;
        var lng = _asDouble(event.payload['longitude']) ?? selfLng;
        final raw =
            event.payload['capturedAt'] ?? event.payload['occurredAt'];
        final captured = raw is String ? DateTime.tryParse(raw) : null;
        final stale =
            captured == null ||
            DateTime.now().toUtc().difference(captured.toUtc()) >
                const Duration(minutes: 4);
        // Bayatsa taze ölçüm kullanılır; ölçüm yoksa kaydedilen gider.
        if (stale && selfLocated) {
          lat = selfLat;
          lng = selfLng;
        }
        final started = await client.startTask(
          id!,
          latitude: lat,
          longitude: lng,
        );
        final t = _maybeTask(id!);
        final state = started.workflowState;
        if (t != null && state != null && state.isNotEmpty) {
          t.wireStatus = state;
          t.status = taskStatusFromPanel(state);
        }
      case SyncOperation.panelLocation:
        // Kuyrukta beklemiş konum bayattır; sunucu yalnız taze konum ister.
        final waited =
            DateTime.now().toUtc().difference(event.occurredAt.toUtc()) >
            const Duration(minutes: 4);
        // Bayat konumun yerine koyacak gerçek ölçüm yoksa hiç gönderilmez.
        if (waited && !selfLocated) break;
        await client.sendLocation(
          id!,
          purposeCode:
              (event.payload['purposeCode'] as String?) ?? 'ACTIVE_TASK',
          latitude: waited
              ? selfLat
              : _asDouble(event.payload['latitude']) ?? selfLat,
          longitude: waited
              ? selfLng
              : _asDouble(event.payload['longitude']) ?? selfLng,
        );
      case SyncOperation.panelFinalize:
        final outcome = (event.payload['outcome'] as String?) ?? 'DELIVERED';
        final capturedRaw = event.payload['capturedAt'];
        final res = await client.finalizeTask(
          id!,
          outcome: outcome,
          // Teslim edilemedi'de bu alan kuryenin açıklamasını taşır.
          note: outcome == 'FAILED'
              ? event.payload['receivedBy'] as String?
              : null,
          latitude: _asDouble(event.payload['latitude']),
          longitude: _asDouble(event.payload['longitude']),
          capturedAt: capturedRaw is String
              ? DateTime.tryParse(capturedRaw)
              : null,
          idempotencyKey:
              event.payload['idempotencyKey'] as String? ??
              event.clientEventId,
          reasonCode: event.payload['reasonCode'] as String?,
          receivedBy: event.payload['receivedBy'] as String?,
          otpEvidenceId: event.payload['otpEvidenceId'] as String?,
        );
        final t = _maybeTask(id!);
        final state = res.currentStateCode;
        if (t != null && state != null && state.isNotEmpty) {
          t.wireStatus = state;
          t.status = taskStatusFromPanel(state);
        }
      case SyncOperation.panelTicketCreate:
        final created = await client.createTicket(
          clientEventId:
              event.payload['idempotencyKey'] as String? ??
              event.clientEventId,
          category: (event.payload['category'] as String?) ?? 'OTHER',
          subject: (event.payload['subject'] as String?) ?? '',
          body: (event.payload['body'] as String?) ?? '',
          taskId:
              event.subjectId ?? event.payload['taskId'] as String?,
        );
        final idx = tickets.indexWhere((t) => t.id == event.clientEventId);
        if (idx >= 0) {
          tickets[idx] = created;
        } else if (!tickets.any((t) => t.id == created.id)) {
          tickets.insert(0, created);
        }
      case SyncOperation.panelCustodyReturn:
        final warehouseId = event.payload['warehouseId'] as String? ?? '';
        final shipmentId = event.payload['shipmentId'] as String? ?? id!;
        await client.returnCustodyUnit(
          shipmentId,
          warehouseId: warehouseId,
          note: event.payload['note'] as String?,
        );
      default:
        throw ArgumentError('panel drain: ${event.operation.wire}');
    }
  }

  /// Sunucu teslim sonucunu kabul etmedi: görev kapanmış görünmesin, kurye
  /// neyin eksik olduğunu bilsin.
  void _onFinalizeRejected(String id, PanelApiException e) {
    final t = _maybeTask(id);
    if (t == null) return;
    // Aynı görev farklı sonuçla zaten kapanmış; liste yenilenince düzelir.
    if (e.code == 'FINALIZE_IDEMPOTENCY_CONFLICT') return;
    t.status = TaskStatus.inProgress;
    t.wireStatus = 'OUT_FOR_DELIVERY';
    t.receivedBy = null;
    t.signed = false;
    const labels = {
      'PHOTO': 'fotoğraf',
      'SIGNATURE': 'imza',
      'OTP': 'doğrulama kodu',
      'FORM': 'anket',
      'LOCATION': 'konum',
    };
    final missing = [
      for (final m in e.missing.toSet())
        if (labels[m] != null) labels[m]!,
    ];
    _prependNotification(
      kind: NotifKind.syncFail,
      title: 'Teslim kaydedilmedi',
      body: missing.isNotEmpty
          ? '${_taskName(id)}: ${missing.join(', ')} eksik. Tamamlayıp tekrar gönder.'
          : '${_taskName(id)}: ${e.serverMessage ?? 'Teslim sonucu kabul edilmedi.'} Durağı açıp tekrar dene.',
      icon: LucideIcons.circleAlert,
      tint: Dg.redBg,
      ink: Dg.red,
      taskId: id,
    );
  }

  /// Toplu gönderimde kayda verilen anahtar; yeniden denemede aynı kalır.
  final _batchKeys = <String, String>{};

  static const _batchKinds = {
    SyncOperation.panelAccept: 'TASK_ACCEPT',
    SyncOperation.panelStart: 'TASK_START',
    SyncOperation.panelLocation: 'TASK_LOCATION',
    SyncOperation.panelFinalize: 'DELIVERY_RESULT',
    SyncOperation.panelShiftStart: 'SHIFT_START',
    SyncOperation.panelShiftEnd: 'SHIFT_END',
  };

  /// Kaydın toplu gönderimdeki gövdesi; tekil istekle aynı kurallar. Bayat
  /// konumun yerine koyacak gerçek ölçüm yoksa null (o konum gönderilmez).
  Map<String, Object?>? _batchBody(OutboxEvent event) {
    final p = event.payload;
    final now = DateTime.now().toUtc();
    final old = now.difference(event.occurredAt.toUtc()) >
        const Duration(minutes: 4);
    ({double lat, double lng})? fix() {
      final lat = _asDouble(p['latitude']);
      final lng = _asDouble(p['longitude']);
      if (old && selfLocated) return (lat: selfLat, lng: selfLng);
      if (lat == null || lng == null) {
        return selfLocated ? (lat: selfLat, lng: selfLng) : null;
      }
      return (lat: lat, lng: lng);
    }

    switch (event.operation) {
      case SyncOperation.panelAccept:
        return const {};
      case SyncOperation.panelStart:
        final f = fix();
        if (f == null) return null;
        return {
          'latitude': f.lat,
          'longitude': f.lng,
          'capturedAt': now.toIso8601String(),
        };
      case SyncOperation.panelLocation:
        if (old && !selfLocated) return null;
        final f = fix();
        if (f == null) return null;
        return {
          'purposeCode': (p['purposeCode'] as String?) ?? 'ACTIVE_TASK',
          'latitude': f.lat,
          'longitude': f.lng,
          'capturedAt': now.toIso8601String(),
        };
      case SyncOperation.panelFinalize:
        final outcome = (p['outcome'] as String?) ?? 'DELIVERED';
        final captured = p['capturedAt'];
        return PanelApi.finalizeBody(
          outcome: outcome,
          reasonCode: p['reasonCode'] as String?,
          receivedBy: p['receivedBy'] as String?,
          otpEvidenceId: p['otpEvidenceId'] as String?,
          note: outcome == 'FAILED' ? p['receivedBy'] as String? : null,
          latitude: _asDouble(p['latitude']),
          longitude: _asDouble(p['longitude']),
          capturedAt: captured is String ? DateTime.tryParse(captured) : null,
        );
      case SyncOperation.panelShiftStart:
      case SyncOperation.panelShiftEnd:
        return {
          'latitude': _asDouble(p['latitude']) ?? selfLat,
          'longitude': _asDouble(p['longitude']) ?? selfLng,
          'occurredAt': event.occurredAt.toUtc().toIso8601String(),
        };
      default:
        return null;
    }
  }

  /// Bekleyen kayıtları `courier-sync/batch` ile tek istekte gönderir.
  /// Sonucu işlenen kayıtların kimliklerini döner; oturum düştüyse null.
  /// Toplu uç yanıt vermezse boş küme döner ve kayıtlar tek tek gönderilir.
  Future<Set<String>?> _flushPanelBatch(
    PanelApi client,
    List<OutboxEvent> pending,
  ) async {
    final events = [
      for (final e in pending)
        if (_batchKinds.containsKey(e.operation)) e,
    ].take(50).toList();
    if (events.length < 2) return const {};

    final handled = <String>{};
    final sent = <OutboxEvent>[];
    final operations = <Map<String, Object?>>[];
    for (final e in events) {
      final body = _batchBody(e);
      if (body == null) {
        // Gönderilecek geçerli konum yok: kayıt düşer, sıradaki ölçüm gider.
        await outbox.applyResults([(id: e.clientEventId, status: 'applied')]);
        handled.add(e.clientEventId);
        continue;
      }
      final shift =
          e.operation == SyncOperation.panelShiftStart ||
          e.operation == SyncOperation.panelShiftEnd;
      sent.add(e);
      operations.add({
        'clientEventId': e.clientEventId,
        'idempotencyKey':
            e.payload['idempotencyKey'] as String? ??
            _batchKeys.putIfAbsent(e.clientEventId, Vault.newUuid),
        'kind': _batchKinds[e.operation],
        'occurredAt': e.occurredAt.toUtc().toIso8601String(),
        if (shift)
          'groupKey': 'shift'
        else
          'params': {'shipmentId': e.subjectId},
        'body': body,
      });
    }
    if (operations.length < 2) return handled;

    final List<SyncBatchResultDto> results;
    try {
      results = await client.syncBatch(
        operations,
        pendingAfter: pending.length - events.length,
      );
    } on PanelApiException catch (e) {
      if (e.statusCode == 401) {
        expirePanelSession();
        return null;
      }
      lastPanelError = e.code;
      // Ağ yoksa beklenir; toplu uç reddettiyse tek tek denenir.
      if (e.isRetryable) {
        return {...handled, for (final s in sent) s.clientEventId};
      }
      return handled;
    } catch (_) {
      lastPanelError = 'PANEL_REQUEST_FAILED';
      return {...handled, for (final s in sent) s.clientEventId};
    }

    final byId = {for (final r in results) r.clientEventId: r};
    for (final e in sent) {
      final r = byId[e.clientEventId];
      if (r == null) continue; // Sonuç yok: tek tek gönderilecek.
      handled.add(e.clientEventId);
      final id = e.subjectId ?? '';
      if (r.done) {
        if (e.operation == SyncOperation.panelStart) {
          final t = _maybeTask(id);
          final state = r.data['workflowState'] as String?;
          if (t != null && state != null && state.isNotEmpty) {
            t.wireStatus = state;
            t.status = taskStatusFromPanel(state);
          }
        }
        _batchKeys.remove(e.clientEventId);
        await outbox.applyResults([(id: e.clientEventId, status: 'applied')]);
        continue;
      }
      if (!r.failed) continue; // RETRY / SKIPPED: kuyrukta kalır.
      final code = r.errorCode;
      // Sunucu zaten istenen durumda: yeniden denemenin anlamı yok.
      final settled =
          (e.operation == SyncOperation.panelShiftStart &&
              code == 'SHIFT_ALREADY_OPEN') ||
          (e.operation == SyncOperation.panelShiftEnd &&
              code == 'NO_OPEN_SHIFT');
      _batchKeys.remove(e.clientEventId);
      await outbox.applyResults([
        (id: e.clientEventId, status: settled ? 'applied' : 'rejected'),
      ]);
      if (settled) continue;
      lastPanelError = code;
      if (e.operation == SyncOperation.panelFinalize) {
        _onFinalizeRejected(
          id,
          PanelApiException(
            code,
            statusCode: r.httpStatus,
            serverMessage: r.error['message'] as String?,
            missing: [
              for (final m in r.error['missing'] as List? ?? const [])
                if (m is Map && m['type'] is String) m['type'] as String,
            ],
          ),
        );
      }
    }
    return handled;
  }

  Future<void> _flushPanelOutbox() async {
    if (!storageOk || !online || !_usesPanelTasks) return;
    final client = panel;
    if (client == null) return;
    final pending = [
      for (final e in outbox.events)
        if (e.pending && e.operation.isPanel) e,
    ]..sort((a, b) => a.sequence.compareTo(b.sequence));
    if (pending.isEmpty) return;

    // Birden çok kayıt birikmişse (çevrimdışı çalışma) tek istekte gider.
    // Toplu yanıtta sonucu dönmeyen kayıtlar aşağıda tek tek gönderilir.
    final batched = await _flushPanelBatch(client, pending);
    if (batched == null) return;

    final hardBlock = <String>{};
    for (final event in pending) {
      if (batched.contains(event.clientEventId)) continue;
      final id = event.subjectId ?? '';
      if (hardBlock.contains(id)) continue;
      try {
        await _playPanelEvent(event);
        await outbox.applyResults([
          (id: event.clientEventId, status: 'applied'),
        ]);
      } on PanelApiException catch (e) {
        if (e.statusCode == 401) {
          expirePanelSession();
          return;
        }
        lastPanelError = e.code;
        if (e.isRetryable) {
          if (event.operation == SyncOperation.panelAccept ||
              event.operation == SyncOperation.panelStart) {
            hardBlock.add(id);
          }
          continue;
        }
        await outbox.applyResults([
          (id: event.clientEventId, status: 'rejected'),
        ]);
        if (event.operation == SyncOperation.panelFinalize) {
          _onFinalizeRejected(id, e);
        }
        if (event.operation == SyncOperation.panelAccept ||
            event.operation == SyncOperation.panelStart) {
          hardBlock.add(id);
        }
      } catch (_) {
        lastPanelError = 'PANEL_REQUEST_FAILED';
        if (event.operation == SyncOperation.panelAccept ||
            event.operation == SyncOperation.panelStart) {
          hardBlock.add(id);
        }
      }
    }
  }

  /// Görevi başlatır. Panel oturumunda gerçek bir konum ölçümü yoksa
  /// başlatmaz ve false döner: sunucuya depo varsayılanı konum diye gitmez.
  Future<bool> startTask(String id) async {
    final t = taskById(id);
    if (_usesPanelTasks) {
      // Zimmet kabulü görevi zaten dağıtıma çıkarmıştır (4020); yeniden
      // başlatma isteği `TASK_NOT_READY_FOR_DELIVERY` ile reddedilir.
      final already =
          t.wireStatus == '4020' || t.wireStatus == 'OUT_FOR_DELIVERY';
      if (already) {
        t.status = TaskStatus.inProgress;
        notifyListeners();
        unawaited(ensureDayRoute());
        return true;
      }
      if (!selfLocated) await refreshSelfPosition();
      if (!selfLocated) {
        notifyListeners();
        return false;
      }
      t.status = TaskStatus.inProgress;
      t.wireStatus = 'OUT_FOR_DELIVERY';
      notifyListeners();
      unawaited(ensureDayRoute());
      _enqueuePanelStart(id);
      await _pushPanelQueue();
      return true;
    }
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
    return true;
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

  Future<void> deliverTask(
    String id, {
    String? receivedBy,
    Map<String, Object?>? proof,
  }) async {
    final t = taskById(id);
    t.status = TaskStatus.delivered;
    t.receivedBy = receivedBy;
    t.signed = proof?['type'] == 'RECIPIENT_SIGNATURE';
    if (_usesPanelTasks) {
      notifyListeners();
      unawaited(ensureDayRoute());
      _enqueuePanelFinalize(
        id,
        outcome: 'DELIVERED',
        receivedBy: receivedBy,
      );
      await _pushPanelQueue();
      return;
    }
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

  Future<void> returnTask(String id, {required String reason, String? note, String? photoMediaId}) async {
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
    if (_usesPanelTasks) {
      notifyListeners();
      unawaited(ensureDayRoute());
      _enqueuePanelFinalize(
        id,
        outcome: 'FAILED',
        reasonCode: panelFailureReasonCode(reason),
        receivedBy: detail,
      );
      await _pushPanelQueue();
      return;
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
    if (!storageOk) return;
    await _flushPanelOutbox();
    final pending = [
      for (final e in outbox.events)
        if (e.pending &&
            !e.operation.isPanel &&
            !e.operation.isBranch &&
            !(_usesPanelTasks &&
                (e.operation.isFastifyTaskWrite ||
                    e.operation == SyncOperation.supportTicketCreate ||
                    e.operation == SyncOperation.shiftStart ||
                    e.operation == SyncOperation.shiftEnd)))
          e,
    ];
    if (pending.isEmpty) {
      notifyListeners();
      return;
    }
    final client = api;
    if (client == null) {
      await outbox.applyResults([
        for (final e in pending) (id: e.clientEventId, status: 'applied'),
      ]);
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
          title: 'Kayıt gönderilemedi',
          body: event.subjectId == null
              ? 'Bir kayıt gönderilemedi. İnternet gelince tekrar denenecek.'
              : '${_taskName(event.subjectId)} gönderilemedi. İnternet gelince tekrar denenecek.',
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
    if (_usesPanelTasks) {
      notifyListeners();
      return;
    }
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
    if (_usesPanelTasks) {
      final client = panel;
      if (client == null) return false;
      try {
        final challengeId = await client.requestDeliveryOtp(taskId);
        deliveryChallengeId = challengeId;
        return challengeId != null && challengeId.isNotEmpty;
      } on PanelApiException catch (_) {
        return false;
      }
    }
    if (!liveApi) {
      if (!kAllowDebugBypass) return false;
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
    if (kAllowDebugBypass && code == '482913') {
      deliveryOtpToken = 'demo-otp-token';
      return true;
    }
    final id = deliveryChallengeId;
    if (_usesPanelTasks) {
      final client = panel;
      if (client == null || id == null) return false;
      try {
        final evidenceId = await client.verifyDeliveryOtp(
          shipmentId: taskId,
          challengeId: id,
          code: code,
        );
        if (evidenceId != null) deliveryOtpToken = evidenceId;
        return evidenceId != null;
      } on PanelApiException catch (_) {
        return false;
      }
    }
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

List<CustodyItemDto> _buildDemoCustodyItems() => const [
  CustodyItemDto(
    id: 'demo-custody-t4',
    type: 'parcel',
    barcode: 'DGO-8844',
    description: 'Fatma Şahin — Yeni Mah.',
    quantity: 1,
    acquiredAt: '2026-08-25T07:00:00.000Z',
    taskId: 't4',
  ),
];

List<TrainingModuleDto> _demoTrainingModulesSeed() => const [
  TrainingModuleDto(
    id: 'demo-training-1',
    title: 'Trafik güvenliği',
    summary: 'Motosikletle güvenli sürüş için 5 temel kural.',
    body:
        '1. Kask her zaman takılı.\n2. Hız sınırlarına uy.\n3. Yaya geçitlerinde dur.\n4. Gece reflektörlü ekipman kullan.\n5. Yorgunken sürme.',
    sortOrder: 1,
    completed: false,
  ),
  TrainingModuleDto(
    id: 'demo-training-2',
    title: 'KVKK ve müşteri verisi',
    summary: 'Teslimat sırasında müşteri bilgilerini nasıl koruruz.',
    body:
        'Alıcı adı, adresi ve telefonu sadece teslimat için kullanılır. Bu bilgileri paylaşmak, fotoğraflamak veya not almak yasaktır.',
    sortOrder: 2,
    completed: false,
  ),
  TrainingModuleDto(
    id: 'demo-training-3',
    title: 'Zimmet ve barkod okutma',
    summary: 'Doğru zimmet akışı neden önemli.',
    body:
        'Her paket teslim alınırken ve teslim edilirken barkodu okutulmalı. Okutulmayan paket zimmetinde görünmeye devam eder.',
    sortOrder: 3,
    completed: true,
    completedAt: '2026-09-01T09:00:00.000Z',
  ),
];

List<DeliveryTask> _buildDemoTasks() => [
  DeliveryTask(
    id: 't1',
    ref: 'DGO-8841',
    recipient: 'Ahmet Yılmaz',
    phone: '+905454879623',
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
    merchantName: 'ALİ BAŞEL – PLUXEE',
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
    sequence: 3,
    etaMinutes: 18,
    lat: 38.1554,
    lng: 29.0692,
    custodyCount: 1,
    slaMinutesLeft: 118,
    merchantName: 'ALİ BAŞEL – ASSİST',
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
    note: 'Alıcı yoktu · kapı fotoğrafı gönderilmeyi bekliyor',
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
      title: 'Kayıt gönderilemedi',
      body: 'DGO-8839 gönderilemedi. İnternet gelince tekrar denenecek.',
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
