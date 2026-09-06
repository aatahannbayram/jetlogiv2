import {
  OpenAPIRegistry,
  OpenApiGeneratorV31,
  type RouteConfig,
} from '@asteasolutions/zod-to-openapi';
import type { OpenAPIObject } from 'openapi3-ts/oas31';

import {
  ActivationStartRequest,
  ActivationStartResponse,
  ActivationVerifyRequest,
  ActivationVerifyResponse,
  CourierProfile,
  DeviceInfo,
  IntegrityAssertion,
  IntegrityVerdict,
  LogoutRequest,
  PushTokenRequest,
  RefreshRequest,
  RefreshResponse,
  TokenPair,
} from './auth.js';
import { AppConfig } from './config.js';
import { CourierAvailability, CourierDocumentList } from './identity.js';
import {
  Address,
  ClientInfoHeader,
  Coordinates,
  ErrorDetail,
  ErrorResponse,
  GeoPoint,
  IdempotencyKeyHeader,
  Uuid,
  z,
} from './common.js';
import {
  CustodyHandoverRequest,
  CustodyHandoverResponse,
  CustodyItem,
  CustodyListQuery,
  CustodyListResponse,
  SupportTicket,
  SupportTicketCreateRequest,
  SupportTicketListResponse,
} from './custody.js';
import { DelayDecisionRequest, DelayDecisionResponse } from './delay-decision.js';
import { TaskAssignRequest, TaskAssignResponse } from './task-assign.js';
import { EventEnvelope, PushNotification, WebhookPayload } from './events.js';
import {
  CourierInboxItem,
  NotificationDispatchRequest,
  NotificationListResponse,
  NotificationReadRequest,
} from './notifications.js';
import { ConfirmMediaResponse, MediaRef, PresignRequest, PresignResponse } from './media.js';
import { RoutingOptimizeRequest, RoutingOptimizeResponse } from './routing-service.js';
import {
  LocationBatchRequest,
  LocationBatchResponse,
  Route,
  RouteStop,
  Shift,
  ShiftEndRequest,
  ShiftStartRequest,
} from './shift.js';
import { SyncBatchRequest, SyncBatchResponse, SyncChanges, SyncPullQuery, SyncResult } from './sync.js';
import {
  Contact,
  MaskedCallRequest,
  MaskedCallResponse,
  StepAnswer,
  StepSubmitRequest,
  TaskDetail,
  TaskFinalizeRequest,
  TaskItem,
  TaskListQuery,
  TaskListResponse,
  TaskMutationResponse,
  TaskOtpSendRequest,
  TaskOtpSendResponse,
  TaskOtpVerifyRequest,
  TaskOtpVerifyResponse,
  TaskSummary,
  TaskTransitionRequest,
} from './task.js';
import { WorkflowDefinition, WorkflowRef, WorkflowStep } from './workflow.js';

export const registry = new OpenAPIRegistry();

/* ------------------------------------------------------------------ *
 * Security
 * ------------------------------------------------------------------ */

const bearerAuth = registry.registerComponent('securitySchemes', 'bearerAuth', {
  type: 'http',
  scheme: 'bearer',
  bearerFormat: 'JWT',
  description:
    'Aktivasyon sonrasi verilen kisa omurlu access token. 15 dakika gecerli, ' +
    'refresh ile doner. Token cihaz kimligine (installationId) baglidir.',
});

/**
 * Not a courier identity — a shared secret for another team's *backend*
 * (jetlogi-panel) to call our service-to-service endpoints. See
 * apps/api/src/plugins/service-auth.ts.
 */
const serviceAuth = registry.registerComponent('securitySchemes', 'serviceAuth', {
  type: 'apiKey',
  in: 'header',
  name: 'x-service-token',
  description:
    'Operasyon panelinin backend’i icin paylasilan servis anahtari. Kurye bearer ' +
    'tokeni degildir, bu API’de operator kimligi yoktur.',
});

/* ------------------------------------------------------------------ *
 * Components
 * ------------------------------------------------------------------ */

