# Hermes Agent

Hermes runs its Slack gateway and dashboard in one container, with a dedicated
SearXNG sidecar. Hermes and SearXNG use a dedicated egress network. The existing
Caddy service reaches Hermes over an internal backend network, so Hermes does
not join the shared application network. State, auth, sessions, skills, and
secrets persist under `/srv/data/hermes`; SearXNG's cache uses a named volume.

## Before deploy

Add these values to the GitHub `PLATFORM_ENV` secret:

```env
HERMES_DASHBOARD_BASIC_AUTH_USERNAME=admin
HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=<strong-random-password>
HERMES_DASHBOARD_BASIC_AUTH_SECRET=<openssl-rand-base64-32-output>
HERMES_SEARXNG_SECRET=<openssl-rand-hex-32-output>
```

Generate the signing secret locally:

```bash
openssl rand -base64 32
openssl rand -hex 32
```

## Initial setup

After deploy, run the required one-time setup over SSH on the homelab server:

```bash
docker exec -it hermes hermes setup
```

Choose `Full Setup`, then `ChatGPT or Codex Subscription`, complete the device
login, and select `gpt-5.6-terra`. Select Local for the terminal backend, leave
A2A disabled, select Local Browser, and select SearXNG with URL
`http://hermes-searxng:8080`. Skip messaging; configure Slack afterward.

The host path may differ from the upstream `~/.hermes` example. The container
path must remain `/opt/data`.

The image runs Hermes as UID/GID `10000` and initializes the bind mount through
its root-owned s6 entrypoint. Do not add Compose `user:` or override the
entrypoint. If setup reports permission errors, check the host owner with
`stat -c '%u:%g' /srv/data/hermes` and set matching `HERMES_UID` and
`HERMES_GID` values in `PLATFORM_ENV`.

In Cloudflare Tunnel, add:

```text
hermes.halvorteigen.no -> http://caddy:80
```

Hermes must trust Caddy's address on its backend network before honoring its
forwarded HTTPS scheme. After the first deploy, get that address:

```bash
docker inspect caddy \
  --format '{{with index .NetworkSettings.Networks "hermes-backend"}}{{.IPAddress}}{{end}}'
```

Add that exact address to `/srv/data/hermes/config.yaml` while preserving the
setup-generated configuration:

```yaml
dashboard:
  public_url: https://hermes.halvorteigen.no
  trusted_proxies:
    - <caddy-hermes-backend-ip>
```

Restart Hermes after editing. Update the address if Caddy is recreated with a
different IP. Never trust `*`, `0.0.0.0/0`, or `::/0`.

For Google login before basic auth, create a Cloudflare Access self-hosted
application for `hermes.halvorteigen.no`, select Google as the identity
provider, and restrict access to the intended Google account.

## OpenAI via ChatGPT subscription

The setup command stores the OAuth credentials and model configuration under
`/srv/data/hermes`. No OpenAI API key is required for this provider.

For an unattended gateway, enable the upstream-recommended loop hard stop in
`/srv/data/hermes/config.yaml`:

```yaml
tool_loop_guardrails:
  hard_stop_enabled: true
  hard_stop_after:
    exact_failure: 5
    idempotent_no_progress: 5
```
