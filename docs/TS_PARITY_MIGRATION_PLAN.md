# TypeScript OpenCLI parity migration plan (revised)

> **Goal**: In **verifiable, phased** steps, approach upstream [**jackwener/opencli**](https://github.com/jackwener/opencli) (TypeScript / `@jackwener/opencli`) **behavior and engineering**, not only command names.  
> **Upstream**: **`docs/UPSTREAM_REFERENCE.md`**.  
> **Baseline ledger**: `docs/MIGRATION_GAP.md` (name alignment `missing=0` done; this doc focuses **deep equivalence** and remaining debt).

---

## 1. Acceptance layers (what “migration done” means)

| Layer | Meaning | Status |
|-------|---------|--------|
| **L0 naming** | `site/command` matches baseline | Done (see MIGRATION_GAP) |
| **L1 YAML pipeline** | `pipeline.steps` in user/plugin YAML parses and runs | Done |
| **L2 HTTP** | Public API, redirects, Cookie, cache vs TS | Ongoing per site; **sign-off** **`TS_PARITY_REMAINING.md` §4** (fixtures, **`fetchJson`/pipeline `fetch` cache**, **`OPENCLI_HTTP_*`**, etc.) |
| **L3 browser** | `browser: true` + CDP vs Playwright critical paths | Ongoing; architectures differ—use scenario matrix |
| **L4 auth** | Cookie/OAuth/private site APIs | Ongoing; many user-specific milestones |
| **L5 rich text** | Turndown-grade HTML→MD, image pipeline | External script + optional built-in (`OPENCLI_BUILTIN_HTML_TO_MD`); images still limited |
| **L6 plugins** | TS plugins / JS / hooks vs upstream | Done: QuickJS `js_init` + per-command `script` + `opencli.args`/`version`/`log`; can still narrow gaps vs full TS API |
| **L7 ops & AI** | Daemon, explore/generate, synthesize vs TS | Ongoing: contract/TCP/golden started (`daemon_*_test`, `ai_explore_golden_test`, `DAEMON_API.md`); extend vs TS |

**“Fully migrated”** = **L0–L7 pass signed matrices**; L4/L5 are capped by live sites and compliance—document + regression, not 100% online everywhere.

**Relation to “phases A–G all checked”**: **A–G** are §2 engineering items — **all done**.  
**Relation to “every TS behavior identical”**: continue **L2–L7**; tasks, backlog, sign-off template in **`docs/TS_PARITY_REMAINING.md`** (required reading).

---

## 2. Phases and deliverables

### Phase A — YAML and pipeline (P0, this repo first)

- [x] Parse YAML `pipeline` → `types.PipelineDef` (`type` / `step_type`, flat `config`).
- [x] Plugin `plugin.yaml` commands may carry `pipeline`, `args`, `columns` and register as executable.
- [x] User single-file commands (`~/.opencli/clis/<site>/<cmd>.yaml`) root `pipeline` works.
- [x] Pipeline executor: `fetch` + `extract`; `data` between steps; `transform` `operation: limit`; templates `args.<name>`.
- [x] `plugin` / `yaml` heap fields freed on `unregister` / `Registry.deinit`.

**Verify**: `zig build test`; manual `opencliz <site>/<cmd>` minimal YAML-only case.

### Phase B — Multi-command single file and manifest (P1)

- [x] Top-level `commands:` **map** or **array** like `examples/bilibili.yaml` (`discovery.loadYamlFile`; children inherit root `site`/`domain`/`strategy`/`browser`/`description`).
- [x] `cli-manifest.json` `type: ts`: register **`source=ts_legacy`**; default JSON stub (`status: ts_adapter_not_supported` + `message` + optional `modulePath`). **Optional**: **`OPENCLI_ENABLE_NODE_SUBPROCESS=1`** runs Node subprocess (**`docs/PLUGIN_QUICKJS.md`**, `runner.zig`); **no** embedded V8/Node in Zig.

### Phase C — Browser and desktop (P1)

- [x] Maintain `docs/CDP_SCENARIO_MATRIX.md` (weixin/zhihu/web/read/jd vs `adapter_browser.zig` + TS boundary).
- [x] Optional: minimal Zig CI — **`.github/workflows/zig-ci.yml`** (ubuntu/macos, `zig build test`, `ZIG_GLOBAL_CACHE_DIR` + actions/cache). **Chrome subset** still cross-checked with Node **`smoke-test`** and **`CDP_SCENARIO_MATRIX.md`**.

### Phase D — Auth and write paths (P2)

- [x] Document Cookie/site vars and structured `status`: `docs/AUTH_AND_WRITE_PATH.md`.
- [x] Per-site OAuth/device **decision sign-off** (2026-04-02): “no device code” matrix for bilibili/github/reddit/twitter. **Full OAuth automation** remains optional; see `AUTH_AND_WRITE_PATH.md` § OAuth. **Tasks**: `TS_PARITY_REMAINING.md` § L4 / §3.

### Phase E — Markdown and images (P2)

- [x] Document `OPENCLI_HTML_TO_MD_SCRIPT`, image switches, Turndown delta: `docs/MARKDOWN_ARTICLE_PIPELINE.md`.
- [x] Optional built-in HTML→MD (`OPENCLI_BUILTIN_HTML_TO_MD=1`, `html_to_md_simple.zig`; not full Turndown; lower priority than script; batch **60** inline+block—see **`MIGRATION_GAP.md`**).

### Phase F — Plugin JS runtime (P2)

- [x] Dependency **[mitchellh/zig-quickjs-ng](https://github.com/mitchellh/zig-quickjs-ng)** (`build.zig.zon` → `quickjs_ng`); optional `js_init` in `loadPlugin`; `src/plugin/quickjs_runtime.zig` + tests.
- [x] Per-command **`script`** (`plugin.yaml` → `Command.js_script_path`, before `pipeline`); inject **`opencli`** (`args`, `version`, **`log`→print**); **HTTP native bridge** iterated (see PLUGIN_QUICKJS).

### Phase G — Wrap-up and “migration done” sign-off (P3)

- [x] `opencliz list --tsv`: columns **site / name / source / pipeline / script**; `scripts/compare_opencli_list.sh` sorted lines without header; `OPENCLI_LIST_HEADER=1` adds header.
- [x] `docs/MIGRATION_GAP.md` batch 46 note; A–G items checked (site alignment still see L2–L5 “ongoing”).

---

## 3. Dependencies and risks

- **Live site changes**: versioned fixtures + optional live tests.
- **Zig std JSON**: `parseFromSliceLeaky` limits (MIGRATION_GAP batches 39/41).
- **TS has no single tag**: baseline from `src/clis` history or npm; record changes in MIGRATION_GAP.

---

## 4. Suggested order

1. Phase A (core code landed)  
2. Phase B  
3. Phases C–E (parallelize by team)  
4. Phases F–G  

---

## 5. What remains for “full TS capability”? (operational definition)

| If your goal is… | Status | Next step |
|------------------|--------|-----------|
| **Written plan A–G in this repo** | **Done** | Keep `zig build test` + docs |
| **Command names = baseline** | **`missing=0`** | `MIGRATION_GAP.md` |
| **HTTP/browser/login/article/Daemon deep match** | **L2–L7 ongoing** | **`TS_PARITY_REMAINING.md`** layers + matrices; cap checklist **`TS_PARITY_99_CAP.md`**; gap table **`TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md`** |

**Not promised in one shot** (sign off or waive in `TS_PARITY_REMAINING` / **`TS_PARITY_99_CAP` §4**): full-site OAuth, Playwright-level parity, full Turndown rules, credentialed writes everywhere, full Electron desktop match.

---

## 6. Latest plan (phase H: L2–L7 vs TS)

> **Phases A–G** closed (§2). Gaps vs TS use **layers L2–L7** + **four waves**; detail **`TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md`**, sign-off **`TS_PARITY_REMAINING.md` §4**, cap language **`TS_PARITY_99_CAP.md`**.

### 6.1 Snapshot

| Layer | vs TS | Planned action (summary) |
|-------|-------|---------------------------|
| **L2** | HTTP/cache/detail may differ | More fixtures, side-by-side JSON diff (batches **50–51, 53**; **`h_l2_ts_diff_suggestions.sh`** / **`compare_command_json.sh`** + **`OPENCLI_CACHE=0`**) |
| **L3** | Playwright ≠ CDP | Sign `CDP_SCENARIO_MATRIX.md`; **`zig-chrome-ci.yml`** minimal CI (batch **52**: `web/read` + `zhihu/download`) |
| **L4** | OAuth/writes | Doc cap + sign-off (**`AUTH_AND_WRITE_PATH.md`** Wave 2.2); Cookie regression **`regression_cookie_writepath.sh`** (batch **52**) |
| **L5** | Turndown/media | External script first; **`MARKDOWN_ARTICLE_PIPELINE.md`** § **H.4** (batch **53**) |
| **L6** | Full Node API | QuickJS subset + optional Node subprocess (timeouts, batch **52**); **`opencli.http`** bridge + allowlist (batch **52**) |
| **L7** | Daemon/explore | **`DAEMON_API.md`** test index + L7 sign-off; **`explore_edge_min`** golden (batch **53**); extend vs TS endpoints |

### 6.2 Suggested waves (same as `TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md` §3)

| Wave | Suggested cadence | Theme |
|------|-------------------|-------|
| **H.1** | Ongoing | L2 P0: fixtures, JSON diff, cache/redirect notes |
| **H.2** | ~2–4 weeks | L3/L4 P1: CDP matrix sign-off, L4 OAuth or written “no device”—**batch 52 closed** |
| **H.3** | ~1–2 months | L3/L6 P2: Chrome CI subset, QuickJS HTTP bridge, Node subprocess hardening — **batch 52 closed** |
| **H.4** | Ongoing | L5/L7 P3: article/images/Daemon/explore UX—not rule-level 100% |

**Explicit exclusions** (not mandatory): full-site OAuth, Playwright↔CDP API parity, credentialed writes everywhere, full Electron—see **`TS_PARITY_99_CAP.md` §4**.

---

*Doc version: 2026-04-02 · A–G closed; **H.2/H.3 (waves 2–3) batch 52 closed** in `MIGRATION_GAP.md`; **H.1/H.4** ongoing; detail in `TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md`.*
