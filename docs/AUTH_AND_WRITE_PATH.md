# 认证与写路径（阶段 D 基线）

> Zig 版与 TS 版对齐的**能力边界**：公开读优先；登录态与写操作依赖环境变量或后续专项，不保证每站与旧版 Node 行为一致。

## 已支持机制

| 机制 | 环境变量 / 行为 |
|------|-----------------|
| 通用 Cookie 头 | `OPENCLI_COOKIE`、`OPENCLI_COOKIE_FILE` |
| 按站点 Cookie | `OPENCLI_<SITE>_COOKIE`（站点名大写，`-`→`_`） |
| HTTP 请求前注入 | `HttpClient.request` 按 URL host 映射 `hostToSiteKey`（见 `src/http/client.zig`） |
| 策略字段 | `AuthStrategy`：`public` / `cookie` / `header` / `oauth` / `api_key`（YAML/类型层） |

## 结构化状态（非裸 `todo`）

命令在缺登录、缺参数或仅 CDP 可用时，应返回带 **`status`** 的 JSON（如 `login_required`、`need_argument`、`http_or_cdp`、`login_or_browser` 等），便于脚本与 TS 侧对照。

## 写路径（Reddit / 即刻 / 微信等）

- **默认**：注册名对齐，执行链可能为占位或仅 URL；需在 **有 Token/Cookie** 的环境做站点级集成测试。
- **里程碑**：按站点开 issue：请求格式、风控、官方 API 变更。

### 写路径 Cookie 手工回归步骤

> 2026-04-01  
> 命令速查：**`scripts/regression_cookie_writepath.sh`**（与下文一致）。

以下写路径命令需要 Cookie 认证。手工回归测试步骤：

#### Reddit 写操作

```bash
# 1. 获取 Reddit 登录 Cookie（通过浏览器开发者工具）
# 2. 设置 Cookie
export OPENCLI_COOKIE="reddit_session_cookie_here"

# 3. 测试 upvote
./zig-out/bin/opencli reddit/upvote --post-id "t3_abc123" --direction up -f json

# 4. 测试 downvote  
./zig-out/bin/opencli reddit/upvote --post-id "t3_abc123" --direction none -f json

# 5. 测试 save
./zig-out/bin/opencli reddit/save --post-id "t3_abc123" -f json

# 6. 测试 comment（需要浏览器）
export OPENCLI_USE_BROWSER=1
./zig-out/bin/opencli reddit/comment --post-id "t3_abc123" --text "Test comment" -f json
```

**预期结果**：
- 有 Cookie：返回 `{"action":"upvote","status":"ok",...}` 或类似
- 无 Cookie：返回 `{"action":"upvote","status":"login_required",...}`

#### Bilibili 收藏夹

```bash
# 1. 设置 B 站 Cookie
export OPENCLI_BILIBILI_COOKIE="bilibili_session_cookie_here"

# 2. 测试收藏夹读取（公开 UID）
./zig-out/bin/opencli bilibili/favorite --uid 123456 --limit 5 -f json

# 3. 测试收藏夹读取（需登录的私有收藏）
./zig-out/bin/opencli bilibili/favorite --limit 5 -f json
```

#### V2EX 通知

```bash
# 1. 设置 V2EX Cookie
export OPENCLI_V2EX_COOKIE="v2ex_session_cookie_here"

# 2. 测试通知读取
./zig-out/bin/opencli v2ex/notifications --limit 10 -f json

# 3. 测试个人资料
./zig-out/bin/opencli v2ex/me -f json
```

**回归检查清单**：
- [ ] Cookie 正确注入到请求头
- [ ] 返回 `status` 字段（非裸 `todo`）
- [ ] 公开数据在无 Cookie 时正确返回 `login_required`
- [ ] 写操作返回结构化状态（`ok`/`pending`/`login_required`）

## OAuth / Device flow

- **当前**：未在 Zig 内嵌完整 OAuth 应用流程；推荐外部拿 Token 后注入 Cookie/Header。
- **后续**：可在 `docs/TS_PARITY_MIGRATION_PLAN.md` 阶段 D 拆分子里程碑。

### 显式「不实现设备码」签字

以下 OAuth 能力**本仓库明确不实现**（2026-04-01 签字）：

