#!/usr/bin/env sh
set -eu

COMPOSE_FILES="
  -f docker-compose.yml
  -f apps/excalidraw/compose.yaml
  -f apps/dozzle/compose.yaml
  -f apps/winelottery/compose.yaml
  -f apps/portainer/compose.yaml
  -f apps/supabase/docker-compose.yml
"

# Support multiple env files if they exist
ENV_FILES="--env-file .env"
if [ -f "apps/supabase/.env" ]; then
  ENV_FILES="$ENV_FILES --env-file apps/supabase/.env"
fi

docker network create homelab-docker >/dev/null 2>&1 || true

# shellcheck disable=SC2086
docker compose $ENV_FILES $COMPOSE_FILES "$@"
