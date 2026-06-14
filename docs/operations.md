# Operations

## Compose

Use the repo deploy wrapper for all services:

```bash
./scripts/deploy.sh config --quiet
./scripts/deploy.sh pull
./scripts/deploy.sh up -d --remove-orphans
```

## Data

Persistent data lives under:

```text
/srv/data/caddy
/srv/data/restic-cache
```

## Logs

```bash
./scripts/deploy.sh logs -f caddy
./scripts/deploy.sh logs -f cloudflared
./scripts/deploy.sh logs -f excalidraw
```
