# jetlogi-panel entegrasyonu

**Tarih:** 05–06.09.2026 · **Güncelleme:** 07.09.2026 (ana plan + Linear + Cursor audit prompt)
**Kaynaklar:** **asıl** `git@github.com:kukaraca/dijigoo-ops.git` · ayna `git@github.com:JetLogiPro/jetlogi-panel.git` (1 commit geride) · bu repo `apps/api` + `apps/mobile`
**Kesim:** Mobil → panel `public/v1/courier-*`. Eksik uçlar panel reposunda. Routing gibi bize özgü parçalar `apps/api`’de kalır.
**Üçüncü sistem (kurye değil):** eski B2B `https://api.jetlogi.net` — ayrıntı [`docs/06-eski-panel-ve-repo-analizi.md`](06-eski-panel-ve-repo-analizi.md).
**Üst plan + takip:** [`docs/07-ana-plan.md`](07-ana-plan.md) (mobil+API+web sitesi birleşik yol haritası) — canlı takip artık Linear'da: [Panel Entegrasyonu (jetlogi-panel)](https://linear.app/flexlore/project/panel-entegrasyonu-jetlogi-panel-4e56684b93a0), [Kurumsal Web Sitesi](https://linear.app/flexlore/project/kurumsal-web-sitesi-4b843cabf90c). **Bu dosya artık güncel durumun tek kaynağı değil — Linear'a bakılmalı.**

---

## 0. Genel tablo (07.09.2026 — Linear'daki JETLOG-15..27 ile eşleşiyor)

