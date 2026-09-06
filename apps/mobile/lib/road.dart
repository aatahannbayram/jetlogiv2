import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import 'geo.dart';
import 'map_config.dart';

/// OSRM (OpenStreetMap, BSD) — Türkiye dahil planet grafiği. Anahtar yok,
/// canlı trafik yok; yol geometrisi ve serbest-akış süre.
///
/// Neden bu, neden GraphHopper/Valhalla değil:
/// - Türkiye'de OSM araç ağı şehir içi teslimatta yeterli (Geofabrik TR).
/// - OSRM `/route` tek istekte çok durak birleştirir; 2–6 nokta <1s.
/// - Canlı trafik (Google/TomTom/Yandex) ücretli; OSM tarafında yok.
///   ETA'yı "yaklaşık" tutuyoruz, UI'yı bloklamıyoruz.
///
/// Varsayılan `router.project-osrm.org` — anahtarsız, herkese açık demo
/// sunucu, ama üretim yükü için tasarlanmamış (rate-limit, düşünülmemiş
/// kesinti). Kendi barındırdığımız OSRM (`infra/osrm`, `docker-compose.yml`
/// → `osrm` servisi, Faz 1+2'de zaten inşa edildi ve test edildi) varsa
/// `--dart-define=OSRM_URL=http://localhost:5001` ile ona işaret et — aynı
/// API, sadece güvenilir. Prod'da CDN arkasında herkese açık bir OSRM ucu
/// varsa aynı şekilde geçilir.
///
/// Mapbox token varsa (`MAPBOX_TOKEN`) Directions v5 tercih edilir: aynı
/// OSRM ailesi, barındırılan graf + `polyline6`. Token yoksa public OSRM.
const kOsrmUrl = String.fromEnvironment(
  'OSRM_URL',
  defaultValue: 'https://router.project-osrm.org',
);

const _publicOsrm = 'https://router.project-osrm.org';

/// Public OSRM / OSM tile politikası bir tanımlı UA ister; Dio'nun varsayılan
/// `dart:io` başlığı bazı edge'lerde 403/boş cevap üretip düz çizgiye düşürüyordu.
const kRoutingUserAgent = 'DijigooKurye/1.0 (courier-routing)';

class _DemoSeed {
  const _DemoSeed({
    required this.waypoints,
    required this.meters,
    required this.seconds,
    required this.polyline,
  });
  final List<LatLng> waypoints;
  final List<int> meters;
  final List<int> seconds;
  final String polyline;
}

