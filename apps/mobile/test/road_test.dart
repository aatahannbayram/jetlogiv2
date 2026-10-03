import 'package:dijigoo_kurye/road.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('roadCacheKey rounds to 11m so rebuilds reuse the same OSRM call', () {
    final a = LatLng(38.14761, 29.07021);
    final b = LatLng(38.15122, 29.06141);
    final nearA = LatLng(38.147609, 29.070209);
    expect(roadCacheKey([a, b]), roadCacheKey([nearA, b]));
  });

  test('fetchRoadLeg: iki noktadan azında null', () async {
    expect(await fetchRoadLeg([const LatLng(38.15, 29.06)]), isNull);
  });

  test('RoadLeg.minutes clamps to at least 1', () {
    expect(
      const RoadLeg(polyline: 'x', meters: 80, seconds: 20).minutes,
      1,
    );
    expect(
      const RoadLeg(polyline: 'x', meters: 4500, seconds: 360).minutes,
      6,
    );
  });

  test('planDayRoute: motor 404 olunca yerel sırayı korur', () async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) =>
              handler.reject(DioException(requestOptions: options, type: DioExceptionType.badResponse)),
        ),
      );
    final route = await planDayRoute(
      const LatLng(38.1476, 29.0702),
      [
        const RouteStopInput(id: 'a', at: LatLng(38.1512, 29.0614), urgency: 0.6),
        const RouteStopInput(id: 'b', at: LatLng(38.1481, 29.0558)),
      ],
      dio: dio,
      timeout: const Duration(milliseconds: 40),
    );
    expect(route.estimated, isTrue);
    expect(route.stops, isNotEmpty);
    expect(route.waypoints.first.latitude, closeTo(38.1476, 1e-6));
  });
}
