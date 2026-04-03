# Plugin QuickJS runtime (phase F)

**opencliz** (Zig) embeds **QuickJS-ng** via **[mitchellh/zig-quickjs-ng](https://github.com/mitchellh/zig-quickjs-ng)**, matching the `quickjs_ng` package in `build.zig` / `build.zig.zon`.

## `plugin.yaml` fields

| Field | Description |
|-------|-------------|
| **`js_init`** | Optional. Path to a script relative to the plugin directory (e.g. `init.js`). On plugin load the **entire file** runs once in an isolated `Runtime`/`Context`; on success logs `js_init ok`. |

### Per-command `script` (inside `commands` array)

Each command mapping may set **`script`**: a `.js` path relative to the plugin directory. When that command runs:

1. Read the full script, wrap in QuickJS as `(function (opencliArgs) { … })(<CLI args JSON>)`, then **`JSON.stringify`** the result.
2. The script **body** should **`return`** a JSON-serializable value; `opencliArgs` is an object whose keys are CLI arg names and values are **strings** (same as CLI passing today).
3. The host injects **`opencli`** (same function scope): **`opencli.args`**, **`opencli.version`** (see `opencli_plugin_api_version`), **`opencli.log(message)`** (QuickJS **`print`**, line prefix **`[opencli] `**, for troubleshooting; not a structured log channel). **`opencli.http`** below requires explicit enable + domain allowlist.

### Implemented: `opencli.http` native bridge (Wave 3.2)

> **Done**: implemented in `src/plugin/quickjs_runtime.zig`.

| API | Description | Security |
|-----|-------------|----------|
| `opencli.http.get(url)` | GET request | URL allowlist |
| `opencli.http.post(url, body)` | POST request | URL allowlist |
| `opencli.http.request(method, url, options)` | Generic request; **`method`** **`GET`** / **`POST`** / **`HEAD`** | Full security model |

**`HEAD`**: host uses curl **`-I`**; JSON **`body`** is raw **response headers** (not entity body), **`status`** is final HTTP status; still subject to **`OPENCLI_PLUGIN_HTTP_MAX_BODY_BYTES`** (guards huge header blocks).

### `error` field in `opencli.http` responses (TS detail parity · P2)

The native bridge serializes failures as a **JSON string** (then `JSON.parse` on the JS side). From **`opencli_plugin_api_version` `0.2.3`**, host **`HttpError`** (curl missing status marker, etc.) maps to **`http_error`** for documentation alignment with Node “network/HTTP failure”; **not** byte-identical to TS.

| `error` value | Meaning | TS / Node note |
|---------------|---------|----------------|
| `missing_url` / `missing_url_or_body` / `missing_method_or_url` | Missing arguments | Like `TypeError` |
| `url_not_string` / `body_not_string` / `method_not_string` | Not a string | Same |
| `url_not_https` | Not https | Stricter than bare `fetch` |
| `url_not_whitelisted` | Host not in **`OPENCLI_PLUGIN_ALLOWED_DOMAINS`** | No global Node equivalent; document allowlist in TS |
| `body_too_large` | Over **`OPENCLI_PLUGIN_HTTP_MAX_BODY_BYTES`** | Like oversized body errors |
| `http_error` | **`HttpClient`** failure (incl. curl missing **`__OPENCLI_STATUS__`**) | “No valid HTTP response”; batch **63** |
| `request_failed` | Other host errors (subprocess timeout, non-`HttpError`, etc.) | Fallback; compare logs with TS |
| `method_not_allowed` | `request` method not GET/POST/HEAD | — |
| `post_body_required` | POST without body | — |
| `oom` | OOM reading allowlist env, etc. | Rare |

On success the object is **`{ status, body, url }`** (not guaranteed to match arbitrary TS `Response` shapes).

**Security model**:

1. **URL allowlist**: default only `https://` hosts on the list
2. **Timeout**: default 30s (`OPENCLI_PLUGIN_HTTP_TIMEOUT`)
3. **Methods**: **GET** / **POST** / **HEAD** only
4. **Sensitive headers**: internal Cookie/Token not exposed to plugins

**Environment variables**:

```bash
OPENCLI_PLUGIN_HTTP=1
OPENCLI_PLUGIN_HTTP_TIMEOUT=30000
OPENCLI_PLUGIN_HTTP_MAX_BODY_BYTES=2097152
OPENCLI_PLUGIN_ALLOWED_DOMAINS=api.example.com,cdn.jsdelivr.net
```

**Implementation notes**:

- `httpGetSync` / `httpPostSync` / **`httpHeadSync`** (**`HttpClient.head`**, curl **`-I`**) build JSON via `StringHashMap`; **`opencli_plugin_api_version`** **0.2.2**+ includes **HEAD**; **0.2.3**+ adds **`http_error`** as above
- Allowlist: `checkUrlWhitelist`
- Enable check: `isPluginHttpEnabled`
- Host registers **`__opencli_http_get` / `__opencli_http_post` / `__opencli_http_request`** (C); JS `opencli.http` wraps with `JSON.parse`
4. If both **`pipeline`** and **`script`** are set, **`script` wins** (same as `docs/TS_PARITY_MIGRATION_PLAN.md` phase F).

Scripts may have side effects (**`opencli.log`**, global state); further alignment with full TS plugin API is optional.

## Code locations

- `src/plugin/quickjs_runtime.zig`: `evalExpressionToString`, `evalPluginHandlerBody` (command script wrapper).
- `src/plugin/manager.zig`: `loadPlugin` runs `js_init`; command parsing sets `Command.js_script_path` for `script`.
- `src/cli/runner.zig`: `executePluginQuickJs` when `source=plugin` and `js_script_path` is set (before pipeline).

## Build

`zig build` / `zig test` statically links `quickjs-ng`. Requires a local C toolchain (same as other Zig C deps).

## Differences vs TS upstream

TS may run full adapter logic in Node; QuickJS here is for **lightweight script hooks**, not a replacement for legacy `type: ts` manifest entries (those default to `ts_adapter_not_supported` stub—see migration plan phase B).

## Optional: Node subprocess for `type: ts` (Wave 3.3)

To run legacy `type: ts` adapters:

```bash
OPENCLI_ENABLE_NODE_SUBPROCESS=1
```

**Behavior**:

1. When `OPENCLI_ENABLE_NODE_SUBPROCESS=1`, Zig detects `source=ts_legacy` and may run `node <modulePath> <args>`
2. Node receives the same argv as the Zig CLI
3. Adapter prints result JSON to stdout
4. Zig parses stdout JSON and returns it

**Requirements**:

- `node` on `PATH`
- `modulePath` correct in `cli-manifest.json`

**Env (H.3 / Wave 3.3)**:

```bash
OPENCLI_NODE_SUBPROCESS_TIMEOUT_MS=120000
OPENCLI_NODE_MAX_OUTPUT_BYTES=10485760
```

**Errors**:

- Missing/failed node → fall back to `ts_adapter_not_supported` stub
- Non-zero exit → `{ status: "node_error", exit_code: N, stderr: "..." }`
- Bad JSON → `{ status: "parse_error", raw_output: "..." }`
- Timeout may **SIGKILL** child; see `OPENCLI_NODE_SUBPROCESS_TIMEOUT_MS`

**When to use**: compliance needing TS adapters; gradual migration off stubs.

---

*Aligned with `docs/TS_PARITY_MIGRATION_PLAN.md` phase F.*
