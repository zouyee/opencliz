# Documentation index (opencliz / Zig OpenCLI)

**Architecture / 设计方案:** **`ARCHITECTURE.md`** — **Zig + Bun + QuickJS**; **our implementation does not require Node.js** (see also **`RUNTIME_MODEL.md`**).

Start with **`CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md`** for **supported features** and **differences from the TypeScript [jackwener/opencli](https://github.com/jackwener/opencli)**.

| Topic | Document |
|--------|----------|
| **Architecture & design (Zig · Bun · QuickJS; no Node)** | **`ARCHITECTURE.md`** |
| **Capability migration map (L0–L7 diagram + backlog)** | **`CAPABILITY_MIGRATION_MAP.md`** |
| **Runtime model (detail)** | **`RUNTIME_MODEL.md`** |
| Upstream baseline | **`UPSTREAM_REFERENCE.md`** |
| Parity progress (P0–P4) | **`PARITY_PROGRESS.md`** |
| CDP browser deepen matrix | **`CDP_SCENARIO_MATRIX.md`** |
| Remote Chrome / Lightpanda / `OPENCLI_CDP_WEBSOCKET` | **`advanced/cdp.md`** |
| Article & Markdown pipeline | **`MARKDOWN_ARTICLE_PIPELINE.md`** |
| Daemon HTTP API | **`DAEMON_API.md`** |
| QuickJS plugins | **`PLUGIN_QUICKJS.md`** |
| Auth & write paths | **`AUTH_AND_WRITE_PATH.md`** |
| Migration / command stats | **`MIGRATION_GAP.md`** |
| Gap schedule | **`TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md`** |
| Parity ceiling & exclusions | **`TS_PARITY_99_CAP.md`** |
| Adapter list (site docs) | **`adapters/index.md`** |
| Browser prereqs (Zig vs upstream) | **`adapters/BROWSER_PREREQUISITES.md`** |

Command-line help: `opencliz --help`, `opencliz list`.
