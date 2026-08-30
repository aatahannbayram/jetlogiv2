# Dijigoo Kurye App — Teknik Değerlendirme ve Faz 1 Planı

**Kime:** Hande
**Konu:** "Dijigoo Kurye App Final Süreç, Teknik Analiz ve Kabul Dokümanı" değerlendirmesi
**Durum:** Teknik ekip görüşü — kapsam ve takvim teyidi bekleniyor

---

## 0. Özet

Doküman süreç tarafında olgun: 30 modül, 40 UAT kriteri ve net kabul şartları var. Bu haliyle "ne yapılacağı" büyük ölçüde belli. Eksik olan taraf **teknik sözleşme**: API şeması, veri modeli, workflow tanımı ve dış servis sağlayıcıları henüz karara bağlanmamış. Dokümanın Bölüm 26'sındaki not da bunu doğruluyor: *"sonrasında onaylanacak API/OpenAPI şeması esas alınır."*

Önerimiz iki maddede:

1. Kod yazmadan önce **2 haftalık bir sözleşme fazı (Faz 0)** koyalım. Bu bitmeden mobil geliştirme başlarsa iş iki kez yazılır.
2. Dokümandaki Faz 1 tanımı fiilen ürünün tamamını kapsıyor. Pilota çıkabilmek için Faz 1'i **çekirdek kapsama** indirip, geri kalanı Faz 1.5'e alalım.

Bu iki kabulle **Faz 1 için tahminimiz ~24 hafta (5,5 ay)**. Gerekçesi Bölüm 4'te.

---

## 1. Eksik veya netleşmesi gereken alanlar

Aşağıdakiler "hata" değil, geliştirmenin başlayabilmesi için kapatılması gereken boşluklar. Sıralama aciliyete göre.

### 1.1 Panel kapsam dışı ama mobil panele bağımlı — en kritik blokaj

Doküman mobil uygulamanın davranışını **%100 panelden gelen workflow kuralına** bağlıyor: adım sıraları, zorunlu kanıt tipleri, OTP gerekliliği, teslim edilemedi nedenleri. Buna karşılık panel "kapsam dışı" olarak işaretlenmiş.

Bu haliyle mobil uygulama ne geliştirilebilir ne test edilebilir. En az şu üçünün Faz 1'in parçası olması gerekiyor:

- Workflow tanımlama ve **versiyonlu yayınlama** ekranı
- Görev/rota atama ekranı
- Kanıt görüntüleme ve UAT doğrulama ekranı

Alternatif olarak panel ayrı bir ekipteyse, **workflow şeması ve yayınlama API'si** yine de Faz 0'da bizim tarafımızdan tanımlanmalı ve panel ekibi bu sözleşmeye uymalı.

### 1.2 API/OpenAPI şeması yok

Bölüm 17 endpoint isimlerini veriyor ama request/response gövdeleri, sayfalama, hata modeli, idempotency ve sürümleme kuralı tanımlı değil. Faz 0 çıktısı olarak OpenAPI 3.1 taslağını biz hazırlıyoruz; onayınıza sunacağız.

### 1.3 Workflow tanımı bir şema olarak yazılmamış

`WorkflowDefinition` / `WorkflowStep` yapısı, adım tipleri, koşullu dallanma ve **versiyon geçiş kuralı** netleşmeli. Kritik soru: bir kurye görevi V1 workflow ile başlatmışken panel V2 yayınlarsa ne olacak? Önerimiz: **çalışan görev başladığı sürümle biter**, yeni sürüm sadece yeni görevlere uygulanır.

### 1.4 Trafik verisi çelişkisi

Bölüm 19 ETA için "trafik ve mesafe" şartı koyuyor. Buna karşılık ücretsiz OpenRouteService **canlı trafik vermiyor**. Bu şart ancak ücretli bir servisle (Google Routes, Mapbox, TomTom) karşılanabilir; kurye başına aylık maliyet doğar.

