# 插件 QuickJS 运行时（阶段 F）

OpenCLI（Zig）通过依赖 **[mitchellh/zig-quickjs-ng](https://github.com/mitchellh/zig-quickjs-ng)** 嵌入 **QuickJS-ng**，与 `build.zig` / `build.zig.zon` 中的 `quickjs_ng` 包一致。

## `plugin.yaml` 字段

| 字段 | 说明 |
|------|------|
| **`js_init`** | 可选。相对于插件目录的脚本路径（如 `init.js`）。加载插件时**整文件**在独立 `Runtime`/`Context` 中执行一次；成功则打日志 `js_init ok`。 |

### 命令级 `script`（`commands` 数组内）

在每条命令映射中可设 **`script`**：相对于插件目录的 `.js` 路径。执行该命令时：

1. 读取脚本全文，在 QuickJS 中包成 `(function (opencliArgs) { … })(<CLI 实参 JSON>)`，再 **`JSON.stringify` 结果**。
2. 脚本**函数体**内应使用 **`return`**，返回可 JSON 序列化的值；`opencliArgs` 为对象，键为 CLI 参数名，值为**字符串**（与当前 CLI 参数传递一致）。
3. 宿主注入 **`opencli`**（同一函数作用域）：**`opencli.args`**、**`opencli.version`**（见 `opencli_plugin_api_version`）、**`opencli.log(message)`**（QuickJS **`print`**，行前缀 **`[opencli] `**，供排障；非结构化日志通道）。**`opencli.http`** 见下文（需显式开启 + 域名白名单）。

### 已实现：`opencli.http` native 桥（Wave 3.2）

> ✅ **已实现**：以下功能已在 `src/plugin/quickjs_runtime.zig` 中实现。

| API | 说明 | 安全考虑 |
|-----|------|---------|
| `opencli.http.get(url)` | 发起 GET 请求 | ✅ URL 白名单验证 |
| `opencli.http.post(url, body)` | 发起 POST 请求 | ✅ URL 白名单验证 |
| `opencli.http.request(method, url, options)` | 通用请求；**`method`** 支持 **`GET`** / **`POST`** / **`HEAD`** | ✅ 完整安全模型 |

**`HEAD`**：宿主使用 curl **`-I`**；返回 JSON 的 **`body`** 字段为**响应头原文**（非实体 body），**`status`** 为最终 HTTP 状态码；同样受 **`OPENCLI_PLUGIN_HTTP_MAX_BODY_BYTES`** 约束（防止异常巨大头块）。

### `opencli.http` 返回串中的 `error` 字段（与 TS 细对照 · P2）

原生桥将失败情况序列化为 **JSON 字符串**（再被 JS 侧 `JSON.parse`）。**`opencli_plugin_api_version`**：**`0.2.3`** 起将宿主 **`HttpClient`** 的 **`error.HttpError`**（curl 无状态标记等）单独映射为 **`http_error`**，便于与 Node 侧「网络/HTTP 失败」类错误对齐文档化；**非**与 TS 字节级一致。

| `error` 值 | 含义 | TS / Node 对照说明 |
|------------|------|-------------------|
| `missing_url` / `missing_url_or_body` / `missing_method_or_url` | 参数个数不足 | 类似 `TypeError` |
| `url_not_string` / `body_not_string` / `method_not_string` | 类型不是 string | 同上 |
| `url_not_https` | 非 https | 策略性强于裸 `fetch` |
| `url_not_whitelisted` | 域名不在 **`OPENCLI_PLUGIN_ALLOWED_DOMAINS`** | 无 Node 全局等价；需在 TS 侧自建 allowlist 文档对齐 |
| `body_too_large` | 超 **`OPENCLI_PLUGIN_HTTP_MAX_BODY_BYTES`** | 类似限制响应体大小时的错误 |
| `http_error` | **`HttpClient`** 层失败（含 curl 未解析到 **`__OPENCLI_STATUS__`**） | 对应「请求未形成合法 HTTP 响应」类失败；**批次 63** |
| `request_failed` | 其它宿主错误（超时子进程、非 `HttpError` 等） | 兜底；与 TS 并排查日志 |
| `method_not_allowed` | `request` 的 method 非 GET/POST/HEAD | — |
| `post_body_required` | POST 但缺 body 参数 | — |
| `oom` | 读白名单环境变量等时 OOM | 罕见 |

成功时返回对象为 **`{ status, body, url }`**（与 TS 任意 `Response` 形状 **不对等**，以本字段为准）。

**安全模型**：
1. **URL 白名单**：默认只允许 `https://` 开头，且在白名单列表中
2. **超时**：默认 30 秒超时（`OPENCLI_PLUGIN_HTTP_TIMEOUT`），防止恶意脚本阻塞
3. **方法限制**：仅允许 **GET** / **POST** / **HEAD**
4. **敏感头过滤**：不暴露内部 Cookie/Token 给插件

**配置环境变量**：
```bash
# 启用插件 HTTP（默认关闭）
OPENCLI_PLUGIN_HTTP=1

# HTTP 超时（毫秒，默认 30000）
OPENCLI_PLUGIN_HTTP_TIMEOUT=30000

# GET/POST 实体体、以及 HEAD 时 curl -I 输出的头块，最大字节数（默认 2 MiB；超限返回 body_too_large）
OPENCLI_PLUGIN_HTTP_MAX_BODY_BYTES=2097152

# 允许的域名（逗号分隔，默认拒绝所有）
OPENCLI_PLUGIN_ALLOWED_DOMAINS=api.example.com,cdn.jsdelivr.net
```

**实现细节**：
- `httpGetSync` / `httpPostSync` / **`httpHeadSync`**（**`HttpClient.head`**，curl **`-I`**）使用 `StringHashMap` 构建 JSON 响应；**`opencli_plugin_api_version`**：**0.2.2** 起含 **HEAD**；**0.2.3** 起 **`http_error`** 与上表细对照
- 白名单检查函数：`checkUrlWhitelist`
- 启用检测：`isPluginHttpEnabled`
- 宿主在 QuickJS 全局注册 **`__opencli_http_get` / `__opencli_http_post` / `__opencli_http_request`**（C 原生），JS 侧由 `opencli.http` 包装为 `JSON.parse` 后的对象
4. 若同时配置了 **`pipeline`**，**优先执行 `script`**（与 `docs/TS_PARITY_MIGRATION_PLAN.md` 阶段 F 一致）。

脚本可执行副作用（如 **`opencli.log`**、全局状态）；与 TS 版完整插件 API 仍可继续对齐。

## 实现位置

- `src/plugin/quickjs_runtime.zig`：`evalExpressionToString`、`evalPluginHandlerBody`（命令脚本包装执行）。
- `src/plugin/manager.zig`：`loadPlugin` 中读取并执行 `js_init`；解析命令时处理 `script` 并写入 `Command.js_script_path`。
- `src/cli/runner.zig`：`executePluginQuickJs`（`source=plugin` 且存在 `js_script_path` 时优先于 pipeline）。

## 构建说明

`zig build` / `zig test` 会静态链接 `quickjs-ng`。需本机 C 工具链（与 Zig 构建 C 依赖相同）。

## 与 TS 版差异

TS 版可能在 Node 中跑完整适配器逻辑；此处 QuickJS 用于**轻量脚本钩子**，不替代 `type: ts` 的 legacy 清单项（后者默认返回 `ts_adapter_not_supported` 存根，见迁移计划阶段 B）。

## 可选：Node 子进程执行 `type: ts`（Wave 3.3）

若必须执行 legacy `type: ts` 适配器，可通过设置环境变量激活 **Node 子进程**执行路径：

```bash
# 启用 Node 子进程执行 ts_legacy 适配器
OPENCLI_ENABLE_NODE_SUBPROCESS=1
```

**工作原理**：
1. 当 `OPENCLI_ENABLE_NODE_SUBPROCESS=1` 时，Zig 版会在检测到 `source=ts_legacy` 命令时尝试用 `node <modulePath> <args>` 执行
2. Node.js 进程接收与 Zig CLI 相同的命令行参数
3. 适配器应将结果 JSON 输出到 stdout
4. Zig 版解析 stdout JSON 并返回结果

**前提条件**：
- `node` 命令必须在 PATH 中可用
- 适配器文件路径必须在 `cli-manifest.json` 的 `modulePath` 中正确指定

**环境变量（H.3 / 波次 3.3）**：
```bash
# Node 子进程最长存活（毫秒），默认 120000；设为 0 关闭超时杀死（仅 POSIX）
OPENCLI_NODE_SUBPROCESS_TIMEOUT_MS=120000

# 捕获 stdout 最大字节数，默认 10485760
OPENCLI_NODE_MAX_OUTPUT_BYTES=10485760
```

**错误处理**：
- 若 node 不可用或执行失败，自动回退到 `ts_adapter_not_supported` 存根响应
- 退出码非 0 时返回 `{ status: "node_error", exit_code: N, stderr: "..." }`
- JSON 解析失败时返回 `{ status: "parse_error", raw_output: "..." }`
- 超时后子进程可能被 **SIGKILL** 终止，表现为非 0 退出码或截断输出（见 `OPENCLI_NODE_SUBPROCESS_TIMEOUT_MS`）

**适用场景**：
- 商业/合规需要执行遗留 TypeScript 适配器
- 渐进式迁移：先用 stub 响应，后续再迁移到 Zig 原生实现

---

*与 `docs/TS_PARITY_MIGRATION_PLAN.md` 阶段 F 同步。*
