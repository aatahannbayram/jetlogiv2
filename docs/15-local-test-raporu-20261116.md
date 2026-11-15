# Deploy öncesi local test raporu — 2026-11-16

Workspace: `Dijigoo-v11` (`feat/dijigoo-v11-giris`, mobile `1.1.1+11`)

## Ortam

| Bileşen | Durum |
|---|---|
| Disk (önce) | ~0.5–5 GB — build düşüyordu |
| Disk (sonra) | ~12 GB boş |
| Flutter | 3.47.1 / Dart 3.13.1 |

## Otomatik test

| Komut | Sonuç | Not |
|---|---|---|
| `flutter analyze` | error yok | 4 warning + 44 info |
| `flutter test` | **954/954 geçti** | ~33 sn |
| `tool/build_web.sh` | **OK** | `build/web` ≈ 53 MB |

## Deploy artefaktı

- Yol: `apps/mobile/build/web`
- API: relative `/api/public/v1` + `/api/portal/v1` (barındırma proxy’si gerekir)
- Kaynak (`lib/`) yok; derlenmiş çıktı

## Claude’un önceki koşusu (Desktop/Dijigo)

- Local Fastify API E2E: OK (OTP 401/200, görevler)
- `flutter build web`: disk dolu diye kesildi
- Simülatör / tam manuel smoke: yapılmadı

## Deploy’a hazır mı?

**Koşullu evet** — otomatik test + web release artefaktı hazır.  
Canlıda `api-mobile.dijigoo.com` için barındırma tarafında `/api/*` proxy veya `PANEL_API_BASE` dart-define netleşmeli. Manuel smoke (giriş / vardiya / görev) hâlâ önerilir.

## Sonraki adımlar

1. SFTP bilgisi gelince yalnız `build/web` içeriğini yükle
2. Proxy / API host doğrula
3. Canlıda kurye hesabıyla kısa smoke
