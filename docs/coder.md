# Coder

Coder runs at `https://coder.halvorteigen.no`. Docker workspaces run on the
homelab host.

## Security model

Coder can control the host Docker daemon. A Coder owner or template author can
therefore gain root-equivalent host access. Keep ownership and template editing
restricted. Workspaces must never receive the host Docker socket.

Wildcard workspace apps use `*-coder.halvorteigen.no`. Path-based apps and
workspace sharing are disabled. This isolates workspace web apps from the Coder
API browser origin.

## Before deploy

Create a dedicated GitHub OAuth app:

- Homepage URL: `https://coder.halvorteigen.no`
- Callback URL: `https://coder.halvorteigen.no/api/v2/users/oauth2/github/callback`

Do not enable callback wildcard matching. The app only needs read access to
email addresses. Do not reuse the Hermes GitHub App.

Add these values to the GitHub `PLATFORM_ENV` secret:

```env
CODER_POSTGRES_PASSWORD=<URL-safe-random-value>
CODER_EXTERNAL_TOKEN_ENCRYPTION_KEY=<base64-encoded-32-byte-key>
CODER_OAUTH2_GITHUB_CLIENT_ID=<oauth-client-id>
CODER_OAUTH2_GITHUB_CLIENT_SECRET=<oauth-client-secret>
```

Generate secrets:

```bash
openssl rand -base64 32 | tr '+/' '-_' | tr -d '='
openssl rand -base64 32
```

The encryption key must decode to exactly 32 bytes. Back it up separately from
PostgreSQL; losing it makes encrypted GitHub tokens unreadable.

The Coder container uses host Docker group ID `990`. If the server is rebuilt,
verify it still matches `stat -c '%g' /var/run/docker.sock` before deploying.

In Cloudflare Tunnel, add:

```text
coder.halvorteigen.no -> http://caddy:80
*.halvorteigen.no -> http://caddy:80
```

Cloudflare's standard `*.halvorteigen.no` certificate covers both the dashboard
and suffix-style workspace app hosts. Caddy only proxies wildcard hosts ending
in `-coder.halvorteigen.no`; other wildcard hosts receive 404.

## Initial setup

Deploy before adding the public Tunnel routes. Create the first owner with the
verified email address used by `halvorot` and a strong temporary password. In
account settings, convert its login type to GitHub and authenticate as
`halvorot`. Log out and verify GitHub login works.

Then set this in `PLATFORM_ENV` and redeploy:

```env
CODER_DISABLE_PASSWORD_AUTH=true
```

GitHub has no personal-account allowlist setting. Coder therefore allows GitHub
as an identity source but keeps new signups disabled. Only pre-created Coder
users can log in; unknown GitHub users are rejected.

In Coder, open **Templates**, select **New Template**, and start with the
official Docker template. Keep `/home/coder` on its persistent Docker volume.
The deploy cleanup intentionally does not prune volumes, so stopped workspace
homes survive deployments.

Do not add Docker-in-Docker or the host Docker socket to a workspace unless a
specific task requires it and the isolation tradeoff has been reviewed.

Enable **Coder Agents** for the template. Give it a specific description and
README so the agent selects it for this repository. Ensure the workspace has
`git`, `sh`, the repository's build tools, and an `AGENTS.md` in its working
directory.

## Coder Agents via 9Router

Generate a dedicated API key in 9Router. Do not reuse its dashboard password or
store the API key in this repository. In Coder, open **Admin settings > AI >
Providers**, add an **OpenAI Compatible** provider, and configure:

```text
Name: 9router
Base URL: http://9router:20128/v1
API key: <dedicated-9router-api-key>
```

Both containers share `homelab-docker`; keep this traffic on the internal
Docker route instead of the public hostname. API authentication is mandatory on
9Router's `/v1` endpoints. After deployment, confirm **Require API Key** is
enabled on 9Router's Endpoint page and an unauthenticated `GET /v1/models`
returns `401`.

