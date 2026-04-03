# opencliz

> **Zig implementation** of the “make any website your CLI” idea — **not** the npm [**OpenCLI**](https://github.com/jackwener/opencli) package. Binary name: **`opencliz`**. Config and env vars still use **`~/.opencli`** and **`OPENCLI_*`** for compatibility with upstream docs and adapters.

**Inspired by [OpenCLI](https://github.com/jackwener/opencli)** — huge thanks to [@jackwener](https://github.com/jackwener) and everyone who contributes to the upstream project for the product vision, adapter ecosystem, and years of iteration. **opencliz** would not exist in this shape without that work.

**Upstream reference** (TypeScript / Node): [jackwener/opencli](https://github.com/jackwener/opencli) (`@jackwener/opencli`, command often `opencli`). **This repo** tracks that command surface where documented; see **`docs/CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md`**.

[![Version](https://img.shields.io/badge/version-v0.0.1-blue.svg)](https://github.com/zouyee/opencliz)
[![Zig](https://img.shields.io/badge/zig-0.15.x-orange.svg)](https://ziglang.org/)
[![License](https://img.shields.io/badge/license-Apache%202.0-green.svg)](LICENSE)

---

## Why opencliz?

**Tired of waiting for CLI tools to start? You'll love a native binary.**

| Metric | Node.js tools (typical) | **opencliz** | **Gain (approx.)** |
|--------|-------------------------|--------------|-------------------|
| Cold startup | ~500ms | **~3ms** | **~100×+ faster** (process only; measure locally) |
| Memory (idle) | ~150MB | **~1.6MB** | **~100× lower RSS** |
| Binary size | 50MB+ (runtime + app) | **~5–6MB** (ReleaseFast; platform-dependent) | **~9–10× smaller** vs ~50MB baseline |
| Runtime dependencies | 100+ npm packages + Node | **No `node_modules`**; Zig stdlib + `build.zig.zon` (e.g. QuickJS-ng), static link | **No Node/npm at run time** |

**Command scenarios** (order-of-magnitude; **adapter wall time is usually network-bound**, so end-to-end speedup is smaller than startup alone):

| Scenario | Node / `opencli` (typical) | **opencliz** (typical) | **Gain (approx.)** |
|----------|----------------------------|------------------------|-------------------|
| `--version` | ~200–500ms cold | **<1ms** | **~200–500×** (startup-dominated) |
| `list` | ~50–150ms | **~1ms** | **~50–150×** (startup + registry) |
| `bilibili/hot --limit 3` | startup + ~100–500ms HTTP | **~100–200ms** total (example; CDN varies) | **Startup + RAM** win; wall clock often **similar** once HTTP dominates |
| `hackernews/top --limit 3` | startup + API latency | **~1–3s** (example; Firebase/API bound) | Mostly **memory / deploy** win |

See **`PERFORMANCE_REPORT.md`** for methodology and how to reproduce timings.

**If you answer yes to any of these, opencliz is for you:**

- 😤 "My CLI takes 500ms just to start—annoying!"
- 📦 "I need to deploy this to 100 servers but Node.js isn't installed"
- 💾 "This tool eats 150MB RAM just to run a simple query"
- 🚀 "I want to query Bilibili, GitHub, and HackerNews in milliseconds"
- 🐍 "I need something lightweight that runs on my Raspberry Pi"

### Parity with the official TypeScript OpenCLI

This Zig port tracks behavior and command coverage against [**jackwener/opencli**](https://github.com/jackwener/opencli) (npm `@jackwener/opencli`). **Authoritative English summary**: **`docs/CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md`**. Baseline definition: **`docs/UPSTREAM_REFERENCE.md`**. Task status: **`docs/PARITY_PROGRESS.md`**. Full doc index: **`docs/README.md`**.

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
```

---

## ✨ Features

- **Broad adapter coverage** — Bilibili, GitHub, Twitter, Zhihu, YouTube, Reddit, HackerNews, StackOverflow, NPM, V2EX, and more (`opencliz list` for the live set)
- **Many commands** — same `site/command` style as upstream where aligned
- **External CLI integration** — Run tools like `gh`, `docker` through **opencliz** with unified formatting
- **AI discovery** — `--explore`, `--generate`, etc.
- **Browser automation (no Chrome extension)** — CDP + optional **`OPENCLI_USE_BROWSER=1`**, **`OPENCLI_CDP_WEBSOCKET`** (see **`docs/CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md`**)
- **Daemon** — `opencliz serve` (see **`docs/DAEMON_API.md`**)
- **Single binary** — No Node.js at runtime
- **QuickJS plugins** — In-plugin global object is still named **`opencli`** for script compatibility (see **`docs/PLUGIN_QUICKJS.md`**)

---

## 📊 Performance

| Metric | TypeScript OpenCLI | **opencliz** | **Gain (approx.)** |
|--------|-------------------|-------------|-------------------|
| Cold startup | ~500ms class | **~3–4ms** class | **~100×+ faster** |
| Memory (idle) | ~150MB class | **~1–2MB** class | **~75–100× lower** |
| Binary size | 50MB+ with runtime | **~5–6MB** | **~9–10× smaller** vs ~50MB baseline |

Same **command scenarios** table as in [Why opencliz?](#why-opencliz) above; full notes in **`PERFORMANCE_REPORT.md`**.

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

- **Zig** 0.15.x
- **C toolchain** for [zig-quickjs-ng](https://github.com/mitchellh/zig-quickjs-ng) / QuickJS-ng
- **Chrome** or **Chromium** (optional — CDP / `OPENCLI_USE_BROWSER=1`)
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

No Node.js on the server.

---

## 🛠️ Development

```bash
zig build
zig build test
zig build run -- bilibili/hot --limit 5
rm -rf zig-out .zig-cache
```

### Parity and migration docs (vs TypeScript OpenCLI)

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