Önerimiz: Faz 1'de trafiksiz ETA + geniş tolerans bandı, ücretli trafik entegrasyonu Faz 1.5. Aksi halde bütçe kalemi açılmalı.

### 1.5 Dış servis sağlayıcıları seçilmemiş

SMS/OTP, **maskeli arama / IVR** ve geocoding için sağlayıcı kararı yok. Türkiye'de maskeli arama BTK uyumlu bir operatör gerektiriyor (Netgsm, Verimor, İletimerkezi) ve sözleşme + numara tahsis süreci haftalar sürüyor. Bu tedarik **Faz 0'da başlatılmazsa** Sprint 3-4'ü bloklar.

### 1.6 Mağaza hesapları ve arka plan konum gerekçesi

Google Play (25 USD tek seferlik) ve Apple Developer (99 USD yıllık) hesapları açılmalı. Daha önemlisi: Android `ACCESS_BACKGROUND_LOCATION` ve iOS `Always` konum izni için **gerekçe formu + tanıtım videosu** ile mağaza incelemesinden geçilmesi gerekiyor; bu inceleme tek başına haftalar sürebiliyor. Bugün başlatılmalı.

### 1.7 KVKK görüşü

Vardiya başlangıcındaki **kurye yüz fotoğrafı** biyometrik veri sayılırsa KVKK 6. madde kapsamında özel nitelikli kişisel veri olur. Sürekli konum takibi de çalışan izleme kapsamına giriyor. Açık rıza metni, saklama süreleri ve VERBİS kaydı için hukuk görüşü gerekiyor. Detay ve taslak metinler ayrı dokümanda.

### 1.8 Doküman sürüm karışıklığı

Bize ulaşan dosyanın adı **V3.0**, ancak içerik kendini **V2.1** olarak tanımlıyor. Kabul kriterleri bu dokümana atıf yapacağı için tek bağlayıcı sürümün netleştirilmesini rica ediyoruz.

---

## 2. Teknik riskler

| # | Risk | Etki | Önerilen aksiyon |
|---|---|---|---|
| R1 | Panel kapsam dışı, mobil panele bağımlı | Geliştirme ve test bloke | Workflow motoru + yayınlama Faz 1'e alınsın |
| R2 | Canlı trafik ücretli servis gerektiriyor | ETA kabul kriteri karşılanamaz | Faz 1'de trafiksiz ETA + tolerans |
| R3 | OEM pil yöneticileri (Xiaomi, Huawei, Oppo) arka plan servisini öldürüyor | Konum kaydı kopar, kanıt eksilir | Cihaz bazlı whitelist yönlendirmesi + saha testi |
| R4 | Mağaza arka plan konum incelemesi uzun sürüyor | Yayın tarihi kayar | Hesaplar ve gerekçe dosyaları hemen açılsın |
| R5 | Maskeli arama tedarik süresi | Sprint 3-4 bloke | Faz 0'da sözleşme süreci başlasın |
| R6 | Vardiya fotoğrafı KVKK 6. madde | Hukuki risk, yayın engeli | Hukuk görüşü + açık rıza akışı |
| R7 | Cihaz bütünlüğü (Play Integrity / App Attest) sert engelleme | Yanlış pozitif kuryeyi sahada kilitler | Risk skoru + loglama, doğrudan blok değil |
| R8 | Offline kuyruk + idempotent gönderim + medya yükleme | En zor mühendislik parçası | Tek başına 2-3 sprint ayrıldı |
| R9 | Doküman sürüm belirsizliği | Kabul anlaşmazlığı | Bağlayıcı sürüm yazılı teyit |

En kritik ikisi **R1** ve **R8**. R1 bir kapsam kararı, R8 bir süre kalemi.

---

## 3. Faz 1'de mutlaka yer alması gereken fonksiyonlar

Pilota çıkabilen, uçtan uca çalışan en küçük kapsam. Modül numaraları dokümandaki numaralandırmayla aynı.