| Faz | Ne | Durum | Linear |
|---|---|---|---|
| **1** — Mobil spike + auth/offline keşif | Görev ekranlarının başlangıçta backend’siz olduğu bulundu. `PanelApi` + `panel_models.dart` (11 test) hazır | **Bitti.** "Sıfırdan mobil" = mevcut `apps/mobile` (kullanıcı onayı, 07.09) — `session.dart`'a bağlanmadı, kasıtlı bekletme | JETLOG-20, 21 |
| **2** — Finalize / proof / delay-decision | Panel reposu. `applyShipmentWorkflowEvent` + gerçek `eventCode`/`contextPatch` düzeltmeleri iletildi | **Panelde, kontrol Cursor'da.** 06.09'da `finalize` HEAD `5a75437`'de yoktu; 07.09'da Cursor'a durum-kontrolü+tamamlama prompt'u verildi (§2'deki düzeltmelerle aynı), rapor bekleniyor | JETLOG-17 (High) |
| **3** — Custody portu | Spec + paste-ready prompt (§7) | **Cursor'a iletildi (07.09), rapor bekleniyor.** Aynı audit prompt'un parçası | JETLOG-18 |
| **3b** — Kurye destek ticket ucu | `SupportTicket` şeması hazır, courier-facing uç yok | **Cursor'a iletildi (07.09), rapor bekleniyor** | JETLOG-19 |
| **4** — Routing proxy | `POST /v1/routing/optimize`, test, OpenAPI | **Bitti** | JETLOG-27 (Done) |
| **5** — Vardiya / offline senkron (panel modeli) | Panelde konsept yok | **Durdu.** Ürün kararı | — |
| **6** — Eski `apps/api` sünümü | Görev/sync yüzeyini kapatmak | **Durdu.** 2/3/5 bitmeden yok | JETLOG-22 |

**OpenAPI:** `packages/contracts` registry — **31 yol, 75 şema** (`/v1/routing/optimize` + mevcut `/v1/tasks/:taskId/delay-decision` kayıtlı).

**Blokaj (4'ü Linear'da ACIK issue olarak açık):**
1. Kimlik: OTP+bearer vs panel `courier-auth` cookie-session — JETLOG-15 (ACIK-7)
2. Not görünürlüğü / manuel override ihtiyacı (panel ekibiyle netleşmeli) — JETLOG-16 (ACIK-8)
3. Test edilebilir canlı veya local panel sunucusu — Linear'da ayrı issue yok, `docs/06` §5.4'te not
4. Panel `finalize`/`custody`/`ticket` bitip bitmediğinin teyidi — **07.09'da Cursor'a durum-kontrolü prompt'u verildi, rapor geldiğinde bu satır ve ilgili Linear issue'ları güncellenecek**

**Bu sohbet / Cursor (aynı Dijigoo repo, panel-geçiş fazı değil):** üretim mobil `apps/api` üzerinden sertleşti — canlı `GET /v1/tasks`, outbox finalize/transition, iptal, destek sayfalama, `GET /v1/sync/changes` watermark, vardiya `SHIFT_START/END`, `GET /v1/shifts/current` ile process-kill sonrası açık vardiya geri yükleme. Bunlar Faz 1–6 kesiminin yerine geçmez; `PanelApi` hâlâ session dışı.

**Üç sistem (karışmasın):** (1) kurye-mobil + bu repo `apps/api`, (2) `dijigoo-ops` `public/v1/courier-*` + Integration Hub, (3) eski `api.jetlogi.net` `ShipmentsService` (kurumsal B2B, body içinde `auth.userName/password`). (3) kurye kesiminin parçası değil; Hub onu `CorporateIntegrationServices.tsx` ile 13/13 eşliyor. Kaynak inceleme bundan sonra `kukaraca/dijigoo-ops`, `JetLogiPro/jetlogi-panel` değil.

**Sıradaki gerçek ilerleme:** Cursor'un finalize/custody/ticket audit+tamamlama raporu, veya kalan 3 blokajdan (auth, not-görünürlüğü, canlı panel) birinin açılması. Web sitesi tarafı tamamen ayrı ve netleşmedi (bkz. `docs/07-ana-plan.md` §3, Linear "Kurumsal Web Sitesi").

---

## 1. Karar (netleşti)

Mobil uygulama veri kaynağı olarak **jetlogi-panel**'in (`dijigoo-ops`, Next.js 16 + Prisma 7 + PostgreSQL) `public/v1/courier-*` API'sini kullanacak. Panel/admin/portal tarafını başka bir ekip yönetiyor; biz kurye-mobil API yüzeyinde eksik kalan uçları **aynı repoda, onun kendi kurallarına göre** (canonical status/reason code, event-tabanlı yazma, tenant/RBAC scope, `$transaction` içinde audit+projection) yazıyoruz.

Bu, [[project-nihai-mimari-plan]]'ın 2026-08-28 "Panel = diğer ekibin işi" kararının **gözden geçirilmiş hali**: panel sadece admin UI değil, kendi kurye-auth + kurye-mobil task API'sini de içeriyormuş — bu yüzden "hangi API'yi kim yazıyor" ayrımı endpoint bazında yeniden çizildi (bkz. §2).

Tam uç-uca karşılaştırma ve fazlı plan: **[Panel Entegrasyon Haritası](https://claude.ai/code/artifact/23a5a089-2017-43cf-ac1b-aa861f77cb15)** (yayınlanmış artifact, bu oturumda üretildi).

---

## 2. Uç-uca özet (detay artifact'ta)

| Alan | Durum |
|---|---|
| Kurye başvuru/onboarding, `courier-tasks` liste/detay/accept/start/location | **Panelde hazır ve gerçek** — doğrudan kullan |
| Teslimat sonucu (finalize), kanıt (imza/foto), gecikme kararı | **Panelde yok — biz yazıyoruz.** Cursor şu an `courier-tasks/:id/finalize`'ı panel reposunda yazıyor |
| Custody/zimmet API'si | **Panelde yok.** Ayrıca README §10'un tarif ettiği `CustodyTransfer`/`ShipmentCustodyState` modelleri şemada henüz yok — doküman-kod uyuşmazlığı |
| Kurye-taraflı destek ticket'ı | `SupportTicket` şeması hazır, courier-facing public/v1 ucu yok — biz yazacağız |
| Vardiya/sürekli konum takibi | Panelde konsept yok — ürün kararı bekliyor |
| Offline/çevrimdışı senkron | Panelde konsept yok — ürün kararı bekliyor, bkz. §4 |
| Kimlik doğrulama modeli | **Çelişki** — bkz. §4 |
| Rota optimizasyonu (OSRM + 2-opt) | Çakışmıyor — panelin "routing"i kural-bazlı atama, bizimki coğrafi sıralama. Ayrı servis olarak kalır |

### Cursor'a finalize için verilen düzeltmeler (kod okunarak doğrulandı)

`accept`/`start` route'ları incelendi — ortak bir domain/validator katmanı yok, her dosya kendi içinde inline. Asıl reusable parça `applyShipmentWorkflowEvent` (`src/modules/workflow/runtime/product-workflow-runtime.ts`):

- `eventCode` sabit: `"DELIVERY_RESULT_RECORDED"` (başarılı/başarısız için aynı, dallanmayı `contextPatch.shipment.deliveryResult` belirliyor).
- Başarılı: `contextPatch: { shipment: { deliveryResult: "DELIVERED", deliveredAt } }`
- Başarısız: `contextPatch: { shipment: { deliveryResult: "FAILED", reasonCode, attemptCount } }`
- Referans (gerçek, çalışan test scriptleri — spec olarak kullanılabilir): `scripts/test-hgs-workflow-delivered-event-v1.ts`, `scripts/test-hgs-workflow-return-redelivery-branch-v1.ts`
- **Önemli nüans:** "FAILED" tek adımda terminal değil — 1. hatada state `REDELIVERY`'ye düşüyor, sonraki hatada `RETURN_PROCESS`'e geçiyor. Motor karar veriyor, route bunu varsaymamalı.
- Idempotency konvansiyonu: tekrar çağrıda 409 değil, mevcut `accept`/`start` paterni gibi 200 + `alreadyX:true`.
- Status/reason code'ları doğrulayan bir Prisma enum yok — `ShipmentStatusDefinition`/`ShipmentReasonDefinition`/`ShipmentStatusReason` DB tabloları + `ShipmentStatusReasonPolicy` enum (NONE/OPTIONAL/REQUIRED), `applyShipmentWorkflowEvent` içinde otomatik doğrulanıyor.

---

## 3. Faz 1 spike bulgusu — `apps/mobile` (05.09) ve sonrası (06.09)

**05.09 spike:** görev ekranları backend’sizdi; `session` sabit `t1`–`t4`. Panel kesimi sıfırdan kurulacak, taşınacak canlı entegrasyon yoktu.

**06.09 üretim Fastify (panel kesimi değil):** `session` artık `GET /v1/tasks` + `GET /v1/sync/changes` çekiyor; teslim/iade outbox → Fastify `transition`/`finalize`; destek ve vardiya start/end kuyrukta. Demo tohum yalnız fallback. Yazmalar hâlâ `/v1/sync/batch` (apps/api) — panele geçiş “listPath değiştir” değil (Açık Karar #2).

**Hâlâ doğru:** `PanelApi` session’a bağlı değil. Hedef satırlar aşağıda.

### Mevcut yerel aksiyon → hedef panel ucu

| `session.dart` metodu | Şu an | Hedef |
|---|---|---|
| `startTask(id)` | Sadece local state, hiçbir yere gitmiyor | `POST courier-tasks/:id/accept` + `POST .../start` |
| `deliverTask(id, {receivedBy})` | `outbox.enqueue(taskFinalize, {outcome:'DELIVERED'})` → `/v1/sync/batch` (bizim eski API) | `POST courier-tasks/:id/finalize` (Cursor yazıyor) |
| `returnTask(id, {reason, note})` | `outbox.enqueue(taskTransition, {outcome:'RETURNED', reason})` | Aynı finalize ucu, `deliveryResult:'FAILED', reasonCode` |
| `failTask(id)` | Sadece "çevrimdışıya düş" simülasyonu | Offline senaryoya bağlı, bkz. §4 |

`SyncOperation` enum'ı (`models.dart:190`): `shiftStart, shiftEnd, taskTransition, stepSubmit, taskFinalize, custodyHandover, supportTicketCreate` — hepsi şu anki opak-payload-batch modeline göre tasarlanmış.

---

## 4. Kapanmamış kararlar (kod yazmadan önce netleşmeli)

1. **Kimlik doğrulama modeli.** `_AuthInterceptor` bearer token header'ı ekliyor; panelin `getCurrentCourierAccount()`'ı cookie-session bekliyor (courier-auth login). Bu netleşmeden hiçbir gerçek çağrı çalışmaz — **en yüksek öncelik.**
2. **Offline/senkron modeli.** `_flushOutbox()` genel bir `SyncOperation` kuyruğunu tek `/v1/sync/batch` çağrısıyla yolluyor; panelde böyle bir toplu/opak uç yok, her aksiyon (`accept`/`start`/`finalize`) ayrı senkron REST çağrısı. Outbox client'ta kalabilir ama drain sırasında panelin spesifik uçlarına **doğru sırayla** (accept→start→finalize) tek tek POST atmalı — bu sıralama mantığı yeni yazılacak.
3. Vardiya/sürekli konum takibi gerekli mi? (Panelde konsept yok.)
4. Medya/kanıt depolama: presigned URL (bizim `/v1/media/presign` deseni) mi, panelin direkt-multipart-upload deseni mi?
5. Custody şeması: README mi, kod mu öncelikli — diğer ekiple netleştirilmeli.

---

## 5. Sıradaki adımlar (blokaj)

Bağımsız işler bitti (Faz 1 client, Faz 4 routing, Faz 3 spec, OpenAPI). Kod yazmadan önce:

1. Auth kararı (bearer vs cookie) — `session` → `PanelApi` kesiminin ön koşulu.
2. Canlı veya local panel sunucusu — kesim testi yoksa bağlama yok.
3. Panel Faz 2 finalize teyidi — yoksa yazma yolu Fastify’de kalır.
4. Faz 2/3 panelde ilerleyince: outbox drain’i accept→start→finalize sırasına çevir (Faz 6’dan önce).
5. Faz 6 (`apps/api` görev/sync sünümü) ancak 2 + 3 + 5 kapanınca.

---

## 6. Faz 4 uygulandı — routing proxy (06.09.2026)

Kendi alanımızda, blokajlardan (auth kararı, canlı panel sunucusu) bağımsız olan tek parça: rota optimizasyonunu jetlogi-panel'in çağırabileceği bir servis-arası uca çıkardım.

**Bulgu:** `apps/api/src/routes/routing.ts` (`GET /v1/routes/current`) tamamen bizim `shifts`/`tasks` tablolarımıza bağlı — panelin doğrudan tüketebileceği bir şey değil. Ama asıl motor (`services/routing.ts`'teki `RoutingProvider` — OSRM + `optimizer.ts`'teki nearest-neighbour/2-opt) zaten jenerik `{id, lat, lng}` durak listesi üzerinde çalışıyor, bizim şemamıza bağımlı değil.

**Ayrıca bulundu:** `apps/api/src/plugins/service-auth.ts` zaten var — "başka bir ekibin backend'i" (panel) için `x-service-token` header'ıyla çalışan bir auth mekanizması, şu ana kadar sadece `POST /v1/tasks/:taskId/delay-decision`'da kullanılıyormuş (Faz 5, SLA riski). Yani panelin bizi servis-arası çağırması için altyapı zaten kuruluymuş — ikinci bir kimlik sistemi icat etmeye gerek yok.

**Eklenenler:**
- `packages/contracts/src/routing-service.ts` — `RoutingOptimizeRequest`/`RoutingOptimizeResponse` (Zod, OpenAPI'ye kayıtlı)
- `apps/api/src/services/routing-optimize.ts` — `buildOptimizedRoute()`, `routing.ts`'teki mantığın DB'siz/shift'siz hali
- `apps/api/src/routes/routing-service.ts` — `POST /v1/routing/optimize`, `authenticateService` ile korunuyor (mevcut `DELAY_DECISION_SERVICE_TOKEN`'ı paylaşıyor — yorum satırında bunun artık iki uç tarafından kullanıldığı not edildi)
- `apps/api/test/routing-optimize.test.ts` — 5 yeni test (mock + sahte matrisle sıralamanın gerçekten değiştiğini kanıtlayan bir test dahil)

**Doğrulama:** Node 22 ile (`.nvmrc` — sistemin varsayılan `node`'u 18, testler bu yüzden önce patladı, `nvm use 22` gerekti) `apps/api` testleri 35/35 yeşil, `@dijigoo/contracts` build temiz, `tsc --noEmit` benim dosyalarımda sıfır hata (repoda halihazırda var olan, benim dokunmadığım 13 hata — `auth.ts`/`sync.ts`/`integrity.ts`/`storage.ts`/`packages/db/workflow.ts` — Node sürümünden bağımsız, önceden var).

**Kullanım (panel tarafı için):** `POST /v1/routing/optimize` + `x-service-token: <DELAY_DECISION_SERVICE_TOKEN>` header, gövde `{ stops: [{id, lat, lng}, ...], startAt? }` (stops[0] sabit başlangıç). Yanıt: sıralanmış duraklar + her biri için `etaAt`/`distanceMeters`/`durationSeconds` + toplam mesafe/süre + polyline geometry.

## 7. Custody (zimmet) kontrat önerisi — Faz 3 spec (06.09.2026)

Kod değil, panel ekibine/Cursor'a verilecek bir tasarım. Bizim tarafımızda gerçek, test edilmiş bir custody sistemi var (`apps/api/src/routes/custody.ts` + `services/custody-status.ts`) — bunu spec olarak kullandım. Panel tarafındaki şemayı da (scratchpad klonundan) satır satır okudum; ilk sandığımdan farklı çıktı, aşağıda o fark önemli.

### 8.1 Bizim tarafta gerçekte ne var

Kanonik **PRD (Ürün/Stok/Zimmet) kod kataloğu** — 21 sabit kod, `packages/contracts/src/custody.ts`:

```
PRD-010 Ürün Bekleniyor        PRD-080 Şubeye Transfer         PRD-150 İade Sevk Edildi
PRD-020 Teslim Alındı          PRD-090 Şubede Teslim Alındı    PRD-160 İade Teslim Edildi
PRD-030 Kontrol Bekliyor       PRD-100 Kuryeye Zimmet          PRD-170 Karantina
PRD-040 Stoğa Alındı           PRD-110 Sahada                  PRD-180 Hasarlı
PRD-050 Stoktan Ayrıldı        PRD-120 Teslim Edildi           PRD-190 Kayıp
PRD-060 Rezerve Edildi         PRD-130 Şubeye Döndü            PRD-200 Tazmin Sürecinde
PRD-070 Eşlendi                PRD-140 İade İçin Hazır         PRD-210 Tazmin Kapandı
```

Bizim kodumuz yalnızca **PRD-100/110/120/130/180/190**'ı kurye tarafından tetikliyor (`productStatusForHandover` + `transitionCustodyItem`). PRD-010..070 (depo intake) ve PRD-200/210 (tazmin) bilinçli olarak dışarıda — depo/operatör aktörü gerektiriyor, [[project-nihai-mimari-plan]]'ın 2026-08-28 kararı gereği "diğer takımın işi."

Somut akış (`custody.ts`):
- `GET /v1/custody` — kuryenin elindeki (releasedAt IS NULL) kalemler
- `POST /v1/custody/handover` — `direction: handover|takeover`, `counterparty: {kind: courier|branch|customer|warehouse}`. Handover→customer = PRD-120 (gerçek teslimat), handover→branch/warehouse = PRD-130, courier→courier = statü değişmez (sadece `holderCourierId` taşınır). Row'lar `for('update')` ile kilitleniyor (aynı parseli iki kurye aynı anda okutamasın diye), `idempotency-key` header zorunlu.
- `POST /v1/custody/:itemId/report-issue` — `kind: damaged|lost` → PRD-180/190. Sadece elindeki kalem için (`holderCourierId` kontrolü).
- Her statü değişikliği `custody_item_transitions` tablosuna audit olarak yazılıyor + outbox event.

### 8.2 Panel tarafında gerçekte ne var (README'den farklı — kontrol edildi)

`prisma/schema.prisma`'da **`CustodyTransfer`/`ShipmentCustodyState`/`InventoryUnitCustodyState` yok** (README §10 bunları listeliyor ama şemada karşılığı yok — doküman-kod uyuşmazlığı, [[project-jetlogi-panel-repo-analysis]]'te not edildi).

Var olan gerçek modeller:
- **`ShipmentInventoryHandover`** — ama bu **sadece depo→kurye teslim alışı** (`warehouseId` + `courierId`, `reservationId` `@unique` — "bir reservation fiziksel olarak yalnızca bir kez handover edilebilir"). Bizim PRD-080/090/100'e denk düşüyor, yani **tam olarak bizim de dışarıda bıraktığımız depo-intake bacağı.** Kurye→müşteri, kurye→şube, kurye→kurye devirleri için kullanılamaz.
- **`InventoryUnit.statusCode`** — serbest string ama kod içi yorumda sabit bir liste var: `AVAILABLE | RESERVED | ASSIGNED | IN_TRANSIT | DELIVERED | RETURNED | DAMAGED | LOST`. Bu bizim PRD-100/110/120/130/180/190'ın hemen hemen birebir karşılığı — **alan zaten var, sadece onu değiştirecek bir courier-facing uç yok.**

Sonuç: Panelin custody eksiği README'nin iddia ettiği "5 modelin tamamı yok" değil, daha dar ve daha kolay kapatılabilir bir eksik — **sadece kurye-tetiklemeli geçiş uçları ve onların audit/kanıt kaydı yok.**

### 8.3 Önerilen tasarım

**Teslimat (PRD-120 karşılığı) ayrı bir custody ucu istemez** — bu zaten finalize'ın işi. `courier-tasks/:id/finalize` `outcome:'DELIVERED'` yazdığında, aynı transaction içinde ilgili `InventoryUnit.statusCode`'u da `DELIVERED`'a çekmeli (varsa `ShipmentPackage`/`productDefinition.inventoryTrackingCode` üzerinden ilgili unit'i bulup). Ayrı bir "custody: teslim et" ucu **yazılmamalı** — iki ayrı uç aynı işi temsil ederse tutarsızlık riski doğar.

Gerçekten eksik olan, yeni yazılması gereken iki şey:

1. **Yeni, küçük bir audit modeli** — README'nin 5 modelli `CustodyTransfer` ailesini kurmaya gerek yok; bizim `custody_item_transitions`in birebir karşılığı kadar küçük bir şey yeter:

```prisma
model InventoryUnitCustodyEvent {
  id              String   @id @default(uuid()) @db.Uuid
  tenantId        String   @map("tenant_id")
  inventoryUnitId String   @map("inventory_unit_id") @db.Uuid
  shipmentId      String   @map("shipment_id") @db.Uuid
  courierId       String   @map("courier_id") @db.Uuid
  /// RETURNED_TO_BRANCH | DAMAGE_REPORTED | LOST_REPORTED
  eventTypeCode   String   @map("event_type_code") @db.VarChar(80)
  fromStatusCode  String   @map("from_status_code") @db.VarChar(50)
  toStatusCode    String   @map("to_status_code") @db.VarChar(50)
  warehouseId     String?  @map("warehouse_id") @db.Uuid
  note            String?  @db.Text
  occurredAt      DateTime @map("occurred_at")
  createdAt       DateTime @default(now()) @map("created_at")
  // ilişkiler: tenant/inventoryUnit/shipment/courier/warehouse, mevcut modellerle ayni desen
}
```

2. **İki yeni public/v1 ucu** (accept/start'ın aynı inline paterniyle — bkz. §2'deki düzeltmeler):

   - `POST public/v1/courier-custody/:unitId/return` — kurye elindeki kalemi şubeye/depoya iade eder. Body: `{ warehouseId, note? }`. `InventoryUnit.statusCode: ASSIGNED|IN_TRANSIT → RETURNED`, `InventoryUnitCustodyEvent(eventTypeCode: RETURNED_TO_BRANCH)` yazar. Bizim PRD-130 karşılığı.
   - `POST public/v1/courier-custody/:unitId/report-issue` — Body: `{ kind: 'damaged'|'lost', note?, photoMediaIds? }`. `InventoryUnit.statusCode → DAMAGED|LOST`, `InventoryUnitCustodyEvent` yazar. Bizim PRD-180/190 karşılığı — **`kind` sabit iki değerli enum, yeni bir reason-definition tablosu icat etmeye gerek yok** (bizim tarafta da bu seviyede tam bir ShipmentReasonDefinition kadar ağır bir mekanizma kullanılmadı, işe yaramadı değil, basitçe ihtiyaç olmadı).
   - `GET public/v1/courier-custody` — kuryenin üzerinde `ASSIGNED`/`IN_TRANSIT` olan `InventoryUnit` listesi (muhtemelen `ShipmentAssignment.courierId` + `isCurrent` üzerinden join).

**Auth/scope/idempotency:** accept/start ile birebir aynı — `getCurrentCourierAccount()`, `courier.party.tenantId` scope, `$transaction` içinde audit+status. Idempotency: accept/start konvansiyonuna uy (409 değil, 200 + zaten-yapıldı bayrağı) — bkz. §2'deki finalize düzeltmesiyle aynı gerekçe.

### 8.4 Cursor'a verilecek prompt (paste-ready)

```
Görev: SADECE kurye-taraflı custody (zimmet) uçları. Depo-intake, tazmin/
compensation, admin/portal UI YOK — bunlar bilerek kapsam dışı (bizim
apps/api'de de aynı sınır var, PRD-010..070 ve PRD-200/210).

Önce keşfet:
1. ShipmentInventoryHandover'ı oku — bu SADECE depo→kurye teslim alışı
   (reservationId @unique). Kurye→müşteri/şube/kurye devirleri için
   KULLANILAMAZ, yanlış model üzerine inşa etme.
2. InventoryUnit.statusCode'un yorum satırındaki sabit listeyi oku:
   AVAILABLE | RESERVED | ASSIGNED | IN_TRANSIT | DELIVERED | RETURNED |
   DAMAGED | LOST. Yeni bir statü icat etme, bu listeden kullan.
3. accept/start route'larının inline paternini (auth, tenant scope,
   $transaction, idempotency-yerine-200+already-flag) tekrar oku — bu
   yeni uçlar da aynı deseni izleyecek.
4. finalize'ın (varsa artık bitmiş) DELIVERED kolunu kontrol et — teslimat
   an'ında ilgili InventoryUnit'i DELIVERED'a çekiyor mu? Çekmiyorsa bunu
   BURADA değil, finalize'a ekle (ayrı bir "custody: teslim et" ucu YOK,
   iki yerde ayrı temsil tutarsızlık yaratır).

Ekle:
- Yeni model InventoryUnitCustodyEvent (küçük audit tablosu — tenantId,
  inventoryUnitId, shipmentId, courierId, eventTypeCode
  [RETURNED_TO_BRANCH|DAMAGE_REPORTED|LOST_REPORTED], fromStatusCode,
  toStatusCode, warehouseId?, note?, occurredAt). README'nin 5 modelli
  CustodyTransfer/ShipmentCustodyState/InventoryUnitCustodyState ailesini
  KURMA — gereğinden büyük, bizim custody_item_transitions'ımız kadar
  küçük bir şey yeter.
- POST public/v1/courier-custody/:unitId/return — body {warehouseId,
  note?}, ASSIGNED|IN_TRANSIT → RETURNED.
- POST public/v1/courier-custody/:unitId/report-issue — body
  {kind:'damaged'|'lost', note?, photoMediaIds?}, → DAMAGED|LOST.
- GET public/v1/courier-custody — kuryenin üzerindeki ASSIGNED/IN_TRANSIT
  InventoryUnit listesi.

Idempotency: tekrar çağrıda 409 değil, accept/start'taki gibi 200 +
{already...: true}. Auth: getCurrentCourierAccount() + tenant scope,
courier.auth modelini değiştirme.

Bitince: değişen dosya listesi + hangi modele nasıl migration eklendiği.
Kod yaz, commit/PR isteme.
```

## 8. OpenAPI kaydı eksikti — tamamlandı (06.09.2026)

`packages/contracts/src/openapi.ts` elle bakımlı bir registry — route dosyalarındaki Fastify şemalarından otomatik türemiyor. Bunu fark ettim çünkü kendi `/v1/routing/optimize` ucumu ekledikten sonra üretilen dokümanda görünmüyordu.

**Bulgu:** Sadece benim yeni ucum değil, **mevcut `/v1/tasks/:taskId/delay-decision` da (Faz 5, önceden var) hiç kayıtlı değilmiş** — aynı boşluğun ikinci bir örneği. İkisi de servis-arası (courier bearer token değil, `x-service-token`) olduğu için tek bir düzeltmeyle ikisini de kapattım:

- `serviceAuth` güvenlik şeması eklendi (`apiKey` / `x-service-token` header) — `bearerAuth`'un yanına
- `/v1/routing/optimize` ve `/v1/tasks/{taskId}/delay-decision` kayıtlandı, yeni `Routing` tag'i altında
- `pnpm --filter @dijigoo/contracts openapi` çalıştırıldı: **31 yol, 75 şema** üretildi, `openapi.json`/`openapi.yaml` güncellendi (bunlar repoya commit edilen, gitignore'da olmayan üretilmiş dosyalar — normal akış)

Panel ekibi artık bu iki ucu insan-okunur bir sözleşmede görebilir, sadece kod okuyarak keşfetmek zorunda değil.

## 9. Faz 1 uygulama durumu (06.09.2026)

Bu Claude Code oturumu `apps/mobile/lib/api/panel_client.dart` + `panel_models.dart`'ı ekledi (jetlogi-panel'in `public/v1/courier-*` uçlarına, cookie-session ile konuşan izole bir client — `cookie_jar`/`dio_cookie_manager` pubspec'e eklendi). Bunlar Cursor'un dokunduğu hiçbir dosyayla çakışmıyor, tamam.

**Eşzamanlı olarak Cursor (aynı repo, farklı oturum) `apps/mobile`'da gerçek bir `/v1/tasks` (apps/api) entegrasyonu yazıyor** — yeni `api/courier_tasks.dart` (`CourierTaskClient`, bilinçli olarak "Today: apps/api, Later: panel — sadece listPath/itemPath değiştir" yorumuyla tasarlanmış), `session.dart`/`client.dart`/`list_screen.dart`/`task_detail_screen.dart` + diğer ekranlarda değişiklik, yeni `support_screen.dart`. **Bu dosyalara bu oturumda dokunulmadı** — çakışmayı önlemek için Cursor'un işini bitirmesi bekleniyor.

**06.09.2026 güncelleme — Cursor'un apps/mobile işi bitti, doğrulandı, dokunulmadı.** Tüm suite (43 test) ve `flutter analyze` temiz. İnceleme: `CourierTaskClient.list()` gerçekten kullanılıyor (`fetchTasks`), ama `.transition()`/`.finalize()` **hiçbir yerden çağrılmıyor** — yazmalar hâlâ eski `outbox → /v1/sync/batch` (apps/api) yoluyla gidiyor. Yani panele geçiş sadece "listPath/itemPath değiştir" değil: okuma tarafı kolay, yazma tarafı (kabul/başla/konum/finalize) panelin çok-uçlu senkron REST modeline göre yeniden tasarlanmalı (Açık Karar #2).

**Karar (kullanıcı onayı, 06.09.2026):** Bu ortamda test edilecek canlı/local bir jetlogi-panel sunucusu yok, ve panel tarafındaki finalize'ın durumu bilinmiyor. Bu yüzden **Cursor'un çalışan `apps/api` entegrasyonuna dokunulmadı** — mobil şu an production'da bu üzerinden çalışmaya devam ediyor. Bunun yerine `panel_client.dart`/`panel_models.dart` olgunlaştırıldı ve tam birim testi eklendi (`test/panel_client_test.dart`, 11 test — DTO parsing + `PanelApi` istekleri, gerçek panel JSON şekliyle, cookie-jar'sız enjekte edilebilir `Dio` ile): `PanelApi` artık `MobileApi`/`CourierTaskClient` ile aynı test deseni. **`session.dart`'a bağlama (gerçek kesme) hâlâ yapılmadı** — panelde local/staging bir sunucu ayakta olduğunda ve Açık Karar #1 (auth) netleştiğinde yapılacak.

## Devam ederken

Panel kaynağı artık **`kukaraca/dijigoo-ops`** (`5a75437`). `JetLogiPro/jetlogi-panel` aynı ağacın 1 commit gerisi (`e2f75e2`). Scratchpad: `/private/tmp/claude-501/-Users-macbookpro-Desktop-Dijigoo/7167760d-cb1a-4aff-a070-f88952fc9815/scratchpad/kukaraca-dijigoo-ops` (geçici). Yeni oturumda `git@github.com:kukaraca/dijigoo-ops.git`. Eski B2B API / repo soyağacı: [`docs/06`](06-eski-panel-ve-repo-analizi.md).
