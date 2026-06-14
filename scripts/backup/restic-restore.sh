#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"

if [ -f "$ROOT_DIR/.env" ]; then
  set -a
  . "$ROOT_DIR/.env"
  set +a
fi

: "${RESTIC_REPOSITORY:?set RESTIC_REPOSITORY}"
: "${RESTIC_PASSWORD:?set RESTIC_PASSWORD}"

SNAPSHOT="${1:-latest}"
TARGET="${2:-/srv}"

restic restore "$SNAPSHOT" --target "$TARGET"
