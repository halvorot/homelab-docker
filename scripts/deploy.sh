#!/usr/bin/env sh
set -eu

COMPOSE_FILES="
  -f docker-compose.yml
  -f apps/dockhand/compose.yaml
  -f apps/excalidraw/compose.yaml
  -f apps/dozzle/compose.yaml
  -f apps/winelottery/compose.yaml
  -f apps/portainer/compose.yaml
  -f apps/nocobase/compose.yaml
  -f apps/homepage/compose.yaml
  -f apps/voiceboard/compose.yaml
"

docker network inspect homelab-docker >/dev/null 2>&1 || \
  docker network create homelab-docker

# shellcheck disable=SC2086
docker compose $COMPOSE_FILES "$@"
