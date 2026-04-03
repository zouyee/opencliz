# jackwener/opencli 能力对齐 — 进度总表

> **English capability & diff doc:** **`docs/CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md`**.

> **上游**：[jackwener/opencli](https://github.com/jackwener/opencli)（`@jackwener/opencli`）· **`docs/UPSTREAM_REFERENCE.md`**  
> **更新方式**：完成一项后改本表 **状态**、必要时在 **`MIGRATION_GAP.md`** 补 **批次**。

---

## 状态图例

| 标记 | 含义 |
|------|------|
| ✅ | 已交付（代码/文档/CI 可指） |
| 🔄 | 进行中 / 需持续执行 |
| ⏳ | 已排期，待开工 |
| ⛔ | 明确不对齐或非目标（见 **`TS_PARITY_99_CAP.md` §4**） |

---

## P0 — L2：公开 API 形状与 JSON 防漂移

| # | 任务 | 状态 | 交付物 / 备注 |
|---|------|------|----------------|
| P0.1 | fixture + `fixture_json_test` 覆盖高频响应 | ✅ | `tests/fixtures/json/` + **`src/tests/fixture_json_test.zig`** |
| P0.2 | 并排 diff 工具链 | ✅ | **`scripts/l2_p0_routine.sh`**、**`compare_command_json.sh --diff-ts`**、**批次 61** |
| P0.3 | 手动 CI 入口 | ✅ | **`.github/workflows/l2-json-parity-dispatch.yml`** |
| P0.4 | 记录上游 JSON 基线（版本可溯源） | 🔄 | 用 **`scripts/record_jackwener_baseline.sh`**；在表下 **「基线记录」** 填 **npm 版本/commit**（需有网；**P0.5** 跑完上游导出后把 **`JACKWENER_OPENCLI_PKG`** 实际值记入表） |
| P0.5 | 选 5 条命令与上游 `jq -S` diff 并归档差异 | ✅ | **`scripts/parity_p0_5_export_zig.sh`**、**`parity_p0_5_export_upstream.sh`**、**`parity_p0_5_diff.sh`**；默认输出 **`parity-output/{zig,ts}/`**（已 **`.gitignore`**）；差异摘要写入本表 **「基线记录」** 或 issue |

---

## P1 — L4 / L7：边界与 Daemon 契约

| # | 任务 | 状态 | 交付物 / 备注 |
|---|------|------|----------------|
| P1.1 | L4 站点读/写边界签字矩阵 | ✅ | **`AUTH_AND_WRITE_PATH.md`** § P1 · **批次 62** |
| P1.2 | Daemon 鉴权 / OPTIONS / TCP | ✅ | **`daemon_*_test`** · **批次 62** |
| P1.3 | 未知命令 HTTP 语义贴近 REST / 上游 | ✅ | **`/execute`** 未注册 → **404** + `Command not found` · **批次 65** |

---

## P2 — L3 / L6：CDP CI 与插件 HTTP

| # | 任务 | 状态 | 交付物 / 备注 |
|---|------|------|----------------|
| P2.1 | Zig + Chrome 多场景 CI | ✅ | **`zig-chrome-ci.yml`** 五场景 + schedule · **批次 63** |
| P2.2 | `opencli.http` 错误码细表 | ✅ | **`PLUGIN_QUICKJS.md`**、`http_error` · **API 0.2.3** · **批次 63** |

---

## P3 — L5 / 体验：文章与媒体

| # | 任务 | 状态 | 交付物 / 备注 |
|---|------|------|----------------|
| P3.1 | 内置 HTML→MD 增量（非 Turndown） | ✅ | **`html_to_md_simple`** 行内+块 · **批次 55/60** |
| P3.2 | 外部 HTML→MD 脚本优先 | ✅ | **`OPENCLI_HTML_TO_MD_SCRIPT`** · **`examples/html_to_md_pandoc_wrap.sh`**（Pandoc）· **`MARKDOWN_ARTICLE_PIPELINE.md`** § 示例 |
| P3.3 | 图片管线对齐上游 article-download | ⛔ / ⏳ | 仅有限开关；完整管线 **非目标** 或长期 backlog |

---

## P4 — 文档与基线锚定

| # | 任务 | 状态 | 交付物 / 备注 |
|---|------|------|----------------|
| P4.1 | 明确上游仓库与 npm | ✅ | **`UPSTREAM_REFERENCE.md`** · **批次 64** |
| P4.2 | 本进度总表 | ✅ | 即本文 · **批次 65** |

---

## 基线记录（请随 P0.4 / P0.5 更新）

| 日期 | @jackwener/opencli 版本 / commit | 命令 | 差异摘要 |
|------|-----------------------------------|------|----------|
| _待填_ | _例：1.6.1 或 git SHA_ | _例：hackernews/top --limit 1_ | _无 / 字段 x 不同_ |

---

## 下一步（按顺序）

1. **P0.4**：在有网环境顺序执行 **`parity_p0_5_export_upstream.sh`**（或单条 **`record_jackwener_baseline.sh`**），把 **基线记录** 表的版本/commit 与差异摘要填实。  
2. **P0.5 回归**：发版或上游大版本前跑 **`parity_p0_5_export_zig.sh`** → **`parity_p0_5_export_upstream.sh`** → **`parity_p0_5_diff.sh`**（可 pin **`JACKWENER_OPENCLI_PKG`**）。  
3. **P3.2**：文章导出验收见 **`MARKDOWN_ARTICLE_PIPELINE.md`** H.4；可选 Turndown/Node 包装仍由用户自备 CLI。  
4. **上游专属能力**（扩展桥、默认 Daemon 端口、`operate` 全量、sysexits）：仅在 **`UPSTREAM_REFERENCE.md`** 与 **`TS_PARITY_99_CAP.md`** 评估后单独立项，避免与当前 Zig 架构强行 1:1。

---

*维护：与 **`TS_PARITY_REMAINING.md` §三–§四** 同步口径；大功能完成后递增 **`MIGRATION_GAP` 批次**。*
