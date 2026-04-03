# OpenCLI (Zig) — Current Capabilities vs Upstream OpenCLI

This document describes **what this repository (`opencliz`, Zig implementation) supports today**, and how that **differs from the original TypeScript OpenCLI** ([jackwener/opencli](https://github.com/jackwener/opencli), npm `@jackwener/opencli`).

For the formal upstream baseline definition, see **`UPSTREAM_REFERENCE.md`**. For migration batches and command-name statistics, see **`MIGRATION_GAP.md`**. For ongoing parity tasks, see **`PARITY_PROGRESS.md`**, **`TS_PARITY_REMAINING.md`**, and **`TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md`**.

---

## 1. Product identity

| Item | This repository (Zig) | Upstream (TypeScript) |
|------|------------------------|------------------------|
| Language | **Zig** (single static binary) | **Node.js / TypeScript** |
| Runtime | None required at install time | Node.js + npm dependencies |
| Browser integration | **CDP over WebSocket** (Chrome spawned locally, or **external** endpoint e.g. Lightpanda via `OPENCLI_CDP_WEBSOCKET`) | **Browser Bridge Chrome extension** + local daemon WebSocket |
| Primary goal | Same *vision* (“make any website your CLI”) with **fast cold start** and **low memory**; **not** byte-for-byte clone of upstream | Reference ecosystem and command surface |

**Version**: Use `./zig-out/bin/opencli --version` (source: `src/main.zig` `VERSION`).

---

## 2. What is supported today (summary)

### 2.1 CLI and output

- Command discovery: `opencli list` (live registry; exact command count evolves with YAML).
- Output formats: `table`, `json`, `yaml`, `markdown`, `csv`, `raw` (where applicable via `-f` / `--format`).
- Structured outcomes often include JSON fields such as `status`, `detail`, and adapter-specific keys; **semantic parity** with upstream is tracked via scripts and fixtures, not guaranteed for every command without running a diff.

### 2.2 Adapters and command surface

- **Broad site coverage**: browser-oriented adapters, HTTP-oriented paths, desktop/Electron-oriented hints, tools, and more — see `docs/adapters/index.md` and generated discovery.
- **Command naming (L0)**: Historical alignment target is **`missing = 0`** against the legacy `src/clis` tree (documented in **`MIGRATION_GAP.md`**).

### 2.3 HTTP execution path

- Fetch-based adapters with configurable HTTP client behavior (timeouts, curl-style overrides via documented `OPENCLI_HTTP_*` variables where implemented).
- **Caching**: In-memory JSON cache for certain adapter and pipeline fetch paths; disable with **`OPENCLI_CACHE=0`** when comparing to upstream or debugging stale data.
- **Authentication helpers**: Cookie and site-specific environment variables (see **`AUTH_AND_WRITE_PATH.md`**). Full per-site OAuth parity is **not** promised; many flows are **best-effort** or **browser-assisted**.

### 2.4 Browser path (no Chrome extension required)

Upstream often assumes the **Browser Bridge** extension and a local daemon. **This Zig build does not use that extension.** Equivalent *goals* for “logged-in or rendered DOM” are addressed as follows:

| Mechanism | Purpose |
|-----------|---------|
| **`OPENCLI_USE_BROWSER=1`** | After an HTTP result, optionally **deepen** using **Chrome DevTools Protocol (CDP)** — navigate, wait for selectors, evaluate script, feed **`article_pipeline`** (see `src/adapters/adapter_browser.zig`). |
| **Spawned Chrome** | Default: start a dedicated Chrome with `--remote-debugging-port` and connect to `ws://…/devtools/browser` (see `src/browser/websocket.zig`). The spawned profile uses **`--disable-extensions`** — your everyday Chrome extensions are **not** loaded there. |
| **`OPENCLI_CDP_WEBSOCKET`** | If set (non-empty), **do not** spawn Chrome; connect directly to the given **`ws://`** URL (e.g. **Lightpanda** `serve`). **`wss://`** is **not** supported yet. |
| **Scenario matrix** | Signed behaviors and timeouts for specific `browser: true` commands are listed in **`CDP_SCENARIO_MATRIX.md`** (smoke coverage references **`.github/workflows/zig-chrome-ci.yml`**). |

**Docs**: **`advanced/cdp.md`** (remote Chrome, tunnels, `OPENCLI_CDP_ENDPOINT` vs `OPENCLI_CDP_WEBSOCKET`).

### 2.5 Article / Markdown pipeline

- HTML → readable Markdown: optional external script **`OPENCLI_HTML_TO_MD_SCRIPT`**, or built-in simplifier **`OPENCLI_BUILTIN_HTML_TO_MD=1`** — see **`MARKDOWN_ARTICLE_PIPELINE.md`**.
- Not a Turndown-level clone of upstream; alignment is **practical readability**, not identical HTML→MD rules.

### 2.6 Plugins

- **QuickJS**-hosted plugins (`plugin.yaml`, `PLUGIN_QUICKJS.md`).
- **`opencli.http`** subset for plugins (GET/POST/HEAD, documented error shapes) — **not** the full Node plugin API from upstream.

### 2.7 Daemon mode

- **`opencli serve`**: HTTP API for remote execution (see **`DAEMON_API.md`**).
- **Different** from upstream’s daemon + extension architecture (ports, routes, and “doctor” integration are not matched 1:1).

### 2.8 External CLIs

- **`external/`** and **`external-clis.yaml`**: invoke tools like `gh`, `docker` through OpenCLI with unified formatting.
- Behavior vs upstream “CLI Hub” / `register` flows may differ; treat as **related capability**, not a guaranteed match.

### 2.9 AI discovery / exploration

- Features such as **`--explore`** / **`--generate`** (and related tests) exist in this codebase; they are **not** documented here as full parity with every upstream AI or `operate`-style browser automation surface.

---

## 3. Major differences from upstream OpenCLI

| Area | Upstream (typical) | This Zig build |
|------|-------------------|----------------|
| **Browser bridge** | Extension + localhost WebSocket to daemon | **No extension**; **CDP** (`OPENCLI_USE_BROWSER`, optional **`OPENCLI_CDP_WEBSOCKET`**) |
| **Automation stack** | Playwright / rich browser tooling in places | **CDP client** + scenario matrix; **no Playwright** |
| **Login session** | Extension can read scoped cookies for commands | Use **HTTP cookies** env vars and/or **log in inside the CDP Chrome profile** (or debugging Chrome you attach to) |
| **Daemon** | Integrated docs / ports as in upstream | **`opencli serve`** REST subset — see **`DAEMON_API.md`** |
| **Exit codes** | Some sysexits-style conventions (e.g. login required) | Often **`status` inside JSON**; exit-code parity is **not** guaranteed |
| **`operate` / deep AI browser control** | Product features in upstream direction | **Not** replicated as a first-class equivalent |
| **Plugins** | Node ecosystem assumptions | **QuickJS** + documented HTTP API subset |
| **Performance** | Node cold start / memory | **Single small binary**, very fast startup (see `README.md` metrics — illustrative, measure on your machine) |

---

## 4. How we measure “parity”

1. **Command names (L0)**: `missing = 0` tracking in **`MIGRATION_GAP.md`**.
2. **JSON shape (L2)**: Fixtures under `tests/fixtures/json/`, `zig build test`, and scripts such as **`scripts/compare_command_json.sh`** / **`scripts/l2_p0_routine.sh`** with **`OPENCLI_CACHE=0`** where appropriate.
3. **Browser deepen (L3)**: **`CDP_SCENARIO_MATRIX.md`** + **`zig-chrome-ci.yml`** — **not** Playwright parity.
4. **Auth / write paths (L4)**: **`AUTH_AND_WRITE_PATH.md`**.
5. **Article / Markdown (L5)**: **`MARKDOWN_ARTICLE_PIPELINE.md`**.
6. **Explicit cap / exclusions**: **`TS_PARITY_99_CAP.md`** (what we do **not** promise).

---

## 5. Choosing a workflow without the extension

1. Prefer **HTTP** + cookies when the adapter supports it.
2. For `browser: true` commands that need rendered DOM or lazy-loaded content: set **`OPENCLI_USE_BROWSER=1`** and ensure **Chrome** is available (or set **`OPENCLI_CDP_WEBSOCKET`** for Lightpanda / another **ws://** CDP server).
3. For remote servers, use SSH tunnel or proxy patterns in **`advanced/cdp.md`**.

---

## 6. Document map (quick links)

| Document | Topic |
|----------|--------|
| **`UPSTREAM_REFERENCE.md`** | Official upstream repo + how we reference it |
| **`CDP_SCENARIO_MATRIX.md`** | Browser deepen matrix |
| **`advanced/cdp.md`** | Chrome remote debugging, tunnels, `OPENCLI_CDP_WEBSOCKET` |
| **`MARKDOWN_ARTICLE_PIPELINE.md`** | Article / Markdown export |
| **`PLUGIN_QUICKJS.md`** | QuickJS plugins |
| **`DAEMON_API.md`** | `opencli serve` |
| **`AUTH_AND_WRITE_PATH.md`** | Cookies, OAuth/write boundaries |
| **`TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md`** | Scheduled gap work |
| **`TS_PARITY_99_CAP.md`** | Theoretical parity ceiling and exclusions |
| **`adapters/index.md`** | Per-site adapter list |
| **`adapters/BROWSER_PREREQUISITES.md`** | Browser Bridge vs CDP for this Zig port |

---

*Last updated: 2026-04-01 — maintainers: keep §2 in sync when adding user-visible env vars or subsystems; point version readers to `src/main.zig`.*
