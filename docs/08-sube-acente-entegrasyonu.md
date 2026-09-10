# Şube/Acente entegrasyonu

**Tarih:** 11.09.2026
**Kaynak:** `dijigoo-ops` (yerel klon `/Users/macbookpro/Desktop/dijigoo-ops`, `git@github.com:kukaraca/dijigoo-ops.git`, HEAD `5a75437`) — aynısı `JetLogiPro/jetlogi-panel` (memory: 1 commit geride, asıl olarak dijigoo-ops kullanılıyor).
**Neden bu doküman:** JetLogi_Workflow akış şemasındaki "Şube/Acente Uygulaması" (Gönderiler, Kuryeler, Stok&Zimmet, Sayım, Merkeze Sevk) kod tabanında hiç yoktu. Kullanıcı, kendi `apps/api`'mizde paralel bir auth kurmak yerine dijigoo-ops'a bakılmasını istedi. Bu doküman o araştırmanın bulgularını taşıyor.

---

## 1. Sonuç (özet)

**Acente portal auth'u dijigoo-ops'ta zaten gerçek ve çalışıyor.** Kurye tarafı için zaten kurulu olan aynı desenle: e-posta+şifre giriş → httpOnly cookie session (JWT + `portal_user_sessions` satırı). Mobile'ın `panel_client.dart`'ta zaten olan dio+CookieJar altyapısı (courier-panel entegrasyonu için yazılmıştı) aynı şekilde bir `AgencyPortalApi` istemcisi için de kullanılabilir — yeni bir networking modeli gerekmiyor.

**Ama 5 modülden sadece "genel bakış" (overview) var.** Gönderiler/Kuryeler/Stok&Zimmet/Sayım/Merkeze Sevk'in gerçek liste/detay uçları yok — sadece sayaçlar var. Bu modüller panel reposunda (courier-tasks/finalize/custody için zaten kurulmuş desenle) yazılması gerekiyor, tıpkı kurye tarafında yapıldığı gibi (`docs/05-panel-entegrasyonu.md`).

---

## 2. Auth mekaniği (`src/infrastructure/auth/agency-portal-auth.ts`, 368 satır)

