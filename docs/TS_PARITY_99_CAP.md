# “~99.99% parity with TS”: definition, plan mapping, and achievable cap

> This turns informal **“align with TS as much as possible”** into **testable** wording. **TS** means upstream [**jackwener/opencli**](https://github.com/jackwener/opencli) (**`docs/UPSTREAM_REFERENCE.md`**). Maps to **`TS_PARITY_MIGRATION_PLAN.md`** (phases A–G) and **`TS_PARITY_REMAINING.md`** (L2–L7).  
> **Important**: **99.9999%** is not a computable ratio; below we use **achievable cap**: the boundary this repo can still approach **without** embedding **Node.js** (optional **Bun** subprocess only for `ts_legacy`; see **`RUNTIME_MODEL.md`**), **without** promising every site online, **without** holding user secrets.

---

## 1. Do not conflate three “migration complete” notions

| Definition | Meaning | Status |
|------------|---------|--------|
| **A–G written delivery** | Checkboxes in migration plan §2 | ✅ **All done** |
| **L0 baseline naming** | `site/command` vs historical `src/clis` stats `missing=0` | ✅ **Done** |
| **L2–L7 deep equivalence** | HTTP/browser/login/article/plugin/daemon vs TS within **signed matrices** | ⚠️ **Ongoing**; some items **cannot cap** (§4) |

**If your goal is “plan migration complete”** → **met**.  
**If your goal is “TS product behavior almost identical on every site, account, and DOM path”** → **no finite schedule**; approach the **achievable cap** via **§3 checklist + signed matrices**.

---

## 2. Implemented capabilities (≈ high-weight alignment)

Items below have **code + tests or docs** in-repo, mapping to TS “main path” chunks:

- **L0/L1**: Command registration, YAML `pipeline`, multi-command single file, `ts_legacy` stub policy (phases A/B).
- **L2 (partial)**: HTTP adapters, `status` semantics, fixture JSON + **`compare_command_json.sh`**; adapter **`fetchJson`** JSON in-memory cache (**`OPENCLI_CACHE=0`** off, **`hnTopStories`** same path, batch **56**); YAML **`pipeline` `fetch` (GET)** same cache (batch **57**); curl **`OPENCLI_HTTP_*`** (batch **55**); TS convergence via side-by-side diff.
- **L3 (partial)**: CDP path + **`CDP_SCENARIO_MATRIX.md`** (not Playwright-equivalent; matrix sign-off only).
- **L4 (mechanism)**: Cookie/site vars, structured `status` (**not** built-in OAuth everywhere).
- **L5 (mechanism)**: `OPENCLI_HTML_TO_MD_SCRIPT`, optional `OPENCLI_BUILTIN_HTML_TO_MD`, limited image switches (**`MARKDOWN_ARTICLE_PIPELINE.md`**).
- **L6 (subset)**: QuickJS `js_init`, `script`, `opencli.args`/`version`/`log`; **`opencli.http`** **GET** / **POST** / **HEAD** (batch **58**) + **`error` table / `http_error`** (batch **63**, **`opencli_plugin_api_version` 0.2.3**; **not** full Node API).
- **L7 (subset)**: `serve`, three auth modes, POST JSON, `daemon_*_test` + `ai_explore_golden_test` (**`DAEMON_API.md`**).

---

## 3. Work still needed for the achievable cap (priority order)

Ordered list to **increase TS similarity**; tick **`TS_PARITY_REMAINING.md` §4** when done.

### P0 — Regression guard, automation

| # | Work | Layer | Acceptance |
|---|------|-------|------------|
| 3.1 | Extend `tests/fixtures/json/` + `fixture_json_test` for high-traffic response shapes | L2 | `zig build test` |
| 3.2 | Run **`scripts/l2_p0_routine.sh`** or **`compare_command_json.sh --diff-ts`** vs TS same-args `jq -S` diff (GitHub: **`L2 JSON parity (P0 dispatch)`** manual workflow) | L2 | Record baseline commit |
| 3.3 | Document cache key/TTL vs TS deltas in `MIGRATION_GAP` or site issues | L2 | Doc / batch id |

### P1 — Matrix and auth “cap”

| # | Work | Layer | Acceptance |
|---|------|-------|------------|
| 3.4 | Sign **`CDP_SCENARIO_MATRIX.md`** per scenario (Zig CDP vs TS Playwright boundary) | L3 | Matrix all checked or explicit “won’t do” |
| 3.5 | **L4**: 1–2 hot sites—either minimal OAuth/device or document in **`AUTH_AND_WRITE_PATH.md`** “no device code / Cookie only” and sign | L4 | **Done**: Wave 2.2 + **§ P1 site matrix** (batch **62**); device code still out |
| 3.6 | Write paths: credentialed regression aligned with **`AUTH_AND_WRITE_PATH.md`** (may skip CI) | L4 | **`scripts/regression_cookie_writepath.sh`** + matrix Reddit/Bilibili/V2EX, etc. |

### P2 — Architectural increments (high cost)

| # | Work | Layer | Acceptance |
|---|------|-------|------------|
| 3.7 | Zig + Chrome CI subset (matrix scenarios + optional weekly schedule) | L3 | **`zig-chrome-ci.yml`** green (batch **63**: five scenarios + Wed cron) |
| 3.8 | QuickJS **`opencli` HTTP** native bridge (allowlist, timeout, error mapping) | L6 | Security review + tests |
| 3.9 | If **`type: ts` must run**: **Bun subprocess** (`OPENCLI_ENABLE_BUN_SUBPROCESS=1`, implemented; **not** Node) | L6 | Coexistence with `ts_legacy` policy documented |

> **Batch 52**: **3.7** (`zig-chrome-ci.yml`: `web/read` + `zhihu/download`), **3.8** (QuickJS **`__opencli_http_*`** + allowlist/timeout tests) delivered; **3.9** adds **`OPENCLI_BUN_SUBPROCESS_TIMEOUT_MS`** / **`OPENCLI_BUN_MAX_OUTPUT_BYTES`** (**`PLUGIN_QUICKJS.md`**; Bun replaces Node). **Batch 63** extends **3.7** (**sinablog/article**, **jd/item**, weekly schedule) and **L6 `error` table**.

### P3 — UX alignment (not full feature parity)

| # | Work | Layer | Acceptance |
|---|------|-------|------------|
| 3.10 | Turndown-level rules: still rely on **`OPENCLI_HTML_TO_MD_SCRIPT`**; built-in simplified only (batch **60** extended common inline + in-block flow, still not Turndown) | L5 | No rule-by-rule parity promised |
| 3.11 | Image pipeline: extend switches per **`MARKDOWN_ARTICLE_PIPELINE.md`** | L5 | Document TS deltas |

> **Batch 53 (H.1/H.4)**: **3.1** extends L2 fixtures + diff scripts; **3.10–3.11** add **H.4** table in **`MARKDOWN_ARTICLE_PIPELINE.md`**; L7 see **`DAEMON_API.md`** and **`explore_edge_min`** golden.

---

## 4. Explicitly outside the achievable cap (do not count toward %)

Do **not** promise “one more release → 99.9999%” for:

- Byte-identical responses across **all** sites, logins, and anti-bot strategies.
- Running arbitrary historical **TS adapters** in-process **without** a JS engine (except QuickJS plugin scripts or **`ts_legacy`** stub / **Bun** subprocess — **not** Node).
- **Playwright option-level** vs **CDP** API equivalence.
- Full write paths and **every vendor OAuth device flow** without user credentials.
- **100%** match vs TS **Electron/desktop** apps (local env + legal bounds).

---

## 5. “Migration complete” under your chosen goal

| Your goal | Can you call it “done”? |
|-----------|-------------------------|
| Phases **A–G** + **missing=0** | ✅ **Yes** (achieved) |
| All checkable §3 items + §4 signed matrices | **Achievable cap**; “99.99%” is team wording |
| Every TS **online** behavior identical | ❌ **No** (§4) |

---

## 6. Doc index

| Doc | Role |
|-----|------|
| [TS_PARITY_MIGRATION_PLAN.md](./TS_PARITY_MIGRATION_PLAN.md) | Phases A–G + L0–L7 master table |
| [TS_PARITY_REMAINING.md](./TS_PARITY_REMAINING.md) | L2–L7 remaining + backlog + sign-off template |
| [MIGRATION_GAP.md](./MIGRATION_GAP.md) | Naming, batches, depth bounds |
| [CDP_SCENARIO_MATRIX.md](./CDP_SCENARIO_MATRIX.md) | L3 |
| [AUTH_AND_WRITE_PATH.md](./AUTH_AND_WRITE_PATH.md) | L4 |
| [MARKDOWN_ARTICLE_PIPELINE.md](./MARKDOWN_ARTICLE_PIPELINE.md) | L5 |
| [PLUGIN_QUICKJS.md](./PLUGIN_QUICKJS.md) | L6 |
| [DAEMON_API.md](./DAEMON_API.md) | L7 |
| [TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md](./TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md) | TS vs Zig **gap table + wave schedule** |

---

*Version: 2026-04-01 · Aligned with **`TS_PARITY_REMAINING`**: plan A–G closed; “TS deep equivalence” = ongoing §3 + explicit §4 cap; **L2–L7 sign-off snapshot** in **`TS_PARITY_REMAINING.md` §4**. Gaps and schedule: **`TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md`**.*
