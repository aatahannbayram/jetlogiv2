import 'package:dijigoo_kurye/api/client.dart';
import 'package:dijigoo_kurye/api/models.dart';
import 'package:dijigoo_kurye/geo.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodePolyline: known short example (Google\'s reference case)', () {
    // From Google's own encoded-polyline-algorithm docs: three points
    // starting at (38.5, -120.2).
    final points = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(points, hasLength(3));
    expect(points[0].latitude, closeTo(38.5, 1e-4));
    expect(points[0].longitude, closeTo(-120.2, 1e-4));
    expect(points[1].latitude, closeTo(40.7, 1e-4));
    expect(points[1].longitude, closeTo(-120.95, 1e-4));
    expect(points[2].latitude, closeTo(43.252, 1e-4));
    expect(points[2].longitude, closeTo(-126.453, 1e-4));
  });

  test('decodePolyline: real demo-route geometry starts and ends near the actual stops', () {
    final route = RoutePlanDto.fromJson(
      mockPayload('/v1/routes/current', RequestOptions(path: '/v1/routes/current')),
    );
    final points = decodePolyline(route.geometry!);
    expect(points.length, greaterThan(50), reason: 'a real road-following line has many vertices');

    // Origin (snapped) → Fatma (last). t3-t1-t2-t4 tour, see api_test.dart.
    expect(points.first.latitude, closeTo(38.1476, 2e-2));
    expect(points.first.longitude, closeTo(29.0702, 2e-2));
    expect(points.last.latitude, closeTo(38.1460, 2e-2));
    expect(points.last.longitude, closeTo(29.0488, 2e-2));
  });
}
