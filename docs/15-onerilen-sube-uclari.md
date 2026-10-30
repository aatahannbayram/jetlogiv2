# 15 · Şube: Swagger'da olmayan uçlar için önerilen sözleşme

**Tarih:** 30.10.2026
**Karşılaştırılan:** Şube Mobil API v1.2.0 (`https://api-mobile.preprod.jetdiji.com/swagger/branch.yaml`). Swagger'daki 66 ucun hepsi uygulamada kullanılıyor.

Bu belgedeki uçlar ve alanlar **JetDiji'de henüz yok**. Mobil uygulama bunlara göre hazırlandı. Her biri `lib/branch_features.dart` içindeki bir bayrağa bağlı ve bayraklar kapalı. Canlıda bayrak kapalıyken ekran "Merkez bağlantısı bekleniyor" gösterir. Demo girişte ekranlar örnek veriyle çalışır.

JetDiji ucu yayınlayınca yapılacaklar:
1. Alan adları Swagger'daki gerçek adlarla karşılaştırılır. Farklıysa `lib/api/branch_proposed_models.dart` ve `agency_client.dart` içindeki "Önerilen uçlar" bölümü düzeltilir.
2. Bayrak açılır. Kod değişmeden de açılabilir: `--dart-define=BF_<AD>=true`.

Genel kurallar mevcut Swagger ile aynıdır: yanıt `{success, data}` zarfında gelir, yazma uçları `Idempotency-Key` ister, hata `error.code` taşır.

| # | Alan | Bayrak (`--dart-define`) | Uç |
|---|---|---|---|
| 1 | Sözleşme ve evrak | `BF_PARTNER_DOCUMENTS` | `GET branch/compliance` (mevcut, alanlar dolmalı) |
| 2 | Fatura & hakediş | `BF_INVOICES` | `GET branch/invoices` (mevcut, alanlar dolmalı) |
| 3 | Gönderiler tarih süzgeci | `BF_SHIPMENT_DATE` | `GET branch/dispatch?date=` |
| 4 | Performans serbest aralık | `BF_CUSTOM_RANGE` | `GET branch/performance?range=custom&from=&to=` |
| 5 | Gün sonu kapatma | `BF_EOD_CLOSE` | `GET branch/end-of-day`, `POST branch/end-of-day/close` |
| 6 | Şube stok sayaçları | `BF_STOCK_COUNTERS` | `GET branch/stock-summary` |
| 7 | Dağıtım planlama talebi | `BF_DISTRIBUTION_PLANNING` | `GET`/`POST branch/distribution-plans` |
| 8 | Kurye detayı, plaka, davet | `BF_COURIER_CREATE` | `GET agency/couriers/{courierId}`, `POST agency/couriers/invitations` |
| 9 | Kurye cihaz bilgisi | `BF_COURIER_DEVICE` | `GET agency/couriers/{courierId}` içinde `device` |
| 10 | Kart yenile / iptal | `BF_CARD_RENEW` | `POST branch/compliance/cards` (`renew: true`), `POST branch/compliance/cards/revoke` |
| 11 | Toplu ürün eşleştirme | `BF_PRODUCT_MATCH` | `POST branch/shipments/product-match` |
| 12 | Şube destek hattı | `SUBE_SUPPORT_PHONE` (yedek) | `agency-auth/session` → `user.agency.supportPhone` |

Mobilde henüz ekranı olmayan: **gönderiye bağlı olmayan merkez transferi** (ekipman, evrak, kart). `transfers/outgoing` gövdesine `items: [{kind: EQUIPMENT|DOCUMENT|CARD, description, quantity}]` önerilir. Ekran, uç kesinleşince yapılacak.

---

## 1. Sözleşme ve evrak · `GET branch/compliance`

Bugün `schemaReady: false` ve her kalem `NOT_AVAILABLE`. Beklenen: `schemaReady: true` ve kalemlerde şu alanlar.

```json
{
  "schemaReady": true,
  "contracts": [
    {"type": "PARTNERSHIP", "status": "SIGNED", "signedAt": "2026-03-01T09:00:00Z",
     "expiresAt": "2027-03-01T00:00:00Z", "fileUrl": "https://…/partnership.pdf"}
  ],
  "documents": [
    {"type": "TAX_PLATE", "status": "APPROVED", "expiresAt": null, "fileUrl": "https://…"}
  ]
}
```

`status`: `SIGNED` | `APPROVED` | `PENDING` | `IN_REVIEW` | `MISSING` | `REJECTED` | `EXPIRED` | `NOT_AVAILABLE`. `fileUrl` kısa ömürlü imzalı bağlantı olabilir. Uygulama dokunulunca tarayıcıda açar.

## 2. Fatura & hakediş · `GET branch/invoices?period=YYYY-MM`

Bugün `schemaReady: false`, `invoices` boş. `supportCases` zaten çalışıyor, değişmez.

```json
{
  "schemaReady": true,
  "invoices": [
    {"id": "inv-1", "number": "DGF-2026-0010", "period": "2026-10",
     "amount": 18450, "vat": 3690, "currency": "TRY",
     "status": "PENDING", "dueAt": "2026-11-15T00:00:00Z",
     "pdfUrl": "https://…/DGF-2026-0010.pdf",
     "lines": [{"label": "Kart teslimatı", "quantity": 410, "amount": 14350}]}
  ]
}
```

`status`: `PENDING` | `PAID` | `OVERDUE` | `DISPUTED`. Tutarlar KDV hariç, `vat` ayrı.

