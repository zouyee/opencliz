# opencliz Daemon API

**opencliz** can run as a background daemon (`opencliz serve`), exposing a REST API for remote command execution.

## Starting the Daemon

```bash
opencliz serve
```

The daemon will start on `http://127.0.0.1:8080` by default.

### Environment variables

| Variable | Effect |
|----------|--------|
| `OPENCLI_DAEMON_PORT` | Listen port (default `8080`) |
| `OPENCLI_DAEMON_HOST` | Bind address (default `127.0.0.1`) |
| `OPENCLI_DAEMON_AUTH_TOKEN` | If set, **all** routes (except `OPTIONS` preflight) require one of the credentials below |
| `OPENCLI_DAEMON_REQUEST_TIMEOUT_MS` | Total time to read one full HTTP request (headers + body) on a connection, in ms; default `30000`; `0` = unlimited (legacy behavior; use with care). |
| `OPENCLI_DAEMON_EXECUTE_TIMEOUT_MS` | Wall-clock timeout **inside** **`/execute`** (ms); default `0` = unlimited. On timeout: **504** + `{"error":"Execute timeout"}`; the host still **joins** the worker thread (**does not** cancel in-flight child processes or network I/O). |

The curl-backed `HttpClient.request` path also honors **`OPENCLI_HTTP_FOLLOW_REDIRECTS`** (`0` disables `-L`), **`OPENCLI_HTTP_MAX_REDIRECTS`** (default `10`), and **`OPENCLI_HTTP_MAX_OUTPUT_BYTES`** (cap for `Child.run`, default 20 MiB).

**Adapter HTTP (`serve` / CLI same process)**: **`OPENCLI_CACHE=0`** disables in-process JSON caching for **`fetchJson`** inside **`http_exec`** (recommended when diffing against TS); TTL / entry limits use **`OPENCLI_CACHE_HTTP_TTL_MS`** and related vars (**`CacheManager.initFromEnv`**).

## API Endpoints

### GET /
Returns daemon status and version.

**Response:**
```json
{
  "name": "opencliz daemon",
  "version": "v0.0.1",
  "status": "running"
}
```

### GET /health
Health check endpoint.

**Response:**
```json
{
  "status": "healthy"
}
```

### GET /commands
List all available commands.

**Response:**
```json
{
  "commands": [
    {
      "site": "bilibili",
      "name": "hot",
      "description": "Get trending videos"
    },
    {
      "site": "github",
      "name": "trending",
      "description": "Get trending repositories"
    }
  ]
}
```

### GET /execute/{site}/{command}
Execute a command with **query parameters** (`key=value` pairs). Same path works for **POST**, **PUT**, or **PATCH** with a **JSON object** body: top-level keys become CLI-style args (string, number, and boolean values are stringified). JSON body keys **override** query keys on conflict. If `Content-Type` is set and is **not** `application/json`, the body is ignored for argument merging.

**Example (GET):**
```bash
curl "http://localhost:8080/execute/bilibili/hot?limit=5"
```

**Example (POST, same semantics as the curl example in *Webhook integration*):**
```bash
curl -X POST "http://localhost:8080/execute/github/trending" \
  -H "Content-Type: application/json" \
  -d '{"language": "python"}'
```

**Response:**
```json
{
  "data": [
    {
      "title": "Video Title",
      "owner": {
        "name": "Author"
      },
      "stat": {
        "view": 12345
      }
    }
  ]
}
```

**Error Response:**
```json
{
  "error": "Command not found"
}
```

If **`OPENCLI_DAEMON_EXECUTE_TIMEOUT_MS` > 0** and execution exceeds that limit: **504** + `{"error":"Execute timeout"}`.

## Configuration

Runtime options are driven by **environment variables** (see above). Conceptual fields:

- `host` / `port`: from `OPENCLI_DAEMON_HOST` / `OPENCLI_DAEMON_PORT`
- `auth_token`: from `OPENCLI_DAEMON_AUTH_TOKEN`
- `enable_cors`: enabled in code (default **true**); responses include `Access-Control-*` headers
- `request_timeout_ms`: from `OPENCLI_DAEMON_REQUEST_TIMEOUT_MS` (request read phase)
- `execute_timeout_ms`: from `OPENCLI_DAEMON_EXECUTE_TIMEOUT_MS` (inside `/execute`; `0` disables)
- `max_connections`: reserved; accept loop does not enforce a hard connection cap yet

## Authentication

When `OPENCLI_DAEMON_AUTH_TOKEN` is set, every request must prove the token using **one** of:

1. Header `Authorization: Bearer <token>`
2. Header `X-OpenCLI-Token: <token>`
3. Query parameter `token=<token>` (useful for quick `curl` tests)

Missing or wrong credentials → **401** with body `{"error":"Unauthorized"}`.

`OPTIONS *` (CORS preflight) does **not** require a token.

## Usage Examples

### Start daemon on custom port
```bash
OPENCLI_DAEMON_PORT=9000 opencliz serve
```

