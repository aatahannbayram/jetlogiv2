import type { Database } from '@dijigoo/db';
import { trainingCompletions, trainingModules } from '@dijigoo/db';
import { and, eq } from 'drizzle-orm';

export interface TrainingModuleView {
  id: string;
  title: string;
  summary: string | null;
  body: string;
  sortOrder: number;
  completed: boolean;
  completedAt: Date | null;
}

/** Aktif modülleri, verilen kurye için tamamlanma durumuyla birlikte döner. */
export async function listTrainingModulesFor(
  db: Database,
  tenantId: string,
  courierId: string,
): Promise<TrainingModuleView[]> {
  const modules = await db
    .select()
    .from(trainingModules)
    .where(and(eq(trainingModules.tenantId, tenantId), eq(trainingModules.isActive, true)))
    .orderBy(trainingModules.sortOrder);

  const completions = await db
    .select({ moduleId: trainingCompletions.moduleId, completedAt: trainingCompletions.completedAt })
    .from(trainingCompletions)
    .where(eq(trainingCompletions.courierId, courierId));
  const completedAt = new Map(completions.map((c) => [c.moduleId, c.completedAt]));

  return modules.map((m) => ({
    id: m.id,
    title: m.title,
    summary: m.summary,
    body: m.body,
    sortOrder: m.sortOrder,
    completed: completedAt.has(m.id),
    completedAt: completedAt.get(m.id) ?? null,
  }));
}

/**
 * Idempotent: modül zaten tamamlanmışsa mevcut satırı döner, yeni satır
 * eklemez — offline kuyruğun aynı isteği ikinci kez göndermesi olağan.
 */
export async function completeTrainingModule(
  db: Database,
  courierId: string,
  moduleId: string,
): Promise<Date> {
  const [existing] = await db
    .select({ completedAt: trainingCompletions.completedAt })
    .from(trainingCompletions)
    .where(and(eq(trainingCompletions.courierId, courierId), eq(trainingCompletions.moduleId, moduleId)))
    .limit(1);
  if (existing) return existing.completedAt;

  const [created] = await db
    .insert(trainingCompletions)
    .values({ courierId, moduleId })
    .returning({ completedAt: trainingCompletions.completedAt });
  return created!.completedAt;
}
