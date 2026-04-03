# Upstream baseline: jackwener/opencli

Unless stated otherwise, **“upstream”**, **“TS OpenCLI”**, or **“original OpenCLI”** in this repository refers to:

| Item | Link / note |
|------|-------------|
| **GitHub** | [https://github.com/jackwener/opencli](https://github.com/jackwener/opencli) |
| **npm** | `@jackwener/opencli` (global CLI is often installed as `opencli`) |
| **Stack** | TypeScript / Node.js; browser side historically **Browser Bridge extension + local daemon** (contrast: this repo uses **CDP WebSocket** to Chrome or an external CDP server) |

**Full picture of current Zig capabilities and differences**: **`CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md`**.

---

## How this repo tracks parity with upstream

| Dimension | Approach |
|-----------|----------|
| **Command names / registry (L0)** | Target **`missing = 0`** vs legacy `src/clis` tree — **`MIGRATION_GAP.md`** |
| **JSON behavior (L2)** | **`scripts/compare_command_json.sh`**, **`scripts/l2_p0_routine.sh`**: same args as upstream **`opencli … -f json`**, diff with **`jq -S`** (use **`OPENCLI_CACHE=0`** when comparing) |
| **Browser deepen (L3)** | **Not** Playwright-level parity; signed matrix in **`CDP_SCENARIO_MATRIX.md`** + **`.github/workflows/zig-chrome-ci.yml`** |
| **Version pin** | When recording baselines, note upstream **npm version or git SHA** in **`MIGRATION_GAP.md`** batches or issues |

---

## Upstream features vs this Zig port (short)

High-level only; details: **`CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md`**, **`TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md`**, **`TS_PARITY_99_CAP.md` §4**.

| Upstream capability | Zig port (summary) |
|--------------------|--------------------|
| Browser Bridge + extension login reuse | **`OPENCLI_USE_BROWSER=1`** + CDP; **no** extension store flow |
| `operate`-style AI browser control | **Not** replicated as a first-class TS-equivalent |
| Daemon + extension “one experience” | **`opencli serve`**: REST subset — **`DAEMON_API.md`** |
| CLI Hub / `register` / auto-install | **`external/`**, **`external-clis.yaml`** — compare case-by-case |
| Sysexits-style exit codes | Prefer JSON **`status`**; exit codes may differ |
| Plugin marketplace / Node plugins | **QuickJS** + **`plugin.yaml`** — **`PLUGIN_QUICKJS.md`** |
| Large adapter set + desktop | Broad registry; depth per **`AUTH_AND_WRITE_PATH.md`** |

---

## Related docs

| Doc | Purpose |
|-----|---------|
| **`CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md`** | **Start here** for supported features vs upstream |
| **`MIGRATION_GAP.md`** | Naming stats, batch history |
| **`PARITY_PROGRESS.md`** | P0–P4 task status |
| **`TS_PARITY_REMAINING.md`** | L2–L7 remaining work |
| **`TS_PARITY_MIGRATION_PLAN.md`** | Phases A–G (completed) + §6 H-layer pointer |
| **`TS_PARITY_99_CAP.md`** | Parity ceiling and exclusions |
| **`TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md`** | Gap table and schedule |

---

*If the upstream repo moves or is renamed, update this page and add a note batch in **`MIGRATION_GAP.md`**.*
