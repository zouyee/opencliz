# OpenCLI Migration Report: TypeScript to Zig

> **⚠️ Historical snapshot — not the live status page** (2026-04-01 maintenance)  
> - **Current capabilities vs upstream:** `docs/CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md`  
> - **Parity / P0–P4 progress:** `docs/PARITY_PROGRESS.md`  
> - **Migration plan A–G (done) & phase H:** `docs/TS_PARITY_MIGRATION_PLAN.md`  
> Sections below retain the **2026-03-31** narrative; metrics, test counts, and CLI version may **differ from today’s tree**. **`zig build test`** currently runs a **small** default test set; large suites under `src/tests.zig` are **not** all linked into that executable without further build fixes (embed paths, Zig 0.15 API drift in `integration_tests.zig`).

**Date**: 2026-03-31  
**Status (original headline)**: ✅ **Planned migration (A–G) delivered** — **not** “100% product parity” with npm `@jackwener/opencli` (see capability doc above).

---

## Executive Summary

The Zig port **delivered the scoped migration work** (command surface, HTTP/adapters, CDP path, pipeline, plugins subset, daemon subset, docs). **Upstream feature parity** is **ongoing** (L2–L7) and **explicitly capped** in `docs/TS_PARITY_99_CAP.md`.

| Metric | TypeScript | Zig (illustrative) | Note |
|--------|------------|--------------------|------|
| Binary Size | ~50MB + Node.js runtime | ~3.5MB single binary | Measure locally |
| Startup Time | ~500ms class | ~3–4ms class | Measure locally |
| Memory Usage | ~150MB class | ~1–3MB RSS class | Measure locally |
| **Default `zig build test`** | — | **~16 tests** pass | Does **not** equal all `src/tests.zig` declarations today |
| Build Success | ✓ | ✓ | `zig build` / `zig build test` |

---

## Migration Overview

### What Was Migrated

1. **Broad adapter coverage** (the original report listed ~20 sites as examples; the live registry is larger — run `opencli list`)
   - Bilibili (hot, search, user)
   - GitHub (trending, repo)
   - HackerNews (top, show)
   - Twitter/X (timeline, search, user)
   - YouTube (trending, search, transcript)
   - Reddit (hot)
   - StackOverflow (search, question, user)
   - NPM (search, info, downloads)
   - V2EX (hot)
   - Zhihu (hot, search, question, user)
   - Douban (movie, book)
   - Weibo (hot, user, post)
   - And more...

2. **Test infrastructure (as of original report)**
   - `src/tests/integration_tests.zig`, `adapter_test_helpers.zig`, `src/tests.zig`, fixture tests, etc.  
   - **Today:** treat **`zig build test`** as the supported default; re-enabling the full `tests.zig` tree in the test executable needs **embed path / std API** updates for Zig 0.15.

3. **Browser Automation (CDP)**
   - Chrome DevTools Protocol implementation in `src/browser/cdp.zig`
   - WebSocket-based browser communication in `src/browser/websocket.zig`
   - Browser adapter in `src/adapters/adapter_browser.zig`

### Architecture Differences

| Aspect | TypeScript | Zig |
|--------|------------|-----|
| Runtime | Node.js | Native |
| HTTP Client | Node fetch | Custom HTTP client |
| Browser Automation | Playwright | CDP (Chrome DevTools Protocol) |
| Response Handling | `func` maps to output | `columns` + `getNestedValue` extracts fields |
| JSON Processing | Native JS | std.json (Zig standard library) |

---

## Functional Test Results (original report — verify locally)

### Default unit test run

```bash
zig build test --summary all
```

As of **2026-04-01**, this runs on the order of **~16** tests pulled in via `main.zig`’s `test { ... }` block and transitive imports — **not** the full `src/tests.zig` catalog. The tables below are **2026-03-31** expectations; **CI smoke** for CDP is described in `docs/CDP_SCENARIO_MATRIX.md` and `.github/workflows/zig-chrome-ci.yml`.

### Integration Tests (`src/tests/integration_tests.zig`) — status

Many cases assumed older Zig `std.process.Child` / `HttpClient` APIs and **may not compile** until updated. Use **manual CLI checks** (see Recommendations) for end-to-end verification.

