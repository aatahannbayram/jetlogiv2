# Solveline: su an ne calisir, nasil test, ne kaldi

Sozlesme: [`docs/09-solveline.md`](09-solveline.md). Secret git'e yazilmaz.

## Su an sistem calisiyor mu?

**Kod evet, canli hayir (varsayilan).**

API `SMS_PROVIDER=mock` ve `MASKED_CALL_PROVIDER=mock` ile acilir. Solveline'a
cagri gitmez. Unit testler mock HTTP ile yesil.

Plan: `solveline_sms_ivr` (993/994, firma 1, IVR ses yok, inbound 4 uc).
Kalan plan maddesi ops: canli env + kendi GSM. Contact center (niyet, E01-16)
yazilmaz.

Canli 993/994 ve click-to-call ancak su env dolunca acilir:

- `SMS_PROVIDER=solveline` ve/veya `MASKED_CALL_PROVIDER=solveline`
- `SOLVELINE_CALL_TOKEN`
- `SOLVELINE_FIRMA_ID=1` (IVR yoksa 503)
- `SOLVELINE_CALLER_ID=908504808538` (varsayilan bu)
- `SOLVELINE_IVR_APPOINTMENT_DEST=993`
- `SOLVELINE_IVR_OTP_DEST=994`

Inbound (sesli asistan bizi cagirir) ayri:

- `SOLVELINE_INBOUND_TOKEN` (bos = 401)
- migration `0007` + `0008`

Uretim `kurye.dijigoo.com` bu env'ler konmadan "calisiyor" sayilmaz.

## Ne bitti (kod)

- SMS `POST /sms/create`, click-to-call (kurye sonra alici)
- 993 randevu `1@tr@{tarih}@{il / ilce}`
- 994 kapı OTP `1@tr@{kod}`
- 911 / 991 / 992 kullanilmaz
- IVR (`DYNAMIC`) ses kaydi yok; kurye OUTBOUND kayit + S3 durur
- Inbound: GET phone, GET reference, POST ticket, POST results
- Webhook `POST /v1/webhooks/solveline/call?token=`

## Ne henuz urunde yok

- 993 icin kurye/panel dugmesi yok. `callWithCode({ kind: 'appointment' })`
  var, HTTP ucu yok. 993 testi Solveline `/call/call` ile elle.
- 994 kurye uygulamasindan: `POST /v1/tasks/:id/otp/send` `channel: "ivr"`
- AI santral kayit bildirimi / M01-M18: [`docs/10-jetlogi-ai-santral-kararlar.md`](10-jetlogi-ai-santral-kararlar.md)

## 1) Makinede, Solveline'siz (simdilik bunu calistir)

Node 22:

```bash
export PATH="$HOME/.nvm/versions/node/v22.23.1/bin:$PATH"
pnpm --filter @dijigoo/core test
pnpm --filter @dijigoo/contracts test
pnpm --filter @dijigoo/api exec node --test --import tsx test/solveline.test.ts
```

Beklenen: core, contracts, `test/solveline.test.ts`, `test/ivr-shipments.test.ts`
yesil. Canli arama yok. Mapper T02/teslim ani DB'siz.

## 2) Canli 994 (kapi OTP) kendi GSM

Yalniz kendi numaran. Baska musteri arama.

