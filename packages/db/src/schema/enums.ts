import { pgEnum } from 'drizzle-orm/pg-core';

/**
 * Enum values mirror the Zod unions in `@dijigoo/contracts` one-for-one. When
 * one changes the other must change in the same commit; the type test in
 * `test/enum-parity.test.ts` fails otherwise.
 */

export const courierStatus = pgEnum('courier_status', ['active', 'suspended', 'terminated']);

export const devicePlatform = pgEnum('device_platform', ['android', 'ios']);

export const integrityAction = pgEnum('integrity_action', ['allow', 'restrict', 'review']);

export const shiftStatus = pgEnum('shift_status', ['active', 'paused', 'closed']);

export const taskType = pgEnum('task_type', ['DELIVERY', 'PICKUP', 'RETURN', 'SERVICE', 'DOCUMENT']);

export const taskStatus = pgEnum('task_status', [
  'ASSIGNED',
  'ACCEPTED',
  'EN_ROUTE',
  'ARRIVED',
  'IN_PROGRESS',
  'COMPLETED',
  'FAILED',
  'CANCELLED',
]);

export const taskPriority = pgEnum('task_priority', ['normal', 'high', 'urgent']);

export const stepStatus = pgEnum('step_status', ['completed', 'skipped']);

export const stepType = pgEnum('step_type', [
  'INSTRUCTION',
  'GEOFENCE_CHECK',
  'BARCODE_SCAN',
  'PHOTO_EVIDENCE',
  'DOCUMENT_SCAN',
  'FORM',
  'CHECKLIST',
  'OTP_VERIFY',
  'SIGNATURE',
  'CASH_COLLECT',
  'IDENTITY_CAPTURE',
]);

export const workflowStatus = pgEnum('workflow_status', ['draft', 'published', 'archived']);

export const mediaKind = pgEnum('media_kind', [
  'photo',
  'document_page',
  'document_pdf',
  'signature',
  'audio',
]);

export const mediaState = pgEnum('media_state', ['pending', 'uploaded', 'verified', 'rejected', 'purged']);

export const custodyItemType = pgEnum('custody_item_type', ['parcel', 'document', 'cash', 'equipment']);

export const custodyDirection = pgEnum('custody_direction', ['handover', 'takeover']);

export const counterpartyKind = pgEnum('counterparty_kind', [
  'courier',
  'branch',
  'customer',
  'warehouse',
]);

export const supportCategory = pgEnum('support_category', [
  'APP_ISSUE',
  'ADDRESS_PROBLEM',
  'RECIPIENT_UNREACHABLE',
  'VEHICLE',
  'ACCIDENT',
  'SECURITY',
  'PAYMENT',
  'OTHER',
]);

export const supportStatus = pgEnum('support_status', ['open', 'in_progress', 'resolved', 'closed']);

export const supportPriority = pgEnum('support_priority', ['low', 'normal', 'high', 'critical']);

export const routeMode = pgEnum('route_mode', ['sequence_only', 'distance_optimized', 'traffic_aware']);

export const outboxState = pgEnum('outbox_state', ['pending', 'dispatched', 'failed', 'dead']);

export const otpPurpose = pgEnum('otp_purpose', ['activation', 'task_delivery', 'phone_change']);

export const otpChannel = pgEnum('otp_channel', ['sms', 'ivr']);

export const actorType = pgEnum('actor_type', ['courier', 'operator', 'system', 'integration']);

/**
 * Canonical İş Emri (WO) codes — DIJIGOO_NIHAI_BACKEND_SISTEM_MIMARISI_V2.docx
 * §37/§4, sheet "03 İŞ EMRİ". The code is permanent; the customer-facing
 * label maps from it separately and can change without touching this enum.
 */
export const workOrderStatusCode = pgEnum('work_order_status_code', [
  'WO-010', // Kayıt Alındı
  'WO-020', // Doğrulama Bekliyor
  'WO-030', // Düzeltme Bekliyor
  'WO-040', // Doğrulandı
  'WO-050', // Kural Seti Atandı
  'WO-060', // Operasyon Planlandı
  'WO-070', // Aktif
  'WO-080', // Beklemede
  'WO-090', // İptal Talebi Alındı
  'WO-100', // Tamamlanma Kontrolünde
  'WO-110', // Tamamlandı
  'WO-120', // İptal Edildi
  'WO-130', // Reddedildi
  'WO-140', // Arşivlendi
]);

