# Authentication and write paths (phase D baseline)

> **Capability boundary** for parity with the TypeScript upstream: public reads first; logged-in and write operations depend on environment variables or follow-up work. Per-site behavior is not guaranteed to match the legacy Node build.

## Supported mechanisms

| Mechanism | Environment / behavior |
|-----------|------------------------|
| Generic Cookie header | `OPENCLI_COOKIE`, `OPENCLI_COOKIE_FILE` |
| Per-site Cookie | `OPENCLI_<SITE>_COOKIE` (uppercase site, `-` → `_`) |
| Pre-request injection | `HttpClient.request` maps URL host via `hostToSiteKey` (see `src/http/client.zig`) |
| Strategy field | `AuthStrategy`: `public` / `cookie` / `header` / `oauth` / `api_key` (YAML / type layer) |

## Structured status (not bare `todo`)

When login is missing, arguments are incomplete, or only CDP is viable, commands should return JSON with **`status`** (e.g. `login_required`, `need_argument`, `http_or_cdp`, `login_or_browser`) so scripts and the TS side can compare behavior.

## Write paths (Reddit, Jike, WeChat, etc.)

- **By default**: registered names align; the execution chain may be a stub or URL-only. Run site-level integration tests in an environment **with Token/Cookie**.
- **Milestones**: open issues per site for request shape, risk controls, and upstream API changes.

### Manual Cookie regression for write paths

> 2026-04-01  
> Command cheat sheet: **`scripts/regression_cookie_writepath.sh`** (same as below).

The following write-path commands need Cookie authentication. Manual regression steps:

#### Reddit writes

```bash
# 1. Obtain Reddit session cookie (browser devtools)
# 2. Set cookie
export OPENCLI_COOKIE="reddit_session_cookie_here"

# 3. Test upvote
./zig-out/bin/opencliz reddit/upvote --post-id "t3_abc123" --direction up -f json

# 4. Test downvote  
./zig-out/bin/opencliz reddit/upvote --post-id "t3_abc123" --direction none -f json

# 5. Test save
./zig-out/bin/opencliz reddit/save --post-id "t3_abc123" -f json

# 6. Test comment (browser required)
export OPENCLI_USE_BROWSER=1
./zig-out/bin/opencliz reddit/comment --post-id "t3_abc123" --text "Test comment" -f json
```

**Expected:**

- With Cookie: `{"action":"upvote","status":"ok",...}` or similar
- Without Cookie: `{"action":"upvote","status":"login_required",...}`

#### Bilibili favorites

```bash
# 1. Set Bilibili cookie
export OPENCLI_BILIBILI_COOKIE="bilibili_session_cookie_here"

# 2. Read favorites (public UID)
./zig-out/bin/opencliz bilibili/favorite --uid 123456 --limit 5 -f json

# 3. Read favorites (private lists need login)
./zig-out/bin/opencliz bilibili/favorite --limit 5 -f json
```

#### V2EX notifications

```bash
# 1. Set V2EX cookie
export OPENCLI_V2EX_COOKIE="v2ex_session_cookie_here"

# 2. Read notifications
./zig-out/bin/opencliz v2ex/notifications --limit 10 -f json

# 3. Profile
./zig-out/bin/opencliz v2ex/me -f json
```

**Regression checklist:**

- [ ] Cookie is injected into request headers
- [ ] Response includes `status` (not bare `todo`)
- [ ] Public data returns `login_required` when unauthenticated where appropriate
- [ ] Writes return structured status (`ok` / `pending` / `login_required`)

## OAuth / device flow

- **Today**: no full in-process OAuth app flow in Zig; obtain tokens externally and inject via Cookie/Header.
- **Later**: can split sub-milestones under phase D in `docs/TS_PARITY_MIGRATION_PLAN.md`.

### Explicit “no device code” sign-off

The following OAuth capabilities are **explicitly out of scope** for this repository (signed 2026-04-01):

