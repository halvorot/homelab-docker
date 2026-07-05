# Repository Guidelines

## Project Structure & Module Organization

Root `docker-compose.yml` defines shared infra: `caddy` and `cloudflared`. App-specific stacks live in `apps/<service>/compose.yaml` such as `apps/n8n/compose.yaml` and `apps/nextcloud/compose.yaml`. Operational scripts live in `scripts/`, with backup helpers under `scripts/backup/`. Reverse-proxy config is in `proxy/Caddyfile`. Runbooks and rebuild docs live in `docs/`, mainly [`docs/setup.md`](docs/setup.md).

## Build, Test, and Development Commands

The Homelab runs on my homelab server, not on the development machine.
Do not try to run docker commands on the development machine to interact with the homelab.

- `./scripts/deploy.sh config --quiet`: validate all compose files exactly as CI does.

## Coding Style & Naming Conventions

Keep YAML and shell changes small and readable. Match existing formatting. Comment only when intent is not obvious.

## Testing Guidelines

There is no separate unit-test suite in this repo. The required validation step is `./scripts/deploy.sh config --quiet`; run it before opening a PR. Keep checks deterministic and avoid editing live data or services while testing.

## Deployment

Homelab is deployed via GitHub Actions and a self-hosted runner on my Homelab Server.
Repo is designed to be in a simplified GitOps style with a strong preference for declarative configuration.

## Security & Config Tips

Never commit `.env` or secrets. Treat `PLATFORM_ENV`, `CLOUDFLARED_TOKEN`, and Restic credentials as sensitive. Review image tags, exposed ports, and volume mounts carefully. Prefer validating compose changes locally before pushing to `main`, since pushes trigger the self-hosted deploy workflow.