## 3. Gönderiler tarih süzgeci · `GET branch/dispatch?date=YYYY-MM-DD`

`date` boşsa bugün (UTC+3), bugünkü davranış aynı kalır. Geçmiş gün salt okunur: `capabilities.operate` false dönebilir.

## 4. Performans serbest aralık · `GET branch/performance?range=custom&from=YYYY-MM-DD&to=YYYY-MM-DD`

Yanıt mevcut performans yanıtıyla aynı, `range: "custom"`. En fazla 92 gün önerilir. Fazlası 400 `RANGE_TOO_LONG`.

## 5. Gün sonu kapatma

`GET branch/end-of-day?date=YYYY-MM-DD` (boşsa bugün):

```json
{
  "date": "2026-10-30",
  "status": "OPEN",
  "canClose": false,
  "closedAt": null,
  "closedByName": null,
  "blockers": [
    {"code": "RESULT_MISSING", "count": 3},
    {"code": "RETURN_NOT_SCANNED", "count": 2}
  ]
}
```

`status`: `OPEN` | `CLOSED`. `blockers[].code`: `RESULT_MISSING` (sonuç girilmemiş), `RETURN_NOT_SCANNED` (kurye iadesi okutulmamış), `HANDOVER_PENDING` (kabul bekleyen zimmet), `COUNT_OPEN` (açık sayım).

`POST branch/end-of-day/close` (yetki: `manage`, `Idempotency-Key` zorunlu):

```json
{"date": "2026-10-30", "note": "isteğe bağlı"}
```

Yanıt: yukarıdaki nesnenin `CLOSED` hali. Engel varsa 409 `EOD_BLOCKED` ve `error.blockers`.

## 6. Şube stok sayaçları · `GET branch/stock-summary`

```json
{"inWarehouse": 128, "atCourier": 46, "inTransit": 12, "returnPending": 7,
 "generatedAt": "2026-10-30T13:00:00Z"}
```

Adetler gönderi (koli değil) bazında. `inTransit`: merkeze ya da merkezden yolda olan.

## 7. Dağıtım planlama talebi

`GET branch/distribution-plans` → `{"items": [DistributionPlan]}` (son 30)

```json
{"id": "dp-1", "date": "2026-11-02", "district": "Keçiören", "expectedVolume": 120,
 "status": "REQUESTED", "note": "Kampanya haftası", "createdAt": "2026-10-30T10:00:00Z"}
```

`status`: `REQUESTED` | `APPROVED` | `REJECTED` | `SCHEDULED`.

`POST branch/distribution-plans` (yetki: `operate`, `Idempotency-Key`): `{"date", "district", "expectedVolume", "note"}`. Yanıt: oluşan kayıt.

## 8–9. Kurye detayı, plaka, cihaz, davet

`GET agency/couriers/{courierId}`:

```json
{
  "courierId": "c-1",
  "plate": "06 ABC 123",
  "vehicleType": "MOTORCYCLE",
  "vehicleModel": "Honda PCX",
  "device": {
    "model": "Samsung SM-A546E", "os": "Android 15", "appVersion": "1.0.1+7",
    "lastSeenAt": "2026-10-30T12:55:00Z",
    "permissions": {"location": true, "backgroundLocation": false,
                    "camera": true, "notifications": true}
  }
}
```

`device` kurye hiç giriş yapmadıysa `null`. Kaynak: kurye uygulamasının `courier-devices` kaydı.

`POST agency/couriers/invitations` (yetki: `manage`, `Idempotency-Key`):

```json
{"fullName": "Ayşe Yılmaz", "phone": "+905551112233", "vehicleType": "MOTORCYCLE", "plate": "06 ABC 123"}
```

Yanıt: `{"id", "status": "SENT", "phone"}`. Kuryeye SMS ile kayıt bağlantısı gider. Aynı telefon kayıtlıysa 409 `COURIER_EXISTS`.

## 10. Kart yenile / iptal

- Yenile: `POST branch/compliance/cards` gövdesine `"renew": true`. Aynı gün de yeni belirteç üretir, öncekini geçersiz kılar.
- İptal: `POST branch/compliance/cards/revoke` (`Idempotency-Key`): `{"ownerType": "COURIER", "ownerId": "c-1", "reason": "LOST"}`. `reason`: `LOST` | `DAMAGED` | `LEFT` | `OTHER`. Sonrasında `cards/verify` bu belirteç için `valid: false, reason: REVOKED` döner.

## 11. Toplu ürün eşleştirme · `POST branch/shipments/product-match`

Seçili gönderilere ürün seri numarası / barkodu bağlar (kart, POS cihazı vb.). `Idempotency-Key` zorunlu.

```json
{"items": [{"shipmentId": "s-1", "productBarcode": "PLX0001234"}]}
```

Yanıt: `{"matched": 3, "failed": [{"shipmentId": "s-2", "code": "PRODUCT_ALREADY_MATCHED"}]}`.

## 12. Şube destek hattı

`agency-auth/session` ve `agency-auth/login` yanıtlarında `agency.supportPhone` (E.164). Gelene kadar uygulama `--dart-define=SUBE_SUPPORT_PHONE=+90…` ile verilen numarayı kullanır, ikisi de yoksa bekleme durumu gösterir.

## Açık soru

`branch/dashboard` → `todayToDeliver` kalan iş mi, günün toplamı mı? Teslim oranı şu an "teslim / (teslim + kalan)" varsayımıyla hesaplanıyor.
