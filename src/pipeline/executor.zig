const std = @import("std");
const types = @import("../core/types.zig");
const errors = @import("../core/errors.zig");
const http = @import("../http/client.zig");
const cdp = @import("../browser/cdp.zig");
const format = @import("../output/format.zig");
const cache_mod = @import("../utils/cache.zig");

const OpenCliError = errors.OpenCliError;

fn jsonValueToOwnedString(allocator: std.mem.Allocator, v: std.json.Value) ![]const u8 {
    return std.json.Stringify.valueAlloc(allocator, v, .{});
}

/// Pipeline执行上下文
pub const PipelineContext = struct {
    allocator: std.mem.Allocator,
    config: *types.Config,
    variables: std.StringHashMap([]const u8),
    http_client: http.HttpClient,
    browser_controller: ?*cdp.BrowserController = null,
    /// `http_exec.fetchJson` 的 JSON 缓存；**`OPENCLI_CACHE=0`** 时不分配（与 TS diff 脚本一致）。
    http_json_cache: ?cache_mod.CacheManager = null,

    pub fn init(allocator: std.mem.Allocator, config: *types.Config) !PipelineContext {
        var http_client = try http.HttpClient.init(allocator);
        try http_client.setDefaultHeaders();
        try http_client.applyCookieFromEnv();
        // 所有经 `HttpClient.get/post/download` 的请求在 `request()` 内按 URL host 应用 `OPENCLI_<SITE>_COOKIE`；`http_exec` 入口仍 `applySiteCookieFromEnv(site)` 作未映射 host 的缺省。

        var http_json_cache: ?cache_mod.CacheManager = null;
        if (!cache_mod.adapterHttpJsonCacheDisabledByEnv()) {
            http_json_cache = cache_mod.CacheManager.initFromEnv(allocator);
        }

        return PipelineContext{
            .allocator = allocator,
            .config = config,
            .variables = std.StringHashMap([]const u8).init(allocator),
            .http_client = http_client,
            .http_json_cache = http_json_cache,
        };
    }

    pub fn deinit(self: *PipelineContext) void {
        if (self.http_json_cache) |*c| c.deinit();
        self.variables.deinit();
        self.http_client.deinit();
    }

    pub fn httpJsonCachePtr(self: *PipelineContext) ?*cache_mod.CacheManager {
        if (self.http_json_cache) |*c| return c;
        return null;
    }

    /// 单测用：与 **`init`** 相同，但 **`json_cache`** 为 true 时**始终**挂载 **`CacheManager.init`**（忽略 **`OPENCLI_CACHE`**），便于 **`executeFetch`** 缓存用例不入网。
    pub fn initForTesting(allocator: std.mem.Allocator, config: *types.Config, json_cache: bool) !PipelineContext {
        var http_client = try http.HttpClient.init(allocator);
        errdefer http_client.deinit();
        try http_client.setDefaultHeaders();
        try http_client.applyCookieFromEnv();

        var http_json_cache: ?cache_mod.CacheManager = null;
        if (json_cache) {
            http_json_cache = cache_mod.CacheManager.init(allocator);
        }

        return PipelineContext{
            .allocator = allocator,
            .config = config,
            .variables = std.StringHashMap([]const u8).init(allocator),
            .http_client = http_client,
            .http_json_cache = http_json_cache,
        };
    }

    /// 设置变量
    pub fn setVar(self: *PipelineContext, name: []const u8, value: []const u8) !void {
        try self.variables.put(name, value);
    }

    /// 获取变量
    pub fn getVar(self: *PipelineContext, name: []const u8) ?[]const u8 {
        return self.variables.get(name);
    }
};

/// 单测 **`executeFetch`** GET 的 mock 响应（**`body`** 须由 **`PipelineExecutor.allocator`** 分配，由 **`executeFetch`** 释放）。
pub const TestFetchGetResponse = struct {
    status: u16,
    body: []const u8,
};

pub const TestFetchGetFn = *const fn (exec: *PipelineExecutor, url: []const u8) anyerror!TestFetchGetResponse;