**Çekirdek — M01-M05, M07, M09-M13, M16-M19, M21-M24**

- **Kimlik ve cihaz:** telefon + OTP aktivasyon, cihaz bağlama, izin sihirbazı (konum, kamera, bildirim)
- **Vardiya:** vardiya başlat/bitir, konum servisinin ayakta olduğunun doğrulanması
- **Dashboard ve dağıtım listesi:** günün görevleri, durum ve basit rota sırası
- **Görev detayı ve dinamik işlem sihirbazı:** panelden gelen workflow'un adım adım yürütülmesi
- **Kanıt toplama:** OTP doğrulama, fotoğraf kanıtı, evrak tarama (PDF), imza
- **Sonuçlandırma:** teslim edildi / teslim edilemedi (nedenli), ön kontrol ve gönderim
- **Zimmet:** kurye üzerindeki gönderi/evrak takibi
- **Destek ve bildirim:** destek kaydı açma, push bildirim
- **Offline senkron:** bağlantısız çalışma, kuyruk, idempotent gönderim, çakışma çözümü

**Faz 1.5'e önerilenler**

- M06 gelişmiş ETA + IVR orkestrasyonu (basit rota sırası Faz 1'de kalıyor)
- M25 QR kimlik, M26 barkod rota hazırlık
- M20 eğitim, M27 hakediş, M28 duyuru, M29 anket, M30 gönderi sorgulama

**Faz 2**

- M14 kimlik yakalama + KYC / e-imza

> Not: M14 için avantajımız var. Elimizde çalışır durumda bir Sodec SAMobileCapture entegrasyonu mevcut; Faz 2'de sıfırdan entegrasyon gerekmeyecek.

---

## 4. Tahmini geliştirme ve test takvimi

**Ekip varsayımı:** 2 backend, 2 Flutter, 1 QA, 0,5 DevOps.

| Aşama | Kapsam | Süre |
|---|---|---|
| Faz 0 | Sözleşme: OpenAPI, workflow şeması, veri modeli, sağlayıcı seçimi, iskele | 2 hafta |
| Sprint 1-2 | Kimlik, cihaz, izin, vardiya, görev listesi ve detayı | 4 hafta |
| Sprint 3-4 | Konum, geofence, basit rota, geocoding, maskeli arama, SMS olayları | 4 hafta |
| Sprint 5-6 | Workflow sihirbazı, OTP, teslim / teslim edilemedi, kanıt, gönderim | 4 hafta |
| Sprint 7 | Evrak tarama ve PDF üretimi | 2 hafta |
| Sprint 8-9 | Offline senkron, zimmet, destek, dashboard, sertleştirme | 4 hafta |
| Kabul | UAT, pilot saha testi, mağaza yayını | 4 hafta |
| **Toplam** | **Faz 1** | **~24 hafta (5,5 ay)** |

**Takvimi etkileyen kabuller**

- Tek Flutter geliştirici ile çalışılırsa **+8 hafta**.
- Panel (R1) Faz 1'e alınmazsa takvim verilemez; entegrasyon testi yapılamaz.
- Mağaza inceleme süresi son 4 haftaya dahildir, uzarsa dışarı taşar.
- Sağlayıcı sözleşmeleri Faz 0'da kapanmazsa Sprint 3-4 kayar.

---

## 5. Sizden beklediğimiz kararlar

1. Bağlayıcı doküman sürümü (V2.1 mi V3.0 mu?)
2. Panelin Faz 1 kapsamına alınması — ya da panel ekibinin sözleşmeye uyacağının teyidi
3. Faz 1 / Faz 1.5 kapsam ayrımının onayı
4. Ücretli trafik servisi için bütçe kalemi açılacak mı?
5. Mağaza hesaplarının açılması ve KVKK hukuk görüşü için sorumlu kişi

Bu beş madde kapandığında Faz 0'ı başlatabiliriz.
