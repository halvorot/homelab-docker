# homelab-docker

Single-repo homelab Docker stack for VM running on Proxmox.

## Scope

- Caddy reverse proxy
- Cloudflare Tunnel ingress
- Apps and services
- Restic backup helpers
- GitHub Actions self-hosted deployment

## VM layout

```text
/srv/
  stacks/
    homelab-docker/
  data/
    caddy/
    pihole/
    restic-cache/
  scripts/
    backup/
```

## First setup

Detailed rebuild steps: [docs/setup.md](docs/setup.md)

```bash
sudo mkdir -p /srv/stacks/homelab-docker /srv/data/caddy /srv/data/pihole/etc-pihole /srv/data/restic-cache /srv/scripts/backup
sudo chown -R "$USER:$USER" /srv/stacks/homelab-docker /srv/data/caddy /srv/data/pihole /srv/data/restic-cache /srv/scripts/backup
cp .env.example .env
./scripts/deploy.sh
```

## Required secrets

Set these in local `.env`:

- `CLOUDFLARED_TOKEN`
- `PIHOLE_WEBPASSWORD`
- `RESTIC_REPOSITORY`
- `RESTIC_PASSWORD`

Set GitHub repo secrets for deployment:

- `PLATFORM_ENV`

`PLATFORM_ENV` should contain the complete production `.env` content.

## Deploy

Push to `main`. The self-hosted runner runs:

```bash
./scripts/deploy.sh
```

`./scripts/deploy.sh` runs `docker system prune -a --volumes -f`, then deploys the core homelab stack and Nextcloud AIO as separate compose projects.

Local deploy:

```bash
./scripts/deploy.sh config --quiet
./scripts/deploy.sh
```

## Backup

```bash
./scripts/backup/restic-backup.sh
```

## Restore

```bash
./scripts/backup/restic-restore.sh latest /srv
```
