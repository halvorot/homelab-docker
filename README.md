# homelab-docker

Single-repo homelab Docker stack for Proxmox VM1.

## Scope

- Caddy reverse proxy
- Cloudflare Tunnel ingress
- Excalidraw
- Restic backup helpers
- GitHub Actions self-hosted deployment

## VM layout

```text
/srv/
  stacks/
    homelab-docker/
  data/
    caddy/
    restic-cache/
  scripts/
    backup/
```

## First setup

Detailed rebuild steps: [docs/setup.md](docs/setup.md)

```bash
sudo mkdir -p /srv/stacks/homelab-docker /srv/data/caddy /srv/data/restic-cache /srv/scripts/backup
sudo chown -R "$USER:$USER" /srv/stacks/homelab-docker /srv/data/caddy /srv/data/restic-cache /srv/scripts/backup
cp .env.example .env
./scripts/deploy.sh up -d
```

## Required secrets

Set these in local `.env`:

- `CLOUDFLARED_TOKEN`
- `RESTIC_REPOSITORY`
- `RESTIC_PASSWORD`

Set GitHub repo secrets for deployment:

- `PLATFORM_ENV`

`PLATFORM_ENV` should contain the complete production `.env` content.

## Deploy

Push to `main`. The self-hosted runner runs:

```bash
./scripts/deploy.sh pull
./scripts/deploy.sh up -d --remove-orphans
```

Local deploy:

```bash
./scripts/deploy.sh config --quiet
./scripts/deploy.sh up -d --remove-orphans
```

## Backup

```bash
./scripts/backup/restic-backup.sh
```

## Restore

```bash
./scripts/backup/restic-restore.sh latest /srv
```
