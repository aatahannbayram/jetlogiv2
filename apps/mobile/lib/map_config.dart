/// Optional Mapbox styled tiles — always the light style, deliberately not
/// matched to [Dg.dark]: a light map reads as a clear, legible map surface
/// against the app's dark cards, where the dark tile style read as muddy and
/// low-contrast against the pin markers/overlay pills. Falls back to Esri's
/// free (no-key) World Street Map tiles when no token is configured. Pass a
/// Mapbox token at build/run time with `--dart-define=MAPBOX_TOKEN=pk.xxxxx`
/// (a Mapbox account's default public token — see mapbox.com, free tier).
///
/// CartoDB's `basemaps.cartocdn.com` used to be the free fallback here, but
/// they locked anonymous access behind a required API key (every tile now
/// comes back as a "API KEY REQUIRED" watermark, HTTP 200 — flutter_map has
/// no way to detect that as an error). Esri's ArcGIS Online basemaps
/// (`server.arcgisonline.com`) are free for reasonable use without any key
/// and don't have this problem — see [MapStrip]'s [RichAttributionWidget]
/// for the matching attribution.
///
/// This only changes what the map *looks like*. Routing (distance/duration/
/// stop-order) is unaffected — that's still our own self-hosted OSRM
/// (apps/api/src/services/routing.ts), regardless of tile source.
const kMapboxToken = String.fromEnvironment('MAPBOX_TOKEN', defaultValue: '');

bool get useMapboxTiles => kMapboxToken.isNotEmpty;

const _mapboxStyleId = 'light-v11';
const _esriService = 'World_Street_Map';

String get mapTileUrlTemplate => useMapboxTiles
    ? 'https://api.mapbox.com/styles/v1/mapbox/$_mapboxStyleId/tiles/512/{z}/{x}/{y}@2x?access_token=$kMapboxToken'
    : 'https://server.arcgisonline.com/ArcGIS/rest/services/$_esriService/MapServer/tile/{z}/{y}/{x}';