/// Güney demo: (1) pin=Ahmet — kurye uygulaması, (2) pinsiz çaprazsız tur.
const _demoSeeds = [
  _DemoSeed(
    waypoints: [
      LatLng(38.1476, 29.0702),
      LatLng(38.1512, 29.0614),
      LatLng(38.1554, 29.0692),
      LatLng(38.1481, 29.0558),
      LatLng(38.1460, 29.0488),
    ],
    meters: [1472, 1486, 1997, 592],
    seconds: [227, 195, 398, 213],
    polyline:
        r'angwgA_odmv@cN|N_GnMoAxKc@pKsApHaDbEaWhRaGbAeL@aL`B}MzBmQ]qFdDuE~HqInDqFiB_DkAsLL_e@rG{\dAgSpCwSaMyLkDVjCk@hB[hBEdGDhF`@zE`@dGsAfFsAtEsBzAiBvBsAlAiBv@o@\yCsB_DpB}Db@gDr@wCd`@cCb\Mx@{Jlr@m@bSbChJqLtHoKjCoFg@~DxGhDNvKeCjOuCpS{HjMcApUtC|EhAnDfFpCdC|AzAjDbDbExEdC`H`AfElAfFUhFDnHg@zGmAjEmAxB_CrAaDsCuCwBaEiDoFwFkHgFsAaAiFeGiCmCyEkEaEuCcBw@}DMkCc@gB~BmDlAcCdCiFfC_CrCkCnB}BvBmDpB}DpBeD`BeCzAiFpBkAcCe@~@oBOcB}BcCaIsDmWkEoO[gAiHkFaGwNcHiI_EmLyD}QUgI}LiSuEuH_NaFiLgAwCYkMcBkGtAa@aIz@gOfCkVdDos@P}D~@eGbAoGvA}MrBqReDq@wM}HiOgSmD}FkT_`@i@_AwEeJaGkLoPiSok@iZyOiEoG^gJrFjI{QdGeGpDaDb^rB|WvFpc@lMhJhClPtE`JbBrGQfI{HhFoG`FaA|K_@dCkBbF_BxD_Cx@Uz@S`@KfD?|Au@bBkA|GqDaCxTuAfMm@vFQbMmCdJ?pDfBjESxF}HnPu@hCyEfPsAbFM|Ai@lGjCuBlGhBxBpBrNpMzV`[dFlGfXv^~BvClAzA|@jAvIdA`ApBv@`B[vPl@rEfA`Iw@`GeO`dAsFf]kFb\nAjMzAfBbF~F~DxGhDNvKeCjOuCpS{HjMcApUtC|EhAdB`@lPjMvG|JvJdTrR~T|EzBrIzNxNlPlLvL|FfGrKbCnW|OrTpLfI|DvEdCxEvI`CrL`C`NLvJs@tOSzMl@vReAxS}AnNiA~QgCxQ_AlM@fMaBpS_HhVgBjFyBvG_GnTqCvFcAlFUbPbE`KnC|KhDdHzFxDjFpEf@zEWzIj@hGxClJbEpHrBvKQvI}@lJi@zNh@nFv@hKDtKaAhODpLf@bHsAfG?pKAbLgC~KhAjKtCbId@bJoArJwCnP',
  ),
  _DemoSeed(
    waypoints: [
      LatLng(38.1476, 29.0702),
      LatLng(38.1554, 29.0692),
      LatLng(38.1512, 29.0614),
      LatLng(38.1481, 29.0558),
      LatLng(38.1460, 29.0488),
    ],
    meters: [1435, 1486, 1026, 592],
    seconds: [219, 196, 281, 213],
    polyline:
        r'angwgA_odmv@cN|N_GnMoAxKc@pKsApHaDbEaWhRaGbAeL@aL`B}MzBmQ]qFdDuE~HqInDqFiB_DkAsLL_e@rG{\dAgSpCwSaMyLkDqCsHcF}MoBeDqIoCyDy@u@QaNuCoIgAgIo@eVaCmQmFaE}CkDkCwG{@me@UyBqBmGiBkCtBh@mGL}ArAcFxEgPt@iC|HoPRyFgBkE?qDlCeJPcMl@wFtAgM`CyT}GpDcBjA}At@gD?a@J{@Ry@TyD~BcF~AeCjB}K^aF`AiFnGgIzHsGPaJcBmPuEiJiCqc@mM}WwFc^sBqD`DeGdGkIzQfJsFnG_@xOhEnk@hZnPhS`GjLvEdJh@~@jT~_@lD|FhOfSvM|HdDp@sBpRwA|McAnG_AdGQ|DeDns@gCjV{@fO`@`IjGuAjMbBvCXhLfA~M`FtEtH|LhSTfIxD|Q~DlLbHhI`GvNhHjFZfAjEnOrDlWbC`IbB|BnBNd@_AjAbChFqBdC{AdDaB|DqBlDqB|BwBjCoB~BsChFgCbCeClDmAfB_CjCb@|DLbBv@`EtCxEjEhClChFdGrA`AjHfFnFvF`EhDtCvB`DrC~BsAlAyBlAkEf@{GEoHTiFmAgFaAgEeCaHcEyEkDcD}A{AqCeCoDgFdB`@lPjMvG|JvJdTrR~T|EzBrIzNxNlPlLvL|FfGrKbCnW|OrTpLfI|DvEdCxEvI`CrL`C`NLvJs@tOSzMl@vReAxS}AnNiA~QgCxQ_AlM@fMaBpS_HhVgBjFyBvG_GnTqCvFcAlFUbPbE`KnC|KhDdHzFxDjFpEf@zEWzIj@hGxClJbEpHrBvKQvI}@lJi@zNh@nFv@hKDtKaAhODpLf@bHsAfG?pKAbLgC~KhAjKtCbId@bJoArJwCnP',
  ),
];

