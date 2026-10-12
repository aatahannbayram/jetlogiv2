# V4.0 Handoff → mobil uyarlama (Şube çekirdeği)

**Tarih:** 12.10.2026
**Kaynak:** `JetLogi_Mobil_App_Flutter_Teknik_Handoff_2026.pdf` (V4.0, 09.09.2026) + Şube Mobil API v1.2.0 (`https://api-mobile.preprod.jetdiji.com/swagger/branch.yaml`, rehber: `swagger/branch-guide.html`).
**Dal:** `feat/sube-v4-handoff`

Handoff "ne yapılacağını" anlatıyor; §17'deki uçlar öneri. Kod **gerçek API'ye** göre yazıldı. `docs/08-sube-acente-entegrasyonu.md` §4'teki "liste/yazma uçları yok" tespiti artık geçersiz: hepsi `portal/v1/branch/*` altında var.

## 1. Eşleme

| Handoff | API (portal/v1) | Mobil |
|---|---|---|
| §3 rol/yetki | `agency-auth/session` → `capabilities{operate, manage}` | düğmeler `operate` ile açılır |
| §4 dashboard | `GET branch/dashboard` | `sube_home_screen.dart` |
| §5 gönderiler, zimmet | `GET branch/dispatch`, `GET dispatch/options`, `POST dispatch/handover` | `sube_shipments_screen.dart` |
| §5.3, §6.2 kurye değişikliği | kabul bekleyen: `POST dispatch/handover/change`, iptal: `handover/cancel`; dağıtımda: `GET/POST dispatch/reassign` | aynı ekran, satır aksiyonları |
| §6 kurye havuzu | `dashboard.courierList` | `sube_couriers_screen.dart` |
| §7.3 stok giriş | `transfers/incoming` (+`scan`, `confirm`) | `sube_stock_screen.dart` |
| §7.5, §13.1 kurye → şube | `GET branch/pending`, `POST pending/courier-return-scan` | `sube_stock_screen.dart` |
| §8 sayım | `GET/POST branch/counts`, `GET/POST counts/{id}` (`scan`, `line-reason`, `close`) | `sube_count_screen.dart` |
| §9 merkeze sevk | `GET transfers/outgoing`, `POST outgoing/resolve`, `POST transfers/outgoing` | `sube_dispatch_screen.dart` |
| §13.3 gün sonu | `pending.endOfDay/overdue` + KPI'lar | `sube_eod_screen.dart` |
| §14 barkod motoru | — | `scan_router.dart` (`ScanContext` → işlem) |
| §19 offline | `Idempotency-Key`, `clientScanId` | `branch_workspace.dart` + mevcut `OutboxStore` |

Alt menü §2.3'e göre: Ana Sayfa • Gönderiler • Kuryeler • Stok & Zimmet • İşlemler + sabit "Barkod Okut" (açık sekmenin bağlamına gider).

## 2. Uygulanan kurallar

- **Sahte veri yok.** Örnek veri yalnız demo girişte; canlıda sunucu düşerse hata + yeniden dene gösterilir.
- **Çift taraflı zimmet.** Atama gönderiyi "Kabul bekliyor"a alır; kurye okutup kabul edene kadar dağıtımda sayılmaz.
- **Sunucu teyidi olmadan tamamlandı gösterilmez.** Sayım ve kurye dönüşü okutmaları outbox'a yazılır, okutma sırasıyla gönderilir; geçici hatada sıra durur, kalıcı ret `rejected` olur. Bekleyen okutma varken sayım kapatılamaz.
- **Idempotency.** Her yazma `Idempotency-Key` başlığıyla gider; yeniden deneme aynı anahtarı kullanır. Sayım okutması cihazlar arası çakışmasın diye `clientScanId` gerçek UUID'dir.
- **Çevrimiçi zorunlu:** atama, kurye değişikliği, iptal, sevk, sayım başlat/kapat.

## 3. API'nin karşılamadığı handoff maddeleri

Uydurulmadı, ekrandan kaldırıldı:

- §9.4 barkodsuz içerik transfere **satır** olarak eklenemez (her satır `shipmentId` ister); iç barkod Etiket ekranından üretilip koli barkodu olarak okutulur.
- §9.2 ayrı koli oluştur/kapat: koli = transferdeki `packageBarcodes`.
- §6.2 `reasonKey` zorunluluğu: `dispatch/reassign` yalnız isteğe bağlı `note` alır (neden zorunlu olan tek yer zimmet iptali).
- Şube stoğu sayaçları (§7.2 "Kullanılabilir / Hasarlı / Sayım farkında"): bu kırılımı veren uç yok.

