# TypeScript OpenCLI 能力对齐迁移计划（修订版）

> 目标：在**可验证、可分阶段交付**的前提下，逐步逼近上游 [**jackwener/opencli**](https://github.com/jackwener/opencli)（TypeScript / `@jackwener/opencli`）的**行为与工程能力**，而非仅命令名对齐。  
> 上游说明：**`docs/UPSTREAM_REFERENCE.md`**。  
> 基线文档：`docs/MIGRATION_GAP.md`（命名对齐 `missing=0` 已完成；本文聚焦**深度等价**与**剩余工程债**）。

---

## 1. 验收分层（什么叫「迁移完毕」）

| 层级 | 含义 | 当前状态 |
|------|------|----------|
| **L0 命名** | `site/command` 与基线一致 | ✅（见 MIGRATION_GAP） |
| **L1 YAML 管线** | 用户/插件 YAML 中 `pipeline.steps` 可解析并执行 | ✅ |
| **L2 HTTP 行为** | 公开 API、重定向、Cookie、缓存与 TS 侧一致 | ⚠️ 按站点持续对照；**签字快照**见 **`TS_PARITY_REMAINING.md` §四**（fixture、**`fetchJson`/pipeline `fetch`（GET）缓存**、**`OPENCLI_HTTP_*`** 等） |
| **L3 浏览器** | `browser: true` + CDP 与 Playwright 版关键路径等价 | ⚠️ 架构不同，需用场景矩阵签字 |
| **L4 认证** | Cookie/OAuth/站点私有 API | ⚠️ 大量依赖用户态，需分站点里程碑 |
| **L5 富文本** | Turndown 级 HTML→Markdown、图片管线 | ⚠️ 外部脚本 + 可选内置简化器（`OPENCLI_BUILTIN_HTML_TO_MD`）；图片管线仍有限 |
| **L6 插件运行时** | TS 插件 / JS 逻辑 / Hooks 与原版一致 | ✅ QuickJS `js_init` + 命令 `script` + `opencli.args`/`version`/`log`；与 TS 全量插件 API 仍可继续对齐 |
| **L7 运维与 AI** | Daemon、explore/generate、synthesize 与 TS 功能对等 | ⚠️ **契约/TCP/golden 已起步**（`daemon_*_test`、`ai_explore_golden_test`、`DAEMON_API.md`）；与 TS 全量行为仍按场景扩测 |

**结论**：「完全迁移完毕」= **L0–L7 在签字矩阵内均达标**；其中 L4/L5 受外部网站与法律合规约束，只能以「支持能力 + 文档 + 回归用例」封顶，不能保证每站 100% 在线可用。

**与「阶段 A–G 全部勾选」的关系**：**阶段 A–G** 指本文件第 2 节工程交付项 —— **已全部完成** ✅。  
**与「和 TS 版每一次行为都一致」的关系**：须继续完成 **L2–L7 分层对照**；**逐项剩余工作、Backlog、签字模板**见 **`docs/TS_PARITY_REMAINING.md`**（**必读**）。

---

## 2. 阶段划分与交付物

### 阶段 A — YAML 与 Pipeline（P0，本仓库优先）

- [x] 从 YAML 解析 `pipeline` → `types.PipelineDef`（含 `type` / `step_type`、扁平 `config`）。
- [x] 插件 `plugin.yaml` 中命令可携带 `pipeline`、`args`、`columns` 并注册为可执行命令。
- [x] 用户目录单文件命令（`~/.opencli/clis/<site>/<cmd>.yaml`）根级 `pipeline` 生效。
- [x] Pipeline 执行器：`fetch` 支持 `extract`；步骤间注入 `data` 变量；`transform` 支持 `operation: limit`；模板支持 `args.<name>`。
- [x] `plugin` / `yaml` 来源命令堆内存可在 `unregister` / `Registry.deinit` 路径释放。

**验证**：`zig build test`；手工 `opencli <site>/<cmd>` 使用仅 YAML 的最小用例。

### 阶段 B — 多命令单文件与 manifest（P1）

- [x] 支持类似 `examples/bilibili.yaml` 的顶层 `commands:` **map** 或 **array**，按命令展开注册（`discovery.loadYamlFile`；子项继承根级 `site`/`domain`/`strategy`/`browser`/`description`）。
- [x] `cli-manifest.json` 中 `type: ts` 条目：注册为 **`source=ts_legacy`**；默认返回 JSON 存根（`status: ts_adapter_not_supported` + `message` + 可选 `modulePath`）。**可选**：环境变量 **`OPENCLI_ENABLE_NODE_SUBPROCESS=1`** 时用 **Node 子进程**执行（见 **`docs/PLUGIN_QUICKJS.md`**、`runner.zig`）；**不**在 Zig 进程内嵌 V8/Node。

### 阶段 C — 浏览器与桌面（P1）

- [x] 维护 `docs/CDP_SCENARIO_MATRIX.md`（微信/知乎/web/read/jd 等与 `adapter_browser.zig` 对照 + TS 差异边界）。
- [x] 可选：Zig 最小 CI — **`.github/workflows/zig-ci.yml`**（ubuntu / macos，`zig build test`，`ZIG_GLOBAL_CACHE_DIR` + actions/cache）。**带 Chrome 的浏览器子集**仍以 Node **`smoke-test`** 与 **`docs/CDP_SCENARIO_MATRIX.md`** 手动对照为主。

### 阶段 D — 认证与写路径（P2）

- [x] 文档化 Cookie/站点变量与结构化 `status` 边界：`docs/AUTH_AND_WRITE_PATH.md`。
- [x] 分站点 OAuth/Device flow **决策签字**（2026-04-02）：已文档化「不实现设备码」签字矩阵，选 bilibili/github/reddit/twitter 四个高频站点明确决策。**实际 OAuth 实现或自动化集成测试仍为可选里程碑**，见 `docs/AUTH_AND_WRITE_PATH.md` § OAuth 决策签字。**任务分解见 `docs/TS_PARITY_REMAINING.md` § L4 / § 三。**

### 阶段 E — Markdown 与图片（P2）

- [x] 文档化 `OPENCLI_HTML_TO_MD_SCRIPT`、图片开关与 Turndown 差异：`docs/MARKDOWN_ARTICLE_PIPELINE.md`。
- [x] 可选：内置简化 HTML→MD（**`OPENCLI_BUILTIN_HTML_TO_MD=1`**，`html_to_md_simple.zig`；不追求 Turndown 全兼容；优先级低于 **`OPENCLI_HTML_TO_MD_SCRIPT`**；**批次 60** 扩行内标签与块级内文贯通，见 **`MIGRATION_GAP.md`**）。

### 阶段 F — 插件 JS 运行时（P2）

- [x] 依赖 **[mitchellh/zig-quickjs-ng](https://github.com/mitchellh/zig-quickjs-ng)**（`build.zig.zon` → `quickjs_ng`）；`plugin.yaml` 可选 **`js_init`** 在 `loadPlugin` 时执行；`src/plugin/quickjs_runtime.zig` + 单测。
- [x] 命令级 **`script`**（`plugin.yaml` → `Command.js_script_path`，优先于 `pipeline`）；向 JS 注入 **`opencli`**（`args`、`version`、**`log`→print**）；**HTTP 等 native 桥接**仍待迭代。

### 阶段 G — 收尾与「迁移完毕」签字（P3）

- [x] `opencli list --tsv`：列 **site / name / source / pipeline / script**；`scripts/compare_opencli_list.sh` 默认输出无表头排序行便于 diff；`OPENCLI_LIST_HEADER=1` 保留表头。
- [x] `docs/MIGRATION_GAP.md` 批次 46 记录；计划内 A–G 交付项已勾选（持续站点对齐仍见 L2–L5「⚠️」）。

---

## 3. 依赖与风险

- **外部网站变更**：适配器行为漂移，需版本化 fixture + 可选 live 测试。
- **Zig std JSON**：`parseFromSliceLeaky` 等已知限制（见 MIGRATION_GAP 批次 39/41）。
- **TS 版无单一 tag**：以仓库内 `src/clis` 历史或发布包为基线，变更需记录在 MIGRATION_GAP。

---

## 4. 执行顺序（建议）

1. 阶段 A（本迭代已实施核心代码）  
2. 阶段 B（多命令 YAML / manifest 策略）  
3. 阶段 C → E（并行度按人力拆分）  
4. 阶段 F → G  

---

## 5. 「完全达到 TS 版能力」还剩什么？（执行定义）

| 若你的目标是… | 当前状态 | 下一步 |
|----------------|----------|--------|
| **完成本仓库书面迁移计划（A–G）** | ✅ **已完成** | 无需再补阶段项；维持 `zig build test` 与文档 |
| **命令名与基线一致** | ✅ **`missing=0`** | 见 `MIGRATION_GAP.md` |
| **HTTP/浏览器/登录/文章/Daemon 与 TS 深度一致** | ⚠️ **L2–L7 持续项** | 按 **`docs/TS_PARITY_REMAINING.md`** 分层推进 + **签字矩阵**；**可实现上限勾选清单**见 **`docs/TS_PARITY_99_CAP.md`**；**差距总表与分波排期**见 **`docs/TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md`** |

**无法在工程上承诺一次性「全部完成」的部分**（需在 `TS_PARITY_REMAINING` / **`TS_PARITY_99_CAP` §4** 中签字或显式放弃）：全站点 OAuth、全命令 Playwright 级等价、Turndown 全规则、无凭据下的写路径、桌面 Electron 全兼容等。

---

## 6. 最新迁移规划（阶段 H：L2–L7 与 TS 深度对齐）

> **阶段 A–G** 已闭环（§2）。此后与 TS 版的差距不再用「阶段 I/J」编号，而按 **验收层 L2–L7** + **四波交付** 推进；详细差距表与任务拆解见 **`docs/TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md`**，签字模板见 **`docs/TS_PARITY_REMAINING.md` §四**，封顶语义见 **`docs/TS_PARITY_99_CAP.md`**。

### 6.1 当前状态一览

| 层级 | 相对 TS | 规划动作（摘要） |
|------|---------|------------------|
| **L2** | HTTP/缓存/响应细节可能不一致 | 扩 fixture、与 TS 并排 JSON diff（**批次 50–51、53**；**`h_l2_ts_diff_suggestions.sh`** / **`compare_command_json.sh`** + **`OPENCLI_CACHE=0`**） |
| **L3** | Playwright ≠ CDP | `CDP_SCENARIO_MATRIX.md` 签字；**`zig-chrome-ci.yml`** 最小 CI（**批次 52**：`web/read` + `zhihu/download`） |
| **L4** | OAuth/写路径 | 文档封顶 + 签字（**`AUTH_AND_WRITE_PATH.md`** Wave 2.2）；Cookie 回归见 **`scripts/regression_cookie_writepath.sh`**（**批次 52**） |
| **L5** | Turndown/媒体管线 | 外接脚本为主；**`MARKDOWN_ARTICLE_PIPELINE.md`** § **H.4** 与 TS 对照清单（**批次 53**） |
| **L6** | 全量 Node API | QuickJS 子集 + 可选 Node 子进程（**超时/输出上限**，**批次 52**）；**`opencli.http`** 原生桥 + 白名单（**批次 52**） |
| **L7** | Daemon/explore | **`DAEMON_API.md`** 测试索引 + L7 签字；**`explore_edge_min`** golden（**批次 53**）；与 TS 端点继续扩测 |

### 6.2 建议波次（与 `TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md` §3 一致）

| 波次 | 周期（建议） | 主题 |
|------|----------------|------|
| **H.1** | 持续 | L2 P0：fixture、JSON diff、缓存/重定向留痕 |
| **H.2** | 约 2～4 周 | L3/L4 P1：CDP 矩阵签字、L4 选型（OAuth 或书面不实现）— **批次 52 已收口** |
| **H.3** | 约 1～2 月 | L3/L6 P2：Chrome CI 子集、QuickJS HTTP 桥、Node 子进程硬化 — **批次 52 已收口** |
| **H.4** | 持续 | L5/L7 P3：文章/图片/Daemon/explore 体验对齐，不追求规则级 100% |

**显式排除**（不纳入必交付）：全站点 OAuth、Playwright↔CDP API 级等价、无凭据全写路径、Electron 全兼容等 —— 见 **`TS_PARITY_99_CAP.md` §4**。

---

*文档版本：2026-04-02 · 阶段 A–G 已闭环；**阶段 H.2/H.3（波次 2–3）批次 52 已收口**，见 `MIGRATION_GAP.md`；**H.1/H.4** 仍为持续项；细节以 `TS_ZIG_CAPABILITY_GAP_AND_SCHEDULE.md` 为准。*
