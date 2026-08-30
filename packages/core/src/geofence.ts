import type { GeoPoint } from '@dijigoo/contracts';

const EARTH_RADIUS_METERS = 6_371_008.8;

export interface LatLng {
  lat: number;
  lng: number;
}

/** Great-circle distance in metres. Accurate enough at delivery scale. */
export function distanceMeters(a: LatLng, b: LatLng): number {
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);

  const h =
    Math.sin(dLat / 2) ** 2 + Math.sin(dLng / 2) ** 2 * Math.cos(lat1) * Math.cos(lat2);

  return 2 * EARTH_RADIUS_METERS * Math.asin(Math.min(1, Math.sqrt(h)));
}

export type GeofenceOutcome =
  | { result: 'inside'; distance: number }
  | { result: 'outside'; distance: number; shortfall: number }
  | { result: 'inconclusive'; reason: 'no_fix' | 'accuracy_too_poor' | 'fix_too_old'; distance?: number };

export interface GeofenceCheckInput {
  target: LatLng;
  fix: GeoPoint | null | undefined;
  radiusMeters: number;
  maxAccuracyMeters: number;
  /** Fixes older than this are treated as no fix at all. */
  maxFixAgeSeconds?: number;
  now?: Date;
}

/**
 * Deliberately three-valued. A fix that is too imprecise to judge is not the
 * same as a fix that proves the courier is elsewhere: the first must let the
 * courier proceed with a reason, the second must not.
 *
 * The accuracy radius is subtracted from the distance before comparing, so a
 * courier standing at the door with a 90 m error circle still passes a 150 m
 * fence instead of being blocked by GPS noise.
 */
export function checkGeofence(input: GeofenceCheckInput): GeofenceOutcome {
  const { target, fix, radiusMeters, maxAccuracyMeters } = input;

  if (!fix) return { result: 'inconclusive', reason: 'no_fix' };

  if (fix.accuracy > maxAccuracyMeters) {
    return {
      result: 'inconclusive',
      reason: 'accuracy_too_poor',
      distance: distanceMeters(target, fix),
    };
  }

  const maxAge = input.maxFixAgeSeconds ?? 180;
  const now = input.now ?? new Date();
  const ageSeconds = (now.getTime() - new Date(fix.capturedAt).getTime()) / 1000;
  if (ageSeconds > maxAge) {
    return { result: 'inconclusive', reason: 'fix_too_old', distance: distanceMeters(target, fix) };
  }

  const distance = distanceMeters(target, fix);
  const effective = Math.max(0, distance - fix.accuracy);

  return effective <= radiusMeters
    ? { result: 'inside', distance }
    : { result: 'outside', distance, shortfall: effective - radiusMeters };
}
