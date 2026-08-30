import {
  ActivationStartRequest,
  ActivationStartResponse,
  ActivationVerifyRequest,
  ActivationVerifyResponse,
  CourierProfile,
  ErrorResponse,
  LogoutRequest,
  type Platform,
  PushTokenRequest,
  RefreshRequest,
  RefreshResponse,
} from '@dijigoo/contracts';
import { AppError } from '@dijigoo/core';
import { couriers, devices } from '@dijigoo/db';
import { and, eq, isNull } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { z } from 'zod';

import type { AppContext } from '../context.js';
import { emitEvent } from '../services/outbox.js';

const problem = { 400: ErrorResponse, 401: ErrorResponse, 429: ErrorResponse };

type RequiredPermissions = z.infer<typeof ActivationVerifyResponse>['requiredPermissions'];

export async function authRoutes(app: FastifyInstance, { ctx }: { ctx: AppContext }) {
  const route = app.withTypeProvider<ZodTypeProvider>();

  /**
   * Deliberately does not reveal whether the number belongs to a courier.
   * Returning 404 for unknown numbers would turn this endpoint into a roster
   * enumeration tool, so an unknown number gets the same shaped response and
   * simply never receives an SMS.
   */
  route.post(
    '/v1/auth/activation/start',
    {
      schema: {
        tags: ['Auth'],
        body: ActivationStartRequest,
        response: { 200: ActivationStartResponse, ...problem },
      },
      config: { rateLimit: { max: 5, timeWindow: '10 minutes' } },
    },
    async (request) => {
      const { phone, device } = request.body;

      const [courier] = await ctx.db
        .select({ id: couriers.id, status: couriers.status })
        .from(couriers)
        .where(and(eq(couriers.phone, phone), isNull(couriers.deletedAt)))
        .limit(1);

      if (!courier || courier.status !== 'active') {
        request.log.info({ phone: mask(phone) }, 'Bilinmeyen numara icin aktivasyon istegi');
        return decoyChallenge();
      }

      const challenge = await ctx.otp.issue({
        purpose: 'activation',
        phone,
        courierId: courier.id,
      });

      request.log.info(
        { courierId: courier.id, platform: device.platform, build: device.appBuild },
        'Aktivasyon kodu gonderildi',
      );

      return {
        challengeId: challenge.challengeId,
        codeLength: challenge.codeLength,
        expiresAt: challenge.expiresAt.toISOString(),
        resendAvailableAt: challenge.resendAvailableAt.toISOString(),
        attemptsRemaining: challenge.attemptsRemaining,
        integrityNonce: challenge.integrityNonce,
      };
    },
  );

  route.post(
    '/v1/auth/activation/verify',
    {
      schema: {
        tags: ['Auth'],
        body: ActivationVerifyRequest,
        response: { 200: ActivationVerifyResponse, ...problem },
      },
      config: { rateLimit: { max: 10, timeWindow: '10 minutes' } },
    },
    async (request) => {
      const { challengeId, code, device, integrity } = request.body;

      const verification = await ctx.otp.verify({ challengeId, code });
      if (!verification.courierId) throw new AppError('OTP_INVALID');

      const courier = await ctx.db.query.couriers.findFirst({
        where: (c, { eq: equals }) => equals(c.id, verification.courierId!),
        with: { branch: { columns: { name: true } } },
      });
      if (!courier) throw new AppError('NOT_FOUND');

      const challenge = await ctx.db.query.otpChallenges.findFirst({
        where: (o, { eq: equals }) => equals(o.id, challengeId),
        columns: { integrityNonce: true },
      });

      const verdict = await ctx.integrity.evaluate({
        assertion: integrity,
        expectedNonce: challenge?.integrityNonce ?? null,
        platform: device.platform,
      });

      const result = await ctx.db.transaction(async (tx) => {
        // Re-activating on a new handset revokes the old binding. One live
        // device per courier is a hard rule: two bound phones would report two
        // locations for one person.
        await tx
          .update(devices)
          .set({ revokedAt: new Date(), revokedReason: 'rebound_to_new_device' })
          .where(and(eq(devices.courierId, courier.id), isNull(devices.revokedAt)));

        const [bound] = await tx
          .insert(devices)
          .values({
            courierId: courier.id,
            installationId: device.installationId,
            platform: device.platform,
            osVersion: device.osVersion,
            model: device.model,
            manufacturer: device.manufacturer,
            appVersion: device.appVersion,
            appBuild: device.appBuild,
            batteryOptimizationExempt: device.batteryOptimizationExempt ?? null,
            integrityScore: verdict.score,
            integrityAction: verdict.action,
            integritySignals: verdict.signals,
            integrityCheckedAt: new Date(),
            lastSeenAt: new Date(),
          })
          .onConflictDoUpdate({
            target: devices.installationId,
            set: {
              courierId: courier.id,
              appVersion: device.appVersion,
              appBuild: device.appBuild,
              osVersion: device.osVersion,
              integrityScore: verdict.score,
              integrityAction: verdict.action,
              integritySignals: verdict.signals,
              integrityCheckedAt: new Date(),
              revokedAt: null,
              revokedReason: null,
              boundAt: new Date(),
              lastSeenAt: new Date(),
            },
          })
          .returning({ id: devices.id });

        await emitEvent(tx, {
          key: 'courier.device_bound',
          tenantId: courier.tenantId,
          subjectType: 'courier',
          subjectId: courier.id,
          actorType: 'courier',
          actorId: courier.id,
          correlationId: request.id,
          occurredAt: new Date(),
          data: {
            deviceId: bound!.id,
            platform: device.platform,
            model: device.model,
            appBuild: device.appBuild,
          },
        });

        if (verdict.action !== 'allow') {
          await emitEvent(tx, {
            key: 'courier.device_integrity_flagged',
            tenantId: courier.tenantId,
            subjectType: 'courier',
            subjectId: courier.id,
            actorType: 'system',
            correlationId: request.id,
            occurredAt: new Date(),
            data: { score: verdict.score, signals: verdict.signals, action: verdict.action },
          });
        }

        return bound!;
      });

      // Any session from a previous binding is dead the moment a new device
      // takes over.
      await ctx.tokens.revokeAllForCourier(courier.id, 'rebound_to_new_device');

      const tokens = await ctx.tokens.issue({
        courierId: courier.id,
        deviceId: result.id,
        installationId: device.installationId,
        tenantId: courier.tenantId,
        ip: request.ip,
        userAgent: request.headers['user-agent'],
      });

      return {
        tokens: serializeTokens(tokens),
        courier: toProfile(courier),
        integrity: verdict,
        requiredPermissions: requiredPermissionsFor(device.platform),
      };
    },
  );

  route.post(
    '/v1/auth/token/refresh',
    {
      schema: {
        tags: ['Auth'],
        body: RefreshRequest,
        response: { 200: RefreshResponse, ...problem },
      },
      config: { rateLimit: { max: 30, timeWindow: '1 minute' } },
    },
    async (request) => {
      const { tokens, familyRevoked } = await ctx.tokens.rotate({
        refreshToken: request.body.refreshToken,
        installationId: request.body.installationId,
        ip: request.ip,
        userAgent: request.headers['user-agent'],
      });

      return { tokens: serializeTokens(tokens), familyRevoked };
    },
  );

  route.post(
    '/v1/auth/logout',
    {
      schema: {
        tags: ['Auth'],
        body: LogoutRequest,
        response: { 204: z.null(), ...problem },
      },
    },
    async (request, reply) => {
      const courier = await app.authenticate(request);

      if (request.body.allDevices) {
        await ctx.tokens.revokeAllForCourier(courier.courierId, 'user_logout_all');
        await ctx.db
          .update(devices)
          .set({ revokedAt: new Date(), revokedReason: 'user_logout_all' })
          .where(and(eq(devices.courierId, courier.courierId), isNull(devices.revokedAt)));
      } else {
        await ctx.tokens.revokeFamily(courier.familyId, 'user_logout');
      }

      return reply.status(204).send();
    },
  );

  route.get(
    '/v1/me',
    {
      schema: { tags: ['Auth'], response: { 200: CourierProfile, ...problem } },
    },
    async (request) => {
      const authenticated = await app.authenticate(request);
      const courier = await ctx.db.query.couriers.findFirst({
        where: (c, { eq: equals }) => equals(c.id, authenticated.courierId),
        with: { branch: { columns: { name: true } } },
      });
      if (!courier) throw new AppError('NOT_FOUND');
      return toProfile(courier);
    },
  );

  route.post(
    '/v1/devices/push-token',
    {
      schema: { tags: ['Auth'], body: PushTokenRequest, response: { 204: z.null(), ...problem } },
    },
    async (request, reply) => {
      const courier = await app.authenticate(request);
      if (request.body.installationId !== courier.installationId) {
        throw new AppError('DEVICE_NOT_BOUND');
      }

      await ctx.db
        .update(devices)
        .set({ pushToken: request.body.token })
        .where(eq(devices.id, courier.deviceId));

      return reply.status(204).send();
    },
  );
}

