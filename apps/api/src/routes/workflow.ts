import { ErrorResponse, WorkflowDefinition } from '@dijigoo/contracts';
import { AppError } from '@dijigoo/core';
import { workflows } from '@dijigoo/db';
import { and, eq } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { z } from 'zod';

import type { AppContext } from '../context.js';

export async function workflowRoutes(app: FastifyInstance, { ctx }: { ctx: AppContext }) {
  const route = app.withTypeProvider<ZodTypeProvider>();

  route.get(
    '/v1/workflows/:key/versions/:version',
    {
      schema: {
        tags: ['Workflow'],
        params: z.object({ key: z.string().max(60), version: z.coerce.number().int().positive() }),
        response: {
          200: WorkflowDefinition,
          400: ErrorResponse,
          401: ErrorResponse,
          404: ErrorResponse,
        },
      },
    },
    async (request, reply) => {
      const courier = await app.authenticate(request);
      const { key, version } = request.params;

      const [workflow] = await ctx.db
        .select()
        .from(workflows)
        .where(
          and(
            eq(workflows.tenantId, courier.tenantId),
            eq(workflows.key, key),
            eq(workflows.version, version),
          ),
        )
        .limit(1);

      if (!workflow || workflow.status === 'draft') throw new AppError('NOT_FOUND');

      // Refuse to hand a definition to a client that cannot render every step
      // type in it. Silently skipping an unknown step would produce a delivery
      // with missing evidence, which is worse than a forced update.
      const build = parseBuild(request.headers['x-client-info']);
      if (build !== null && build < workflow.minAppBuild) {
        throw new AppError('UNSUPPORTED_CLIENT_VERSION', {
          details: [
            {
              field: 'x-client-info',
              issue: 'workflow_requires_newer_build',
              meta: { required: workflow.minAppBuild, provided: build },
            },
          ],
        });
      }

      // A published version is immutable, so this can be cached forever.
      reply.header('cache-control', 'public, max-age=31536000, immutable');
      reply.header('etag', `"${workflow.key}-v${workflow.version}"`);

      return {
        id: workflow.id,
        key: workflow.key,
        version: workflow.version,
        name: workflow.name,
        description: workflow.description,
        status: workflow.status,
        appliesTo: workflow.appliesTo as z.infer<typeof WorkflowDefinition>['appliesTo'],
        steps: workflow.steps,
        outcomes: workflow.outcomes,
        minAppBuild: workflow.minAppBuild,
        publishedAt: workflow.publishedAt?.toISOString() ?? null,
        publishedBy: workflow.publishedBy,
        createdAt: workflow.createdAt.toISOString(),
        updatedAt: workflow.updatedAt.toISOString(),
      };
    },
  );
}

function parseBuild(header: string | string[] | undefined): number | null {
  if (typeof header !== 'string') return null;
  const match = /build (\d+)\)$/.exec(header);
  return match ? Number(match[1]) : null;
}
