# JetLogi / Dijigoo — Ana Plan

**Tarih:** 07.09.2026
**Kapsam netleşmesi (bu konuşmada):** Kullanıcının görevi (a) mobil uygulamayı sıfırdan/yeniden geliştirmek, (b) bazı API'lerde yardımcı olmak, (c) kurumsal web sitesini yapmak. Bu doküman bu üç görevi, bu oturumda toplanan tüm bulgularla (`docs/05`, `docs/06`) birleştirip tek bir yol haritasına indiriyor.
**Takip:** Bu plan Linear'a işlendi — [Panel Entegrasyonu (jetlogi-panel)](https://linear.app/flexlore/project/panel-entegrasyonu-jetlogi-panel-4e56684b93a0) ve [Kurumsal Web Sitesi](https://linear.app/flexlore/project/kurumsal-web-sitesi-4b843cabf90c) projeleri, JETLOG-15..27. Güncel durum için buradan çok Linear'a bakılmalı — orası canlı, bu dosya bir snapshot.

**Bu doküman neyin üzerine kurulu:** `docs/05-panel-entegrasyonu.md` (panel entegrasyon planı) + `docs/06-eski-panel-ve-repo-analizi.md` (eski sistem/repo analizi). Detay için oraya bakılmalı, burada sadece sentez ve aksiyon var.

---

## 0. Tek sayfalık özet

**Üç nesil sistem var, biri emekli olacak, biri geçiş halinde, biri bizim işimiz:**

| Sistem | Durum | Kim sahipleniyor |
|---|---|---|
| **Eski sistem** (`panel.jetlogi.net` + `api.jetlogi.net`) | **Canlı, üretimde** — 191.282 gönderi, gerçek müşteri (Borusan), bugün de yeni sipariş alıyor (kanıtlandı, `docs/06` §7.1) | Kimse aktif geliştirmiyor, sadece ayakta |
| **Yeni panel** (`kukaraca/dijigoo-ops` = `jetlogi-panel`) | Geçiş halinde — kurye onboarding/task list gerçek, finalize/custody/ticket henüz yok, kurumsal entegrasyon Hub'ı "planned" | Ruken Turhan (+ekibi) |
| **Bizim iş** (`apps/mobile`, `apps/api`, yeni web sitesi) | Mobil: apps/api'ye bağlı, panele geçiş hazır ama bağlanmadı. API: routing-proxy bitti. Web sitesi: başlamadı | **Kullanıcı (bu konuşma)** |

**07.09.2026 güncelleme — §1'deki açık karar netleşti (kullanıcı onayı):** "Sıfırdan mobil uygulama" = hâlihazırda üzerinde çalışılan `apps/mobile`'ın ta kendisi, yeni bir proje değil. Yani **(A) seçeneği doğrulandı** — mimari/tasarım sistemi korunuyor, veri kaynağı jetlogi-panel'e geçecek. Ayrıca yeni panelin (`kukaraca/dijigoo-ops`) gerçekten aktif yazıldığı da doğrulandı (zaten gözlemlenmişti, şimdi teyit edildi).

**Kilit karar (zaten netleşmişti):** Mobil, veri kaynağı olarak jetlogi-panel'in `public/v1/courier-*` API'sini kullanacak. Eksik kalan courier-facing uçları (finalize, custody, ticket, shift) **biz o repoda yazacağız** — bu, kullanıcının "bazı API'lerde yardımcı olmak" görevinin somut karşılığı.

**En büyük risk:** Eski sistem düşük kesinti toleransıyla, gerçek parayla/gerçek müşteriyle (Borusan) çalışıyor. Bu bir "eski, önemsiz sistemi değiştirme" projesi değil — **canlı bir platformu kesintisiz devretme** projesi.

---

## 1. Mobil uygulama — netleşti: (A), mevcut `apps/mobile` üzerinden devam

