import {
  ErrorResponse,
  IvrResultRequest,
  IvrResultResponse,
  IvrShipmentDetail,
  IvrShipmentListResponse,
  IvrTicketCreateRequest,
  IvrTicketCreateResponse,
} from '@dijigoo/contracts';
import { AppError, fieldKeyFromEnv } from '@dijigoo/core';
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { z } from 'zod';

import type { AppContext } from '../context.js';
import { serviceRouteRateLimit } from '../rate-limits.js';
import {
  createIvrTicket,
  findIvrShipmentByReference,
  findIvrShipmentsByPhone,
  recordIvrResult,
} from '../services/ivr-shipments.js';

const problem = {
  400: ErrorResponse,
  401: ErrorResponse,
  404: ErrorResponse,
  429: ErrorResponse,
};

export async function ivrRoutes(app: FastifyInstance, { ctx }: { ctx: AppContext }) {
  const route = app.withTypeProvider<ZodTypeProvider>();

  route.get(
    '/v1/ivr/shipments',
    {
      config: { rateLimit: serviceRouteRateLimit },
      schema: {
        tags: ['Ivr'],
        querystring: z.object({ phone: z.string().min(10).max(20) }),
        response: { 200: IvrShipmentListResponse, ...problem },
      },
    },
    async (request) => {
      await app.authenticateSolvelineInbound(request);
      const key = fieldKeyFromEnv(ctx.env.FIELD_ENCRYPTION_KEY);
      const shipments = await findIvrShipmentsByPhone(ctx.db, key, request.query.phone);
      return { shipments };
    },
  );

  route.get(
    '/v1/ivr/shipments/:reference',
    {
      config: { rateLimit: serviceRouteRateLimit },
      schema: {
        tags: ['Ivr'],
        params: z.object({ reference: z.string().min(3).max(60) }),
        response: { 200: IvrShipmentDetail, ...problem },
      },
    },
    async (request) => {
      await app.authenticateSolvelineInbound(request);
      const key = fieldKeyFromEnv(ctx.env.FIELD_ENCRYPTION_KEY);
      const shipment = await findIvrShipmentByReference(ctx.db, key, request.params.reference);
      if (!shipment) throw new AppError('NOT_FOUND');
      return shipment;
    },
  );

  route.post(
    '/v1/ivr/shipments/:reference/tickets',
    {
      config: { rateLimit: serviceRouteRateLimit },
      schema: {
        tags: ['Ivr'],
        params: z.object({ reference: z.string().min(3).max(60) }),
        body: IvrTicketCreateRequest,
        response: { 200: IvrTicketCreateResponse, ...problem },
      },
    },
    async (request) => {
      await app.authenticateSolvelineInbound(request);
      return createIvrTicket(ctx.db, {
        reference: request.params.reference,
        kind: request.body.kind,
        note: request.body.note,
        correlationId: request.id,
      });
    },
  );

  route.post(
    '/v1/ivr/results',
    {
      config: { rateLimit: serviceRouteRateLimit },
      schema: {
        tags: ['Ivr'],
        body: IvrResultRequest,
        response: { 200: IvrResultResponse, ...problem },
      },
    },
    async (request) => {
      await app.authenticateSolvelineInbound(request);
      return recordIvrResult(ctx.db, request.body);
    },
  );
}
