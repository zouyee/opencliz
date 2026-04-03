# OpenCLI：TypeScript 版 vs Zig 版 — 能力差距与实现排期

> **English summary of supported capabilities vs upstream:** **`CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md`**.

> 基线：上游 [**jackwener/opencli**](https://github.com/jackwener/opencli)（TypeScript；Browser Bridge + Playwright 等）为**能力参照**；Zig 版为 **`opencliz`** 本仓库。详见 **`docs/UPSTREAM_REFERENCE.md`**。  
> **已对齐**：命令名与基线统计 **`missing=0`**（见 `MIGRATION_GAP.md`）；迁移计划 **阶段 A–G** 已全部交付（见 `TS_PARITY_MIGRATION_PLAN.md`）。  
> 本文只列 **「产品行为 / 运行时能力」** 上 Zig 相对 TS **仍未对齐或仅部分对齐** 的点，并给出 **建议排期**（可按人力压缩或拉长）。

---

## 1. 总览对照表

| 能力域 | TS 版典型能力 | Zig 版现状 | 差距摘要 |
|--------|----------------|------------|----------|
| **命令面** | `site/command` 全量 | 基线命令已注册；部分命令深度不同 | 同名 ≠ 同行为；需 L2 逐站对照 |
| **HTTP** | axios/fetch、缓存、重定向细节 | `http_exec` + `HttpClient`；**`fetchJson`** 与 **YAML `pipeline` `fetch`（GET）** 共用 **JSON 内存缓存**（**`OPENCLI_CACHE=0`** 关闭；TTL/上限见 **`OPENCLI_CACHE_*`**；**批次 57**） | 与 TS 缓存键/TTL 仍可能不一致；需并排 diff 验证 |
| **浏览器** | Playwright | CDP（`OPENCLI_USE_BROWSER=1`） | 架构不同；仅能以 **场景矩阵** 对齐 |
| **登录 / OAuth** | 多站 OAuth、设备码等 | Cookie/Header 注入 + `status` | **无**内嵌完整 OAuth 流程 |
| **HTML→MD** | Turndown 等 | 外接脚本优先 + 内置简化（**批次 60**：常见行内标签 + 标题/段落/列表/引用/表元格/链接文本贯通） | 仍非 Turndown 级规则对等 |
| **图片 / 媒体** | article-download 管线 | 有限开关 + 绝对 URL 下载 | 非旧版完整媒体管道 |
| **插件** | Node 生态、`type: ts` 默认可跑 | QuickJS + `script`；`ts_legacy` 默认存根；**可选** Node 子进程；**`opencli.http`**（`OPENCLI_PLUGIN_HTTP=1` + 白名单，见 **`PLUGIN_QUICKJS.md`**） | 无 **进程内** TS；无全量 Node 内置模块 |
| **Daemon** | （若 TS 有完整 API 面） | `serve` + REST 子集 + 测试；**读请求超时**（**批次 54**）+ 可选 **`/execute` 执行超时**（**批次 55** / **`OPENCLI_DAEMON_EXECUTE_TIMEOUT_MS`**） | WebSocket / 批量执行等仍可能缺失；与 TS 扩展端点逐项对照 |
| **AI 探索 / 生成** | explore / generate 深度 | 启发式 HTML 分析 + YAML 合成 golden | 与 TS 启发式/模型链可能不一致 |
| **桌面 / Electron** | CDP 连应用 | `desktop_exec` + `OPENCLI_CDP_ENDPOINT` | 依赖本机环境；难与 TS 100% 一致 |

---

## 2. 按分层详列「未对齐功能点」

与 **`TS_PARITY_MIGRATION_PLAN.md` §1（L0–L7）** 一致。

### L2 — HTTP 行为

| 功能点 | TS | Zig | 未对齐说明 |
|--------|----|----|------------|
| 全站响应字节级一致 | 是（随站点变） | 否 | 站点改版、反爬、缓存差异 |
| 核心公开 API 形状稳定 | 隐式 | fixture + 可选 live diff | fixture 覆盖仍可扩；**`l2_p0_routine.sh`** / **`--diff-ts`**（**批次 61**）；与 TS 有网 diff 仍靠人工/自建 job，未默认进 push CI |
| 缓存语义 | TS 实现为准 | Zig 自有 | 需文档或脚本对照 TTL/键 |

### L3 — 浏览器（`browser: true`）

| 功能点 | TS | Zig | 未对齐说明 |
|--------|----|----|------------|
| Playwright 选择器/等待语义 | 全量 | CDP + 站点分支 | **不等价**；只认 `CDP_SCENARIO_MATRIX.md` 勾选 |
| CI 自动跑浏览器子集 | 可能有 | **`zig-chrome-ci.yml`**（**批次 63**：五场景 + 周 schedule） | 与 Playwright 用例 **不对等** |
| 矩阵签字 | — | 文档已维护 | **未完成**逐行签字 |

### L4 — 认证与写路径

| 功能点 | TS | Zig | 未对齐说明 |
|--------|----|----|------------|
| OAuth / Device flow | 多站 | 无内嵌 | 阶段 D **未勾选**；靠外部 Token + Cookie；**`AUTH_AND_WRITE_PATH.md`** **P1 站点边界矩阵**（**批次 62**） |
| 写操作（发帖、收藏等） | 部分站有 | 注册/链路不齐 | 需凭据与站点级集成测试；矩阵写明各站承诺边界 |
| 结构化错误 | 有 | `login_required` 等 | 覆盖面需与 TS 对照 |

### L5 — 富文本与图片

| 功能点 | TS | Zig | 未对齐说明 |
|--------|----|----|------------|
| Turndown 级 HTML→MD | 有 | 外接脚本或内置简化（**批次 60** 已扩行内/块内） | 规则集仍不对等 |
| 完整图片管线 | 有 | `OPENCLI_ARTICLE_DOWNLOAD_IMAGES` 等有限能力 | 见 `MARKDOWN_ARTICLE_PIPELINE.md` |

### L6 — 插件运行时

| 功能点 | TS | Zig | 未对齐说明 |
|--------|----|----|------------|
| `type: ts` 适配器进程内执行 | 是 | **可选** → `ts_legacy` JSON 存根 + `OPENCLI_ENABLE_NODE_SUBPROCESS=1` Node 子进程 | 已实现：**Node 子进程** 可选方案 |
| Node 内置模块（fs、http…） | 有 | **无** | QuickJS 仅 `opencli` 子集 |
| `opencli` HTTP 桥 | 隐式 Node | **`opencli.http`**（**GET** / **POST** / **HEAD**；**`error` 细表 + `http_error`** **批次 63**；**`opencli_plugin_api_version` 0.2.3**） | 与 Node `fetch` 能力集仍不对等 |

### L7 — Daemon / explore / synthesize

| 功能点 | TS | Zig | 未对齐说明 |
|--------|----|----|------------|
| Daemon API 全集 | 视 TS 版本 | 子集 + `DAEMON_API.md`；**请求读超时**（**批次 54**）+ **执行超时**（**批次 55**）；**批次 62** 测扩面；未知命令 **404**（**批次 65**） | WebSocket、批量执行等仍可能缺 |
| explore 准确度 | 可能更深 | 启发式 + `exploreFromHtml` 测试 | 非逐特征对齐 |
| generate 全链路 | TS | Zig 有 Generator | 需按 URL/站点对照行为 |

---

## 3. 建议实现排期（可执行波次）

以下为 **相对优先级 + 建议周期**，便于排入迭代；**非合同承诺**。

### 第 1 波 — **持续 / 每个迭代可穿插（P0）**

| 序号 | 交付 | 验收 |
|------|------|------|
| 1.1 | 扩充 `tests/fixtures/json/` + `fixture_json_test`（**批次 53**：HN 补 `time`、GitHub trending 数组、SO `items` 包装；**批次 50–51** 见前文） | `zig build test` |
| 1.2 | 核心命令与 TS 并排 `jq -S` diff（**`l2_p0_routine.sh`**、**`compare_command_json.sh --diff-ts`**；建议 **`OPENCLI_CACHE=0`**） | 记录基线 commit |
| 1.3 | 缓存/重定向差异记入 `MIGRATION_GAP` 批次 | 可追溯（批次 49 + 脚本注释） |

**目标**：L2 回归可验证，减少「同名命令悄悄漂移」。

### 第 2 波 — **约 2～4 周（P1）** ✅（批次 52 收口）

| 序号 | 交付 | 验收 |
|------|------|------|
| 2.1 | `CDP_SCENARIO_MATRIX.md` **逐场景签字**（或标 N/A） | 矩阵更新 + **`zig-chrome-ci.yml`** |
| 2.2 | L4：1～2 个高频站 — **OAuth 最小实现** *或* **书面「不实现设备码」** | **`AUTH_AND_WRITE_PATH.md`** Wave 2.2 已签字（ZZ） |
| 2.3 | 可选：1 条有 Cookie 的写路径/读私有 API **手工回归步骤** | **`AUTH_AND_WRITE_PATH.md`** + **`scripts/regression_cookie_writepath.sh`** |

**目标**：L3/L4 **封顶有签字**，避免无限扯皮「算不算对齐」。

### 第 3 波 — **约 1～2 个月（P2，架构）** ✅（批次 52 收口）

| 序号 | 交付 | 验收 |
|------|------|------|
| 3.1 | Zig + Chrome **最小 CI**（矩阵内 1～2 场景） | **`zig-chrome-ci.yml`**：`web/read` + **`zhihu/download`**（软失败 `|| true`） |
| 3.2 | QuickJS **`opencli.http`** + 白名单 + 超时 | **`quickjs_runtime.zig`** 全局 **`__opencli_http_*`** + 无网络单测 |
| 3.3 | **硬化** Node 子进程路径：超时/错误映射/与 TS 版 argv 对齐；扩展 manifest 场景覆盖 | **`runner.zig`** 超时/输出上限 + **`PLUGIN_QUICKJS.md`** |

**目标**：L6 能力向 TS 插件靠拢；L3 有一点自动化证据。

### 第 4 波 — **持续优化（P3）**

| 序号 | 交付 | 验收 |
|------|------|------|
| 4.1 | `OPENCLI_HTML_TO_MD_SCRIPT` 文档与示例固化；内置规则小步增加 | **`MARKDOWN_ARTICLE_PIPELINE.md`** § H.4 对照清单（**批次 53**） |
| 4.2 | 图片管线按 `MARKDOWN_ARTICLE_PIPELINE.md` 扩展 | 与 TS 差异写明（同 § H.4） |
| 4.3 | Daemon / explore 与 TS 新端点 **逐项 diff** | **`DAEMON_API.md`** L7 签字 + **`explore_edge_min`** golden（**批次 53**） |

**目标**：体验对齐；**不**追求规则级 100% 一致。

### 显式 **不排入「必须交付」** 的项

（若在 OKR 中出现，应标为 **N/A** 或 **放弃**）

- 全站点 OAuth、无凭据全写路径、Playwright↔CDP API 级等价、Electron 全兼容、TS 适配器不加子进程而「全进 Zig」。

详见 **`TS_PARITY_99_CAP.md` §4**。

---

## 4. 与其他文档的关系

| 文档 | 用途 |
|------|------|
| 本文 | **TS vs Zig 差距清单 + 排期波次** |
| `TS_PARITY_REMAINING.md` | L2–L7 剩余叙述 + Backlog + **签字矩阵快照（§四）** + 空模板 |
| `TS_PARITY_99_CAP.md` | 「~99.99%」可实现上限与勾选逻辑 |
| `TS_PARITY_MIGRATION_PLAN.md` | 阶段 A–G（已完成）+ **§6 阶段 H（最新迁移规划）** 与 L 层定义 |
| `MIGRATION_GAP.md` | 命名统计、批次历史、深度边界说明 |

---

*版本：2026-04-01 · 排期为建议值，以团队迭代容量为准；**H.1/H.4** 见 **批次 53**；L2 缓存/HTTP 环境变量见 **批次 55–57**（含 pipeline **`fetch`**）；**签字一页表**见 **`TS_PARITY_REMAINING.md` §四**。*
