# CDP 浏览器加深场景矩阵（Zig / TS 对照用）

> **目的**：签字「阶段 C」——明确哪些命令在 **`OPENCLI_USE_BROWSER=1`** 下走 Chrome CDP，以及实现位置与 TS 版（Playwright）的差异边界。  
> **实现代码**：`src/adapters/adapter_browser.zig` 中 `browserProfile` + `maybeBrowserDeepen`。

## 环境与前置

| 项 | 说明 |
|----|------|
| 开关 | `OPENCLI_USE_BROWSER=1` |
| 配置 | `config.browser.enabled`（默认 true）；可关浏览器 |
| 可执行文件 | 本机 Chrome/Chromium；CDP 端口见 `types.Config.browser` |
| Cookie | `OPENCLI_COOKIE` / `OPENCLI_COOKIE_FILE` / `OPENCLI_<SITE>_COOKIE`（与 HTTP 链一致） |

## 已配置 `waitFor` / `evaluate_light` 的命令

| 站点 | 命令 | `wait_for` | 超时 (ms) | `evaluate_light` | 备注 |
|------|------|------------|-----------|------------------|------|
| weixin | download | `#js_content` | 45000 | `title`+`text` JSON | 正文区懒加载 |
| web | read | `body` | 15000 | 同上 | 通用页 |
| zhihu | download | `.QuestionHeader, body` | 20000 | 同上 | 问答/文章 |
| sinablog | article | `body` | 15000 | 同上 | 博客文 |
| jd | item | `body` | 20000 | 同上 | 商品页 |
| （默认） | 其他 `browser: true` | — | 30000 | — | 无专用 profile 时用通用 CDP 路径 |

## 与 TypeScript（Playwright）版差异（签字边界）

| 维度 | TS 版 | Zig 版 |
|------|--------|--------|
| 引擎 | Playwright | CDP WebSocket（`src/browser/`） |
| 选择器策略 | 各测试用 DOM 用例 | 上表固定 profile + 可扩展 `browserProfile` |
| 会话/多页 | 较完整 | 按命令单次加深为主 |
| 输出形态 | 与旧 article 管道一致目标 | 与 `article_pipeline` 对齐（frontmatter / 纯文本 / 可选外部 HTML→MD） |

**结论**：行为 **不要求字节级一致**；以「同 URL 下能拉出可读正文 + 结构化字段」为场景验收口径。

## 场景签字矩阵

> 2026-04-01

| 站点 | 命令 | 状态 | 签字 | 备注 |
|------|------|------|------|------|
| weixin | download | ⚠️ 待验证 | （需 Chrome + 有效文章 URL） | CDP profile 已配置 |
| web | read | ⚠️ 待验证 | （需 Chrome + 有效 URL） | CDP profile 已配置 |
| zhihu | download | ⚠️ 待验证 | （需 Chrome + 有效文章 URL） | CDP profile 已配置 |
| sinablog | article | ⚠️ 待验证 | （需 Chrome + 有效博客 URL） | CDP profile 已配置 |
| jd | item | ⚠️ 待验证 | （需 Chrome + 有效商品 URL） | CDP profile 已配置 |
| 其他 | `browser: true` | N/A | N/A | 使用通用 CDP 路径 |

**签字状态说明**：
- ✅ 已签字：已验证工作正常
- ⚠️ 待验证：profile 已配置，需手动验证
- ❌ 失败：验证发现问题
- N/A：不适用

## 建议手动回归（可选 CI）

在装有 Chrome 的环境执行（需网络）：

```bash
export OPENCLI_USE_BROWSER=1
zig build run -- weixin/download --url 'https://mp.weixin.qq.com/s/…' -f json
zig build run -- zhihu/download --url 'https://zhuanlan.zhihu.com/p/…' -f json
zig build run -- web/read --url 'https://example.com' -f json
```

失败时检查：Chrome 是否可启动、端口是否被占用、URL 是否需登录（返回 `login_required` / `http_or_cdp` 属预期分支）。

---

*与 `docs/TS_PARITY_MIGRATION_PLAN.md` 阶段 C 同步。*
