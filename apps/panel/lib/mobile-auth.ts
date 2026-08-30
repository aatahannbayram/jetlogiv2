import { jwtVerify } from 'jose';
import { NextResponse } from 'next/server';

function problem(code: string, message: string, status: number) {
  return NextResponse.json(
    { error: { code, message, userVisible: false } },
    { status },
  );
}

/**
 * Phone JWT only. Incoming `Cookie` is ignored and must never be forwarded
 * to the onboarding origin.
 */
export async function readMobileAuth(
  request: Request,
): Promise<{ ok: true; courierId?: string } | { ok: false; response: NextResponse }> {
  const header = request.headers.get('authorization');
  if (!header?.startsWith('Bearer ')) {
    return { ok: false, response: problem('UNAUTHENTICATED', 'Bearer token gerekli', 401) };
  }

  const secret = process.env.JWT_ACCESS_SECRET;
  if (!secret) {
    return { ok: true };
  }

  try {
    const { payload } = await jwtVerify(header.slice(7), new TextEncoder().encode(secret), {
      issuer: process.env.JWT_ISSUER ?? 'dijigoo-api',
    });
    return { ok: true, courierId: typeof payload.sub === 'string' ? payload.sub : undefined };
  } catch {
    return { ok: false, response: problem('TOKEN_EXPIRED', 'Oturum suresi doldu', 401) };
  }
}