**Karar (kullanıcı onayı, 07.09.2026):** "Sıfırdan mobil uygulama" = hâlihazırda üzerinde çalışılan `apps/mobile`'ın ta kendisi. Yeni bir proje **değil**. Mimari/tasarım sistemi (`Dg` tema, `DgCard`, `StatusChip`, navigasyon, 43 test) korunuyor; veri kaynağı jetlogi-panel'e geçecek — aşağıdaki §1.1 aynen geçerli.

### 1.1 Mobil tarafta somut kalan iş

`docs/05` §4'teki 5 açık karardan ikisi mobilin önünü kesiyor:

1. **Kimlik doğrulama modeli** — bizim OTP+bearer vs. panelin cookie-session'ı. Panel değişmeyecek (Cursor'a "auth modelini değiştirme" denildi), yani mobilin cookie-session'a uyum sağlaması gerekiyor — bu zaten `PanelApi`'nin tasarımında var (`cookie_jar`/`dio_cookie_manager`), ama gerçek login akışı (email/telefon+şifre ekranı, mevcut OTP ekranının yanına/yerine) henüz yazılmadı.
2. **Offline/senkron modeli** — mevcut generic `outbox → /v1/sync/batch` yerine, panelin çok-uçlu senkron REST modeline (accept→start→finalize sırayla) uyacak yeni bir drain mantığı.

Bunların ikisi de **canlı/test edilebilir bir panel sunucusu olmadan** güvenle bitirilemez (bkz. §3).

---

## 2. API yardımı — somut liste

Kullanıcının "bazı API'lerde yardımcı olmak" görevi, `docs/05` §7 ve §2'de zaten spec'lenmiş durumda. Öncelik sırası:

1. **`courier-tasks/:id/finalize`** (jetlogi-panel reposunda) — teslim edildi/edilemedi. Kontrat + gerçek kod referansları (`applyShipmentWorkflowEvent`, `DELIVERY_RESULT_RECORDED` eventCode'u) `docs/05` §2'de hazır. **En yüksek öncelik** — hem mobil hem eski panelin devretmesi buna bağlı.
2. **Custody (zimmet) uçları** — `docs/05` §7'de tam spec + Cursor'a paste-ready prompt hazır (`InventoryUnitCustodyEvent` + 2 uç).
3. **Kurye-taraflı destek ticket ucu** — `SupportTicket` şeması zaten var, courier-facing `public/v1` ucu yok.
4. **Kendi `apps/api`'mizdeki routing-proxy** — **zaten bitti** (`POST /v1/routing/optimize`, test edilmiş, OpenAPI'de kayıtlı). Bu iş bitmiş sayılır.

**Yeni bulgu, tasarımı etkiler (`docs/06` §7.2):** Eski sistemin sipariş modeli bizim finalize/custody tasarımımızdan üç yerde daha zengin — görünürlük seviyeli notlar (müşteri görsün/görmesin), ayrı bir "kontrol edilme"/"firmaya teslim edildi" adımı (alıcıya teslimden farklı), ve admin panelden manuel teslimat-sonucu override butonları. Finalize/custody uçlarını yazarken bu üçünün gerekip gerekmediği panel ekibiyle (Ruken) netleştirilmeli — köre körüne bizim daha basit modelimizi dayatmamak lazım.

---

## 3. Web sitesi — en az netleşmiş parça (açık karar)

`jetlogi.com` bugün: sade bir kurumsal tanıtım sitesi (Anasayfa, Hakkımızda, Hizmetler, Belgeler, Kariyer, Bize Ulaşın, Kampanyalar, Gönderi Sorgulama), gerçek hizmet kataloğuyla (`docs/06` §4). Teknoloji tespiti yapılamadı (bot koruması nedeniyle sayfa kaynağı incelenemedi).

