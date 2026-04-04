# opencliz

> **Zig implementation** of the “make any website your CLI” idea — **not** the npm [**OpenCLI**](https://github.com/jackwener/opencli) package. Binary name: **`opencliz`**. Config and env vars still use **`~/.opencli`** and **`OPENCLI_*`** for compatibility with upstream docs and adapters.

**Inspired by [OpenCLI](https://github.com/jackwener/opencli)** — huge thanks to [@jackwener](https://github.com/jackwener) and everyone who contributes to the upstream project for the product vision, adapter ecosystem, and years of iteration. **opencliz** would not exist in this shape without that work.

**Upstream reference** (TypeScript / Node.js distribution): [jackwener/opencli](https://github.com/jackwener/opencli) (`@jackwener/opencli`, command often `opencli`). **This repo** tracks that command surface where documented; see **`docs/CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md`**.

**Architecture (this repo):** **Zig + Bun + QuickJS** — **our implementation does not use Node.js** (single **Zig** binary, **QuickJS** for plugins, optional **Bun** for legacy **`type: ts`** and for docs/CI). **Design doc:** **`docs/ARCHITECTURE.md`** · **Runtime detail:** **`docs/RUNTIME_MODEL.md`**.

[![Version](https://img.shields.io/badge/version-v0.0.1-blue.svg)](https://github.com/zouyee/opencliz)
[![Zig](https://img.shields.io/badge/zig-0.15.x-orange.svg)](https://ziglang.org/)
[![License](https://img.shields.io/badge/license-Apache%202.0-green.svg)](LICENSE)

---

## Why opencliz?

**Tired of waiting for CLI tools to start? You'll love a native binary.**

Comparison baseline in the tables below is a **typical upstream install** of **`opencli`** (Node.js + npm dependency tree). **opencliz** itself does **not** ship or call Node.

| Metric | Typical upstream (`opencli` on Node) | **opencliz** | **Gain (approx.)** |
|--------|--------------------------------------|--------------|-------------------|
| Cold startup | ~200–500 ms | **~3–5 ms** | **~100×+ faster** (trivial CLI path; measure locally) |
| Memory (idle) | ~100–200 MB RSS | **~1–3 MB** | **~50–100× lower RSS** |
| Binary size | ~50 MB+ (runtime + app) | **~5–6 MB** (ReleaseFast; platform-dependent) | **~9–10× smaller** vs ~50 MB baseline |
| Runtime dependencies | 100+ npm packages + Node | **Zig stdlib + `build.zig.zon`** (e.g. QuickJS-ng), static link; **no `node_modules`** | **No Node/npm inside opencliz** |

**Command scenarios** (order-of-magnitude; **adapter wall time is usually network-bound**, so end-to-end speedup is smaller than startup alone):

| Scenario | Typical upstream (`opencli`) | **opencliz** (typical) | **Gain (approx.)** |
|----------|------------------------------|------------------------|-------------------|
| `--version` | ~200–500 ms cold | **<1 ms** | **~200–500×** (startup-dominated) |
| `list` | ~50–150 ms | **~1 ms** | **~50–150×** (startup + registry) |
| `bilibili/hot --limit 3` | cold start + ~100–500 ms HTTP | **~100–200 ms** total (example; CDN varies) | **Startup + RAM** win; wall clock often **similar** once HTTP dominates |
| `hackernews/top --limit 3` | cold start + API latency | **~1–3 s** (example; API-bound) | Mostly **memory / deploy** win |

See **`PERFORMANCE_REPORT.md`** for methodology and how to reproduce timings.

**If you answer yes to any of these, opencliz is for you:**

- 😤 "My CLI takes hundreds of ms just to start—annoying!"
- 📦 "I want a single binary on servers—**no Node.js** in the hot path"
- 💾 "This tool eats 100+ MB RAM just to run a simple query"
- 🚀 "I want to query Bilibili, GitHub, and HackerNews with minimal startup overhead"
- 🐍 "I need something lightweight that runs on my Raspberry Pi"

### Parity with the official TypeScript OpenCLI

This Zig port tracks behavior and command coverage against [**jackwener/opencli**](https://github.com/jackwener/opencli) (npm `@jackwener/opencli`). **Authoritative English summary**: **`docs/CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md`**. Baseline definition: **`docs/UPSTREAM_REFERENCE.md`**. Task status: **`docs/PARITY_PROGRESS.md`**. Full doc index: **`docs/README.md`**.

---

## Runtime model (Zig · QuickJS · Bun)

| Layer | Role |
|-------|------|
| **Zig binary** | All built-in adapters, YAML pipelines, HTTP, CDP glue, daemon, CLI. |
| **QuickJS** | **`plugin.yaml`** `script` / `js_init`; global **`opencli`** (+ optional **`opencli.http`**). **Not** Node. |
| **Bun (optional)** | **`OPENCLI_ENABLE_BUN_SUBPROCESS=1`** → run legacy **`type: ts`** (`ts_legacy`) as **`bun <modulePath>`**. **Node is not used.** |

Details, env vars, and migration from the old Node subprocess: **`docs/RUNTIME_MODEL.md`** and **`docs/PLUGIN_QUICKJS.md`**.

---

## Quick Start

```bash
# Build
zig build

# Run built-in commands (binary is opencliz, not opencli)
./zig-out/bin/opencliz list
./zig-out/bin/opencliz bilibili/hot --limit 5
./zig-out/bin/opencliz github/trending --language rust
./zig-out/bin/opencliz hackernews/top --limit 3
./zig-out/bin/opencliz npm/search --query zig

# External CLI tools (gh, docker, etc.)
./zig-out/bin/opencliz external/gh pr list
./zig-out/bin/opencliz external/docker ps

# Output formats
./zig-out/bin/opencliz bilibili/hot -f json
./zig-out/bin/opencliz bilibili/hot -f table

# Explore → draft adapter.yaml (heuristic; see Features + docs/CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md §2.9)
./zig-out/bin/opencliz --explore https://example.com --explore-out ./ex.json
./zig-out/bin/opencliz synthesize --explore ./ex.json --site mysite
# Or one step: ./zig-out/bin/opencliz --generate https://api.example.com --site mysite
```

---

## ✨ Features

- **Broad adapter coverage** — Bilibili, GitHub, Twitter, Zhihu, YouTube, Reddit, HackerNews, StackOverflow, NPM (registry site), V2EX, and more (`opencliz list` for the live set)
- **Many commands** — same `site/command` style as upstream where aligned
- **External CLI integration** — Run tools like `gh`, `docker` through **opencliz** with unified formatting
- **Explore → adapter scaffolding** — **`--explore <url>`** (JSON: title, guessed endpoints, storage hints), **`--generate <url> --site <name>`** and **`synthesize --explore <file>`** → **`~/.opencli/clis/<site>/adapter.yaml`**. **Heuristic + HTTP** (no bundled LLM); **not** upstream **`operate`** / full AI browser control — **`docs/CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md`** §2.9
- **Browser automation (no Chrome extension)** — CDP + optional **`OPENCLI_USE_BROWSER=1`**, **`OPENCLI_CDP_WEBSOCKET`** (see **`docs/CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md`**)
- **Daemon** — `opencliz serve` (see **`docs/DAEMON_API.md`**)
- **No Node in opencliz** — Optional **Bun** only for legacy **`type: ts`**; plugins use **QuickJS** (**`docs/PLUGIN_QUICKJS.md`**)

---

## 📊 Performance

Headline metrics and **command scenarios** are in **[Why opencliz?](#why-opencliz)** above; they follow **`PERFORMANCE_REPORT.md`** §1 (cold start **~3–5 ms**, idle RSS **~1–3 MB**, binary **~5–6 MB**, and order-of-magnitude gains).

For build-loop vs upstream **`npm install` + `tsc`**, RSS on **`list`** / HTTP-heavy paths, and reproduction steps, see **`PERFORMANCE_REPORT.md`**.

---

## 🔧 Installation

### Build from source

```bash
zig build -Doptimize=ReleaseFast
./zig-out/bin/opencliz --version
```

### Or use the build script

```bash
chmod +x build.sh
./build.sh build
./build.sh install
```

### Prerequisites

- **Zig** 0.15.x (see **`build.zig.zon`** `minimum_zig_version`)
- **C toolchain** for [zig-quickjs-ng](https://github.com/mitchellh/zig-quickjs-ng) / QuickJS-ng
- **Chrome** or **Chromium** (optional — CDP / `OPENCLI_USE_BROWSER=1`)
- **Bun** (optional — only if you use **`OPENCLI_ENABLE_BUN_SUBPROCESS=1`** for **`type: ts`**)
- **Zig global cache**: set **`ZIG_GLOBAL_CACHE_DIR`** if needed; **`./build.sh`** defaults to **`./.zig-global-cache`**

---

## 🌐 Supported Websites

See **`docs/adapters/index.md`** and `opencliz list`. Categories include video, code, social, knowledge bases, and more.

---

## 📦 For Server Deployment

```bash
scp zig-out/bin/opencliz server:/usr/local/bin/
ssh server "opencliz bilibili/hot --limit 3"
```

**opencliz** on the server: **copy the binary only** — no Node.js, no npm install. Add **Bun** only if you rely on **`ts_legacy`** with **`OPENCLI_ENABLE_BUN_SUBPROCESS=1`**.

---

## 🛠️ Development

```bash
zig build
zig build test
zig build run -- bilibili/hot --limit 5
rm -rf zig-out .zig-cache
```

### Design and parity docs (vs TypeScript OpenCLI)

- **`docs/ARCHITECTURE.md`** — **设计方案**: Zig + Bun + QuickJS; **no Node in our implementation**
- **`docs/RUNTIME_MODEL.md`** — Runtime paths, env vars, subprocess policy (companion to **`ARCHITECTURE.md`**)
- **`docs/CAPABILITY_MIGRATION_MAP.md`** — L0–L7 与上游 OpenCLI 的能力迁移图与剩余 backlog
- **`docs/CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md`**
- **`docs/TS_PARITY_MIGRATION_PLAN.md`**, **`docs/PARITY_PROGRESS.md`**, **`docs/MIGRATION_GAP.md`**
- **`docs/TS_PARITY_REMAINING.md`**, **`docs/TS_PARITY_99_CAP.md`**

---

## 🙏 Acknowledgments

- **[OpenCLI](https://github.com/jackwener/opencli)** ([jackwener](https://github.com/jackwener) et al.) — **opencliz** is inspired by and aligned with this project where documented; we are grateful for the original idea, CLI design, and community.
- **[Zig](https://ziglang.org/)** — language and toolchain for a small, fast native binary.
- All contributors and users of both **OpenCLI** and **opencliz**.

---

## 📄 License

Apache License 2.0 — see [LICENSE](LICENSE).

---

**Made with Zig**

*opencliz v0.0.1 | `src/core/version.zig`*