const schemas = {
  Coordinates,
  GeoPoint,
  Address,
  ErrorDetail,
  ErrorResponse,
  AppConfig,
  CourierAvailability,
  CourierDocumentList,
  DeviceInfo,
  IntegrityAssertion,
  IntegrityVerdict,
  CourierProfile,
  TokenPair,
  ActivationStartRequest,
  ActivationStartResponse,
  ActivationVerifyRequest,
  ActivationVerifyResponse,
  RefreshRequest,
  RefreshResponse,
  LogoutRequest,
  PushTokenRequest,
  WorkflowStep,
  WorkflowDefinition,
  WorkflowRef,
  MediaRef,
  PresignRequest,
  PresignResponse,
  Contact,
  TaskItem,
  StepAnswer,
  TaskSummary,
  TaskDetail,
  TaskListResponse,
  TaskTransitionRequest,
  StepSubmitRequest,
  TaskFinalizeRequest,
  TaskMutationResponse,
  TaskOtpSendRequest,
  TaskOtpSendResponse,
  TaskOtpVerifyRequest,
  TaskOtpVerifyResponse,
  MaskedCallRequest,
  MaskedCallResponse,
  Shift,
  ShiftStartRequest,
  ShiftEndRequest,
  LocationBatchRequest,
  LocationBatchResponse,
  RouteStop,
  Route,
  RoutingOptimizeRequest,
  RoutingOptimizeResponse,
  DelayDecisionRequest,
  DelayDecisionResponse,
  TaskAssignRequest,
  TaskAssignResponse,
  CustodyItem,
  CustodyListResponse,
  CustodyHandoverRequest,
  CustodyHandoverResponse,
  SupportTicket,
  SupportTicketCreateRequest,
  SupportTicketListResponse,
  SyncResult,
  SyncBatchRequest,
  SyncBatchResponse,
  SyncChanges,
  EventEnvelope,
  WebhookPayload,
  PushNotification,
  CourierInboxItem,
  NotificationListResponse,
  NotificationReadRequest,
  NotificationDispatchRequest,
} as const;

for (const [name, schema] of Object.entries(schemas)) {
  registry.register(name, schema as never);
}

/* ------------------------------------------------------------------ *
 * Reusable response fragments
 * ------------------------------------------------------------------ */

const errorContent = { 'application/problem+json': { schema: ErrorResponse } };

/** Attached to every route so the client never meets an undocumented failure. */
const commonErrors = {
  400: { description: 'Gecersiz istek', content: errorContent },
  401: { description: 'Kimlik dogrulanamadi veya token suresi doldu', content: errorContent },
  429: { description: 'Hiz siniri asildi', content: errorContent },
  500: { description: 'Beklenmeyen sunucu hatasi', content: errorContent },
} satisfies RouteConfig['responses'];

const authedErrors = {
  ...commonErrors,
  403: { description: 'Yetkisiz, cihaz bagli degil veya vardiya acik degil', content: errorContent },
  404: { description: 'Kayit bulunamadi', content: errorContent },
} satisfies RouteConfig['responses'];

const mutationErrors = {
  ...authedErrors,
  409: { description: 'Surum catismasi veya kayit zaten sonuclandirilmis', content: errorContent },
  422: { description: 'Is kurali ihlali veya eksik kanit', content: errorContent },
} satisfies RouteConfig['responses'];

const clientHeaders = z.object({
  'x-client-info': ClientInfoHeader,
});

const idempotentHeaders = z.object({
  'x-client-info': ClientInfoHeader,
  'idempotency-key': IdempotencyKeyHeader,
});

function json<T>(schema: T) {
  return { 'application/json': { schema } };
}

/* ------------------------------------------------------------------ *
 * Config (unauthenticated)
 * ------------------------------------------------------------------ */

registry.registerPath({
  method: 'get',
  path: '/v1/config',
  tags: ['Config'],
  summary: 'Zorunlu guncelleme, feature flag, geofence esikleri',
  description:
    'Splash bu yaniti beklemeden ilerleyemez. min*Build istemci build altindaysa ' +
    'forceUpdate true ise magaza yonlendirmesi gosterilir. shiftFaceMatch v1 icin false.',
  security: [],
  request: { headers: clientHeaders },
  responses: {
    200: { description: 'Uygulama konfigurasyonu', content: json(AppConfig) },
    ...commonErrors,
  },
});

