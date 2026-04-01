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

**不实现原因**：
1. OAuth 流程需要处理回调 URL、状态参数、安全密钥等，增加复杂度和安全风险
2. 用户应自行管理 Token，通过环境变量注入
3. 与开源项目「零依赖」原则一致

**替代方案**：
```bash
# 用户自行获取 Token 后通过 Cookie/Header 注入
export OPENCLI_COOKIE="your_session_cookie"
export OPENCLI_<SITE>_COOKIE="your_site_specific_cookie"
```

---

*阶段 D 文档基线；细节随 `docs/MIGRATION_GAP.md` 更新。*
