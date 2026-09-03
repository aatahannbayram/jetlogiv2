import 'theme.dart';

/// Optional Mapbox styled tiles, matching [Dg.dark] (dark-v11/light-v11).
/// Falls back to CartoDB's free basemap tiles when no token is configured —
/// also theme-matched (dark_all/light_all). Pass a Mapbox token at
/// build/run time with `--dart-define=MAPBOX_TOKEN=pk.xxxxx` (a Mapbox
/// account's default public token — see mapbox.com, free tier).
///
/// CartoDB (not raw `tile.openstreetmap.org`) is the fallback because OSM's
/// own tile server is dev/low-volume only per their tile usage policy, not
/// meant for a shipping app — Carto's basemaps are free for reasonable use
/// with attribution, see [MapStrip]'s [RichAttributionWidget].
///
/// This only changes what the map *looks like*. Routing (distance/duration/
/// stop-order) is unaffected — that's still our own self-hosted OSRM
/// (apps/api/src/services/routing.ts), regardless of tile source.
const kMapboxToken = String.fromEnvironment('MAPBOX_TOKEN', defaultValue: '');

bool get useMapboxTiles => kMapboxToken.isNotEmpty;

String get _mapboxStyleId => Dg.dark ? 'dark-v11' : 'light-v11';
String get _cartoStyleSlug => Dg.dark ? 'dark_all' : 'light_all';

String get mapTileUrlTemplate => useMapboxTiles
    ? 'https://api.mapbox.com/styles/v1/mapbox/$_mapboxStyleId/tiles/512/{z}/{x}/{y}@2x?access_token=$kMapboxToken'
    : 'https://{s}.basemaps.cartocdn.com/$_cartoStyleSlug/{z}/{x}/{y}{r}.png';
