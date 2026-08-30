import { Timestamp, Uuid, z } from './common.js';

/**
 * Canlı web (`kurye.dijigoo.com`) onboarding kimliğini taşır.
 * Mobil bu kayıtları devralır; cookie session kullanmaz.
 *
 * Canlı örnek (2026-08-25): DGC-2026-9CF4875F, Denizli/Güney, CAR, PART_TIME.
 */

export const WorkVehicle = z.enum(['CAR', 'MOTORCYCLE', 'BICYCLE', 'ON_FOOT', 'VAN']);
export const EmploymentType = z.enum(['FULL_TIME', 'PART_TIME', 'SEASONAL']);
export const CourierAvailabilityStatus = z.enum([
  'AVAILABLE',
  'UNAVAILABLE',
  'ON_SHIFT',
  'ON_BREAK',
]);
export const DocumentReviewStatus = z.enum([
  'MISSING',
  'PENDING',
  'COMPLETED',
  'REJECTED',
  'EXPIRED',
]);

export const AvailabilityWindow = z
  .object({
    weekday: z.number().int().min(1).max(7).describe('ISO: 1=Pazartesi'),
    start: z.string().regex(/^\d{2}:\d{2}$/),
    end: z.string().regex(/^\d{2}:\d{2}$/),
  })
  .openapi('AvailabilityWindow');
export type AvailabilityWindow = z.infer<typeof AvailabilityWindow>;

export const CourierAvailability = z
  .object({
    status: CourierAvailabilityStatus,
    vehicle: WorkVehicle,
    employmentType: EmploymentType,
    city: z.string(),
    district: z.string().nullish(),
    weekly: z.array(AvailabilityWindow),
    updatedAt: Timestamp,
  })
  .openapi('CourierAvailability');
export type CourierAvailability = z.infer<typeof CourierAvailability>;

export const CourierDocument = z
  .object({
    id: Uuid,
    type: z.enum([
      'IDENTITY',
      'DRIVING_LICENSE',
      'SRC',
      'CRIMINAL_RECORD',
      'RESIDENCE',
      'IBAN',
      'CONTRACT',
      'OTHER',
    ]),
    label: z.string(),
    status: DocumentReviewStatus,
    expiresAt: Timestamp.nullish(),
  })
  .openapi('CourierDocument');
export type CourierDocument = z.infer<typeof CourierDocument>;

export const CourierDocumentList = z
  .object({
    items: z.array(CourierDocument),
    completedCount: z.number().int().nonnegative(),
    requiredCount: z.number().int().nonnegative(),
  })
  .openapi('CourierDocumentList');
export type CourierDocumentList = z.infer<typeof CourierDocumentList>;
