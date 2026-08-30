/// Optional Mapbox styled tiles for a dark, branded map. Falls back to the
/// free OpenStreetMap raster tiles when no token is configured. Pass at
/// build/run time with `--dart-define=MAPBOX_TOKEN=pk.xxxxx` (a Mapbox
/// account's default public token — see mapbox.com, free tier).
///
/// This only changes what the map *looks like*. Routing (distance/duration/
/// stop-order) is unaffected — that's still our own self-hosted OSRM
/// (apps/api/src/services/routing.ts), regardless of tile source.
const kMapboxToken = String.fromEnvironment('MAPBOX_TOKEN', defaultValue: '');

const kMapboxStyleId = 'light-v11';

bool get useMapboxTiles => kMapboxToken.isNotEmpty;

String get mapTileUrlTemplate => useMapboxTiles
    ? 'https://api.mapbox.com/styles/v1/mapbox/$kMapboxStyleId/tiles/512/{z}/{x}/{y}@2x?access_token=$kMapboxToken'
    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
