# OpenCLI: TypeScript vs Zig — capability gap and schedule

> **English summary vs upstream:** **`CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md`**.

> **Baseline**: Upstream [**jackwener/opencli**](https://github.com/jackwener/opencli) (TypeScript; browser bridge + Playwright, etc.) is the **reference**; this Zig port is **`opencliz`**. See **`docs/UPSTREAM_REFERENCE.md`**.  
> **Aligned today**: command names **`missing=0`** (`MIGRATION_GAP.md`); migration plan **phases A–G** delivered (`TS_PARITY_MIGRATION_PLAN.md`).  
> This doc lists **product/runtime** gaps where Zig is not yet aligned (or only partly), plus a **suggested schedule** (adjust to team capacity).

---

## 1. Overview

| Area | Typical TS | Zig today | Gap summary |
|------|------------|-----------|-------------|
| **Command surface** | Full `site/command` | Baseline registered; depth varies per command | Same name ≠ same behavior; L2 per-site |
| **HTTP** | axios/fetch, cache, redirects | `http_exec` + `HttpClient`; **`fetchJson`** and **YAML `pipeline` `fetch` (GET)** share **JSON memory cache** (**`OPENCLI_CACHE=0`** off; TTL caps **`OPENCLI_CACHE_*`**; batch **57**) | Cache keys/TTL may differ; side-by-side diff |
| **Browser** | Playwright | CDP (`OPENCLI_USE_BROWSER=1`) | Different stack; **scenario matrix** only |
| **Login / OAuth** | Multi-site OAuth, device flows | Cookie/header injection + `status` | **No** full in-process OAuth |
| **HTML→MD** | Turndown, etc. | External script first + built-in simplifier (batch **60**: common inline + block flow) | Not Turndown rule-by-rule |
| **Images / media** | article-download pipeline | Limited switches + absolute URL download | Not legacy full media pipe |
| **Plugins** | Node ecosystem, `type: ts` often runnable | QuickJS + `script`; `ts_legacy` stub by default; **optional** Node subprocess; **`opencli.http`** (`OPENCLI_PLUGIN_HTTP=1` + allowlist, **`PLUGIN_QUICKJS.md`**) | No in-process TS; no full Node builtins |
| **Daemon** | (if present) full API surface | `serve` + REST subset + tests; **read timeout** (batch **54**) + optional **`/execute` timeout** (batch **55** / **`OPENCLI_DAEMON_EXECUTE_TIMEOUT_MS`**) | WebSocket / batch may be missing; compare TS |
| **AI explore / generate** | Deeper explore/generate | Heuristic HTML + YAML synthesize golden | Heuristics/model chain may differ |
| **Desktop / Electron** | CDP to app | `desktop_exec` + `OPENCLI_CDP_ENDPOINT` | Local env; hard to match TS 100% |

---

## 2. Layered gaps (vs `TS_PARITY_MIGRATION_PLAN.md` §1 L0–L7)

### L2 — HTTP

| Point | TS | Zig | Note |
|-------|----|-----|------|
| Byte-identical all sites | Varies | No | Redesign, anti-bot, cache |
| Stable public API shapes | Implicit | Fixtures + optional live diff | Expand fixtures; **`l2_p0_routine.sh`** / **`--diff-ts`** (batch **61**); networked diff manual/CI |
| Cache semantics | TS impl | Zig own | Document or script TTL/keys |

### L3 — Browser (`browser: true`)

| Point | TS | Zig | Note |
|-------|----|-----|------|
| Playwright wait/selectors | Full | CDP + site branches | **Not equivalent**; only `CDP_SCENARIO_MATRIX.md` checks |
| CI browser subset | Maybe | **`zig-chrome-ci.yml`** (batch **63**: five scenarios + weekly) | Not Playwright-equivalent |
| Matrix sign-off | — | Doc maintained | Per-row sign-off ongoing |

### L4 — Auth and writes

| Point | TS | Zig | Note |
|-------|----|-----|------|
| OAuth / device | Multi-site | Not embedded | External token + Cookie; **`AUTH_AND_WRITE_PATH.md`** P1 matrix (batch **62**) |
| Writes (post, favorite, …) | Some sites | Register/chain incomplete | Needs creds + per-site tests; matrix states boundaries |
| Structured errors | Yes | `login_required`, etc. | Compare coverage vs TS |

### L5 — Rich text and images

| Point | TS | Zig | Note |
|-------|----|-----|------|
| Turndown-grade HTML→MD | Yes | Script or built-in (batch **60**) | Ruleset not equivalent |
| Full image pipeline | Yes | `OPENCLI_ARTICLE_DOWNLOAD_IMAGES`, etc. | See `MARKDOWN_ARTICLE_PIPELINE.md` |

### L6 — Plugin runtime

| Point | TS | Zig | Note |
|-------|----|-----|------|
| `type: ts` in-process | Yes | **Optional** → `ts_legacy` stub + `OPENCLI_ENABLE_NODE_SUBPROCESS=1` | Subprocess path exists |
| Node builtins (fs, http, …) | Yes | **No** | QuickJS = `opencli` subset only |
| `opencli` HTTP bridge | Implicit in Node | **`opencli.http`** GET/POST/HEAD + **`error`/`http_error`** (batch **63**, API **0.2.3**) | Not `fetch` superset |

### L7 — Daemon / explore / synthesize

| Point | TS | Zig | Note |
|-------|----|-----|------|
| Full daemon API | Depends on TS version | Subset + `DAEMON_API.md`; read timeout + execute timeout; batch **62** tests; unknown **404** (batch **65**) | WebSocket / batch may lack |
| Explore depth | May be deeper | Heuristic + `exploreFromHtml` tests | Not feature-by-feature |
| generate full chain | TS | Zig has Generator | Compare per URL/site |

---

## 3. Suggested waves (priorities)

### Wave 1 — **Ongoing / every sprint (P0)**

| # | Deliverable | Acceptance |
|---|-------------|------------|
| 1.1 | Expand `tests/fixtures/json/` + `fixture_json_test` (batch **53** HN `time`, GitHub trending array, SO `items` wrapper; batches **50–51**) | `zig build test` |
| 1.2 | Core commands vs TS **`jq -S`** diff (`l2_p0_routine.sh`, `compare_command_json.sh --diff-ts`; **`OPENCLI_CACHE=0`**) | Record baseline commit |
| 1.3 | Cache/redirect deltas in `MIGRATION_GAP` | Traceable (batch **49** + script comments) |

**Aim**: L2 regression is provable; less silent drift.

### Wave 2 — **~2–4 weeks (P1)** (batch **52** closed)

| # | Deliverable | Acceptance |
|---|-------------|------------|
| 2.1 | `CDP_SCENARIO_MATRIX.md` **per-row** sign-off (or N/A) | Matrix + **`zig-chrome-ci.yml`** |
| 2.2 | L4: minimal OAuth **or** written “no device code” | **`AUTH_AND_WRITE_PATH.md`** Wave 2.2 **ZZ** |
| 2.3 | Optional: one Cookie write/private read **manual** steps | **`AUTH_AND_WRITE_PATH.md`** + **`regression_cookie_writepath.sh`** |

**Aim**: L3/L4 **signed caps**.

### Wave 3 — **~1–2 months (P2)** (batch **52** closed)

| # | Deliverable | Acceptance |
|---|-------------|------------|
| 3.1 | Zig + Chrome **minimal** CI (1–2 matrix scenarios) | **`zig-chrome-ci.yml`**: `web/read` + **`zhihu/download`** (`|| true`) |
| 3.2 | QuickJS **`opencli.http`** + allowlist + timeout | **`quickjs_runtime.zig`** **`__opencli_http_*`** + offline tests |
| 3.3 | **Harden** Node subprocess: timeout/error mapping/argv vs TS | **`runner.zig`** + **`PLUGIN_QUICKJS.md`** |

**Aim**: L6 closer to TS plugins; L3 has CI signal.

### Wave 4 — **Ongoing (P3)**

| # | Deliverable | Acceptance |
|---|-------------|------------|
| 4.1 | `OPENCLI_HTML_TO_MD_SCRIPT` docs + examples; small built-in rule adds | **`MARKDOWN_ARTICLE_PIPELINE.md`** § H.4 (batch **53**) |
| 4.2 | Image pipeline per `MARKDOWN_ARTICLE_PIPELINE.md` | Document TS delta (§ H.4) |
| 4.3 | Daemon/explore vs TS new endpoints **itemized diff** | **`DAEMON_API.md`** L7 sign-off + **`explore_edge_min`** golden (batch **53**) |

**Aim**: UX alignment; **not** rule-level 100%.

### Explicitly **not** mandatory

Full-site OAuth, credentialed writes everywhere, Playwright↔CDP API parity, full Electron, “all TS adapters in Zig without subprocess”. See **`TS_PARITY_99_CAP.md` §4**.

---

## 4. Related docs

| Doc | Role |
|-----|------|
| This file | **TS vs Zig gap + wave schedule** |
| `TS_PARITY_REMAINING.md` | L2–L7 narrative + backlog + **§4 sign-off snapshot** + empty template |
| `TS_PARITY_99_CAP.md` | “~99.99%” achievable cap logic |
| `TS_PARITY_MIGRATION_PLAN.md` | Phases A–G (done) + **§6 phase H** + L-layer definitions |
| `MIGRATION_GAP.md` | Name stats, batch history, depth notes |

---

*Version: 2026-04-01 · Schedule is guidance; **H.1/H.4** batch **53**; L2 cache/HTTP env batches **55–57** (incl. pipeline **`fetch`**); sign-off one-pager **`TS_PARITY_REMAINING.md` §4**.*