class RoadLeg {
  const RoadLeg({
    required this.polyline,
    required this.meters,
    required this.seconds,
    this.precision = 6,
  });

  final String polyline;
  final int meters;
  final int seconds;
  final int precision;

  int get minutes => (seconds / 60).clamp(1, 180).round();

  List<LatLng> get points =>
      polyline.isEmpty ? const [] : decodePolyline(polyline, precision: precision);
}

/// Bir günün kalan durakları — kurye konumu sabit başlangıç, duraklar
/// NN+2-opt (SLA ağırlıklı) + yol ağı geometrisi.
class DayRoute {
  const DayRoute({
    required this.points,
    required this.meters,
    required this.seconds,
    required this.estimated,
    required this.provider,
    required this.stops,
    required this.waypoints,
    this.polyline = '',
    this.precision = 6,
    this.highlight = const [],
  });

  final List<LatLng> points;
  final String polyline;
  final int precision;
  final int meters;
  final int seconds;
  final bool estimated;
  final String provider;

  /// Ziyaret sırası (aynı kapıdaki görevler gruplu).
  final List<DayStop> stops;

  /// origin + sıralı duraklar (tekilleştirilmiş).
  final List<LatLng> waypoints;

  /// origin → ilk durak — haritada mor vurgulanan bacak.
  final List<LatLng> highlight;

  int get minutes => (seconds / 60).clamp(1, 180).round();

  /// Public/self-host OSRM veya Mapbox — tohum / kuş-uçuşu değil.
  bool get fromLiveEngine =>
      provider == 'osrm' ||
      provider == 'mapbox' ||
      provider.endsWith('-legs');

  List<String> get stopTaskIds => [for (final s in stops) ...s.taskIds];

  /// [taskId] durağına gelen bacak — harita şeridi ve detay ETA için.
  RoadSlice? legFor(String taskId) {
    final i = stops.indexWhere((s) => s.taskIds.contains(taskId));
    if (i < 0 || i + 1 >= waypoints.length) return null;
    final from = waypoints[i];
    final to = waypoints[i + 1];
    final pts = points.length > waypoints.length
        ? _sliceAlong(points, from, to)
        : [from, to];
    return RoadSlice(
      points: pts,
      meters: stops[i].meters,
      seconds: stops[i].seconds,
      precision: precision,
      estimated: estimated,
    );
  }
}

List<LatLng> _sliceAlong(List<LatLng> line, LatLng from, LatLng to) {
  final cuts = snapAlongRoute(line, [from, to]);
  final a = cuts[0];
  var b = cuts[1];
  if (b <= a) b = (a + 1).clamp(0, line.length - 1);
  return line.sublist(a, b + 1);
}

class RoadSlice {
  const RoadSlice({
    required this.points,
    required this.meters,
    required this.seconds,
    required this.precision,
    this.estimated = false,
  });

  final List<LatLng> points;
  final int meters;
  final int seconds;
  final int precision;
  final bool estimated;

  int get minutes => (seconds / 60).clamp(1, 180).round();
}

class DayStop {
  const DayStop({
    required this.taskIds,
    required this.at,
    required this.meters,
    required this.seconds,
  });

  final List<String> taskIds;
  final LatLng at;
  final int meters;
  final int seconds;
}

class RouteStopInput {
  const RouteStopInput({
    required this.id,
    required this.at,
    this.urgency = 0,
  });

  final String id;
  final LatLng at;
  final double urgency;
}

