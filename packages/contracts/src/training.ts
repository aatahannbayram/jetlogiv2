import { Timestamp, Uuid, z } from './common.js';

/**
 * Eğitim modülü — toplantı maddesi 5. MVP: metin/checklist içerik, video
 * barındırma yok. `completed`/`completedAt` bu kurye için tamamlanma
 * durumunu taşır — global modül tanımına ait değildir.
 */
export const TrainingModule = z
  .object({
    id: Uuid,
    title: z.string().max(200),
    summary: z.string().max(500).nullish(),
    body: z.string(),
    sortOrder: z.number().int(),
    completed: z.boolean(),
    completedAt: Timestamp.nullish(),
  })
  .openapi('TrainingModule');

export const TrainingModuleListResponse = z
  .object({ items: z.array(TrainingModule) })
  .openapi('TrainingModuleListResponse');

export const TrainingCompleteResponse = z
  .object({ moduleId: Uuid, completedAt: Timestamp })
  .openapi('TrainingCompleteResponse');
