import 'dart:math';

import 'package:latlong2/latlong.dart';

/// Decodes a Google-algorithm encoded polyline.
///
/// OSRM/Mapbox `geometries=polyline` → [precision] 5 (~1.1 m).
/// `geometries=polyline6` → 6 (~11 cm) — şehir içi teslimatta yol çizgisi
/// kaba kırık doğru olmasın diye varsayılan motor çıktımız bu.
String? _polylineCacheKey;
List<LatLng>? _polylineCache;

List<LatLng> decodePolyline(String encoded, {int precision = 5}) {
  final cacheKey = '$precision|$encoded';
  if (cacheKey == _polylineCacheKey && _polylineCache != null) {
    return _polylineCache!;
  }
  final factor = pow(10, precision).toDouble();
  final points = <LatLng>[];
  var index = 0, lat = 0, lng = 0;

  while (index < encoded.length) {
    var shift = 0, result = 0, b = 0x20;
    while (b >= 0x20) {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    }
    lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

    shift = 0;
    result = 0;
    b = 0x20;
    while (b >= 0x20) {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    }
    lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

    points.add(LatLng(lat / factor, lng / factor));
  }
  _polylineCacheKey = cacheKey;
  _polylineCache = points;
  return points;
}

double haversineMeters(LatLng a, LatLng b) {
  const radius = 6371000.0;
  final dLat = _rad(b.latitude - a.latitude);
  final dLng = _rad(b.longitude - a.longitude);
  final h =
      (1 - cos(dLat)) / 2 +
      cos(_rad(a.latitude)) * cos(_rad(b.latitude)) * (1 - cos(dLng)) / 2;
  return 2 * radius * asin(sqrt(h));
}

double _rad(double deg) => deg * 3.141592653589793 / 180;

/// ~15 m — aynı kapı / aynı bina. Yinelenen koordinat OSRM'de U-dönüşü
/// ve haritada zikzak üretir.
const kSameStopMeters = 15.0;

/// ~30 km/h saha-içi serbest akış — canlı trafik yokken ETA tabanı.
const kUrbanSpeedMps = 8.3;

/// SLA / pencere aciliyeti 0..1. Yüksek değer "daha erken uğra" demek:
/// NN maliyetini kısar, 2-opt aynı ağırlıklı matriste çalışır.
///
/// Last-mile pratiği: kuş uçuşu + 2-opt tek başına SLA'yı ezer (13:00
/// penceresi batıya, kurye doğudayken atlanır). Ağırlık küçük tutulur
/// (0.35) — yolu ikiye katlamaz, kaçırılmak üzere olan durağı öne alır.
List<int> optimizeVisitOrder(
  LatLng start,
  List<LatLng> stops, {
  List<double>? urgency,
}) {
  final n = stops.length;
  if (n == 0) return const [];
  if (n == 1) return const [0];

  final pts = [start, ...stops];
  final m = pts.length;
  // Urgency must not warp the metre matrix — that produced self-crossing
  // tours (west through town, then back east) that looked like a scribble.
  final matrix = List.generate(m, (i) {
    return List.generate(m, (j) {
      if (i == j) return 0.0;
      return haversineMeters(pts[i], pts[j]);
    });
  });

  final tour = _twoOpt(_nearestNeighbor(matrix), matrix);
  var order = [for (var i = 1; i < tour.length; i++) tour[i] - 1];
  if (urgency != null && urgency.length == n) {
    order = _nudgeUrgent(start, stops, order, urgency);
  }
  return order;
}

/// Move a nearly-due stop one slot earlier only when the detour is small.
List<int> _nudgeUrgent(
  LatLng start,
  List<LatLng> stops,
  List<int> order,
  List<double> urgency,
) {
  final out = List<int>.from(order);
  for (var i = 1; i < out.length; i++) {
    final u = urgency[out[i]].clamp(0.0, 1.0);
    if (u < 0.75) continue;
    final prev = i == 0 ? start : stops[out[i - 1]];
    final cur = stops[out[i]];
    final earlier = i == 1 ? start : stops[out[i - 2]];
    final swapped = haversineMeters(earlier, cur) + haversineMeters(cur, prev);
    final base = haversineMeters(earlier, prev) + haversineMeters(prev, cur);
    if (swapped <= base * 1.15) {
      final tmp = out[i - 1];
      out[i - 1] = out[i];
      out[i] = tmp;
    }
  }
  return out;
}