String roadCacheKey(Iterable<LatLng> points) => [
  for (final p in points)
    '${p.latitude.toStringAsFixed(4)},${p.longitude.toStringAsFixed(4)}',
].join('>');

String dayRouteCacheKey(
  LatLng origin,
  Iterable<RouteStopInput> stops, {
  String? pinFirstId,
}) =>
    '${origin.latitude.toStringAsFixed(4)},${origin.longitude.toStringAsFixed(4)}|$pinFirstId|'
    '${[for (final s in stops) '${s.id}:${s.at.latitude.toStringAsFixed(4)},${s.at.longitude.toStringAsFixed(4)}:${s.urgency.toStringAsFixed(2)}'].join('>')}';

/// Tek HTTP: [points] sırasıyla yol-izleyen geometri. Başarısız/timeout → null.
Future<RoadLeg?> fetchRoadLeg(
  List<LatLng> points, {
  Dio? dio,
  String baseUrl = kOsrmUrl,
  Duration timeout = const Duration(seconds: 6),
}) async {
  if (points.length < 2) return null;
  final fetched = await _fetchRoad(points, dio: dio, timeout: timeout);
  if (fetched == null) return null;
  return RoadLeg(
    polyline: fetched.polyline,
    meters: fetched.meters,
    seconds: fetched.seconds,
    precision: fetched.precision,
  );
}

/// Ağ yokken bile doğru ziyaret sırası — kuş uçuşu + SLA. Harita kesikli
/// çizer; [planDayRoute] sonra yol geometrisiyle yükseltir.
DayRoute planDayRouteLocal(
  LatLng origin,
  List<RouteStopInput> input, {
  String? pinFirstId,
}) {
  final clustered = _clusterStops(origin, input);
  if (clustered.isEmpty) {
    return DayRoute(
      points: const [],
      meters: 0,
      seconds: 0,
      estimated: true,
      provider: 'none',
      stops: const [],
      waypoints: [origin],
    );
  }
  final pinAt = pinFirstId == null
      ? -1
      : clustered.indexWhere((c) => c.ids.contains(pinFirstId));
  final List<_Cluster> ordered;
  if (pinAt >= 0) {
    final head = clustered[pinAt];
    final rest = [for (var i = 0; i < clustered.length; i++) if (i != pinAt) clustered[i]];
    if (rest.isEmpty) {
      ordered = [head];
    } else {
      final restOrder = optimizeVisitOrder(
        head.at,
        [for (final c in rest) c.at],
        urgency: [for (final c in rest) c.urgency],
      );
      ordered = [head, for (final i in restOrder) rest[i]];
    }
  } else {
    final order = optimizeVisitOrder(
      origin,
      [for (final c in clustered) c.at],
      urgency: [for (final c in clustered) c.urgency],
    );
    ordered = [for (final i in order) clustered[i]];
  }
  final waypoints = [origin, ...ordered.map((c) => c.at)];

  final stops = <DayStop>[];
  var meters = 0;
  var seconds = 0;
  for (var i = 0; i < ordered.length; i++) {
    final from = i == 0 ? origin : ordered[i - 1].at;
    final d = haversineMeters(from, ordered[i].at).round();
    final t = (d / kUrbanSpeedMps).round();
    meters += d;
    seconds += t;
    stops.add(
      DayStop(taskIds: ordered[i].ids, at: ordered[i].at, meters: d, seconds: t),
    );
  }

  final highlight = waypoints.length > 1
      ? [waypoints[0], waypoints[1]]
      : const <LatLng>[];

  final local = DayRoute(
    points: waypoints,
    meters: meters,
    seconds: seconds,
    estimated: true,
    provider: 'haversine',
    stops: stops,
    waypoints: waypoints,
    highlight: highlight,
  );
  // Demo Güney kümesi: ağ beklemeden caddeyi izleyen çizgi.
  return _demoSeedIfMatch(local) ?? local;
}

