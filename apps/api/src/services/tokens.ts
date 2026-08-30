import { createHash, randomUUID } from 'node:crypto';

import { AppError } from '@dijigoo/core';
import { devices, sessions } from '@dijigoo/db';
import type { Database } from '@dijigoo/db';
import { and, eq, isNull } from 'drizzle-orm';
import { SignJWT, jwtVerify } from 'jose';

import type { Env } from '../env.js';

export interface AccessClaims {
  sub: string;
  /** Bound device. A token minted for one handset is useless on another. */
  did: string;
  iid: string;
  tid: string;
  /** Session family; revoking the family invalidates the access token too. */
  fam: string;
}

export interface IssuedTokens {
  accessToken: string;
  accessTokenExpiresAt: Date;
  refreshToken: string;
  refreshTokenExpiresAt: Date;
}

function sha256(value: string): string {
  return createHash('sha256').update(value).digest('hex');
}

export class TokenService {
  private readonly accessKey: Uint8Array;
  private readonly refreshKey: Uint8Array;

  constructor(
    private readonly db: Database,
    private readonly env: Env,
  ) {
    this.accessKey = new TextEncoder().encode(env.JWT_ACCESS_SECRET);
    this.refreshKey = new TextEncoder().encode(env.JWT_REFRESH_SECRET);
  }

  async issue(params: {
    courierId: string;
    deviceId: string;
    installationId: string;
    tenantId: string;
    familyId?: string;
    parentSessionId?: string;
    ip?: string;
    userAgent?: string;
  }): Promise<IssuedTokens> {
    const familyId = params.familyId ?? randomUUID();
    const now = Date.now();
    const accessExpiresAt = new Date(now + this.env.JWT_ACCESS_TTL * 1000);
    const refreshExpiresAt = new Date(now + this.env.JWT_REFRESH_TTL * 1000);

    const claims: AccessClaims = {
      sub: params.courierId,
      did: params.deviceId,
      iid: params.installationId,
      tid: params.tenantId,
      fam: familyId,
    };

    const accessToken = await new SignJWT({ ...claims })
      .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
      .setIssuer(this.env.JWT_ISSUER)
      .setIssuedAt()
      .setExpirationTime(Math.floor(accessExpiresAt.getTime() / 1000))
      .setJti(randomUUID())
      .sign(this.accessKey);

    const refreshJti = randomUUID();
    const refreshToken = await new SignJWT({ sub: params.courierId, fam: familyId })
      .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
      .setIssuer(this.env.JWT_ISSUER)
      .setIssuedAt()
      .setExpirationTime(Math.floor(refreshExpiresAt.getTime() / 1000))
      .setJti(refreshJti)
      .sign(this.refreshKey);

    await this.db.insert(sessions).values({
      courierId: params.courierId,
      deviceId: params.deviceId,
      familyId,
      refreshTokenHash: sha256(refreshToken),
      parentId: params.parentSessionId ?? null,
      expiresAt: refreshExpiresAt,
      ip: params.ip ?? null,
      userAgent: params.userAgent ?? null,
    });

    return {
      accessToken,
      accessTokenExpiresAt: accessExpiresAt,
      refreshToken,
      refreshTokenExpiresAt: refreshExpiresAt,
    };
  }

  async verifyAccess(token: string): Promise<AccessClaims> {
    try {
      const { payload } = await jwtVerify(token, this.accessKey, {
        issuer: this.env.JWT_ISSUER,
      });
      return payload as unknown as AccessClaims;
    } catch (error) {
      const expired =
        error instanceof Error && error.name === 'JWTExpired';
      throw new AppError(expired ? 'TOKEN_EXPIRED' : 'UNAUTHENTICATED', { cause: error });
    }
  }

  /**
   * Single-use rotation. Presenting a refresh token that was already spent is
   * the signature of a stolen token being replayed, so the entire family is
   * revoked rather than just the one row: the attacker and the real courier
   * both get logged out and the courier re-activates.
   */
  async rotate(params: {
    refreshToken: string;
    installationId: string;
    ip?: string;
    userAgent?: string;
  }): Promise<{ tokens: IssuedTokens; familyRevoked: boolean }> {
    let payload: { sub?: string; fam?: string };
    try {
      const verified = await jwtVerify(params.refreshToken, this.refreshKey, {
        issuer: this.env.JWT_ISSUER,
      });
      payload = verified.payload as { sub?: string; fam?: string };
    } catch (error) {
      throw new AppError('TOKEN_EXPIRED', { cause: error });
    }

    const hash = sha256(params.refreshToken);
    const [session] = await this.db
      .select()
      .from(sessions)
      .where(eq(sessions.refreshTokenHash, hash))
      .limit(1);

    if (!session) throw new AppError('TOKEN_REVOKED');

    if (session.revokedAt) throw new AppError('TOKEN_REVOKED');

    if (session.usedAt) {
      await this.revokeFamily(session.familyId, 'refresh_token_replay');
      throw new AppError('TOKEN_REVOKED', {
        message: 'Oturum guvenlik nedeniyle sonlandirildi, yeniden giris yapin.',
        userVisible: true,
      });
    }

    if (session.expiresAt.getTime() < Date.now()) throw new AppError('TOKEN_EXPIRED');

    const [device] = await this.db
      .select()
      .from(devices)
      .where(and(eq(devices.id, session.deviceId), isNull(devices.revokedAt)))
      .limit(1);

    if (!device) throw new AppError('DEVICE_NOT_BOUND');
    if (device.installationId !== params.installationId) {
      // The token is valid but arrived from a different handset.
      await this.revokeFamily(session.familyId, 'installation_mismatch');
      throw new AppError('DEVICE_NOT_BOUND');
    }

    await this.db
      .update(sessions)
      .set({ usedAt: new Date() })
      .where(eq(sessions.id, session.id));

    const tokens = await this.issue({
      courierId: session.courierId,
      deviceId: session.deviceId,
      installationId: params.installationId,
      tenantId: payload.fam ? await this.tenantOf(session.courierId) : await this.tenantOf(session.courierId),
      familyId: session.familyId,
      parentSessionId: session.id,
      ip: params.ip,
      userAgent: params.userAgent,
    });

    return { tokens, familyRevoked: false };
  }

  async revokeFamily(familyId: string, reason: string): Promise<void> {
    await this.db
      .update(sessions)
      .set({ revokedAt: new Date(), revokedReason: reason })
      .where(and(eq(sessions.familyId, familyId), isNull(sessions.revokedAt)));
  }

  async revokeAllForCourier(courierId: string, reason: string): Promise<void> {
    await this.db
      .update(sessions)
      .set({ revokedAt: new Date(), revokedReason: reason })
      .where(and(eq(sessions.courierId, courierId), isNull(sessions.revokedAt)));
  }

  /** Access tokens carry the family id so revocation reaches them too. */
  async isFamilyLive(familyId: string): Promise<boolean> {
    const [row] = await this.db
      .select({ id: sessions.id })
      .from(sessions)
      .where(and(eq(sessions.familyId, familyId), isNull(sessions.revokedAt)))
      .limit(1);
    return Boolean(row);
  }

  private async tenantOf(courierId: string): Promise<string> {
    const rows = await this.db.query.couriers.findFirst({
      where: (c, { eq: equals }) => equals(c.id, courierId),
      columns: { tenantId: true },
    });
    if (!rows) throw new AppError('NOT_FOUND');
    return rows.tenantId;
  }
}