/* ------------------------------------------------------------------ *
 * Auth
 * ------------------------------------------------------------------ */

registry.registerPath({
  method: 'post',
  path: '/v1/auth/activation/start',
  tags: ['Auth'],
  summary: 'Telefon numarasi ile aktivasyonu baslat',
  description:
    'Numara panelde kayitli bir kuryeye ait degilse de ayni yanit doner; ' +
    'numara kesfini engellemek icin kasitli olarak ayirt edilmez.',
  request: {
    headers: clientHeaders,
    body: { content: json(ActivationStartRequest) },
  },
  responses: {
    200: { description: 'OTP gonderildi', content: json(ActivationStartResponse) },
    ...commonErrors,
  },
});

registry.registerPath({
  method: 'post',
  path: '/v1/auth/activation/verify',
  tags: ['Auth'],
  summary: 'OTP dogrula, cihazi bagla ve token cifti al',
  request: {
    headers: clientHeaders,
    body: { content: json(ActivationVerifyRequest) },
  },
  responses: {
    200: { description: 'Aktivasyon tamam', content: json(ActivationVerifyResponse) },
    ...commonErrors,
  },
});

registry.registerPath({
  method: 'post',
  path: '/v1/auth/token/refresh',
  tags: ['Auth'],
  summary: 'Refresh token ile yeni token cifti al',
  description:
    'Refresh token tek kullanimliktir. Harcanmis bir token yeniden sunulursa ' +
    'token ailesinin tamami iptal edilir ve kurye yeniden aktivasyon yapar.',
  request: {
    headers: clientHeaders,
    body: { content: json(RefreshRequest) },
  },
  responses: {
    200: { description: 'Yeni token cifti', content: json(RefreshResponse) },
    ...commonErrors,
  },
});

registry.registerPath({
  method: 'post',
  path: '/v1/auth/logout',
  tags: ['Auth'],
  summary: 'Oturumu kapat',
  security: [{ [bearerAuth.name]: [] }],
  request: { headers: clientHeaders, body: { content: json(LogoutRequest) } },
  responses: { 204: { description: 'Kapatildi' }, ...authedErrors },
});

registry.registerPath({
  method: 'get',
  path: '/v1/me',
  tags: ['Auth'],
  summary: 'Oturum acmis kurye profili',
  security: [{ [bearerAuth.name]: [] }],
  request: { headers: clientHeaders },
  responses: { 200: { description: 'Profil', content: json(CourierProfile) }, ...authedErrors },
});

registry.registerPath({
  method: 'get',
  path: '/v1/me/availability',
  tags: ['Identity'],
  summary: 'Musaitlik — web panel kaydini devralir',
  description:
    'Kaynak: kurye.dijigoo.com /api/public/v1/courier-availability. Mobil yeniden tasarlamaz. ' +
    'Cookie session kullanilmaz; ayni kayit token ile okunur.',
  security: [{ [bearerAuth.name]: [] }],
  request: { headers: clientHeaders },
  responses: {
    200: { description: 'Haftalik musaitlik', content: json(CourierAvailability) },
    ...authedErrors,
  },
});

registry.registerPath({
  method: 'get',
  path: '/v1/me/documents',
  tags: ['Identity'],
  summary: 'Onboarding belgelerinin ozeti',
  description:
    'Kaynak: /api/public/v1/courier-my-documents. Saha uygulaması evrak taramaz (v1.1).',
  security: [{ [bearerAuth.name]: [] }],
  request: { headers: clientHeaders },
  responses: {
    200: { description: 'Belge listesi', content: json(CourierDocumentList) },
    ...authedErrors,
  },
});

registry.registerPath({
  method: 'post',
  path: '/v1/devices/push-token',
  tags: ['Auth'],
  summary: 'FCM push tokenini kaydet',
  security: [{ [bearerAuth.name]: [] }],
  request: { headers: clientHeaders, body: { content: json(PushTokenRequest) } },
  responses: { 204: { description: 'Kaydedildi' }, ...authedErrors },
});