| Site | TS capability | Zig today | Sign-off |
|------|---------------|-----------|----------|
| Twitter/X | OAuth 1.0a / OAuth 2.0 | Cookie injection works; **no embedded OAuth** | ✅ No device code |
| Reddit | OAuth 2.0 | Same | ✅ No device code |
| GitHub | OAuth 2.0 | Same | ✅ No device code |
| WeChat | Official account OAuth | Same | ✅ No device code |
| Bilibili | OAuth 2.0 | Same | ✅ No device code |

### OAuth / device flow decisions (Wave 2.2)

> 2026-04-02

| Site | Decision | Rationale | Sign | Date |
|------|----------|-----------|------|------|
| bilibili | No device code | Users manage tokens; Cookie/Header sufficient | ZZ | 2026-04-02 |
| github | No device code | Same | ZZ | 2026-04-02 |
| reddit | No device code | Same | ZZ | 2026-04-02 |
| twitter | No device code | Same | ZZ | 2026-04-02 |

**Alternatives:**

```bash
# After obtaining a token, inject via Cookie/Header
export OPENCLI_COOKIE="your_session_cookie"
export OPENCLI_<SITE>_COOKIE="your_site_specific_cookie"
```

**Why not implement:**

1. OAuth needs callback URLs, state, secrets—more complexity and risk.
2. Users should own tokens and inject via env.
3. Aligns with a minimal-dependency open-source stance.

---

## P1: High-traffic site read/write boundary matrix

> **Purpose**: One page you can cite for what Zig vs TS can promise on login, writes, and browser dependence (**not** byte-identical to TS). Use with **`docs/CDP_SCENARIO_MATRIX.md`** and **`scripts/regression_cookie_writepath.sh`**.  
> **Sign-off**: ZZ · **2026-04-01**

| Site / domain | Public read (no Cookie) | Logged-in read | Write path (Zig) | TS alignment | Notes |
|---------------|-------------------------|----------------|------------------|--------------|-------|
| HN / npm / PyPI / crates / SO public APIs, etc. | ✅ Mostly HTTP adapters | — | Usually none | L2 fixtures + **`compare_command_json.sh`** | Drift: use **`status`** |
| GitHub (public) | ✅ | Private repos, etc. | No embedded OAuth | **`OPENCLI_GITHUB_COOKIE`**; no device code (Wave 2.2) | Deep private API parity **not** promised |
| Bilibili | ✅ Partial APIs | Favorites / account scope | Names aligned | **`OPENCLI_BILIBILI_COOKIE`**; regression above | Risk/field drift → issues |
| V2EX | ✅ Lists, etc. | Notifications / `me` | Mostly read | **`OPENCLI_V2EX_COOKIE`** | See regression above |
| Reddit | ✅ Partial | Feeds, etc. | upvote/save/comment, etc. | **`OPENCLI_COOKIE`** or site vars | See **`regression_cookie_writepath.sh`** |
| Zhihu / Weibo / Twitter(X) | ⚠️ Login shells / anti-bot | ✅ | Writes **not** fully promised | Cookie + optional **`OPENCLI_USE_BROWSER=1`**; **no device code** | Not deep-equivalent to TS Playwright |
| WeChat / weixin | ⚠️ Often CDP or Cookie | ✅ | Matrix scenarios only | **`CDP_SCENARIO_MATRIX.md`** | Only signed matrix rows |
| Jike, Doubao / ChatWise desktop, etc. | Per YAML | Mixed | Writes **not** guaranteed | **`desktop_exec`** + local env | See **`MIGRATION_GAP`** |

**Acceptance**: without credentials, return structured **`status`** (e.g. **`login_required`**), **not** bare **`todo`**; with credentials, follow per-site **`regression_cookie_writepath.sh`** and the manual steps above.

---

*Phase D doc baseline; details track `docs/MIGRATION_GAP.md`.*
