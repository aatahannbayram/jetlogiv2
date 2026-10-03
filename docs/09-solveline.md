# Solveline SMS / CALL / IVR

Cift yonlu entegrasyon. Biz Solveline'i SMS, click-to-call, DYNAMIC IVR ve
kayit icin cagiririz; sesli asistan gonderi sorgu ve hizlandirma ticket icin
bizim API'yi cagirir.

Secret, Postman koleksiyonu ve canli token git'e girmez. Degerler yalniz
ortam degiskeninde (`.env`). Yerel/demo varsayilan saglayici `mock`.

## Outbound (biz -> Solveline)

| Is | Host | Auth |
|---|---|---|
| SMS `/sms/create` | `smslogin.nac.com.tr:9588` | HTTP Basic (`SOLVELINE_SMS_USER` / `SOLVELINE_SMS_PASSWORD`) |
| CALL `/call/call`, kayit `/reports/getrecording` | `capi.ncvav.com` | header `token` (`SOLVELINE_CALL_TOKEN`) |

Gonderen basligi **JETLOGI**, DID **908504808538**.

### SMS / OTP

`SMS_PROVIDER=solveline` iken `OtpService` ayni `SmsProvider.send` yolunu kullanir.
Govde: `type:1`, `sendingType:0`, `number` = 90… (arti yok), `sender` env'deki
`SMS_SENDER_ID`.

### Click-to-call (`POST /v1/tasks/:id/call`)

Kurye **Ara** der.

- `caller.1` = kurye GSM (ilk bacak)
- `destination` = alici GSM (kurye acinca)
- `callerid` = 850 DID
- `variable` = `masked_call_sessions.id`
- `responseurl` = `SOLVELINE_CALL_WEBHOOK_URL` (+ `token` query)

Anlik yanit `callinfo[0].uniqueid`, `status: "1"` = kuyruga alindi. Degilse
`UPSTREAM_UNAVAILABLE` (503). `uniqueid` oturuma yazilir.

Mobil sozlesme: `mode: originated`. Uygulama `tel:` acmaz; snackbar
"Sizi ve aliciyi ariyoruz". Alici MSISDN elsete hicbir zaman donmez.
`MASKED_CALL_PROVIDER=mock` iken `mode: dial` (eski `tel:` yolu).

### Webhook ve kayit

`POST /v1/webhooks/solveline/call?token=…` (`SOLVELINE_WEBHOOK_SECRET`).
HMAC yok. Eslesme: `uniqueid` veya `variable`. Idempotent.

Ses kaydi yalniz cift tarafli diyalog: kurye click-to-call (OUTBOUND) ve
AI gorusmesi. `application=DYNAMIC` (993/994) icin `getrecording` yok;
Solveline CDR/log tutar, ses dosyasi yok. 993/994 metninde "kaydedilir"
denmez.

OUTBOUND `status: ANSWER` sonrasi `getrecording`: `uniqueid` **ve**
`startdate` = `enddate` = cagri gunu (Europe/Istanbul). Azami aralik 1 ay.
Donen URL sureli; hemen S3'e kopyalanir. Kayit kurye uygulamasina gitmez.

Webhook URL bos olsa bile originate calisir; bitis o zaman bu kanaldan
gelmez. IVR orneklerinde `responseurl` bos; biz kendi webhook'umuzu
yine gonderebiliriz (log), ses kopyalanmaz.

### DYNAMIC IVR (993 / 994)

Solveline acti (2026-09). `caller.1` **yalniz alici**. Kurye koprulenmez.
Ayraç `@`. Destination **993** randevu, **994** kapi OTP (dogrulama kodu).
**911 / 991 / 992'ye dokunulmaz.**

JetLogi hesabinda `firmaId=1` (Solveline verdi). Eski paylasilan listede
1=vodafone idi; bu hesapta JetLogi=1. Dest 911 kullanilmaz.

**993 randevu** `1@tr@{tarih}@{il / ilce}`

