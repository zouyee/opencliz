# OpenCLI

> **High-performance CLI tool written in Zig** — Make any website your CLI. Single binary, zero dependencies.

[![Version](https://img.shields.io/badge/version-2.2.0-blue.svg)](https://github.com/jackwener/opencli)
[![Zig](https://img.shields.io/badge/zig-0.15.x-orange.svg)](https://ziglang.org/)
[![License](https://img.shields.io/badge/license-Apache%202.0-green.svg)](LICENSE)

---

## Why OpenCLI?

**Tired of waiting for CLI tools to start? You'll love OpenCLI.**

| Metric | Node.js Tools | OpenCLI |
|--------|--------------|---------|
| Cold startup | 500ms | **3ms** |
| Memory usage | 150MB | **1.6MB** |
| Binary size | 50MB+ | **3.5MB** |
| Dependencies | 100+ packages | **Zero** |

**If you answer yes to any of these, OpenCLI is for you:**

- 😤 "My CLI takes 500ms just to start—annoying!"
- 📦 "I need to deploy this to 100 servers but Node.js isn't installed"
- 💾 "This tool eats 150MB RAM just to run a simple query"
- 🚀 "I want to query Bilibili, GitHub, and HackerNews in milliseconds"
- 🐍 "I need something lightweight that runs on my Raspberry Pi"

### Parity with the official TypeScript OpenCLI

This Zig port tracks behavior and command coverage against [**jackwener/opencli**](https://github.com/jackwener/opencli) (npm `@jackwener/opencli`). **Authoritative English summary**: **`docs/CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md`** (what works here, extension-free CDP path, env vars, and major upstream differences). Baseline definition: **`docs/UPSTREAM_REFERENCE.md`**. Task status: **`docs/PARITY_PROGRESS.md`**. Full doc index: **`docs/README.md`**.

---

## Quick Start

```bash
# Build
zig build

# Run built-in commands
./zig-out/bin/opencli list                    # List all commands
./zig-out/bin/opencli bilibili/hot --limit 5  # Trending videos
./zig-out/bin/opencli github/trending --language rust
./zig-out/bin/opencli hackernews/top --limit 3
./zig-out/bin/opencli npm/search --query zig

# Run external CLI tools (gh, docker, etc.)
./zig-out/bin/opencli external/gh pr list     # GitHub PRs
./zig-out/bin/opencli external/docker ps      # Docker containers

# Different output formats
./zig-out/bin/opencli bilibili/hot -f json    # JSON output
./zig-out/bin/opencli bilibili/hot -f table   # Table (default)
```

---

## ✨ Features

- **20+ Website Adapters** — Bilibili, GitHub, Twitter, Zhihu, YouTube, Reddit, HackerNews, StackOverflow, NPM, V2EX, and more
- **354 Commands** — Covering videos, code, social media, knowledge bases, and more
- **External CLI Integration** — Run any CLI tool (gh, docker, etc.) through opencli with unified output formatting
- **AI-Powered Discovery** — Automatic API discovery (--explore, --generate)
- **Browser automation (no Chrome extension)** — CDP: local Chrome or **`OPENCLI_CDP_WEBSOCKET`** (e.g. Lightpanda); optional deepen with **`OPENCLI_USE_BROWSER=1`** (see **`docs/CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md`**)
- **Daemon Mode** — HTTP API server for remote execution
- **Single Binary** — No Node.js, no dependencies, just one 3.5MB file
- **Blazing Fast** — 3ms cold start, 1.6MB memory footprint

---

## 📊 Performance

| Metric | TypeScript Version | OpenCLI (Zig) | Improvement |
|--------|-------------------|----------------|-------------|
| Cold startup | 500ms | **3-4ms** | **125x faster** |
| Memory (idle) | 150MB | **1.6MB** | **94x less** |
| Binary size | 50MB+ | **3.5MB** | **14x smaller** |
| Debug build | 30s+ | **0.1s** | **300x faster** |
| Dependencies | 100+ | **0** | **Zero** |

---

## 🔧 Installation

### Build from source

From your checkout of **this** repository (Zig port):

```bash
zig build -Doptimize=ReleaseFast
./zig-out/bin/opencli --version
```

### Or use the build script

```bash
chmod +x build.sh
./build.sh build    # Build
./build.sh install  # Install to system
```

### Prerequisites

- **Zig** 0.15.x
- **C toolchain** to link [zig-quickjs-ng](https://github.com/mitchellh/zig-quickjs-ng) / QuickJS-ng at build time
- **Chrome** or **Chromium** (optional — for CDP browser automation or `OPENCLI_USE_BROWSER=1`)
- **Zig global cache**: if `~/.cache/zig` is not writable (some CI/sandboxes), set **`ZIG_GLOBAL_CACHE_DIR`** to a directory inside the repo; **`./build.sh`** defaults to **`./.zig-global-cache`** when unset (gitignored). Fetching git dependencies in `build.zig.zon` still needs network on first resolve.

---

## 🌐 Supported Websites

| Category | Sites |
|----------|-------|
| Video | Bilibili, YouTube |
| Code | GitHub, StackOverflow, HackerNews, NPM, PyPI, crates.io |
| Social | Twitter/X, Reddit, Weibo |
| Knowledge | Zhihu, StackOverflow |
| Products | Product Hunt |
| Entertainment | Douban |
| Academic | ArXiv, Unsplash, Weather, NewsAPI |

---

## 📦 For Server Deployment

**This is where OpenCLI shines:**

```bash
# Traditional Node.js tool
scp 50MB+heavy-package.tar.gz server:/opt/
ssh server "npm install && node tool.js"  # 2+ minutes

# OpenCLI
scp 3.5MB-opencli server:/usr/local/bin/
ssh server "opencli bilibili/hot"  # Instant
```

No Node.js runtime required. No package.json. No npm install. Just scp and run.

---

## 🛠️ Development

```bash
# Build
zig build

# Test
zig build test

# Run with args
zig build run -- bilibili/hot --limit 5

# Clean
rm -rf zig-out .zig-cache
```

### Parity and migration docs (vs TypeScript OpenCLI)

- **English capability & diff summary**: **`docs/CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md`**
- **Phases A–G** (YAML/pipeline, manifest, `ts_legacy`, CDP docs, auth/Markdown, QuickJS, `list --tsv`, Zig CI, etc.): **`docs/TS_PARITY_MIGRATION_PLAN.md`** — phase checklist **completed**
- **Phase H (L2–L7)**: same file **§6**; schedule **`docs/TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md`**
- **Command-name baseline** (`missing=0`) and batch history: **`docs/MIGRATION_GAP.md`**
- **Remaining L2–L7 work**, cap, backlog: **`docs/TS_PARITY_REMAINING.md`**
- **Parity ceiling & exclusions**: **`docs/TS_PARITY_99_CAP.md`**

---

## 🙏 Acknowledgments

- **[Zig Language](https://ziglang.org/)** — The programming language powering this project
- **[zig-clap](https://github.com/Hejsil/zig-clap)** — Command-line argument parsing
- **[Original TypeScript OpenCLI](https://github.com/jackwener/opencli)** — This project was inspired by and built upon the original TypeScript version. We are grateful to the original authors and contributors for establishing the vision of "make any website your CLI."
- All contributors and supporters

---

## 📄 License

Apache License 2.0 — see [LICENSE](LICENSE) file.

---

**Made with ❤️ and Zig**

*Version 2.2.0 | 2026-04-01*
