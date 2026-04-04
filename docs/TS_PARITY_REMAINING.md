# Remaining work toward TypeScript “full capability” parity (and explicit caps)

> **English — what the Zig port supports today:** **`docs/CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md`**.

> **Upstream**: [**jackwener/opencli**](https://github.com/jackwener/opencli) (**`docs/UPSTREAM_REFERENCE.md`**).  
> Read with **`docs/TS_PARITY_MIGRATION_PLAN.md`** (phases A–G **+ §6 phase H**), **`docs/MIGRATION_GAP.md`** (`missing=0` and batch history).  
> **Bottom line**: Phases **A–G** promised in the migration plan are **all delivered** (see checkboxes there).  
> **Byte-identical** behavior on every request, login state, and DOM path vs TS is **not** a single milestone here; without shared user credentials, full-site online reproducibility **cannot** be guaranteed. Further work follows **L2–L7 layers + sign-off matrices**; this doc lists **actionable tasks** and **cap language**.  
> For a checkable “~99.99%” list, see **`docs/TS_PARITY_99_CAP.md`**.

---

## 1. Two meanings of “migration done”

| Meaning | Status | Basis |
|---------|--------|-------|
| **Plan delivery (A–G)** | ✅ Done | `TS_PARITY_MIGRATION_PLAN.md` §2 all checked |
| **Baseline command names** | ✅ `missing=0` | `MIGRATION_GAP.md` counting rules |
| **Product-deep equivalence (L0–L7 all green)** | Ongoing / partly uncapped | Real sites, accounts, OAuth, anti-bot, desktop apps, legal bounds |

---

## 2. Layered remaining work (vs `TS_PARITY_MIGRATION_PLAN` §1)

### L2 — HTTP

| Topic | Remaining | Cap / acceptance |
|-------|-----------|------------------|
| Public APIs, redirects, Cookie, cache | **In place**: adapter **`fetchJson`** in-process JSON cache (**`OPENCLI_CACHE=0`** off), **`hnTopStories`** list+item same cache (batch **56**); YAML **`pipeline` `fetch` GET** same cache (batch **57**); curl **`OPENCLI_HTTP_*`** (batch **55**). **Ongoing**: grow **`tests/fixtures/json/`**, **`h_l2_ts_diff_suggestions.sh`** / **`compare_command_json.sh`** vs TS **`jq -S`** (use **`OPENCLI_CACHE=0`** before diff) | Site redesign → structured **`status`** + **`MIGRATION_GAP`** batch notes; no promise of perpetual online parity |

### L3 — Browser (CDP vs Playwright)

| Topic | Remaining | Cap / acceptance |
|-------|-----------|------------------|
| `browser: true` critical paths | **`CDP_SCENARIO_MATRIX.md`** signed; **`zig-chrome-ci.yml`** (batch **63**) runs **web/read, zhihu/download, weixin/download, sinablog/article, jd/item** (some **`|| true`**) + optional **weekly schedule** | Architectures differ (Playwright ≠ CDP); only **matrix scenarios** count as equivalent |

### L4 — Auth and writes

| Topic | Remaining | Cap / acceptance |
|-------|-----------|------------------|
| Cookie / OAuth / private site APIs | OAuth **device code** explicitly out (**`AUTH_AND_WRITE_PATH.md`** Wave 2.2); manual write regression → **`scripts/regression_cookie_writepath.sh`** | Without user creds, **`login_required`**-style **status** is valid acceptance; **no** promise to replicate all TS private integrations |

### L5 — Rich text and images

| Topic | Remaining | Cap / acceptance |
|-------|-----------|------------------|
| Turndown-grade HTML→MD, full image pipeline | External script still preferred; **built-in simplifier** extended **inline + blocks** (batch **60**, **`MIGRATION_GAP.md`**); checklist **`MARKDOWN_ARTICLE_PIPELINE.md`** § **H.4** (batch **53**) | **No** Turndown rule-by-rule parity; **no** legacy full media pipe |

### L6 — Plugin runtime

| Topic | Remaining | Cap / acceptance |
|-------|-----------|------------------|
| TS plugins / full Node API | **Present**: **`opencli.http`** (**GET** / **POST** / **HEAD**; **`error`** table + **`http_error`** batch **63**; **`opencli_plugin_api_version` 0.2.3**); **Bun** subprocess timeout/output caps for `type: ts` (**`PLUGIN_QUICKJS.md`**) | **`ts_legacy`** stub is policy; full Node API **not** a goal |

### L7 — Ops and AI

| Topic | Remaining | Cap / acceptance |
|-------|-----------|------------------|
| Daemon, explore, generate, synthesize | **Present**: read timeout (batch **54**), optional **`/execute`** timeout (batch **55**); **`daemon_*_test`** (batch **62** + unknown command **404** batch **65**); **`DAEMON_API.md`**, **`explore_edge_min`** (batch **53**). **Explore / generate / synthesize**: **heuristic** scaffolding → **`adapter.yaml`** (**`README.md`**, **`CURRENT_CAPABILITIES` §2.9**); **no** bundled LLM; **not** **`operate`**-class parity. **Ongoing**: vs TS extra AI endpoints / model chains | WebSocket, batch execute → **`DAEMON_API.md`** “Zig vs TS” **N/A** |

---

## 3. Suggested backlog (split into issues)

| Priority | Item | Notes |
|----------|------|-------|
| P0 | L2: core public fixtures + JSON diff vs TS | **`scripts/l2_p0_routine.sh`**, **`record_jackwener_baseline.sh`** (upstream **`jq -S`**), **`compare_command_json.sh --diff-ts`**; **`docs/PARITY_PROGRESS.md`** **P0.4–P0.5**. CI: manual **`L2 JSON parity (P0 dispatch)`** |
| P1 | L4: OAuth or doc sign-off “no device code” for 1–2 hot sites | **Done**: **`AUTH_AND_WRITE_PATH.md`** **P1 site matrix** (with Wave 2.2 + CDP matrix); device code still **out** |
| P1 | L7: minimal daemon contract tests | **Extended (batch 62)**: **`X-OpenCLI-Token`**, bad Bearer, **OPTIONS** unauthenticated, unknown command **500**, TCP **`GET /`** / **401** / header auth; **`DAEMON_API.md`** updated; still compare TS WebSocket/batch piecemeal |
| P2 | L3: Zig + Chrome CI subset | **Extended (batch 63)**: **`zig-chrome-ci.yml`** — **`sinablog/article`**, **`jd/item`** + **`more_sites`/`chinese`/`http_exec`** triggers + **weekly schedule**; see **`CDP_SCENARIO_MATRIX.md`** |
| P2 | L6: QuickJS **`opencli.http`** | **Detailed (batch 63)**: **`PLUGIN_QUICKJS.md`** **`error`** table; **`http_error`** vs **`request_failed`**; **`opencli_plugin_api_version` 0.2.3** |

---

## 4. Sign-off matrix (repo snapshot · ongoing)

> **Purpose**: One checkable page for **L2–L7 + docs/tests** alongside §2. If TS has no single commit, **Baseline** = “this repo + doc anchors”. Update **Date** and **`MIGRATION_GAP.md`** batch when code changes.

| Layer | Scope (sites / scenarios) | Baseline | Sign | Date | Notes |
|-------|---------------------------|----------|------|------|-------|
| **L2** | Fixtures + **`l2_p0_routine.sh`** / **`record_jackwener_baseline.sh`** / **`compare_command_json.sh`** (**`--diff-ts`**); **`PARITY_PROGRESS.md`**; **`fetchJson` / `hnTopStories` / pipeline `fetch` (GET)** JSON cache (**`OPENCLI_CACHE=0`**); **`OPENCLI_HTTP_*`**; **`pipeline_fetch_cache_test`** mock (batch **59**); **`status`** + 列表形状 fixture（batch **67**) | **`MIGRATION_GAP`** batches 50–67; **`tests/fixtures/json/`** | ZZ | 2026-04-01 | Online drift → **`status`** + batch caps |
| **L3** | Matrix: weixin/web/zhihu/sinablog/jd + generic **N/A** | **`CDP_SCENARIO_MATRIX.md`**; **`zig-chrome-ci.yml`** (batch **63** five scenarios + weekly) | ZZ | 2026-04-01 | Playwright ↔ CDP **not** API-equivalent |
| **L4** | Cookie injection, write-path docs, OAuth decisions, **P1 site matrix** | **`AUTH_AND_WRITE_PATH.md`** Wave 2.2 + **§ P1 matrix**; **`regression_cookie_writepath.sh`** | ZZ | 2026-04-01 | No device code; deep private API **not** promised |
| **L5** | Article pipeline, H.4 checklist, built-in HTML→MD increment | **`MARKDOWN_ARTICLE_PIPELINE.md`** § H.4; **`html_to_md_simple`** (hr/table batch **55** + inline/block batch **60**) | ZZ | 2026-04-01 | **Not** Turndown rule-by-rule |
| **L6** | QuickJS `script`/`js_init`, **`opencli.http`** (incl. **HEAD**, **`error`** table batch **63**), Bun subprocess hardening (`ts_legacy`) | **`PLUGIN_QUICKJS.md`**; **`quickjs_runtime.zig`** tests | ZZ | 2026-04-01 | Full Node builtins **not** a goal |
| **L7** | Daemon contract + TCP e2e; read/execute timeouts; explore/synthesize golden; root **`version`** = **`version.zig`** | **`DAEMON_API.md`** (incl. L7 table; unknown **404** batch **65**); **`daemon_*_test`**, **`ai_explore_golden_test`** | ZZ | 2026-04-01 | WebSocket / batch **N/A** (see DAEMON_API) |

