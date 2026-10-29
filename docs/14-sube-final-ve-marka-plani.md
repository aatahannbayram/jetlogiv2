# Şube uygulaması final + Dijigoo kimlik geçişi: plan

**Tarih:** 29.10.2026
**Kapsam:** `apps/mobile` (Flutter). Şube/Acente akışının Hande'nin 20 maddelik revizyonuna göre tamamlanması, yeni kurumsal kimliğe (Kılavuz Sürüm 5.2, Ekim 2026) geçiş, hareket (motion) sistemi ve performans bütçesi.
**Girdiler:** Hande'nin revizyon notu, `Dijigoo_Kurumsal_Kimlik_FINAL (11).pdf` (40 sayfa), onaylı tasarım panosu, mevcut kod (101 Dart dosyası), `docs/08`, `docs/13`.
**Durum:** Plan. Kod yazılmadı. Bölüm 10'daki kararlar netleşmeden Faz 4 sonrasına geçilmemeli.

---

## 0. Özet

1. **Mevcut geliştirme korunur.** Şube tarafında 20 maddenin ~12'sinin temeli zaten var (dashboard, gönderi listesi + toplu atama, kurye dönüş okutması, transfer kabul, merkeze sevk, sayım, etiket, performans, bildirim, gün sonu, outbox). İş çoğunlukla **yeniden düzenleme + eksik adımları tamamlama**.
2. **Marka geçişi tek noktadan yapılır.** Bütün renk/tipografi `lib/theme.dart` içindeki `Dg` token'larından geliyor. Token değerleri değişince 101 dosyanın büyük kısmı otomatik yeni kimliğe geçer. Turuncu eylem rengi, Geist fontu ve JetLogi logoları kalkar; lacivert + marka mavisi + Inter gelir.
3. **Hareket sistemi zaten var, disipline edilecek.** `lib/motion.dart` iyi bir temel (StaggerIn, Appear, CountUp, Pressable, DgTabStack). Üzerine 5 süre + 3 eğri token'ı, 3 hareket seviyesi (Tam / Azaltılmış / Kapalı) ve 8 "imza an" eklenir. Sürekli dönen animasyon yok; boşta CPU ~0.
4. **En büyük risk backend.** 20 maddenin 7'si (gönderi detayı + işlem geçmişi, kurye haritası, cihaz bilgisi, fatura/hakediş, iş ortaklığı evrakları, dağıtım planlama, gün sonu kapatma) için mobilin konuşacağı uç **yok veya teyitsiz**. Bu ekranlar tasarlanır, canlıda uç gelene kadar yetki/özellik bayrağı ile gizlenir (`docs/13` kuralı: canlıda sahte veri yok).
5. **Proje klasörü git altında değil.** `docs/13`'te `feat/sube-v4-handoff` dalı geçiyor ama `Desktop/Dijigo` bir git deposu değil. Kodlamaya başlamadan önce asıl deponun hangisi olduğu netleşmeli.

---

## 1. Kurumsal kimlik: uygulamaya çevirisi

### 1.1 Kılavuzdan bağlayıcı kurallar

| Kural (PDF sayfa) | Uygulamadaki karşılığı |
|---|---|
| Ana logo = "Dijig" yazısı + sonsuzluk. Önüne D eklenmez (s.3, s.8) | Üst bar, splash, giriş ekranı: yalnız ana logo. D ikonu ile yan yana kullanılmaz. |
| D ikonu uygulama, favicon, avatar ve dar alanlarda bağımsız (s.4) | Uygulama ikonu, bildirim ikonu, profil/avatar boş durumu, 24 px altı yuvalar. |
| Minimum: ana logo 120 px genişlik, D ikonu 24 px (s.6) | `DijigooWordmark` 120 px altına inmez; daha dar yerde `DijigooMark` (D ikonu). |
| Koruma alanı x = D harfi yüksekliğinin 1/4'ü (s.5) | Logo widget'ı kendi içinde x kadar padding taşır, dışarıdan kırpılamaz. |
| Açık yüzey: lacivert yazı. Koyu yüzey: beyaz yazı (s.7) | `onDark` parametresi iki varyantı seçer. Tek renk varyant ikincil. |
| Sonsuzluk yeniden çizilmez, döndürülmez, renk geçişi yeniden üretilmez (s.7, s.8, s.10) | **Logo canlandırılırken çizgi-izleme (path trim), döndürme, gradyan kaydırma yapılmaz.** Yalnız bütün olarak opaklık ve ölçek. Yükleme göstergesi logodan türetilmez. |
| Ana renk akışı mor → mavi → turkuaz (s.10) | Yardımcı grafik: aktif sekme göstergesi, ince ayraç çizgisi (antetli/sunumdaki gibi), ilerleme çubuğu. Logoya uygulanmaz. |
| Inter: başlık SemiBold/Bold, gövde Regular, buton Medium (s.11) | Tek font ailesi Inter. Geist, Geist Mono, Newsreader, Archivo, IBM Plex Mono kaldırılır (APK küçülür). |
| Panel: "Durumlar renk, metin ve ikonla birlikte gösterilir" (s.35) | Hiçbir durum yalnız renkle anlatılmaz. Ortak `DgStatusChip` = ikon + metin + ton. |
| İki tema, aynı bilgi sırası (s.34, s.35) | Açık ve koyu tema eşit öncelikte. |

### 1.2 Logo varlıkları

