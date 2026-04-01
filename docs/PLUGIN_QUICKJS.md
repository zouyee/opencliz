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
3. 宿主注入 **`opencli`**（同一函数作用域）：**`opencli.args`**、**`opencli.version`**（见 `opencli_plugin_api_version`）、**`opencli.log(message)`**（QuickJS **`print`**，行前缀 **`[opencli] `**，供排障；非结构化日志通道）。**HTTP 等 native 能力**仍待迭代。

### 待实现：`opencli.http` native 桥（Wave 3.2）

> ⚠️ **规划中**：以下功能尚未实现，计划在 Wave 3.2 完成。

| API | 说明 | 安全考虑 |
|-----|------|---------|
| `opencli.http.get(url)` | 发起 GET 请求 | 需要 URL 白名单验证 |
| `opencli.http.post(url, body)` | 发起 POST 请求 | 需要 URL 白名单 + body 验证 |
| `opencli.http.request(method, url, options)` | 通用请求 | 完整安全模型 |

**安全模型设计**：
1. **URL 白名单**：默认只允许 `https://` 开头，且在白名单列表中
2. **超时**：默认 30 秒超时，防止恶意脚本阻塞
3. **方法限制**：默认只允许 GET/POST
4. **敏感头过滤**：不暴露内部 Cookie/Token 给插件

**配置环境变量**（规划中）：
```bash
# 启用插件 HTTP（规划中，默认关闭）
OPENCLI_PLUGIN_HTTP=1

# HTTP 超时（毫秒）
OPENCLI_PLUGIN_HTTP_TIMEOUT=30000

# 允许的域名（逗号分隔，规划中）
OPENCLI_PLUGIN_ALLOWED_DOMAINS=api.example.com,cdn.jsdelivr.net
```
4. 若同时配置了 **`pipeline`**，**优先执行 `script`**（与 `docs/TS_PARITY_MIGRATION_PLAN.md` 阶段 F 一致）。

脚本可执行副作用（如 **`opencli.log`**、全局状态）；与 TS 版完整插件 API 仍可继续对齐。

## 实现位置

- `src/plugin/quickjs_runtime.zig`：`evalExpressionToString`、`evalPluginHandlerBody`（命令脚本包装执行）。
- `src/plugin/manager.zig`：`loadPlugin` 中读取并执行 `js_init`；解析命令时处理 `script` 并写入 `Command.js_script_path`。
- `src/cli/runner.zig`：`executePluginQuickJs`（`source=plugin` 且存在 `js_script_path` 时优先于 pipeline）。

## 构建说明

`zig build` / `zig test` 会静态链接 `quickjs-ng`。需本机 C 工具链（与 Zig 构建 C 依赖相同）。

## 与 TS 版差异

TS 版可能在 Node 中跑完整适配器逻辑；此处 QuickJS 用于**轻量脚本钩子**，不替代 `type: ts` 的 legacy 清单项（后者仍为 `ts_legacy` 存根，见迁移计划阶段 B）。

---

*与 `docs/TS_PARITY_MIGRATION_PLAN.md` 阶段 F 同步。*
