import 'package:dijigoo_kurye/geo.dart';
import 'package:dijigoo_kurye/l10n.dart';
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
    expect(const RoadLeg(polyline: 'x', meters: 80, seconds: 20).minutes, 1);
    expect(const RoadLeg(polyline: 'x', meters: 4500, seconds: 360).minutes, 6);
  });

  test('planDayRoute: motor 404 olunca yerel sırayı korur', () async {
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
      const LatLng(38.1476, 29.0702),
      [
        const RouteStopInput(
          id: 'a',
          at: LatLng(38.1512, 29.0614),
          urgency: 0.6,
        ),
        const RouteStopInput(id: 'b', at: LatLng(38.1481, 29.0558)),
      ],
      dio: dio,
      timeout: const Duration(milliseconds: 40),
    );
    expect(route.estimated, isTrue);
    expect(route.stops, isNotEmpty);
    expect(route.waypoints.first.latitude, closeTo(38.1476, 1e-6));
  });

  test('durak yürüme mesafesindeyse araç turu yerine düz çizgi', () {
    const origin = LatLng(39.9105, 32.8585);
    const stop = LatLng(39.9100, 32.8590);
    // Tek yönlü sokaklar: 70 m ötedeki durağa 693 m araç rotası.
    final day = DayRoute(
      points: const [origin, LatLng(39.9120, 32.8600), stop],
      meters: 693,
      seconds: 90,
      estimated: false,
      provider: 'osrm',
      stops: const [
        DayStop(taskIds: ['a'], at: stop, meters: 693, seconds: 90),
      ],
      waypoints: const [origin, stop],
    );
    final leg = day.legFor('a')!;
    expect(leg.walking, isTrue);
    expect(leg.points, [origin, stop]);
    expect(leg.meters, inInclusiveRange(60, 80));
    expect(leg.estimated, isFalse);
  });

  test('bacaklar ayrı çekildiyse durak çizgisi tam yerinden kesilir', () {
    const o = LatLng(39.90, 32.80);
    const a = LatLng(39.91, 32.81);
    const b = LatLng(39.92, 32.80);
    // İkinci bacak ilk durağın yanından geri geçer; tahminle kesim şaşardı.
    const pts = [
      o,
      LatLng(39.905, 32.805),
      a,
      LatLng(39.905, 32.806),
      LatLng(39.915, 32.803),
      b,
    ];
    final day = DayRoute(
      points: pts,
      meters: 4000,
      seconds: 600,
      estimated: false,
      provider: 'osrm-legs',
      stops: const [
        DayStop(taskIds: ['a'], at: a, meters: 1500, seconds: 200),
        DayStop(taskIds: ['b'], at: b, meters: 2500, seconds: 400),
      ],
      waypoints: const [o, a, b],
      legCuts: const [0, 2, 5],
    );
    expect(day.legFor('a')!.points, pts.sublist(0, 3));
    expect(day.legFor('b')!.points, pts.sublist(2, 6));
    expect(day.legFor('b')!.walking, isFalse);
  });

  test('mesafe etiketi: 1 km altı metre, yürümede süre yok', () {
    const l = L10n('tr');
    expect(l.travelLabel(68, 1, walking: true), '70 m · yürüyerek');
    expect(l.travelLabel(640, 2), '640 m · 2 dk');
    expect(l.travelLabel(1540, 4), '1.5 km · 4 dk');
    expect(l.travelLabel(12400, 21), '12 km · 21 dk');
    expect(l.travelLabel(900, null), '900 m');
  });

  test(
    'planDayRoute: yakın ilk durakta dolanan bacak düz çizgi olur',
    () async {
      const origin = LatLng(39.9105, 32.8585);
      const near = LatLng(39.9100, 32.8590);
      const far = LatLng(39.9040, 32.8590);
      const loop = [
        origin,
        LatLng(39.9120, 32.8585),
        LatLng(39.9120, 32.8600),
        near,
      ];
      const onward = [near, LatLng(39.9070, 32.8592), far];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final first = options.uri.path.contains('32.858500,39.910500;');
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'code': 'Ok',
                    'routes': [
                      {
                        'geometry': encodePolyline(
                          first ? loop : onward,
                          precision: 6,
                        ),
                        'distance': first ? 693 : 700,
                        'duration': first ? 90 : 120,
                        'legs': [
                          {
                            'distance': first ? 693 : 700,
                            'duration': first ? 90 : 120,
                          },
                        ],
                      },
                    ],
                  },
                ),
              );
            },
          ),
        );
      final route = await planDayRoute(origin, const [
        RouteStopInput(id: 'a', at: near),
        RouteStopInput(id: 'b', at: far),
      ], dio: dio);

      expect(route.estimated, isFalse);
      expect(route.stops.first.walking, isTrue);
      expect(route.stops.first.meters, inInclusiveRange(60, 80));
      expect(route.highlight, [origin, near]);
      // Dolanan köşeler çizgiden çıktı; kalan bacak aynen duruyor.
      expect(route.points.first, origin);
      expect(route.points[1], near);
      expect(route.points.length, 2 + onward.length - 1);
      expect(route.meters, inInclusiveRange(760, 780));
      final legB = route.legFor('b')!;
      expect(legB.walking, isFalse);
      expect(legB.points.length, onward.length);
      expect(route.legFor('a')!.walking, isTrue);
    },
  );
}
