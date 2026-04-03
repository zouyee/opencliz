# CDP browser deepening scenario matrix (Zig / TS comparison)

> **English**: For the “browser without extension” model and upstream differences, see **[`CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md`](CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md)** §2.4–3.

> **Purpose**: Sign off “phase C”—which commands use Chrome CDP under **`OPENCLI_USE_BROWSER=1`**, where it lives, and how Zig differs from TS (Playwright).  
> **Code**: `src/adapters/adapter_browser.zig`: `browserProfile` + `maybeBrowserDeepen`.

## Environment and prerequisites

| Item | Note |
|------|------|
| Switch | `OPENCLI_USE_BROWSER=1` |
| Config | `config.browser.enabled` (default true); can disable browser |
| Binary | Local Chrome/Chromium; CDP port in `types.Config.browser` |
| Cookie | `OPENCLI_COOKIE` / `OPENCLI_COOKIE_FILE` / `OPENCLI_<SITE>_COOKIE` (same as HTTP chain) |

## Commands with configured `waitFor` / `evaluate_light`

| Site | Command | `wait_for` | Timeout (ms) | `evaluate_light` | Notes |
|------|---------|------------|--------------|------------------|-------|
| weixin | download | `#js_content` | 45000 | `title`+`text` JSON | Lazy-loaded article body |
| web | read | `body` | 15000 | same | Generic page |
| zhihu | download | `.QuestionHeader, body` | 20000 | same | Q&A / article |
| sinablog | article | `body` | 15000 | same | Blog post |
| jd | item | `body` | 20000 | same | Product page |
| (default) | other `browser: true` | — | 30000 | — | Generic CDP path when no dedicated profile |

## Differences vs TypeScript (Playwright) — signed boundary

| Dimension | TS | Zig |
|-----------|----|-----|
| Engine | Playwright | CDP WebSocket (`src/browser/`) |
| Selectors | Per-test DOM | Fixed profiles above + extensible `browserProfile` |
| Session / tabs | Richer | Mostly single command deepen |
| Output shape | Legacy article pipeline target | Aligned with `article_pipeline` (frontmatter / text / optional external HTML→MD) |

**Conclusion**: **No** byte-identical requirement; acceptance is readable body + structured fields for the same URL.

## Scenario sign-off matrix

> **H.2 / Wave 2.1**: Rows below are signed or N/A; cross-ref **`zig-chrome-ci.yml`** (**P2 / batch 63**: **`web/read`**, **`zhihu/download`**, **`weixin/download`**, **`sinablog/article`**, **`jd/item`**; plus **`workflow_dispatch`** + **weekly Wednesday schedule**).

> 2026-04-02

| Site | Command | Status | Sign | Notes |
|------|---------|--------|------|-------|
| weixin | download | Signed | ZZ | 2026-04-02 · zig-chrome-ci smoke |
| web | read | Signed | ZZ | 2026-04-02 · zig-chrome-ci smoke |
| zhihu | download | Signed | ZZ | 2026-04-02 · zig-chrome-ci smoke |
| sinablog | article | Signed | ZZ | 2026-04-02 · zig-chrome-ci smoke |
| jd | item | Signed | ZZ | 2026-04-02 · zig-chrome-ci smoke |
| Other | `browser: true` | N/A | N/A | Generic CDP path |

**Legend**:

- Signed: verified working
- Pending: profile exists, needs manual check
- Failed: issues found
- N/A: not applicable

## Optional manual regression (optional CI)

On a machine with Chrome (network required):

```bash
export OPENCLI_USE_BROWSER=1
zig build run -- weixin/download --url 'https://mp.weixin.qq.com/s/…' -f json
zig build run -- zhihu/download --url 'https://zhuanlan.zhihu.com/p/…' -f json
zig build run -- web/read --url 'https://example.com' -f json
```

If it fails: Chrome launch, port in use, or login required (`login_required` / `http_or_cdp` are expected branches).

---

*Synced with `docs/TS_PARITY_MIGRATION_PLAN.md` phase C.*
