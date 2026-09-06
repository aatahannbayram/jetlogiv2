# JetLogi (Dijigoo Kurye)

Kurye operasyonları için monorepo: mobil kurye uygulaması, backend API, panel ve
paylaşılan paketler. Detaylı mimari kararlar ve durum notları `docs/` altında.

## Yapı

| Yol | Ne | Stack |
|---|---|---|
| `apps/api` | Backend API | Fastify, Drizzle ORM, Zod |
| `apps/mobile` | Kurye mobil uygulaması | Flutter |
| `apps/panel` | Web paneli | Next.js |
| `apps/worker` | Arka plan iş kuyruğu | *(iskelet, henüz boş)* |
| `packages/contracts` | Ortak API şeması/tipleri (Zod + OpenAPI) | TypeScript |
| `packages/core` | Paylaşılan iş mantığı (workflow, idempotency, geofence) | TypeScript |
| `packages/db` | Veritabanı şeması, migration'lar | Drizzle ORM + PostgreSQL |
| `infra/osrm` | Kendi barındırılan rota motoru verisi | OSRM |

## Gereksinimler

- Node.js 22+ (bkz. `.nvmrc`)
- pnpm 9+
- Docker (bu makinede Docker Desktop yerine [Colima](https://github.com/abiosoft/colima) kullanılıyor — `colima start`)

## Yerel kurulum

```bash
cp .env.example .env        # zaten varsa atla
pnpm install

# Altyapı: Postgres, Redis, MinIO, OSRM
docker compose up -d postgres redis minio createbuckets osrm

# Migration'lar .env'i process.env'e export etmeyi bekliyor
set -a && source .env && set +a
pnpm db:migrate

# API + Panel (turbo strict env-mode .env'deki bazı değişkenleri filtreliyor,
# bu yüzden --env-mode=loose gerekiyor)
pnpm exec turbo run dev --filter=@dijigoo/api --filter=@dijigoo/panel --env-mode=loose
```

- API: http://localhost:3001 (`/health`)
- Panel: http://localhost:3000
- OSRM: http://localhost:5001 (`ROUTING_PROVIDER=osrm` iken kullanılır; `mock` ile de çalışır, düz-hat tahmini yapar)

## Scriptler (repo kökünden)

```bash
pnpm dev          # turbo run dev — tüm uygulamalar
pnpm build        # turbo run build
pnpm lint         # turbo run lint
pnpm typecheck    # turbo run typecheck
pnpm test         # turbo run test

pnpm db:generate  # drizzle-kit generate (bu ortamda kırık — bkz. packages/db/src/migrate.ts yorumları)
pnpm db:migrate   # migration'ları uygula
pnpm openapi      # packages/contracts'tan OpenAPI şeması üret

pnpm infra:up     # docker compose up -d
pnpm infra:down   # docker compose down
```

## Dokümantasyon

- `docs/00-hande-yanit.md` — teknik değerlendirme, Faz 1 planı, bilinen riskler
- `docs/01-workflow-versioning.md` — workflow tanımı/versiyonlama
- `docs/02-master-plan.md` — 16 modüllük kurye pilotu kapsamı
- `docs/03-demo-akis.md` — demo akışı
- `docs/04-mobile-v2-redesign.md` — mobil v2 tasarım sistemi notları
- `docs/05-panel-entegrasyonu.md` — jetlogi-panel entegrasyon planı
- `docs/06-eski-panel-ve-repo-analizi.md` — eski sistem (api/panel.jetlogi.net) analizi
- `docs/07-ana-plan.md` — üç sistemi (eski/yeni panel/bizim iş) birleştiren yol haritası

Not: `docs/07`'den itibaren güncel durumun asıl kaynağı Linear (JETLOG
takımı) — bu dosyalar birer görüntü (snapshot), canlı takip değil.