| 站点 | TS 版能力 | Zig 版现状 | 签字 |
|------|-----------|------------|------|
| Twitter/X | OAuth 1.0a / OAuth 2.0 | Cookie 注入可用；**无内嵌 OAuth 流程** | ✅ 不实现设备码 |
| Reddit | OAuth 2.0 | Cookie 注入可用；**无内嵌 OAuth 流程** | ✅ 不实现设备码 |
| GitHub | OAuth 2.0 | Cookie 注入可用；**无内嵌 OAuth 流程** | ✅ 不实现设备码 |
| 微信 | 公众号 OAuth | Cookie 注入可用；**无内嵌 OAuth 流程** | ✅ 不实现设备码 |
| Bilibili | OAuth 2.0 | Cookie 注入可用；**无内嵌 OAuth 流程** | ✅ 不实现设备码 |

### OAuth / Device flow 决策签字（Wave 2.2）

> 2026-04-02

| 站点 | 决策 | 理由 | 签字 | 日期 |
|------|------|------|------|------|
| bilibili | 不实现设备码 | 用户自行管理 Token；Cookie/Header 替代方案足够 | ZZ | 2026-04-02 |
| github | 不实现设备码 | Cookie/Header 替代方案足够 | ZZ | 2026-04-02 |
| reddit | 不实现设备码 | Cookie/Header 替代方案足够 | ZZ | 2026-04-02 |
| twitter | 不实现设备码 | Cookie/Header 替代方案足够 | ZZ | 2026-04-02 |

**替代方案**：
```bash
# 用户自行获取 Token 后通过 Cookie/Header 注入
export OPENCLI_COOKIE="your_session_cookie"
export OPENCLI_<SITE>_COOKIE="your_site_specific_cookie"
```

**不实现原因**：
1. OAuth 流程需要处理回调 URL、状态参数、安全密钥等，增加复杂度和安全风险
2. 用户应自行管理 Token，通过环境变量注入
3. 与开源项目「零依赖」原则一致

---

## P1：高频站点读/写边界签字矩阵

> **用途**：把「Zig 与 TS 在登录态、写路径、浏览器依赖上能承诺什么」收敛成**可引用的一页**（**非**字节级与 TS 一致）。与 **`docs/CDP_SCENARIO_MATRIX.md`**、**`scripts/regression_cookie_writepath.sh`** 并用。  
> **签字**：ZZ · **2026-04-01**

| 站点/域 | 公开读（无 Cookie） | 需登录读 | 写路径（Zig） | 与 TS 对齐方式 | 备注 |
|---------|---------------------|----------|---------------|----------------|------|
| HN / npm / PyPI / crates / SO 公开 API 等 | ✅ HTTP 适配器为主 | — | 一般无 | L2 fixture + **`compare_command_json.sh`** | 改版以 **`status`** 为准 |
| GitHub（公开） | ✅ | 私有仓库等 | 无内嵌 OAuth | **`OPENCLI_GITHUB_COOKIE`**；设备码 **不实现**（Wave 2.2） | 与 TS 私有 API 深度 **不承诺** |
| Bilibili | ✅ 部分接口 | 收藏夹/账号维度 | 注册对齐 | **`OPENCLI_BILIBILI_COOKIE`**；见上文回归 | 风控/字段漂移见 issue |
| V2EX | ✅ 列表等 | 通知 / `me` | 读为主 | **`OPENCLI_V2EX_COOKIE`** | 见上文回归 |
| Reddit | ✅ 部分 | 关注流等 | upvote/save/comment 等 | **`OPENCLI_COOKIE`** 或站点变量 | 见 **`regression_cookie_writepath.sh`** |
| 知乎 / 微博 / Twitter(X) | ⚠️ 易登录壳/反爬 | ✅ | 写 **不承诺**全量 | Cookie + 可选 **`OPENCLI_USE_BROWSER=1`**；**无设备码** | 与 TS Playwright 深度 **不对等** |
| 微信 / weixin | ⚠️ 多依赖 CDP 或 Cookie | ✅ | 矩阵内场景 | **`CDP_SCENARIO_MATRIX.md`** | 仅认矩阵勾选 |
| 即刻、豆包/ChatWise 桌面等 | 视 YAML | 混合 | 写路径 **不保证** | **`desktop_exec`** + 本机环境 | 见 **`MIGRATION_GAP`** |

**验收口径**：无凭据时返回结构化 **`status`**（如 **`login_required`**），**不**使用裸字符串 **`todo`**；有凭据时以各站 **`regression_cookie_writepath.sh`** 与手工步骤为准。

---

*阶段 D 文档基线；细节随 `docs/MIGRATION_GAP.md` 更新。*
