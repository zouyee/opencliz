# 与 TypeScript 版「完全能力」对齐：剩余工作与封顶说明

> **English — what the Zig port supports today:** **`docs/CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md`**.

> **对照上游**：[**jackwener/opencli**](https://github.com/jackwener/opencli)（详见 **`docs/UPSTREAM_REFERENCE.md`**）。  
> 配合 **`docs/TS_PARITY_MIGRATION_PLAN.md`**（阶段 A–G **+ §6 阶段 H 最新规划**）、**`docs/MIGRATION_GAP.md`**（命名 `missing=0` 与批次历史）阅读。  
> **结论先行**：仓库内 **阶段 A–G 所承诺的工程交付已全部完成**（见迁移计划勾选）。  
> 「与 TS 版在**每一次请求、每一种登录态、每一条 DOM 路径**上均 100% 字节级一致」**不是**本仓库单次里程碑目标；在开源与无统一用户凭据的前提下也**无法保证全站在线可复现**。后续工作按 **L2–L7 分层对照 + 签字矩阵** 推进，本文给出**可执行任务分解**与**封顶口径**。  
> 若需把「尽量对齐 TS / ~99.99%」说成**可勾选、可签字**的清单，见 **`docs/TS_PARITY_99_CAP.md`**。

---

## 一、两种「迁移完毕」的定义

| 含义 | 状态 | 依据 |
|------|------|------|
| **计划交付完毕（阶段 A–G）** | ✅ 已完成 | `TS_PARITY_MIGRATION_PLAN.md` 第 2 节全部勾选 |
| **基线命令名对齐** | ✅ `missing=0` | `MIGRATION_GAP.md` 统计口径 |
| **产品深度等价（L0–L7 全绿）** | 持续进行 / 部分不可封顶 | 依赖真实站点、账号、OAuth、反爬、桌面应用与法律边界 |

---

## 二、分层剩余工作（对照 `TS_PARITY_MIGRATION_PLAN` 第 1 节）

### L2 — HTTP 行为

| 内容 | 剩余工作 | 封顶 / 验收 |
|------|----------|-------------|
| 公开 API、重定向、Cookie、缓存 | **已接**：适配器 **`fetchJson`** 进程内 JSON 缓存（**`OPENCLI_CACHE=0`** 关闭）、**`hnTopStories` 列表+item URL 同缓存**（**批次 56**）；YAML **`pipeline` `fetch` GET 同缓存**（**批次 57**）；curl **`OPENCLI_HTTP_*`**（**批次 55**）。**仍持续**：扩充 **`tests/fixtures/json/`**、**`h_l2_ts_diff_suggestions.sh`** / **`compare_command_json.sh`** 与 TS **`jq -S` diff**（diff 前建议 **`OPENCLI_CACHE=0`**） | 站点改版导致漂移时，以结构化 **`status`** + **`MIGRATION_GAP`** 批次说明为准，不承诺永久在线 |

### L3 — 浏览器（CDP vs Playwright）

| 内容 | 剩余工作 | 封顶 / 验收 |
|------|----------|-------------|
| `browser: true` 关键路径 | **`CDP_SCENARIO_MATRIX.md`** 已签字；**`zig-chrome-ci.yml`**（**批次 63**）跑 **web/read、zhihu/download、weixin/download、sinablog/article、jd/item**（部分 **`|| true`**）+ 可选 **周 schedule** | 架构不同（Playwright ≠ CDP），只承认**矩阵内场景**等价 |

### L4 — 认证与写路径

| 内容 | 剩余工作 | 封顶 / 验收 |
|------|----------|-------------|
| Cookie / OAuth / 站点私有 API | OAuth **设备码**书面不实现（**`AUTH_AND_WRITE_PATH.md`** Wave 2.2 已签字）；写路径手工回归见 **`scripts/regression_cookie_writepath.sh`** | 无用户凭据时 **`login_required`** 等 **status** 即为合规验收；**不承诺**复刻全部 TS 私有集成 |

### L5 — 富文本与图片

| 内容 | 剩余工作 | 封顶 / 验收 |
|------|----------|-------------|
| Turndown 级 HTML→MD、完整图片管线 | 外部脚本仍优先；**内置简化器**已扩 **行内 + 块级贯通**（**批次 60**，见 **`MIGRATION_GAP.md`**）；对照仍用 **`MARKDOWN_ARTICLE_PIPELINE.md`** § **H.4**（**批次 53**） | **不承诺**与 Turndown 逐规则一致；不承诺旧版完整媒体管道 |

### L6 — 插件运行时

| 内容 | 剩余工作 | 封顶 / 验收 |
|------|----------|-------------|
| TS 插件 / 全量 Node API | **已具备**：**`opencli.http`**（**GET** / **POST** / **HEAD**；**`error` 细表 + `http_error`** **批次 63**；**`opencli_plugin_api_version` 0.2.3**）；**Node 子进程**超时/输出上限（**`PLUGIN_QUICKJS.md`**） | **`ts_legacy`** 存根为既定策略；全量 Node API **非目标** |

### L7 — 运维与 AI

| 内容 | 剩余工作 | 封顶 / 验收 |
|------|----------|-------------|
| Daemon、explore、generate、synthesize | **已具备**：读请求超时（**批次 54**）、可选 **`/execute` 执行超时**（**批次 55**）；**`daemon_*_test`**（**批次 62** + 未知命令 **404** **批次 65**）；**`DAEMON_API.md`**、**`explore_edge_min`**（**批次 53**）。**仍持续**：与 TS 扩展端点 / 模型链 **逐项对照** | WebSocket、批量执行等见 **`DAEMON_API.md`**「Zig vs TS」**N/A** |

---

## 三、Backlog 建议（可在 Issue 中拆单）

| 优先级 | 事项 | 说明 |
|--------|------|------|
| P0 | L2：核心公开命令 fixture + 与 TS JSON 输出 diff | **`scripts/l2_p0_routine.sh`**、**`record_jackwener_baseline.sh`**（上游 **`jq -S`** 落盘）、**`compare_command_json.sh --diff-ts`**；**`docs/PARITY_PROGRESS.md`** 跟进 **P0.4–P0.5**。CI：手动 **`L2 JSON parity (P0 dispatch)`** |
| P1 | L4：选 1～2 个高频站点的 OAuth 或文档级「本仓库不支持设备码」签字 | **已补**：**`AUTH_AND_WRITE_PATH.md`** **P1 高频站点读/写边界签字矩阵**（与 Wave 2.2、CDP 矩阵并用）；设备码仍 **不实现** |
| P1 | L7：Daemon 最小契约测试（HTTP API） | **已扩（批次 62）**：**`X-OpenCLI-Token`**、错误 Bearer、**OPTIONS** 免鉴权、未知命令 **500**、TCP **`GET /`** / **401** / 头鉴权；**`DAEMON_API.md`** 已更新；与 TS 全量端点/WebSocket/批量仍 **逐项对照** |
| P2 | L3：Zig + Chrome 的 CI 子集 | **已扩（批次 63）**：**`zig-chrome-ci.yml`** — **`sinablog/article`**、**`jd/item`** + **`more_sites`/`chinese`/`http_exec`** 路径触发 + **周 schedule**；见 **`CDP_SCENARIO_MATRIX.md`** |
| P2 | L6：QuickJS **`opencli.http`** | **已细对照（批次 63）**：**`PLUGIN_QUICKJS.md`** **`error` 表**；**`http_error`** vs **`request_failed`**；**`opencli_plugin_api_version` 0.2.3** |

---

## 四、签字矩阵（仓库内快照 · 持续推进）

> **用途**：把「L2–L7 + 文档/测试」收敛成**可勾选**的一页；与 **§二** 剩余工作并用。TS 侧无单一 commit 时，**对照基线**填「本仓库 + 文档锚点」。更新本表时请改 **日期** 并在 **`MIGRATION_GAP.md`** 补批次（若含代码变更）。

| 层级 | 覆盖范围（站点/场景） | 对照基线 | 签字 | 日期 | 备注 |
|------|------------------------|----------|------|------|------|
| **L2** | fixture + **`l2_p0_routine.sh`** / **`record_jackwener_baseline.sh`** / **`compare_command_json.sh`**（**`--diff-ts`**）；**`PARITY_PROGRESS.md`**；**`fetchJson` / `hnTopStories` / pipeline `fetch`（GET）** JSON 缓存（**`OPENCLI_CACHE=0`**）；**`OPENCLI_HTTP_*`**；**`pipeline_fetch_cache_test`** mock（**批次 59**） | **`MIGRATION_GAP`** 批次 50–65；**`tests/fixtures/json/`** | ZZ | 2026-04-01 | 在线漂移以 **`status`** + 批次封顶 |
| **L3** | 矩阵内 weixin/web/zhihu/sinablog/jd + 通用 **N/A** | **`CDP_SCENARIO_MATRIX.md`**；**`zig-chrome-ci.yml`**（**批次 63** 五场景 + 周跑） | ZZ | 2026-04-01 | Playwright ↔ CDP **API 级不对等** |
| **L4** | Cookie 注入、写路径文档、OAuth 决策、**P1 站点边界矩阵** | **`AUTH_AND_WRITE_PATH.md`** Wave 2.2 + **§ P1 签字矩阵**；**`regression_cookie_writepath.sh`** | ZZ | 2026-04-01 | 设备码 **不实现**；深度私有 API **不承诺** |
| **L5** | 文章管线、H.4 对照、内置 HTML→MD 增量 | **`MARKDOWN_ARTICLE_PIPELINE.md`** § H.4；**`html_to_md_simple`**（hr/table **批次 55** + 行内/块贯通 **批次 60**） | ZZ | 2026-04-01 | **非** Turndown 逐规则对等 |
| **L6** | QuickJS `script`/`js_init`、**`opencli.http`**（含 **HEAD**、**`error` 细表 批次 63**）、Node 子进程硬化 | **`PLUGIN_QUICKJS.md`**；**`quickjs_runtime.zig`** 单测 | ZZ | 2026-04-01 | 全量 Node 内置模块 **非目标** |
| **L7** | Daemon 契约 + TCP e2e；读/执行超时；explore/synthesize golden | **`DAEMON_API.md`**（含 L7 表；未知命令 **404** **批次 65**）；**`daemon_*_test`**、**`ai_explore_golden_test`** | ZZ | 2026-04-01 | WebSocket / 批量 **N/A**（见 DAEMON_API） |

**复制用空模板**（新建项目或重置快照时）：

```
层级 | 覆盖范围 | 对照基线 | 签字 | 日期 | 备注
L2   |          |          |      |      |
L3   | 见 CDP_SCENARIO_MATRIX |  |      |      |
...
```

---

## 五、相关文档索引

| 文档 | 用途 |
|------|------|
| [TS_PARITY_MIGRATION_PLAN.md](./TS_PARITY_MIGRATION_PLAN.md) | 阶段 A–G 与 L0–L7 总表 |
| [MIGRATION_GAP.md](./MIGRATION_GAP.md) | 命名对齐、批次历史、深度边界 |
| [CDP_SCENARIO_MATRIX.md](./CDP_SCENARIO_MATRIX.md) | L3 |
| [AUTH_AND_WRITE_PATH.md](./AUTH_AND_WRITE_PATH.md) | L4 |
| [MARKDOWN_ARTICLE_PIPELINE.md](./MARKDOWN_ARTICLE_PIPELINE.md) | L5 |
| [PLUGIN_QUICKJS.md](./PLUGIN_QUICKJS.md) | L6 |
| [DAEMON_API.md](./DAEMON_API.md) | L7 |
| [TS_PARITY_99_CAP.md](./TS_PARITY_99_CAP.md) | 「~99.99%」可实现上限、剩余勾选、显式排除 |
| [TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md](./TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md) | **TS vs Zig 能力差距表 + 分波排期** |
| [UPSTREAM_REFERENCE.md](./UPSTREAM_REFERENCE.md) | **上游基线：jackwener/opencli**（npm、diff 方式、能力映射） |
| [PARITY_PROGRESS.md](./PARITY_PROGRESS.md) | **对齐进度总表**（P0–P4、基线记录、下一步） |

---

*文档版本：2026-04-01 · 上游基线见 **`UPSTREAM_REFERENCE.md`**；进度见 **`PARITY_PROGRESS.md`**；「计划 A–G」已闭环；L2–L7 **签字快照**见 **§四**；批次历史见 **`MIGRATION_GAP.md`**（含 **55–65** 等）；封顶语义见 **`TS_PARITY_99_CAP.md`**。*
