# Eski panel, kurumsal API ve repo ilişkisi — analiz

**Tarih:** 06.09.2026 · **Güncelleme:** 06.09.2026 (doğrulama + Integration Hub eşlemesi)
**Kaynaklar:** `git@github.com:kukaraca/dijigoo-ops.git`, `git@github.com:JetLogiPro/jetlogi-panel.git`, `https://api.jetlogi.net/swagger/v1/swagger.json`, `https://panel.jetlogi.net/allorder`
**Amaç:** `docs/05-panel-entegrasyonu.md`'deki plana eklenecek üçüncü bir veri seti — karar öncesi tüm argümanları birleştirmek için. **`docs/05` §0 bu dosyaya bağlandı.**

---

## 1. `kukaraca/dijigoo-ops` = `JetLogiPro/jetlogi-panel`'in ta kendisi

İki reponun git geçmişi karşılaştırıldı (`git log --oneline`, `git merge-base --is-ancestor`):

- İlk commit hash'leri **birebir aynı**: `725927c "Initial commit from Create Next App"`
- `jetlogi-panel` HEAD (`e2f75e2`), `kukaraca/dijigoo-ops` HEAD'inin (`5a75437`) **doğrudan atası** — yani `jetlogi-panel` tam olarak `kukaraca/dijigoo-ops`'un 1 commit gerisi, ayrı bir fork ya da farklı bir kod tabanı değil.
- Fazladan commit: `5a75437 feat(integrations): add process package UAT and controlled production promotion` (05.09.2026, **Ruken Turhan**, +15.824/-73 satır)

**Yorum:** `kukaraca` muhtemelen geliştiricinin kişisel hesabı — asıl geliştirme burada yapılıyor, `JetLogiPro/jetlogi-panel` kurumsal org'a taşınan/mirror'lanan kopya (bkz. proje notu "panel repo moving to new JetLogi GitHub" — taşınma tam bitmemiş). **Pratik sonuç: bundan sonra `kukaraca/dijigoo-ops`'u kaynak almalıyız, `jetlogi-panel`'i değil** — daha güncel.

Son commit'in içeriği courier-finalize ile **ilgisiz**: `admin/integrations/_components/ProductionPromotionPanel.tsx`, `CorporateUatTestCenterV2.tsx`, `portal/v1/customer/integrations/uat/*`, `integration/runtime/workflow-integration-worker.ts` — tamamı kurumsal müşteri entegrasyonu (UAT ortamından production'a kontrollü geçiş) tarafında. **Şu ana kadarki push geçmişinde `docs/05`'te beklediğimiz finalize/custody ilerlemesine dair bir iz yok** — geliştiricinin en son odağı bu değilmiş (yerelde/commit'lenmemiş olabilir, bilemeyiz).

---

## 2. `api.jetlogi.net` — eski/kurumsal entegrasyon API'si (kurye API'si DEĞİL)

Swagger (`https://api.jetlogi.net/swagger/index.html`, JSON: `.../swagger/v1/swagger.json`) canlı ve herkese açık şekilde erişilebilir durumda.

- **Başlık:** "Jetlogi Servis" v1 — 13 endpoint, 28 şema, hepsi `ShipmentsService` altında:

| Endpoint | İş |
|---|---|
| `POST Create` | Gönderi oluştur |
| `POST Update` / `UpdateProduct` / `UpdateAddress` / `UpdateCustomerUniq` | Gönderi/ürün/adres/müşteri-referans güncelle |
| `POST UpdateStatus` | Hazırlık statüsü güncelle |
| `POST RequiredDocumentList` | Gerekli belge listesi |
| `POST ShipmentState` / `...byCustomerUniqNumber` / `...byTransactionID` / `BaseShipmentState...` | Durum sorgulama (3 farklı anahtarla) |
| `POST ShipmentCancel` / `...byTransactionID` | İptal |

