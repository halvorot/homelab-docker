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

BACKUP_SOURCE="${BACKUP_SOURCE:-/srv/data}"
RESTIC_CACHE_DIR="${RESTIC_CACHE_DIR:-/srv/data/restic-cache}"
HOSTNAME="$(hostname)"

restic snapshots >/dev/null 2>&1 || restic init

restic backup "$BACKUP_SOURCE" \
  --host "$HOSTNAME" \
  --tag homelab \
  --exclude "$RESTIC_CACHE_DIR"

restic forget \
  --host "$HOSTNAME" \
  --tag homelab \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 6 \
  --prune

restic check