- PDF'teki logo sayfaları **vektör** (s.3-6'da gömülü raster görsel yok). `pdftocairo -svg` ile ana logo (açık/koyu) ve D ikonu çıkarılır, viewBox kırpılır.
- Yine de tercih edilen kaynak tasarımcının orijinal SVG/AI dosyası. Gelirse onu kullanırız; gelmezse PDF'ten çıkan vektör.
- Çalışma zamanında SVG ayrıştırmamak için `vector_graphics_compiler` ile derlenmiş `.vec` dosyaları + `vector_graphics` paketi. Raster PNG yalnız uygulama ikonu ve native splash için.
- `assets/images/jetlogi_*.png` ve `brand.dart` içindeki elle çizilmiş harita iğnesi (`_MarkPainter`) kalkar.
- Uygulama ikonu: D ikonu, lacivert kare zemin (s.4). Android adaptive icon (ön plan D, arka plan #0A0F2B) + iOS. `flutter_launcher_icons` ile üretilir.
- Native splash: düz lacivert + ortada ana logo (`flutter_native_splash`). Flutter tarafındaki splash aynı kareden devralır, sıçrama olmaz.

### 1.3 Renk token'ları

Marka renkleri (s.9): Lacivert `#0A0F2B`, Mavi `#2563FF`, Mor `#8B5CF6`, Turkuaz `#06D6FF`; nötrler `#111827`, `#374151`, `#9CA3AF`, `#FFFFFF`.

Kontrast hesabı (WCAG 2.2, normal metin için 4.5:1, büyük metin/ikon için 3:1):

| Kombinasyon | Oran | Sonuç |
|---|---|---|
| Beyaz metin / Mavi `#2563FF` buton | 4.9 | Birincil buton için uygun |
| Mavi `#2563FF` metin / beyaz | 4.9 | Açık temada bağlantı/vurgu metni uygun |
| Mavi `#2563FF` metin / Lacivert | 3.9 | **Koyu temada küçük metinde yetersiz**, yalnız ikon/büyük metin |
| Mor `#8B5CF6` metin / beyaz | 4.2 | **Küçük metinde yetersiz**, yalnız dekor/ikon |
| Mor `#8B5CF6` / Lacivert | 4.4 | Sınırda, küçük metinde kullanılmaz |
| Turkuaz `#06D6FF` / Lacivert | 10.8 | Koyu temada vurgu metni için ideal |
| `#9CA3AF` / Lacivert | 7.4 | Koyu temada ikincil metin uygun |
| `#9CA3AF` / beyaz | 2.5 | **Açık temada metin olarak kullanılmaz** |

Önerilen token eşlemesi (`Dg` API adları korunur, yalnız değerler değişir):

| Token | Açık tema | Koyu tema | Not |
|---|---|---|---|
| `bg` (zemin) | `#F4F5F8` | `#0A0F2B` | Açık zemin PDF s.7'deki açık gri yüzey |
| `surface1` (kart) | `#FFFFFF` | `#111827` | |
| `surface2` (yükseltilmiş/giriş alanı) | `#EEF0F5` | `#1A2237` | Koyu değer türetilmiş |
| `text1` | `#0A0F2B` | `#FFFFFF` | |
| `text2` | `#374151` | `#C5CAD3` | Koyu değer türetilmiş |
| `text3` | `#5B6472` | `#9CA3AF` | Açık değer türetilmiş (gri 9CA3AF metinde yetersiz) |
| `action` (birincil buton) | `#2563FF` | `#2563FF` | Üstünde beyaz metin |
| `brand` (vurgu metni/ikon) | `#2563FF` | `#06D6FF` | Koyu temada turkuaz |
| `accent` (seçim, rozet) | `#8B5CF6` | `#8B5CF6` | Yalnız dolgu/ikon |
| `brandFlow` (gradyan) | mor → mavi → turkuaz | aynı | Yardımcı grafik |

**Durum renkleri kılavuzda yok.** Operasyon "teslim edildi / edilemedi / uyarı" ayrımına muhtaç. Öneri: marka paletiyle çatışmayan, kontrastı doğrulanmış üç anlam rengi eklenir ve her zaman ikon + metinle kullanılır:

| Anlam | Açık | Koyu | Örnek |
|---|---|---|---|
| Başarılı | `#15803D` | `#4ADE80` | Teslim edildi, onaylandı, yüklendi |
| Uyarı | `#B45309` | `#FBBF24` | Onay bekliyor, süresi doluyor, gecikmiş |
| Hata | `#B91C1C` | `#F87171` | Teslim edilemedi, eksik, reddedildi |
| Bilgi/aktif | `brand` | `brand` | Dağıtımda, kurye atandı |
| Nötr | `text3` | `text3` | İptal, pasif, çevrimdışı |

Bu üç renk kılavuzun dışında kaldığı için **marka ekibinin onayı** gerekiyor (Bölüm 10).

### 1.4 Tipografi ölçeği (Inter)

| Rol | Boyut / ağırlık | Kullanım |
|---|---|---|
| Display | 28 / SemiBold, -2% | Dashboard ana sayı, başarı ekranı |
| H1 | 22 / SemiBold | Ekran başlığı |
| H2 | 18 / SemiBold | Bölüm başlığı |
| Body | 16 / Regular | Gövde |
| Label | 14 / Medium | Buton, sekme, çip |
| Caption | 13 / Regular | Yardımcı bilgi, zaman |
| Overline | 12 / SemiBold, +6% harf aralığı | "CANLI OPERASYON" gibi küçük başlıklar |
| Sayı | Inter `tnum` (sabit genişlikli rakam) | KPI, barkod, adet |

Saha kuralı korunur: 14 pt altına inilmez (mevcut `Dg.ui` zaten 14'e yuvarlıyor), dokunma hedefi 48, eylem butonu 56.

### 1.5 Görsel dil

- Kartlar: gölgesiz, tonla ayrışan yüzeyler (mevcut karar korunur). Köşe 16, büyük kart 24.
- Marka dalgası (panodaki mor-mavi ışık dalgası): yalnız Ana Sayfa başlığında ve giriş ekranında, **önceden çizilmiş WebP** olarak (1x/2x/3x). Çalışma zamanında blur/gradyan hesaplanmaz.
- Antetli kâğıttaki ince gradyan çizgi: bölüm ayracı ve aktif sekme göstergesi olarak.
- İkonlar: Lucide (mevcut), 1.75 px çizgi, durum ikonları dolu varyant.

---

## 2. Bilgi mimarisi

### 2.1 Alt menü (sabit)

Ana Sayfa • Gönderiler • Kuryeler • İşlemler • Profil

Mevcut: Ana Sayfa • Gönderiler • Kuryeler • **Stok & Zimmet** • İşlemler. Stok & Zimmet İşlemler'in altına taşınır, Profil yeni sekme olur (çıkış İşlemler'den Profil'e geçer).

Sabit "Barkod Okut" düğmesi korunur ve açık sekmenin bağlamına gider (mevcut `ScanContext` mantığı). Üst barda: bildirim zili (okunmamış rozeti) + çevrimdışı kuyruk rozeti (bekleyen işlem varsa).

### 2.2 Ekran ağacı

```
Ana Sayfa
├─ KPI kartları (7) ──────────────► Gönderiler (filtreli)
├─ Canlı Operasyon (4) ───────────► Kurye Haritası / filtreli listeler
└─ Hızlı İşlemler: Kurye Ata · Kurye Dönüş · Transfer

Gönderiler
├─ Filtre çubuğu: Tarih · İlçe · Mahalle · Durum · Kurye · Öncelik
├─ Toplu seçim → Kurye Ata · Kurye Değiştir · Zimmetle · Evrak Yazdır · Ürün Eşleştir
└─ Gönderi Detayı (hızlı işlem ikonları + alanlar + İşlem Geçmişi)

Kuryeler
├─ Sekmeler: Aktif · Pasif · Harita · Performans
├─ + Yeni Kurye
└─ Kurye Detayı: Genel · Kurye Kartı · Evraklar · İletişim · Cihaz

İşlemler (gruplu hub)
├─ Saha: Kurye Ata · Kurye Dönüş · Gün Sonu
├─ Stok & Zimmet: Şube Stoku · Kurye Üzerindeki · Kurye Dönüşleri · Gelen Transferler · Merkeze Gönderilecekler · Sayım
├─ Transfer: Transfer Kabul · Merkeze Transfer · Transferlerim
├─ Belgeler & Finans: Fatura & Hakediş · İş Ortaklığı Evrakları · Dağıtım Planlama
└─ Diğer: Etiket · Eğitim Merkezi · Vardiya & İzin · SMS · Duyurular · Bekleyen İşlemler

Profil
└─ Kullanıcı · Şube · Rol/Yetki · İletişim · Bildirim Ayarları · Güvenlik · Uygulama Ayarları (tema, hareket seviyesi) · Yardım & Destek · Hakkında · Çıkış
```

### 2.3 Tekilleştirme (Hande: "aynı işi yapan sayfaları çoğaltmayalım")

| İş | Girişler | Tek uygulama |
|---|---|---|
| Kurye atama | Dashboard hızlı işlem, Gönderiler toplu, Gönderi detayı, İşlemler | `AssignFlow` (gönderi seç → kurye seç → onay). Gönderi önceden seçiliyse 1. adım atlanır. |
| Kurye dönüş | Dashboard, İşlemler, Kurye detayı, Barkod Okut (Stok bağlamı) | `CourierReturnFlow`. Kurye detayından açılırsa kurye seçili gelir. |
| Transfer | Dashboard "Transfer" → seçim sayfası: Gelen / Merkeze | `IncomingTransferFlow`, `OutgoingTransferFlow` |
| Barkod okutma | Tüm okutma noktaları | `DgScanInput` (Kamera / Manuel / Sesli) |
| Evrak yazdır | Gönderi toplu, Gönderi detayı, Merkeze transfer | Mevcut etiket/hazırlık servisi + tek yazdırma sayfası |

---

## 3. 20 madde: mevcut durum ve boşluk

Gösterim: **Var** = ekran ve uç mevcut. **Kısmen** = temel var, eksik adım/alan var. **Yok** = ekran yok. API sütunu mobil istemcinin bugün çağırdığı uçlara (`api/agency_client.dart`) ve `docs/13`'e dayanır; "teyit" yazanlar Swagger'da (`branch.yaml` v1.2.0) kontrol edilmeli.

| # | Madde | Mevcut ekran | Durum | API | Yapılacak |
|---|---|---|---|---|---|
| 1 | Ana Şube Dashboard | `sube_home_screen.dart` (11 KPI) | Kısmen | `branch/dashboard` var. "Teslim edilemeyen", "Hatalı/Eksik işlem" alanı yok (teyit) | KPI setini Hande'nin 7'lisine indir, Canlı Operasyon bloğu, Hızlı İşlemler, kart → filtreli liste |
| 2 | Gönderiler | `sube_shipments_screen.dart` (durum filtresi, çoklu seçim, atama) | Kısmen | `dispatch`, `handover`, `handover/change`, `reassign` var (tekil). Ürün eşleştir yok | 6 filtre (filtre sayfası), toplu işlem çubuğu, kart alanları |
| 3 | Gönderi Detayı | Yok | Yok | Detay ve işlem geçmişi ucu **yok** | Ekran + hızlı işlem ikonları; geçmiş için backend |
| 4 | Kurye Atama | Gönderiler içinde satır aksiyonu | Kısmen | `dispatch/options` (ad, kod, durum, uygunluk), `courier-jobs` var. Bölge/rota yok | 2 adımlı akış, kurye kartında bölge/gönderi/aktif iş, iptal |
| 5 | Kurye Dönüş | `sube_stock_screen.dart` içinde okutma | Kısmen | `pending`, `pending/courier-return-scan` var. "Dönüşü başlat" ucu yok (teyit) | Adımlı akış, 6 sonuç ayrımı, toplu "Teslim Al" |
| 6 | Kurye Haritası | Yok (bilinçli olarak panelde, `docs/13` §4) | Yok | Şube için konum ucu **yok** | Harita ekranı + pin kartı; backend uç gerekli |
| 7 | Kuryeler | `sube_couriers_screen.dart` (dashboard listesi) | Kısmen | `agency/couriers` var. Yeni kurye ekleme **merkezde** (`docs/08` §2) | Aktif/Pasif sekmeleri, kart alanları; "Yeni Kurye" kararı |
| 8 | Kurye Detayı | Parçalar var: kart (`SubeCardsScreen`), uyum (`SubeComplianceScreen`) | Kısmen | `compliance`, `compliance/cards`, `cards/verify` var. Cihaz bilgisi ucu **yok** | 5 sekmeli detay; Cihaz sekmesi backend'e bağlı |
| 9 | Kurye Performansı | `sube_performance_screen.dart` | Kısmen | `performance?range=today|7d|30d`: teslim, başarısız, oran, ilk deneme oranı | Özel tarih aralığı, kurye filtresi, karşılaştırma grafiği; iptal/hatalı/zamanında/ort. süre alanları teyit |
| 10 | Gün Sonu | `sube_eod_screen.dart` | Kısmen | `pending.endOfDay/overdue` var. **Kapatma ucu yok** | Kurye filtresi, 7'li özet, açık zimmet varken kilit |
| 11 | Stok & Zimmet | `sube_stock_screen.dart` | Kısmen | Şube stoğu sayaçları ucu yok (`docs/13` §3) | 6 bölümlü hub |
| 12 | Transfer Kabul | `sube_incoming_screen.dart` | Var | `incoming`, `incoming/scan` (otomatik bulma), `accept`, `confirm` | Adım başlığı, beklenen/okunan/eksik/fazla özeti, "Tümünü İçeri Al" |
| 13 | Merkeze Transfer | `sube_dispatch_screen.dart` + etiket | Kısmen | `outgoing`, `outgoing/resolve` var. Her satır `shipmentId` ister: **Ekipman / Evrak / Kart türleri desteklenmiyor**. "Transferlerim" listesi teyit | Tür seçimi, koli adımları, Transferlerim |
| 14 | Sayım | `sube_count_screen.dart` | Kısmen | `counts` + `scan`, `line-reason`, `close`, `post` var | Alt ekranlar (farklar, mutabakat), hasarlı alanı, "Merkeze Gönder → Mutabakat Bekliyor" durumu |
| 15 | Eğitim Merkezi | `SubeTrainingScreen` (şubenin **kuryelere** eğitim atadığı ekran) | Yok | Şube personelinin kendi eğitimleri için uç **teyit** (`targetType=COURIER` dışında) | Yeni ekran: 3 sekme, video/PDF/rehber kartları, ilerleme |
| 16 | Fatura & Hakediş | Yok | Yok | **Yok** (`docs/13` §4.1) | Ekran tasarımı + backend |
| 17 | İş Ortaklığı Evrakları + Dağıtım Planlama | Yok | Yok | **Yok** | Ekran tasarımı + backend |
| 18 | Bildirimler | `sube_inbox_screen.dart` + duyurular | Kısmen | `notifications`, `notifications/{id}/read`, `announcements/{id}/{action}` var | 5 kategori sekmesi, okundu filtresi, Okudum/Onaylıyorum |
| 19 | Offline Kuyruk | Altyapı var (`OutboxStore`, `flush`, kuryede `sync_screen.dart`) | Kısmen | Mevcut uçlar + `Idempotency-Key` | Şube ekranı, başarısızlar, bağlantı gelince otomatik gönderim |
| 20 | Profilim | `SubeAgencyInfoScreen` + çıkış | Kısmen | `agency-auth/session` (kullanıcı, rol, yetki) var | Profil sekmesi, ayarlar |
| G1 | Ortak barkod (Kamera / Manuel / Sesli) | `BarcodeScanPane` + `sube_scan_sheet.dart` (kamera + manuel) | Kısmen | Yok gerektirmez | Sesli mod (cihaz üstü, tr-TR) |
| G2 | Audit kaydı | İstemcide `Idempotency-Key`, `clientScanId` | Kısmen | Kayıt sunucunun işi; okuma ucu yok | İstemci her yazmada cihaz/sürüm/zaman/önceki statü gönderir; geçmiş ekranı backend'e bağlı |

**Sayısal özet:** 1 Var, 13 Kısmen, 6 Yok (+2 genel madde). Backend'e bağımlı ekran/alan: 3, 6, 8 (cihaz), 10 (kapatma), 13 (tür), 15, 16, 17, G2.

---

## 4. Ekran bazlı tasarım notları

Her ekran aynı iskeleti kullanır: başlık + (varsa) filtre/sekme + içerik + alt sabit eylem. Durumlar `DgStatusChip`, boş/hata/yükleniyor durumları ortak bileşenlerle.

**1. Dashboard.** Üstte marka dalgalı başlık (şube adı, kullanıcı, son senkron). 7 KPI kartı 2 sütunlu ızgara; "Hatalı/Eksik" ve "Teslim Edilemeyen" sıfırdan büyükse hata tonunda. Canlı Operasyon: 4 sayaç + "Haritada gör". Hızlı İşlemler: 3 büyük ikon düğme. Her kart `Gönderiler`'i ilgili filtreyle açar (filtre çipleri dolu gelir).

**2. Gönderiler.** Yatay kaydırılan hızlı durum çipleri + "Filtre" düğmesi (alt sayfa: tarih aralığı, ilçe → mahalle bağımlı seçim, durum, kurye, öncelik). Uzun basma veya onay kutusuyla seçim modu; altta seçili adet + 5 toplu işlem. Kart: gönderi no (tabular), alıcı, ilçe/mahalle, durum çipi, kurye, öncelik rozeti.

**3. Gönderi Detayı.** Üstte gönderi no + durum + SLA geri sayımı. 6 hızlı işlem ikonu (ızgara). Alanlar gruplu: Alıcı (ad, telefon ara düğmesi, adres harita bağlantısı), Ürün, Müşteri/Proje, Randevu, SLA. İşlem Geçmişi zaman çizelgesi (kullanıcı, saat, cihaz, önceki → yeni statü).

**4. Kurye Atama.** Adım 1: gönderi seçimi (Gönderiler'in filtre bileşeni). Adım 2: kurye listesi; kart: müsaitlik, bölge, üzerindeki gönderi, aktif iş, rota özeti; uygun olmayan kurye gri ve nedeni yazılı. Onay sayfası: "12 gönderi → Ahmet Y." + Ata. Toplu atama tek istekte değilse sıralı gönderim ve kısmi başarı raporu.

**5. Kurye Dönüş.** Adım başlığı: Kurye Seç → Başlat → Okut → Listele → Teslim Al. Okutulan her gönderi 6 sonuçtan birine düşer (sunucudan gelen durumla ön seçili, değiştirilebilir). Eksik okutulan gönderiler "kuryede kaldı" olarak üstte uyarı. Teslim Al sonrası zimmet güncellemesi sunucu teyidiyle gösterilir.

**6. Kurye Haritası.** `flutter_map` (mevcut). Pinler duruma göre renk + ikon; 30+ kuryede kümeleme. Pine dokununca alt kart: ad, son konum zamanı, gönderi sayısı, kalan durak, bölge, Ara, Detay. Konum yenileme 30 sn (kurye tarafı zaten 30 sn/50 m gönderiyor).

**7-8. Kuryeler ve Kurye Detayı.** Liste kartı: ad, bölge, araç tipi, durum, gönderi adedi. Detay 5 sekme. Kurye Kartı: dijital kart önizleme (D ikonu + ad + QR), Oluştur/Yenile/İptal. Evraklar: 6 belge satırı, durum çipi, süresi doluyor ise kalan gün. İletişim: Ara, Bildirim, SMS (mevcut SMS akışı önizleme zorunluluğuyla).

**9. Performans.** Tarih aralığı + kurye seçici. KPI kartları, kurye karşılaştırma yatay çubuk grafiği (renkler s.35'teki panel grafiği gibi mavi/mor/turkuaz). Grafik `CustomPainter`, tek seferlik çizim animasyonu.

**10. Gün Sonu.** Tarih + kurye filtresi, 7'li özet. Açık işlem/zimmet varsa "Gün sonu kapatılamaz" bloğu ve her birine doğrudan git bağlantısı. Kapat düğmesi yalnız temizse aktif.

**11-14. Stok, Transfer, Sayım.** Hepsi `DgStepFlow` başlığı ve `DgScanInput` ile. Sayılar her zaman "Beklenen / Okunan / Eksik / Fazla (/ Hasarlı)" sırasında, aynı bileşenle.

**15. Eğitim Merkezi.** 3 sekme. Kart: tür ikonu (video/PDF/rehber), süre, ilerleme halkası, tamamlandı rozeti. Not: Flexlore'un ürünü tam olarak bu alan (video SOP, quiz, hazırlık takibi); içeriğin Flexlore'dan beslenmesi bir seçenek, karar sizde (Bölüm 10).

**16. Fatura & Hakediş.** 4 sekme, dönem kartları. Detayda kalemler (+/- işaretli, tabular rakam), Net Ödeme vurgulu. Mutabakat onayı geri alınamaz bir işlem olarak onay penceresiyle. Onaydan sonra PDF yükle ve Excel'e aktar açılır.

**17. İş Ortaklığı Evrakları.** 4 alt bölüm, 5 durum. Dağıtım Planlama: açık ilçe listesi → ilçe → takvimden gün (onaylı günler işaretli) → talep gönder; talepler listesinde 3 durum.

**18. Bildirimler.** Kategori sekmeleri + "Okunmamış" anahtarı. Kritik bildirim kırmızı kenar şerit + ikon. Onay gerektiren duyuruda Okudum / Onaylıyorum düğmeleri.

**19. Bekleyen İşlemler (Offline Kuyruk).** Üstte bekleyen adet + son senkron. Liste: işlem tipi, zaman, durum (bekliyor / gönderiliyor / başarısız + neden). "Hemen Gönder", başarısızlarda "Tekrar Dene". Bağlantı gelince otomatik `flush` (bağlantı dinleyicisi eklenir).

**20. Profil.** Liste düzeni; Uygulama Ayarları altında Tema (Sistem / Açık / Koyu) ve Hareket (Tam / Azaltılmış / Kapalı).

**Ortak barkod bileşeni (`DgScanInput`).** Üç sekmeli tek bileşen: Kamera (mevcut `BarcodeScanPane`), Manuel (klavye, tabular), Sesli (mikrofon ikonu, cihaz üstü konuşma tanıma, Türkçe rakam/harf normalizasyonu: "sıfır" → 0, "be" → B; sonuç onay için gösterilir, otomatik gönderilmez). Her okutma aynı geri bildirimi verir (Bölüm 5.3).

---

## 5. Hareket (motion) sistemi

Hedef: tatlı ve kararında, "cool" ama işi yavaşlatmayan. Saha kullanıcısı aynı işlemi günde yüzlerce kez yapıyor; tekrarlanan işlemde animasyon kısa, nadir ve önemli anda biraz daha belirgin.

### 5.1 Token'lar

| Token | Süre | Eğri | Kullanım |
|---|---|---|---|
| `press` | 90 ms | easeOut | Basınca küçülme (0.97) |
| `quick` | 160 ms | easeOutCubic | Çip, anahtar, ikon geçişi, renk değişimi |
| `standard` | 240 ms | easeOutCubic (giriş), easeInCubic %70 süre (çıkış) | Kart girişi, sekme, alt sayfa içeriği |
| `emphasized` | 360 ms | Cubic(0.2, 0, 0, 1) | Sayfa geçişi, başarı anı, splash logosu |
| `max` | 450 ms | | Hiçbir UI animasyonu bunu aşmaz |
| `spring.sheet` | kütle 1, sertlik 420, sönüm 34 | | Alt sayfa, sürükleme bırakma |

Mevcut `motion.dart` süreleri (220/280/320/420/520 ms) bu token'lara toplanır; `CountUp` 520 → 400 ms.

### 5.2 Hareket seviyeleri

| Seviye | Ne olur | Ne zaman |
|---|---|---|
| Tam | Tüm token'lar | Varsayılan |
| Azaltılmış | Kaydırma/ölçek yok, yalnız 120 ms opaklık; sayaç sayımı yok; nabız noktaları sabit | Kullanıcı seçerse, sistem "hareketi azalt" açıksa, **veya** cihaz yavaşsa (aşağıda) |
| Kapalı | Sıfır animasyon (mevcut `disableAnimations` davranışı) | Kullanıcı seçerse |

Otomatik düşürme: açılıştan sonraki ilk 10 sn'de `SchedulerBinding.addTimingsCallback` ile kare süreleri ölçülür; karelerin %15'inden fazlası 16.6 ms'yi aşıyorsa oturum boyunca "Azaltılmış"a geçilir. Maliyeti yok denecek kadar az, zayıf telefonda kendiliğinden hafifler.

### 5.3 İmza anlar (8 adet, başka "özel" animasyon eklenmez)

| An | Hareket | Neden ucuz |
|---|---|---|
| 1. Açılış | Native splash (lacivert + logo) → Flutter'da aynı logo 0.96 → 1 ölçek + opaklık (360 ms), arkada marka dalgası 24 px yukarı kayarak belirir. Oturum geri yüklenince biter, beklenmez | Tek görsel, yalnız transform/opaklık |
| 2. Ana sayfa başlığı | Marka dalgası kaydırmayla 0.3x paralaks | Ticker yok; `ScrollController` değeriyle `Transform.translate`, kaydırma durunca kare üretmez |
| 3. Alt menü | Aktif sekmenin altındaki gradyan kapsül yaya (spring) kayar; ikon boş → dolu çapraz geçiş | Tek `AnimatedPositioned`, gradyan sabit |
| 4. KPI sayıları | Değer değişince sayım (400 ms); ilk yüklemede kartlar en fazla 6 x 30 ms kademeli | Yalnız metin; değer aynıysa animasyon yok |
| 5. Barkod geri bildirimi | Başarılı: turkuaz halka büyüyüp kaybolur + onay ikonu (300 ms) + hafif titreşim + kısa ses. Uyarı: amber tek nabız. Hata: 320 ms sarsılma + güçlü titreşim | `RepaintBoundary` içinde küçük katman |
| 6. Toplu seçim | Seçilen kartta onay işareti ölçekle girer; alt işlem çubuğu 240 ms aşağıdan kayar, adet sayılır | Tek çubuk, liste yeniden çizilmez |
| 7. Liste → detay | Gönderi no ve durum çipi `Hero` ile detaya uçar | Flutter yerleşik, iOS geri kaydırma korunur |
| 8. İşlem tamamlandı | Gün sonu kapandı / transfer kabul edildi / sayım gönderildi: onay ikonu + mor-mavi-turkuaz halka bir kez dolar (500 ms) | Tek seferlik `CustomPainter` |

Haritada kurye pini yeni konuma 800 ms'de kayar (yalnız konum güncellemesi geldiğinde), seçili pinde tek halka nabzı.

### 5.4 Yasaklar (performans ve marka)

- Logo çizgi-izleme, döndürme, gradyan kaydırma (kılavuz s.8, s.10).
- Liste içinde `BackdropFilter`, blur, animasyonlu gölge, animasyonlu `ClipPath`.
- Her karede gradyan duraklarını değiştirmek.
- Ekranda görünmeyen veya uygulama arka plandayken çalışan ticker.
- Boşta sonsuz döngü. İstisna: canlı durum noktası (2 sn opaklık, yalnız görünür olanlar). `HeroBackground` içindeki 8 sn'lik sürekli `_VividHero` döngüsü kaldırılır veya tek seferliğe çevrilir.
- Lottie/Rive bağımlılığı (gerekmiyor; ihtiyaç olan her şey yerleşik).

---

## 6. Performans bütçesi ve doğrulama

| Ölçü | Hedef | Nasıl ölçülür |
|---|---|---|
| Kare hızı | Referans cihazda 60 fps, p90 build < 8 ms, p90 raster < 8 ms | `flutter run --profile` + DevTools; `integration_test` içinde `traceAction` özetleri |
| Soğuk açılış | İlk kare < 2.5 sn (referans cihaz) | `flutter run --profile --trace-startup` |
| Boşta | Etkileşim yokken 0 kare | Performans katmanı / DevTools |
| Uzun liste | 500 gönderide kaydırma takılmasız | `ListView.builder`, mümkünse `itemExtent`, sabit (`const`) alt ağaçlar |
| Uygulama boyutu | Net artış ≤ +1 MB | 5 font ailesinin kaldırılması artışı karşılar |
| Bellek | Harita + 50 kurye pininde < 250 MB | DevTools Memory |

Test senaryoları (otomatik, profile modda): Dashboard kaydırma, Gönderiler 500 satır kaydırma, 50 gönderi toplu seçim, barkod sayfası aç/kapa, 50 kuryeli harita. Referans cihazı Bölüm 10'da belirlenmeli; şubelerdeki en zayıf telefon ölçü alınmalı.

Diğer kurallar: animasyonlu adalar `RepaintBoundary` içinde; görseller `cacheWidth` ile; logo derlenmiş vektör; Impeller açık (Flutter 3.47 varsayılanı).

---

## 7. Ortak bileşenler (yeni veya yenilenen)

| Bileşen | Ne yapar | Kullanıldığı yerler |
|---|---|---|
| `DijigooWordmark`, `DijigooMark` | Ana logo ve D ikonu, koruma alanı ve minimum boyut kuralları içinde | Splash, giriş, başlık, kart, avatar |
| `DgStatusChip` + `ShipmentStatus` eşlemesi | Sunucu statüsü → etiket + ton + ikon; tek sözlük | Tüm listeler, detay, harita |
| `DgKpiCard` | Sayı + etiket + ton + dokununca filtreli hedef | Dashboard, Gün Sonu, Performans |
| `DgFilterBar` + filtre alt sayfası | Hızlı çipler + gelişmiş filtre, seçili filtre özeti | Gönderiler, Atama, Performans, Gün Sonu |
| `DgSelectableList` + `DgBulkBar` | Seçim modu, adet, toplu işlemler | Gönderiler, Atama, Kurye Dönüş |
| `DgScanInput` | Kamera / Manuel / Sesli + ortak geri bildirim | Tüm okutma noktaları |
| `DgStepFlow` | Adım başlığı, geri, ilerleme | Atama, Dönüş, Transfer, Sayım, Dağıtım talebi |
| `DgCountSummary` | Beklenen / Okunan / Eksik / Fazla / Hasarlı | Transfer, Sayım, Kurye Dönüş |
| `DgDocRow` | Belge + durum + yükle/gör | Kurye evrakları, İş ortaklığı evrakları |
| `DgActionGrid` | İkonlu hızlı işlem ızgarası | Dashboard, Gönderi detayı |
| `DgTimeline` | İşlem geçmişi | Gönderi detayı, Transferlerim |
| `DgSyncBadge` | Bekleyen işlem rozeti | Üst bar, Profil |
| `DgPillNav` (yenilenir) | 5 sekme, gradyan gösterge | Kabuk |

Mevcut `widgets.dart` (2.851 satır) bileşenleri korunur; yeni bileşenler `lib/ui/` altında ayrı dosyalarda tutulur ki dosya büyümesin.

---

## 8. Teknik notlar

- **Durum yönetimi:** mevcut Riverpod + `BranchWorkspace` deseni korunur. Yeni modüller (`invoice`, `partner_docs`, `training_center`, `courier_detail`) ayrı küçük workspace sınıfları olarak eklenir; `branch_workspace.dart` (1.233 satır) daha fazla büyütülmez.
- **Özellik bayrakları:** `session.capabilities` (`operate`, `manage`) yanına "uç mevcut mu" bayrakları. Canlıda ucu olmayan ekran gizlenir; demo girişte örnek veriyle görünür (mevcut kural).
- **Audit:** her yazma isteğine `X-Device-Id`, `X-App-Version`, `X-Client-Time` başlıkları ve gövdede `previousStatus` (biliniyorsa). Kaydın kendisi sunucuda tutulur.
- **Offline:** `connectivity_plus` ile bağlantı geri gelince `flush`. Çevrimiçi zorunlu işlemler değişmez (atama, iptal, sevk, sayım başlat/kapat).
- **Sesli okutma:** `speech_to_text` (cihaz üstü, `tr_TR`). Mikrofon izni yalnız ilk kullanımda istenir. Gürültülü depoda başarı oranı düşük olabilir; manuel her zaman yedek.
- **Yeni bağımlılıklar:** `vector_graphics` (+ dev: `vector_graphics_compiler`), `flutter_launcher_icons`, `flutter_native_splash` (dev), `speech_to_text`, `connectivity_plus`, harita kümeleme için `flutter_map_marker_cluster`. Kaldırılanlar: 5 font ailesi, JetLogi görselleri.
- **Kurye uygulaması:** tema ortak olduğu için kurye ekranları da otomatik yeni renklere geçer. Kurye akışlarının işlevi değişmez; yalnız görsel kontrol turu gerekir.
- **l10n:** yeni metinler mevcut `l10n.dart` yapısına eklenir (1.857 satır, Türkçe/İngilizce).
- **Testler:** mevcut 29 test dosyası korunur. `sube_shell_test`, `navigation_design_test`, `field_design_test` yeni IA ve token'lara göre güncellenir; her yeni akış için widget testi, her toplu işlem için kısmi başarı testi.

---

## 9. Fazlar

Büyüklük: S (1-2 gün), M (3-5 gün), L (1-2 hafta). Bunlar kaba tahmin; backend uçlarının hazır olma tarihi takvimi asıl belirleyecek.

| Faz | İçerik | Büyüklük | Bağımlılık |
|---|---|---|---|
| F0 Hazırlık | Asıl git deposu ve dal; logo SVG'lerinin çıkarılması; mevcut ekranların ekran görüntüsü ve performans ölçümü (önce/sonra karşılaştırması için) | S | Bölüm 10 / 1, 8 |
| F1 Marka ve token | `theme.dart` değerleri, Inter, logo widget'ları, uygulama ikonu, native splash, durum sözlüğü, turuncunun kaldırılması | M | Durum renkleri onayı |
| F2 Hareket sistemi | Token'lar, hareket seviyeleri, otomatik düşürme, 8 imza an, `_VividHero` temizliği | M | F1 |
| F3 Ortak bileşenler | Bölüm 7 listesi | L | F1 |
| F4 Kabuk ve IA | 5 sekme, İşlemler hub, Profil, üst bar rozetleri, tekil akış girişleri | M | F3 |
| F5 API'si hazır ekranlar | Dashboard (1), Gönderiler (2), Atama (4), Kurye Dönüş (5), Kuryeler (7), Performans (9), Gün Sonu ekranı (10), Stok hub (11), Transfer Kabul (12), Merkeze Transfer (13, desteklenen türler), Sayım (14), Bildirimler (18), Bekleyen İşlemler (19), Profil (20) | L (2 tur) | F4 |
| F6 Backend'e bağlı ekranlar | Gönderi Detayı + Geçmiş (3), Harita (6), Kurye Detayı + Cihaz (8), Eğitim (15), Fatura (16), Evrak + Dağıtım (17), Gün sonu kapatma, Ürün eşleştir. Önce demo veriyle UI, uç gelince bağlama | L | Backend |
| F7 Sesli okutma ve cila | `DgScanInput` sesli mod, erişilebilirlik turu, performans turu (Bölüm 6), kurye ekranları görsel kontrol | M | F5 |
| F8 Doğrulama ve yayın | Testler, preprod API'ye karşı şube hesabıyla uçtan uca deneme (`docs/13`: hiçbir şube ucu canlıda denenmedi), mağaza görselleri | M | Şube test hesabı |

F1-F3 bittiğinde, ekran yeniden düzenlemesi başlamadan, Dashboard + Gönderiler'in yeni kimlikli bir örneği gösterilip onay alınması öneriliyor. Görsel yön erken onaylanırsa geri kalan ekranlar hızlanır.

### Backend'den istenecek uçlar (panel/API ekibi için liste)

1. Gönderi detayı (alıcı, telefon, adres, ürün, müşteri/proje, randevu, SLA) ve işlem geçmişi (audit kayıtları).
2. Dashboard'a "teslim edilemeyen", "hatalı/eksik işlem" sayaçları.
3. Şube kapsamında kurye canlı konumları (son konum, zaman, kalan durak).
4. Kurye cihaz bilgisi (model, OS, uygulama sürümü, son giriş/senkron, izinler).
5. Kurye dönüşü başlatma/kapatma ve sonuç kategorileri.
6. Gün sonu kapatma (açık zimmet kontrolü sunucuda).
7. Merkeze transferde gönderiye bağlı olmayan kalemler (ekipman, fiziki evrak, kart) ve "transferlerim" listesi.
8. Sayımda hasarlı adedi ve mutabakat durumları.
9. Şube personeli eğitimleri (atanan/tamamlanan, ilerleme).
10. Fatura & hakediş (liste, detay kalemleri, mutabakat onayı, itiraz, PDF yükleme, dışa aktarma).
11. İş ortaklığı evrakları ve dağıtım planlama talepleri.
12. Ürün eşleştirme (tanımı netleşmeli).
13. Performansta iptal, hatalı işlem, zamanında teslim oranı, ortalama teslim süresi, özel tarih aralığı.

---

## 10. Netleşmesi gereken kararlar

| # | Soru | Neden önemli | Önerim |
|---|---|---|---|
| 1 | Asıl git deposu hangisi? (`Desktop/Dijigo` git altında değil) | Geri alınabilirlik, dal, inceleme | Kodlamadan önce depo ve dal belirlensin |
| 2 | "Kurye Ata" ile "Zimmetle" farkı ne? | Bugün atama zaten çift taraflı zimmet başlatıyor (`docs/13` §2). İkisi ayrı işlemse yeni uç gerekir | Ata = planlama (kuryenin listesine ekle), Zimmetle = fiziksel teslim (okutarak). Hande teyit etmeli |
| 3 | Ucu olmayan ekranlar canlıda nasıl görünsün? | Sahte veri yasağı | Canlıda gizli, demo girişte görünür |
| 4 | Durum renkleri (yeşil/amber/kırmızı) marka dışı; onaylanıyor mu? | Operasyonda anlam rengi şart | Bölüm 1.3'teki değerler, her zaman ikon + metinle |
| 5 | Varsayılan tema | Gün ışığında açık tema, depoda koyu tema daha okunaklı | Sistem temasını izle; iki tema eşit kalitede |
| 6 | Referans test cihazı | Performans bütçesi buna göre ölçülür | Şubelerdeki en zayıf Android model |
| 7 | "Yeni Kurye Ekle" şubede ne yapar? | Kurye hesabı merkezde açılıyor (`docs/08` §2) | Şube başvuru/davet oluşturur, merkez onaylar |
| 8 | Logo kaynak dosyaları (SVG/AI) | PDF'ten çıkarılan vektör yeterli ama orijinal daha güvenli | Tasarımcıdan iste; gelmezse PDF'ten çıkarılır |
| 9 | Hande'nin "ekte paylaştığım görsel örnekler" | Notta geçiyor, elimizde yok | Paylaşılsın |
| 10 | Eğitim Merkezi içeriği nereden gelecek? | Ayrı içerik sistemi gerekebilir | Backend'de yoksa Flexlore ile beslenmesi değerlendirilsin |
| 11 | Kurye uygulaması da bu turda yeni kimliğe geçsin mi? | Tema ortak; geçiş otomatik olur | Evet, yalnız görsel kontrol turuyla |

---

## 11. Uygulama durumu (29.10.2026, ilk tur)

**Yapıldı**

- F0: `backups/mobile-before-rebrand-20261029.tar.gz` (değişiklik öncesi tam kopya). Git bağlanmadı: `aatahannbayram/jetlogiv2` dallarının en yenisi 77 Dart dosyası, yerel kod 101 dosya; yerel klasör tüm dallardan ileride.
- F1 marka: `theme.dart` token'ları Dijigoo paletine ve Inter'e geçti (5 font ailesi kaldırıldı). Logo ve D ikonu PDF'ten birebir çıkarıldı (`assets/brand/`, sonsuzluk işareti PDF'te zaten raster olduğu için PNG @1x/2x/3x; plandaki `vector_graphics` gerekmedi). Uygulama ikonu (iOS + Android adaptive), native splash (Android 12+ dahil), uygulama adı "Dijigoo". Marka dalgası çevrimdışı üretilmiş tek WebP.
- Kontrast testi iki değeri düzeltti: açık temada vurgu mavisi `#1D4FE0`, uyarı `#9A4508`, başarılı `#136C37`, çizgi `#737C8C`; eylem gradyanı yalnız beyaz metni taşıyabilen mavi tonlarda. Marka mavisi `#2563FF` buton dolgusu olarak aynen kullanılıyor.
- F2 hareket: `DgMotion` token'ları, `MotionGovernor` (Otomatik/Tam/Azaltılmış + ilk 10 sn kare ölçümüyle otomatik düşürme), `MotionScope`, `ParallaxLayer`, `ScanPulse`, `DoneRing`, `FlowProgressRing`; alt menüde kayan marka akışı göstergesi; `_VividHero` sürekli döngüsü tek seferliğe çevrildi.
- F4 kabuk: Ana Sayfa / Gönderiler / Kuryeler / İşlemler / Profil. Stok & Zimmet İşlemler'e taşındı, çıkış Profil'e. Sekme geçişi ve "filtreyle aç" `sube_nav.dart` üzerinden.
- Dashboard: lacivert marka başlığı (dalga paralaksı, teslim halkası), kartlar ilgili filtreli listeye/ekrana gidiyor, Canlı Operasyon ve Hızlı İşlemler.
- İşlemler merkezi gruplu, Profil (kullanıcı, rol, şube, tema, hareket, dil, çıkış) yeni.
- Testler: 751/751 geçiyor (yeni: dashboard kartı → filtreli Gönderiler). Analizde hata yok.

**Açık / doğrulanmadı**

- `todayToDeliver` kalan iş gibi davranıyor (demo: 7 kalan, 19 teslim); teslim oranı buna göre hesaplanıyor. Swagger'dan teyit edilmeli.
- "Teslim edilemeyen" kartı gösterilmiyor (sunucuda alan yok). "Hatalı / eksik işlem" kartı `kpis.pending` değerini gösteriyor; anlamı teyit edilmeli.
- Gerçek cihazda/simülatörde derlenmedi; ikon ve splash dosyaları yalnız dosya düzeyinde doğrulandı.
- Sıradaki: ortak filtre çubuğu + toplu işlem çubuğu, Kurye Atama ve Kurye Dönüş adımlı akışları, Kuryeler sekmeleri, Gün Sonu kilidi, Bekleyen İşlemler ekranı, `ScanPulse`/`DoneRing`'in okutma ve tamamlama ekranlarına bağlanması, sesli okutma.

---

## 12. İç ekranların yeni tasarıma geçmesi (web dalı, 29.10.2026)

**Neden:** Yeni kimlik ilk turda web dalına yalnız tema katmanı (renk, yazı tipi, logo, ikon, hareket) olarak taşındı. Web dalının şube ekranları (eski 5 sekme: Ana / Gönderi / Kurye / Stok / İşlem, kutulu ana sayfa, düz İşlemler listesi) korunduğu için iç ekranlar kurumsal kimlik örneğindeki mobil uygulama görünümüne ve Hande'nin istediği yapıya uymadı.

**Yapılacaklar (bu turda):**

| Ekran | Değişiklik |
|---|---|
| Kabuk | Alt menü Ana Sayfa / Gönderiler / Kuryeler / İşlemler / Profil. Stok & Zimmet İşlemler'e iner, çıkış Profil'e. Web dalının `SubeNav` gezinmesi tek kaynak; paralel `sube_nav.dart` kaldırılır. |
| Ana Sayfa | Lacivert marka başlığı (dalga paralaksı, selam, şube, son senkron, teslim halkası), "Bugün" kartları, "Canlı operasyon", "Hızlı işlemler". Web dalındaki tanıtım turu korunur. Her kart ilgili filtreli listeye/ekrana gider. |
| İşlemler | Gruplu merkez: Saha, Stok & Zimmet, İletişim & Eğitim, Şube. Web dalının eklediği Fatura & Hakediş, Acente bilgileri ve Hazırlık listesi korunur. |
| Profil | Kullanıcı, rol/yetki, şube, tema, hareket seviyesi, dil, çıkış. |

**Sonraki tur:** Gönderiler filtre çubuğu + toplu işlem çubuğu, Kurye Atama ve Kurye Dönüş adımlı akışları, Kuryeler sekmesindeki alt sekmeler ve kurye ekranlarının (görev listesi, ziyaret) aynı görsel dile geçmesi.