**Empty template** (new project or reset):

```
Layer | Scope | Baseline | Sign | Date | Notes
L2   |       |          |      |      |
L3   | see CDP_SCENARIO_MATRIX |  |      |      |
...
```

---

## 5. Doc index

| Doc | Role |
|-----|------|
| [TS_PARITY_MIGRATION_PLAN.md](./TS_PARITY_MIGRATION_PLAN.md) | Phases A–G and L0–L7 master table |
| [MIGRATION_GAP.md](./MIGRATION_GAP.md) | Name alignment, batch history, depth bounds |
| [CDP_SCENARIO_MATRIX.md](./CDP_SCENARIO_MATRIX.md) | L3 |
| [AUTH_AND_WRITE_PATH.md](./AUTH_AND_WRITE_PATH.md) | L4 |
| [MARKDOWN_ARTICLE_PIPELINE.md](./MARKDOWN_ARTICLE_PIPELINE.md) | L5 |
| [PLUGIN_QUICKJS.md](./PLUGIN_QUICKJS.md) | L6 |
| [CAPABILITY_MIGRATION_MAP.md](./CAPABILITY_MIGRATION_MAP.md) | **L0–L7 migration diagram** + exclusions + backlog |
| [ARCHITECTURE.md](./ARCHITECTURE.md) | **Design**: Zig + Bun + QuickJS; **no Node** in our implementation |
| [RUNTIME_MODEL.md](./RUNTIME_MODEL.md) | Runtime detail (paths, env vars) |
| [DAEMON_API.md](./DAEMON_API.md) | L7 |
| [TS_PARITY_99_CAP.md](./TS_PARITY_99_CAP.md) | “~99.99%” achievable cap, remaining checks, exclusions |
| [TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md](./TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md) | **TS vs Zig gap table + wave schedule** |
| [UPSTREAM_REFERENCE.md](./UPSTREAM_REFERENCE.md) | **Upstream baseline: jackwener/opencli** (npm, diff, capability map) |
| [PARITY_PROGRESS.md](./PARITY_PROGRESS.md) | **Parity progress** (P0–P4, baseline log, next steps) |

---

*Doc version: 2026-04-01 · Upstream baseline **`UPSTREAM_REFERENCE.md`**; progress **`PARITY_PROGRESS.md`**; plan A–G closed; L2–L7 **sign-off snapshot** §4; batches **`MIGRATION_GAP.md`** (incl. **55–67**); cap semantics **`TS_PARITY_99_CAP.md`**; migration view **`CAPABILITY_MIGRATION_MAP.md` §0** (~99%).*
