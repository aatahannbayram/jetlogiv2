import { ERROR_STATUS, NON_RETRYABLE_ERRORS, type ErrorCode, type ErrorResponse } from '@dijigoo/contracts';

export interface AppErrorOptions {
  /** Turkish text safe to show the courier. Only rendered when `userVisible`. */
  message?: string;
  userVisible?: boolean;
  details?: { field?: string | null; issue: string; meta?: Record<string, unknown> | null }[];
  retryAfter?: number;
  cause?: unknown;
}

/**
 * The single error type the API throws. Everything else that escapes a handler
 * is converted to INTERNAL_ERROR at the boundary, so no stack trace or driver
 * message ever reaches a courier's handset.
 */
export class AppError extends Error {
  readonly code: ErrorCode;
  readonly status: number;
  readonly userVisible: boolean;
  readonly details?: AppErrorOptions['details'];
  readonly retryAfter?: number;

  constructor(code: ErrorCode, options: AppErrorOptions = {}) {
    super(options.message ?? DEFAULT_MESSAGES[code], { cause: options.cause });
    this.name = 'AppError';
    this.code = code;
    this.status = ERROR_STATUS[code];
    this.userVisible = options.userVisible ?? USER_VISIBLE_BY_DEFAULT.has(code);
    this.details = options.details;
    this.retryAfter = options.retryAfter;
  }

  toResponse(traceId: string): ErrorResponse {
    return {
      error: {
        code: this.code,
        message: this.message,
        userVisible: this.userVisible,
        traceId,
        details: this.details ?? null,
        retryAfter: this.retryAfter ?? null,
      },
    };
  }
}

export function isRetryable(code: ErrorCode): boolean {
  return !NON_RETRYABLE_ERRORS.includes(code);
}

/**
 * Codes whose message is written for the courier, not for the log. Everything
 * else gets a generic string in the UI regardless of what the server said.
 */
const USER_VISIBLE_BY_DEFAULT = new Set<ErrorCode>([
  'OTP_INVALID',
  'OTP_EXPIRED',
  'GEOFENCE_VIOLATION',
  'SHIFT_NOT_ACTIVE',
  'EVIDENCE_INCOMPLETE',
  'TASK_ALREADY_FINALIZED',
  'WORKFLOW_VERSION_SUPERSEDED',
  'UNSUPPORTED_CLIENT_VERSION',
  'DEVICE_NOT_BOUND',
  'RATE_LIMITED',
]);

const DEFAULT_MESSAGES: Record<ErrorCode, string> = {
  VALIDATION_FAILED: 'Gonderilen veri gecerli degil.',
  MALFORMED_REQUEST: 'Istek govdesi okunamadi.',
  UNSUPPORTED_CLIENT_VERSION: 'Uygulamanizi guncellemeniz gerekiyor.',
  UNAUTHENTICATED: 'Oturum bulunamadi.',
  TOKEN_EXPIRED: 'Oturum suresi doldu.',
  TOKEN_REVOKED: 'Oturum iptal edildi.',
  OTP_INVALID: 'Girilen kod hatali.',
  OTP_EXPIRED: 'Kodun suresi doldu, yeniden gonderin.',
  FORBIDDEN: 'Bu islem icin yetkiniz yok.',
  DEVICE_NOT_BOUND: 'Bu cihaz hesabiniza bagli degil.',
  DEVICE_INTEGRITY_FAILED: 'Cihaz butunlugu dogrulanamadi.',
  SHIFT_NOT_ACTIVE: 'Once vardiya baslatmalisiniz.',
  GEOFENCE_VIOLATION: 'Teslimat adresine yeterince yakin degilsiniz.',
  WORKFLOW_STEP_OUT_OF_ORDER: 'Onceki adimlari tamamlamaniz gerekiyor.',
  NOT_FOUND: 'Kayit bulunamadi.',
  CONFLICT: 'Kayit baska bir islemle cakisti.',
  VERSION_MISMATCH: 'Kayit guncellenmis, lutfen yenileyin.',
  IDEMPOTENCY_KEY_REUSED: 'Ayni anahtar farkli bir istek govdesiyle kullanildi.',
  TASK_ALREADY_FINALIZED: 'Bu gorev zaten sonuclandirilmis.',
  WORKFLOW_VERSION_SUPERSEDED: 'Gorev akisi guncellendi, gorevi yeniden acin.',
  MEDIA_NOT_READY: 'Fotograf yuklemesi tamamlanmadi.',
  PAYLOAD_TOO_LARGE: 'Dosya boyutu cok buyuk.',
  UNSUPPORTED_MEDIA_TYPE: 'Bu dosya tipi desteklenmiyor.',
  BUSINESS_RULE_VIOLATION: 'Islem is kurallarina uymuyor.',
  EVIDENCE_INCOMPLETE: 'Zorunlu kanitlar eksik.',
  RATE_LIMITED: 'Cok fazla istek gonderdiniz, biraz bekleyin.',
  INTERNAL_ERROR: 'Beklenmeyen bir hata olustu.',
  UPSTREAM_UNAVAILABLE: 'Servis su anda kullanilamiyor.',
  UPSTREAM_TIMEOUT: 'Servis zaman asimina ugradi.',
};
