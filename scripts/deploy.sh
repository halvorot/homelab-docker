#!/usr/bin/env sh
set -eu

COMPOSE_FILES="
  -f docker-compose.yml
  -f apps/excalidraw/compose.yml
"

docker network create homelab-docker >/dev/null 2>&1 || true

# shellcheck disable=SC2086
docker compose $COMPOSE_FILES "$@"
