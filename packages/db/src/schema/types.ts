import { customType } from 'drizzle-orm/pg-core';

export interface Point {
  lat: number;
  lng: number;
}

/**
 * PostGIS point, WGS84.
 *
 * Stored as `geometry` rather than `geography` because drizzle-kit only knows
 * how to emit the former, and because geometry is the cheaper type to index.
 * Every distance question here is in metres, so proximity queries cast at the
 * call site — `ST_DWithin(position::geography, $1::geography, radius)` — and
 * `sql/99-post.sql` creates matching geography expression indexes so that cast
 * still uses an index instead of a sequential scan.
 */
export const geoPoint = customType<{
  data: Point;
  driverData: string;
  config: never;
}>({
  dataType() {
    return 'geometry(point,4326)';
  },
  toDriver(value: Point) {
    return `SRID=4326;POINT(${value.lng} ${value.lat})`;
  },
  fromDriver(value: string): Point {
    // A plain `select position` returns EWKB hex, which is what PostGIS sends
    // on the wire. GeoJSON and EWKT only appear when a query wrapped the column
    // in ST_AsGeoJSON or ST_AsText, so all three have to be accepted.
    if (value.startsWith('{')) {
      const parsed = JSON.parse(value) as { coordinates: [number, number] };
      return { lng: parsed.coordinates[0], lat: parsed.coordinates[1] };
    }
    if (/^[0-9A-Fa-f]+$/.test(value)) return decodeEwkbPoint(value);

    const match = /POINT\(([-\d.]+) ([-\d.]+)\)/.exec(value);
    if (!match) throw new Error(`Cozulemeyen nokta: ${value}`);
    return { lng: Number(match[1]), lat: Number(match[2]) };
  },
});

/**
 * Minimal EWKB reader: byte order, type word with the SRID flag, optional SRID,
 * then two doubles. Only 2D points are stored in this schema, so anything else
 * is a schema mistake worth failing loudly on rather than silently truncating.
 */
function decodeEwkbPoint(hex: string): Point {
  const buffer = Buffer.from(hex, 'hex');
  const littleEndian = buffer.readUInt8(0) === 1;
  const type = littleEndian ? buffer.readUInt32LE(1) : buffer.readUInt32BE(1);

  const hasSrid = (type & 0x20000000) !== 0;
  const geometryType = type & 0xff;
  if (geometryType !== 1) throw new Error(`Nokta bekleniyordu, gelen geometri tipi: ${geometryType}`);

  const offset = hasSrid ? 9 : 5;
  const lng = littleEndian ? buffer.readDoubleLE(offset) : buffer.readDoubleBE(offset);
  const lat = littleEndian ? buffer.readDoubleLE(offset + 8) : buffer.readDoubleBE(offset + 8);
  return { lat, lng };
}

/**
 * Monetary amounts. `numeric(12,2)` mapped to string on purpose: floats lose
 * kurus, and cash-on-delivery reconciliation is one place that cannot tolerate
 * a rounding drift.
 */
export const money = customType<{ data: string; driverData: string }>({
  dataType() {
    return 'numeric(12, 2)';
  },
});

/** Citext for case-insensitive natural keys such as barcodes and references. */
export const citext = customType<{ data: string; driverData: string }>({
  dataType() {
    return 'citext';
  },
});