/**
 * Canonical Ürün/Stok/Zimmet (PRD) codes — same source, sheet
 * "06 ÜRÜN-STOK-ZİMMET". Faz 2 (~/.claude/plans/toasty-mixing-adleman.md):
 * PRD-010..070 (depo/stok/rezervasyon/eşleme) and PRD-200/210 (tazmin
 * mutabakatı) are in the catalog for completeness but have no wiring yet —
 * the first needs a depot/warehouse actor this codebase's auth does not
 * have, the second is financial resolution, out of this codebase's scope
 * per the 2026-08-28 scope decision. PRD-080..190 are wired.
 */
export const productStatusCode = pgEnum('product_status_code', [
  'PRD-010', // Ürün Bekleniyor
  'PRD-020', // Teslim Alındı
  'PRD-030', // Kontrol Bekliyor
  'PRD-040', // Stoğa Alındı
  'PRD-050', // Stoktan Ayrıldı
  'PRD-060', // Rezerve Edildi
  'PRD-070', // Eşlendi
  'PRD-080', // Şubeye Transfer
  'PRD-090', // Şubede Teslim Alındı
  'PRD-100', // Kuryeye Zimmet
  'PRD-110', // Sahada
  'PRD-120', // Teslim Edildi
  'PRD-130', // Şubeye Döndü
  'PRD-140', // İade İçin Hazır
  'PRD-150', // İade Sevk Edildi
  'PRD-160', // İade Teslim Edildi
  'PRD-170', // Karantina
  'PRD-180', // Hasarlı
  'PRD-190', // Kayıp
  'PRD-200', // Tazmin Sürecinde
  'PRD-210', // Tazmin Kapandı
]);

/**
 * Canonical Evrak/Arşiv (DOC) codes — sheet "07 EVRAK-ARŞİV". Faz 3
 * (~/.claude/plans/toasty-mixing-adleman.md): only DOC-070 (İmzalandı) and
 * DOC-080 (Sahada İmzalandı) are wired — reached when a courier completes a
 * SIGNATURE / DOCUMENT_SCAN workflow step. The customer-approval
 * (DOC-170..190) and merkez/arşiv (DOC-100..160, 200..220) segments have no
 * producer yet — they need a customer or back-office actor this codebase's
 * courier-only auth does not have.
 */
export const documentStatusCode = pgEnum('document_status_code', [
  'DOC-010', // Evrak Bekleniyor
  'DOC-020', // Basım Bekliyor
  'DOC-030', // Oluşturuldu
  'DOC-040', // Basılı
  'DOC-050', // Kuryeye Zimmet
  'DOC-060', // Dijital İmza Bekliyor
  'DOC-070', // İmzalandı
  'DOC-080', // Sahada İmzalandı
  'DOC-090', // Şubeye Döndü
  'DOC-100', // Merkeze Sevk
  'DOC-110', // Merkezde Teslim Alındı
  'DOC-120', // Kontrol Bekliyor
  'DOC-130', // Eksik Evrak - Alıcı Kaynaklı
  'DOC-140', // Eksik Evrak - Operasyon Kaynaklı
  'DOC-150', // Tamamlama Bekliyor
  'DOC-160', // Onaylandı
  'DOC-170', // Müşteri Onayı Bekliyor
  'DOC-180', // Müşteri Onayladı
  'DOC-190', // Müşteri Reddetti
  'DOC-200', // Arşivlendi
  'DOC-210', // Müşteriye Teslim
  'DOC-220', // Süresi Doldu
]);

/**
 * Canonical Kalite/Kontrol (QUA) codes — sheet "10 KONTROL-UYGUNLUK". Only
 * the "Otomatik" control policy is wired (docx §2.1 lists Otomatik /
 * operasyon kalite kontrolü / müşteri onayı as the three project-level
 * options): a delivery result that passed this codebase's existing
 * evidence-completeness check (`missingRequiredSteps` in `@dijigoo/core`,
 * already required before a task can finalize) is recorded straight at
 * QUA-070 — the check already happened, this just gives it a canonical
 * record. Manual/uzman review (QUA-040..090) needs an operator actor this
 * codebase does not have.
 */
export const qualityReviewStatusCode = pgEnum('quality_review_status_code', [
  'QUA-010', // Kontrol Bekliyor
  'QUA-020', // Otomatik Kontrolde
  'QUA-030', // Otomatik Onay
  'QUA-040', // Uzman Kontrolünde
  'QUA-050', // Düzeltme Gerekli
  'QUA-060', // Düzeltme Görevi Açıldı
  'QUA-070', // Onaylandı
  'QUA-080', // Reddedildi
  'QUA-090', // İtiraz Bekliyor
  'QUA-100', // Teknik Hata
]);

