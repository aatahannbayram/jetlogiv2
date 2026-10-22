#!/usr/bin/env bash
# iPhone'da "Ana Ekrana Ekle" ile kullanılacak web sürümü (App Store onayı
# gelene kadar). API istekleri aynı adresin /api yoluna gider; barındırma
# (web/vercel.json, yerelde tool/web_proxy.mjs) bunları JetDiji'ye aktarır.
#   tool/build_web.sh            -> build/web
#   node tool/web_proxy.mjs      -> http://localhost:8088 ile yerel deneme
set -euo pipefail
cd "$(dirname "$0")/.."
flutter build web --release --no-tree-shake-icons \
  --dart-define=PANEL_API_BASE=/api/public/v1 \
  --dart-define=AGENCY_API_BASE=/api/portal/v1 \
  "$@"
echo "build/web hazır."
