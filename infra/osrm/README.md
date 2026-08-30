# Self-hosted rota motoru (OSRM)

Faz 1'in "gerçek süre/mesafe" kısmı — [`docs/00-hande-yanit.md`](../../docs/00-hande-yanit.md)'de planlanan
"trafiksiz ETA" katmanı. Ücretli/trafik farkında rota (Faz 1.5) ayrı bir konu; burada amaç sabit/kuş uçuşu ETA
yerine gerçek yol ağı üzerinden mesafe, süre ve rota geometrisi üretmek.

## Ne var

`data/usak-demo.osm` — OpenStreetMap'ten (© OpenStreetMap contributors, ODbL) çekilmiş gerçek yol verisi,
mobil app'in demo koordinatlarını (`apps/mobile/lib/session.dart`, `onboard_screen.dart` — 38.14–38.16°K,
29.04–29.07°D, Uşak) kapsayan küçük bir bölge. Tüm Türkiye'yi indirip işlemek yerine kasıtlı olarak küçük
tutuldu — hem depolama hem işlem süresi açısından.

Nasıl çekildi (Overpass API, sadece `highway` yolları — OSRM'in ihtiyacı olan tek şey):

```bash
curl -X POST --data-binary @- https://overpass-api.de/api/interpreter -o data/usak-demo.osm <<'EOF'
[bbox:38.08,28.98,38.22,29.15][timeout:90];
(
  way["highway"];
  >;
);
out;
EOF
```

## Kurulum

```bash
./prepare.sh          # osrm-extract + osrm-partition + osrm-customize (Docker gerekir)
docker compose up osrm   # osrm-routed'u 5001 portunda ayağa kaldırır
```

Test:

```bash
curl "http://localhost:5001/route/v1/driving/29.0614,38.1512;29.0488,38.1460?overview=full&geometries=polyline"
```

`apps/api`'nin bunu kullanması için `.env`'de `ROUTING_PROVIDER=osrm` ayarlı olmalı (bkz. `.env.example`).
Ayarlanmazsa API `mock` sağlayıcıya düşer — düz-hat tahmini, hiçbir dış bağımlılık yok — bu yüzden `osrm`
container'ı kapalıyken de API çökmez, sadece tahminler kabalaşır (`isEstimateOnly: true`).

## Daha geniş bölge / tüm Türkiye

Geofabrik'in `turkey-latest.osm.pbf` dosyasıyla aynı adımlar çalışır, tek fark disk/RAM ihtiyacının çok daha
büyük olması (işlenmiş graf birkaç GB olabilir). Pilot bölge dışına çıkmak gerektiğinde `usak-demo.osm`'i o
extract'le değiştirip `prepare.sh`'ı tekrar çalıştırmak yeterli.
