# 「与 TS 版 ~99.99% 能力」：定义、计划对照与封顶清单

> 本文把口语里的 **「尽量完全对齐 TS」** 落成**可验收**的表述；**TS** 默认指上游 [**jackwener/opencli**](https://github.com/jackwener/opencli)（见 **`docs/UPSTREAM_REFERENCE.md`**）。与 **`TS_PARITY_MIGRATION_PLAN.md`**（阶段 A–G）、**`TS_PARITY_REMAINING.md`**（L2–L7）一一对应。  
> **重要**：**99.9999%** 不是可计算的精确比例；下文用 **「可实现上限（cap）」** 表示：在**不引入 Node 内嵌、不承诺全站在线、不持有用户密钥**的前提下，本仓库**理论上仍能通过工程手段逼近**的边界。

---

## 1. 三种「迁移完毕」不要混用

| 口径 | 含义 | 当前状态 |
|------|------|----------|
| **A–G 书面交付** | 迁移计划第 2 节勾选项 | ✅ **已全部完成** |
| **L0 基线命名** | `site/command` 与历史 `src/clis` 统计 `missing=0` | ✅ **已完成** |
| **L2–L7 深度等价** | HTTP/浏览器/登录/文章/插件/Daemon 等与 TS 在**签字矩阵**内一致 | ⚠️ **持续项**；部分条目**不可封顶**（见 §4） |

**结论**：若你的目标是 **「计划迁移完毕」** → **已达到**。  
若目标是 **「与 TS 产品行为在全网、全账号、全 DOM 上几乎完全一致」** → **无有限工期**；只能以 **§3 清单 + 签字矩阵** 逼近 **可实现上限**。

---

## 2. 已实现能力（≈ 高权重对齐段）

下列项在仓库内**已有代码 + 测试或文档**，对应 TS 版「主路径」中的大块能力：

- **L0/L1**：命令注册、YAML `pipeline`、多命令单文件、`ts_legacy` 存根策略（阶段 A/B）。
- **L2（部分）**：HTTP 适配器、`status` 语义、fixture JSON 与 **`compare_command_json.sh`**；适配器 **`fetchJson` JSON 内存缓存**（**`OPENCLI_CACHE=0`** 关闭，**`hnTopStories` 同路径**，**批次 56**）；YAML **`pipeline` `fetch`（GET）** 同缓存（**批次 57**）；curl **`OPENCLI_HTTP_*`**（批次 55）；与 TS 仍靠并排 diff 持续收敛。
- **L3（部分）**：CDP 路径与 **`CDP_SCENARIO_MATRIX.md`**（与 Playwright **不等价**，只认矩阵内签字）。
- **L4（机制）**：Cookie/站点变量、结构化 `status`（**非**全站点 OAuth 内建）。
- **L5（机制）**：`OPENCLI_HTML_TO_MD_SCRIPT`、可选 `OPENCLI_BUILTIN_HTML_TO_MD`、有限图片开关（见 `MARKDOWN_ARTICLE_PIPELINE.md`）。
- **L6（子集）**：QuickJS `js_init`、`script`、`opencli.args`/`version`/`log`；**`opencli.http`** **GET** / **POST** / **HEAD**（**批次 58**）+ **`error` 细表/`http_error`**（**批次 63**，**`opencli_plugin_api_version` 0.2.3**；**非**全量 Node API）。
- **L7（子集）**：`serve`、鉴权三种方式、POST JSON、`daemon_*_test` + `ai_explore_golden_test`（见 `DAEMON_API.md`）。

---

## 3. 要达到「可实现上限」仍须做的工作（按优先级）

下列为 **仍能增加 TS 近似度** 的**有序清单**；每项完成后可在 **`TS_PARITY_REMAINING.md` §四** 矩阵中签字。

### P0 — 防回归、可自动化

| # | 工作 | 对应层 | 验收 |
|---|------|--------|------|
| 3.1 | 扩展 `tests/fixtures/json/` + `fixture_json_test`，覆盖高频公开 API 响应形状 | L2 | `zig build test` |
| 3.2 | 对核心命令定期跑 **`scripts/l2_p0_routine.sh`** 或 **`compare_command_json.sh --diff-ts`** 与 TS 版同参 `jq -S` diff（GitHub：**`L2 JSON parity (P0 dispatch)`** 手动 workflow 跑无网单测） | L2 | 记录基线 commit |
| 3.3 | 缓存键/TTL 与 TS 差异在 `MIGRATION_GAP` 或站点 issue 留痕 | L2 | 文档/批次号 |

### P1 — 矩阵与认证「封顶」

| # | 工作 | 对应层 | 验收 |
|---|------|--------|------|
| 3.4 | **`CDP_SCENARIO_MATRIX.md`** 按场景勾选签字（Zig CDP vs TS Playwright 边界） | L3 | 矩阵全勾或显式「放弃」 |
| 3.5 | **L4**：选 1～2 个高频站点，要么补 **OAuth/Device 最小实现**，要么在 **`AUTH_AND_WRITE_PATH.md`** 写明「本仓库不实现设备码 / 仅 Cookie 注入」并签字 | L4 | **已补**：Wave 2.2 + **§ P1 站点边界签字矩阵**（**批次 62**）；设备码仍不实现 |
| 3.6 | 写路径：与 `AUTH_AND_WRITE_PATH.md` 一致的 **有凭据** 回归用例（可跳过 CI） | L4 | **`scripts/regression_cookie_writepath.sh`** + 矩阵中 Reddit/B 站/V2EX 等 |

### P2 — 架构性增量（投入大）

| # | 工作 | 对应层 | 验收 |
|---|------|--------|------|
| 3.7 | **Zig + Chrome** CI 子集（矩阵内多场景 + 可选周 schedule） | L3 | **`zig-chrome-ci.yml`** 绿（**批次 63**：五场景 + 周三 cron） |
| 3.8 | QuickJS **`opencli` HTTP** native 桥（URL 白名单、超时、错误映射） | L6 | 安全评审 + 单测 |
| 3.9 | 若必须跑 **`type: ts`**：**Node 子进程**执行器（`OPENCLI_ENABLE_NODE_SUBPROCESS=1`，已实现） | L6 | 与 `ts_legacy` 策略共存说明 |

> **批次 52**：**3.7**（`zig-chrome-ci.yml`：`web/read` + `zhihu/download`）、**3.8**（QuickJS 全局 **`__opencli_http_*`** + 白名单/超时单测）已交付；**3.9** 补充 **`OPENCLI_NODE_SUBPROCESS_TIMEOUT_MS`** / **`OPENCLI_NODE_MAX_OUTPUT_BYTES`**（见 **`PLUGIN_QUICKJS.md`**）。**批次 63** 扩 **3.7**（**sinablog/article**、**jd/item**、周 schedule）与 **L6 `error` 细表**。

### P3 — 体验对齐（非功能完备）

| # | 工作 | 对应层 | 验收 |
|---|------|--------|------|
| 3.10 | Turndown 级规则：继续依赖 **`OPENCLI_HTML_TO_MD_SCRIPT`**；内置仅简化（**批次 60** 已扩常见行内 + 块内贯通，仍非 Turndown） | L5 | 不承诺逐规则一致 |
| 3.11 | 图片管线：按 `MARKDOWN_ARTICLE_PIPELINE.md` 扩展开关与文档 | L5 | 与 TS 差异写明 |

> **批次 53（H.1/H.4）**：**3.1** 扩 L2 fixture 与 diff 脚本；**3.10–3.11** 在 **`MARKDOWN_ARTICLE_PIPELINE.md`** 增加 **H.4** 对照表；L7 见 **`DAEMON_API.md`** 与 **`explore_edge_min`** golden。

---

## 4. 显式不在「可实现上限」承诺内（勿计入 %）

以下任一项均**不应**纳入「再打一版就 99.9999%」的口头承诺；应在矩阵中 **N/A** 或 **放弃**：

- 全站点、全登录态、全反爬策略下的 **字节级** 响应一致。
- **不经过 Node** 而在进程内执行任意历史 **TS 适配器**（除非接受 `ts_legacy` 存根或子进程方案）。
- **Playwright 选项级** 与 **CDP** 逐 API 等价（架构不同）。
- 无用户凭据时的 **全量写路径** 与 **OAuth 全厂商设备码**。
- **Electron/桌面** 应用与 TS 版 **100%** 一致（依赖本机环境与法律边界）。

---

## 5. 「迁移完毕」在你选的目标下的结论

| 你的目标 | 是否可宣布「完毕」 |
|----------|-------------------|
| 完成 **阶段 A–G** + **missing=0** | ✅ **是**（已达成） |
| 完成 **§3 全部可勾项** + **§四签字矩阵** | 可达 **可实现上限**；是否叫「99.99%」由团队定义 |
| TS 版 **每一次线上行为** 一致 | ❌ **否**（§4） |

---

## 6. 文档索引（已制定计划）

| 文档 | 角色 |
|------|------|
| [TS_PARITY_MIGRATION_PLAN.md](./TS_PARITY_MIGRATION_PLAN.md) | 阶段 A–G + L0–L7 总表 |
| [TS_PARITY_REMAINING.md](./TS_PARITY_REMAINING.md) | L2–L7 剩余 + Backlog + 签字模板 |
| [MIGRATION_GAP.md](./MIGRATION_GAP.md) | 命名、批次、深度边界 |
| [CDP_SCENARIO_MATRIX.md](./CDP_SCENARIO_MATRIX.md) | L3 |
| [AUTH_AND_WRITE_PATH.md](./AUTH_AND_WRITE_PATH.md) | L4 |
| [MARKDOWN_ARTICLE_PIPELINE.md](./MARKDOWN_ARTICLE_PIPELINE.md) | L5 |
| [PLUGIN_QUICKJS.md](./PLUGIN_QUICKJS.md) | L6 |
| [DAEMON_API.md](./DAEMON_API.md) | L7 |
| [TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md](./TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md) | TS vs Zig **差距总表 + 实现排期（波次）** |

---

*版本：2026-04-01 · 与 `TS_PARITY_REMAINING` 一致：「计划迁移完毕」已完成；「TS 深度等价」= §3 持续勾选 + §4 显式封顶；**L2–L7 签字快照**见 **`TS_PARITY_REMAINING.md` §四**。差距与排期见 `TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md`。*
