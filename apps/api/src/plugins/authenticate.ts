import { AppError } from '@dijigoo/core';
import { couriers, devices } from '@dijigoo/db';
import { and, eq, isNull } from 'drizzle-orm';
import type { FastifyInstance, FastifyRequest } from 'fastify';
import fp from 'fastify-plugin';

import type { AppContext } from '../context.js';

export interface AuthenticatedCourier {
  courierId: string;
  tenantId: string;
  deviceId: string;
  installationId: string;
  familyId: string;
  capabilities: string[];
  /** Set when the last integrity check asked for reduced privileges. */
  restricted: boolean;
}

declare module 'fastify' {
  interface FastifyRequest {
    courier?: AuthenticatedCourier;
  }
  interface FastifyInstance {
    authenticate: (request: FastifyRequest) => Promise<AuthenticatedCourier>;
  }
}

const CLIENT_INFO = /^dijigoo-courier\/(\d+\.\d+\.\d+) \((android|ios); build (\d+)\)$/;

export const authenticate = fp(async (app: FastifyInstance, opts: { ctx: AppContext }) => {
  const { ctx } = opts;

  app.decorate('authenticate', async (request: FastifyRequest): Promise<AuthenticatedCourier> => {
    if (request.courier) return request.courier;

    // Gate old builds before anything else. A client that cannot render a step
    // type must be told to update, not allowed to skip it.
    const clientInfo = request.headers['x-client-info'];
    if (typeof clientInfo === 'string') {
      const match = CLIENT_INFO.exec(clientInfo);
      if (match && Number(match[3]) < ctx.env.MIN_SUPPORTED_APP_BUILD) {
        throw new AppError('UNSUPPORTED_CLIENT_VERSION', {
          details: [
            {
              field: 'x-client-info',
              issue: 'build_too_old',
              meta: { minimum: ctx.env.MIN_SUPPORTED_APP_BUILD, provided: Number(match[3]) },
            },
          ],
        });
      }
    }

    const header = request.headers.authorization;
    if (!header?.startsWith('Bearer ')) throw new AppError('UNAUTHENTICATED');

    const claims = await ctx.tokens.verifyAccess(header.slice(7));

    // Revocation must reach access tokens too, not just refresh tokens, or a
    // stolen handset stays usable for the remaining 15 minutes.
    if (!(await ctx.tokens.isFamilyLive(claims.fam))) {
      throw new AppError('TOKEN_REVOKED');
    }

    const [row] = await ctx.db
      .select({
        courierId: couriers.id,
        tenantId: couriers.tenantId,
        status: couriers.status,
        capabilities: couriers.capabilities,
        deviceId: devices.id,
        installationId: devices.installationId,
        integrityAction: devices.integrityAction,
      })
      .from(couriers)
      .innerJoin(devices, eq(devices.courierId, couriers.id))
      .where(
        and(
          eq(couriers.id, claims.sub),
          eq(devices.id, claims.did),
          isNull(devices.revokedAt),
          isNull(couriers.deletedAt),
        ),
      )
      .limit(1);

    if (!row) throw new AppError('DEVICE_NOT_BOUND');
    if (row.status !== 'active') {
      throw new AppError('FORBIDDEN', {
        message: 'Hesabiniz askiya alinmis. Yoneticinizle gorusun.',
        userVisible: true,
      });
    }
    if (row.installationId !== claims.iid) throw new AppError('DEVICE_NOT_BOUND');

    const courier: AuthenticatedCourier = {
      courierId: row.courierId,
      tenantId: row.tenantId,
      deviceId: row.deviceId,
      installationId: row.installationId,
      familyId: claims.fam,
      capabilities: row.capabilities,
      restricted: row.integrityAction === 'restrict' || row.integrityAction === 'review',
    };

    request.courier = courier;

    // Fire and forget: a failed heartbeat must not fail the request.
    void ctx.db
      .update(devices)
      .set({ lastSeenAt: new Date() })
      .where(eq(devices.id, row.deviceId))
      .catch((error: unknown) => request.log.warn({ err: error }, 'lastSeenAt guncellenemedi'));

    return courier;
  });
});

/** Convenience for routes: throws unless the courier holds the capability. */
export function requireCapability(courier: AuthenticatedCourier, capability: string): void {
  if (!courier.capabilities.includes(capability)) {
    throw new AppError('FORBIDDEN', {
      details: [{ field: 'capability', issue: 'missing', meta: { capability } }],
    });
  }
}