/* ------------------------------------------------------------------ *
 * Shift & location
 * ------------------------------------------------------------------ */

registry.registerPath({
  method: 'post',
  path: '/v1/shifts',
  tags: ['Shift'],
  summary: 'Vardiya baslat',
  security: [{ [bearerAuth.name]: [] }],
  request: { headers: idempotentHeaders, body: { content: json(ShiftStartRequest) } },
  responses: { 201: { description: 'Vardiya acildi', content: json(Shift) }, ...mutationErrors },
});

registry.registerPath({
  method: 'get',
  path: '/v1/shifts/current',
  tags: ['Shift'],
  summary: 'Acik vardiyayi getir',
  security: [{ [bearerAuth.name]: [] }],
  request: { headers: clientHeaders },
  responses: {
    200: { description: 'Acik vardiya', content: json(Shift) },
    204: { description: 'Acik vardiya yok' },
    ...authedErrors,
  },
});

registry.registerPath({
  method: 'post',
  path: '/v1/shifts/{shiftId}/end',
  tags: ['Shift'],
  summary: 'Vardiya bitir',
  security: [{ [bearerAuth.name]: [] }],
  request: {
    params: z.object({ shiftId: Uuid }),
    headers: idempotentHeaders,
    body: { content: json(ShiftEndRequest) },
  },
  responses: { 200: { description: 'Vardiya kapandi', content: json(Shift) }, ...mutationErrors },
});

registry.registerPath({
  method: 'post',
  path: '/v1/locations/batch',
  tags: ['Shift'],
  summary: 'Konum kayitlarini toplu gonder',
  description:
    'Arka plan servisi 30-60 saniyede veya 250 metrede bir tampon bosaltir. ' +
    'Dogrulugu yetersiz veya saklama penceresinden eski kayitlar sessizce elenir.',
  security: [{ [bearerAuth.name]: [] }],
  request: { headers: clientHeaders, body: { content: json(LocationBatchRequest) } },
  responses: {
    202: { description: 'Alindi', content: json(LocationBatchResponse) },
    ...authedErrors,
  },
});

registry.registerPath({
  method: 'get',
  path: '/v1/routes/current',
  tags: ['Shift'],
  summary: 'Gunun rota sirasi',
  security: [{ [bearerAuth.name]: [] }],
  request: { headers: clientHeaders },
  responses: {
    200: { description: 'Rota', content: json(Route) },
    204: { description: 'Rota hesaplanmadi' },
    ...authedErrors,
  },
});

/* ------------------------------------------------------------------ *
 * Routing (service-to-service — jetlogi-panel, not the mobile app)
 * ------------------------------------------------------------------ */

registry.registerPath({
  method: 'post',
  path: '/v1/routing/optimize',
  tags: ['Routing'],
  summary: 'Verilen duraklar icin en iyi sirayi hesapla (servisler-arasi)',
  description:
    'Baska bir ekibin backend’i (jetlogi-panel) icin durumsuz uc — kendi ' +
    '`tasks`/`shifts` tablomuza hicbir okuma/yazma yapmaz, caginin kendi ' +
    'duraklarini optimize eder. Ayni motor `GET /v1/routes/current` ile paylasilir.',
  security: [{ [serviceAuth.name]: [] }],
  request: { body: { content: json(RoutingOptimizeRequest) } },
  responses: {
    200: { description: 'Optimize sira', content: json(RoutingOptimizeResponse) },
    401: { description: 'Servis anahtari eksik veya hatali', content: errorContent },
  },
});

/* ------------------------------------------------------------------ *
 * Delay decision (service-to-service — jetlogi-panel, not the mobile app)
 * ------------------------------------------------------------------ */