List<int> _nearestNeighbor(List<List<double>> matrix) {
  final n = matrix.length;
  final visited = List<bool>.filled(n, false);
  final order = <int>[0];
  visited[0] = true;
  var current = 0;
  for (var step = 1; step < n; step++) {
    var best = -1;
    var bestCost = double.infinity;
    for (var j = 0; j < n; j++) {
      if (visited[j]) continue;
      final cost = matrix[current][j];
      if (cost < bestCost) {
        bestCost = cost;
        best = j;
      }
    }
    if (best < 0) break;
    order.add(best);
    visited[best] = true;
    current = best;
  }
  return order;
}

List<int> _twoOpt(List<int> initial, List<List<double>> matrix) {
  var tour = List<int>.from(initial);
  var best = _pathLength(tour, matrix);
  var improved = true;
  while (improved) {
    improved = false;
    for (var i = 1; i < tour.length - 1; i++) {
      for (var k = i + 1; k < tour.length; k++) {
        final candidate = [
          ...tour.sublist(0, i),
          ...tour.sublist(i, k + 1).reversed,
          ...tour.sublist(k + 1),
        ];
        final len = _pathLength(candidate, matrix);
        if (len + 1e-6 < best) {
          tour = candidate;
          best = len;
          improved = true;
        }
      }
    }
  }
  return tour;
}

double _pathLength(List<int> order, List<List<double>> matrix) {
  var total = 0.0;
  for (var i = 0; i < order.length - 1; i++) {
    total += matrix[order[i]][order[i + 1]];
  }
  return total;
}

/// [polyline] üzerinde [target]'e en yakın tepe — mevcut bacağı boyamak için.
int nearestVertexIndex(List<LatLng> polyline, LatLng target) {
  if (polyline.isEmpty) return 0;
  var best = 0;
  var bestD = double.infinity;
  for (var i = 0; i < polyline.length; i++) {
    final d = haversineMeters(polyline[i], target);
    if (d < bestD) {
      bestD = d;
      best = i;
    }
  }
  return best;
}

/// Each target snaps to a vertex *after* the previous one, so a line that
/// passes a stop twice (or backtracks) still paints the correct leg.
List<int> snapAlongRoute(List<LatLng> line, List<LatLng> targets) {
  if (line.isEmpty) return [for (final _ in targets) 0];
  if (targets.isEmpty) return const [];
  final cuts = <int>[];
  var from = 0;
  for (var t = 0; t < targets.length; t++) {
    final left = targets.length - t;
    final lastAllowed = (line.length - left).clamp(from, line.length - 1);
    var best = from;
    var bestD = double.infinity;
    for (var i = from; i <= lastAllowed; i++) {
      final d = haversineMeters(line[i], targets[t]);
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    cuts.add(best);
    from = (best + (t < targets.length - 1 ? 1 : 0)).clamp(0, line.length - 1);
  }
  return cuts;
}

/// Pull a stop marker onto the driven line when the address is just off-road.
List<LatLng> alignStopsToRoute(
  List<LatLng> stops,
  List<LatLng> line, {
  double maxSnapMeters = 160,
}) {
  if (line.length < 2 || stops.isEmpty) return stops;
  final idx = snapAlongRoute(line, stops);
  return [
    for (var i = 0; i < stops.length; i++)
      haversineMeters(stops[i], line[idx[i]]) <= maxSnapMeters
          ? line[idx[i]]
          : stops[i],
  ];
}

bool lineFitsWaypoints(
  List<LatLng> line,
  List<LatLng> waypoints, {
  double maxMeters = 450,
}) {
  if (line.length < 2 || waypoints.length < 2) return false;
  final cuts = snapAlongRoute(line, waypoints);
  if (cuts.length != waypoints.length) return false;
  for (var i = 0; i < waypoints.length; i++) {
    if (haversineMeters(line[cuts[i]], waypoints[i]) > maxMeters) {
      return false;
    }
  }
  return true;
}
