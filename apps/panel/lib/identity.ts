import {
  fallbackAvailability,
  fallbackDocuments,
  mapPanelAvailability,
  mapPanelDocuments,
  pullPanelJson,
} from '@dijigoo/core';
import { NextResponse } from 'next/server';

import { readMobileAuth } from './mobile-auth';

type IdentityKind = 'availability' | 'documents';

/**
 * Server-to-server identity. The browser cookie `dijigoo_courier_session`
 * is not read and is not sent upstream.
 */
export async function identityResponse(request: Request, kind: IdentityKind) {
  const auth = await readMobileAuth(request);
  if (!auth.ok) return auth.response;

  const origin = process.env.IDENTITY_UPSTREAM;
  if (!origin) {
    return NextResponse.json(kind === 'availability' ? fallbackAvailability() : fallbackDocuments());
  }

  const raw = await pullPanelJson({
    origin,
    path: kind === 'availability' ? '/api/public/v1/courier-availability' : '/api/public/v1/courier-my-documents',
    courierId: auth.courierId,
    token: process.env.IDENTITY_INTERNAL_TOKEN,
  });

  if (kind === 'availability') {
    return NextResponse.json(raw ? mapPanelAvailability(raw) : fallbackAvailability());
  }
  return NextResponse.json(raw ? mapPanelDocuments(raw) : fallbackDocuments());
}