registry.registerPath({
  method: 'post',
  path: '/v1/tasks/{taskId}/delay-decision',
  tags: ['Routing'],
  summary: 'SLA riskindeki gorev icin gecikme/iptal karari uygula',
  description:
    'Faz 5: operasyon panelinin backend’i, sla.at_risk isaretli bir gorev icin ' +
    'insan kararini bildirir — bu API’de operator kimligi olmadigi icin karar ' +
    'bu ucla disaridan alinir.',
  security: [{ [serviceAuth.name]: [] }],
  request: {
    params: z.object({ taskId: Uuid }),
    body: { content: json(DelayDecisionRequest) },
  },
  responses: {
    200: { description: 'Karar uygulandi', content: json(DelayDecisionResponse) },
    400: { description: 'Gecersiz istek', content: errorContent },
    401: { description: 'Servis anahtari eksik veya hatali', content: errorContent },
    404: { description: 'Gorev bulunamadi', content: errorContent },
    409: { description: 'Uygulanamaz durum', content: errorContent },
  },
});

registry.registerPath({
  method: 'post',
  path: '/v1/tasks/{taskId}/assign',
  tags: ['Task'],
  summary: 'Gorevi kuryeye ata veya baska kuryeden cek',
  description:
    'Operasyon paneli bir gorevi kuryeye verir. Onceki kurye varsa TASK_PULLED, ' +
    'yeni kuryeye TASK_ASSIGNED yazilir ve token varsa FCM gider.',
  security: [{ [serviceAuth.name]: [] }],
  request: {
    params: z.object({ taskId: Uuid }),
    body: { content: json(TaskAssignRequest) },
  },
  responses: {
    200: { description: 'Atama uygulandi', content: json(TaskAssignResponse) },
    400: { description: 'Gecersiz istek', content: errorContent },
    401: { description: 'Servis anahtari eksik veya hatali', content: errorContent },
    404: { description: 'Gorev veya kurye bulunamadi', content: errorContent },
    409: { description: 'Uygulanamaz durum', content: errorContent },
  },
});

/* ------------------------------------------------------------------ *
 * Workflow
 * ------------------------------------------------------------------ */

registry.registerPath({
  method: 'get',
  path: '/v1/workflows/{key}/versions/{version}',
  tags: ['Workflow'],
  summary: 'Yayinlanmis workflow surumunu getir',
  description:
    'Surumler degismezdir, bu yuzden yanit uzun sureli onbelleklenebilir. ' +
    'Istemcinin build numarasi minAppBuild altindaysa 400 UNSUPPORTED_CLIENT_VERSION doner.',
  security: [{ [bearerAuth.name]: [] }],
  request: {
    params: z.object({ key: z.string(), version: z.coerce.number().int().positive() }),
    headers: clientHeaders,
  },
  responses: {
    200: { description: 'Workflow tanimi', content: json(WorkflowDefinition) },
    ...authedErrors,
  },
});

/* ------------------------------------------------------------------ *
 * Tasks
 * ------------------------------------------------------------------ */

registry.registerPath({
  method: 'get',
  path: '/v1/tasks',
  tags: ['Task'],
  summary: 'Dagitim listesi',
  security: [{ [bearerAuth.name]: [] }],
  request: { query: TaskListQuery, headers: clientHeaders },
  responses: { 200: { description: 'Gorev listesi', content: json(TaskListResponse) }, ...authedErrors },
});

registry.registerPath({
  method: 'get',
  path: '/v1/tasks/{taskId}',
  tags: ['Task'],
  summary: 'Gorev detayi',
  security: [{ [bearerAuth.name]: [] }],
  request: { params: z.object({ taskId: Uuid }), headers: clientHeaders },
  responses: { 200: { description: 'Gorev', content: json(TaskDetail) }, ...authedErrors },
});

registry.registerPath({
  method: 'post',
  path: '/v1/tasks/{taskId}/transition',
  tags: ['Task'],
  summary: 'Gorev durumunu ilerlet',
  security: [{ [bearerAuth.name]: [] }],
  request: {
    params: z.object({ taskId: Uuid }),
    headers: idempotentHeaders,
    body: { content: json(TaskTransitionRequest) },
  },
  responses: {
    200: { description: 'Durum guncellendi', content: json(TaskMutationResponse) },
    ...mutationErrors,
  },
});