/// Pipeline执行器
pub const PipelineExecutor = struct {
    allocator: std.mem.Allocator,
    context: PipelineContext,
    browser_executor: ?cdp.BrowserStepExecutor = null,
    /// 非 null 时 **`executeFetch`** 的 **GET** 走该回调，不调用 **`http_client.get`**（单测 mock）。
    test_fetch_get: ?TestFetchGetFn = null,

    pub fn init(allocator: std.mem.Allocator, config: *types.Config) !PipelineExecutor {
        return PipelineExecutor{
            .allocator = allocator,
            .context = try PipelineContext.init(allocator, config),
            .browser_executor = null,
            .test_fetch_get = null,
        };
    }

    pub fn initForTesting(allocator: std.mem.Allocator, config: *types.Config, json_cache: bool) !PipelineExecutor {
        return PipelineExecutor{
            .allocator = allocator,
            .context = try PipelineContext.initForTesting(allocator, config, json_cache),
            .browser_executor = null,
            .test_fetch_get = null,
        };
    }

    pub fn deinit(self: *PipelineExecutor) void {
        self.context.deinit();
        if (self.browser_executor) |*be| {
            be.deinit();
        }
    }

    /// 执行Pipeline
    pub fn execute(
        self: *PipelineExecutor,
        pipeline: types.PipelineDef,
        args: std.StringHashMap([]const u8),
    ) !?std.json.Value {
        // 将参数转换为变量
        var it = args.iterator();
        while (it.next()) |entry| {
            try self.context.setVar(entry.key_ptr.*, entry.value_ptr.*);
        }

        var data: ?std.json.Value = null;

        // 执行每个步骤
        for (pipeline.steps, 0..) |step, i| {
            if (self.context.config.verbose) {
                std.log.info("Executing step {d}/{d}: {s}", .{ i + 1, pipeline.steps.len, step.name });
            }

            const result = try self.executeStep(step);
            if (result) |d| {
                if (data) |old| {
                    @import("../utils/cache.zig").destroyLeakyJsonValue(self.allocator, old);
                }
                data = d;
                const as_str = try jsonValueToOwnedString(self.allocator, d);
                try self.context.setVar("data", as_str);
            }
        }

        return data;
    }

    /// 执行单个步骤
    fn executeStep(self: *PipelineExecutor, step: types.PipelineDef.Step) !?std.json.Value {
        return switch (step.step_type) {
            .fetch => try self.executeFetch(step),
            .browser => try self.executeBrowser(step),
            .transform => try self.executeTransform(step),
            .download => try self.executeDownload(step),
            .tap => try self.executeTap(step),
            .intercept => try self.executeIntercept(step),
            .exec => try self.executeExec(step),
        };
    }

    /// 将已解析的 fetch 响应 JSON 应用可选 **`extract`**（与 **`http_exec.fetchJson`** 缓存语义一致：缓存存**完整** body，extract 在命中后同样执行）。
    fn finishFetchAfterParse(self: *PipelineExecutor, step: types.PipelineDef.Step, parsed: std.json.Value) !?std.json.Value {
        const cache = @import("../utils/cache.zig");
        if (step.config.get("extract")) |ext_path| {
            const inner = format.getNestedValue(parsed, ext_path);
            const s = try jsonValueToOwnedString(self.allocator, inner);
            defer self.allocator.free(s);
            const out = try std.json.parseFromSliceLeaky(std.json.Value, self.allocator, s, .{});
            cache.destroyLeakyJsonValue(self.allocator, parsed);
            return out;
        }
        return parsed;
    }

    /// 执行HTTP请求步骤
    fn executeFetch(self: *PipelineExecutor, step: types.PipelineDef.Step) !?std.json.Value {
        const url = step.config.get("url") orelse return null;
        const method = step.config.get("method") orelse "GET";

        // 模板替换
        const rendered_url = try self.renderTemplate(url);
        defer self.allocator.free(rendered_url);

        const is_get = std.mem.eql(u8, method, "GET");

        if (is_get) {
            if (self.context.httpJsonCachePtr()) |cm| {
                if (cm.getCachedJson(rendered_url)) |cached| {
                    const json_str = try std.json.Stringify.valueAlloc(self.allocator, cached, .{});
                    defer self.allocator.free(json_str);
                    const parsed = try std.json.parseFromSliceLeaky(std.json.Value, self.allocator, json_str, .{});
                    return try self.finishFetchAfterParse(step, parsed);
                }
            }
        }

        if (std.mem.eql(u8, method, "POST")) {
            var response = try self.context.http_client.post(rendered_url, null, null);
            defer {
                response.headers.deinit();
                self.allocator.free(response.body);
            }
            if (response.status >= 200 and response.status < 300) {
                const parsed = try std.json.parseFromSliceLeaky(
                    std.json.Value,
                    self.allocator,
                    response.body,
                    .{},
                );
                return try self.finishFetchAfterParse(step, parsed);
            }
            return null;
        }

        // GET（或默认）：可选单测 mock
        if (self.test_fetch_get) |hook| {
            const r = try hook(self, rendered_url);
            defer self.allocator.free(r.body);
            if (r.status < 200 or r.status >= 300) return null;
            const parsed = try std.json.parseFromSliceLeaky(
                std.json.Value,
                self.allocator,
                r.body,
                .{},
            );
            if (is_get) {
                if (self.context.httpJsonCachePtr()) |cm| {
                    cm.cacheJson(rendered_url, parsed) catch {};
                }
            }
            return try self.finishFetchAfterParse(step, parsed);
        }

        var response = try self.context.http_client.get(rendered_url);
        defer {
            response.headers.deinit();
            self.allocator.free(response.body);
        }

        if (response.status >= 200 and response.status < 300) {
            const parsed = try std.json.parseFromSliceLeaky(
                std.json.Value,
                self.allocator,
                response.body,
                .{},
            );
            if (is_get) {
                if (self.context.httpJsonCachePtr()) |cm| {
                    cm.cacheJson(rendered_url, parsed) catch {};
                }
            }
            return try self.finishFetchAfterParse(step, parsed);
        }

        return null;
    }

    /// 执行浏览器步骤
    fn executeBrowser(self: *PipelineExecutor, step: types.PipelineDef.Step) !?std.json.Value {
        // 初始化浏览器执行器
        if (self.browser_executor == null) {
            self.browser_executor = cdp.BrowserStepExecutor.init(self.allocator);
        }

        return try self.browser_executor.?.execute(step.config);
    }

    /// 执行数据转换步骤
    fn executeTransform(self: *PipelineExecutor, step: types.PipelineDef.Step) !?std.json.Value {
        const transform_mod = @import("transform.zig");

        if (step.config.get("operation")) |op_name| {
            if (std.mem.eql(u8, op_name, "limit")) {
                const count_str = step.config.get("count") orelse return null;
                const rendered = try self.renderTemplate(count_str);
                defer self.allocator.free(rendered);
                const n = std.fmt.parseInt(usize, rendered, 10) catch return null;

                const input_key = step.config.get("input") orelse "data";
                const input_data = self.context.getVar(input_key) orelse return null;

                const value = std.json.parseFromSliceLeaky(std.json.Value, self.allocator, input_data, .{}) catch |err| {
                    std.log.warn("Failed to parse transform input: {}", .{err});
                    return null;
                };

                switch (value) {
                    .array => |arr| {
                        const take = @min(n, arr.items.len);
                        var out = std.json.Array.init(self.allocator);
                        for (0..take) |i| {
                            try out.append(arr.items[i]);
                        }
                        return std.json.Value{ .array = out };
                    },
                    else => return value,
                }
            }
        }

        const input_key = step.config.get("input") orelse "data";
        const input_data = self.context.getVar(input_key);

        if (input_data == null) return null;

        const value = std.json.parseFromSliceLeaky(std.json.Value, self.allocator, input_data.?, .{}) catch |err| {
            std.log.warn("Failed to parse transform input: {}", .{err});
            return null;
        };

        var executor = transform_mod.TransformExecutor.init(self.allocator);
        defer executor.deinit();

        const query = step.config.get("query") orelse ".";

        if (transform_mod.parseSimpleQuery(query)) |op| {
            const result = executor.execute(value, op) catch |err| {
                std.log.warn("Transform execution failed: {}", .{err});
                @import("../utils/cache.zig").destroyLeakyJsonValue(self.allocator, value);
                return null;
            };
            @import("../utils/cache.zig").destroyLeakyJsonValue(self.allocator, value);
            return result;
        }
        return value;
    }

    /// 执行下载步骤
    fn executeDownload(self: *PipelineExecutor, step: types.PipelineDef.Step) !?std.json.Value {
        const url = step.config.get("url") orelse return null;
        const output = step.config.get("output") orelse return null;

        const rendered_url = try self.renderTemplate(url);
        defer self.allocator.free(rendered_url);

        const rendered_output = try self.renderTemplate(output);
        defer self.allocator.free(rendered_output);

        try self.context.http_client.download(rendered_url, rendered_output);

        return std.json.Value{ .string = rendered_output };
    }

    /// 执行调试输出步骤
    fn executeTap(self: *PipelineExecutor, step: types.PipelineDef.Step) !?std.json.Value {
        const label = step.config.get("label") orelse "tap";
        const stdout = std.fs.File.stdout().deprecatedWriter();

        try stdout.print("[{s}] Variables:\n", .{label});
        var it = self.context.variables.iterator();
        while (it.next()) |entry| {
            try stdout.print("  {s} = {s}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }

        return null;
    }

    /// 执行拦截步骤
    fn executeIntercept(self: *PipelineExecutor, step: types.PipelineDef.Step) !?std.json.Value {
        const interceptor = @import("../browser/interceptor.zig");

        // Get intercept configuration
        const pattern = step.config.get("pattern") orelse "*";
        const intercept_type_str = step.config.get("type") orelse "all";
        const action_str = step.config.get("action") orelse "log";

        // InterceptType：request / response / all（与仅记录等 action 无关）
        const intercept_type = std.meta.stringToEnum(interceptor.InterceptType, intercept_type_str) orelse .all;

        // Create action
        var action: interceptor.InterceptRule.Action = undefined;
        if (std.mem.eql(u8, action_str, "block")) {
            action = .{ .block = {} };
        } else if (std.mem.eql(u8, action_str, "log")) {
            action = .{ .log = {} };
        } else {
            action = .{ .log = {} };
        }

        // Create interceptor if not exists
        if (self.context.browser_controller) |controller| {
            var net_interceptor = interceptor.NetworkInterceptor.init(self.allocator);
            defer net_interceptor.deinit();

            // Set browser controller
            net_interceptor.setBrowserController(controller);

            // Add rule
            const rule_id = try net_interceptor.addRule(pattern, intercept_type, action);

            if (self.context.config.verbose) {
                std.log.info("Network interceptor rule added: id={d}, pattern={s}", .{ rule_id, pattern });
            }
        } else {
            std.log.warn("Browser controller not initialized, skipping intercept step", .{});
        }

        return null;
    }

    /// 执行外部CLI步骤
    /// 支持的配置项:
    ///   - binary:       二进制名称或路径 (必需)
    ///   - args:         空格分隔的参数 (与 argv 二选一)
    ///   - argv:         逗号分隔的参数 (与 args 二选一)
    ///   - cwd:          工作目录 (可选)
    ///   - env:          环境变量，格式: KEY1=VALUE1,KEY2=VALUE2 (可选)
    ///   - inherit_env:  是否继承父进程环境变量，默认 true (可选)
    ///   - stdin:        标准输入数据 (可选)
    ///   - timeout:      超时毫秒数 (可选)
    ///   - skip_which:   跳过二进制检查，默认 false (可选)
    fn executeExec(self: *PipelineExecutor, step: types.PipelineDef.Step) !?std.json.Value {
        const binary = step.config.get("binary") orelse {
            std.log.warn("exec step missing 'binary' config", .{});
            return null;
        };

        // Check if we should skip the binary existence check
        const skip_which = if (step.config.get("skip_which")) |v|
            std.mem.eql(u8, v, "true") or std.mem.eql(u8, v, "1")
        else
            false;

        // Check if binary exists using which (unless skip_which is true)
        if (!skip_which) {
            const which_result = std.process.Child.run(.{
                .allocator = self.allocator,
                .argv = &[_][]const u8{ "which", binary },
            }) catch {
                std.log.warn("Failed to run 'which' command", .{});
                return null;
            };
            defer self.allocator.free(which_result.stdout);
            defer self.allocator.free(which_result.stderr);

            if (which_result.term.Exited != 0) {
                std.log.warn("Binary '{s}' not found in PATH", .{binary});
                return null;
            }
        }

        // Build arguments - support both "args" (single string) and "argv" (array-like)
        var args_list = std.ArrayListUnmanaged([]const u8){};
        defer {
            for (args_list.items) |item| {
                self.allocator.free(item);
            }
        }

        if (step.config.get("args")) |args_str| {
            // Support template rendering for args
            const rendered_args = try self.renderTemplate(args_str);
            defer self.allocator.free(rendered_args);

            // Split args by space (simple approach)
            var args_iter = std.mem.splitScalar(u8, rendered_args, ' ');
            while (args_iter.next()) |arg| {
                if (arg.len > 0) {
                    const arg_copy = try self.allocator.dupe(u8, arg);
                    try args_list.append(self.allocator, arg_copy);
                }
            }
        } else if (step.config.get("argv")) |argv_str| {
            // Support comma-separated args
            const rendered_args = try self.renderTemplate(argv_str);
            defer self.allocator.free(rendered_args);

            var args_iter = std.mem.splitScalar(u8, rendered_args, ',');
            while (args_iter.next()) |arg| {
                const trimmed = std.mem.trim(u8, arg, " ");
                if (trimmed.len > 0) {
                    const arg_copy = try self.allocator.dupe(u8, trimmed);
                    try args_list.append(self.allocator, arg_copy);
                }
            }
        }

        // Build the full command array
        var cmd_args = std.ArrayListUnmanaged([]const u8){};
        defer {
            for (cmd_args.items) |item| {
                self.allocator.free(item);
            }
        }
        try cmd_args.append(self.allocator, try self.allocator.dupe(u8, binary));
        for (args_list.items) |arg| {
            try cmd_args.append(self.allocator, arg);
        }

        // Initialize child process
        var child = std.process.Child.init(cmd_args.items, self.allocator);
        child.stdin_behavior = .Close;
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        // Set working directory if specified
        if (step.config.get("cwd")) |cwd_str| {
            const rendered_cwd = try self.renderTemplate(cwd_str);
            child.cwd = rendered_cwd;
        }

        // Set up environment variables
        const inherit_env = if (step.config.get("inherit_env")) |v|
            !std.mem.eql(u8, v, "false") and !std.mem.eql(u8, v, "0")
        else
            true;

        if (inherit_env) {
            // Inherit current environment - set to null to use parent environment
            child.env_map = null;
        }

        // Add custom environment variables if specified
        if (step.config.get("env")) |env_str| {
            const rendered_env = try self.renderTemplate(env_str);
            defer self.allocator.free(rendered_env);

            // Parse KEY1=VALUE1,KEY2=VALUE2 format
            var env_iter = std.mem.splitScalar(u8, rendered_env, ',');
            while (env_iter.next()) |env_pair| {
                if (std.mem.indexOf(u8, env_pair, "=")) |eq_idx| {
                    const key = std.mem.trim(u8, env_pair[0..eq_idx], " ");
                    const value = std.mem.trim(u8, env_pair[eq_idx + 1 ..], " ");
                    // Note: In a full implementation, we would merge into a custom env_map
                    // For now, log the intended behavior
                    if (self.context.config.verbose) {
                        std.log.info("exec env: {s}={s}", .{ key, value });
                    }
                }
            }
        }

        // Spawn the child process
        child.spawn() catch {
            std.log.warn("exec '{s}' failed to spawn", .{binary});
            return null;
        };

        // Handle stdin if specified
        if (step.config.get("stdin")) |stdin_str| {
            const rendered_stdin = try self.renderTemplate(stdin_str);
            defer self.allocator.free(rendered_stdin);

            if (child.stdin) |*stdin_file| {
                stdin_file.writeAll(rendered_stdin) catch {
                    std.log.warn("exec '{s}' failed to write stdin", .{binary});
                    _ = child.wait() catch {};
                    return null;
                };
            }
        }

        // Wait for the child with optional timeout
        var wait_result: std.process.Child.Term = undefined;
        const timeout_ms = if (step.config.get("timeout")) |timeout_str|
            std.fmt.parseInt(u32, timeout_str, 10) catch 0
        else
            0;

        if (timeout_ms > 0) {
            // Wait with timeout using a timer thread
            const timeout_ns = timeout_ms * std.time.ns_per_ms;
            const child_ptr = &child;
            const timeout_thread = try std.Thread.spawn(.{}, struct {
                fn timerWait(cp: *std.process.Child, timeout: u64) void {
                    std.Thread.sleep(timeout);
                    _ = cp.kill() catch {};
                }
            }.timerWait, .{ child_ptr, timeout_ns });

            wait_result = child.wait() catch {
                std.log.warn("exec '{s}' wait failed", .{binary});
                _ = child.kill() catch {};
                timeout_thread.detach();
                return null;
            };
            timeout_thread.detach();
        } else {
            wait_result = child.wait() catch {
                std.log.warn("exec '{s}' wait failed", .{binary});
                _ = child.kill() catch {};
                return null;
            };
        }

        // Collect stdout and stderr
        const stdout = child.stdout.?.readToEndAlloc(self.allocator, 10 * 1024 * 1024) catch "";
        const stderr = child.stderr.?.readToEndAlloc(self.allocator, 1024 * 1024) catch "";
        defer {
            self.allocator.free(stdout);
            self.allocator.free(stderr);
        }

        // Log stderr if verbose and command failed
        if (self.context.config.verbose and wait_result.Exited != 0) {
            std.log.warn("exec '{s}' stderr: {s}", .{ binary, stderr });
        }

        if (wait_result.Exited != 0) {
            std.log.warn("exec '{s}' exited with code {d}", .{ binary, wait_result.Exited });
            // Optionally return error info in result
            if (self.context.config.verbose) {
                return std.json.Value{ .string = try self.allocator.dupe(u8, stderr) };
            }
            return null;
        }

        // Try to parse stdout as JSON
        const trimmed_stdout = std.mem.trim(u8, stdout, " \n\r\t");
        if (trimmed_stdout.len > 0) {
            if (trimmed_stdout[0] == '{' or trimmed_stdout[0] == '[') {
                // It's JSON, parse it
                return std.json.parseFromSliceLeaky(std.json.Value, self.allocator, trimmed_stdout, .{}) catch {
                    // If JSON parsing fails, return as string
                    return std.json.Value{ .string = try self.allocator.dupe(u8, stdout) };
                };
            } else {
                // Return as string
                return std.json.Value{ .string = try self.allocator.dupe(u8, stdout) };
            }
        }

        return null;
    }

    /// 模板替换
    fn renderTemplate(self: *PipelineExecutor, template: []const u8) ![]const u8 {
        var result = std.array_list.Managed(u8).init(self.allocator);
        defer result.deinit();

        var i: usize = 0;
        while (i < template.len) {
            if (std.mem.startsWith(u8, template[i..], "{{")) {
                if (std.mem.indexOf(u8, template[i..], "}}")) |end| {
                    const var_name = std.mem.trim(u8, template[i + 2 .. i + end], " ");

                    var resolved: ?[]const u8 = null;
                    if (self.context.getVar(var_name)) |value| {
                        resolved = value;
                    } else if (std.mem.startsWith(u8, var_name, "args.")) {
                        const arg_key = var_name["args.".len..];
                        resolved = self.context.getVar(arg_key);
                    }
                    if (resolved) |value| {
                        try result.appendSlice(value);
                    } else {
                        try result.appendSlice(template[i .. i + end + 2]);
                    }

                    i += end + 2;
                    continue;
                }
            }

            try result.append(template[i]);
            i += 1;
        }

        return result.toOwnedSlice();
    }
};
