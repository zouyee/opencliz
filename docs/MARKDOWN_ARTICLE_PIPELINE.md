# 文章 / Markdown 管线（阶段 E）

> **English (Zig port)**: Article/Markdown export behavior and its place in the stack (vs upstream Turndown) are summarized in **[`CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md`](CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md)** §2.5 and **`MARKDOWN_ARTICLE_PIPELINE.md`** below.

> 目标：对齐 TS 版「可导出可读 Markdown」的**主要形态**，不追求与 Turndown 逐规则一致。

## 当前 Zig 行为（摘要）

| 能力 | 说明 |
|------|------|
| 默认正文 | `article_pipeline`：纯文本 + frontmatter（`---` / 原文链接 / 标题） |
| 可选写盘 | 命令层 `--output` 等（见各适配器） |
| 外部 HTML→MD | 设置可执行文件 **`OPENCLI_HTML_TO_MD_SCRIPT`**：入参为 `.opencli/article-html-input.html`，stdout 作为 Markdown 正文（**优先于**内置转换） |
| 内置简化 HTML→MD | 设置 **`OPENCLI_BUILTIN_HTML_TO_MD=1`** 且**未**使用外部脚本成功时，用 `src/adapters/html_to_md_simple.zig`：块级含 **`<h1>`–`<h6>`、`<p>`、`<li>`、`<br>`、`<pre>`、`<blockquote>`、`<hr>`（`---`）、极简 `<table>`（GFM 表头行）**；上述块内与 **`<a href>`** 锚文本走同一套**行内**规则（**`strong`/`b`、`em`/`i`、`code`、`del`/`s`/`strike`、`img`+`src`/`alt`、注释等）；**非** Turndown 级精度（**批次 60** 见 **`MIGRATION_GAP.md`**） |
| 正文内图片 | **`OPENCLI_ARTICLE_DOWNLOAD_IMAGES=1`**：在带 `output` 的导出中尝试下载绝对 URL 图片到 `article-images/` 并写引用 |

## 与 TS 版差异

- 未内嵌 Turndown；精细规则依赖 **`OPENCLI_HTML_TO_MD_SCRIPT`** 或（可选）内置简化器；**`<blockquote>`** 内已先行内 Markdown 化后再按行加 **`> `**（嵌套块级 HTML 仍弱）；表格/复杂列表等仍弱于 Turndown。
- 图片管线为「有限下载」，非旧版完整媒体管道。

## 推荐工具链示例

用户可选用任意 CLI/HTML→MD 工具，包装为 `OPENCLI_HTML_TO_MD_SCRIPT` 所指脚本（接口见上）。

### `OPENCLI_HTML_TO_MD_SCRIPT` 可执行约定

- Zig 调用方式：`argv = [ 脚本绝对或相对路径, ".opencli/article-html-input.html" ]`（见 **`article_pipeline.runHtmlToMdScript`**）。
- 脚本须**读入参路径**的 HTML，在 **stdout** 打印 Markdown；**exit 0** 表示成功。

### 仓库内示例：Pandoc 包装

仓库提供 **`examples/html_to_md_pandoc_wrap.sh`**（依赖系统 **`pandoc`**）：

```bash
chmod +x examples/html_to_md_pandoc_wrap.sh
export OPENCLI_HTML_TO_MD_SCRIPT="$PWD/examples/html_to_md_pandoc_wrap.sh"
# 再执行带文章/HTML 导出的 opencli 命令
```

（若需贴近上游 Turndown 规则，可自行用 Node **`turndown`** 等写同等接口的小脚本，不随仓库分发 `node_modules`。）

---

## H.4 / 波次 4：与 TS 版对照清单（L5，持续）

> 目标：**可验收的体验对齐**，不追求 Turndown 逐规则或旧版媒体管道 1:1。

| 检查项 | Zig 侧抓手 | 与 TS 并排时注意 |
|--------|------------|------------------|
| 正文来源 | 默认纯文本 + frontmatter；`OPENCLI_HTML_TO_MD_SCRIPT` 优先 | TS 可能默认 Turndown；diff 只比「可读性」不比字节 |
| 内置 HTML→MD | `OPENCLI_BUILTIN_HTML_TO_MD=1`（**批次 60**：常见行内 + 块内贯通） | 仍非 Turndown 规则集；表格/复杂列表弱于 TS |
| 图片 | `OPENCLI_ARTICLE_DOWNLOAD_IMAGES=1` + 带 `output` 的导出 | TS 可能多一层代理/缓存路径 |
| 验收记录 | 结构化的 `status` / 空正文 | 站点反爬或脚本失败时记入 `MIGRATION_GAP` 或 issue |

---

*阶段 E 文档基线；**H.4** 对照段随 L5 迭代更新；内置转换器能力以 **`MIGRATION_GAP.md` 批次 55/60** 为准。*