- **Kimlik doğrulama:** Modern token/session yok — her istek gövdesinde ayrı bir `auth: {userName, password}` alanı (`Authentication` şeması). Eski nesil, stateless, B2B entegrasyon deseni.
- **Eşleştirme anahtarları:** `customerUniqNumber` (müşterinin kendi referansı), `transactionID`, `cargokey` (int) — üçü de aynı gönderiyi farklı taraflardan adreslemek için.
- **Hata sözlüğü** (`APIResult.errorCode`): `10` yetki hatası, `20` mükerrer kayıt, `30` parametre hatası, `40` gönderi bulunamadı, `50` kullanıcı bilgisi hatası, `60` diğer.
- **`ShipmentChargeType`**: enum `1|2|3` — Swagger Create açıklaması: `HesapSahibi=1`, `Alıcı=2`, `GöndericiAdresiVerilen=3` (üçüncü taraf değil; fatura edilecek cari).
- **İletişim (Swagger `info.contact`):** Jetlogi Panel · `https://panel.jetlogi.com` · `soner.eren@bydysoft.com` — canlı UI ise `panel.jetlogi.net`. `.com` / `.net` ayrımı doğrulanmadı; eski tedarikçi izi (Bydysoft).
- **`APIResult.statu`:** alan adı kasıtlı yazım hatası (`status` değil). `cargoKey` (int), `cargoUrl`, `barcode` / `returnBarcode`.

**Bu API kim için:** Kurumsal müşterinin (örn. Borusan) kendi sistemlerinden gönderi oluşturup takip etmesi için — courier-mobile ile hiç ilgisi yok, [[project-jetlogi-panel-repo-analysis]]'te bahsedilen jetlogi-panel'in **Integration Hub**'ıyla (`IntegrationConnection`/`MappingProfile`/`MappingRule`, `CREATE_SHIPMENT`/`GET_TRACKING` capability modeli) aynı işi yapıyor. §1'deki UAT/production-promotion commit'i, muhtemelen kurumsal müşterileri bu eski API'den yeni Integration Hub'a **kontrollü şekilde geçirme** mekanizması — isim de ("controlled production promotion") bunu destekliyor.

**Açık soru (doğrulanmadı):** Bu eski API hâlâ üretimde canlı trafik mi taşıyor, yoksa sadece geriye dönük uyumluluk için mi ayakta? Swagger'ın halka açık olması aktif kullanıldığı anlamına gelmiyor. Panel ekibine sorulmalı.

---

## 3. `panel.jetlogi.net/allorder` — eski panel canlı UI

Ziyaret edildi, login duvarına düştü (`https://panel.jetlogi.net/user/login?ReturnUrl=%2fallorder`). Bu tarayıcı profilinde (Claude in Chrome kendi ayrı profilinde çalışıyor, kullanıcının normal oturumunu paylaşmıyor) kayıtlı bir oturum yok. Güvenlik kuralı gereği kimlik bilgilerini benim girmem doğru olmaz — **kullanıcı bu sekmede giriş yaptıktan sonra devam edilebilir.**

Giriş ekranı: telefon/e-posta + şifre + SMS ya da 2FA doğrulama seçeneği — bu da `jetlogi-panel`'in `courier-auth`'undan (email/telefon+şifre, cookie-session) farklı, admin/kurumsal kullanıcı için ayrı bir giriş akışı olduğunu gösteriyor (muhtemelen `admin-auth.ts`/`customer-portal-auth.ts` eşdeğeri, ama bu eski sistemde).

**Kullanıcının paylaştığı ekran görüntüsü — `/billing` (Faturalama listesi):** Kendi tarayıcısında giriş yapıp erişmiş (Claude in Chrome sekmesi hâlâ login duvarında — canlı gezinme için kullanıcının o sekmede giriş yapması hâlâ gerekiyor, şimdilik statik ekran görüntüsü üzerinden okundu).

Sol menü taksonomisi tek başına çok şey anlatıyor — bu eski panel sadece kurye/gönderi değil, **tam bir operasyon platformu**:

- **Admin** (açık): İçerdekiler, Hata Takip, Uyarı Takip, Login Takip, İşlem Takip, Kullanıcı Akış Takip, Güncellemeler, Sayfa Yönetimi, Announcement, Sayfa Bilgilerini Güncelle, Kullanıcı Hatası, Çağrı Merkezi, Yazılım Yönetimi
- **Finans**, **Yönetim**, **Ticket Yönetimi** — kapalı, alt maddeleri görülmedi

`/billing` sayfasının kendisi: aylık faturalama dönemleri listesi (ID 17-26, `2025-11/1` → `2026-07/1`), her satırda "Faturalama Yükle" aksiyonu — muhtemelen o aya ait fatura/mutabakat dosyasının yüklendiği bir mekanizma (agency/kurye hakediş mutabakatı ya da kurumsal müşteri faturalaması, hangisi olduğu ekrandan tek başına belli değil).

