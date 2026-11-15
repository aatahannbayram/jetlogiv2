#!/usr/bin/env bash
# Web sürümünü uygulama.dijigoo.com sunucusuna (SFTP, /uygulama) yükler.
# Sunucu: Caddy; /api/* JetDiji API'sine yönlenir, bu yüzden derleme göreli
# /api yollarını kullanır (tool/build_web.sh).
#
#   tool/deploy_sftp.sh            -> canlı derleme (demo kapalı)
#   tool/deploy_sftp.sh --demo     -> sunum derlemesi (demo girişi açık)
#   tool/deploy_sftp.sh --test     -> yalnız bağlantı + test dosyası
#
# Anahtar: ~/.ssh/id_ed25519 (sunucudaki dijigoo-deploy kullanıcısına tanımlı).
set -euo pipefail
cd "$(dirname "$0")/.."

HOST="${SFTP_HOST:-178.105.242.243}"
USER_NAME="${SFTP_USER:-dijigoo-deploy}"
REMOTE="${SFTP_DIR:-/uygulama}"
KEY="${SFTP_KEY:-$HOME/.ssh/id_ed25519}"
SITE="${SITE_URL:-https://uygulama.dijigoo.com}"
SFTP=(sftp -o BatchMode=yes -o ConnectTimeout=20 -i "$KEY" -P 22)

mode="${1:-}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "1/4 Bağlantı ve test dosyası…"
echo "dijigoo deploy test $(date -u +%FT%TZ)" > "$tmp/sftp-test.txt"
printf 'put %s %s/sftp-test.txt\nbye\n' "$tmp/sftp-test.txt" "$REMOTE" > "$tmp/test.batch"
"${SFTP[@]}" -b "$tmp/test.batch" "$USER_NAME@$HOST"
echo "   Test dosyası yüklendi: $REMOTE/sftp-test.txt"
[[ "$mode" == "--test" ]] && exit 0

echo "2/4 Derleme…"
extra=()
[[ "$mode" == "--demo" ]] && extra+=(--dart-define=ALLOW_DEMO=true)
tool/build_web.sh ${extra[@]+"${extra[@]}"}

echo "3/4 Yükleme…"
# index.html en son gider: eski index yeni dosyaları yarım görmesin.
{
  echo "lcd build/web"
  echo "cd $REMOTE"
  ( cd build/web && find . -type d ! -name . | sed 's|^\./||' | sort ) |
    while read -r d; do echo "-mkdir $d"; done
  ( cd build/web && find . -type f ! -name index.html | sed 's|^\./||' | sort ) |
    while read -r f; do echo "put $f $f"; done
  echo "put index.html index.html"
  echo "rm sftp-test.txt"
  echo "bye"
} > "$tmp/deploy.batch"
"${SFTP[@]}" -b "$tmp/deploy.batch" "$USER_NAME@$HOST" >/dev/null

echo "4/4 Doğrulama…"
code=$(curl -s -o /dev/null -w '%{http_code}' "$SITE/")
api=$(curl -s -o /dev/null -w '%{http_code}' "$SITE/api/public/v1/courier-auth/session")
echo "   $SITE/ -> $code (200 beklenir)"
echo "   $SITE/api/... -> $api (401 beklenir: oturum yok)"
[[ "$code" == "200" ]] || { echo "Site açılmadı."; exit 1; }
echo "Yayında: $SITE"
