import {
  ErrorResponse,
  TrainingCompleteResponse,
  TrainingModuleListResponse,
  Uuid,
} from '@dijigoo/contracts';
import { AppError } from '@dijigoo/core';
import { trainingModules } from '@dijigoo/db';
import { and, eq } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { z } from 'zod';

import type { AppContext } from '../context.js';
import { completeTrainingModule, listTrainingModulesFor } from '../services/training.js';

/**
 * Eğitim modülü — toplantı maddesi 5. MVP: sadece listeleme + tamamlama,
 * içerik yönetimi (ekleme/düzenleme) bu kod tabanında yok — modüller şimdilik
 * doğrudan veritabanına yazılıyor, bir admin arayüzü kapsam dışı.
 */
export async function trainingRoutes(app: FastifyInstance, { ctx }: { ctx: AppContext }) {
  const route = app.withTypeProvider<ZodTypeProvider>();

  route.get(
    '/v1/training/modules',
    {
      schema: {
        tags: ['Training'],
        response: { 200: TrainingModuleListResponse, 401: ErrorResponse },
      },
    },
    async (request) => {
      const courier = await app.authenticate(request);
      const modules = await listTrainingModulesFor(ctx.db, courier.tenantId, courier.courierId);
      return {
        items: modules.map((m) => ({
          ...m,
          completedAt: m.completedAt?.toISOString() ?? null,
        })),
      };
    },
  );

  route.post(
    '/v1/training/modules/:moduleId/complete',
    {
      schema: {
        tags: ['Training'],
        params: z.object({ moduleId: Uuid }),
        response: { 200: TrainingCompleteResponse, 401: ErrorResponse, 404: ErrorResponse },
      },
    },
    async (request) => {
      const courier = await app.authenticate(request);
      const { moduleId } = request.params;

      const [module] = await ctx.db
        .select({ id: trainingModules.id })
        .from(trainingModules)
        .where(and(eq(trainingModules.id, moduleId), eq(trainingModules.tenantId, courier.tenantId)))
        .limit(1);
      if (!module) throw new AppError('NOT_FOUND');

      const completedAt = await completeTrainingModule(ctx.db, courier.courierId, moduleId);
      return { moduleId, completedAt: completedAt.toISOString() };
    },
  );
}