## 4. Sonradan eklenenler (13.10.2026)

- **Etiket** (`sube_labels_screen.dart`): `GET/POST branch/labels` ile koli / paket / iç barkod etiketi üretir; ZPL'i ağdaki Zebra yazıcıya ham olarak (TCP 9100, `zpl_printer.dart`) gönderir ve yalnız baskı başarılıysa `printed` işaretler. Etiketi sunucu çizer, uygulama yorumlamaz (UAT-25). Bluetooth yazıcı ve A4/PDF çıktı yok.
- **Performans** (`sube_performance_screen.dart`): `GET branch/performance?range=today|7d|30d`; şube KPI'ları, kurye bazında ve günlük kırılım.
- **Gelen transfer detayı** (`sube_incoming_screen.dart`): kalem durumları, okut → İçeri Al (`accept`) → Transferi Onayla (`confirm`).
- **Merkeze sevk taslağı** cihazda saklanır (güvenli depo); uygulama kapanıp açılınca geri gelir, çıkışta silinir.
- **Şube oturumu** açılışta geri yüklenir (`restoreAgencySession`): saklı bearer `agency-auth/session` ile doğrulanır.

- **Kurye canlı konumu** (`live_location.dart`): başlatılmış görev varken konum `POST courier-tasks/{id}/location` (`ACTIVE_TASK`) ile panele akar — en fazla 30 sn'de bir ve ~50 m hareketten sonra, yalnız taze ölçüm; kuyruğa alınmaz. Panel kuryeleri haritada buradan görür, bu yüzden mobilde ayrı "kurye haritası" ekranı yok. Sınır: API'de göreve bağlı olmayan konum ucu yok (görevler arasında konum gitmez) ve takip yalnız uygulama ön plandayken çalışır.

## 4.0 Backend'e bağlananlar (13.10.2026, ikinci tur)

Kural: bütün API'ler backend'den gelir (`api-mobile…/api/public/v1` kurye, `/api/portal/v1` şube); kendi `apps/api`'mize yeni bağımlılık eklenmez.

**Kurye**
- Vardiya: `courier-shifts/start|end` (konum + `Idempotency-Key`, çevrimdışıysa kuyrukta). Önceden panel oturumunda vardiya backend'e hiç gitmiyordu.
- Gün sonu sayaçları: `courier-dashboard` (8 gösterge). Bekleyen kayıt varken vardiya kapanmaz.
- Eğitim: `courier-trainings` (liste, metin, tamamlama). Zorunlu eğitim **kilitlemez**, yalnız uyarır — backend kuralı (PDF §20.5 "politika gereği uyarı" kolu).
- Zimmet uyuşmazlığı: not + okutulanlar `courier-support/cases` kaydı olarak gider (ayrı uyuşmazlık ucu yok). Önceden not atılıyordu.

**Şube**
- Bildirimler + duyurular + operasyon uyarıları (`branch/notifications`, `branch/announcements`).
- Vardiya & İzin (`branch/courier-shifts`, `courier-leave-requests` + onay/ret; ret nedeni zorunlu, yetki `manage`).
- SMS (`branch/sms/templates|targets|preview|send`): önizleme görülmeden gönderilmez.

## 4.1 Hâlâ yok

- Şubede duyuru yayımlama, eğitim yönetimi, fatura mutabakatı, sözleşme/kart, hazırlık listesi, SMS geçmişi (API'de var, ekranı yok). Kurye haritası bilinçli olarak panelde.
- Kuryede backend'e bağlı olmayanlar: bildirim kutusu, mola, müsaitlik, cihaz kaydı (push), `courier-sync/batch`.
- Sayımda `manage` işlemleri (manuel giriş, okutma iptali, onay, iptal) — merkez/panelde.
- Sayım satırı adet alanları Swagger'da tanımsız (`additionalProperties`); `CountLine` bilinen adayları okur, şube hesabıyla canlı yanıt üzerinde doğrulanmalı.
- Hiçbir şube ucu canlı API'ye karşı denenmedi (şube hesabı yoktu); doğrulama sahte sunuculu testlerle.

## 5. Kurye tarafı — sonraki tur

Handoff'a göre eksik kalanlar: zimmet kabulünde uyuşmazlık kaydı (§5.3), kurye KPI panosu (§10.2), gün sonunda bekleyen senkron varken vardiya kapatma engeli (§13.2), zorunlu eğitim → görev kilidi (§20.5).