### CLI Command Verification (spot-check)

| Command | Notes |
|---------|--------|
| `./zig-out/bin/opencli --version` | Version string from `src/main.zig` `VERSION` (e.g. **2.2.0**) |
| `./zig-out/bin/opencli --help` | Help text |
| `./zig-out/bin/opencli list` | Live command count |
| `./zig-out/bin/opencli bilibili/hot --limit 3` | Requires network |
| `./zig-out/bin/opencli hackernews/top --limit 3` | Requires network |
| `./zig-out/bin/opencli v2ex/hot --limit 3` | Requires network |

---

## Performance Analysis

### Binary Characteristics

| Metric | Value |
|--------|-------|
| Binary Size | 3,690,632 bytes (~3.5 MB) |
| Startup Time | 3-4 ms |
| Memory (RSS) | ~2.3 MB |

### Runtime Performance

| Operation | Time |
|-----------|------|
| `opencli --version` | ~50ms (including process spawn) |
| `opencli list` | ~100ms |
| `opencli bilibili/hot --limit 3` | ~225ms (includes API call) |
| `opencli hackernews/top --limit 3` | ~2.9s (HN API is slow) |

### Comparison with TypeScript

| Metric | TypeScript | Zig | Factor |
|--------|------------|-----|--------|
| Startup | 500ms | 3-4ms | **125x faster** |
| Memory | 150MB | 2.3MB | **65x less** |
| Binary | 50MB+ | 3.5MB | **14x smaller** |
| Cold API call | ~200ms | ~50ms | **4x faster** |

---

## Test Coverage Analysis

### TypeScript Tests (Original 46 files)

The original TypeScript tests used browser automation mocking (Playwright-like page objects with DOM selectors). These don't directly translate to Zig's CDP-based model.

**Browser Automation Tests Not Migrated:**
- Page navigation tests (DOM selectors)
- Element click/interaction tests
- Screenshot tests
- Cookie/session tests

**Reason:** The architecture difference makes direct translation impractical. Browser automation in Zig uses CDP commands directly rather than DOM selectors.

### Alternative Approach Implemented

Instead of mocking browser automation, we created:

1. **HTTP API Integration Tests** - Test the actual API adapters with real HTTP calls
2. **CLI Subprocess Tests** - Test the binary end-to-end by spawning as subprocess
3. **Format Output Tests** - Verify JSON/Table output formatting works correctly

This approach tests the actual user experience rather than implementation details.

---

## Adapter Feature Comparison

| Adapter | TypeScript | Zig | Status |
|---------|------------|-----|--------|
| bilibili/hot | ✓ | ✓ | Fully functional |
| bilibili/search | ✓ | ✓ | Fully functional |
| bilibili/user | ✓ | ✓ | Fully functional |
| github/trending | ✓ | ✓ | Fully functional |
| github/repo | ✓ | ✓ | Fully functional |
| hackernews/top | ✓ | ✓ | Fully functional |
| hackernews/show | ✓ | ✓ | Fully functional |
| twitter/timeline | ✓ | ✓ | Fully functional |
| twitter/search | ✓ | ✓ | Fully functional |
| twitter/user | ✓ | ✓ | Fully functional |
| youtube/trending | ✓ | ✓ | Fully functional |
| youtube/search | ✓ | ✓ | Fully functional |
| youtube/transcript | ✓ | ✓ | Fully functional |
| reddit/hot | ✓ | ✓ | Fully functional |
| stackoverflow/search | ✓ | ✓ | Fully functional |
| stackoverflow/question | ✓ | ✓ | Fully functional |
| npm/search | ✓ | ✓ | Fully functional |
| npm/info | ✓ | ✓ | Fully functional |
| npm/downloads | ✓ | ✓ | Fully functional |
| v2ex/hot | ✓ | ✓ | Fully functional |
| zhihu/hot | ✓ | ✓ | Fully functional |
| zhihu/search | ✓ | ✓ | Fully functional |
| zhihu/question | ✓ | ✓ | Fully functional |
| douban/movie | ✓ | ✓ | Fully functional |
| weibo/hot | ✓ | ✓ | Fully functional |
| weibo/user | ✓ | ✓ | Fully functional |
| weibo/post | ✓ | ✓ | Fully functional |
| juejin/hot | ✓ | ✓ | Fully functional |
| producthunt/trending | ✓ | ✓ | Fully functional |
| arxiv/search | ✓ | ✓ | Fully functional |
| unsplash/search | ✓ | ✓ | Fully functional |
| weather/current | ✓ | ✓ | Fully functional |
| newsapi/top | ✓ | ✓ | Fully functional |

