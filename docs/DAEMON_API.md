# OpenCLI Daemon API

OpenCLI can run as a background daemon service, providing a REST API for remote command execution.

## Starting the Daemon

```bash
opencli serve
```

The daemon will start on `http://127.0.0.1:8080` by default.

### Environment variables

| Variable | Effect |
|----------|--------|
| `OPENCLI_DAEMON_PORT` | Listen port (default `8080`) |
| `OPENCLI_DAEMON_HOST` | Bind address (default `127.0.0.1`) |
| `OPENCLI_DAEMON_AUTH_TOKEN` | If set, **all** routes (except `OPTIONS` preflight) require one of the credentials below |
| `OPENCLI_DAEMON_REQUEST_TIMEOUT_MS` | 单连接读取完整 HTTP 请求（头+体）的总超时，毫秒；默认 `30000`；`0` 表示不限制（与旧行为一致；慎用） |
| `OPENCLI_DAEMON_EXECUTE_TIMEOUT_MS` | **`/execute` 内**命令执行 wall-clock 超时（毫秒）；默认 `0` = 不限制。超时返回 **504** + `{"error":"Execute timeout"}`；宿主仍会 **join** 工作线程（**不取消**正在运行的子进程/网络请求） |

curl 后端（`HttpClient.request`）另支持 **`OPENCLI_HTTP_FOLLOW_REDIRECTS`**（`0` 关闭 `-L`）、**`OPENCLI_HTTP_MAX_REDIRECTS`**（默认 `10`）、**`OPENCLI_HTTP_MAX_OUTPUT_BYTES`**（`Child.run` 上限，默认 20 MiB）。

**适配器 HTTP（`serve` / CLI 共用进程）**：**`OPENCLI_CACHE=0`** 关闭 **`http_exec`** 内 **`fetchJson`** 的进程内 JSON 响应缓存（与 TS 并排 diff 时建议关闭）；TTL/条数上限见 **`OPENCLI_CACHE_HTTP_TTL_MS`** 等（**`CacheManager.initFromEnv`**）。

## API Endpoints

### GET /
Returns daemon status and version.

**Response:**
```json
{
  "name": "OpenCLI Daemon",
  "version": "2.2.0",
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

若设置 **`OPENCLI_DAEMON_EXECUTE_TIMEOUT_MS` > 0** 且执行超过该时长：**504** + `{"error":"Execute timeout"}`。

## Configuration

Runtime options are driven by **environment variables** (see above). Conceptual fields:

- `host` / `port`: from `OPENCLI_DAEMON_HOST` / `OPENCLI_DAEMON_PORT`
- `auth_token`: from `OPENCLI_DAEMON_AUTH_TOKEN`
- `enable_cors`: enabled in code (default **true**); responses include `Access-Control-*` headers
- `request_timeout_ms`: from `OPENCLI_DAEMON_REQUEST_TIMEOUT_MS`（读请求阶段）
- `execute_timeout_ms`: from `OPENCLI_DAEMON_EXECUTE_TIMEOUT_MS`（`/execute` 内执行；`0` 关闭）
- `max_connections`: 仍为预留字段（当前 accept 循环未做连接数硬限制）

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
OPENCLI_DAEMON_PORT=9000 opencli serve
```

### Daemon with auth token
```bash
OPENCLI_DAEMON_AUTH_TOKEN='my-secret' opencli serve
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
| **`src/tests/daemon_contract_test.zig`** | Handler-only: JSON shapes, `auth_token`（**Bearer** / **`X-OpenCLI-Token`** / **query `token`**）、错误 Bearer→**401**、`OPTIONS` 在要求鉴权时仍 **204**、未知命令 **`/execute/...`**→**404**（无 runner 亦先判命令）、`parseHttpRequest`、`POST` body merge、`dispatchHttpRequest` wire output |
| **`src/tests/daemon_tcp_e2e_test.zig`** | Real TCP: **`GET /`**、`GET /health`、鉴权开启时无凭证 **401**、**`X-OpenCLI-Token`** 通过、带 Bearer 的 **`POST /execute/...`**（ts_legacy 桩） |
| **`src/tests/ai_explore_golden_test.zig`** | `exploreFromHtml` on **`explore_sample.html`** + **`explore_edge_min.html`** + `Synthesizer` vs **`tests/fixtures/golden/synthesizer_golden.yaml`** |

Run: `zig build test`.

## 与 TS 版 Daemon API 对照（Wave 4.3 diff）

> ⚠️ 以下对照基于 Zig 版实现；TS 版完整 API 端点需对照 `src/daemon.ts`（若存在）。

### Zig 版已实现端点

| 端点 | 方法 | 说明 |
|------|------|------|
| `/` | GET | 返回 `{"name","version","status"}` |
| `/health` | GET | 返回 `{"status":"healthy"}` |
| `/commands` | GET | 返回 `{"commands":[...]}` 命令列表 |
| `/execute/{site}/{command}` | GET/POST/PUT/PATCH | 执行命令，参数通过 query string 或 JSON body 传入 |

### Zig vs TS 差异（已知）

| 维度 | TS 版 | Zig 版 |
|------|-------|--------|
| 请求超时 | 可能有 | **`readHttpRequestFromStream`** 按 **`request_timeout_ms`** / **`OPENCLI_DAEMON_REQUEST_TIMEOUT_MS`** 在读请求阶段生效；超时 **408**。执行阶段可选 **`OPENCLI_DAEMON_EXECUTE_TIMEOUT_MS`**（**504**；不取消子进程，见上文） |
| WebSocket | TS 可能支持 | **不支持**（纯 HTTP） |
| 批量执行 | TS 可能支持 | **不支持** |
| 端点前缀 | TS 可能是 `/api/` | Zig 直接用根路径 `/` |
| 认证方式 | Bearer / X-Token / query | 与 TS 一致 |

### 待对照项（若 TS 版本有）

| 潜在差异 | 状态 | 说明 |
|----------|------|------|
| `/api/commands` vs `/commands` | ⚠️ 需确认 | Zig 用 `/commands` |
| `/api/execute/...` | ⚠️ 需确认 | Zig 用 `/execute/...` |
| 认证 middleware | ✅ 已一致 | Bearer / **`X-OpenCLI-Token`** / query；**批次 62** 单测覆盖错误凭证与 **OPTIONS** 绕过 |
| 请求/响应拦截器 | N/A | Zig 无此概念 |
| keep-alive | ⚠️ 需确认 | 需测 TS 版 |
| 未知命令错误码 | ✅ 与 REST 常见语义一致 | **`/execute`** 未注册命令 → **404** + **`{"error":"Command not found"}`**（**批次 65**；与 **`DAEMON_API`** 示例一致） |

### L7 阶段 H.4 签字

| 层级 | 覆盖范围 | 对照基线 | 签字 | 日期 | 备注 |
|------|----------|----------|------|------|------|
| L7 | Daemon HTTP + explore/synthesize golden | 本文 + `daemon_*_test`（**批次 62** 扩鉴权/根路径/TCP）/ `ai_explore_golden_test`；TS 以各仓库 `daemon` 实现为准 | ZZ | 2026-04-01 | 前缀/WebSocket/批量等差异见上表「Zig vs TS」 |

**注意**：字节级一致**不**是目标；以「同命令同参数同响应结构」为验收口径。CLI **`explore` / `synthesize`** 与 Daemon 解耦；L7 扩测时一并记录 TS 行为差异。