/// Yerel sırayı koruyup yol geometrisiyle yükseltir.
///
/// Çok-duraklı tek OSRM isteği kasabada zikzak scribble üretebiliyor
/// (durakların hepsine yakın geçip 8 km'ye şişiyor). Bacak bacak
/// birleştirmek caddeyi takip eder. Kötü canlı cevap tohum/yerel
/// çizginin üstüne yazılmaz.
Future<DayRoute> planDayRoute(
  LatLng origin,
  List<RouteStopInput> input, {
  String? pinFirstId,
  Dio? dio,
  Duration timeout = const Duration(seconds: 6),
}) async {
  final local = planDayRouteLocal(origin, input, pinFirstId: pinFirstId);
  if (local.waypoints.length < 2) return local;

  final client = dio ??
      Dio(
        BaseOptions(
          connectTimeout: timeout,
          receiveTimeout: timeout,
          sendTimeout: timeout,
          headers: const {
            'User-Agent': kRoutingUserAgent,
            'Accept': 'application/json',
          },
        ),
      );

  _FetchedRoad? road;
  if (local.waypoints.length >= 3) {
    road = await _fetchRoadLegs(
      local.waypoints,
      dio: client,
      timeout: timeout,
    );
  }
  road ??= await _fetchRoad(
    local.waypoints,
    dio: client,
    timeout: timeout,
  );
  if (road != null &&
      road.points.length > 1 &&
      _roadIsSane(local, road)) {
    return _withRoad(local, road);
  }
  return local;
}

/// Canlı çizgi duraklara oturmalı ve kuş-uçuşu / tohumdan makul sapmalı.
bool _roadIsSane(DayRoute local, _FetchedRoad road) {
  if (!lineFitsWaypoints(road.points, local.waypoints)) return false;
  if (local.meters <= 0) return true;
  final cap = !local.estimated
      ? local.meters * 1.25
      : (local.meters * 2.2).clamp(800, 25000);
  return road.meters <= cap;
}

DayRoute _withRoad(DayRoute local, _FetchedRoad road) {
  final legs = _splitLegs(local.waypoints, road);
  final stops = <DayStop>[
    for (var i = 0; i < local.stops.length; i++)
      DayStop(
        taskIds: local.stops[i].taskIds,
        at: local.stops[i].at,
        meters: i < legs.length ? legs[i].meters : local.stops[i].meters,
        seconds: i < legs.length ? legs[i].seconds : local.stops[i].seconds,
      ),
  ];
  final cuts = snapAlongRoute(road.points, [
    local.waypoints.first,
    local.stops.first.at,
  ]);
  final cut = (cuts.length > 1 ? cuts[1] : 1).clamp(1, road.points.length - 1);
  return DayRoute(
    points: road.points,
    polyline: road.polyline,
    precision: road.precision,
    meters: road.meters,
    seconds: road.seconds,
    estimated: false,
    provider: road.provider,
    stops: stops,
    waypoints: local.waypoints,
    highlight: road.points.sublist(0, cut + 1),
  );
}

DayRoute? _demoSeedIfMatch(DayRoute local) {
  for (final seed in _demoSeeds) {
    if (local.waypoints.length != seed.waypoints.length) continue;
    var match = true;
    for (var i = 0; i < local.waypoints.length; i++) {
      if (haversineMeters(local.waypoints[i], seed.waypoints[i]) >
          kSameStopMeters) {
        match = false;
        break;
      }
    }
    if (!match) continue;
    return _withRoad(
      local,
      _FetchedRoad(
        polyline: seed.polyline,
        precision: 6,
        meters: seed.meters.fold(0, (a, b) => a + b),
        seconds: seed.seconds.fold(0, (a, b) => a + b),
        provider: 'osrm-seed',
        legMeters: seed.meters,
        legSeconds: seed.seconds,
      ),
    );
  }
  return null;
}

class _Cluster {
  _Cluster({required this.ids, required this.at, required this.urgency});
  final List<String> ids;
  final LatLng at;
  final double urgency;
}

