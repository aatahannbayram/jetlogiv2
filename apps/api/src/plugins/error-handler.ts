import { AppError } from '@dijigoo/core';
import type { FastifyInstance } from 'fastify';
import fp from 'fastify-plugin';
import { hasZodFastifySchemaValidationErrors } from 'fastify-type-provider-zod';

/**
 * Single exit point for every failure. Anything that is not an AppError is
 * logged with its stack and reported as INTERNAL_ERROR, so a driver message or
 * a stack trace never reaches a courier's handset.
 */
export const errorHandler = fp(async (app: FastifyInstance) => {
  app.setErrorHandler((error, request, reply) => {
    const traceId = request.id;

    if (error instanceof AppError) {
      // 4xx is the client's problem and is expected traffic; only log the body
      // for server-side faults.
      const level = error.status >= 500 ? 'error' : 'info';
      request.log[level]({ code: error.code, status: error.status }, error.message);

      if (error.retryAfter) reply.header('retry-after', String(error.retryAfter));
      return reply
        .status(error.status)
        .type('application/problem+json')
        .send(error.toResponse(traceId));
    }

    if (hasZodFastifySchemaValidationErrors(error)) {
      return reply
        .status(400)
        .type('application/problem+json')
        .send({
          error: {
            code: 'VALIDATION_FAILED',
            message: 'Gonderilen veri gecerli degil.',
            userVisible: false,
            traceId,
            details: error.validation.map((issue) => ({
              field: issue.instancePath || issue.params?.issue?.path?.join('.') || null,
              issue: issue.message ?? 'invalid',
            })),
            retryAfter: null,
          },
        });
    }

    if ((error as { statusCode?: number }).statusCode === 429) {
      return reply
        .status(429)
        .type('application/problem+json')
        .send({
          error: {
            code: 'RATE_LIMITED',
            message: 'Cok fazla istek gonderdiniz, biraz bekleyin.',
            userVisible: true,
            traceId,
            details: null,
            retryAfter: 60,
          },
        });
    }

    request.log.error({ err: error }, 'Beklenmeyen hata');

    return reply
      .status(500)
      .type('application/problem+json')
      .send({
        error: {
          code: 'INTERNAL_ERROR',
          message: 'Beklenmeyen bir hata olustu.',
          userVisible: false,
          traceId,
          details: null,
          retryAfter: null,
        },
      });
  });

  app.setNotFoundHandler((request, reply) =>
    reply
      .status(404)
      .type('application/problem+json')
      .send({
        error: {
          code: 'NOT_FOUND',
          message: 'Kayit bulunamadi.',
          userVisible: false,
          traceId: request.id,
          details: null,
          retryAfter: null,
        },
      }),
  );
});