registry.registerPath({
  method: 'post',
  path: '/v1/tasks/{taskId}/steps',
  tags: ['Task'],
  summary: 'Workflow adimi gonder',
  description:
    'workflowVersion gorevin baslatildigi surumle eslesmelidir. Panel yeni surum ' +
    'yayinlamis olsa bile calisan gorev basladigi surumle biter.',
  security: [{ [bearerAuth.name]: [] }],
  request: {
    params: z.object({ taskId: Uuid }),
    headers: idempotentHeaders,
    body: { content: json(StepSubmitRequest) },
  },
  responses: {
    200: { description: 'Adim kaydedildi', content: json(TaskMutationResponse) },
    ...mutationErrors,
  },
});

registry.registerPath({
  method: 'post',
  path: '/v1/tasks/{taskId}/finalize',
  tags: ['Task'],
  summary: 'Gorevi sonuclandir (teslim edildi / edilemedi)',
  security: [{ [bearerAuth.name]: [] }],
  request: {
    params: z.object({ taskId: Uuid }),
    headers: idempotentHeaders,
    body: { content: json(TaskFinalizeRequest) },
  },
  responses: {
    200: { description: 'Gorev sonuclandi', content: json(TaskMutationResponse) },
    ...mutationErrors,
  },
});

registry.registerPath({
  method: 'post',
  path: '/v1/tasks/{taskId}/otp/send',
  tags: ['Task'],
  summary: 'Alici dogrulama kodu gonder',
  security: [{ [bearerAuth.name]: [] }],
  request: {
    params: z.object({ taskId: Uuid }),
    headers: idempotentHeaders,
    body: { content: json(TaskOtpSendRequest) },
  },
  responses: {
    200: { description: 'Kod gonderildi', content: json(TaskOtpSendResponse) },
    ...mutationErrors,
  },
});

registry.registerPath({
  method: 'post',
  path: '/v1/tasks/{taskId}/otp/verify',
  tags: ['Task'],
  summary: 'Alici dogrulama kodunu dogrula',
  security: [{ [bearerAuth.name]: [] }],
  request: {
    params: z.object({ taskId: Uuid }),
    headers: clientHeaders,
    body: { content: json(TaskOtpVerifyRequest) },
  },
  responses: {
    200: { description: 'Dogrulama sonucu', content: json(TaskOtpVerifyResponse) },
    ...mutationErrors,
  },
});

registry.registerPath({
  method: 'post',
  path: '/v1/tasks/{taskId}/call',
  tags: ['Task'],
  summary: 'Maskeli arama oturumu ac',
  security: [{ [bearerAuth.name]: [] }],
  request: {
    params: z.object({ taskId: Uuid }),
    headers: clientHeaders,
    body: { content: json(MaskedCallRequest) },
  },
  responses: {
    200: { description: 'Aranacak proxy numara', content: json(MaskedCallResponse) },
    ...authedErrors,
    503: { description: 'Operator servisi kullanilamiyor', content: errorContent },
  },
});

/* ------------------------------------------------------------------ *
 * Media
 * ------------------------------------------------------------------ */

registry.registerPath({
  method: 'post',
  path: '/v1/media/presign',
  tags: ['Media'],
  summary: 'Nesne depolamaya dogrudan yukleme icin imzali URL al',
  description:
    'Medya hicbir zaman API uzerinden akmaz. Istemci imzali PUT alir, dosyayi ' +
    'dogrudan depolamaya yukler, sonra mediaId referansini adim gonderiminde kullanir.',
  security: [{ [bearerAuth.name]: [] }],
  request: { headers: clientHeaders, body: { content: json(PresignRequest) } },
  responses: {
    200: { description: 'Imzali URL', content: json(PresignResponse) },
    ...authedErrors,
    413: { description: 'Dosya cok buyuk', content: errorContent },
    415: { description: 'Desteklenmeyen icerik tipi', content: errorContent },
  },
});

registry.registerPath({
  method: 'post',
  path: '/v1/media/{mediaId}/confirm',
  tags: ['Media'],
  summary: 'Presign PUT sonrasi medyayi uploaded isaretle',
  security: [{ [bearerAuth.name]: [] }],
  request: { params: z.object({ mediaId: Uuid }), headers: clientHeaders },
  responses: {
    200: { description: 'Yukleme onaylandi', content: json(ConfirmMediaResponse) },
    ...authedErrors,
    409: { description: 'Nesne henuz depolamada yok', content: errorContent },
  },
});