*Merhaba, JetLogi. {tarih} tarihinde {il ilce} bolgesine teslimatimiz var.
Kuryemiz yola ciktiginda sizi arayacagiz. Iyi gunler.*

Ornek `variable`: `1@tr@22 Nisan 2026 Pazartesi@MALATYA / YESILYURT`

**994 kapi OTP** `1@tr@{kod}`

*Merhaba, JetLogi teslimat kodunuz. Kod: {rakam rakam}. Bu kodu kuryenizle
paylasin.*

Ornek `variable`: `1@tr@123456`

`callerid` `908504808538`. Bos slot ASCII tire `-` (U+2014 yok).
993 kendi GSM ile test edilebilir.

`SOLVELINE_FIRMA_ID` bossa IVR kapalidir (canlida `1`). OTP kanal `ivr`
bu client'i cagirir. Firma id yoksa 503.

## Inbound (Solveline -> biz)

Sesli asistan. Kurye JWT ve panel `x-service-token` degildir.

**Taban URL**

| Ortam | Taban |
|---|---|
| Uretim | `https://kurye.dijigoo.com/api/mobile` |
| Yerel | `http://localhost:3001` |

**Bearer (tum GET/POST)**

```
Authorization: Bearer <SOLVELINE_INBOUND_TOKEN>
Accept: application/json
Content-Type: application/json
```

Token'i biz uretiriz, API env `SOLVELINE_INBOUND_TOKEN`. Ayni degeri
Solveline'a git disi kanaldan veririz. Git / Postman / bu dosyaya yazilmaz.
Bos veya yanlis token = 401. Rate limit + audit (`support.ticket_created`).

```
openssl rand -hex 32
```

Cikan degeri sunucuda `SOLVELINE_INBOUND_TOKEN=` olarak koyun; Solveline'a
ayni metni verin.

| Metod | Tam yol (uretim) |
|---|---|
| GET | `https://kurye.dijigoo.com/api/mobile/v1/ivr/shipments?phone=90532…` |
| GET | `https://kurye.dijigoo.com/api/mobile/v1/ivr/shipments/{reference}` |
| POST | `https://kurye.dijigoo.com/api/mobile/v1/ivr/shipments/{reference}/tickets` |
| POST | `https://kurye.dijigoo.com/api/mobile/v1/ivr/results` |

Cagri bitis webhook'u ayri token: `POST …/v1/webhooks/solveline/call?token=`
(`SOLVELINE_WEBHOOK_SECRET`). Inbound Bearer ile karistirma.

Alanlar (yoksa `null`, uydurma yok):

- `reference`, `company` (tenant veya attributes), `status`
- `custodyAt` (zimmet `acquiredAt`)
- `slotEndAt` = `tasks.slot_end_at` (teslim penceresi; yoksa `null`)
- `etaConfirmed` (T02). Simdilik `false`: saati musteriye soyleme. Pencere
  dolu olsa da taahhut degildir.
- `deliveredAt` yalniz `COMPLETED` + `finalizedAt`
- `courierName`, `agencyName` (sube). **Kurye MSISDN ve IBAN/TCKN donulmez (T04, T11).**
- `customerPhone` yalniz GET by-reference.

### Ornek

```
GET https://kurye.dijigoo.com/api/mobile/v1/ivr/shipments?phone=905321110026
Authorization: Bearer <SOLVELINE_INBOUND_TOKEN>
```

```json
{
  "shipments": [
    {
      "reference": "DGO-8841",
      "company": "JetLogi",
      "status": "IN_PROGRESS",
      "custodyAt": "2026-09-14T08:12:00+03:00",
      "etaConfirmed": false,
      "slotEndAt": "2026-09-14T18:00:00+03:00",
      "deliveredAt": null,
      "courierName": "Ruken Turhan",
      "agencyName": "Guney / Denizli"
    }
  ]
}
```

```
GET https://kurye.dijigoo.com/api/mobile/v1/ivr/shipments/DGO-8841
Authorization: Bearer <SOLVELINE_INBOUND_TOKEN>
```