List<_Cluster> _clusterStops(LatLng origin, List<RouteStopInput> input) {
  final clusters = <_Cluster>[];
  for (final s in input) {
    if (haversineMeters(origin, s.at) < kSameStopMeters) {
      // Kurye zaten bu kapıdaysa rota durağı olarak ekleme.
      continue;
    }
    final hit = clusters.indexWhere(
      (c) => haversineMeters(c.at, s.at) < kSameStopMeters,
    );
    if (hit >= 0) {
      clusters[hit].ids.add(s.id);
      if (s.urgency > clusters[hit].urgency) {
        clusters[hit] = _Cluster(
          ids: clusters[hit].ids,
          at: clusters[hit].at,
          urgency: s.urgency,
        );
      }
    } else {
      clusters.add(_Cluster(ids: [s.id], at: s.at, urgency: s.urgency));
    }
  }
  return clusters;
}

class _FetchedRoad {
  const _FetchedRoad({
    required this.polyline,
    required this.precision,
    required this.meters,
    required this.seconds,
    required this.provider,
    required this.legMeters,
    required this.legSeconds,
    this.decoded,
  });

  final String polyline;
  final int precision;
  final int meters;
  final int seconds;
  final String provider;
  final List<int> legMeters;
  final List<int> legSeconds;
  final List<LatLng>? decoded;

  List<LatLng> get points =>
      decoded ?? decodePolyline(polyline, precision: precision);
}

Future<_FetchedRoad?> _fetchRoadLegs(
  List<LatLng> points, {
  required Dio dio,
  required Duration timeout,
}) async {
  if (points.length < 3) return null;
  final legs = <_FetchedRoad>[];
  for (var i = 0; i < points.length - 1; i++) {
    final leg = await _fetchRoad(
      [points[i], points[i + 1]],
      dio: dio,
      timeout: timeout,
    );
    if (leg == null || leg.points.length < 2) return null;
    legs.add(leg);
  }
  final pts = <LatLng>[];
  final legMeters = <int>[];
  final legSeconds = <int>[];
  var meters = 0;
  var seconds = 0;
  for (final leg in legs) {
    final p = leg.points;
    if (pts.isEmpty) {
      pts.addAll(p);
    } else {
      pts.addAll(p.skip(1));
    }
    legMeters.add(leg.meters);
    legSeconds.add(leg.seconds);
    meters += leg.meters;
    seconds += leg.seconds;
  }
  if (!lineFitsWaypoints(pts, points)) return null;
  return _FetchedRoad(
    polyline: '',
    precision: legs.first.precision,
    meters: meters,
    seconds: seconds,
    provider: '${legs.first.provider}-legs',
    legMeters: legMeters,
    legSeconds: legSeconds,
    decoded: pts,
  );
}

/// OSRM bacak uzunluklarını duraklara yazar; yoksa geometriyi duraklarda keser.
List<({int meters, int seconds})> _splitLegs(
  List<LatLng> waypoints,
  _FetchedRoad road,
) {
  if (road.legMeters.length == waypoints.length - 1) {
    return [
      for (var i = 0; i < road.legMeters.length; i++)
        (meters: road.legMeters[i], seconds: road.legSeconds[i]),
    ];
  }
  final out = <({int meters, int seconds})>[];
  for (var i = 1; i < waypoints.length; i++) {
    final d = haversineMeters(waypoints[i - 1], waypoints[i]).round();
    out.add((meters: d, seconds: (d / kUrbanSpeedMps).round()));
  }
  return out;
}