**Bu, [[project-nihai-mimari-plan]]'daki "45 modül ailesi" panel IA'sının somut, canlı örneği** — jetlogi-panel'in (`dijigoo-ops`) `SupportTicket`, `AdminNotification`, `SystemSettingDefinition` gibi modelleri, bu eski panelin Ticket Yönetimi / Announcement / Sayfa Yönetimi modüllerinin **yeni nesil karşılıkları** gibi duruyor. Yani jetlogi-panel sadece courier-mobile API'si değil, **bu eski admin panelinin tamamının yerini almayı hedefleyen bir platform** — kapsamı ilk sandığımızdan daha geniş.

---

## 4. `jetlogi.com` — kurumsal tanıtım sitesi (gerçek hizmet kataloğu)

`WebFetch` bot korumasına takıldı (403), Chrome tarayıcı aracıyla sorunsuz okundu.

**Öne çıkan ürün/modül isimleri** (siteye göre, hepsi kendi ekipleri tarafından yazılmış):
- **JET Mobil** — "kendi uzman yazılım ekibimiz tarafından yazılan... saha yönetim programı" (bizim `apps/mobile`/courier-tasks'ın karşılığı olan gerçek üretim uygulaması)
- **Entegrasyon** — "müşterilerimizin sistemleri ile çift yönlü tam entegrasyon" (bkz. §2 — `api.jetlogi.net` + jetlogi-panel Integration Hub)
- **Ticket Sistemi** — "SLA ve KPI sonuçlarının raporlanması"
- **Çağrı Yönetimi** — çift yönlü arama
- **Raporlama** — anlık teslimat/randevu takibi

**Hizmet kataloğu** (Hizmetler menüsü) — [[project-nihai-mimari-plan]]'daki "9 servis profili" iddiasını somut isimlerle doğruluyor:

| Site'deki hizmet adı | Muhtemel Nihai Mimari profili |
|---|---|
| Dijital İmza & KYC | KYC |
| Kredi Kartı Dağıtımı | Kontrollü teslimat (controlled delivery) |
| Adresli Dağıtım | Standart dağıtım |
| E-Ticaret Dağıtımı | Standart dağıtım (e-ticaret varyantı) |
| E-Ticaret İade | Ters lojistik (reverse logistics) |
| Insert Dağıtımı | Toplu/imzasız dağıtım (yeni — önceki notlarda yoktu) |
| Muhaberat | Kurumsal evrak/yazışma dağıtımı |
| Telemarketing / Inbound-Outbound | Saha satışı değil, çağrı merkezi hizmeti |
| Evrak Yönetimi / E-İmza Evrak | Belge (DOC) süreçleri |

**Pratik sonuç:** Kurye-mobil API'sini tasarlarken (finalize/proof/reason kodları) bu hizmet çeşitliliğini unutmamak lazım — örn. "Kredi Kartı Dağıtımı" muhtemelen sıkı KYC/kimlik doğrulama adımı gerektirir, "Insert Dağıtımı" muhtemelen imza gerektirmez, "E-Ticaret İade" bizim RET-0xx kodlarımızın gerçek karşılığı. Şu ana kadarki courier-tasks/finalize tasarımımız (bkz. `docs/05` §2) tek tip "standart teslimat" varsayıyor — panelin `ServiceDefinition`/`ProductDefinition` modeli (README §5.3) muhtemelen bu farkı zaten taşıyor, finalize'ın `reasonCode`/`statusReasonPath` çözümlemesi ürüne göre değişebilir.

---

## 5. Doğrulama (aynı gün, ikinci geçiş)

Scratchpad klonları hâlâ duruyor; her iki remote `fetch` edildi. Soy iddiası **aynı**:

| | `kukaraca/dijigoo-ops` | `JetLogiPro/jetlogi-panel` |
|---|---|---|
| HEAD | `5a75437` (05.09.2026, Ruken Turhan) | `e2f75e2` |
| İlk commit | `725927c` | `725927c` |
| İlişki | `e2f75e2` → `5a75437` ancestor | 1 commit geride |

### 5.1 Eski API ↔ Integration Hub — hipotez değil, kaynak kod

`src/app/[locale]/kurumsal-panel/entegrasyonlar/_components/CorporateIntegrationServices.tsx` 13 legacy ucu **birebir** yeni kanonik yola eşliyor. Swagger path listesi (13 POST, 28 şema) bu tabloyla aynı:

| Legacy (`api.jetlogi.net`) | Yeni (`/api/integration/v1/...`) |
|---|---|
| `/api/ShipmentsService/Create` | `/shipments` |
| `/UpdateProduct` | `/shipments/{id}/product` |
| `/UpdateCustomerUniq` | `/shipments/{id}/references` |
| `/RequiredDocumentList` | `/shipments/{id}/required-documents` |
| `/Update` | `/shipments/{id}` |
| `/UpdateAddress` | `/shipments/{id}/address` |
| `/UpdateStatus` | `/shipments/{id}/events` |
| `/ShipmentState` | `/shipments/{id}/state` |
| `/ShipmentStatebyCustomerUniqNumber` | `/shipments/state?customerReference=` |
| `/BaseShipmentStatebyCustomerUniqNumber` | `/shipments/state/base?customerReference=` |
| `/ShipmentStatebyTransactionID` | `/shipments/state?transactionId=` |
| `/ShipmentCancel` | `/shipments/{id}/cancel` |
| `/ShipmentCancelbyTransactionID` | `/shipments/by-transaction/{id}/cancel` |

UI metni bu katalogdaki her satırı **"planned"** gösteriyor — yani Hub yazılmış, kurumsal müşteri kesimi henüz tamamlanmamış olabilir. Bu, `5a75437` UAT/production-promotion commit'inin *neden* orada olduğunu güçlendirir: eski B2B API'den Hub'a kontrollü geçiş.

**Kurye mobil bu tablonun hiçbir satırını kullanmaz.** `CREATE_SHIPMENT` / `GET_TRACKING` kabiliyetleri müşteri entegrasyonu.

### 5.2 `public/v1` kurye yüzeyi (`5a75437`, taze)

Var (liste/detay + yazma): `courier-auth` (login/logout/session/activate/change-password), `courier-tasks` (**yalnız** list / get / accept / start / location), başvuru/profil/belge/onay/availability, `geography/*`.

**Yok (Faz 2/3/5 hâlâ boş):** `courier-tasks/:id/finalize`, `courier-custody*`, `courier-tickets*`, `courier-shifts*`. `public/v1/tickets/recipient` alıcı ticket'ı — kurye destegi değil.

Web kurye paneli (`kurye-paneli/gorevlerim/[shipmentId]`) de aynı üç yazmayı çağırıyor: accept / start / location (`purposeCode: ARRIVAL`). Teslim sonucu butonu yok; `DELIVERY_RESULT` yalnız workflow etiketi.

`prisma/schema.prisma`: `InventoryUnit` + `ShipmentInventoryHandover` var, `CustodyTransfer` / `ShipmentCustodyState` yok. `SupportTicket` şeması var, kurye public ucu yok. `docs/05` §8.2 ile uyumlu.

**Blokaj #3 (finalize teyidi):** fresher HEAD'de de route yok. Push geçmişinde hâlâ iz yok. Yerel/commit'siz çalışma ihtimali duruyor, ama olumsuz sinyal güçlendi.

### 5.3 Bu Dijigoo repo içindeki `apps/panel`

`apps/panel` (`@dijigoo/panel`, Next 15, port 3000) **dijigoo-ops değil** — Fastify sözleşmesine bağlı ayrı bir iskelet. Eski `panel.jetlogi.net` veya `kukaraca/dijigoo-ops` ile karıştırılmamalı.

### 5.4 Hâlâ açık

- Eski API üretim trafiği taşıyor mu? Swagger açık olması yetmez — ama §6 (`/allorder`) bunu artık dolaylı olarak doğruluyor, bkz. aşağı.
- `panel.jetlogi.com` (Swagger) vs `panel.jetlogi.net` (canlı) — aynı host mu, yönlendirme mi?

---

## 6. `panel.jetlogi.net/allorder` — canlı üretim verisi (kullanıcının ekran görüntüsü)

Claude in Chrome kendi profilinde giremediği için doğrudan gezinemedim, ama kullanıcı kendi oturumundan iki ekran görüntüsü paylaştı — bu, eski panelin **hâlâ gerçek, büyük ölçekli üretim trafiği taşıdığını kanıtlıyor** (§2/§5.4'teki açık soruyu kapatıyor).

### 6.1 Pipeline sayaçları (üstteki 11 kutu)

| Aşama | Adet |
|---|---:|
| Hazırlık Aşaması | 142 |
| Müşteri Hizmetleri | 241 |
| Sevkiyat Aşaması | 58 |
| Dağıtım Aşaması | 42.167 |
| Kontrol Süreci | 453 |
| Devir | 4.659 |
| Teslim | 78.811 |
| Beklemede | 454 |
| İade | 531 |
| İptal | 63.766 |
| **Toplam** | **191.282** |

**Dikkat çeken:** İptal oranı toplamın **~%33'ü** (63.766/191.282) — Teslim'in (78.811) neredeyse yarısı kadar. Bunun sebebi (gerçek iptal mi, veri temizliği/test kaydı mı, yoksa normal bir sektör oranı mı) bilinmiyor — panel ekibine sorulmadan yorum yapılmamalı, ama courier-mobil tarafında RET/İPTAL akışlarını hafife almamak gerektiğine işaret ediyor.

### 6.2 Gönderi satırı yapısı (`GÖNDERİLER` tablosu)

Her satır: `ADS` rozeti + **müşteri adı (Borusan)** + alıcı adı, plaka-biçimli bir kod (`34TC2861` vb. — muhtemelen kurye/araç plakası ya da takip kodu), zaman damgası + "Bekleme 0", akış adımı metni (`Yeni Sipariş - Şube Sevk 2 /Beklemede`), hub/işlem bilgisi (`MERKEZ HUB / 1. İşlem`), **ürün adı (`BMWPRIME`)**, "Yazılmadı" rozeti, foto sayacı, ve sağda bir aksiyon ikon kümesi (2 farklı renkte konum pini, 2 telefon/arama ikonu, foto, pano/clipboard, paylaş, kamera) + dahili gönderi ID'si (`1192544` vb.).

**Doğrulanan şeyler:**
- **Borusan gerçekten canlı, aktif bir müşteri** — jetlogi-panel README §5.4'teki "Borusan = Customer" örneği varsayımsal değil, gerçek veri.
- **`BMWPRIME` ürün adı** — Borusan'ın gönderdiği ürünün BMW'yle ilgili olduğunu düşündürüyor (yedek parça/doküman olabilir); "ürün" kavramının jetlogi-panel'in `ProductDefinition` modeliyle örtüştüğünü gösteriyor.
- **"Şube Sevk 2"** gibi adımlı, isimlendirilmiş bir workflow var — jetlogi-panel'in `WorkflowDefinition`/`WorkflowInstance` motoruna (bkz. `docs/05` §2) kavramsal olarak denk düşüyor.
- Satır başına aksiyon ikonları (arama, foto, konum, not) — tam olarak bizim finalize/proof tasarımımızın (çağrı, kanıt fotoğrafı, konum, not) operasyonda zaten beklenen ihtiyaçlar olduğunu doğruluyor.

### 6.3 Sidebar — daha da geniş bir modül listesi

`/billing`'teki listeye ek olarak görülen yeni üst-seviye menüler: **Tanımlamalar** (Definitions), **Operasyon**, **Toplu İşlemler** (Bulk operations), **Eğitim** (Training), **Gönderiler** (Shipments), **Sözleşme Yönetim** (Contract management), ve doğrudan hizmet adına göre ayrılmış bölümler: **Adresli Dağıtım**, **E-Ticaret Dağıtım** (devamı kesildi, muhtemelen §4'teki tüm hizmet listesi kadar uzuyor).

**Bu, §4'teki hizmet kataloğu ile sidebar'ın birebir eşleştiğini gösteriyor** — her hizmet türü (Adresli Dağıtım, E-Ticaret Dağıtım, ...) panelin kendi ayrı bölümüne sahip. jetlogi-panel'in `ServiceDefinition`/`ProductDefinition` + `BusinessScenario` modelleri muhtemelen bu ayrımı genelleştirmeyi hedefliyor (tek panel, çok hizmet — hardcoded sidebar bölümleri yerine data-driven).

---

## 7. Sipariş detayı (`/allorder/edit/1192544` + indirilen PDF) — tam veri modeli

Kullanıcı hem düzenleme ekranının (`panel.jetlogi.net/allorder/edit/1192544`) ekran görüntülerini hem de aynı siparişin PDF çıktısını (`panel.jetlogi.net/ads/order/detail/1192544`) paylaştı — ikisi birbirini tamamlıyor, PDF'te ekran görüntüsünde kesilen alanlar da var.

### 7.1 Entegrasyonun canlı olduğunun doğrudan kanıtı

`TransactionID: 01a0783b-3585-7f16-b045-2eb47082ee9c` — bu alan **§2'deki `api.jetlogi.net` Swagger şemasındaki `transactionID` alanının ta kendisi.** Yani bu spesifik sipariş (bugünün tarihiyle, 06.09.2026 22:42) gerçekten eski B2B API'nin `ShipmentsService/Create` ucundan, `Entegreborusan` adlı bir entegrasyon kullanıcısı tarafından oluşturulmuş. §5.4'teki açık soru ("eski API üretimde mi") artık **kesin olarak evet** — varsayım değil, aynı sipariş kaydında görülen somut kanıt.

### 7.2 Sipariş alan taksonomisi (özet)

**Sipariş bilgisi:** Alıcı Sipariş no, **TC Kimlik numarası** (KYC/kimlik doğrulama — "KART DAĞITIM" = jetlogi.com'daki "Kredi Kartı Dağıtımı" hizmetinin ta kendisi, kart dağıtımının neden kimlik sorduğu netleşti), Alıcı GSM, Gönderi Tipi, Adres (İstek), Ürün Seri No, Ürün tipi (`BMWPRIME`), TransactionID, + 5 farklı not alanı (müşteri notu, müşteri bekletme sebebi, kurye formu notu **[müşteri göremez]**, şubeye özel not **[müşteri göremez]**, ek açıklama) — **görünürlük seviyesi olan notlar**, bizim tek tip `note` alanımızdan daha ayrıntılı.

**Kontrol bilgisi:** Şehir/İlçe/Mahalle/Adres (Teslim)/Adres Tarifi, Gönderi Tarih, **Son arayan + İlk/son arama tarihi** (bizim `maskedCall` özelliğimizle örtüşüyor), **Son yazdıran + tarih** (`Yazılmadı` rozeti — kart/etiket basım adımı, bizim DOC-0xx'e denk), Şube/Acente + çıkış tarihi, Kurye + zimmet tarihi, Teslim alan, Saha Sonuç tarihi, Son işlem yapan + tarihi, **Entegre tarihi** (`Son Entegre Bekliyor` rozeti), **Kontrol edilme tarihi** (`Kontrol Edilmedi` rozeti — bizim QUA-0xx kalite kontrolüne denk), **Müşteri teslim tarihi** (`Firmaya Teslim Edilmedi` rozeti — alıcıya teslimden AYRI bir "kurumsal müşteriye raporlandı" adımı).

**Sipariş Durumu — 5 aşamalı kanonik pipeline (görsel, ikonlu):**
`Gönderi Hazırlandı → Randevu İşlemi → Teslimat Şubesinde → Kurye Dağıtımda → Teslim edildi`

Bu, ayrıntılı iç durum metninden (`Yeni Sipariş - Şube Sevk 2` gibi) **ayrı, sadeleştirilmiş bir üst seviye statü** — tam olarak jetlogi-panel'in `ShipmentMainStatus` (kaba) / `ShipmentStatusDefinition` (ayrıntılı) ikili modeliyle örtüşüyor (bkz. `docs/05` §2, §7). Hipotez değil, iki seviyeli statü tasarımının gerçek dünyadaki önceli.

**Kurye çekimleri:** admin ekranında doğrudan iki manuel aksiyon butonu var — **"Teslim Edilemedi"** ve **"Kurye Teslim Etti"** — yani operasyon ekibi, kurye uygulaması dışında admin panelden de teslimat sonucunu elle işaretleyebiliyor (bir fallback/override yolu). Fotoğraf yükleme alanı var ama bu siparişte boş ("Siparişle ilişkili bir görüntü bulunmuyor").

### 7.3 Küçük bir teknik not

PDF dosya adı ve sayfa başlığı bozuk çıkmış: **"Dijital Çaðýn Lojistik Çözümleri"** (`ğ`→`ð`, `ı`→`ý`) — klasik Windows-1254/UTF-8 karışıklığı, PDF export özelliğinde bir encoding hatası. Küçük ama sistemin yaşını/teknik borcunu gösteren bir detay.

---

## 8. Sentez — `docs/05`'teki plana etkisi

1. **Kaynak repo değişikliği:** Bundan sonraki tüm panel-tarafı incelemeler `kukaraca/dijigoo-ops`'tan yapılmalı, `jetlogi-panel`'den değil (1 commit gerisi kalıyor).
2. **İki değil, dört sistem var:** courier-mobile (bizim ilgilendiğimiz), jetlogi-panel'in kendi Integration Hub'ı (henüz "planned"), eski `api.jetlogi.net` B2B API'si (muhtemelen hâlâ üretimde), ve eski `panel.jetlogi.net` admin platformu (finans/ticket/announcement/sayfa yönetimi — jetlogi-panel'in bunları da devralması planlanıyor). Bizim işimiz hâlâ sadece birincisi.
3. **Blokaj #3 (finalize teyidi) güçlü olumsuz sinyal aldı:** §5.2'de doğrulandı — kukaraca'nın en taze HEAD'inde (`5a75437`) bile `courier-tasks/:id/finalize`, `courier-custody*`, `courier-tickets*`, `courier-shifts*` **yok**. Ne web kurye panelinde ne public API'de bir "teslim sonucu" ucu var. Kesin değil (yerel/commit'siz çalışma ihtimali kalır) ama artık sadece varsayım değil, push edilmiş koda dayanıyor.
4. **Hizmet çeşitliliği finalize tasarımını etkileyebilir** (§4) — "standart teslimat" tek tip varsayımı, panelin `ServiceDefinition`/`ProductDefinition` modeliyle örtüşmeyebilir; Cursor'a verilecek custody/finalize prompt'larına bu nüans eklenmeli.
5. **`apps/panel` bu Dijigoo reposunda ayrı, ilgisiz bir iskelet** (§5.3) — dijigoo-ops/jetlogi-panel ile karıştırılmamalı.
6. **Eski panel gerçekten canlı ve büyük ölçekli** (§6) — 191.282 gönderi, gerçek müşteri (Borusan). "Eski API üretimde mi" sorusu artık **kanıtla kapandı** (§7.1 — bir siparişin `TransactionID`'si Swagger şemasındaki alanla birebir eşleşiyor, bugünün tarihiyle). Migrasyon/geçiş konuşulurken bunun sıfırdan bir sistem değil, **gerçek, çalışan bir üretim platformunun** yerini almak olduğu unutulmamalı — kesinti toleransı düşük olabilir.
7. **İptal oranı (~%33) dikkat çekici** (§6.1) — sebebi bilinmiyor, panel ekibine sorulmalı. Courier-mobil tarafında RET/İPTAL akışlarının (bizim `custody.ts`'teki PRD-180/190, panel tarafında henüz yazılmamış custody uçları) küçümsenmemesi gerektiğine işaret ediyor.
8. **Eski sistemin sipariş modeli bizim finalize/custody tasarımımızdan zengin** (§7.2) — görünürlük seviyeli notlar (müşteri görebilir/göremez), ayrı "kontrol edilme" ve "firmaya teslim edilme" adımları (alıcıya teslimden farklı), ve admin panelden manuel "Teslim Edilemedi"/"Kurye Teslim Etti" override butonları. Cursor'a verilecek finalize/custody prompt'larına bu üç nüansın (not görünürlüğü, ayrı QA/raporlama adımı, manuel override ihtiyacı olup olmadığı) eklenmesi düşünülmeli — panel ekibiyle netleştirilmeden varsayılmamalı.

## Devam ederken

- Kaynak klon: `/private/tmp/claude-501/-Users-macbookpro-Desktop-Dijigoo/7167760d-cb1a-4aff-a070-f88952fc9815/scratchpad/kukaraca-dijigoo-ops` (geçici scratchpad). Kalıcı devam için `git@github.com:kukaraca/dijigoo-ops.git`.
- `jetlogi-panel` aynı scratchpad'de, 1 commit geride; inceleme için **kullanma**.
- `/allorder` canlı gezinme hâlâ yapılmadı (Claude in Chrome'un kendi profili, kullanıcının oturumunu paylaşmıyor) — ekran görüntüleriyle §6'daki analiz yapıldı. Daha fazla ekran/sayfa paylaşılırsa bu dosyaya eklenir.