```json
{
  "reference": "DGO-8841",
  "customerPhone": "905321110026",
  "company": "JetLogi",
  "status": "IN_PROGRESS",
  "custodyAt": "2026-09-14T08:12:00+03:00",
  "etaConfirmed": false,
  "slotEndAt": "2026-09-14T18:00:00+03:00",
  "deliveredAt": null,
  "courierName": "Ruken Turhan",
  "agencyName": "Guney / Denizli"
}
```

```
POST https://kurye.dijigoo.com/api/mobile/v1/ivr/shipments/DGO-8841/tickets
Authorization: Bearer <SOLVELINE_INBOUND_TOKEN>
Content-Type: application/json
```

```json
{ "kind": "expedite", "note": "Musteri IVR hizlandirma" }
```

```json
{ "ticketReference": "TCK-20260914-AB12C", "status": "open" }
```

```
POST https://kurye.dijigoo.com/api/mobile/v1/ivr/results
Authorization: Bearer <SOLVELINE_INBOUND_TOKEN>
Content-Type: application/json
```

```json
{
  "uniqueId": "111-55849811574444.1",
  "variable": "9@tr@123456",
  "selection": "confirm",
  "dtmf": "1",
  "calledAt": "2026-09-14T10:12:00+03:00"
}
```

```json
{ "uniqueId": "111-55849811574444.1", "selection": "confirm", "duplicate": false }
```

Ayni telefonda birden fazla acik gonderi: hepsi `shipments[]` icinde, acik
olanlar once. IVR hangisini okuyacagina karar verir.

## Ortam

| Degisken | Rol |
|---|---|
| `SMS_PROVIDER` / `MASKED_CALL_PROVIDER` | `mock` (varsayilan) veya `solveline` |
| `SMS_SENDER_ID` | Canlida `JETLOGI` |
| `SOLVELINE_SMS_*` | SMS host + Basic |
| `SOLVELINE_CALL_TOKEN` | Ses token (prod, suresiz, koleksiyon guncel) |
| `SOLVELINE_CALL_WEBHOOK_URL` / `SOLVELINE_WEBHOOK_SECRET` | Bitis POST |
| `SOLVELINE_CALLER_ID` | `908504808538` |
| `SOLVELINE_FIRMA_ID` | Canlida `1` (Solveline). Bos = IVR kapali |
| `SOLVELINE_IVR_APPOINTMENT_DEST` / `SOLVELINE_IVR_OTP_DEST` | 993 / 994 |
| `SOLVELINE_INBOUND_TOKEN` | Sesli asistan Bearer |
| `SOLVELINE_INBOUND_CIDRS` | Solveline cikis IPv4/CIDR (virgul). Bos = IP kontrolu yok |

**IP allowlist (iki yon):**
- Onlar bizi cagirir: `SOLVELINE_INBOUND_CIDRS` (bizim middleware).
- Biz onlari cagiririz (SMS/CALL, yurt disi IP): **prod ve staging cikis IP'lerimizi Solveline'a bildirin.** Token suresiz; TR IP serbest, yurt disi allowlist sart. Deger bu repoda tutulmaz.

P0 contract: `packages/contracts/test/ivr-guardrails.test.ts` (T02, T04, T11).

JetLogi karar listesi: [`docs/10-jetlogi-ai-santral-kararlar.md`](10-jetlogi-ai-santral-kararlar.md).

Kod: `packages/core/src/solveline-sms.ts`, `solveline-call.ts`;
`apps/api/src/routes/task.ts` (originate), `solveline-webhook.ts`, `ivr.ts`.

## Bilincli disarida

- Postman secret'lari
- Netgsm silmek
- Gelen SMS is kurali
- Prod token ile rastgele musteri aramak (yalniz kendi GSM)
- Destination `911` / `991` / `992` ile JetLogi prod IVR
- IVR (993/994) icin `getrecording` / S3 ses
- Metin ve `variable` icinde U+2014
- WebRTC; panel kayit oynatici (S3 yeterli)

Acik: 993 kendi GSM test; AI gorusmesinde kayit + bildirim (Hande M10).
