import 'package:latlong2/latlong.dart';

/// Decodes a Google-algorithm encoded polyline (precision 5) — the format
/// OSRM returns from `apps/api`'s `/v1/routes/current` (see
/// `apps/api/src/services/routing.ts`, `geometries=polyline`). Used to draw
/// the real road-following line on [MapStrip] instead of straight segments
/// between stops.
List<LatLng> decodePolyline(String encoded) {
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

    points.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return points;
}