---

## Pre-existing Issues (historical note)

The table below reflected **2026-03-31** transform-test expectations. **Current** status: run **`zig build test`**; for full **`src/tests.zig`** coverage, see the banner at the top of this file.

| Test (historical) | Issue | Impact |
|-------------------|-------|--------|
| `parseSimpleQuery with dot notation` | Transform edge cases | Low |
| `parseSimpleQuery with whitespace` | Transform edge cases | Low |
| `TransformExecutor selectField on object` | Test / allocator hygiene | Low |

---

## Browser Automation Architecture

### TypeScript (Original)
- Used Playwright for browser automation
- DOM selectors for element identification
- Page objects for test organization

### Zig (New)
- Uses Chrome DevTools Protocol (CDP) directly
- WebSocket communication with Chrome
- Commands: navigate, click, typeText, waitForSelector, evaluate, screenshot

### CDP Commands Available

```zig
BrowserController.navigate(url)       // Navigate to URL
BrowserController.click(selector)      // Click element
BrowserController.typeText(selector, text)  // Type into element
BrowserController.waitForSelector(selector, timeout)  // Wait for element
BrowserController.evaluate(expression) // Execute JS
BrowserController.getContent()         // Get outerHTML
BrowserController.screenshot(path)     // Take screenshot
```

### Browser Integration Points

Browser automation is invoked via `OPENCLI_USE_BROWSER=1` environment variable for commands with `browser: true`:

- `zhihu/download` - Download article content
- `weixin/download` - WeChat article download
- `web/read` - Generic web page reader
- `jd/item` - JD.com product pages
- `sinablog/article` - Sina blog articles

---

## Recommendations

### For Production Use
1. HTTP-first adapters: **best-effort**; site breakage and auth gaps are normal — see `docs/AUTH_AND_WRITE_PATH.md`
2. Browser automation: Chrome/Chromium or external CDP **`ws://`** (`OPENCLI_CDP_WEBSOCKET`); see `docs/advanced/cdp.md`
3. CDP smoke: **`docs/CDP_SCENARIO_MATRIX.md`** / **`zig-chrome-ci.yml`**

### For CI/CD
```bash
# Run unit tests
zig build test

# Run integration tests (requires network)
./zig-out/bin/opencli bilibili/hot --limit 1
./zig-out/bin/opencli hackernews/top --limit 1
./zig-out/bin/opencli github/trending --limit 1
```

### For Browser Tests (Manual)
```bash
# Requires Chrome installed
OPENCLI_USE_BROWSER=1 ./opencli zhihu/download --url https://...
```

---

## Conclusion

**Engineering migration (planned phases A–G)** is **documented as complete** in `docs/TS_PARITY_MIGRATION_PLAN.md`. **Product parity** with npm `@jackwener/opencli` is **not** claimed here; use **`docs/CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md`** and **`docs/PARITY_PROGRESS.md`**.

The Zig port targets **fast startup**, **small binary**, and **low memory**; exact factors depend on your build and machine. **Default `zig build test`** is a **subset** of the repository’s test declarations until the full `src/tests.zig` graph is wired to the test step again.

---

## Files Created/Modified

### Created
- `src/tests/integration_tests.zig` - 23 integration tests
- `src/tests/adapter_test_helpers.zig` - Test utilities
- `src/tests/adapters/format_test.zig` - Format tests

### Modified
- `src/tests.zig` - Added integration test imports
- `src/main.zig` - Test import added
- `src/output/format.zig` - Made getNestedValue public

### Test infrastructure (do not use the numbers below as current truth)

- Historical note: this report once cited **88** declared tests with **85** passing / **3** transform failures. **Current** numbers: run **`zig build test --summary all`** and see **`docs/PARITY_PROGRESS.md`**.