Future<_FetchedRoad?> _fetchRoad(
  List<LatLng> points, {
  Dio? dio,
  Duration timeout = const Duration(seconds: 6),
}) async {
  if (points.length < 2) return null;
  final client =
      dio ??
      Dio(
        BaseOptions(
          connectTimeout: timeout,
          receiveTimeout: timeout,
          sendTimeout: timeout,
          headers: const {
            'User-Agent': kRoutingUserAgent,
            'Accept': 'application/json',
          },
        ),
      );

  if (kMapboxToken.isNotEmpty) {
    final mapped = await _get(
      client,
      _mapboxUrl(points),
      precision: 6,
      provider: 'mapbox',
      near: points,
    );
    if (mapped != null) return mapped;
  }

  final hosts = <String>[kOsrmUrl];
  if (_publicOsrm != kOsrmUrl) hosts.add(_publicOsrm);
  final attempts = <({String url, int precision})>[
    for (final host in hosts) (url: _osrmUrl(host, points, rich: true), precision: 6),
    for (final host in hosts) (url: _osrmUrl(host, points, rich: false), precision: 6),
    for (final host in hosts)
      (url: _osrmUrl(host, points, rich: false, polyline6: false), precision: 5),
  ];
  for (final attempt in attempts) {
    final fetched = await _get(
      client,
      attempt.url,
      precision: attempt.precision,
      provider: 'osrm',
      near: points,
    );
    if (fetched != null) return fetched;
  }
  return null;
}

String _osrmUrl(
  String base,
  List<LatLng> points, {
  bool rich = true,
  bool polyline6 = true,
}) {
  final coords = points
      .map(
        (p) =>
            '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}',
      )
      .join(';');
  final geom = polyline6 ? 'polyline6' : 'polyline';
  if (!rich) {
    return '$base/route/v1/driving/$coords?overview=full&geometries=$geom&steps=false';
  }
  // 1 km kurye (bina içi GPS), 400 m durak. continue_straight kurye
  // teslimatında U-dönüşünü yasaklayıp kasaba turunu şişiriyordu.
  final radiuses = [
    '1000',
    ...List.filled(points.length - 1, '400'),
  ].join(';');
  return '$base/route/v1/driving/$coords?overview=full&geometries=$geom&steps=false&radiuses=$radiuses';
}

String _mapboxUrl(List<LatLng> points) {
  final coords = points
      .map(
        (p) =>
            '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}',
      )
      .join(';');
  return 'https://api.mapbox.com/directions/v5/mapbox/driving/$coords?geometries=polyline6&overview=full&steps=false&access_token=$kMapboxToken';
}

Future<_FetchedRoad?> _get(
  Dio client,
  String url, {
  required int precision,
  required String provider,
  List<LatLng>? near,
}) async {
  Future<_FetchedRoad?> once() async {
    try {
      final res = await client.get<Map<String, dynamic>>(
        url,
        options: Options(
          headers: const {
            'User-Agent': kRoutingUserAgent,
            'Accept': 'application/json',
          },
        ),
      );
      final body = res.data;
      if (body == null) return null;
      final code = body['code'];
      if (code != null && code != 'Ok') return null;
      final routes = body['routes'];
      if (routes is! List || routes.isEmpty) return null;
      final route = routes.first;
      if (route is! Map) return null;
      final geometry = route['geometry'];
      if (geometry is! String || geometry.isEmpty) return null;
      final distance = route['distance'];
      final duration = route['duration'];
      final rawLegs = route['legs'];
      final legMeters = <int>[];
      final legSeconds = <int>[];
      if (rawLegs is List) {
        for (final leg in rawLegs) {
          if (leg is! Map) continue;
          final d = leg['distance'];
          final t = leg['duration'];
          legMeters.add(d is num ? d.round() : 0);
          legSeconds.add(t is num ? t.round() : 0);
        }
      }
      _FetchedRoad built(int prec) => _FetchedRoad(
        polyline: geometry,
        precision: prec,
        meters: distance is num ? distance.round() : 0,
        seconds: duration is num ? duration.round() : 0,
        provider: provider,
        legMeters: legMeters,
        legSeconds: legSeconds,
      );
      final fetched = built(precision);
      if (near == null || lineFitsWaypoints(fetched.points, near)) {
        return fetched;
      }
      final alt = built(precision == 6 ? 5 : 6);
      if (lineFitsWaypoints(alt.points, near)) return alt;
      return null;
    } catch (_) {
      return null;
    }
  }

  return await once() ?? await once();
}
