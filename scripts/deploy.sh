#!/usr/bin/env sh
set -eu

CORE_COMPOSE_FILES="
  -f docker-compose.yml
  -f apps/llama-cpp/compose.yaml
  -f apps/open-webui/compose.yaml
  -f apps/dockhand/compose.yaml
  -f apps/excalidraw/compose.yaml
  -f apps/winelottery/compose.yaml
  -f apps/portainer/compose.yaml
  -f apps/homepage/compose.yaml
  -f apps/voiceboard/compose.yaml
  -f apps/beszel/compose.yaml
"

NEXTCLOUD_COMPOSE_FILES="-f apps/nextcloud/compose.yaml"

ensure_network() {
  docker network inspect homelab-docker >/dev/null 2>&1 || \
    docker network create homelab-docker
}

run_core() {
  # shellcheck disable=SC2086
  docker compose $CORE_COMPOSE_FILES "$@"
}

run_nextcloud() {
  # shellcheck disable=SC2086
  docker compose $NEXTCLOUD_COMPOSE_FILES "$@"
}

deploy() {
  ensure_network
  run_core pull
  run_nextcloud pull
  run_core up -d --remove-orphans
  run_nextcloud up -d
}

if [ "${1:-}" = "config" ]; then
  ensure_network
  shift
  run_core config "$@"
  run_nextcloud config "$@"
else
  deploy
fi
