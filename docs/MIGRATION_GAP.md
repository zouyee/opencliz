# opencli 迁移差距清单（正式）

> **TypeScript 能力对照基线仓库**：[**jackwener/opencli**](https://github.com/jackwener/opencli)（npm：`@jackwener/opencli`）。详见 **`docs/UPSTREAM_REFERENCE.md`**。

## 统计口径

- 基线：Git 历史 `src/clis`（过滤 `*.test.*`、`utils`、`test-utils`、`_shared`）；与上游 [**jackwener/opencli**](https://github.com/jackwener/opencli) 命令树同源对照
- 目标：与基线命令能力对齐（站点 + 命令）
- 当前实现：`src/adapters/*.zig` + `src/adapters/http_exec.zig`

## 当前结论（截至本次）

- 基线能力项：约 `262`（`site/command`；`git ls-tree` + 过滤规则同「统计口径」）
- 当前运行时注册站点数：以 `opencli list` 解析为准（含扩展能力，**多于**基线）
- 基线站点数：`61`（含 `_shared`）
- 迁移状态（基线命令名对齐）：**`missing=0`**（同上脚本口径）
- 说明：运行时仍包含基线外的命令与站点；完整「产品级」能力（浏览器自动化、登录态、Markdown 导出等）需在后续迭代按命令逐步加深实现
- **与 TS 版「深度能力」还差什么、如何才算签字完毕**：见 **`docs/TS_PARITY_REMAINING.md`**（L2–L7 分解 + Backlog + 签字模板）。**`docs/TS_PARITY_MIGRATION_PLAN.md` 阶段 A–G 已全部勾选**；二者不要混淆。
- **口语「尽量对齐 TS / ~99.99%」的可实现上限与勾选清单**：见 **`docs/TS_PARITY_99_CAP.md`**（与 A–G「迁移完毕」、与 L2–L7「深度等价」分栏说明）。
- **TS 版 vs Zig 版能力差距 + 分波排期**：见 **`docs/TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md`**。

### 「深度迁移」边界说明（重要）

**无法在一次迭代内做到「所有命令」与旧版 Node 行为 100% 等价**，原因包括但不限于：

- **登录 / OAuth / Cookie**：大量站点（B 站收藏/关注/个人、即刻动态、Reddit 写操作、微信完整导出等）依赖用户态或官方未公开 API。
- **桌面 / Electron**：豆包桌面端、ChatWise、Cursor、Codex 等需 **CDP + 本机应用**，与纯 HTTP 适配器不是同一条执行链（见 `docs/advanced/cdp.md`）。
- **反爬与动态渲染**：部分页面仅返回壳 HTML，摘要抓取只能得到空壳或登录页文本，不等价旧版浏览器 DOM 流水线。
- **Markdown / 图片管道**：旧版 `article-download` + Turndown 等尚未在 Zig 侧复刻。

当前策略是：**在 `http_exec` 能稳定 GET 的范围内加深**（公开 JSON、HTML 摘要、`__NEXT_DATA__` 等）；需登录/CDP/缺参的分支使用结构化 **`status`**（如 `login_required`、`http_or_cdp`、`need_argument` 等），**不再使用裸字符串 `todo`**。

实现辅助模块：

- `src/adapters/html_extract.zig`：标题与纯文本抽取。
- `src/adapters/html_to_md_simple.zig`：可选内置 HTML→Markdown（见 **`OPENCLI_BUILTIN_HTML_TO_MD`**）；**批次 60** 起块级内贯通行内规则（**`strong`/`em`/`code`/`del`/图片/`a`** 等，见 **`MARKDOWN_ARTICLE_PIPELINE.md`**）。
- `src/adapters/article_pipeline.zig`：对齐旧版 `article-download` **文件与 frontmatter 形态**（`---` / `原文链接` / `# 标题` + 正文）；默认正文为去标签纯文本；**`OPENCLI_HTML_TO_MD_SCRIPT`** 或 **`OPENCLI_BUILTIN_HTML_TO_MD=1`**（`html_to_md_simple.zig`）时可得简化 Markdown 正文；可选 `--output` 写 `.md`；字段含 `markdown`、`output_file`。
- `src/adapters/adapter_browser.zig`：与旧版 `execution.ts` 一致，对 `browser: true` 的命令在 **`OPENCLI_USE_BROWSER=1`** 时用 CDP 拉取 **渲染后 DOM**，再走同一套 `article_pipeline`；`strategy: cookie` 时先 `https://{domain}` 预导航（对齐 `resolvePreNav`）；按站点可选 `waitFor`/`timeout`。
- `src/adapters/desktop_exec.zig`：对 `cursor`/`codex`/`chatwise`/`doubao-app` 合并 **`OPENCLI_CDP_ENDPOINT`** 相关字段与 `cdp_hint`。
- Cookie / 文章：`OPENCLI_COOKIE`、`OPENCLI_COOKIE_FILE`、**`OPENCLI_<SITE>_COOKIE`**；**`OPENCLI_HTML_TO_MD_SCRIPT`**（可选 Turndown 等子进程，优先）；**`OPENCLI_BUILTIN_HTML_TO_MD=1`**（无外部脚本成功时的内置简化 HTML→MD）；**`OPENCLI_ARTICLE_DOWNLOAD_IMAGES=1`** 时在带 `output` 的文章导出中尝试下载正文内绝对 `http(s)` 图片到 `article-images/` 并追加 Markdown 引用。

**与旧版 Node 仍不完全等价之处**：未嵌入 Turndown（无 HTML→Markdown 的列表/链接/代码块精细规则）；正文内图片仅为 **`OPENCLI_ARTICLE_DOWNLOAD_IMAGES=1`** 下的有限下载，非旧版完整图片管线；OAuth/各站点私有 API 未全部迁移。

## 已迁移（站点级）

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
- doubao、doubao-app、chatwise、sinablog、sinafinance、smzdm、web、weixin、xiaoyuzhou、antigravity、barchart（批次 31）

## 未迁移站点（高优先级建议）

### P0（用户高频/公开能力优先）

- （已清空）

### P1（开发者与资讯能力）

- （已清空）

### P2（桌面/重浏览器/写操作复杂）

- （已清空）

## 本轮已补齐（批次 1）

- v2ex: `latest` `topic` `node` `nodes` `member` `replies`（含 HTTP 执行）
- hackernews: `best` `new` `jobs` `user`（含 HTTP 执行）

## 已补齐（批次 2）

- bilibili: `ranking` `dynamic` `feed` `history`
- wikipedia: `search` `summary` `random` `trending`

## 下一批建议（批次 3）

- reddit: `search` `user` `subreddit`
- stackoverflow: `hot` `unanswered` `bounties`
- zhihu: `trending`（如历史命令存在）

## 已补齐（批次 3）

- reddit: `search` `user` `subreddit`（含 HTTP 执行）
- stackoverflow: `hot` `unanswered` `bounties`（含 HTTP 执行）

## 已补齐（批次 4）

- hackernews: `ask` `search`（含 HTTP 执行）
- reddit: `frontpage` `popular` `user-posts` `user-comments`（含 HTTP 执行）
- v2ex: `daily` `user`（含 HTTP 执行）

## 已补齐（批次 5）

- bilibili: `user-videos` `subtitle` `download`（基础公开链路）

## 已补齐（批次 6）

- youtube: `video` `channel` `comments` `transcript` `transcript-group`（命令与基础执行链路）
- weibo: `feed` `search` `comments` `me` `post`（命令与基础执行链路）

## 已补齐（批次 7）

- twitter: `profile` `trending` `notifications` `followers` `following` `bookmarks` `bookmark` `unbookmark` `like` `follow` `unfollow` `block` `unblock` `accept` `hide-reply` `post` `reply` `reply-dm` `thread` `article` `delete` `download`（命令注册 + 基础执行链路）
- zhihu: `download`（命令注册 + 基础执行链路）

## 已补齐（批次 8）

- weread: `search` `book` `ranking`（公开只读基础执行链路）
- weread: `shelf` `notes` `highlights` `notebooks`（命令注册 + 结构化占位返回，待登录态/API补齐）

## 已补齐（批次 9）

- xiaohongshu: `search` `user`（命令注册 + 公开只读最小链路，返回可访问 URL）
- xiaohongshu: `creator-note-detail` `creator-notes-summary` `creator-notes` `creator-profile` `creator-stats` `download` `publish` `feed` `notifications`（命令注册 + 结构化占位返回，待登录态/浏览器链路补齐）

## 已补齐（批次 10）

- douyin: `profile` `hashtag` `videos`（命令注册 + 公开只读最小链路，返回可访问 URL）
- douyin: `activities` `collections` `delete` `draft` `drafts` `location` `publish` `stats` `update`（命令注册 + 结构化占位返回，待登录态/浏览器链路补齐）

## 已补齐（批次 11）

- xueqiu: `search` `stock` `hot`（命令注册 + 公开只读最小链路，返回可访问 URL）
- xueqiu: `earnings-date` `feed` `fund-holdings` `fund-snapshot` `hot-stock` `watchlist`（命令注册 + 结构化占位返回，待财经 API/登录态补齐）

## 已补齐（批次 12）

- google: `search` `news` `suggest` `trends`（命令注册 + 公开只读最小链路，返回可访问 URL；`suggest` 使用稳定 fallback）

## 已补齐（批次 13）

- pixiv: `search` `user` `ranking` `detail`（命令注册 + 公开只读最小链路，返回可访问 URL）
- pixiv: `download` `illusts`（命令注册 + 结构化占位返回，待登录态/session 补齐）

## 已补齐（批次 14）

- wikipedia: 对照基线确认 `search` `summary` `random` `trending` 已完整覆盖（本轮无新增缺口）
- linkedin: `search` `timeline`（命令注册 + 公开只读最小链路，返回可访问 URL）

## 已补齐（批次 15）

- bloomberg: `businessweek` `economics` `feeds` `industries` `main` `markets` `news` `opinions` `politics` `tech`（命令注册 + 公开只读最小链路，返回可访问 URL）

## 已补齐（批次 16）

- reuters: `search`（命令注册 + 公开只读最小链路，返回可访问 URL）

## 已补齐（批次 17）

- substack: `search` `publication` `feed`（命令注册 + 公开只读最小链路，返回可访问 URL）

## 已补齐（批次 18）

- medium: `search` `user` `feed`（命令注册 + 公开只读最小链路，返回可访问 URL）

## 已补齐（批次 19）

- yahoo-finance: `quote`（命令注册 + 公开只读最小链路，返回可访问 URL）

## 已补齐（批次 20）

- chatgpt: `ask` `ax` `new` `read` `send` `status`（命令注册 + 最小可执行链路，返回入口 URL）
- codex: `ask` `dump` `export` `extract-diff` `history` `model` `new` `read` `screenshot` `send` `status`（命令注册 + 最小可执行链路，返回入口 URL）

## 已补齐（批次 21）

- cursor: `ask` `composer` `dump` `export` `extract-code` `history` `model` `new` `read` `screenshot` `send` `status`（命令注册 + 最小可执行链路，返回入口 URL）

## 已补齐（批次 22）

- notion: `export` `favorites` `new` `read` `search` `sidebar` `status` `write`（命令注册 + 最小可执行链路，返回入口 URL）

## 已补齐（批次 23）

- boss: `batchgreet` `chatlist` `chatmsg` `detail` `exchange` `greet` `invite` `joblist` `mark` `recommend` `resume` `search` `send` `stats`（命令注册 + 最小可执行链路，返回入口 URL）

## 已补齐（批次 24）

- discord-app: `channels` `members` `read` `search` `send` `servers` `status`（命令注册 + 最小可执行链路，返回入口 URL）

## 已补齐（批次 25）

- yollomi: `background` `edit` `face-swap` `generate` `models` `object-remover` `remove-bg` `restore` `try-on` `upload` `upscale` `video`（命令注册 + 最小可执行链路，返回入口 URL）

## 已补齐（批次 26）

- apple-podcasts: `search` `episodes` `top`（命令注册 + 最小可执行链路，返回入口 URL）

## 已补齐（批次 27）

- bbc: `news`（命令注册 + 最小可执行链路，返回入口 URL）
- dictionary: `search` `synonyms` `examples`（命令注册 + 最小可执行链路；`search` 使用稳定 fallback URL）

## 已补齐（批次 28）

- devto: `top` `tag` `user`（命令注册 + 最小可执行链路，返回入口 URL）

## 已补齐（批次 29）

- bilibili: `favorite` `following` `me`（命令注册 + 最小可执行链路，返回登录入口 URL / todo）
- v2ex: `me` `notifications`（命令注册 + 最小可执行链路，返回登录入口 URL / todo）
- douban: `search` `book-hot` `movie-hot` `marks` `reviews`（命令注册 + 最小可执行链路，公开查询走 URL，登录态命令按 uid/todo 收口）
- arxiv: `paper`（命令注册 + 最小可执行链路；并补 `search/download` 的稳定 URL 执行）
- hf: `top`（命令注册 + 最小可执行链路，返回 HuggingFace API URL）
- grok: `ask`（命令注册 + 最小可执行链路，登录命令 todo 收口）
- jd: `item`（命令注册 + 最小可执行链路，返回商品页 URL）
- chaoxing: `assignments` `exams`（命令注册 + 最小可执行链路，登录命令 todo 收口）
- coupang: `search` `add-to-cart`（命令注册 + 最小可执行链路，搜索返回 URL，购物车命令 todo 收口）
- ctrip: `search`（命令注册 + 最小可执行链路，返回搜索 URL）

## 已补齐（批次 30）

- reddit: `read` `comment` `save` `saved` `subscribe` `upvote` `upvoted`（`read` 走公开 `comments/{id}.json`；交互类命令注册 + todo/入口 URL）
- jike: `search` `feed` `like` `comment` `create` `repost` `notifications`（命令注册 + 最小可执行链路，搜索/帖子页 URL，登录态 todo）

## 已补齐（批次 31）

- doubao / doubao-app / chatwise：命令注册 + `http_exec` 最小链路（入口 URL 或 todo）
- sinablog: `article` `hot` `search` `user`；sinafinance: `news`（`news` 走公开 API JSON）
- smzdm: `search`；web: `read`；weixin: `download`
- xiaoyuzhou: `podcast` `episode` `podcast-episodes`
- antigravity: `dump` `extract-code` `model` `new` `read` `send` `serve` `status` `watch`
- barchart: `flow` `greeks` `options` `quote`
- 实现位置：`src/adapters/more_sites.zig`（注册）+ `http_exec.zig`（执行）

## 已补齐（批次 32 — 深度兜底，非全量等价）

- 新增 `src/adapters/html_extract.zig`：`GET` 后解析 `<title>` + 去标签文本摘要。
- `web/read`、`weixin/download`、`sinablog/article|hot|user`：优先走 HTML 摘要；失败（HTTP 非 2xx 等）时回退为原 `todo` + URL。
- `barchart/flow|greeks|options|quote`：对目标页做同上摘要；失败时回退 `todo`。

## 已补齐（批次 33 — 文章流水线 + 可选 CDP，逼近旧版 Node）

- `article_pipeline`：`stripScriptAndStyle` + frontmatter + 可选写盘；`barchart` 等仍走同一管道（`output` 多为空）。
- `runner`：适配器命令在 HTTP 执行后调用 `maybeBrowserDeepen`（需 `OPENCLI_USE_BROWSER=1` 且 `config.browser.enabled`）。
- 环境变量：**`OPENCLI_USE_BROWSER=1`** 启用与旧版类似的「浏览器会话」加深（需本机可启动 Chrome / CDP，见 `src/browser`）。

## 已补齐（批次 34 — 方案 B/C/D/E/F 横切落地）

- **L2（HTTP）**：`bilibili/favorite`、`bilibili/following` 走公开/登录态 API（`--uid` 或 Cookie；无则 `need_uid_or_cookie`）；`zhihu/download` 等沿用文章管道。
- **L3（Cookie）**：`HttpClient.putCookieHeader` 避免覆盖 Cookie 时泄漏；`OPENCLI_COOKIE_FILE` / `OPENCLI_COOKIE`；**`OPENCLI_<SITE>_COOKIE`**（站点名大写、`-`→`_`，如 `OPENCLI_BILIBILI_COOKIE`）；每条 `adapter` 命令前 `applySiteCookieFromEnv`。
- **L4（CDP）**：`adapter_browser` 按站点注入 `waitFor`/`timeout`（如 `weixin/download`→`#js_content`，`zhihu/download`、 `web/read`、`sinablog/article`）。
- **L5（外部 HTML→MD）**：`OPENCLI_HTML_TO_MD_SCRIPT` 可执行文件 + 参数为 `.opencli/article-html-input.html`，stdout 作为正文写入 `processHtmlArticle` 的 Markdown（默认仍为纯文本路径）。
- **L6（桌面提示）**：`src/adapters/desktop_exec.zig`；`cursor`/`codex`/`chatwise`/`doubao-app` 在 JSON 上合并 `cdp_hint` / `cdp_endpoint_set`（未设 `OPENCLI_CDP_ENDPOINT` 时）。
- **工程**：`scripts/list_http_exec_todos.sh` 罗列 `http_exec` 中 todo/登录占位；`zig build test` 通过 `main.zig` 的 `test` 块拉取 `article_pipeline` 单测；`fetchJson` 旁注释标明 JSON 树生命周期待统一 deinit。

### L2–L6 站点抽样矩阵（签字用，非全表）

| 站点 / 能力 | L2 公开数据 | L3 会话 | L4 浏览器加深 | L5 精细 MD | L6 桌面 CDP |
|-------------|------------|---------|---------------|------------|-------------|
| bilibili | 部分（含 favorite/following 条件 API） | Cookie 环境变量 | `browser:true` + CDP | 同默认管道 | — |
| zhihu | question/search + download 文章 | 站点 Cookie | download 等 waitFor | 可选 HTML_TO_MD_SCRIPT | — |
| weixin | download HTTP | Cookie | `#js_content` wait | 可选脚本 | — |
| web/read | HTML 摘要 | Cookie | body wait | 可选脚本 | — |
| cursor / chatwise / doubao-app | 入口 URL / todo | — | — | — | 提示 + `OPENCLI_CDP_ENDPOINT` |

## 已补齐（批次 35 — L2/L4/L5 加深与状态语义）

- **L2**：`jike/feed` 先尝试 `article_pipeline` 拉取 `https://web.okjike.com/`；失败时 `status: login_required`。Reddit 写类、`v2ex` 个人态等将原 `todo` 改为 **`login_required`** / **`login_or_browser`** / **`pending`**；知乎下载 HTTP 失败为 **`http_or_cdp`**。
- **L4**：`adapter_browser` 对 `weixin/web/zhihu/sinablog` 文章类命令在 `waitFor` 之后优先 **`evaluate_light`**（`JSON.stringify({title,text})`），失败回退 **outerHTML**。
- **L5**：`processHtmlArticle` 增加 **`ArticleOpts.http_client`**；`OPENCLI_ARTICLE_DOWNLOAD_IMAGES=1` 且存在 `output_dir` 时下载正文内图片。
- **L6 语义**：`doubao-app` / `chatwise` 基础返回 **`desktop_cdp`**（仍由 `desktop_exec` 合并 `cdp_hint`）。
- **YAML**：`pipeline/executor` 注释说明 fetch 步与 adapter 的 Cookie 约定差异。

## 已补齐（批次 36）

- **`http_exec` 清零 `status: "todo"`**：改为 **`need_argument`**（豆瓣缺 uid）、**`login_required`**（超星/酷澎/Grok）、**`login_or_browser`**（Pixiv 兜底、LinkedIn 未知命令兜底）、**`http_or_cdp`**（新浪博客 / web / 微信 / barchart 等文章失败回退）、**`local_app`**（Antigravity）。
- **`jd/item`**：优先 **`article_pipeline.fetchPageArticle`**，失败回退 URL；注册项增加可选 **`--output`**；**`adapter_browser`** 为 `jd/item` 增加 `waitFor` + **`evaluate_light`**。
- **`linkedin`**：未覆盖子命令返回结构化 **`login_or_browser`**，避免静默落入 `null`。

## 已补齐（批次 37）

- **`HttpClient.applySiteCookieFromUrl`**：`std.Uri` 解析 host → **`hostToSiteKey`**（常见域名后缀映射到 adapter `site`）→ **`OPENCLI_<SITE>_COOKIE`**（首批映射表；批次 38 起由 **`request()`** 统一调用，见下）。

## 已补齐（批次 38）

- **`HttpClient.request`**：每次 **GET/POST**（及经 `get` 的 **download**）前 **`applySiteCookieFromUrl(url)`**，单条命令内跨域请求自动切换对应 **`OPENCLI_<SITE>_COOKIE`**；YAML 管线不再重复调用。
- **`hostToSiteKey`**：补充 **npmjs.org、juejin.cn、producthunt、unsplash、hn.algolia.com、noembed.com** 等映射。
- **`fetchJson`**：改为 **`parseFromSliceLeaky`**，避免误用 `parseFromSlice` 返回 `.value` 却未 **`deinit`** 的 **`Parsed`** 泄漏。

## 已补齐（批次 39 — JSON 生命周期 + Cookie 域名表）

- **`fetchNextDataJsonPage`**：`__NEXT_DATA__` 的 payload 改为 **`parseFromSliceLeaky`**，释放 `response.body` 前完成解析，避免 **`Parsed`** 泄漏。
- **`hnTopStories`**：item 详情去掉 **stringify → 再 parse** 往返，直接 **`parseFromSliceLeaky(ir.body)`** 后入数组。
- **`hostToSiteKey`**：补充 **维基 / Wikimedia**、**Google 子域**（news / suggestqueries / trends）、**Substack / Medium**、**Yahoo Finance**、**dictionaryapi.dev**、**Apple Podcasts**、**BOSS（zhipin）**、**Notion / Discord / Yollomi / Cursor**、**dev.to**、**news.ycombinator.com** 等，与 `http_exec` 常见请求 host 对齐。
- **`CacheManager.cacheJson`**：深拷贝回读 JSON 时改为 **`parseFromSliceLeaky`**，避免每次 `set` 泄漏一个未 **`deinit`** 的 **`Parsed`**。

## 对照迁移计划：仍缺项（非「missing 命令名」）

| 类别 | 说明 |
|------|------|
| **基线命令名** | 脚本口径 **`missing=0`**，本文件「未迁移站点」P0–P2 已清空。 |
| **行为等价** | 登录态写操作、桌面 CDP 全链路、反爬动态站、Turndown 级 MD 等仍按上文「深度迁移边界」处理。 |
| **工程/文档** | `scripts/check-doc-coverage.sh` 已改为对照 **`src/adapters/*.zig` 的 `pub const name`** 与 **`docs/adapters/browser|desktop/*.md`**；`discord-app` 等 **`*-app`** 站点可映射到去掉后缀的文档名。 |
| **YAML 子集** | 已支持 **`key:\n  nested:`**、**`commands:\n  - name: …`**（含续行 **`description:`** 等）、列表项内 **`args:\n      - name: …`** 嵌套；**`CliDefinition.fromYaml`** 已解析各命令下的 **`pipeline`** → **`types.PipelineDef`**（`type`/`step_type`、扁平 **`config`**）；**`pipeline.steps`** 的 **`-` 多字段块** 仍可能需扩展。 |
| **内存** | **`utils/cache.zig`** 已对 HTTP/JSON 缓存在 **`delete`/`clear`/`deinit`** 路径调用 **`destroyLeakyJsonValue`**（见批次 41）。 |
| **已知 Zig std 限制** | **`parseFromSliceLeaky`** 在 Zig 0.15.x 中存在 Scanner 的 `allocated_numbers` 泄漏（每次 JSON 解析少量内存未释放）。这是 Zig 标准库的已知问题，需要等待 Zig 版本更新或使用 `ArenaAllocator` 重构 API。CLI 工具每次命令执行量较小，可接受此限制。 |

## 已补齐（批次 40 — Cookie host + 文档覆盖脚本）

- **`hostToSiteKey`**：补充 **`registry.npmjs.org`**、**`api.npmjs.org`** → **`npm`**（与 `http_exec` 中 npm 请求 host 一致；`npmjs.org` 规则仍保留）。
- **`scripts/check-doc-coverage.sh`**：从已删除的 **`src/clis`** 改为扫描 Zig 适配器源码中的站点名，并检查 **`docs/adapters/browser`** / **`docs/adapters/desktop`**。
- **适配器文档占位**：为此前无页的注册站点补充 **`pypi`、`npm`、`crates`、`github`、`juejin`、`producthunt`、`unsplash`、`weather`、`news`、`daily`** 等 **browser** 侧 Markdown（与 `opencli list` 对齐，便于站点文档覆盖率 **63/63**）。

## 已补齐（批次 41 — 缓存/参数/YAML backlog）

- **`destroyLeakyJsonValue`** + **`Cache(T, free_fn)`**：HTTP 体与 JSON 树在 **`get` 过期、`delete`、LRU **`evict`、`clear`、`deinit`** 时正确释放；**`CacheManager.deinit`/`clearAll`** 简化为一律走缓存 **`deinit`/`clear`**。
- **`cli/args_parse`**：`parse` 入口 **`defer std.process.argsFree(allocator, argv)`**，对选项与 positional 均 **`dupe`**；**`ParsedArgs.deinit`** 统一释放；**`main`** 使用 **`defer cli.deinit(allocator)`**。
- **`utils/yaml`**：**`CliDefinition.fromYaml`** 解析 **`commands`**、**`args`** 与 **`pipeline`**；**`CliDefinition`/`CommandDefinition` 的 `deinit`** 释放 **`pipeline`**；单测覆盖无命令与手工树；原「嵌套 YAML」单测改为与当前解析器能力一致的扁平样例说明。

## 已补齐（批次 42 — YAML 缩进嵌套）

- **`YamlParser.parse`**：增加 **`ParseFrame` 缩进栈**（**`min_indent = 声明行缩进 + 1`**），支持 **`parent:\\n  child: value`** 与多层嵌套；**`- ` 列表**仍依赖 **`last_key`**，与旧逻辑兼容。
- **单测**：恢复 **`config` / `port` / `debug`** 嵌套样例，保留顶层扁平样例，并增加 **`a/b/c` 双级嵌套**。

## 已补齐（批次 43 — YAML 命令列表与稳定性）

- **`- k: v` 优先于** 含 **`:`** 的泛化 **`k: v` 行**，避免 **`- name: hot`** 误写入 **`"- name"`** 键。
- **`array_of_maps`**：用 **`merge_item_index`** 代替指向 **`items`** 元素的裸指针，避免扩容悬垂；**`stack.pop()` 前**保存 **`frame_min`**。
- **列表项续行**：支持 **`commands`** 下 **`- name:` + 缩进续行** 合并到同一 object。
- **列表项内嵌套块**：**`args:`**（等 **`key:`**）下可再接 **`- name: …`** 子列表（与空 object → array 转换链兼容）。
- **单测**：**`fromYaml`** 字符串集成（含 **`args`**）、**`commands` 块后顶层兄弟键**、**两条 command（首条含 args、次条纯项）**。

## 已补齐（批次 46 — 阶段 F/G：QuickJS + `list --tsv`）

- **依赖**：[mitchellh/zig-quickjs-ng](https://github.com/mitchellh/zig-quickjs-ng)（`build.zig.zon` 中 `quickjs_ng`）；`build.zig` 为根模块增加 `quickjs` import 并链接 **`quickjs-ng`**。
- **`src/plugin/quickjs_runtime.zig`**：`evalExpressionToString`；单测经 `tests.zig` 中 `comptime` 引用拉入。
- **`plugin.yaml`**：可选 **`js_init`**（相对插件目录的 `.js`），在 **`loadPlugin`** 内执行一次。
- **`list --tsv` / `list --machine`**：输出 **site、name、source、pipeline(0/1)、script(0/1)**（**`script=1`** 表示 **`Command.js_script_path`** 已配置）；**`scripts/compare_opencli_list.sh`** 默认无表头排序行；**`OPENCLI_LIST_HEADER=1`** 输出含表头 TSV。
- **命令级 `script`** + QuickJS 包装器内 **`opencli.args` / `opencli.version` / `opencli.log`（print）**（见 **`docs/PLUGIN_QUICKJS.md`**、`quickjs_runtime.zig`）。
- 文档：**`docs/PLUGIN_QUICKJS.md`**；**`docs/TS_PARITY_MIGRATION_PLAN.md`** 阶段 F/G 已勾选。

## 已补齐（批次 48 — TS 深度对齐：封顶文档与 L7 测试基线）

- **`docs/TS_PARITY_99_CAP.md`**：定义「计划迁移完毕」vs「~99.99% 可实现上限」、§3 有序剩余工作、§4 显式排除项；与 **`TS_PARITY_MIGRATION_PLAN`** / **`TS_PARITY_REMAINING`** 交叉引用。
- **Daemon（L7）**：`readHttpRequestFromStream`、`parseHttpRequest`、**`OPENCLI_DAEMON_AUTH_TOKEN`**（Bearer / `X-OpenCLI-Token` / `?token=`）、**POST/PUT/PATCH** JSON 体合并入 `/execute/...`、**OPTIONS**+CORS、**`dispatchHttpRequest`**；**`src/tests/daemon_contract_test.zig`**、**`src/tests/daemon_tcp_e2e_test.zig`**；**`main.zig`** `serve` 读 **`OPENCLI_DAEMON_*`**。
- **Explore / AI golden**：**`exploreFromHtml`**（`src/ai/explore.zig`）、**`src/tests/ai_explore_golden_test.zig`**、**`tests/fixtures/html/explore_sample.html`**、**`tests/fixtures/golden/synthesizer_golden.yaml`**。
- **L2 fixture**：**`tests/fixtures/json/stackoverflow_item_min.json`** + **`fixture_json_test`** 断言（与 `tests.zig` 内 SO 用例同构）。
- 文档：**`docs/DAEMON_API.md`**（鉴权、POST、环境变量、测试索引）、**`docs/TS_PARITY_REMAINING.md`** L7 行更新。

## 已补齐（批次 49 — L2 HTTP 缓存/重定向差异记录）

- **HTTP 缓存语义**：Zig 缓存由 `CacheManager` 管理，TTL 默认 `600s`（10分钟）；TS 版缓存策略需对照 `src/http/client.ts` 或实际行为。
- **重定向处理**：`HttpClient` 在 Zig 版默认 `follow_redirect=true`（`max_redirects=10`）；TS 版 axios/fetch 默认行为可能不同（max_redirects、redirect methods）。
- **差异影响**：相同命令相同参数可能因缓存状态或重定向链差异返回不同 `data`。
- **建议**：使用 `OPENCLI_CACHE=0` 禁用缓存后并排 diff；重定向链差异需人工审查 `Location` header。
- **记录位置**：`src/utils/cache.zig`（Zig 缓存实现）、`docs/TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md` § 第1波。

## 已补齐（批次 50 — 阶段 H.1：L2 fixture 扩展）

- **新增最小 JSON fixture**（与 `src/tests.zig` 内联结构同构，供 TS 侧片段对齐）：**`twitter_timeline_item_min.json`**、**`douban_movie_min.json`**、**`wikipedia_search_min.json`**、**`youtube_transcript_min.json`**。
- **`src/tests/fixture_json_test.zig`**：上述 4 个文件的 **`@embedFile`** + **`getNestedValue`** 断言。
- **脚本**：**`scripts/h_l2_ts_diff_suggestions.sh`** — 打印建议与 TS 版 `opencli … -f json` 并排 diff 的命令列表（需网络；配合 **`scripts/compare_command_json.sh`**）。
- **对应规划**：**`TS_PARITY_MIGRATION_PLAN.md` §6.2** 波次 **H.1**。

## 已补齐（批次 66 — L2 P0.5 / L5 P3.2：五条命令并排导出脚本 + HTML→MD 包装示例）

- **L2 / P0.5**：**`scripts/parity_p0_5_export_zig.sh`**（**`OPENCLI_CACHE=0`**，输出 **`parity-output/zig/*.json`**）、**`parity_p0_5_export_upstream.sh`**（**`record_jackwener_baseline.sh`** 批量）、**`parity_p0_5_diff.sh`**（**`diff -u`** 同名文件）；**`.gitignore`** 增加 **`parity-output/`**。
- **L5 / P3.2**：**`examples/html_to_md_pandoc_wrap.sh`**（**`pandoc -f html -t gfm`**）；**`MARKDOWN_ARTICLE_PIPELINE.md`** 补充脚本接口与示例命令。
- **文档**：**`docs/PARITY_PROGRESS.md`** — P0.5、P3.2 状态与「下一步」刷新；**`scripts/l2_p0_routine.sh`** 增加 P0.5 一键三条脚本提示。

## 已补齐（批次 65 — L7：Daemon 未知命令 404 + L2 基线脚本 + 对齐进度总表）

- **`src/daemon/daemon.zig`**：**`/execute/{site}/{cmd}`** 在注册表中不存在时 **404** + **`{"error":"Command not found"}`**（有/无 runner、有/无执行超时路径均一致）；仍 **500** 的为其它执行错误。
- **`src/tests/daemon_contract_test.zig`**：未知命令 **404**；无 runner 且命令存在仍 **503**；补充「无 runner + 未知命令 → **404**」。
- **`scripts/record_jackwener_baseline.sh`**：对上游 **`npx @jackwener/opencli … -f json | jq -S`** 落盘，供 **`compare_command_json.sh --diff-ts`**；可选 **`JACKWENER_OPENCLI_PKG`** pin 版本。
- **`docs/PARITY_PROGRESS.md`**：P0–P4 任务状态、**基线记录**表、下一步顺序。
- **`docs/DAEMON_API.md`**：「待对照项」未知命令行更新。
- **`scripts/l2_p0_routine.sh`**：增加 **`record_jackwener_baseline.sh`** 与 **`PARITY_PROGRESS.md`** 提示。

## 已补齐（批次 64 — 文档：明确 TS 能力对照基线为 jackwener/opencli）

- **`docs/UPSTREAM_REFERENCE.md`**：官方上游 [**jackwener/opencli**](https://github.com/jackwener/opencli)、npm、并排 diff 约定、上游能力 vs Zig 摘要表。
- **交叉引用**：**`MIGRATION_GAP.md`** 文首、**`TS_PARITY_REMAINING.md`**、**`TS_PARITY_MIGRATION_PLAN.md`**、**`TS_PARITY_99_CAP.md`**、**`TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md`**、**`README.md`**（英文「Parity」段）。

## 已补齐（批次 63 — P2：L3 扩 Zig+Chrome CI；L6 `opencli.http` 错误码细对照）

- **L3 / `.github/workflows/zig-chrome-ci.yml`**：`paths` 扩至 **`more_sites.zig`**、**`chinese.zig`**、**`http_exec.zig`**、**`CDP_SCENARIO_MATRIX.md`**；新增 **`sinablog/article`**、**`jd/item`** 烟雾（Linux **`xvfb-run`** + macOS；**`|| true`**）；**`schedule: 0 10 * * 3`** 周更。
- **L6 / `src/plugin/quickjs_runtime.zig`**：**`HttpError`** → JS 可见 **`{\"error\":\"http_error\"}`**（与泛 **`request_failed`** 区分）；**`opencli_plugin_api_version` → 0.2.3**。
- **文档**：**`PLUGIN_QUICKJS.md`** — **`opencli.http` `error` 表** + TS 对照说明；**`CDP_SCENARIO_MATRIX.md`** — CI 交叉引用；**`TS_PARITY_REMAINING` / `TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE`** P2。

## 已补齐（批次 62 — L4/L7 P1：站点边界签字矩阵 + Daemon 单测扩面）

- **L4 / `docs/AUTH_AND_WRITE_PATH.md`**：新增 **「P1：高频站点读/写边界签字矩阵」**（公开读/需登录/写路径/与 TS 对齐方式/验收口径；与 **`CDP_SCENARIO_MATRIX`**、**`regression_cookie_writepath.sh`** 交叉引用）。
- **L7 / `src/tests/daemon_contract_test.zig`**：**`X-OpenCLI-Token`** 鉴权、错误 **Bearer→401**（JSON **`Unauthorized`**）、**`OPTIONS`** 在配置 **`auth_token`** 时仍 **204**、**`GET /execute`** 未知命令 **500**（含 `Command execution failed` 片段）。
- **L7 / `src/tests/daemon_tcp_e2e_test.zig`**：**`GET /`** 根响应、鉴权开启无头 **401**、**`X-OpenCLI-Token`** TCP 全链路 **200**。
- **文档 / `docs/DAEMON_API.md`**：Tests 表与「待对照项」更新；L7 签字日期刷新。
- **交叉引用**：**`TS_PARITY_REMAINING.md`** §三 P1、**`TS_PARITY_99_CAP.md`** §3.5–3.6。

## 已补齐（批次 61 — L2 P0：`l2_p0_routine` + `compare_command_json --diff-ts` + 手动 CI）

- **`scripts/l2_p0_routine.sh`**：仓库根执行 → **`zig build test`**（含 **`fixture_json_test`**）→ 打印 **`h_l2_ts_diff_suggestions.sh`** 与 **`compare_command_json.sh --diff-ts`** 示例（建议 **`OPENCLI_CACHE=0`**）。
- **`scripts/compare_command_json.sh`**：新增 **`--diff-ts <file>`**，对 Zig 与 TS 已导出 JSON 做 **`jq -S`** 后 **`diff -u`**；**exit 0** 一致、**exit 1** 有差异（便于本地/CI 判红）。
- **`scripts/h_l2_ts_diff_suggestions.sh`**：头注释指向 **`l2_p0_routine.sh`**。
- **`.github/workflows/l2-json-parity-dispatch.yml`**：**`workflow_dispatch`** 仅跑 **`zig build test`**，与 **`zig-ci`** 互补，命名便于「L2 发版前点跑」。
- **文档**：**`TS_PARITY_REMAINING.md`** §三 P0、§四 L2；**`TS_PARITY_99_CAP.md`** §3.2。

## 已补齐（批次 59 — L2：`executeFetch` 缓存单测 + mock GET）

- **`PipelineContext.initForTesting`** / **`PipelineExecutor.initForTesting`**：可强制挂载 **`CacheManager.init`**（不受 **`OPENCLI_CACHE`** 影响），便于不入网用例。
- **`PipelineExecutor.test_fetch_get`**：**GET** 时替代 **`http_client.get`**；**`TestFetchGetFn`** / **`TestFetchGetResponse`**。
- **`src/tests/pipeline_fetch_cache_test.zig`**：两次 **`execute`** 同 URL 时 mock 只调用一次；**`extract`** 在缓存命中后仍生效。

## 已补齐（批次 60 — L5：`html_to_md_simple` 行内规则 + 块级贯通）

- **`src/adapters/html_to_md_simple.zig`**：行内 **`<strong>`/`b`、`<em>`/`i`、`<code>`、`<del>`/`s`/`strike`、`![alt](src)`**（需 **`src`**）、**`<br>`**、HTML 注释等；**`h1`–`h6`、`p`、`li`、`blockquote`、表格 `th`/`td`、顶层带 `href` 的 `a`** 的内文统一走 **`convertInlineFragment`**，与行内规则一致（不再用 **`html_extract`** 纯文本摘录）。
- **边界**：**`<i>`/`s`** 与 **`<img`、`<iframe`、`<span`** 等区分，避免误匹配。
- **单测**：段落内行内组合、标题/引用行内、表内 **strong**、**`<span>`** 路径。
- **文档**：**`MARKDOWN_ARTICLE_PIPELINE.md`**、**`TS_PARITY_REMAINING.md`**（§二 L5、§四 签字矩阵）、**`TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md`**（总览表 HTML→MD 一行）。

## 已补齐（批次 58 — L6：`opencli.http` 支持 **HEAD**）

- **`src/http/client.zig`**：新增 **`head()`**；**`request(.HEAD, …)`** 使用 curl **`-I`**（不用 **`-X HEAD`**）；HEAD 不附带 **body** / **Content-Type** 参数。
- **`src/plugin/quickjs_runtime.zig`**：**`httpHeadSync`**、**`nativeHttpHead`**（由 **`nativeHttpRequest`** 在 **`method`** 为 **HEAD** 时调用）；**`opencli_plugin_api_version` → 0.2.2**；单测 **`httpHeadSync`** 白名单 / https 拒绝。
- **`docs/PLUGIN_QUICKJS.md`**：方法表与安全模型更新。

## 已补齐（批次 57 — L2：YAML `pipeline` 的 `fetch` 步骤 JSON 缓存）

- **`PipelineExecutor.executeFetch`**：**GET** 与 **`http_exec.fetchJson`** 共用 **`PipelineContext.http_json_cache`**（键为渲染后 URL；**`OPENCLI_CACHE=0`** 时与适配器一致不缓存）；**POST** 不缓存。
- 缓存存**完整**响应 JSON；**`extract`** 在缓存命中后仍执行（与适配器侧「先整包再截取」一致）。
- **文档交叉引用**：**`TS_PARITY_REMAINING.md` §二 L2**、**§四** 备注可写「含 pipeline **`fetch`**」。

## 已补齐（批次 56 — L2/L7 持续优化：适配器 JSON 缓存接线 + HN id 列表 fixture）

- **`PipelineContext.http_json_cache`**：**`OPENCLI_CACHE=0`** 时不创建缓存（与 diff 脚本一致）；否则 **`CacheManager.initFromEnv`**。
- **`http_exec.fetchJson`**：命中 **`getCachedJson(url)`** 时 stringify→`parseFromSliceLeaky` 克隆到调用方 **`allocator`**；未命中则网络拉取后 **`cacheJson(url, v)`**（失败忽略）。
- **`http_exec.hnTopStories`**：**`topstories` / `newstories` 等** 的 **id 列表 URL** 与各 **`…/v0/item/{id}.json`** 均复用 **`fetchJson`**（与上项缓存一致）。
- **`utils/cache.zig`**：**`adapterHttpJsonCacheDisabledByEnv`**；单测覆盖缓存命中克隆路径。
- **L2 fixture**：**`tests/fixtures/json/hn_firebase_top_ids_min.json`**（Firebase **`v0/topstories.json`** 形状片段）+ **`fixture_json_test`**。
- **`docs/DAEMON_API.md`**：补充 **`OPENCLI_CACHE`** 与适配器缓存说明（**`serve`** 与 CLI 同进程语义）。
- **流程**：**`docs/TS_PARITY_REMAINING.md` §四** 更新为 **L2–L7 签字矩阵快照**（与本文批次交叉引用，持续推进用）。

## 已补齐（批次 55 — L2/L7/L5/L6 横切：HTTP 环境变量、Daemon 执行超时、HTML→MD、插件 HTTP 体上限）

- **L2 / `src/http/client.zig`**：**`OPENCLI_HTTP_FOLLOW_REDIRECTS`**（`0` 关闭 **`-L`**）、**`OPENCLI_HTTP_MAX_REDIRECTS`**（**`--max-redirs`**，默认 **10**）、**`OPENCLI_HTTP_MAX_OUTPUT_BYTES`**（**`Child.run.max_output_bytes`**，默认 **20 MiB**）。
- **L2 / `src/utils/cache.zig`**：**`CacheManager.initFromEnv`** 读 **`OPENCLI_CACHE_HTTP_TTL_MS`** / **`OPENCLI_CACHE_JSON_TTL_MS`** / **`OPENCLI_CACHE_HTTP_MAX`** / **`OPENCLI_CACHE_JSON_MAX`**（业务路径接线可后续接入）。
- **L7 / `src/daemon/daemon.zig`**：**`DaemonConfig.execute_timeout_ms`** + **`OPENCLI_DAEMON_EXECUTE_TIMEOUT_MS`**；**`>0`** 时用 **`std.Thread` + `ResetEvent.timedWait`** 包裹 **`runAndGetResultWithAllocator`**（工作线程内 **Arena**）；超时 **504**；主线程 **`join`**；**`src/cli/runner.zig`** 新增 **`runAndGetResultWithAllocator`**。
- **L5 / `src/adapters/html_to_md_simple.zig`**：**`<hr>`** → **`---`**；极简 **`<table>`**（**`<tr>`/`th`/`td`**，首行全 **`th`** 时 GFM 分隔行）+ 单测。
- **L6 / `src/plugin/quickjs_runtime.zig`**：响应体超过 **`OPENCLI_PLUGIN_HTTP_MAX_BODY_BYTES`**（默认 **2 MiB**）→ **`error.ResponseBodyTooLarge`** → JS 侧 **`body_too_large`**。
- **文档**：**`docs/DAEMON_API.md`**、**`docs/PLUGIN_QUICKJS.md`**、**`docs/TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md`**。

## 已补齐（批次 54 — L7：Daemon 读请求超时，贴近 TS「有超时」语义）

- **`readHttpRequestFromStream`**：新增参数 **`read_timeout_ms`**；`>0` 时用 **`std.posix.poll`** 在 **`stream.read`** 前等待可读，并以 **`std.time.Instant`** 约束**整段请求读取**总时长；错误 **`ReadTimeout`** 时 **`readAndDispatch`** 写 **HTTP 408** + `{"error":"Request read timeout"}`。
- **`DaemonConfig.request_timeout_ms`**：默认 **30000**；**`serve`** 启动时读 **`OPENCLI_DAEMON_REQUEST_TIMEOUT_MS`**（**`0`** = 不限制，与旧行为一致）。
- **`docs/DAEMON_API.md`**、**`docs/TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md`**：环境变量与「Zig vs TS」表更新。
- **调用点**：**`daemon_tcp_e2e_test`** 传 **`0`** 避免单测受超时影响。

## 已补齐（批次 53 — 阶段 H.1 / H.4 深入）

- **H.1 / L2**：**`hn_item_min.json`** 补 **`time`**，与 **`src/tests.zig`** HN 内联用例一致；新增 **`github_trending_array_min.json`**、**`stackoverflow_items_wrapper_min.json`** + **`fixture_json_test`**；**`h_l2_ts_diff_suggestions.sh`** 扩展 wikipedia / douban 命令与 **`OPENCLI_CACHE=0`** 提示；**`compare_command_json.sh`** 头注释补充缓存环境变量。
- **H.4 / L5–L7**：**`MARKDOWN_ARTICLE_PIPELINE.md`** 增加 **H.4 与 TS 对照清单**；**`DAEMON_API.md`** L7 签字 **TBD→ZZ**，测试索引含 **`explore_edge_min.html`**；**`tests/fixtures/html/explore_edge_min.html`** + **`ai_explore_golden_test`**「无 `/api/` 提示」标题断言。

## 已补齐（批次 52 — 阶段 H.2 / H.3：P1–P2 交付收口）

- **H.2 / 第 2 波**：**`docs/CDP_SCENARIO_MATRIX.md`** 与 **`zig-chrome-ci.yml`** 交叉引用说明（矩阵已签字）；**`docs/AUTH_AND_WRITE_PATH.md`** OAuth / 设备码决策表 **Wave 2.2** 签字列由 TBD 收口为 **ZZ**；**`scripts/regression_cookie_writepath.sh`** 汇总 Cookie 写路径手工回归命令（正文仍以 **`AUTH_AND_WRITE_PATH.md`** 为准）。
- **H.3 / 第 3 波**：**`zig-chrome-ci.yml`** 增加矩阵第二场景 **`zhihu/download`** 烟雾（`|| true`，防反爬导致 job 红）；路径过滤纳入 **`quickjs_runtime.zig`** / **`runner.zig`**。
- **QuickJS HTTP 桥（3.2）**：**`src/plugin/quickjs_runtime.zig`** 在 QuickJS 全局注册 **`__opencli_http_*`** 原生函数，修正此前仅 JS 包装、未绑定宿主实现的问题；**`opencli_plugin_api_version` → 0.2.1**；单测覆盖 **`httpGetSync`/`httpPostSync`** 白名单与 **https** 拒绝（无网络）。
- **Node 子进程硬化（3.3）**：**`src/cli/runner.zig`** — **`OPENCLI_NODE_SUBPROCESS_TIMEOUT_MS`**（默认 120s，**`0`** 关闭）、**`OPENCLI_NODE_MAX_OUTPUT_BYTES`**；POSIX 下超时 **detach** 线程 **`SIGKILL`**；**`errdefer child.kill`**。**`docs/PLUGIN_QUICKJS.md`** 已更新。

## 已补齐（批次 51 — 阶段 H.1：L2 fixture 与 Reddit 热帖形状修正）

- **修正**：**`reddit_hot_item_min.json`** 增加与 **`getNestedValue(..., "data.*")`** 一致的 **`data`** 包装层（与 Reddit 列表项常见结构对齐）。
- **新增 fixture**（与 **`src/tests.zig`** 内联用例同构）：**`bilibili_dynamic_archive_fallback_min.json`**（无 `desc.text`、走 **`major.archive.title`**）、**`reddit_read_comments_min.json`**（读帖线程数组 POST/L0）、**`npm_package_registry_meta_min.json`**（含 **`time.modified`** 的 registry 元数据形状，区别于字段更全的 **`npm_package_min.json`**）。
- **`src/tests/fixture_json_test.zig`**：上述 3 个新文件 + **`bilibili_dynamic_archive_fallback`** 断言；**`reddit_hot`** 仍覆盖包装后路径。

## 已补齐（批次 47 — 阶段 E：内置简化 HTML→MD）

- **`src/adapters/html_to_md_simple.zig`**：`convert` 支持 **`h1`–`h6`**、**`p`**、**`li`**、**`br`**、**`pre`**（围栏代码）、**`blockquote`**（`> `）、带 **`href`** 的 **`a`** 与少量实体解码；单测覆盖标题/段落/链接/列表/代码/引用。（**行内标签与块级贯通**见 **批次 60**。）
- **`article_pipeline.processHtmlArticle`**：在 **`OPENCLI_HTML_TO_MD_SCRIPT`** 未成功时，若 **`OPENCLI_BUILTIN_HTML_TO_MD=1`** 则用内置转换作为 **`markdown` 正文**。
- **Zig 0.15.x**：插件参数 JSON 使用 **`std.json.Stringify.valueAlloc`**；内置 HTML→MD 与 QuickJS 包装器使用 **`ArrayList(u8) = .empty`** + **`deinit(allocator)`** / **`append(allocator, …)`**；**`build.sh`** / **`README`** 说明 **`ZIG_GLOBAL_CACHE_DIR=./.zig-global-cache`** 以便沙箱或不可写家目录缓存时仍能 **`zig build`**（依赖已缓存后无需网络）。
- **GitHub Actions**：**`.github/workflows/zig-ci.yml`** 并行运行 **`zig build test`**（与 Node **`ci.yml`** 独立）；**`format.zig`** 暴露 **`formatJsonValue` / `formatTable`** 供 **`integration_tests`**；**`adapter_test_helpers`** 中 **`MockHttpClient`** 对齐 **`ArrayList`** 新 API。
- 文档：**`docs/MARKDOWN_ARTICLE_PIPELINE.md`**、**`docs/TS_PARITY_MIGRATION_PLAN.md`** 阶段 E / L5。

## 已补齐（批次 45 — 阶段 B：多命令 YAML + manifest TS 策略）

- **`discovery.loadYamlFile`**：根级 **`commands:`** 为 **object**（map）或 **array** 时展开多命令；子命令继承根级 **`site`/`domain`/`strategy`/`browser`/`description`**（子项优先）。示例见仓库根 **`examples/bilibili.yaml`**（可放到 `~/.opencli/clis/<site>/` 或 `src/clis/<site>/` 下加载）。
- **`commandFromYamlObject`**：单命令体解析与继承逻辑复用。
- **`cli-manifest.json`**：**`type: yaml`** 条目改为堆拷贝字段，**`source=manifest_yaml`**（避免 JSON 缓冲区释放后悬垂）。
- **`type: ts`**：注册 **`source=ts_legacy`**，**`module_path`** 归 Registry 堆所有；运行时由 **`runner`** 返回 **`ts_adapter_not_supported`** JSON（不执行 Node）。
- 计划与矩阵文档：**`docs/TS_PARITY_MIGRATION_PLAN.md`**（阶段 B 勾选）、**`docs/CDP_SCENARIO_MATRIX.md`**、**`docs/AUTH_AND_WRITE_PATH.md`**、**`docs/MARKDOWN_ARTICLE_PIPELINE.md`**；列表对比 **`scripts/compare_opencli_list.sh`**。

## 已补齐（批次 44 — YAML pipeline 与插件命令执行）

- **`yaml.zig`**：`parsePipelineDefFromYaml`、`parseRuntimeArgsFromYaml`、`parseRuntimeColumnsFromYaml`；**`CliDefinition.CommandDefinition.pipeline`** 使用 **`types.PipelineDef`**；**`fromYaml`** 填充 **`pipeline`**。
- **`plugin/manager.zig`**：**`plugin.yaml`** 内命令可带 **`pipeline`/`args`/`columns`/`strategy`/`browser`/`domain`**；**`cmd_refs`** 记录已注册命令以便卸载；**`register` 失败** 时 **`errdefer`** 注销。
- **`discovery.zig`**：用户目录 **`~/.opencli/clis/<site>/<cmd>.yaml`** 根级 **`pipeline`** 等字段堆分配注册（**`source=yaml`**）。
- **`types.zig`**：**`pipelineDefDeinit`**、**`destroyHeapCommandIfNeeded`**；**`Registry.deinit`/`unregisterCommand`** 释放 **`plugin`/`yaml`** 命令堆字段。
- **`pipeline/executor.zig`**：步骤间 **`data`** 变量（JSON 字符串）；**`fetch`** 支持 **`extract`**（子树深拷贝）；**`transform`** 支持 **`operation: limit`**；模板 **`{{args.xxx}}`** 解析。
- 详细阶段计划见 **`docs/TS_PARITY_MIGRATION_PLAN.md`**。

## 验收标准

1. `zig build` 通过
2. `opencli list` 稳定输出（无崩溃）
3. 每批新增命令至少完成：
   - 注册成功
   - 参数可解析
   - HTTP/浏览器执行链路可跑
4. 每批提交能力对照表（新增、未完成、阻塞原因）
