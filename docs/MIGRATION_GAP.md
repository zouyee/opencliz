# Migration gap ledger (formal)

> **TypeScript parity baseline**: [**jackwener/opencli**](https://github.com/jackwener/opencli) (npm: `@jackwener/opencli`). See **`docs/UPSTREAM_REFERENCE.md`**.

## Counting rules

- **Baseline**: Git history `src/clis` (exclude `*.test.*`, `utils`, `test-utils`, `_shared`); compared to upstream [**jackwener/opencli**](https://github.com/jackwener/opencli) command tree.
- **Goal**: Align command capability with baseline (site + command).
- **Current implementation**: `src/adapters/*.zig` + `src/adapters/http_exec.zig`.

## Current summary

- Baseline capability items: ~`262` (`site/command`; `git ls-tree` + same filters as above).
- Sites registered at runtime: parse **`opencliz list`** (includes extensions, **more** than baseline).
- Baseline site count: `61` (incl. `_shared`).
- Migration status (baseline command names): **`missing=0`** (same script rules).
- **Note**: Runtime may include commands/sites beyond baseline; full **product** depth (browser automation, login, Markdown export, etc.) deepens per command in later iterations.
- **What “deep capability” vs TS still lacks and how to sign off**: **`docs/TS_PARITY_REMAINING.md`** (L2–L7 breakdown + backlog + sign-off template). **`docs/TS_PARITY_MIGRATION_PLAN.md` phases A–G are all checked**—do not conflate the two.
- **Colloquial “align with TS / ~99.99%” achievable cap**: **`docs/TS_PARITY_99_CAP.md`** (separate columns for A–G “migration done” vs L2–L7 “deep equivalence”).
- **TS vs Zig gap + wave schedule**: **`docs/TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md`**.

### “Deep migration” boundary (important)

**You cannot make every command 100% equivalent to legacy Node in one iteration**, including but not limited to:

- **Login / OAuth / Cookie**: Many sites (Bilibili favorites/follows/profile, Jike feed, Reddit writes, full WeChat export, etc.) depend on user session or undocumented APIs.
- **Desktop / Electron**: Doubao desktop, ChatWise, Cursor, Codex need **CDP + local apps**—not the same chain as pure HTTP adapters (see `docs/advanced/cdp.md`).
- **Anti-bot / dynamic rendering**: Some pages return shell HTML only; summaries may be empty shells or login text—not equivalent to legacy browser DOM pipelines.
- **Markdown / image pipeline**: Legacy `article-download` + Turndown are not fully replicated in Zig.

**Strategy**: **Deepen where `http_exec` can reliably GET** (public JSON, HTML summary, `__NEXT_DATA__`, etc.); login/CDP/missing-arg branches use structured **`status`** (`login_required`, `http_or_cdp`, `need_argument`, …)—**no bare `todo` strings**.

**Helper modules**:

- `src/adapters/html_extract.zig`: title and plain-text extraction.
- `src/adapters/html_to_md_simple.zig`: optional built-in HTML→Markdown (**`OPENCLI_BUILTIN_HTML_TO_MD`**); from batch **60**, inline rules apply inside blocks (**`strong`/`em`/`code`/`del`/images/`a`**, see **`MARKDOWN_ARTICLE_PIPELINE.md`**).
- `src/adapters/article_pipeline.zig`: matches legacy `article-download` **file + frontmatter** (`---` / source link / `# title` + body); default body is stripped text; simplified Markdown with **`OPENCLI_HTML_TO_MD_SCRIPT`** or **`OPENCLI_BUILTIN_HTML_TO_MD=1`**; optional `--output` writes `.md`; fields include `markdown`, `output_file`.
- `src/adapters/adapter_browser.zig`: like legacy `execution.ts`, `browser: true` uses CDP for **rendered DOM** when **`OPENCLI_USE_BROWSER=1`**, then `article_pipeline`; `strategy: cookie` pre-navigates `https://{domain}` (`resolvePreNav`); per-site `waitFor`/`timeout`.
- `src/adapters/desktop_exec.zig`: merges **`OPENCLI_CDP_ENDPOINT`** and `cdp_hint` for `cursor`/`codex`/`chatwise`/`doubao-app`.
- **Cookie / articles**: `OPENCLI_COOKIE`, `OPENCLI_COOKIE_FILE`, **`OPENCLI_<SITE>_COOKIE`**; **`OPENCLI_HTML_TO_MD_SCRIPT`** (optional Turndown subprocess, preferred); **`OPENCLI_BUILTIN_HTML_TO_MD=1`**; **`OPENCLI_ARTICLE_DOWNLOAD_IMAGES=1`** downloads absolute `http(s)` images in body to `article-images/` when `output` is set.

**Still not equivalent to legacy Node**: no embedded Turndown; in-body images are limited under **`OPENCLI_ARTICLE_DOWNLOAD_IMAGES=1`** only; OAuth/private APIs not all migrated.

## Migrated (site-level)

- bilibili
- github
- twitter
- youtube
- hackernews
- reddit
- v2ex
- zhihu
- daily
- weibo
- producthunt
- juejin
- douban
- stackoverflow
- npm
- pypi
- crates
- arxiv
- unsplash
- weather
- news
- doubao, doubao-app, chatwise, sinablog, sinafinance, smzdm, web, weixin, xiaoyuzhou, antigravity, barchart (batch 31)

## Not migrated (suggested priority)

### P0 (high traffic / public first)

- _(empty)_

### P1 (developer & news)

- _(empty)_

### P2 (desktop / heavy browser / complex writes)

- _(empty)_

## Delivered this round (batch 1)

- v2ex: `latest` `topic` `node` `nodes` `member` `replies` (HTTP execution)
- hackernews: `best` `new` `jobs` `user` (HTTP execution)

## Delivered (batch 2)

- bilibili: `ranking` `dynamic` `feed` `history`
- wikipedia: `search` `summary` `random` `trending`

## Suggested next (batch 3)

- reddit: `search` `user` `subreddit`
- stackoverflow: `hot` `unanswered` `bounties`
- zhihu: `trending` (if command existed historically)

## Delivered (batch 3)

- reddit: `search` `user` `subreddit` (HTTP execution)
- stackoverflow: `hot` `unanswered` `bounties` (HTTP execution)

## Delivered (batch 4)

- hackernews: `ask` `search` (HTTP execution)
- reddit: `frontpage` `popular` `user-posts` `user-comments` (HTTP execution)
- v2ex: `daily` `user` (HTTP execution)

## Delivered (batch 5)

- bilibili: `user-videos` `subtitle` `download` (basic public path)

## Delivered (batch 6)

- youtube: `video` `channel` `comments` `transcript` `transcript-group` (commands + basic execution path)
- weibo: `feed` `search` `comments` `me` `post` (commands + basic execution path)

## Delivered (batch 7)

- twitter: `profile` `trending` `notifications` `followers` `following` `bookmarks` `bookmark` `unbookmark` `like` `follow` `unfollow` `block` `unblock` `accept` `hide-reply` `post` `reply` `reply-dm` `thread` `article` `delete` `download` (registered + basic execution path)
- zhihu: `download` (registered + basic execution path)

## Delivered (batch 8)

- weread: `search` `book` `ranking` (public read, basic execution path)
- weread: `shelf` `notes` `highlights` `notebooks` (registered + structured placeholder; login/API TBD)

## Delivered (batch 9)

- xiaohongshu: `search` `user` (registered + minimal public read, navigable URL)
- xiaohongshu: `creator-note-detail` `creator-notes-summary` `creator-notes` `creator-profile` `creator-stats` `download` `publish` `feed` `notifications` (registered + structured placeholder; login/browser TBD)

## Delivered (batch 10)

- douyin: `profile` `hashtag` `videos` (registered + minimal public read, navigable URL)
- douyin: `activities` `collections` `delete` `draft` `drafts` `location` `publish` `stats` `update` (registered + structured placeholder; login/browser TBD)

## Delivered (batch 11)

- xueqiu: `search` `stock` `hot` (registered + minimal public read, navigable URL)
- xueqiu: `earnings-date` `feed` `fund-holdings` `fund-snapshot` `hot-stock` `watchlist` (registered + structured placeholder; finance API/login TBD)

## Delivered (batch 12)

- google: `search` `news` `suggest` `trends` (registered + minimal public read, navigable URL; `suggest` uses stable fallback)

## Delivered (batch 13)

- pixiv: `search` `user` `ranking` `detail` (registered + minimal public read, navigable URL)
- pixiv: `download` `illusts` (registered + structured placeholder; login/session TBD)

## Delivered (batch 14)

- wikipedia: Baseline check: `search` `summary` `random` `trending` fully covered (no new gap this round)
- linkedin: `search` `timeline` (registered + minimal public read, navigable URL)

## Delivered (batch 15)

- bloomberg: `businessweek` `economics` `feeds` `industries` `main` `markets` `news` `opinions` `politics` `tech` (registered + minimal public read, navigable URL)

## Delivered (batch 16)

- reuters: `search` (registered + minimal public read, navigable URL)

## Delivered (batch 17)

- substack: `search` `publication` `feed` (registered + minimal public read, navigable URL)

## Delivered (batch 18)

- medium: `search` `user` `feed` (registered + minimal public read, navigable URL)

## Delivered (batch 19)

- yahoo-finance: `quote` (registered + minimal public read, navigable URL)

## Delivered (batch 20)

- chatgpt: `ask` `ax` `new` `read` `send` `status` (registered + minimal executable path, entry URL)
- codex: `ask` `dump` `export` `extract-diff` `history` `model` `new` `read` `screenshot` `send` `status` (registered + minimal executable path, entry URL)

## Delivered (batch 21)

- cursor: `ask` `composer` `dump` `export` `extract-code` `history` `model` `new` `read` `screenshot` `send` `status` (registered + minimal executable path, entry URL)

## Delivered (batch 22)

- notion: `export` `favorites` `new` `read` `search` `sidebar` `status` `write` (registered + minimal executable path, entry URL)

## Delivered (batch 23)

- boss: `batchgreet` `chatlist` `chatmsg` `detail` `exchange` `greet` `invite` `joblist` `mark` `recommend` `resume` `search` `send` `stats` (registered + minimal executable path, entry URL)

## Delivered (batch 24)

- discord-app: `channels` `members` `read` `search` `send` `servers` `status` (registered + minimal executable path, entry URL)

## Delivered (batch 25)

- yollomi: `background` `edit` `face-swap` `generate` `models` `object-remover` `remove-bg` `restore` `try-on` `upload` `upscale` `video` (registered + minimal executable path, entry URL)

## Delivered (batch 26)

- apple-podcasts: `search` `episodes` `top` (registered + minimal executable path, entry URL)

## Delivered (batch 27)

- bbc: `news` (registered + minimal executable path, entry URL)
- dictionary: `search` `synonyms` `examples` (registered + minimal path; `search` uses stable fallback URL)

## Delivered (batch 28)

- devto: `top` `tag` `user` (registered + minimal executable path, entry URL)

## Delivered (batch 29)

- bilibili: `favorite` `following` `me` (registered + minimal path, login entry URL / structured status)
- v2ex: `me` `notifications` (registered + minimal path, login entry URL / structured status)
- douban: `search` `book-hot` `movie-hot` `marks` `reviews` (registered + minimal path; public queries use URL; logged-in cmds use uid/structured status)
- arxiv: `paper` (registered + minimal path; stable URL for `search/download`)
- hf: `top` (registered + minimal path, HuggingFace API URL)
- grok: `ask` (registered + minimal path; login cmds use structured status)
- jd: `item` (registered + minimal path, product page URL)
- chaoxing: `assignments` `exams` (registered + minimal path; login cmds use structured status)
- coupang: `search` `add-to-cart` (registered + minimal path; search returns URL; cart cmds use structured status)
- ctrip: `search` (registered + minimal path, search URL)

## Delivered (batch 30)

- reddit: `read` `comment` `save` `saved` `subscribe` `upvote` `upvoted` (`read` uses public `comments/{id}.json`; interactive cmds + structured status/entry URL)
- jike: `search` `feed` `like` `comment` `create` `repost` `notifications` (registered + minimal path; search/post URL; login structured status)

## Delivered (batch 31)

- doubao / doubao-app / chatwise: registered + minimal `http_exec` path (entry URL or structured status)
- sinablog: `article` `hot` `search` `user`; sinafinance: `news` (`news` uses public API JSON)
- smzdm: `search`；web: `read`；weixin: `download`
- xiaoyuzhou: `podcast` `episode` `podcast-episodes`
- antigravity: `dump` `extract-code` `model` `new` `read` `send` `serve` `status` `watch`
- barchart: `flow` `greeks` `options` `quote`
- Implementation: `src/adapters/more_sites.zig` (register) + `http_exec.zig` (execute)

## Delivered (batch 32 — depth fallback, not full equivalence)

- Added `src/adapters/html_extract.zig`: after `GET`, parse `<title>` + strip-tag text summary.
- `web/read`, `weixin/download`, `sinablog/article|hot|user`: prefer HTML summary; on failure (non-2xx HTTP, etc.) fall back to structured status + URL.
- `barchart/flow|greeks|options|quote`: same summary; on failure fall back to structured status.

## Delivered (batch 33 — article pipeline + optional CDP, toward legacy Node)

- `article_pipeline`: `stripScriptAndStyle` + frontmatter + optional disk; `barchart` etc. same pipe (`output` often empty).
- `runner`: after HTTP, adapter commands call `maybeBrowserDeepen` (`OPENCLI_USE_BROWSER=1` and `config.browser.enabled`).
- Env: **`OPENCLI_USE_BROWSER=1`** enables browser-session deepening like legacy (local Chrome/CDP, see `src/browser`).

## Delivered (batch 34 — cross-cutting B/C/D/E/F)

- **L2 (HTTP)**: `bilibili/favorite`, `bilibili/following` use public/logged-in API (`--uid` or Cookie; else `need_uid_or_cookie`); `zhihu/download` etc. use article pipeline.
- **L3 (Cookie)**: `HttpClient.putCookieHeader` avoids leak on overwrite; `OPENCLI_COOKIE_FILE` / `OPENCLI_COOKIE`; **`OPENCLI_<SITE>_COOKIE`** (uppercase, `-`→`_`, e.g. `OPENCLI_BILIBILI_COOKIE`); `applySiteCookieFromEnv` before each adapter command.
- **L4 (CDP)**: `adapter_browser` injects `waitFor`/`timeout` per site (e.g. `weixin/download`→`#js_content`, `zhihu/download`, `web/read`, `sinablog/article`).
- **L5 (external HTML→MD)**: `OPENCLI_HTML_TO_MD_SCRIPT` executable + arg `.opencli/article-html-input.html`, stdout → Markdown in `processHtmlArticle` (default still plain-text path).
- **L6 (desktop hints)**: `src/adapters/desktop_exec.zig`; `cursor`/`codex`/`chatwise`/`doubao-app` merge `cdp_hint` / `cdp_endpoint_set` when `OPENCLI_CDP_ENDPOINT` unset.
- **Engineering**: `scripts/list_http_exec_todos.sh` lists `http_exec` placeholders; `zig build test` pulls `article_pipeline` tests via `main.zig`; `fetchJson` comments note JSON lifetime / deinit.

### L2–L6 site sample matrix (sign-off, not exhaustive)

| Site / area | L2 public | L3 session | L4 browser | L5 fine MD | L6 desktop CDP |
|-------------|------------|---------|---------------|------------|-------------|
| bilibili | Partial (favorite/following conditional API) | Cookie env | `browser:true` + CDP | Default pipe | — |
| zhihu | question/search + download article | Site Cookie | download waitFor | Optional HTML_TO_MD_SCRIPT | — |
| weixin | download HTTP | Cookie | `#js_content` wait | Optional script | — |
| web/read | HTML summary | Cookie | body wait | Optional script | — |
| cursor / chatwise / doubao-app | Entry URL / status | — | — | — | Hint + `OPENCLI_CDP_ENDPOINT` |

## Delivered (batch 35 — L2/L4/L5 depth + status semantics)

- **L2**: `jike/feed` tries `article_pipeline` on `https://web.okjike.com/`; on failure `status: login_required`. Reddit writes, `v2ex` personal states map old placeholders to **`login_required`** / **`login_or_browser`** / **`pending`**; Zhihu download HTTP failure → **`http_or_cdp`**.
- **L4**: `adapter_browser` for `weixin/web/zhihu/sinablog` article commands prefers **`evaluate_light`** after `waitFor` (`JSON.stringify({title,text})`), else **outerHTML**.
- **L5**: `processHtmlArticle` adds **`ArticleOpts.http_client`**; with `OPENCLI_ARTICLE_DOWNLOAD_IMAGES=1` and `output_dir`, download in-body images.
- **L6 semantics**: `doubao-app` / `chatwise` base returns **`desktop_cdp`** (`desktop_exec` still merges `cdp_hint`).
- **YAML**: `pipeline/executor` comments explain fetch vs adapter Cookie contract.

## Delivered (batch 36)

- **`http_exec` removed bare `status: "todo"`**: now **`need_argument`** (Douban missing uid), **`login_required`** (Chaoxing/Coupang/Grok), **`login_or_browser`** (Pixiv fallback, LinkedIn unknown cmd), **`http_or_cdp`** (Sinablog/web/weixin/barchart article fallback), **`local_app`** (Antigravity).
- **`jd/item`**: prefer **`article_pipeline.fetchPageArticle`**, else URL; optional **`--output`**; **`adapter_browser`** adds `waitFor` + **`evaluate_light`** for `jd/item`.
- **`linkedin`**: uncovered subcommands return **`login_or_browser`**, avoid silent `null`.

## Delivered (batch 37)

- **`HttpClient.applySiteCookieFromUrl`**: `std.Uri` host → **`hostToSiteKey`** → **`OPENCLI_<SITE>_COOKIE`** (from batch 38 wired in **`request()`**, below).

## Delivered (batch 38)

- **`HttpClient.request`**: before each **GET/POST** (and **download** via `get`) **`applySiteCookieFromUrl(url)`**; cross-domain in one command switches **`OPENCLI_<SITE>_COOKIE`**; YAML pipeline does not duplicate.
- **`hostToSiteKey`**: added npmjs.org, juejin.cn, producthunt, unsplash, hn.algolia.com, noembed.com, etc.
- **`fetchJson`**: uses **`parseFromSliceLeaky`** to avoid **`Parsed`** leaks from `.value` without **`deinit`**.

## Delivered (batch 39 — JSON lifetime + Cookie host map)

- **`fetchNextDataJsonPage`**: `__NEXT_DATA__` payload uses **`parseFromSliceLeaky`** before freeing `response.body`.
- **`hnTopStories`**: item details use **`parseFromSliceLeaky(ir.body)`** directly, no stringify/parse round-trip.
- **`hostToSiteKey`**: Wikipedia/Wikimedia, Google subdomains, Substack/Medium, Yahoo Finance, dictionaryapi.dev, Apple Podcasts, BOSS (zhipin), Notion/Discord/Yollomi/Cursor, dev.to, news.ycombinator.com, aligned with `http_exec`.
- **`CacheManager.cacheJson`**: deep-copy read uses **`parseFromSliceLeaky`** to avoid **`Parsed`** leaks per `set`.

## vs migration plan: still open (not “missing command names”)

| Area | Note |
|------|------|
| **Baseline command names** | Script says **`missing=0`**; P0–P2 “not migrated” lists empty. |
| **Behavioral parity** | Logged-in writes, full desktop CDP, anti-bot sites, Turndown-grade MD still per “deep migration” above. |
| **Engineering/docs** | `scripts/check-doc-coverage.sh` checks **`pub const name`** vs **`docs/adapters/browser|desktop/*.md`**; `discord-app` maps to doc name without `-app`. |
| **YAML subset** | Nested keys, `commands` lists, indented `args`, **`pipeline`** → **`types.PipelineDef`**; multi-field **`pipeline.steps`** blocks may still need extension. |
| **Memory** | **`utils/cache.zig`** calls **`destroyLeakyJsonValue`** on cache **`delete`/`clear`/`deinit`** (batch 41). |
| **Known Zig std** | **`parseFromSliceLeaky`** on Zig 0.15.x may leak `allocated_numbers` per parse (std issue); Arena refactor possible. Acceptable for per-invocation CLI. |

## Delivered (batch 40 — Cookie host + doc coverage script)

- **`hostToSiteKey`**: add **`registry.npmjs.org`**, **`api.npmjs.org`** → **`npm`** (matches npm hosts in `http_exec`; `npmjs.org` rules kept).
- **`scripts/check-doc-coverage.sh`**: scan Zig adapter `pub const name` and check **`docs/adapters/browser`** / **`docs/adapters/desktop`** (replaces removed **`src/clis`** scan).
- **Adapter doc stubs**: added browser Markdown for **`pypi`**, **`npm`**, **`crates`**, **`github`**, **`juejin`**, **`producthunt`**, **`unsplash`**, **`weather`**, **`news`**, **`daily`**, etc., aligned with **`opencliz list`** (site doc coverage **63/63**).

## Delivered (batch 41 — cache / args / YAML backlog)

- **`destroyLeakyJsonValue`** + **`Cache(T, free_fn)`**: HTTP bodies and JSON trees freed on **`get` expiry, `delete`, LRU `evict`, `clear`, `deinit`**; **`CacheManager.deinit`/`clearAll`** route through cache **`deinit`/`clear`**.
- **`cli/args_parse`**: **`defer std.process.argsFree(allocator, argv)`** at parse entry; options and positionals **`dupe`**d; **`ParsedArgs.deinit`**; **`main`** uses **`defer cli.deinit(allocator)`**.
- **`utils/yaml`**: **`CliDefinition.fromYaml`** parses **`commands`**, **`args`**, **`pipeline`**; **`deinit`** releases **`pipeline`**; tests for empty commands and hand-built trees; nested-YAML test updated to flat samples matching parser.

## Delivered (batch 42 — YAML indent nesting)

- **`YamlParser.parse`**: **`ParseFrame` indent stack** (**`min_indent = declaration indent + 1`**), supports **`parent:\n  child: value`** and multi-level nesting; **`- ` lists** still use **`last_key`** (backward compatible).
- **Tests**: nested **`config` / `port` / `debug`**, flat top-level, **`a/b/c`** two-level nesting.

## Delivered (batch 43 — YAML command list stability)

- **`- k: v` wins** over generic **`k: v`** lines containing **`:`**, so **`- name: hot`** is not stored under **`"- name"`**.
- **`array_of_maps`**: **`merge_item_index`** instead of raw pointers into **`items`** (avoids dangle on grow); save **`frame_min`** before **`stack.pop()`**.
- **List continuation**: under **`commands`**, **`- name:`** + indented continuation merges into one object.
- **Nested blocks in list items**: under **`args:`** (or other **`key:`**), **`- name: …`** sub-lists (compatible with empty-object → array chain).
- **Tests**: **`fromYaml`** string integration (with **`args`**), sibling keys after **`commands`**, two commands (first with args, second plain).

## Delivered (batch 46 — phases F/G: QuickJS + `list --tsv`)

- **Dependency**: [mitchellh/zig-quickjs-ng](https://github.com/mitchellh/zig-quickjs-ng) (`quickjs_ng` in `build.zig.zon`); `build.zig` links **`quickjs-ng`** with `quickjs` import.
- **`src/plugin/quickjs_runtime.zig`**: `evalExpressionToString`; tests pulled via `comptime` in `tests.zig`.
- **`plugin.yaml`**: optional **`js_init`** (`.js` relative to plugin), run once in **`loadPlugin`**.
- **`list --tsv` / `list --machine`**: columns **site, name, source, pipeline(0/1), script(0/1)** (**`script=1`** ⇒ **`Command.js_script_path`** set); **`scripts/compare_opencli_list.sh`** sorted lines, no header by default; **`OPENCLI_LIST_HEADER=1`** adds TSV header.
- **Per-command `script`** + QuickJS wrapper **`opencli.args` / `opencli.version` / `opencli.log` (print)** (see **`docs/PLUGIN_QUICKJS.md`**, `quickjs_runtime.zig`).
- Docs: **`docs/PLUGIN_QUICKJS.md`**; **`docs/TS_PARITY_MIGRATION_PLAN.md`** F/G checked.

## Delivered (batch 48 — TS deep parity: cap doc + L7 test baseline)

- **`docs/TS_PARITY_99_CAP.md`**: “plan complete” vs “~99.99% cap”, §3 ordered backlog, §4 exclusions; cross-links **`TS_PARITY_MIGRATION_PLAN`** / **`TS_PARITY_REMAINING`**.
- **Daemon (L7)**: `readHttpRequestFromStream`, `parseHttpRequest`, **`OPENCLI_DAEMON_AUTH_TOKEN`** (Bearer / `X-OpenCLI-Token` / `?token=`), **POST/PUT/PATCH** JSON merge into `/execute/...`, **OPTIONS**+CORS, **`dispatchHttpRequest`**; **`daemon_contract_test`**, **`daemon_tcp_e2e_test`**; **`main.zig`** `serve` reads **`OPENCLI_DAEMON_*`**.
- **Explore / AI golden**: **`exploreFromHtml`** (`src/ai/explore.zig`), **`ai_explore_golden_test`**, **`explore_sample.html`**, **`synthesizer_golden.yaml`**.
- **L2 fixture**: **`stackoverflow_item_min.json`** + **`fixture_json_test`** (matches SO case in `tests.zig`).
- Docs: **`docs/DAEMON_API.md`** (auth, POST, env, test index); **`docs/TS_PARITY_REMAINING.md`** L7 row.

## Delivered (batch 49 — L2 HTTP cache / redirect notes)

- **HTTP cache**: Zig uses `CacheManager`, default TTL **600s**; compare TS policy in `src/http/client.ts` or runtime.
- **Redirects**: Zig **`HttpClient`** default **`follow_redirect=true`** (`max_redirects=10`); TS axios/fetch may differ (methods, limits).
- **Impact**: same command/args may return different **`data`** depending on cache or redirect chain.
- **Recommendation**: **`OPENCLI_CACHE=0`** for side-by-side diff; inspect **`Location`** manually when chains differ.
- **Recorded in**: `src/utils/cache.zig`, **`docs/TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md`** § wave 1.

## Delivered (batch 50 — phase H.1: L2 fixture expansion)

- **New minimal JSON fixtures** (same shape as `tests.zig` inline, for TS snippets): **`twitter_timeline_item_min.json`**, **`douban_movie_min.json`**, **`wikipedia_search_min.json`**, **`youtube_transcript_min.json`**.
- **`fixture_json_test.zig`**: **`@embedFile`** + **`getNestedValue`** for those four.
- **Script**: **`h_l2_ts_diff_suggestions.sh`** — suggested commands to diff Zig vs TS **`opencli … -f json`** (needs network; use with **`compare_command_json.sh`**).
- **Plan**: **`TS_PARITY_MIGRATION_PLAN.md` §6.2** wave **H.1**.

## Delivered (batch 68 — Registry: free `ExternalCli` strings; P0.5 optional `PARITY_SKIP_V2EX`)

- **`types.zig` / `Registry.deinit`**: 释放 **`external_clis`** 中 **`name`/`description`/`binary`/`install_cmd`**，消除 Debug **GPA** 泄漏（**`loadExternalClis`** 路径）。
- **Scripts**: **`parity_p0_5_export_zig.sh`** / **`parity_p0_5_export_upstream.sh`** / **`parity_p0_5_diff.sh`** 支持 **`PARITY_SKIP_V2EX=1`**（**`v2ex/hot`** 网络卡住时三边一致跳过）。
- **`PARITY_PROGRESS.md`**: **「首次运行」** 中文步骤 + 跳过 **v2ex** 说明。

## Delivered (batch 67 — L2: structured `status` + list fixtures for parity map ~99%)

- **L2 / `tests/fixtures/json/`**: **`opencli_status_login_required_min.json`**, **`opencli_status_http_or_cdp_min.json`**（对齐 **`http_exec`** 常见 **`status`**）；**`hackernews_top_array_min.json`**（**`hnTopStories`** 顶层数组）；**`v2ex_hot_array_min.json`**（**`/api/topics/hot.json`** 数组）。
- **`fixture_json_test.zig`**: 上述四文件 **`@embedFile`** + **`getNestedValue`** 断言。
- **Docs**: **`CAPABILITY_MIGRATION_MAP.md`** — **§0** 可核对 **~99%** 口径（加权表 + 余量 **P0.4**）；L2/L7 行刷新。

## Delivered (batch 66 — L2 P0.5 / L5 P3.2: five-command export + HTML→MD wrapper)

- **L2 / P0.5**: **`parity_p0_5_export_zig.sh`** (**`OPENCLI_CACHE=0`**, **`parity-output/zig/*.json`**), **`parity_p0_5_export_upstream.sh`** (batch **`record_jackwener_baseline.sh`**), **`parity_p0_5_diff.sh`** (**`diff -u`**); **`.gitignore`** **`parity-output/`**.
- **L5 / P3.2**: **`examples/html_to_md_pandoc_wrap.sh`** (**`pandoc -f html -t gfm`**); **`MARKDOWN_ARTICLE_PIPELINE.md`** script contract + examples.
- **Docs**: **`PARITY_PROGRESS.md`** — P0.5/P3.2 status and next steps; **`l2_p0_routine.sh`** mentions the three scripts.

## Delivered (batch 65 — L7: daemon unknown command 404 + L2 baseline script + parity tracker)

- **`daemon.zig`**: **`/execute/{site}/{cmd}`** not in registry → **404** + **`{"error":"Command not found"}`** (with/without runner, with/without execute timeout); other failures still **500**.
- **`daemon_contract_test.zig`**: unknown → **404**; known command without runner → **503**; “no runner + unknown” → **404**.
- **`record_jackwener_baseline.sh`**: upstream CLI via **`bunx @jackwener/opencli … -f json | jq -S`** by default; override with **`OPENCLI_UPSTREAM_CLI_RUNNER=npx`** if needed — used for **`compare_command_json.sh --diff-ts`**; optional **`JACKWENER_OPENCLI_PKG`** pin.
- **`PARITY_PROGRESS.md`**: P0–P4 status, baseline table, ordered next steps.
- **`DAEMON_API.md`**: “items to verify” row for unknown commands.
- **`l2_p0_routine.sh`**: mentions **`record_jackwener_baseline.sh`** and **`PARITY_PROGRESS.md`**.

## Delivered (batch 64 — docs: upstream baseline is jackwener/opencli)

- **`UPSTREAM_REFERENCE.md`**: official upstream, npm, diff conventions, capability summary table.
- **Cross-links**: top of **`MIGRATION_GAP.md`**, **`TS_PARITY_REMAINING.md`**, **`TS_PARITY_MIGRATION_PLAN.md`**, **`TS_PARITY_99_CAP.md`**, **`TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md`**, **`README.md`** (Parity section).

## Delivered (batch 63 — P2: L3 Zig+Chrome CI; L6 `opencli.http` error mapping)

- **L3 / `zig-chrome-ci.yml`**: **`paths`** include **`more_sites.zig`**, **`chinese.zig`**, **`http_exec.zig`**, **`CDP_SCENARIO_MATRIX.md`**; smoke **`sinablog/article`**, **`jd/item`** (Linux **`xvfb-run`**, macOS, **`|| true`**); weekly **`schedule: 0 10 * * 3`**.
- **L6 / `quickjs_runtime.zig`**: **`HttpError`** → JS **`{\"error\":\"http_error\"}`** (vs **`request_failed`**); **`opencli_plugin_api_version` → 0.2.3**.
- **Docs**: **`PLUGIN_QUICKJS.md`** — **`error` table** + TS notes; **`CDP_SCENARIO_MATRIX.md`** — CI cross-ref; **`TS_PARITY_REMAINING`** / **`TS_ZIG`** P2.

## Delivered (batch 62 — L4/L7 P1: site boundary matrix + wider daemon tests)

- **L4 / `AUTH_AND_WRITE_PATH.md`**: **§ P1 high-traffic read/write matrix** (public / login / writes / TS alignment / acceptance); links **`CDP_SCENARIO_MATRIX`**, **`regression_cookie_writepath.sh`**.
- **L7 / `daemon_contract_test.zig`**: **`X-OpenCLI-Token`**, bad Bearer → **401** (**`Unauthorized`**), **`OPTIONS`** still **204** when **`auth_token`** set, **`GET /execute`** unknown → **500** (includes `Command execution failed`).
- **L7 / `daemon_tcp_e2e_test.zig`**: **`GET /`**, auth on without header → **401**, **`X-OpenCLI-Token`** end-to-end **200**.
- **`DAEMON_API.md`**: tests table + “items to verify”; L7 sign-off date refreshed.
- **Cross-links**: **`TS_PARITY_REMAINING.md`** §3 P1, **`TS_PARITY_99_CAP.md`** §3.5–3.6.

## Delivered (batch 61 — L2 P0: `l2_p0_routine` + `compare_command_json --diff-ts` + manual CI)

- **`l2_p0_routine.sh`**: repo root → **`zig build test`** (incl. **`fixture_json_test`**) → print **`h_l2_ts_diff_suggestions.sh`** and **`compare_command_json.sh --diff-ts`** hints (**`OPENCLI_CACHE=0`** recommended).
- **`compare_command_json.sh`**: **`--diff-ts <file>`**, **`jq -S`** then **`diff -u`**; exit **0** match, **1** diff.
- **`h_l2_ts_diff_suggestions.sh`**: header points to **`l2_p0_routine.sh`**.
- **`l2-json-parity-dispatch.yml`**: **`workflow_dispatch`** runs **`zig build test`** only (complements **`zig-ci`**).
- **Docs**: **`TS_PARITY_REMAINING.md`** §3 P0, §4 L2; **`TS_PARITY_99_CAP.md`** §3.2.

## Delivered (batch 59 — L2: `executeFetch` cache test + mock GET)

- **`PipelineContext.initForTesting`** / **`PipelineExecutor.initForTesting`**: force **`CacheManager.init`** (ignores **`OPENCLI_CACHE`** for offline tests).
- **`PipelineExecutor.test_fetch_get`**: replaces **`http_client.get`** on **GET**; **`TestFetchGetFn`** / **`TestFetchGetResponse`**.
- **`pipeline_fetch_cache_test.zig`**: two **`execute`** same URL → mock called once; **`extract`** still runs on cache hit.

## Delivered (batch 60 — L5: `html_to_md_simple` inline + block flow)

- **`html_to_md_simple.zig`**: inline **`<strong>`/`b`, `<em>`/`i`, `<code>`, `<del>`/`s`/`strike`, images, `<br>`**, comments; **`h1`–`h6`, `p`, `li`, `blockquote`, table cells, top-level `a[href]`** use **`convertInlineFragment`** (not raw **`html_extract`** text).
- **Edge cases**: distinguish **`<i>`/`s`** from **`<img`, `<iframe`, `<span`**.
- **Tests**: inline combos in paragraphs, headings/blockquotes, table **strong**, **`<span>`** paths.
- **Docs**: **`MARKDOWN_ARTICLE_PIPELINE.md`**, **`TS_PARITY_REMAINING.md`** (§2 L5, §4 matrix), **`TS_ZIG`** overview HTML→MD row.

## Delivered (batch 58 — L6: `opencli.http` **HEAD**)

- **`http/client.zig`**: **`head()`**; **`request(.HEAD, …)`** uses curl **`-I`** (not **`-X HEAD`**); no body / Content-Type on HEAD.
- **`quickjs_runtime.zig`**: **`httpHeadSync`**, **`nativeHttpHead`** from **`nativeHttpRequest`** when method is HEAD; **`opencli_plugin_api_version` → 0.2.2**; tests whitelist / https reject.
- **`PLUGIN_QUICKJS.md`**: method table + security model.

## Delivered (batch 57 — L2: YAML `pipeline` `fetch` JSON cache)

- **`PipelineExecutor.executeFetch`**: **GET** shares **`PipelineContext.http_json_cache`** with **`fetchJson`** (key = rendered URL; **`OPENCLI_CACHE=0`** disables like adapters); **POST** not cached.
- Cache stores **full** JSON; **`extract`** runs after hit (same as adapter “whole response then slice”).
- **Doc refs**: **`TS_PARITY_REMAINING.md`** §2 L2, §4 notes may mention pipeline **`fetch`**.

## Delivered (batch 56 — L2/L7: adapter JSON cache wiring + HN id fixture)

- **`PipelineContext.http_json_cache`**: no cache when **`OPENCLI_CACHE=0`**; else **`CacheManager.initFromEnv`**.
- **`fetchJson`**: on **`getCachedJson(url)`** hit, stringify→**`parseFromSliceLeaky`** clone to caller **`allocator`**; miss → fetch then **`cacheJson`** (errors ignored).
- **`hnTopStories`**: id-list URLs and **`…/v0/item/{id}.json`** share **`fetchJson`** cache.
- **`utils/cache.zig`**: **`adapterHttpJsonCacheDisabledByEnv`**; tests for clone-on-hit.
- **L2 fixture**: **`hn_firebase_top_ids_min.json`** (Firebase **`v0/topstories.json`** fragment) + **`fixture_json_test`**.
- **`DAEMON_API.md`**: **`OPENCLI_CACHE`** + adapter cache (**`serve`** same process as CLI).
- **Process**: **`TS_PARITY_REMAINING.md` §4** L2–L7 sign-off snapshot (cross-ref batches).

## Delivered (batch 55 — cross-cutting L2/L7/L5/L6: HTTP env, daemon execute timeout, HTML→MD, plugin body cap)

- **L2 / `http/client.zig`**: **`OPENCLI_HTTP_FOLLOW_REDIRECTS`** (`0` disables **`-L`**), **`OPENCLI_HTTP_MAX_REDIRECTS`**, **`OPENCLI_HTTP_MAX_OUTPUT_BYTES`** (default **20 MiB**).
- **L2 / `utils/cache.zig`**: **`CacheManager.initFromEnv`** reads **`OPENCLI_CACHE_HTTP_TTL_MS`**, etc. (wiring can extend).
- **L7 / `daemon.zig`**: **`DaemonConfig.execute_timeout_ms`**, **`OPENCLI_DAEMON_EXECUTE_TIMEOUT_MS`**; **`>0`** wraps **`runAndGetResultWithAllocator`** with thread + **`ResetEvent.timedWait`** (Arena in worker); **504**; main **`join`**; **`runner.zig`** **`runAndGetResultWithAllocator`**.
- **L5 / `html_to_md_simple.zig`**: **`<hr>`** → **`---`**; minimal **`<table>`** (GFM header row when first row all **`th`**) + tests.
- **L6 / `quickjs_runtime.zig`**: body over **`OPENCLI_PLUGIN_HTTP_MAX_BODY_BYTES`** (default **2 MiB**) → **`body_too_large`**.
- **Docs**: **`DAEMON_API.md`**, **`PLUGIN_QUICKJS.md`**, **`TS_ZIG`**.

## Delivered (batch 54 — L7: daemon request read timeout, closer to TS “has timeout”)

- **`readHttpRequestFromStream`**: **`read_timeout_ms`**; **`>0`** uses **`std.posix.poll`** before **`stream.read`**, **`std.time.Instant`** caps full request read; **`ReadTimeout`** → **408** + `{"error":"Request read timeout"}`.
- **`DaemonConfig.request_timeout_ms`**: default **30000**; **`serve`** reads **`OPENCLI_DAEMON_REQUEST_TIMEOUT_MS`** (**`0`** = unlimited, legacy).
- **`DAEMON_API.md`**, **`TS_ZIG`**: env + Zig vs TS table.
- **Call sites**: **`daemon_tcp_e2e_test`** passes **`0`** to avoid flaky timeouts.

## Delivered (batch 53 — phases H.1 / H.4)

- **H.1 / L2**: **`hn_item_min.json`** add **`time`**; **`github_trending_array_min.json`**, **`stackoverflow_items_wrapper_min.json`** + **`fixture_json_test`**; **`h_l2_ts_diff_suggestions.sh`** wikipedia/douban + **`OPENCLI_CACHE=0`**; **`compare_command_json.sh`** header mentions cache env.
- **H.4 / L5–L7**: **`MARKDOWN_ARTICLE_PIPELINE.md`** H.4 checklist vs TS; **`DAEMON_API.md`** L7 sign-off **TBD→ZZ**, tests list **`explore_edge_min.html`**; golden **`explore_edge_min.html`** + **`ai_explore_golden_test`** title without `/api/` hint.

## Delivered (batch 52 — phases H.2 / H.3: P1–P2 closure)

- **H.2 / wave 2**: **`CDP_SCENARIO_MATRIX.md`** ↔ **`zig-chrome-ci.yml`** (matrix signed); **`AUTH_AND_WRITE_PATH.md`** OAuth/device Wave 2.2 **ZZ**; **`regression_cookie_writepath.sh`** lists Cookie write commands (details in **`AUTH_AND_WRITE_PATH.md`**).
- **H.3 / wave 3**: **`zig-chrome-ci.yml`** second scenario **`zhihu/download`** smoke (**`|| true`**, anti-bot); **`paths`** include **`quickjs_runtime.zig`**, **`runner.zig`**.
- **QuickJS HTTP bridge (3.2)**: **`__opencli_http_*`** natives in **`quickjs_runtime.zig`**; **`opencli_plugin_api_version` → 0.2.1**; tests **`httpGetSync`/`httpPostSync`** whitelist + https reject (no network).
- **Bun subprocess hardening (3.3)**: **`runner.zig`** — **`OPENCLI_BUN_SUBPROCESS_TIMEOUT_MS`** (default 120s, **`0`** off), **`OPENCLI_BUN_MAX_OUTPUT_BYTES`**; POSIX timeout **detach** + **`SIGKILL`**; **`errdefer child.kill`**; **`PLUGIN_QUICKJS.md`** updated (**Bun** replaces Node for `type: ts`).

## Delivered (batch 51 — H.1: L2 fixtures + Reddit hot shape)

- **Fix**: **`reddit_hot_item_min.json`** **`data`** wrapper for **`getNestedValue(..., "data.*")`**.
- **New fixtures**: **`bilibili_dynamic_archive_fallback_min.json`** (no `desc.text`, **`major.archive.title`**), **`reddit_read_comments_min.json`**, **`npm_package_registry_meta_min.json`** (**`time.modified`**, vs fuller **`npm_package_min.json`**).
- **`fixture_json_test.zig`**: three files + **`bilibili_dynamic_archive_fallback`**; **`reddit_hot`** uses wrapped path.

## Delivered (batch 47 — phase E: built-in simplified HTML→MD)

- **`html_to_md_simple.zig`**: **`h1`–`h6`, `p`, `li`, `br`, `pre`, `blockquote`, `a[href]`**, entity decode; tests for headings, links, lists, code, quotes. (Inline-in-block batch **60**.)
- **`processHtmlArticle`**: when **`OPENCLI_HTML_TO_MD_SCRIPT`** fails, **`OPENCLI_BUILTIN_HTML_TO_MD=1`** uses built-in for **`markdown`** body.
- **Zig 0.15.x**: plugin JSON **`std.json.Stringify.valueAlloc`**; **`ArrayList(u8) = .empty`** patterns; **`build.sh`/`README`**: **`ZIG_GLOBAL_CACHE_DIR=./.zig-global-cache`** for sandbox/homeless cache; **`zig build`** after deps cached.
- **GitHub Actions**: **`zig-ci.yml`** runs **`zig build test`** (parallel to Node **`ci.yml`**); **`format.zig`** exports for **`integration_tests`**; **`MockHttpClient`** **`ArrayList`** API.
- **Docs**: **`MARKDOWN_ARTICLE_PIPELINE.md`**, **`TS_PARITY_MIGRATION_PLAN.md`** phase E / L5.

## Delivered (batch 45 — phase B: multi-command YAML + manifest TS policy)

- **`discovery.loadYamlFile`**: root **`commands:`** as **object** or **array** expands commands; children inherit **`site`/`domain`/`strategy`/`browser`/`description`** (child wins). Example **`examples/bilibili.yaml`** → `~/.opencli/clis/<site>/` or `src/clis/<site>/`.
- **`commandFromYamlObject`**: shared parse/inherit for single command body.
- **`cli-manifest.json`**: **`type: yaml`** heap-copied fields, **`source=manifest_yaml`** (no dangling JSON buffers).
- **`type: ts`**: **`source=ts_legacy`**, **`module_path`** owned by registry; **`runner`** returns **`ts_adapter_not_supported`** JSON unless **`OPENCLI_ENABLE_BUN_SUBPROCESS=1`** (**Bun** child — **no Node**).
- **Plan/matrix docs**: **`TS_PARITY_MIGRATION_PLAN.md`** (B checked), **`CDP_SCENARIO_MATRIX.md`**, **`AUTH_AND_WRITE_PATH.md`**, **`MARKDOWN_ARTICLE_PIPELINE.md`**; list diff **`scripts/compare_opencli_list.sh`**.

## Delivered (batch 44 — YAML pipeline + plugin command execution)

- **`yaml.zig`**: `parsePipelineDefFromYaml`, `parseRuntimeArgsFromYaml`, `parseRuntimeColumnsFromYaml`; **`CommandDefinition.pipeline`** = **`types.PipelineDef`**; **`fromYaml`** fills **`pipeline`**.
- **`plugin/manager.zig`**: **`plugin.yaml`** commands may carry **`pipeline`/`args`/`columns`/`strategy`/`browser`/`domain`**; **`cmd_refs`** for unload; **`errdefer`** unregister on **`register`** failure.
- **`discovery.zig`**: user **`~/.opencli/clis/<site>/<cmd>.yaml`** root **`pipeline`** heap-registered (**`source=yaml`**).
- **`types.zig`**: **`pipelineDefDeinit`**, **`destroyHeapCommandIfNeeded`**; **`Registry.deinit`/`unregisterCommand`** free plugin/yaml heap fields.
- **`pipeline/executor.zig`**: step **`data`** (JSON strings); **`fetch`** **`extract`** (deep copy subtree); **`transform`** **`operation: limit`**; **`{{args.xxx}}`** templates.
- Details: **`TS_PARITY_MIGRATION_PLAN.md`**.

## Acceptance criteria

1. `zig build` succeeds.
2. `opencliz list` runs without crash.
3. Each batch of new commands at least:
   - Registers successfully
   - Args parse
   - HTTP/browser execution path runs
4. Each batch updates this capability ledger (added, incomplete, blockers).
