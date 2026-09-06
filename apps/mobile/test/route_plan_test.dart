import 'package:dijigoo_kurye/geo.dart';
import 'package:dijigoo_kurye/road.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const self = LatLng(38.1476, 29.0702);
  const ahmet = LatLng(38.1512, 29.0614);
  const elif = LatLng(38.1481, 29.0558);
  const mehmet = LatLng(38.1554, 29.0692);
  const fatma = LatLng(38.1460, 29.0488);

  test('optimizeVisitOrder: zigzag on a line is uncrossed', () {
    const start = LatLng(0, 0);
    final stops = [
      const LatLng(0, 0.4),
      const LatLng(0, 0.1),
      const LatLng(0, 0.3),
      const LatLng(0, 0.2),
    ];
    final order = optimizeVisitOrder(start, stops);
    expect(order.toSet(), {0, 1, 2, 3});
    // From 0, the nearest-neighbour + 2-opt walk is 0.1 → 0.2 → 0.3 → 0.4
    expect(order, [1, 3, 2, 0]);
  });

  test('optimizeVisitOrder: visits every stop once from a fixed start', () {
    final order = optimizeVisitOrder(
      self,
      [ahmet, elif, mehmet, fatma],
      urgency: const [0.6, 0, 0.34, 0.45],
    );
    expect(order.toSet(), {0, 1, 2, 3});
    expect(order.length, 4);
  });

  test('planDayRouteLocal: pinned stop stays first, same doorway is clustered', () {
    final route = planDayRouteLocal(
      self,
      [
        RouteStopInput(id: 't1', at: ahmet, urgency: 0.6),
        RouteStopInput(id: 't2', at: elif),
        RouteStopInput(id: 't5', at: elif),
        RouteStopInput(id: 't3', at: mehmet, urgency: 0.34),
        RouteStopInput(id: 't4', at: fatma, urgency: 0.45),
      ],
      pinFirstId: 't1',
    );
    expect(route.waypoints.first, self);
    expect(route.stops.length, 4, reason: 't2+t5 share a door');
    expect(route.stopTaskIds.contains('t2'), isTrue);
    expect(route.stopTaskIds.contains('t5'), isTrue);
    expect(route.stops.first.taskIds, ['t1']);
    expect(
      [for (final s in route.stops) s.taskIds.first],
      ['t1', 't3', 't2', 't4'],
    );
    expect(route.provider, 'osrm-seed');
    expect(route.estimated, isFalse);
    expect(route.meters, 1472 + 1486 + 1997 + 592);
    expect(route.highlight.length, greaterThan(2));
    expect(route.legFor('t1')?.meters, 1472);
  });

  test('planDayRouteLocal: drops a stop the rider is already standing on', () {
    final route = planDayRouteLocal(ahmet, [
      RouteStopInput(id: 't1', at: ahmet),
      RouteStopInput(id: 't2', at: elif),
    ]);
    expect(route.stops.map((s) => s.taskIds.single), ['t2']);
  });

  test('planDayRouteLocal: pin yokken Mehmet başa gelir (çaprazsız tur)', () {
    final route = planDayRouteLocal(self, [
      RouteStopInput(id: 't1', at: ahmet, urgency: 0.6),
      RouteStopInput(id: 't2', at: elif),
      RouteStopInput(id: 't5', at: elif),
      RouteStopInput(id: 't3', at: mehmet, urgency: 0.34),
      RouteStopInput(id: 't4', at: fatma, urgency: 0.45),
    ]);
    expect(route.stops.first.taskIds, ['t3']);
    expect(route.provider, 'osrm-seed');
    expect(route.estimated, isFalse);
    expect(route.meters, 1435 + 1486 + 1026 + 592);
  });

  test('planDayRoute: pinli Güney kümesi Ahmet tohumunu korur', () async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
            ),
          ),
        ),
      );
    final route = await planDayRoute(
      self,
      [
        RouteStopInput(id: 't1', at: ahmet, urgency: 0.6),
        RouteStopInput(id: 't2', at: elif),
        RouteStopInput(id: 't5', at: elif),
        RouteStopInput(id: 't3', at: mehmet, urgency: 0.34),
        RouteStopInput(id: 't4', at: fatma, urgency: 0.45),
      ],
      pinFirstId: 't1',
      dio: dio,
      timeout: const Duration(milliseconds: 40),
    );
    expect(route.provider, 'osrm-seed');
    expect(route.stops.first.taskIds, ['t1']);
    expect(route.meters, 1472 + 1486 + 1997 + 592);
    expect(route.legFor('t1')?.meters, 1472);
  });

  test('planDayRoute: Güney demo kümesinde ağ düşünce tohum geometri kullanılır', () async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
            ),
          ),
        ),
      );
    final route = await planDayRoute(
      self,
      [
        RouteStopInput(id: 't1', at: ahmet, urgency: 0.6),
        RouteStopInput(id: 't2', at: elif),
        RouteStopInput(id: 't5', at: elif),
        RouteStopInput(id: 't3', at: mehmet, urgency: 0.34),
        RouteStopInput(id: 't4', at: fatma, urgency: 0.45),
      ],
      dio: dio,
      timeout: const Duration(milliseconds: 40),
    );
    expect(route.estimated, isFalse);
    expect(route.provider, 'osrm-seed');
    expect(route.points.length, greaterThan(40));
    expect(route.meters, 1435 + 1486 + 1026 + 592);
    expect(route.stops.first.taskIds, ['t3']);
    expect(route.highlight.length, greaterThan(2));
    expect(lineFitsWaypoints(route.points, route.waypoints), isTrue);
    final toMehmet = route.legFor('t3');
    expect(toMehmet, isNotNull);
    expect(toMehmet!.meters, 1435);
    expect(toMehmet.points.length, greaterThan(5));
    expect(toMehmet.points.first.latitude, closeTo(38.1476, 2e-2));
    expect(route.legFor('t1')?.meters, 1486);
  });

  test('snapAlongRoute: later stop cannot snap behind an earlier one', () {
    final line = [
      self,
      const LatLng(38.1500, 29.0660),
      mehmet,
      ahmet,
      elif,
      fatma,
    ];
    final cuts = snapAlongRoute(line, [self, mehmet, ahmet, elif, fatma]);
    for (var i = 1; i < cuts.length; i++) {
      expect(cuts[i] >= cuts[i - 1], isTrue);
    }
    expect(cuts.last, line.length - 1);
  });

  test('lineFitsWaypoints: rejects a line that misses a middle stop', () {
    const line = [
      LatLng(38.1476, 29.0702),
      LatLng(38.1512, 29.0614),
      LatLng(38.1460, 29.0488),
    ];
    expect(lineFitsWaypoints(line, [self, ahmet, fatma]), isTrue);
    expect(lineFitsWaypoints(line, [self, mehmet, fatma]), isFalse);
  });

  test('decodePolyline: precision 6 is a stricter scale than 5', () {
    // Same encoded bytes decoded at 5 vs 6 must not match — a precision
    // mix-up is exactly how a road line detaches from the basemap.
    const sample = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';
    final p5 = decodePolyline(sample, precision: 5);
    final p6 = decodePolyline(sample, precision: 6);
    expect(p5, isNot(p6));
    expect(p5.first.latitude, closeTo(38.5, 1e-4));
  });
}
