# Setup Runbook

Manual steps to recreate `homelab-docker` on fresh Proxmox.

## Assumptions

- Domain: `halvorteigen.no`
- VM: Ubuntu Server 24.04
- Repo: `homelab-docker`
- Public ingress: Cloudflare Tunnel
- Private admin access: Tailscale on VM host

## 1. Cloudflare

1. Add `halvorteigen.no` to Cloudflare.
2. Change registrar nameservers to Cloudflare nameservers.
3. Wait until Cloudflare marks domain active.
4. Do not create normal public A records for services.
5. Use Cloudflare Zero Trust Tunnel for service hostnames.

## 2. Proxmox VM

Create VM:

- name: `homelab-docker`
- OS: Ubuntu Server 24.04
- CPU: 2-4 cores
- RAM: 8-16 GB
- disk: 100 GB minimum
- network: `vmbr0`

During Ubuntu install:

- create admin user
- enable OpenSSH
- use static DHCP lease in router, or set static IP later

## 3. Base VM Setup

```bash
sudo apt update
sudo apt upgrade -y
sudo reboot
```

Reconnect:

```bash
ssh <user>@<vm-ip-or-host>
```

Install packages:

```bash
sudo apt install -y git curl ca-certificates gnupg restic ufw
```

Install docker as described here: https://docs.docker.com/engine/install/ubuntu/

Then

```bash
sudo usermod -aG docker "$USER"
sudo systemctl enable --now docker
```

Log out and back in.

Verify:

```bash
docker version
docker compose version
```

## 4. Tailscale

Install Tailscale on the VM host, not Docker.

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

Reason:

- keeps admin access working if Docker breaks
- simpler SSH and firewall setup
- better for host recovery

Check IP:

```bash
tailscale ip -4
```

## 5. Firewall

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow in on tailscale0
sudo ufw allow OpenSSH
sudo ufw enable
sudo ufw status
```

After Tailscale SSH works, optionally remove public SSH:

```bash
sudo ufw delete allow OpenSSH
```

## 6. Folders

```bash
sudo mkdir -p /srv/stacks/homelab-docker
sudo mkdir -p /srv/data
sudo mkdir -p /srv/scripts/backup
sudo chown -R "$USER:$USER" /srv/stacks /srv/data /srv/scripts
```

## 7. Clone Repo On VM

```bash
git clone git@github.com:halvorot/homelab-docker.git /srv/stacks/homelab-docker
cd /srv/stacks/homelab-docker
cp .env.example .env
```

HTTPS clone is fine until SSH deploy key is ready.

## 8. Secrets

Edit .env with new secrets.

Generate random secrets:

```bash
openssl rand -hex 32
```

## 9. Cloudflare Tunnel

In Cloudflare Zero Trust:

1. Go to Networks -> Tunnels.
2. Create tunnel.
3. Name: `homelab-docker`.
4. Choose Docker connector.
5. Copy tunnel token.

Set:

```env
CLOUDFLARED_TOKEN=<token>
LLAMA_CPP_API_KEY=<long-random-key>
OPEN_WEBUI_SECRET_KEY=<long-random-key>
```

Add public hostnames:

```text
excalidraw.halvorteigen.no -> http://caddy:80
ai.halvorteigen.no -> http://caddy:80
ai-api.halvorteigen.no -> http://caddy:80
```

## 10. GitHub Runner

In GitHub repo:

1. Settings -> Actions -> Runners.
2. New self-hosted runner.
3. Linux x64.
4. Run shown commands on VM.

Install as service:

```bash
sudo ./svc.sh install root
sudo ./svc.sh start
```

Verify runner is online.

## 11. GitHub Secret

In GitHub repo:

1. Settings -> Secrets and variables -> Actions.
2. New repository secret.
3. Name: `PLATFORM_ENV`.
4. Value: full `.env` content.

Future pushes to `main` deploy automatically.

## 12. Restic Backups

Set in `.env`:

```env
RESTIC_REPOSITORY=s3:<endpoint>/<bucket>/<path>
RESTIC_PASSWORD=<random>
AWS_ACCESS_KEY_ID=<key>
AWS_SECRET_ACCESS_KEY=<secret>
BACKUP_SOURCE=/srv/data
RESTIC_CACHE_DIR=/srv/data/restic-cache
```

Run first backup:

```bash
./scripts/backup/restic-backup.sh
restic snapshots
```

Test restore:

```bash
mkdir -p /tmp/homelab-restore-test
./scripts/backup/restic-restore.sh latest /tmp/homelab-restore-test
```

Cron:

```bash
crontab -e
```

Add:

```cron
15 3 * * * cd /srv/stacks/homelab-docker && ./scripts/backup/restic-backup.sh >> /srv/data/restic-backup.log 2>&1
```

## 13. Proxmox Backups

In Proxmox UI:

1. Datacenter -> Storage: configure backup storage.
2. Datacenter -> Backup -> Add.
3. Select VM.
4. Schedule daily.
5. Mode: snapshot.
6. Retention: 3-7 daily.

## 14. Updates

Local change flow:

```bash
git add .
git commit -m "update homelab"
git push
```

Deploy manually on VM:

```bash
cd /srv/stacks/homelab-docker
git pull
./scripts/deploy.sh pull
./scripts/deploy.sh up -d --remove-orphans
```

## 15. Recovery

1. reinstall Proxmox / Ubuntu VM
2. install packages
3. install Tailscale
4. clone repo
5. restore `/srv/data`
6. restore `.env`
7. start stack

```bash
./scripts/backup/restic-restore.sh latest /srv
./scripts/deploy.sh up -d --remove-orphans
```

## Open Items

- add `.env` validation script
- consider systemd timer for Restic instead of cron