### Daemon with auth token
```bash
OPENCLI_DAEMON_AUTH_TOKEN='my-secret' opencliz serve
curl -H "Authorization: Bearer my-secret" http://127.0.0.1:8080/health
```

### Execute command via API
```bash
# Get GitHub trending repositories
curl "http://localhost:8080/execute/github/trending?language=zig"

# Search Bilibili videos
curl "http://localhost:8080/execute/bilibili/search?query=zig&limit=10"
```

### Health monitoring
```bash
# Check if daemon is running
curl http://localhost:8080/health
```

### Stop the daemon
Press `Ctrl+C` in the terminal where the daemon is running.

## Security Considerations

- By default, the daemon only binds to localhost (127.0.0.1)
- To expose to the network, change the host to "0.0.0.0" (not recommended without authentication)
- Set `OPENCLI_DAEMON_AUTH_TOKEN` to require authentication on all routes except `OPTIONS`
- Use HTTPS in production (put behind a reverse proxy like nginx)

## Integration Examples

### Webhook integration
```bash
# Execute command when webhook is received
curl -X POST "http://localhost:8080/execute/github/trending" \
  -H "Content-Type: application/json" \
  -d '{"language": "python"}'
```

### Script automation
```bash
#!/bin/bash
# get_trending.sh
DAEMON_URL="http://localhost:8080"
curl -s "${DAEMON_URL}/execute/github/trending?language=$1" | jq '.data[0].full_name'
```

## Tests (Zig)

| File | What it covers |
|------|----------------|
| **`src/tests/daemon_contract_test.zig`** | Handler-only: JSON shapes, `auth_token` (**Bearer** / **`X-OpenCLI-Token`** / query **`token`**), bad Bearer → **401**, **`OPTIONS`** still **204** when auth is required, unknown **`/execute/...`** → **404** (command checked before runner), `parseHttpRequest`, `POST` body merge, `dispatchHttpRequest` wiring |
| **`src/tests/daemon_tcp_e2e_test.zig`** | Real TCP: **`GET /`**, **`GET /health`**, **401** without creds when auth on, **`X-OpenCLI-Token`** accepted, **`POST /execute/...`** with Bearer (ts_legacy stub) |
| **`src/tests/ai_explore_golden_test.zig`** | `exploreFromHtml` on **`explore_sample.html`** + **`explore_edge_min.html`** + `Synthesizer` vs **`tests/fixtures/golden/synthesizer_golden.yaml`** |

Run: `zig build test`.

## Daemon API vs TypeScript upstream (Wave 4.3 diff)

> ⚠️ This comparison reflects the Zig build. For the full TS surface, compare `src/daemon.ts` in the upstream repo (if present).

### Endpoints implemented in Zig

| Path | Method | Description |
|------|--------|-------------|
| `/` | GET | `{"name","version","status"}` |
| `/health` | GET | `{"status":"healthy"}` |
| `/commands` | GET | `{"commands":[...]}` command list |
| `/execute/{site}/{command}` | GET/POST/PUT/PATCH | Run command; args from query string or JSON body |

### Known Zig vs TS differences

| Area | TS | Zig |
|------|----|-----|
| Request timeout | May exist | **`readHttpRequestFromStream`** uses **`request_timeout_ms`** / **`OPENCLI_DAEMON_REQUEST_TIMEOUT_MS`** during read → **408**. Optional **`OPENCLI_DAEMON_EXECUTE_TIMEOUT_MS`** for execute → **504** (does not kill children; see above) |
| WebSocket | TS may support | **Not supported** (HTTP only) |
| Batch execute | TS may support | **Not supported** |
| Path prefix | TS may use `/api/` | Zig uses `/` at repo root |
| Auth | Bearer / X-Token / query | Same shape as TS |

### Items to verify against TS (if applicable)

| Potential gap | Status | Note |
|---------------|--------|------|
| `/api/commands` vs `/commands` | ⚠️ confirm | Zig uses `/commands` |
| `/api/execute/...` | ⚠️ confirm | Zig uses `/execute/...` |
| Auth middleware | ✅ aligned | Bearer / **`X-OpenCLI-Token`** / query; batch **62** tests bad creds + **OPTIONS** |
| Request/response interceptors | N/A | Not a Zig concept |
| keep-alive | ⚠️ confirm | Measure on TS if needed |
| Unknown command status | ✅ REST-like | Unregistered **`/execute`** → **404** + **`{"error":"Command not found"}`** (batch **65**; matches examples here) |

### L7 phase H.4 sign-off

| Layer | Scope | Baseline | Sign | Date | Notes |
|-------|-------|----------|------|------|-------|
| L7 | Daemon HTTP + explore/synthesize golden | This doc + `daemon_*_test` (batch **62**: auth, `/`, TCP) / `ai_explore_golden_test`; TS = that repo’s daemon | ZZ | 2026-04-01 | Prefix / WebSocket / batch gaps → “Zig vs TS” table |

**Note**: Byte-identical responses are **not** the goal. Acceptance is same command, same args, same response **shape**. CLI **`explore` / `synthesize`** are decoupled from the daemon; record TS behavioral deltas when extending L7 tests.