/* ------------------------------------------------------------------ *
 * Helpers
 * ------------------------------------------------------------------ */

/**
 * Android is the only platform that can be told to stop killing the location
 * service, and it is the difference between a usable trail and a dotted line.
 */
function requiredPermissionsFor(platform: Platform): RequiredPermissions {
  const base: RequiredPermissions = [
    'LOCATION_ALWAYS',
    'CAMERA',
    'NOTIFICATIONS',
  ];
  return platform === 'android' ? [...base, 'BATTERY_OPTIMIZATION_EXEMPTION'] : base;
}

function serializeTokens(tokens: {
  accessToken: string;
  accessTokenExpiresAt: Date;
  refreshToken: string;
  refreshTokenExpiresAt: Date;
}) {
  return {
    accessToken: tokens.accessToken,
    accessTokenExpiresAt: tokens.accessTokenExpiresAt.toISOString(),
    refreshToken: tokens.refreshToken,
    refreshTokenExpiresAt: tokens.refreshTokenExpiresAt.toISOString(),
  };
}

type CourierRow = {
  id: string;
  fullName: string;
  phone: string;
  employeeCode: string | null;
  branchId: string | null;
  status: 'active' | 'suspended' | 'terminated';
  capabilities: string[];
  branch?: { name: string } | null;
};

function toProfile(courier: CourierRow): z.infer<typeof CourierProfile> {
  return {
    id: courier.id,
    fullName: courier.fullName,
    phone: courier.phone,
    employeeCode: courier.employeeCode,
    branchId: courier.branchId,
    branchName: courier.branch?.name ?? null,
    avatarUrl: null,
    status: courier.status,
    capabilities: courier.capabilities as z.infer<typeof CourierProfile>['capabilities'],
  };
}

/**
 * Response for an unknown or inactive number. Shaped exactly like a real one,
 * including a plausible cooldown, so timing and payload give nothing away.
 */
function decoyChallenge(): z.infer<typeof ActivationStartResponse> {
  const now = Date.now();
  return {
    challengeId: crypto.randomUUID(),
    codeLength: 6,
    expiresAt: new Date(now + 300_000).toISOString(),
    resendAvailableAt: new Date(now + 60_000).toISOString(),
    attemptsRemaining: 5,
    integrityNonce: Buffer.from(crypto.randomUUID()).toString('base64url'),
  };
}

function mask(phone: string): string {
  return `${phone.slice(0, 6)}***${phone.slice(-2)}`;
}
