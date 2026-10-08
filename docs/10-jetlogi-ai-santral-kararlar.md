# JetLogi AI santral: acik kararlar (M01-M18)

**Tarih:** 14.09.2026  
**Sahip (dolduracak taraf):** JetLogi  
**Hazirlayan:** Flexlore / Dijigoo  
**Kaynak:** Hande Yesilyaprak, `JetLogi_AI_Santral_Is_Gereksinimleri_.xlsx` sayfa 14

Bu sayfa kod degildir. 14 madde **AI santral canlisini bloklar**. Bos satirla canliya cikilmaz. Her satira sahip ad + hedef tarih yazin, Dijigoo'ya geri gonderin.

Dijigoo tarafinda maskeli arama, OTP SMS, 3 inbound sorgu/ticket ucu ve IVR sonuc kaydi ayakta. Niyet diyalogu, kuyruk isimleri ve mesai Solveline + bu tablo olmadan calismaz.

| Kod | Karar | Config (doldurulunca) | Canli gate | Sahip | Tarih |
|---|---|---|---|---|---|
| M01 | Mesai saatleri | `business_hours` | Evet (T13) | | |
| M02 | Mesai disi acil tanimi | `after_hours_urgent_intents` | Evet | | |
| M03 | VIP tanima kurali | `vip_rule` | Evet (T14) | | |
| M04 | Dedike temsilci eslesmesi | `dedicated_agent_id` | Hayir | | |
| M05 | Adres degisikligi yasagi (proje) | `allow_address_change` | Evet (T05) | | |
| M06 | Subeden teslim | `allow_branch_pickup` | Evet | | |
| M07 | Proje SLA | `sla_hours` | Evet | | |
| M08 | Onayli outbound senaryolar | `outbound_campaigns` | Evet | | |
| M09 | Outbound tekrar ve saat; arama istememe | `outbound_window`, `max_retries` | Evet (T18) | | |
| M10 | KVKK aydinlatma metni; kayit saklama suresi | `kvkk_announcement` | Evet | | |
| M11 | Kuyruklar ve yedekler | `routing_rules` | Evet | | |
| M12 | Temsilci musait degilse. Dahili yoksa ilgili cep | `no_agent_fallback` | Evet | Hande | 06.10.2026 |
| M13 | Dil destegi | `languages` | Hayir | | |
| M14 | Erisilebilirlik alternatifi | `accessibility_channel` | Hayir | | |
| M15 | Resmi kurum proseduru | `routing_rules` official | Evet (T15) | | |
| M16 | Kriz iletisimi | `crisis_contacts` | Evet | | |
| M17 | AI yasak islem listesi | `forbidden_actions` | Evet (T20) | | |
| M18 | Geri arama hedef suresi | `callback_sla_minutes` | Evet | | |

**T01-T20 kabul testlerini kim onaylar?** (Excel 12 son satir) Sahip: ________  Tarih: ________

**KVKK / ses kaydi:** saklama suresi ve erisim yetkisi hukuk onayi olmadan kayit URL'si panelde acilmaz. Dijigoo kaydi S3'e kopyalar; oynatici bu fazda yok.

Gonderim: bu dosyayi oldugu gibi iletin. Degerleri buraya isleyin, ayri bir "sozlu teyit" yetmez.
