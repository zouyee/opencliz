# Performance report: TypeScript upstream vs Zig port (`opencliz`)

**Date:** 2026-04-01  
**Scope:** Qualitative and order-of-magnitude comparison between a typical **Node.js / TypeScript** distribution of [jackwener/opencli](https://github.com/jackwener/opencli) and this repository’s **Zig** binary **`opencliz`**. Numbers below mix **published benchmarks**, **one-off local measurements**, and **rounded estimates**—use them for planning, not as SLAs.

**Dimensions:** build time · artifact size · cold start · memory · dependency surface

**opencliz runtime (this repo):** the **Zig** binary does **not** invoke **Node.js**. Plugins use embedded **QuickJS**; legacy **`type: ts`** may run under optional **Bun** (`OPENCLI_ENABLE_BUN_SUBPROCESS=1`). The **Node/npm** column in the tables below describes a **typical upstream `opencli`** install, not opencliz internals — see **`docs/RUNTIME_MODEL.md`**.

---

## 1. Headline metrics

| Metric | Typical TS / Node stack | Zig `opencliz` (this repo) | Order of magnitude |
|--------|-------------------------|----------------------------|--------------------|
| **Artifact size** | ~50 MB+ (app + Node runtime footprint) | **~5–6 MB** single binary (ReleaseFast; platform-dependent) | **~9–10× smaller** (vs ~50 MB baseline) |
| **Cold start** | ~200–500 ms (Node init + load) | **~3–5 ms** (process start + trivial CLI path) | **~100× faster** |
| **RSS (idle)** | ~100–200 MB typical for Node CLI | **~1–3 MB** (`--version` / tiny paths) | **~50–100× lower** |
| **RSS (`list`)** | Often tens of MB | **~2–4 MB** (measured in prior runs; depends on registry size) | Much lower |
| **RSS (HTTP command)** | Higher (buffers, TLS, JSON) | **~5–10 MB** typical for one-shot API call | Still far below Node baseline |
| **Debug iteration** | `npm install` + `tsc` often **15–45 s** first/full cycle | **`zig build`** often **sub-second** after cache warm | **Large win** |
| **Release build** | **~30–70 s** typical CI path | **`zig build -Doptimize=ReleaseFast`** **~10–30 s** (machine-dependent) | **Several× faster** |
| **Runtime deps** | **100+** npm packages + Node (upstream-style) | **No `node_modules`**; Zig **stdlib** + **`build.zig.zon`** deps (e.g. **QuickJS-ng**), static link; optional **Bun** only for `ts_legacy` | **No Node in opencliz** |

---

## 2. Build efficiency

### 2.1 Developer loop (debug)

Typical TypeScript CLI project:

```text
npm install     → 10–30 s (cold or lockfile change)
tsc --build     → 5–15 s
Total           → often 15–45 s per full cycle
```

This Zig port (after dependencies are fetched):

```text
zig build       → commonly <1 s (incremental); cold can be higher
```

**Takeaway:** Edit–compile–test loops are much shorter in Zig for this codebase size.

### 2.2 Release (optimized)

```text
TypeScript (typical):
  install + optimized bundle → often 30–70 s in CI

Zig:
  zig build -Doptimize=ReleaseFast → often ~10–30 s (CPU-dependent)
```

### 2.3 Deliverable shape

| Output | TypeScript / Node | Zig |
|--------|-------------------|-----|
| What you ship | JS + `node_modules` or bundled assets + **Node runtime** | **One native executable** |
| Host requirement | Compatible Node version | None beyond OS + (optional) Chrome for CDP paths |
| Distribution | `npm i -g` or container with Node base | Copy binary; small container base (e.g. Alpine) possible |

---

## 3. Runtime behavior

### 3.1 Example latencies (includes network where noted)

| Command | Approx. time | Notes |
|---------|--------------|--------|
| `--version` | **<1 ms** | No I/O beyond stdout |
| `list` | **~1 ms** | Depends on command count and disk; still tiny |
| `bilibili/hot --limit 3` | **~100–200 ms** | Dominated by **HTTP**; figures drift with CDN and region |
| `hackernews/top --limit 3` | **~1–3 s** | Upstream Firebase/API latency dominates |

### 3.2 TS vs Zig (illustrative, non-network)

| Scenario | TS / Node (order of magnitude) | Zig | Comment |
|----------|--------------------------------|-----|---------|
| Cold process start | 200–500 ms | 3–5 ms | Biggest differentiator for shell automation |
| Warm / reused process | 50 ms+ | N/A for one-shot CLI | Node can amortize if long-lived |
| Pure CPU path (no HTTP) | tens of ms | single-digit ms | V8 vs native; workload-specific |
| `list` | ~50–150 ms | **~1 ms** | Registry parse in Zig is lightweight |

**Important:** For real adapters, **wall-clock is usually network-bound**. Zig wins most clearly on **startup**, **memory**, and **deployment surface**.

---

## 4. Memory (RSS)

### 4.1 Example snapshots (macOS `time`; values vary by OS and allocator)

```text
opencliz --version     → ~1.6 MB RSS  (example)
opencliz list          → ~2.7 MB RSS  (example)
opencliz bilibili/hot  → ~7.4 MB RSS  (example; includes HTTP buffers)
```

### 4.2 vs Node (typical)

| Scenario | Node (typical) | Zig (this port) |
|----------|----------------|-----------------|
| Idle / tiny CLI | ~100–200 MB RSS | **~1–3 MB** |
| Peak for one command | Often **hundreds of MB** with full dependency tree | **Single-digit to low tens of MB** unless large allocations |

---

## 5. Dependency surface

### 5.1 Upstream-style TypeScript stack (illustrative)

Large CLIs often pull:

- Playwright or Puppeteer (browser automation) — **very large** on disk  
- HTTP, HTML, YAML, WebSocket, Redis clients, etc. — **many** `node_modules` entries  

**Disk:** `node_modules` commonly **hundreds of MB** for rich apps.

### 5.2 This Zig port

- **No** npm / **Node** inside **opencliz**; optional **Bun** for `ts_legacy` only (**`RUNTIME_MODEL.md`**).  
- **Zig standard library** for most logic.  
- **`build.zig.zon`**: e.g. **QuickJS-ng** for plugin JS; **libcurl** (or system curl) for HTTP—**linked into the binary**, not shipped as separate package manager tree.  
- Operational complexity shifts from **semver of 100 packages** to **Zig version + C toolchain** for native deps.

---

## 6. Scorecard (subjective 1–10)

| Dimension | TS / Node | Zig `opencliz` | Notes |
|-----------|-----------|----------------|--------|
| Incremental build speed | 3–5 | **9–10** | Zig excels for this repo size |
| Artifact size | 3–4 | **9** | Single-digit MB vs runtime + app |
| Cold start | 3–4 | **10** | Native process vs Node bootstrap |
| Memory efficiency | 2–4 | **9–10** | Orders of magnitude for idle/small cmds |
| Dependency hygiene (runtime) | 4–5 | **9** | No transitive npm at run time |
| Ecosystem (libraries, SO answers) | **9** | 5–6 | Node wins raw ecosystem breadth |

**Net:** Strong fit for a **CLI/daemon** where **footprint and startup** matter; TS remains strong for **rapid app iteration** and **browser-automation parity** where you keep Node/Playwright anyway.

---

## 7. Scenario narratives

### 7.1 Local dev: change → test

**TypeScript:** edit → `tsc` → test → often **15–45 s** per full cold cycle.  
**Zig:** edit → `zig build` / `zig build test` → often **a few seconds** total.

### 7.2 Container image (illustrative)

**Node image:** base **~900 MB+** with full toolchain and deps is common.  
**Zig binary in minimal base:**

```dockerfile
FROM alpine:latest
COPY zig-out/bin/opencliz /usr/local/bin/opencliz
ENTRYPOINT ["opencliz"]
```

Image size is dominated by **Alpine + libc + binary**—often **tens of MB**, not hundreds.

### 7.3 User runs one command

**Node:** pay **startup + module load** every invocation unless wrapped.  
**Zig:** **sub-millisecond** process start; remaining time is **your logic + network**.

---

## 8. Conclusions

### 8.1 What you gain with the Zig port

| Area | Benefit |
|------|---------|
| **Dev loop** | Much faster compile/test cycles vs full Node+tsc pipeline |
| **Operations** | Tiny binary, low RSS, **no Node** on servers for **opencliz** (optional Bun only if you enable `ts_legacy`) |
| **Supply chain** | No runtime npm tree; audit **Zig + native deps** instead |
| **Edge / CI** | Faster cold starts for wrappers and automation |

### 8.2 Trade-offs (honest)

- **Playwright-level browser automation** is **not** replicated 1:1; CDP-based paths differ (see `docs/CDP_SCENARIO_MATRIX.md`).  
- **Ecosystem**: fewer off-the-shelf Zig packages than npm for odd integrations.  
- **Migration cost:** engineering time to reach feature parity (tracked separately from this performance note).

### 8.3 Illustrative ROI model (not financial advice)

Rough **thought experiment** only—substitute your own salaries and CI minutes:

```text
Assume:
  - 10 developers × 20 min/day saved on build loops → ~200 min/day
  - CI: 100 builds/day × 1 min saved each → 100 min/day
  - Memory: fewer/smaller instances where the CLI runs as a sidecar

Monetize with your internal $/minute and $/GB-month; treat as order-of-magnitude only.
```

---

## Appendix A: How to reproduce (local)

**Binary size:**

```bash
zig build -Doptimize=ReleaseFast
ls -lh zig-out/bin/opencliz
# Example (macOS arm64, 2026-04): ~5.5 MB
```

**Build time:**

```bash
/usr/bin/time -p zig build -Doptimize=ReleaseFast
```

**RSS (macOS):**

```bash
/usr/bin/time -l zig-out/bin/opencliz --version 2>&1 | grep maximum
```

**Command latency (includes network):**

```bash
/usr/bin/time -p zig-out/bin/opencliz bilibili/hot --limit 3 -f json
```

Repeat on **your** machine; CI and laptops differ.

---

## Appendix B: Example captured numbers (point-in-time)

These matched **one** local environment; **do not** treat as guarantees.

```text
Release build (example):     ~9.7 s real (varies by CPU)
Binary (example):            ~5.5 MB  opencliz

RSS (examples):
  --version:                 ~1.6 MB
  list:                      ~2.7 MB
  bilibili/hot:              ~7.4 MB

Latency (examples):
  --version / list:          <1 ms
  bilibili/hot:              ~162 ms (network-heavy)
  hackernews/top:            ~2900 ms (upstream API latency)
```

---

*Maintainer note: refresh Appendix B after major dependency or feature changes (QuickJS, curl, adapter count).*