**Netleşmesi gerekenler (kullanıcıya sorulmalı, burada varsayılmadı):**
1. Bu, mevcut `jetlogi.com`'un **yeniden yapımı** mı, yoksa yeni platform için **ayrı bir marka/site** mi?
2. "Gönderi Sorgulama" (tracking) sayfası canlı API'ye mi bağlanacak — hangisine, eski `api.jetlogi.net`'e mi yoksa yeni jetlogi-panel'e mi?
3. Tasarım kaynağı var mı (Figma/Claude Design canvas gibi), yoksa mevcut site içerik/yapı olarak referans mı alınacak?
4. Bu repo içine mi (`apps/website` gibi yeni bir paket), yoksa tamamen ayrı bir proje mi?

Bu dört soru netleşmeden web sitesi için somut bir teknik plan yazmak spekülasyon olur — bilerek yazmadım.

---

## 4. Fazlı yol haritası (birleşik)

```
Faz A — Karar kilitleri (kod yazmadan önce)
  A1. ✅ Mobil "sıfırdan" ne demek — netleşti, (A): mevcut apps/mobile üzerinden devam
  A2. Web sitesi kapsamı — §3'teki 4 soru
  A3. Kimlik doğrulama modeli (mobil ↔ panel)
  A4. Not görünürlüğü / manuel override ihtiyacı (§2, panel ekibiyle)

Faz B — API: finalize + custody (jetlogi-panel reposunda, kullanıcı+Cursor)
  B1. courier-tasks/:id/finalize (docs/05 §2 spec'i)
  B2. courier-custody/* (docs/05 §7 spec'i)
  B3. courier-taraflı destek ticket ucu

Faz C — Mobil: panele gerçek kesim
  C1. Panel login ekranı (email/telefon+şifre, cookie-session)
  C2. session.dart'ı PanelApi'ye bağla (accept/start/location/finalize)
  C3. Offline drain'i çok-uçlu modele çevir (accept→start→finalize sırayla)
  C4. list_screen/task_detail_screen'i gerçek panel verisiyle çalıştır

Faz D — Web sitesi (A2 netleşince)
  D1. Kapsam/teknoloji kararı
  D2. İçerik/IA (mevcut jetlogi.com referans)
  D3. İnşa

Faz E — Eski sistemden kesim
  E1. Eski panel/API'nin hangi trafiği ne zaman kesileceği (191k+ canlı veri, agresif olmayan geçiş)
  E2. Faz B/C/D bitince paralel çalıştırma → kademeli kesim
```

**Şu an nerede olduğumuz:** Faz A'nın 4 maddesinden 1'i (A1, mobil kapsamı) kilitlendi; kalan 3'ü (web sitesi, auth modeli, not-görünürlüğü/override) hâlâ açık. Faz B'nin bir kısmı (spec + prompt) ve Faz C'nin altyapısı (`PanelApi`, testler) zaten hazır — kalan kararlar netleşince hızlı ilerlenebilir.

---

## 5. Şimdi, karar beklemeden yapılabilecekler

1. **Faz B1/B2'yi başlat** — spec'ler hazır, jetlogi-panel reposunda kod yazmaya şimdi başlanabilir (kullanıcı + Cursor). Mobil karara bağlı değil.
2. **§3'teki 4 soruyu netleştir** — web sitesi için gerçek bir başlangıç noktası olması için şart.
3. **Panel ekibiyle (Ruken) bir görüşme/mesaj** — açık kalan 4 madde: (a) eski API üretim trafiği ne zaman/nasıl kesilecek, (b) %33 iptal oranının sebebi, (c) not-görünürlüğü/manuel-override ihtiyacı, (d) auth modeli kararı.

## 6. Riskler (özet)

- **Kesinti riski:** Eski sistem gerçek, büyük ölçekli üretim (191k+ gönderi, Borusan). Ani geçiş yok.
- **Çift geliştirme riski:** Bu konuşma boyunca birkaç kez aynı işin paralelde iki yerde yapıldığı görüldü (mobil task-list wiring, custody). Faz A kilitlenmeden büyük yatırım yapılan her şey bu riski taşır.
- **Kapsam belirsizliği (web sitesi):** En az tanımlı parça — büyük olasılıkla en son başlanacak.
