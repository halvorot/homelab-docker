# 9Router

9Router is available at `https://9router.halvorteigen.no`. Its SQLite database,
settings, provider credentials, and API keys persist under
`/srv/data/9router`.

## Pre-merge and deploy gate

Do not merge or deploy the 9Router compose changes until both prerequisites are
complete:

- Add this public hostname to the existing Cloudflare Tunnel:

  ```text
  9router.halvorteigen.no -> http://caddy:80
  ```

- Generate four independent values locally and add them to the complete
  production `.env` stored in the GitHub Actions `PLATFORM_ENV` secret:

  ```bash
  openssl rand -hex 32       # NINEROUTER_JWT_SECRET
  openssl rand -base64 32    # NINEROUTER_INITIAL_PASSWORD
  openssl rand -hex 32       # NINEROUTER_API_KEY_SECRET
  openssl rand -hex 32       # NINEROUTER_MACHINE_ID_SALT
  ```

  ```env
  NINEROUTER_JWT_SECRET=<first-output>
  NINEROUTER_INITIAL_PASSWORD=<second-output>
  NINEROUTER_API_KEY_SECRET=<third-output>
  NINEROUTER_MACHINE_ID_SALT=<fourth-output>
  ```

Keep these values stable across redeploys and restores. Never commit their
values. Compose validation deliberately fails when any one is absent.

`BASE_URL` defaults to the container's loopback URL for internal callbacks. If
OIDC or SAML SSO is enabled later, also set the following in `PLATFORM_ENV` so
9Router generates public callback URLs:

```env
NINEROUTER_BASE_URL=https://9router.halvorteigen.no
```

## First login and API key

1. Open `https://9router.halvorteigen.no` and sign in with the generated
   `NINEROUTER_INITIAL_PASSWORD`.
2. Keep dashboard login required.
3. Open **Endpoint**, create a named API key, and store it in the intended
   client's secret store.
4. Enable **Require API key** and reload the page to confirm the toggle remains
   enabled. This is a persisted database setting.

9Router 0.5.69 does not initialize the persisted `requireApiKey` setting from a
`REQUIRE_API_KEY` environment variable, so the compose file does not set that
variable. The public request guard in this release independently rejects remote
LLM API requests without a valid stored key; verify that behavior after every
deploy rather than relying on configuration intent.

## Post-deploy verification

Run these checks from a machine outside the Docker host. The health route is
intentionally public:

```bash
curl --fail --silent --show-error \
  https://9router.halvorteigen.no/api/health
# expected: {"ok":true}
```

Both a missing key and an invalid key must return HTTP 401 with
`{"error":"API key required for remote API access"}`:

```bash
curl --silent --show-error --output /tmp/9router-no-key.json \
  --write-out '%{http_code}\n' \
  https://9router.halvorteigen.no/v1/models

curl --silent --show-error --output /tmp/9router-invalid-key.json \
  --write-out '%{http_code}\n' \
  --header 'Authorization: Bearer invalid' \
  https://9router.halvorteigen.no/v1/models

cat /tmp/9router-no-key.json
cat /tmp/9router-invalid-key.json
```

Finally, verify the generated key is accepted:

```bash
read -r -s NINEROUTER_API_KEY
export NINEROUTER_API_KEY
curl --fail --silent --show-error \
  --header "Authorization: Bearer $NINEROUTER_API_KEY" \
  https://9router.halvorteigen.no/v1/models
unset NINEROUTER_API_KEY
```

If either unauthenticated check is not a 401, remove the Cloudflare hostname
route until the exposure is understood and corrected.

## Backup and restore

The repository's Restic backup includes `/srv/data/9router` because
`BACKUP_SOURCE` defaults to `/srv/data`. A restore brings back the database and
therefore the saved password, settings, provider credentials, and API keys.
`PLATFORM_ENV` is external to the backup and must still contain the same four
secrets.

Restore while 9Router is stopped to avoid replacing a live SQLite database.
Restore to a staging directory first, inspect it, then copy only the 9Router
data back:

```bash
docker compose -f docker-compose.yml -f apps/9router/compose.yaml stop 9router
./scripts/backup/restic-restore.sh latest /tmp/9router-restore
sudo rsync -a --delete \
  /tmp/9router-restore/srv/data/9router/ /srv/data/9router/
docker compose -f docker-compose.yml -f apps/9router/compose.yaml up -d 9router
```

Repeat the health, unauthorized, and valid-key checks after the restore. Remove
the staging directory only after those checks pass.
