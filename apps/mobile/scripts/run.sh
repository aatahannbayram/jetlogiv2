#!/usr/bin/env bash
# Runs the app with local secrets from .env.local (gitignored, never
# committed) passed in as --dart-define values. Usage:
#   ./scripts/run.sh -d macos
#   ./scripts/run.sh -d chrome
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -f .env.local ]; then
  set -a
  # shellcheck disable=SC1091
  source .env.local
  set +a
fi

defines=()
[ -n "${MAPBOX_TOKEN:-}" ] && defines+=(--dart-define=MAPBOX_TOKEN="$MAPBOX_TOKEN")
[ -n "${API_BASE:-}" ] && defines+=(--dart-define=API_BASE="$API_BASE")

exec flutter run "${defines[@]}" "$@"
