# Workflow tanımı ve sürümleme kuralı

Bu doküman `WorkflowDefinition` / `WorkflowStep` yapısının bağlayıcı kurallarını tanımlar. Panel ekibi ve mobil ekip aynı kurallara uyar.

- Makine tarafından okunabilir şema: `packages/contracts/schemas/workflow-definition.schema.json` (JSON Schema 2020-12)
- Çalışma zamanı doğrulaması: `packages/contracts/src/workflow.ts` (Zod)
- Örnek tanım: `packages/contracts/schemas/examples/standart-teslimat.v3.json`

İkisi arasında bir tutarsızlık olursa **JSON Schema esastır**; Zod ona göre düzeltilir.

---

## 1. Temel model

Bir workflow, bir görevin sahada nasıl yürütüleceğini tarif eder:

```
WorkflowDefinition
  key          -> tüm sürümlerde sabit slug (standart_teslimat)
  version      -> her yayında +1
  steps[]      -> sırayla yürütülen adımlar
  outcomes[]   -> görev tam olarak birinde biter
```

**Adım tipleri:** `INSTRUCTION`, `GEOFENCE_CHECK`, `BARCODE_SCAN`, `PHOTO_EVIDENCE`, `DOCUMENT_SCAN`, `FORM`, `CHECKLIST`, `OTP_VERIFY`, `SIGNATURE`, `CASH_COLLECT`, `IDENTITY_CAPTURE`.

**Sonuç türleri:** `success`, `failure`, `deferred`. "Teslim edilemedi" bir hata değil, kendi zorunlu kanıtları olan bir `failure` sonucudur; bu yüzden `outcomes[].steps` alanı var.

---

## 2. Sürümleme kuralları

### K1 — Sürüm tam sayıdır, monotonik artar

`version` her yayında bir artar. Sıfırlanmaz, geri alınmaz, yeniden kullanılmaz. Semantik sürüm (1.2.3) kullanılmaz; tek sayı, tek doğruluk kaynağı.

### K2 — Yayınlanmış sürüm değişmezdir

`status: published` olan bir kayıt bir daha **hiçbir alanı** değiştirilemez. Düzeltme bile yeni sürüm gerektirir. Bunun sonucu: `GET /v1/workflows/{key}/versions/{version}` yanıtı sonsuza kadar önbelleklenebilir; mobil taraf bir sürümü bir kez indirir.

### K3 — Çalışan görev başladığı sürümle biter

Bir görev V3 ile `IN_PROGRESS` olduysa, panel V4 yayınlasa bile o görev V3 ile tamamlanır. Aksi halde kurye yarısını doldurduğu bir sihirbazın kuralları elinde değişir.

Sunucu bunu `StepSubmitRequest.workflowVersion` ile zorlar:

| Durum | Yanıt |
|---|---|
| Gönderilen sürüm = görevin sürümü | Kabul |
| Gönderilen sürüm ≠ görevin sürümü | `409 WORKFLOW_VERSION_SUPERSEDED` |

### K4 — Sürüm sadece atama anında seçilir

Yeni sürüm yalnızca **henüz başlamamış** (`ASSIGNED`) görevlere uygulanır ve bu yükseltme panelde açık bir aksiyondur, otomatik değildir.

### K5 — Adım anahtarı kalıcıdır

`step.key` cevapların saklandığı anahtardır. Bir kez yayınlandıktan sonra:

- Anlamı değiştirilemez (`alici_imza` bir sürümde imza, diğerinde fotoğraf olamaz)
- Silinen bir anahtar **yeniden kullanılamaz**
- Tipi değiştirilemez; farklı tip isteniyorsa yeni anahtar açılır

Sebebi basit: geçmiş görevlerin kanıtları bu anahtarla saklı. Anahtarın anlamını değiştirmek geçmişi bozar.

### K6 — `minAppBuild` geriye dönük uyumluluğu korur

Yeni bir adım tipi eklendiğinde, o tipi kullanan tanımın `minAppBuild` değeri o tipi render edebilen ilk uygulama build'ine yükseltilir.

Sunucu, istemcinin `X-Client-Info` başlığındaki build numarasını kontrol eder. Daha eskiyse `400 UNSUPPORTED_CLIENT_VERSION` döner ve uygulama güncelleme ekranı gösterir.

**Bu kural olmadan** eski bir uygulama tanımadığı adım tipini sessizce atlar ve eksik kanıtla teslim yapar. Kabul edilemez.