1. `.env` (git'e koyma):

```bash
MASKED_CALL_PROVIDER=solveline
SMS_PROVIDER=solveline
SOLVELINE_CALL_TOKEN=...
SOLVELINE_FIRMA_ID=1
SOLVELINE_IVR_OTP_DEST=994
SOLVELINE_CALLER_ID=908504808538
```

2. API ayakta, DB migrate (`0007`, `0008`).
3. Test gorevinde alici telefonu **senin GSM**.
4. Kurye JWT ile:

```bash
curl -sS -X POST "$API/v1/tasks/$TASK_ID/otp/send" \
  -H "Authorization: Bearer $COURIER_JWT" \
  -H "Content-Type: application/json" \
  -d '{"stepKey":"otp_dogrula","channel":"ivr"}'
```

`stepKey` o gorevin `OTP_VERIFY` adimi olmali.

Beklenen: 850 DID'den arama; "JetLogi teslimat kodunuz" + rakamlar;
ses kaydi yok; Solveline logunda satir var. 503 = `SOLVELINE_FIRMA_ID` bos
veya token/cikis IP.

Ayni govdeyi Solveline ornegiyle dogrudan da atabilirsin (kendi GSM):

```bash
curl -sS -X POST "https://capi.ncvav.com/call/call" \
  -H "token: $SOLVELINE_CALL_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "application": "DYNAMIC",
    "destination": "994",
    "callerid": "908504808538",
    "responseurl": "",
    "variable": "1@tr@123456",
    "priority": "0",
    "vmdetect": "0",
    "caller": { "1": "90XXXXXXXXXX" }
  }'
```

`callinfo[0].status` = `"1"` kuyruga alindi.

## 3) Canli 993 (randevu) kendi GSM

Urun dugmesi yok. Ayni `/call/call`, destination 993:

```bash
curl -sS -X POST "https://capi.ncvav.com/call/call" \
  -H "token: $SOLVELINE_CALL_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "application": "DYNAMIC",
    "destination": "993",
    "callerid": "908504808538",
    "responseurl": "",
    "variable": "1@tr@22 Nisan 2026 Pazartesi@MALATYA / YESILYURT",
    "priority": "0",
    "vmdetect": "0",
    "caller": { "1": "90XXXXXXXXXX" }
  }'
```

Beklenen: randevu metni (tarih + il/ilce); "kaydedilir" yok; ses yok; log var.

## 4) Click-to-call (kayit + bildirim burda)

`MASKED_CALL_PROVIDER=solveline`. Mobil **Ara**: kurye cep (sen), alici cep
(senin ikinci hat veya ayni test). `mode: originated`, `tel:` acilmaz.

Beklenen: iki bacak, ANSWER sonrasi S3'e ses. IVR ile karisma.

Webhook (bizim log + OUTBOUND kayit):

`POST https://kurye.dijigoo.com/api/mobile/v1/webhooks/solveline/call?token=$SOLVELINE_WEBHOOK_SECRET`

Yerel: `http://localhost:3001/v1/webhooks/solveline/call?token=...`

## 5) Inbound API (Solveline -> biz)

API + `SOLVELINE_INBOUND_TOKEN` + migrate. Token'i onlara git disi ver.

```bash
curl -sS "$API/v1/ivr/shipments?phone=90XXXXXXXXXX" \
  -H "Authorization: Bearer $SOLVELINE_INBOUND_TOKEN"

curl -sS "$API/v1/ivr/shipments/DGO-XXXX" \
  -H "Authorization: Bearer $SOLVELINE_INBOUND_TOKEN"

curl -sS -X POST "$API/v1/ivr/shipments/DGO-XXXX/tickets" \
  -H "Authorization: Bearer $SOLVELINE_INBOUND_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"kind":"expedite","note":"test"}'

curl -sS -X POST "$API/v1/ivr/results" \
  -H "Authorization: Bearer $SOLVELINE_INBOUND_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"uniqueId":"test-1","selection":"confirm","dtmf":"1"}'
```

Yerel `$API` = `http://localhost:3001`.
Uretim taban = `https://kurye.dijigoo.com/api/mobile`.

Bos HMAC / o telefonda gorev yok = `shipments: []`. 401 = token veya CIDR.

## Kalan adimlar

### Senin / ops

1. Canli (veya staging) `.env`: token, `SOLVELINE_FIRMA_ID=1`, saglayici
   `solveline`. Secret commit yok.
2. `pnpm db:migrate` (0007, 0008).
3. `openssl rand -hex 32` ile inbound token; ayni deger Solveline'a.
4. Prod/staging **cikis IP** Solveline yurt disi allowlist (TR serbest).
5. 993 ve 994 kendi GSM (yukari).
6. Click-to-call kendi iki hat; kayit S3'te mi bak.
7. Inbound dort ucu curl (yukari).

### Solveline / Edip

- 993/994 metin canli (onlar acti, sen teyit et).
- Inbound scriptler bizim GET/POST + Bearer.
- IVR'de ses kapali kaldıgını logdan teyit.

### Hande / is

- AI gorusmesi: kayit + "kaydedilir" (M10, saklama suresi).
- M01-M18 bos satırlar AI canlisini bloklar (`docs/10`).
- 993 icin urunde ne zaman aranacak (zimmet? slot?) henuz karar/yok.

### Bilerek sonra

- 993 icin resmi API/ekran.
- Gelen SMS.
- Panel kayit oynatici (S3 yeterli).

## Hizli ariza

| Belirti | Muhtemel neden |
|---|---|
| IVR 503 | `SOLVELINE_FIRMA_ID` bos |
| Originate 503 | token, dest 993/994 degil, veya cikis IP |
| Inbound 401 | Bearer yok/yanlis veya `SOLVELINE_INBOUND_CIDRS` |
| IVR sessiz / yanlis metin | dest 911/991/992 veya `variable` formati |
| OTP IVR yok, SMS gidiyor | `channel` `ivr` degil veya provider mock |
| 993 curl OK, uygulamada yok | 993 dugmesi yok, beklenen |
