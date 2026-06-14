# Homelab Deployment Guide (Proxmox + Docker + GitHub Ops)

## Overview

This guide defines a low-maintenance self-hosting setup on a Proxmox-based mini PC for:

- Excalidraw

Goals:

- minimal day-2 maintenance
- strong backup and recovery model
- one GitHub repo as source of truth
- GitHub-driven deployments
- secure public exposure via Cloudflare Tunnel + Tailscale

---

## 1. Architecture

```text
Internet
  │
  ├── Cloudflare Tunnel (public services)
  │       │
  │     Caddy (reverse proxy)
  │       │
  │   Docker services (VM1)
  │
  └── Tailscale (private access)
          │
       Admin / DB access
```

---

## 2. Proxmox Layout

### VM1: homelab-docker (Ubuntu 24.04)

- Docker + Docker Compose
- Caddy reverse proxy
- Cloudflare Tunnel
- Excalidraw
- Restic backup scripts

### VM2: backup-agent (optional)

- Restic backups
- S3/B2 sync

### Optional LXC

- Uptime Kuma / monitoring

---

## 3. VM1 Folder Structure

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

`/srv/stacks/homelab-docker` contains this repo.

`/srv/data` contains persistent runtime data and is the primary backup target.

---

## 4. Repository Structure

```text
homelab-docker/
  docker-compose.yml
  .env.example
  README.md

  apps/
    excalidraw/
      compose.yml

  proxy/
    Caddyfile

  scripts/
    deploy.sh
    backup/
      restic-backup.sh
      restic-restore.sh

  docs/
    operations.md
    recovery.md
    homelab-proxmox-gitops-guide.md

  .github/
    workflows/
      deploy.yml
```

---

## 5. Docker Compose Model

The root compose file owns shared infrastructure:

- Caddy
- Cloudflare Tunnel
- shared external Docker network

Each app has its own compose file:

- `apps/excalidraw/compose.yml`

All files are combined by:

```bash
./scripts/deploy.sh
```

Deploy command:

```bash
./scripts/deploy.sh up -d --remove-orphans
```

The shared network is:

```text
homelab-docker
```

---

## 6. Services

### Excalidraw

- stateless
- image: `excalidraw/excalidraw`
- proxied by Caddy

Persistent data: none.

---

## 7. Reverse Proxy (Caddy)

```caddyfile
{$EXCALIDRAW_DOMAIN} {
  reverse_proxy {$EXCALIDRAW_UPSTREAM}
}
```

Default upstreams:

```text
EXCALIDRAW_UPSTREAM=excalidraw:80
```

---

## 8. GitHub Deployment Model

Single repo:

```text
homelab-docker
```

Push to `main` deploys the whole stack on a self-hosted runner.

Workflow:

```yaml
name: deploy

on:
  push:
    branches: ["main"]
  workflow_dispatch:

jobs:
  deploy:
    runs-on: self-hosted

    steps:
      - uses: actions/checkout@v4
      - run: printf '%s\n' "${{ secrets.PLATFORM_ENV }}" > .env
      - run: docker network create homelab-docker || true
      - run: ./scripts/deploy.sh config --quiet
      - run: ./scripts/deploy.sh pull
      - run: ./scripts/deploy.sh up -d --remove-orphans
```

GitHub secret:

```text
PLATFORM_ENV
```

`PLATFORM_ENV` contains production `.env` content.

---

## 9. Backups

### Layer 1: Proxmox snapshots

- daily
- 3-7 day retention

### Layer 2: Restic backups

```bash
./scripts/backup/restic-backup.sh
```

Targets:

- Caddy state

### Layer 3: Offsite storage

- Backblaze B2 or S3

---

## 10. Public Access

### Cloudflare Tunnel (recommended)

- no open ports
- automatic public TLS
- DDoS protection

Flow:

```text
Cloudflare -> tunnel -> Caddy -> services
```

### Tailscale

Use for:

- admin dashboards
- database access
- internal tools
- SSH

---

## 11. Security Model

- no public DB exposure
- only tunnel ingress
- Tailscale for admin access
- secrets in GitHub Secrets + local `.env`
- `.env` not committed
- internal Docker networking only
- strong generated Supabase JWT secrets
- strong database passwords

---

## 12. First Setup

Detailed runbook: [setup.md](setup.md)

On VM1:

```bash
sudo apt update
sudo apt install docker.io docker-compose-plugin restic git
sudo usermod -aG docker "$USER"
```

Create folders:

```bash
sudo mkdir -p /srv/stacks/homelab-docker /srv/data /srv/scripts/backup
sudo chown -R "$USER:$USER" /srv/stacks/homelab-docker /srv/data /srv/scripts/backup
```

Clone repo:

```bash
git clone git@github.com:<user>/homelab-docker.git /srv/stacks/homelab-docker
cd /srv/stacks/homelab-docker
cp .env.example .env
```

Set real secrets in `.env`.

Start stack:

```bash
./scripts/deploy.sh config --quiet
./scripts/deploy.sh up -d --remove-orphans
```

---

## 13. Disaster Recovery

1. reinstall Proxmox / VM
2. install Docker, Compose, Restic, Git
3. clone `homelab-docker`
4. restore `/srv/data` via Restic
5. restore `.env` from password manager / GitHub secret
6. run:

```bash
./scripts/deploy.sh up -d --remove-orphans
```

---

## Result

- one repo source of truth
- push-to-deploy system
- reproducible infrastructure
- fast recovery from hardware failure
- minimal operational overhead
