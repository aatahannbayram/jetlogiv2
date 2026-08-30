#!/usr/bin/env bash
# Builds the OSRM routing graph from infra/osrm/data/usak-demo.osm.
#
# Run this once (and again any time the .osm source changes) before
# `docker compose up osrm`. Output is infra/osrm/data/usak-demo.osrm.* —
# gitignored build artifacts, not source.
#
# To route a bigger area, replace usak-demo.osm with a larger extract (see
# README.md for how it was generated) and rerun this script.
set -euo pipefail

cd "$(dirname "$0")/data"

IMAGE="ghcr.io/project-osrm/osrm-backend:latest"
BASE="usak-demo"

if [ ! -f "$BASE.osm" ]; then
  echo "error: $BASE.osm not found in infra/osrm/data/" >&2
  exit 1
fi

echo "==> osrm-extract"
docker run --rm -t -v "$PWD:/data" "$IMAGE" osrm-extract -p /opt/car.lua "/data/$BASE.osm"

echo "==> osrm-partition"
docker run --rm -t -v "$PWD:/data" "$IMAGE" osrm-partition "/data/$BASE"

echo "==> osrm-customize"
docker run --rm -t -v "$PWD:/data" "$IMAGE" osrm-customize "/data/$BASE"

echo "==> done. Start it with: docker compose up osrm"