Open **Admin settings > AI > Models**, select the default organization, and add
one model backed by `9router`. Get its exact ID from 9Router's authenticated
`GET /v1/models` response, verify it supports tool calls, and make it the
default. Model availability depends on the accounts connected to 9Router, so do
not hard-code a model ID in this repository.

Create one Coder Agent chat directly and confirm it can select the template,
clone the repository, edit a file, and run the validation command before adding
Hermes.

## Hermes integration

Hermes is the conversational orchestrator. It delegates substantial coding to
native Coder Agents through Coder's remote MCP server. Use a dedicated Coder
user rather than the owner token.

From an authenticated owner CLI session:

```bash
coder users create \
  --username hermes \
  --email hermes@halvorteigen.no \
  --login-type none
coder tokens create \
  --user hermes \
  --name hermes-mcp \
  --lifetime 2160h
```

Hermes is a regular member because service accounts require Coder Premium. It
cannot log in interactively. Do not grant it owner or template-admin roles.
Allow the user to access only the agent template and model it needs.

Do not add Coder's generated SSH key to the `halvorot` GitHub account. It would
inherit that account's repository access.

Use a dedicated private GitHub App for Coder. Install it on the `halvorot`
account with **All repositories** so it also covers future repositories. Grant
only **Contents: Read and write** initially. Add **Pull requests: Read and
write** if Coder must manage pull requests, and **Workflows: Read and write**
only if it must modify `.github/workflows`.

Use short-lived GitHub App installation tokens with HTTPS remotes. Keep the App
private key outside workspaces and issue tokens through an authenticated
internal broker or credential helper. Never persist a token in a remote URL.
Use a separate GitHub App and private key for Hermes so either identity can be
restricted, audited, rotated, and revoked independently.

Coder's native GitHub external authentication is not the service identity used
here. It creates a user access token through an interactive OAuth flow. Even
though a GitHub App limits that token's permissions and repositories, actions
still run on behalf of the authorizing GitHub user.

Add this to the existing `/srv/data/hermes/config.yaml`, substituting the
returned token:

```yaml
mcp_servers:
  coder:
    url: https://coder.halvorteigen.no/api/experimental/mcp/http
    headers:
      Coder-Session-Token: <hermes-coder-token>
```

Append this policy to `/srv/data/hermes/SOUL.md`:

```markdown
For substantial coding tasks, delegate to a native Coder Agent through the
Coder MCP server. Discover the Coder chat tools with `find_tools`, then use
`coder_create_chat`. Monitor with `coder_get_chat` and
`coder_get_chat_messages`; relay questions with `coder_send_chat_message`.
Report the final summary, workspace, validation result, and changed files.

Use Coder's direct file and command tools only for inspection or small explicit
operations. Do not interrupt, archive, delete, push, or open a pull request
unless the user requested it.
```

Restart Hermes. Ask it to delegate a small repository task. Verify that it uses
`coder_create_chat`, the child chat appears in Coder, work runs as `hermes`, and
Hermes reports the result. The MCP server defers most schemas behind
`find_tools`, so initial tool lists are intentionally small.

Treat `config.yaml` as a secret, restrict its permissions, and rotate this
90-day token before expiry. Never commit it or add it to `PLATFORM_ENV`.

## Codex and other harnesses

For interactive MCP clients supporting OAuth, add:

```json
{
  "mcpServers": {
    "coder": {
      "url": "https://coder.halvorteigen.no/api/experimental/mcp/http"
    }
  }
}
```

Alternatively install the Coder CLI, run `coder login
https://coder.halvorteigen.no`, and configure the client to launch `coder exp
mcp server` over stdio. Install Codex or another coding harness inside the
workspace when the work should execute there.

The remote MCP endpoint is beta and requires the explicitly enabled `oauth2`
and `mcp-server-http` experiments. Coder Agents and its Chats API are stable in
Coder 2.37; review the MCP experiment flags during upgrades.
