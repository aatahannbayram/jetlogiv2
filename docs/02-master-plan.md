# Dijigoo Kurye Mobil — Master Plan

**Tarih:** 25.08.2026  
**Kaynaklar:** Kabul Dokümanı V3.0 · kurye.dijigoo.com canlı panel · teknik analiz HTML · mevcut Dijigoo monorepo  
**Durum:** Karar kilidi — Hande onayı + developer sprint 1

---

## 1. Tek cümle

Flutter ile çıkıyoruz. Haberleşme zor değil. Gecikme riski kapsamda. Canlı web kurye **kimliğini** taşır; mobil kurye **sahasını** taşır. İkisini aynı Next.js API ailesinde birleştiririz — ikinci bir backend evreni açmayız.

## 2. Kilitlenen kararlar

| Konu | Karar |
|---|---|
| Mobil teknoloji | Flutter (Riverpod, Drift+SQLCipher, dio, freezed, feature-first) |
| Panel / kimlik kaynağı | Mevcut `kurye.dijigoo.com` (Next.js). Cookie session **dokunulmaz**. |
| Mobil API | Aynı uygulamada yeni namespace: `/api/mobile/v1/*`. Token (15 dk access + rotating refresh, `deviceId` bağlı). |
| Sözleşme | OpenAPI 3.1 tek kaynak. Mevcut `@dijigoo/contracts` ve workflow JSON Schema **taşınır**, sıfırdan yazılmaz. |
| Protokol | REST. GraphQL/gRPC Faz 1'de yok. |
| Gerçek zamanlı | FCM/APNs + delta pull. WebSocket v1'de yok. |
| Medya | Presigned S3/R2, chunked + resumable. Next.js gövdesinden geçmez. |
| Pilot kapsam | 16 modül, ~4 ay (2 mobil + 1 backend + 0,5 QA) |
| Tam V3.0 Faz 1 | 30 modül ≈ 9–12 ay — pilota alınmaz |

## 3. İki ürün, bir kimlik

Canlı web **onboarding / uyumluluk** ürünüdür: başvuru, belge, sözleşme, müsaitlik, hesap. Teslimat, depo, finans menüde durur; API'si yoktur.

Mobil **saha operasyonu** ürünüdür: görev, sihirbaz, OTP, fotoğraf, offline, geofence.

Köprü:

```
Başvuru → belgeler/onaylar → CONVERTED_TO_COURIER
         → courierId + DGC-kodu + hesap
         → mobil aktivasyon (OTP + cihaz bağlama)
         → /api/mobile/v1 görev, vardiya, kanıt, sync
```

Müsaitlik (`/api/public/v1/courier-availability`) üretimde. Mobil bunu **devralır**.

## 4. Pilot çekirdek (16 modül)

**v1 — kurye sahada iş bitirir**

M01 Splash / zorunlu güncelleme · M02 Aktivasyon · M03 İzin/cihaz · M04 Dashboard · M05 Dağıtım listesi · M06 Rota (liste + harici navigasyon) · M07 Görev detayı · M08 Maskeli arama (CPaaS) · M09 İşleme başla · M10 Dinamik sihirbaz · M11 OTP · M12 Fotoğraf kanıtı · M16 Teslim sonucu · M17 Teslim edilemedi · M18 Bitir/gönder · M24 Offline/senkron

Minimum v1'de: açık zimmet uyarısı + tek tuş merkez arama (tam M19/M21 ekranları v1.1).

**v1.1 (4–6 hafta sonra):** M13 evrak tarama · M19 zimmet · M21 destek · M22 bildirim merkezi · M25 QR · M26 barkod/geocode

**Ertele:** M14 kimlik/KYC · M20 eğitim · M27 hakediş · M28 duyuru · M29 anket · Bölüm 19 ETA/IVR motoru · gelişmiş rota

## 5. Workflow — beş bağlayıcı kural

1. Adım tipleri kapalı enum (~10). Panel yeni tip uyduramaz.
2. `validationSchema` JSON Schema; Dart ve sunucu aynı şema.
3. Snapshot immutable: görev başladığı sürümle biter.
4. Mobil doğrulama yalnız UX; `precheck` sunucuda tekrar çalışır.
5. Bilinmeyen tip = görevi açma + “uygulamayı güncelle”.

Önce `photo` ve `select` gerçek; kalan tipler mekanik.

## 6. Auth modeli

Panel: `dijigoo_courier_session` / `jetdiji_admin_session` httpOnly cookie — kalır.

Mobil: `/api/mobile/v1/auth/*` — access JWT 10–15 dk, refresh rotation, `deviceId` + `installationId` bağlama, uzaktan iptal. Cookie ile prototip **yok**.

İki OTP havuzu: kurye login ≠ alıcı teslim (`courierId` vs `taskId+phone`).

## 7. Takvim (~16–18 hafta)

| Hafta | Ne |
|---|---|
| 1 | OpenAPI kilidi, outbox, token auth iskeleti, kapalı step enum, `GET /config` |
| 2–5 | Aktivasyon, cihaz, izin, müsaitlik devri, görev listesi/detay |
| 6–9 | Sihirbaz (`photo`/`select`), OTP, teslim, fotoğraf, presigned medya |
| 10–13 | Offline drenaj, geofence, maskeli arama webhook, dashboard |
| 14–16 | UAT, saha turu, mağaza |

Kritik yol: mobil auth + BFF, sonra workflow motoru, sonra Flutter 16 modül.

## 8. Üç kırmızı risk

1. Cookie session mobilde çalışmaz — token BFF her şeyi bloklar.
2. Evrak tarama hazır paketlerle UAT-26'yı geçmez — v1.1 / ticari SDK.
3. Arka plan konum iOS'ta native'de de aynı — ücretli plugin bütçesi.

## 9. Dokümanda düzeltilmesi gerekenler

1. Bildirim dedupe'dan `routeVersion` çıksın.
2. `taskStatus` ve `custodyStatus` ayrı makineler.
3. Geofence 150–250 m + `accuracy > 100 m` red.
4. UAT-05 CPaaS webhook'tan; mobilden arama kanıtı yok.
5. v1 vardiya fotoğrafı otomatik yüz eşleştirme yok (KVKK m.6).
6. Login OTP ve teslim OTP ayrı rate-limit.

## 10. Mevcut kod ne olacak

`/Users/macbookpro/Desktop/Dijigoo` içindeki `@dijigoo/contracts`, workflow JSON Schema, core validator, Drizzle taslağı **atılmaz**. Next.js mobil BFF'ye taşınır veya paket olarak bağlanır. Ayrı Fastify süreci ürün olarak yaşamaz; sözleşme ve iş kuralı yaşar.

## 11. Hande'den kararlar

1. Bağlayıcı doküman: V3.0.
2. Pilot = 16 modül / 4 ay onayı.
3. Panel ekibi `/api/mobile/v1` sözleşmesine uyar (veya BFF'yi biz aynı repoda yazarız).
4. Arka plan konum plugin lisansı + mağaza hesapları.
5. KVKK: vardiya fotoğrafı yalnız kanıt, eşleştirme yok.
6. SMS / maskeli arama sağlayıcı tedariki bu hafta başlar.

## 12. Developer — bu hafta (ertelenince yeniden yazım)

1. OpenAPI 3.1 kilidi + Dart codegen CI.
2. Outbox + `Idempotency-Key` — her yazma bu kuyruktan.
3. Workflow step enum; `photo` + `select` renderer.
4. Token auth ilk günden.
5. Feature flag + zorunlu güncelleme (`GET /config`).