### K7 — Kırıcı / kırıcı olmayan ayrımı

Panel, yayın öncesi bir önceki sürümle diff alır ve değişikliği sınıflandırır:

| Değişiklik | Sınıf | Sonuç |
|---|---|---|
| Metin, ipucu, etiket düzenleme | Kırıcı değil | Serbest |
| Yeni **isteğe bağlı** adım eklemek | Kırıcı değil | Serbest |
| Adım sırasını değiştirmek | Kırıcı değil | Serbest |
| Yeni **zorunlu** adım eklemek | Kırıcı | Onay + `minAppBuild` kontrolü |
| Adım silmek | Kırıcı | Onay, anahtar rezerve kalır |
| Adım tipi değiştirmek | **Yasak** | K5 ihlali |
| `outcome.code` silmek | Kırıcı | Onay, geçmiş raporlar etkilenir |
| Yeni adım tipi kullanmak | Kırıcı | `minAppBuild` zorunlu yükseltilir |

### K8 — Taslak → yayın → arşiv

```
draft ──publish──> published ──archive──> archived
  ^                                          
  └── yeni sürüm olarak kopyalanabilir
```

`archived` bir sürüm yeni göreve atanamaz, ama devam eden görevler onunla bitirilebilir. Silme yok.

---

## 3. Koşullar (`visibleWhen`)

Genel amaçlı bir ifade dili **değil**, kapalı bir karşılaştırma kümesi. Sebep: mobil tarafın bunu çevrimdışı ve deterministik değerlendirebilmesi gerekiyor.

```json
{
  "any": [
    { "path": "steps.odeme_tipi.value", "op": "eq", "value": "cash" },
    { "path": "task.attributes.codAmount", "op": "gt", "value": 0 }
  ]
}
```

**Yaprak:** `{ path, op, value }`
**Düğüm:** `{ all: [...] }`, `{ any: [...] }`, `{ not: {...} }`

**Operatörler:** `eq`, `neq`, `in`, `notIn`, `gt`, `gte`, `lt`, `lte`, `isTrue`, `isFalse`, `isEmpty`, `isNotEmpty`

**Yol kökleri:**

| Kök | İçerik |
|---|---|
| `steps.<key>.value` | Aynı görevde daha önce tamamlanmış adımın cevabı |
| `steps.<key>.status` | `completed` / `skipped` |
| `task.attributes.<field>` | Kaynak sistemden gelen serbest alanlar |
| `task.<field>` | `type`, `priority`, `codAmount`, `attemptNumber` |
| `courier.capabilities` | Kuryenin yetkileri |

**İleriye referans yasak.** Bir adım, kendisinden sonra gelen bir adımın cevabına bakamaz. Panel yayın öncesi bunu doğrular; ihlal `WORKFLOW_FORWARD_REFERENCE` hatası verir.

---

## 4. Yayın öncesi doğrulama

`packages/core/src/workflow-validator.ts` içindeki `validateWorkflow()` hem panelde (yayın butonu) hem API'de (kaydetme) çalışır. Kontroller:

1. JSON Schema uyumu
2. `step.key` tekilliği (adımlar + outcome adımları birlikte)
3. `visibleWhen` yollarının var olan bir anahtara işaret etmesi
4. İleriye referans olmaması
5. En az bir `success` outcome bulunması
6. `mustMatchPath` ve `expectedAmountPath` hedeflerinin çözülebilmesi
7. `select` / `multiselect` alanlarının dolu `options` taşıması
8. Kullanılan adım tiplerine göre `minAppBuild` alt sınırı
9. Bir önceki yayınlanmış sürümle diff → kırıcı değişiklik sınıflandırması (K7)

---

## 5. Önbellekleme

| Katman | Strateji |
|---|---|
| Mobil | `(key, version)` ile kalıcı disk önbelleği, süresiz. Sürüm değişmez olduğu için invalidasyon gerekmez. |
| API | `Cache-Control: public, max-age=31536000, immutable` |
| Ön yükleme | Delta pull yanıtı `workflows[]` içinde görevlerin işaret ettiği sürümleri listeler; uygulama Wi-Fi'da önden indirir. |

Kurye sahada çevrimdışıyken bilmediği bir workflow sürümüyle karşılaşırsa görevi başlatamaz. Bu yüzden ön yükleme zorunlu, opsiyonel değil.
