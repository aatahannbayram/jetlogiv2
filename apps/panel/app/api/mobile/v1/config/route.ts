import { AppConfig } from '@dijigoo/contracts';
import { NextResponse } from 'next/server';

export async function GET() {
  const min = Number(process.env.MIN_SUPPORTED_APP_BUILD ?? '1') || 1;
  const body = AppConfig.parse({
    environment: process.env.NODE_ENV === 'production' ? 'production' : 'demo',
    minAndroidBuild: min,
    minIosBuild: min,
    forceUpdate: false,
    storeUrlAndroid: null,
    storeUrlIos: null,
    supportPhone: '+902124440026',
    opsPhone: '+902124440026',
    geofenceDefaultRadiusMeters: 200,
    geofenceMaxAccuracyMeters: 100,
    featureFlags: {
      maskedCall: false,
      cashCollect: true,
      documentScan: false,
      custody: false,
      shiftFaceMatch: false,
      offlineSync: true,
    },
    publishedAt: new Date().toISOString(),
  });
  return NextResponse.json(body);
}