/* ------------------------------------------------------------------ *
 * Custody & support
 * ------------------------------------------------------------------ */

registry.registerPath({
  method: 'get',
  path: '/v1/custody',
  tags: ['Custody'],
  summary: 'Kurye uzerindeki zimmet',
  security: [{ [bearerAuth.name]: [] }],
  request: { query: CustodyListQuery, headers: clientHeaders },
  responses: { 200: { description: 'Zimmet listesi', content: json(CustodyListResponse) }, ...authedErrors },
});

registry.registerPath({
  method: 'post',
  path: '/v1/custody/handover',
  tags: ['Custody'],
  summary: 'Zimmet devret veya devral',
  security: [{ [bearerAuth.name]: [] }],
  request: { headers: idempotentHeaders, body: { content: json(CustodyHandoverRequest) } },
  responses: {
    200: { description: 'Devir tamam', content: json(CustodyHandoverResponse) },
    ...mutationErrors,
  },
});

registry.registerPath({
  method: 'get',
  path: '/v1/support/tickets',
  tags: ['Support'],
  summary: 'Destek kayitlari',
  security: [{ [bearerAuth.name]: [] }],
  request: { query: CustodyListQuery.omit({ type: true }), headers: clientHeaders },
  responses: {
    200: { description: 'Kayit listesi', content: json(SupportTicketListResponse) },
    ...authedErrors,
  },
});

registry.registerPath({
  method: 'post',
  path: '/v1/support/tickets',
  tags: ['Support'],
  summary: 'Destek kaydi ac',
  security: [{ [bearerAuth.name]: [] }],
  request: { headers: idempotentHeaders, body: { content: json(SupportTicketCreateRequest) } },
  responses: { 201: { description: 'Kayit acildi', content: json(SupportTicket) }, ...mutationErrors },
});

/* ------------------------------------------------------------------ *
 * Sync
 * ------------------------------------------------------------------ */

registry.registerPath({
  method: 'post',
  path: '/v1/sync/batch',
  tags: ['Sync'],
  summary: 'Offline kuyrugu bosalt',
  description:
    'Tekil bir olayin reddedilmesi partiyi durdurmaz; her olay icin ayri sonuc doner. ' +
    'Istemci sadece yeniden denenebilir hatalarda tekrar gonderir.',
  security: [{ [bearerAuth.name]: [] }],
  request: { headers: clientHeaders, body: { content: json(SyncBatchRequest) } },
  responses: {
    200: { description: 'Olay bazli sonuclar', content: json(SyncBatchResponse) },
    ...authedErrors,
  },
});

registry.registerPath({
  method: 'get',
  path: '/v1/sync/changes',
  tags: ['Sync'],
  summary: 'Sunucudan degisiklikleri cek',
  security: [{ [bearerAuth.name]: [] }],
  request: { query: SyncPullQuery, headers: clientHeaders },
  responses: { 200: { description: 'Delta', content: json(SyncChanges) }, ...authedErrors },
});

/* ------------------------------------------------------------------ *
 * Notifications
 * ------------------------------------------------------------------ */

registry.registerPath({
  method: 'get',
  path: '/v1/notifications',
  tags: ['Notifications'],
  summary: 'Kurye bildirim kutusunu getir',
  security: [{ [bearerAuth.name]: [] }],
  request: { headers: clientHeaders },
  responses: { 200: { description: 'Kutu', content: json(NotificationListResponse) }, ...authedErrors },
});

registry.registerPath({
  method: 'post',
  path: '/v1/notifications/read',
  tags: ['Notifications'],
  summary: 'Bildirimleri okundu isaretle',
  security: [{ [bearerAuth.name]: [] }],
  request: { headers: clientHeaders, body: { content: json(NotificationReadRequest) } },
  responses: { 204: { description: 'Kaydedildi' }, ...authedErrors },
});