- **Giriş:** `POST /api/portal/v1/agency-auth/login` — e-posta + şifre (bcrypt), 5 hatalı denemede 15 dk kilit. Kullanıcı birden fazla acenteye bağlıysa `agencyId` seçimi istenir (`AGENCY_SELECTION_REQUIRED`, 409).
- **Veri modeli:** Dedike bir `Agency` tablosu **yok**. "Acente" = `Provider` (`providerTypeCode: "AGENCY"`) — canonical Party/Provider modelinin bir parçası. Personel = genel `User` tablosu, yetki = `UserRole` (RBAC), `scopeType: AGENCY`, `scopeId: <provider.id>`. Bir kullanıcı birden fazla acenteye (provider'a) rol ile bağlanabilir.
- **Session:** Login başarılı olunca `portal_user_sessions` tablosuna satır yazılır (`portalTypeCode: "AGENCY"`, `scopeType: AGENCY`, `scopeId: <agencyId>`, `expiresAt`, 8 saat) + `jetdiji_agency_session` adlı **httpOnly, sameSite=lax cookie**'ye HS256 JWT (`sub=userId`, `sessionId`, `providerId`, `tenantId`, `portalType: "AGENCY"`) yazılır. Her istekte `getCurrentAgencyPortalUser()` cookie'yi doğrular + `portal_user_sessions` satırının hâlâ `ACTIVE`/süresi dolmamış olduğunu kontrol eder — session iptali anlık.
- **Kurye tarafıyla birebir aynı desen:** `courier-auth.ts` da `COURIER_SESSION_COOKIE` ile aynı httpOnly-cookie yaklaşımını kullanıyor. Yani mobile zaten kurye-panel entegrasyonu için çözdüğü "cookie session'ı Flutter'da nasıl tutarım" sorusunu (bkz. [[project-jetlogi-panel-repo-analysis]] — `PanelApi(dio, [cookieJar])`) buraya da aynen taşıyabilir.
- **Personel provizyonu self-servis değil:** `internal/v1/agency-users` (admin yetkili, `requirePermission("providers.read")`) üzerinden HQ tarafı acente kullanıcısı oluşturuyor/yönetiyor. Şube/Acente app'in kendi içinde "yeni personel ekle" akışı yok — bu bilinçli bir tasarım, değiştirmemize gerek yok.

## 3. Bugün ne çalışıyor (`agency/overview/route.ts`)

Login sonrası tek gerçek veri ucu bu: `GET /api/portal/v1/agency/overview` → `session.user.agency.id`'ye ait `Provider` satırının sayaçlarını döner: `courierAssignments`, `regionCoverages`, `distributionNodeLinks`, `currentShipments` — hepsi `_count`, liste değil. Yani bugün bir acente kullanıcısı giriş yapıp "kaç kuryem var, kaç aktif gönderim var" görebilir ama tek bir kuryenin veya gönderinin detayına inemez.

## 4. Şube/Acente'nin 5 modülüne göre boşluk analizi

| Modül | Durum | Kanıt |
|---|---|---|
| **Giriş** | ✅ Var, gerçek | `agency-auth/{login,logout,session}` |
| **Gönderiler** (listele, barkod, kuryeye zimmetle) | ❌ Yok | `overview`'da sadece `currentShipments` sayısı; liste/detay/atama ucu yok |
| **Kuryeler** (liste, anlık durum, performans) | ❌ Yok | `overview`'da sadece `courierAssignments` sayısı; `Provider.courierAssignments` ilişkisi şemada var ama onu döken bir liste ucu yok |
| **Stok & Zimmet** | ⚠️ Kısmen — ama **bizim tarafımızda** | Bu, dijigoo-ops'un değil, kendi `apps/api`'mizin `custody.ts` sisteminin işi (courier↔branch/warehouse handover zaten orada gerçek ve test edilmiş — bkz. Faz 1 bu oturumda eklenen `POST /v1/custody/intake`). dijigoo-ops tarafında örtüşen/çakışan modeller var: `InventoryUnit`, `InventoryUnitCustodyEvent` (bu ikincisi 06-09'daki custody-port spec'imizde önerilmişti, şimdi şemada **gerçekten var** — Cursor'un o işi yapmış olması muhtemel, teyit gerek), `ShipmentInventoryReservation`, `ShipmentInventoryHandover`, `InventoryMovement`. **Karar gerektiren nokta:** Şube app'in "Stok & Zimmet" ekranı hangi backend'e konuşacak — kendi `apps/api`'mize mi, yoksa dijigoo-ops'un bu Inventory modellerine mi? İkisi de gerçek zimmet kavramları taşıyor, tek kaynağa indirilmeli. |
| **Sayım** (sayım emri, barkodla sayım, fark) | ❌ Yok | Şemada `StockCount`/`InventoryCount` gibi bir model yok; grep temiz |
| **Merkeze Sevk** (koli oluştur, etiket, sevk) | ❌ Yok | Şemada `Dispatch`/`Box`/`ShipmentBox` gibi bir model yok; grep temiz |

## 5. Mobil entegrasyon önerisi

`apps/mobile`'a yeni bir `AgencyPortalApi` istemcisi (`lib/api/agency_client.dart`), `PanelApi`'nin (`panel_client.dart`) aynı iskeletiyle: `Dio` + `CookieJar`, `login(email, password, {agencyId})`, `session()`, `logout()`. `SessionController`'a `AppRole { kurye, sube }` eklenip şube girişi bu istemciyi kullanır — kendi `apps/api`'mizde branch-staff auth'u tekrar icat etmeye gerek yok (kullanıcının kararı buydu).

Gönderiler/Kuryeler/Sayım/Merkeze Sevk uçları dijigoo-ops'ta yazılana kadar, mobil tarafta bu ekranlar önce **demo/mock veriyle** (kurye app'in geri kalanında zaten kullanılan desen — `session.dart` demo state) iskelet olarak kurulabilir; gerçek veri bağlanması ayrı, panel-tarafı bir iş kalemi.

---

## 6. Açık kararlar

1. **"Ayrı canlı sistem" belirsiz.** Kullanıcı, bu iki repodan (`jetlogi-panel`/`dijigoo-ops`) ayrı, canlı verisi olan üçüncü bir sistemden bahsetti ama neyi kastettiğini belirtmedi. `docs/05-panel-entegrasyonu.md` zaten bilinen bir "üçüncü sistem" tanımlıyor: eski B2B `https://api.jetlogi.net` (kurumsal entegrasyon, kurye-mobil ile ilgisiz — detay `docs/06-eski-panel-ve-repo-analizi.md`). Kullanıcının kastettiği bu mu, yoksa dijigoo-ops'un canlıda çalışan bir deploy'u (bu git klonundan farklı, gerçek müşteri/acente verisi olan bir ortam) mu — **netleşmeli**, geçiş planı buna göre değişir.
2. **Stok & Zimmet'in tek sahibi kim olacak** — kendi `apps/api`'mizin `custody.ts`'i mi, yoksa dijigoo-ops'un Inventory/`ShipmentInventoryHandover` modelleri mi? İkisi de gerçek ve örtüşüyor.
3. **`InventoryUnitCustodyEvent` modelinin dijigoo-ops şemasında görünmesi** (06.09'daki spec'imizle aynı isim) teyit edilmeli — Cursor bunu bizim önerdiğimiz şekilde mi yaptı, yoksa bağımsız bir geliştirme mi, davranışı hâlâ spec'le uyumlu mu?
4. **Sayım ve Merkeze Sevk kimin reposunda yazılacak** — kurye-tarafı emsale göre (docs/05) dijigoo-ops'ta yazılması mantıklı, ama bu iki modül tamamen yeni domain'ler (hiçbir yerde temeli yok); panel ekibiyle mi koordine edilecek, yoksa biz mi yazacağız netleşmeli.