/**
 * Canonical İade/Ters Lojistik (RET) codes — sheet "08 İADE-TERS LOJİSTİK".
 * Faz 4 (~/.claude/plans/toasty-mixing-adleman.md): only RET-010 (İade
 * Kararı Bekliyor — entered automatically when a delivery fails and the
 * courier still physically holds the item) and RET-070 (İade Teslim Edildi
 * — entered when that item is later handed to a branch/warehouse, the
 * existing custody handover flow from Faz 2) are wired. Everything between
 * needs an explicit customer/warehouse decision or transit tracking this
 * codebase's courier-only auth cannot produce; mutabakat (RET-090..110) is
 * financial reconciliation, out of scope per the 2026-08-28 decision.
 */
export const returnStatusCode = pgEnum('return_status_code', [
  'RET-010', // İade Kararı Bekliyor
  'RET-020', // İade Talimatı Alındı
  'RET-030', // İade İçin Hazırlanıyor
  'RET-040', // İade Sevk Hazır
  'RET-050', // İade Yola Çıktı
  'RET-060', // İade Noktasına Ulaştı
  'RET-070', // İade Teslim Edildi
  'RET-080', // İade Teslim Edilemedi
  'RET-090', // Mutabakat Bekliyor
  'RET-100', // Fark İncelemede
  'RET-110', // Mutabakat Tamamlandı
]);

/**
 * Canonical SLA/İstisna codes — sheet "13 SLA-İSTİSNA". Faz 4: only the
 * synchronous states are wired — SLA-010 (Başladı, when a target exists —
 * `tasks.slotEndAt`) and the resolution at finalize time, SLA-050 (Karşılandı)
 * or SLA-060 (İhlali). SLA-030 (Riskte) needs something watching the clock
 * *without* an incoming request to notice a deadline approaching — this API
 * is purely request-driven, no background worker exists (`apps/worker` is
 * an empty placeholder per docs/02-master-plan.md), so it is never entered.
 */
export const slaStatusCode = pgEnum('sla_status_code', [
  'SLA-010', // SLA Başladı
  'SLA-020', // SLA İşliyor
  'SLA-030', // SLA Riskte
  'SLA-040', // SLA Durdu
  'SLA-050', // SLA Karşılandı
  'SLA-060', // SLA İhlali
  'SLA-070', // İhlal İncelemede
  'SLA-080', // Ceza Uygulanacak
  'SLA-090', // Ceza Muaf
  'SLA-100', // İhlal Kapatıldı
]);

/**
 * Canonical Teslimat Sonucu (DLV) codes — same source, sheet
 * "05 TESLİMAT SONUCU". 7 successful recipient types + 12 standard failure
 * reasons + 3 process states (kısmi/kontrol/onay).
 */
export const deliveryResultCode = pgEnum('delivery_result_code', [
  'DLV-010', // Teslim Edildi - Kendisi
  'DLV-020', // Teslim Edildi - Birinci Derece Yakını
  'DLV-030', // Teslim Edildi - Vekili / Yetkilisi
  'DLV-040', // Teslim Edildi - İşyeri Yetkilisi
  'DLV-050', // Teslim Edildi - Güvenlik / Muhaberat
  'DLV-060', // Teslim Edildi - Kurum Yetkilisi
  'DLV-070', // Teslim Edildi - Diğer İzinli Kişi
  'DLV-080', // Teslim Edilemedi - Alıcıya Ulaşılamadı
  'DLV-090', // Teslim Edilemedi - Hatalı / Yetersiz Adres
  'DLV-100', // Teslim Edilemedi - Taşınmış / Tanınmıyor
  'DLV-110', // Teslim Edilemedi - Alıcı Kabul Etmedi
  'DLV-120', // Teslim Edilemedi - Kalıcı Kapalı
  'DLV-130', // Teslim Edilemedi - Kapalı / Saat Dışı
  'DLV-140', // Teslim Edilemedi - Randevu / İleri Tarih
  'DLV-150', // Teslim Edilemedi - Kimlik / OTP Sorunu
  'DLV-160', // Teslim Edilemedi - Hasarlı / Sorunlu Gönderi
  'DLV-170', // Teslim Edilemedi - Vefat
  'DLV-180', // Teslim Edilemedi - Mücbir / Operasyonel Engel
  'DLV-190', // Teslim Edilemedi - Diğer / Merkez Desteği
  'DLV-200', // Kısmi Tamamlandı
  'DLV-210', // Kontrol Bekliyor
  'DLV-220', // Sonuç Onaylandı
]);