registry.registerPath({
  method: 'post',
  path: '/v1/notifications/dispatch',
  tags: ['Notifications'],
  summary: 'Panelden kuryeye bildirim yaz ve FCM gonder',
  security: [{ [serviceAuth.name]: [] }],
  request: { body: { content: json(NotificationDispatchRequest) } },
  responses: {
    201: { description: 'Yazildi', content: json(CourierInboxItem) },
    ...mutationErrors,
  },
});

/* ------------------------------------------------------------------ *
 * Document
 * ------------------------------------------------------------------ */

export function buildOpenApiDocument(): OpenAPIObject {
  const generator = new OpenApiGeneratorV31(registry.definitions);

  return generator.generateDocument({
    openapi: '3.1.0',
    info: {
      title: 'Dijigoo Kurye Mobil API',
      version: '1.0.0-draft.2',
      description: [
        'Dijigoo Kurye saha uygulamasinin mobil API sozlesmesi.',
        '',
        'Iki urun, bir kimlik: web (kurye.dijigoo.com) onboarding tasir;',
        'mobil saha operasyonunu tasir. Ayni Next.js ailesinde yasir.',
        '',
        '## Namespace',
        '',
        '- Mobil token API: `https://kurye.dijigoo.com/api/mobile` + bu belgedeki `/v1/*`',
        '  (tam yol `/api/mobile/v1/...`).',
        '- Web cookie session (`dijigoo_courier_session`) dokunulmaz; mobil kullanmaz.',
        '- Web public API (`/api/public/v1/courier-*`) kimlik kaynagi olarak devralinir.',
        '- Iki OTP havuzu: kurye aktivasyon (`courierId`) ≠ alici teslim (`taskId+phone`).',
        '',
        '## Sozlesme kurallari',
        '',
        '- Tum tarih alanlari RFC 3339, UTC ve acik offsetli.',
        '- Tum mutasyon istekleri `Idempotency-Key` basligi tasir. Ayni anahtarla',
        '  gelen tekrar istegi ilk yanitin aynisini doner.',
        '- Gorev mutasyonlari `rowVersion` tasir; uyusmazlik 409 VERSION_MISMATCH.',
        '- Hata govdesi her zaman `application/problem+json` ve `ErrorResponse` semasidir.',
        '- Sayfalama imlec tabanlidir; `nextCursor` null ise son sayfadir.',
        '- Surumleme yol tabanlidir (`/v1`). Kirici degisiklik yeni yol acar.',
        '- Workflow adim tipleri kapali enum. v1 renderer: PHOTO_EVIDENCE ve FORM.select.',
        '- Vardiya fotografi yuz eslestirme yapmaz (KVKK m.6); `shiftFaceMatch=false`.',
      ].join('\n'),
      contact: { name: 'Dijigoo teknik ekip' },
    },
    servers: [
      { url: 'https://kurye.dijigoo.com/api/mobile', description: 'Uretim — ayni Next.js' },
      { url: 'http://localhost:3000/api/mobile', description: 'Yerel panel' },
      { url: 'http://localhost:3001', description: 'Sozlesme taslagi (Fastify, urun degil)' },
    ],
    tags: [
      { name: 'Config', description: 'Zorunlu guncelleme ve feature flag' },
      { name: 'Auth', description: 'Aktivasyon, cihaz baglama, token — cookie yok' },
      { name: 'Identity', description: 'Web onboarding kayitlarinin mobil devri' },
      { name: 'Shift', description: 'Vardiya, konum, rota' },
      { name: 'Routing', description: 'Servisler-arasi: jetlogi-panel icin rota/gecikme karari' },
      { name: 'Workflow', description: 'Dinamik islem sihirbazi tanimlari' },
      { name: 'Task', description: 'Gorev listesi, detay, adimlar, sonuclandirma' },
      { name: 'Media', description: 'Kanit yukleme' },
      { name: 'Custody', description: 'Zimmet (v1.1)' },
      { name: 'Support', description: 'Destek kayitlari (v1.1)' },
      { name: 'Sync', description: 'Offline senkronizasyon' },
    ],
    security: [{ bearerAuth: [] }],
  });
}
