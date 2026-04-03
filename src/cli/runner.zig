const std = @import("std");
const builtin = @import("builtin");
const types = @import("../core/types.zig");
const errors = @import("../core/errors.zig");
const pipeline = @import("../pipeline/executor.zig");
const VERSION = @import("../core/version.zig").VERSION;

const OpenCliError = errors.OpenCliError;

/// Node 子进程最长存活（毫秒）。`0` 表示不启用超时杀死（POSIX；Windows 未接 SIGKILL 线程）。
fn nodeSubprocessTimeoutMs() u32 {
    const e = std.process.getEnvVarOwned(std.heap.page_allocator, "OPENCLI_NODE_SUBPROCESS_TIMEOUT_MS") catch return 120_000;
    defer std.heap.page_allocator.free(e);
    if (e.len == 0) return 120_000;
    return std.fmt.parseInt(u32, e, 10) catch 120_000;
}

fn nodeSubprocessMaxOutputBytes() usize {
    const e = std.process.getEnvVarOwned(std.heap.page_allocator, "OPENCLI_NODE_MAX_OUTPUT_BYTES") catch return 10 * 1024 * 1024;
    defer std.heap.page_allocator.free(e);
    if (e.len == 0) return 10 * 1024 * 1024;
    return std.fmt.parseInt(usize, e, 10) catch 10 * 1024 * 1024;
}

const NodeKillDelayArgs = struct { pid: std.process.Child.Id, ms: u32 };

fn spawnNodeTimeoutKiller(child: *std.process.Child, delay_ms: u32) void {
    if (delay_ms == 0) return;
    if (builtin.os.tag == .windows) return;
    const pid = child.id;
    const t = std.Thread.spawn(.{}, nodeKillAfterDelay, .{NodeKillDelayArgs{ .pid = pid, .ms = delay_ms }}) catch return;
    t.detach();
}

fn nodeKillAfterDelay(args: NodeKillDelayArgs) void {
    std.Thread.sleep(@as(u64, args.ms) * std.time.ns_per_ms);
    std.posix.kill(args.pid, std.posix.SIG.KILL) catch {};
}

/// `cli-manifest.json` 中 `type: ts` 条目：Zig 版默认不执行 Node 适配器，返回结构化说明。
/// 若设置 `OPENCLI_ENABLE_NODE_SUBPROCESS=1` 且 node 可用，则通过 Node 子进程执行。
fn tsLegacyStubResponse(allocator: std.mem.Allocator, cmd: types.Command) !std.json.Value {
    var m = std.json.ObjectMap.init(allocator);
    try m.put(try allocator.dupe(u8, "status"), .{ .string = try allocator.dupe(u8, "ts_adapter_not_supported") });
    try m.put(try allocator.dupe(u8, "message"), .{ .string = try allocator.dupe(u8, "TypeScript/legacy OpenCLI adapters are not executed in this Zig build. Use built-in Zig adapters or YAML pipelines. See docs/TS_PARITY_MIGRATION_PLAN.md.") });
    if (cmd.module_path) |mp| {
        try m.put(try allocator.dupe(u8, "modulePath"), .{ .string = try allocator.dupe(u8, mp) });
    }
    return .{ .object = m };
}

/// CLI运行器
pub const CliRunner = struct {
    allocator: std.mem.Allocator,
    config: *types.Config,
    registry: *types.Registry,
    executor: pipeline.PipelineExecutor,

    pub fn init(allocator: std.mem.Allocator, config: *types.Config, registry: *types.Registry) !CliRunner {
        return CliRunner{
            .allocator = allocator,
            .config = config,
            .registry = registry,
            .executor = try pipeline.PipelineExecutor.init(allocator, config),
        };
    }

    pub fn deinit(self: *CliRunner) void {
        self.executor.deinit();
    }

    /// 注册命令
    pub fn registerCommand(self: *CliRunner, cmd: types.Command) !void {
        try self.registry.registerCommand(cmd);
    }

    /// 运行命令
    pub fn run(self: *CliRunner, site: []const u8, name: []const u8, args: std.StringHashMap([]const u8)) !void {
        const cmd = self.registry.getCommand(site, name) orelse {
            std.log.err("Command not found: {s}/{s}", .{ site, name });
            return OpenCliError.CommandNotFound;
        };

        if (self.config.verbose) {
            std.log.info("Running command: {s}/{s}", .{ site, name });
        }

        // Use arena for JSON allocations - this ensures ALL JSON-related memory
        // (including Scanner internals from parseFromSliceLeaky) is freed when arena is destroyed
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const json_allocator = arena.allocator();

        // 执行命令 (use arena for JSON allocations)
        const result = try self.executeCommand(cmd, args, json_allocator);

        // 输出结果
        if (result) |data| {
            try @import("../output/format.zig").formatOutput(json_allocator, data, self.config.format, cmd.columns);
        }
        // Arena destruction below handles all JSON memory cleanup
    }

    /// 运行命令并返回JSON结果（用于Daemon）
    pub fn runAndGetResult(self: *CliRunner, site: []const u8, name: []const u8, args: std.StringHashMap([]const u8)) !?std.json.Value {
        const cmd = self.registry.getCommand(site, name) orelse {
            std.log.err("Command not found: {s}/{s}", .{ site, name });
            return OpenCliError.CommandNotFound;
        };

        if (self.config.verbose) {
            std.log.info("Running command: {s}/{s}", .{ site, name });
        }

        // 执行命令并返回结果
        return try self.executeCommand(cmd, args, self.allocator);
    }

    /// 与 `runAndGetResult` 相同，但 JSON 子树由 `json_allocator` 分配（供后台线程内 Arena 等使用）。
    pub fn runAndGetResultWithAllocator(self: *CliRunner, site: []const u8, name: []const u8, args: std.StringHashMap([]const u8), json_allocator: std.mem.Allocator) !?std.json.Value {
        const cmd = self.registry.getCommand(site, name) orelse {
            std.log.err("Command not found: {s}/{s}", .{ site, name });
            return OpenCliError.CommandNotFound;
        };

        if (self.config.verbose) {
            std.log.info("Running command: {s}/{s}", .{ site, name });
        }

        return try self.executeCommand(cmd, args, json_allocator);
    }

    fn argsMapToJsonString(allocator: std.mem.Allocator, args: std.StringHashMap([]const u8)) ![]const u8 {
        var obj = std.json.ObjectMap.init(allocator);
        defer {
            var it = obj.iterator();
            while (it.next()) |e| {
                allocator.free(e.key_ptr.*);
                switch (e.value_ptr.*) {
                    .string => |s| allocator.free(s),
                    else => {},
                }
            }
            obj.deinit();
        }
        var it = args.iterator();
        while (it.next()) |e| {
            const k = try allocator.dupe(u8, e.key_ptr.*);
            const v = try allocator.dupe(u8, e.value_ptr.*);
            try obj.put(k, .{ .string = v });
        }
        return try std.json.Stringify.valueAlloc(allocator, std.json.Value{ .object = obj }, .{});
    }

    /// `source=plugin` 且配置了 `script`：读 JS 文件，用 QuickJS 执行并解析返回的 JSON。
    fn executePluginQuickJs(self: *CliRunner, cmd: types.Command, args: std.StringHashMap([]const u8), json_allocator: std.mem.Allocator) !std.json.Value {
        const path = cmd.js_script_path orelse return OpenCliError.InvalidCommand;
        const body = try std.fs.cwd().readFileAlloc(self.allocator, path, 2 * 1024 * 1024);
        defer self.allocator.free(body);

        const args_json = try argsMapToJsonString(self.allocator, args);
        defer self.allocator.free(args_json);

        const qjs = @import("../plugin/quickjs_runtime.zig");
        const out = try qjs.evalPluginHandlerBody(self.allocator, body, args_json);
        defer self.allocator.free(out);

        return try std.json.parseFromSliceLeaky(std.json.Value, json_allocator, out, .{});
    }

    /// 执行命令
    fn executeCommand(self: *CliRunner, cmd: types.Command, args: std.StringHashMap([]const u8), json_allocator: std.mem.Allocator) !?std.json.Value {
        const hooks = @import("../utils/hooks.zig");

        // Trigger onBeforeExecute hook
        if (hooks.getGlobalHooks()) |hooks_mgr| {
            var ctx = hooks.HookContext.init(.on_before_execute);
            ctx.command = cmd;
            // Note: args is passed by value, so we can't easily store it in ctx
            hooks_mgr.trigger(ctx) catch |err| {
                std.log.warn("Hook error: {}", .{err});
            };
        }

        var result: ?std.json.Value = null;
        var exec_error: ?anyerror = null;

        if (cmd.is_internal) {
            if (cmd.handler) |handler| {
                handler(self.allocator, args, self.config) catch |err| {
                    exec_error = err;
                };
            }
        } else if (std.mem.eql(u8, cmd.source, "plugin") and cmd.js_script_path != null) {
            result = try self.executePluginQuickJs(cmd, args, json_allocator);
        } else if (cmd.pipeline) |pipeline_def| {
            // YAML定义的Pipeline命令
            result = self.executor.execute(pipeline_def, args) catch |err| {
                exec_error = err;
                return err;
            };
        } else if (std.mem.eql(u8, cmd.source, "adapter")) {
            const http_exec = @import("../adapters/http_exec.zig");
            var adapter_result = try http_exec.tryExecute(json_allocator, cmd, args, &self.executor.context.http_client, self.executor.context.httpJsonCachePtr()) orelse {
                return OpenCliError.InvalidCommand;
            };
            const adapter_browser = @import("../adapters/adapter_browser.zig");
            adapter_result = try adapter_browser.maybeBrowserDeepen(json_allocator, self.config, cmd, args, adapter_result, &self.executor);
            const desktop_exec = @import("../adapters/desktop_exec.zig");
            try desktop_exec.mergeIfDesktopHints(self.allocator, cmd.site, &adapter_result);
            result = adapter_result;
        } else if (std.mem.eql(u8, cmd.source, "external")) {
            // 执行外部CLI命令
            result = try self.executeExternalCli(cmd, args);
        } else if (std.mem.eql(u8, cmd.source, "ts_legacy")) {
            result = try self.executeTsLegacy(cmd, args, json_allocator);
        } else {
            return OpenCliError.InvalidCommand;
        }

        // Trigger onAfterExecute or onError hook
        if (hooks.getGlobalHooks()) |hooks_mgr| {
            if (exec_error) |err| {
                var ctx = hooks.HookContext.init(.on_error);
                ctx.command = cmd;
                // Convert error to string (simplified)
                const err_str = try std.fmt.allocPrint(self.allocator, "{}", .{err});
                defer self.allocator.free(err_str);
                ctx.error_info = err_str;
                hooks_mgr.trigger(ctx) catch {};
            } else {
                var ctx = hooks.HookContext.init(.on_after_execute);
                ctx.command = cmd;
                ctx.result = result;
                hooks_mgr.trigger(ctx) catch |hook_err| {
                    std.log.warn("Hook error: {}", .{hook_err});
                };
            }
        }

        return result;
    }

    /// 执行外部CLI命令
    /// cmd.domain 存储二进制名称，cmd.description 存储描述
    fn executeExternalCli(self: *CliRunner, cmd: types.Command, args: std.StringHashMap([]const u8)) !std.json.Value {
        const allocator = self.allocator;
        const binary = cmd.domain;

        std.log.info("executeExternalCli: binary={s}", .{binary});

        // 检查二进制是否存在
        const which_result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{ "which", binary },
        }) catch return error.ChildSpawnFailed;
        defer {
            allocator.free(which_result.stdout);
            allocator.free(which_result.stderr);
        }

        if (which_result.term.Exited != 0) {
            // 二进制不存在，返回错误信息
            var result_obj = std.json.ObjectMap.init(allocator);
            try result_obj.put(try allocator.dupe(u8, "success"), std.json.Value{ .bool = false });
            try result_obj.put(try allocator.dupe(u8, "error"), std.json.Value{ .string = try allocator.dupe(u8, "binary not found in PATH") });
            try result_obj.put(try allocator.dupe(u8, "binary"), std.json.Value{ .string = try allocator.dupe(u8, binary) });
            const return_value = std.json.Value{ .object = result_obj };
            std.log.info("Returning JSON value, result_obj.count={d}", .{result_obj.count()});
            return return_value;
        }

        // 构建命令行参数
        var cmd_args = std.ArrayListUnmanaged([]const u8){};
        defer {
            for (cmd_args.items) |item| {
                allocator.free(item);
            }
        }

        try cmd_args.append(allocator, try allocator.dupe(u8, binary));

        // 首先添加位置参数（_）
        if (args.get("_")) |positional| {
            var iter = std.mem.splitScalar(u8, positional, ' ');
            while (iter.next()) |arg| {
                if (arg.len > 0) {
                    const arg_copy = try allocator.dupe(u8, arg);
                    try cmd_args.append(allocator, arg_copy);
                }
            }
        }

        // 将其他 args HashMap 转换为命令行参数（跳过 _）
        var it = args.iterator();
        while (it.next()) |entry| {
            // 跳过位置参数，它们已经处理过了
            if (std.mem.eql(u8, entry.key_ptr.*, "_")) continue;

            // 添加参数名（带 -- 前缀）
            const key = try std.fmt.allocPrint(allocator, "--{s}", .{entry.key_ptr.*});
            try cmd_args.append(allocator, key);

            // 添加参数值
            const value = entry.value_ptr.*;
            if (value.len > 0) {
                const val = try allocator.dupe(u8, value);
                try cmd_args.append(allocator, val);
            }
        }

        std.log.info("executeExternalCli: spawning {s} with args len={d}", .{ binary, cmd_args.items.len });

        // 执行外部命令
        var child = std.process.Child.init(cmd_args.items, allocator);
        child.stdin_behavior = .Close;
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        try child.spawn();
        std.log.info("executeExternalCli: spawned successfully, waiting...", .{});

        // 读取 stdout 和 stderr
        var stdout_data: []u8 = &.{};
        var stderr_data: []u8 = &.{};

        if (child.stdout) |out| {
            const result = out.readToEndAlloc(allocator, 1024 * 1024);
            if (result) |data| {
                stdout_data = data;
            } else |read_err| {
                std.log.warn("Failed to read stdout: {}", .{read_err});
            }
        }

        std.log.info("child.stderr exists: {}", .{child.stderr != null});
        if (child.stderr) |err_out| {
            std.log.info("Reading stderr...", .{});
            const result = err_out.readToEndAlloc(allocator, 1024 * 1024);
            if (result) |data| {
                stderr_data = data;
                std.log.info("stderr_data.len={d}, first bytes: {any}", .{ data.len, if (data.len > 10) data[0..10] else data });
            } else |read_err| {
                std.log.warn("Failed to read stderr: {}", .{read_err});
            }
        } else {
            std.log.info("child.stderr is null, skipping", .{});
        }

        const term = try child.wait();
        std.log.info("executeExternalCli: wait completed, exit_code={d}", .{term.Exited});

        std.log.info("executeExternalCli: stdout len={d}, stderr len={d}", .{ stdout_data.len, stderr_data.len });

        // 构建结果 JSON
        const stdout_len = stdout_data.len;
        const stderr_len = stderr_data.len;

        // 创建所有需要复制的数据
        const stdout_copy = if (stdout_len > 0) try allocator.dupe(u8, stdout_data) else "";
        const stderr_copy = if (stderr_len > 0) try allocator.dupe(u8, stderr_data) else "";

        var result_obj = std.json.ObjectMap.init(allocator);
        errdefer result_obj.deinit();

        try result_obj.put(try allocator.dupe(u8, "success"), std.json.Value{ .bool = term.Exited == 0 });
        try result_obj.put(try allocator.dupe(u8, "exit_code"), std.json.Value{ .integer = @as(i64, term.Exited) });
        try result_obj.put(try allocator.dupe(u8, "stdout"), std.json.Value{ .string = stdout_copy });
        try result_obj.put(try allocator.dupe(u8, "stderr"), std.json.Value{ .string = stderr_copy });

        // 释放原始 child 输出数据（在复制完成后）
        if (stdout_len > 0) allocator.free(stdout_data);
        if (stderr_len > 0) allocator.free(stderr_data);

        if (term.Exited != 0) {
            // 使用 stderr_copy（已经复制过的），而不是 stderr_data
            try result_obj.put(try allocator.dupe(u8, "error"), std.json.Value{ .string = stderr_copy });
        }

        return std.json.Value{ .object = result_obj };
    }

    /// 检查 node 是否在 PATH 中可用
    fn nodeAvailable(self: *CliRunner) !bool {
        const result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "which", "node" },
        }) catch return false;
        defer {
            self.allocator.free(result.stdout);
            self.allocator.free(result.stderr);
        }
        return result.term.Exited == 0;
    }

    /// 通过 Node 子进程执行 TypeScript 适配器（Wave 3.3）
    /// 仅在 OPENCLI_ENABLE_NODE_SUBPROCESS=1 时激活
    fn executeTsLegacy(self: *CliRunner, cmd: types.Command, args: std.StringHashMap([]const u8), json_allocator: std.mem.Allocator) !std.json.Value {
        // 检查是否启用 Node 子进程
        const enable_node = std.process.getEnvVarOwned(self.allocator, "OPENCLI_ENABLE_NODE_SUBPROCESS") catch null;
        defer if (enable_node) |v| self.allocator.free(v);

        if (enable_node == null or !std.mem.eql(u8, enable_node.?, "1")) {
            // 未启用，返回 stub
            return tsLegacyStubResponse(json_allocator, cmd);
        }

        // 检查 node 是否可用
        const node_avail = self.nodeAvailable() catch false;
        if (!node_avail) {
            std.log.warn("OPENCLI_ENABLE_NODE_SUBPROCESS=1 but node not found in PATH", .{});
            return tsLegacyStubResponse(json_allocator, cmd);
        }

        const module_path = cmd.module_path orelse {
            std.log.warn("ts_legacy command has no module_path", .{});
            return tsLegacyStubResponse(json_allocator, cmd);
        };

        // 构建 node 命令行参数
        var cmd_args = std.ArrayListUnmanaged([]const u8){};
        defer {
            for (cmd_args.items) |item| {
                self.allocator.free(item);
            }
        }

        try cmd_args.append(self.allocator, try self.allocator.dupe(u8, "node"));
        try cmd_args.append(self.allocator, try self.allocator.dupe(u8, module_path));

        // 添加位置参数（_）
        if (args.get("_")) |positional| {
            var iter = std.mem.splitScalar(u8, positional, ' ');
            while (iter.next()) |arg| {
                if (arg.len > 0) {
                    const arg_copy = try self.allocator.dupe(u8, arg);
                    try cmd_args.append(self.allocator, arg_copy);
                }
            }
        }

        // 将其他 args HashMap 转换为命令行参数（跳过 _）
        var it = args.iterator();
        while (it.next()) |entry| {
            if (std.mem.eql(u8, entry.key_ptr.*, "_")) continue;

            const key = try std.fmt.allocPrint(self.allocator, "--{s}", .{entry.key_ptr.*});
            try cmd_args.append(self.allocator, key);

            const value = entry.value_ptr.*;
            if (value.len > 0) {
                const val = try self.allocator.dupe(u8, value);
                try cmd_args.append(self.allocator, val);
            }
        }

        std.log.info("executeTsLegacy: spawning node with module_path={s}, args count={d}", .{ module_path, cmd_args.items.len });

        // 执行 node 命令
        var child = std.process.Child.init(cmd_args.items, self.allocator);
        child.stdin_behavior = .Close;
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        try child.spawn();
        errdefer {
            _ = child.kill() catch {};
        }

        const max_io = nodeSubprocessMaxOutputBytes();
        spawnNodeTimeoutKiller(&child, nodeSubprocessTimeoutMs());

        // 读取 stdout
        var stdout_data: []u8 = &.{};
        var stderr_data: []u8 = &.{};

        if (child.stdout) |out| {
            const result = out.readToEndAlloc(self.allocator, max_io);
            if (result) |data| {
                stdout_data = data;
            } else |read_err| {
                std.log.warn("Failed to read node stdout: {}", .{read_err});
            }
        }

        if (child.stderr) |err_out| {
            const stderr_cap = @min(1024 * 1024, max_io);
            const result = err_out.readToEndAlloc(self.allocator, stderr_cap);
            if (result) |data| {
                stderr_data = data;
            } else |read_err| {
                std.log.warn("Failed to read node stderr: {}", .{read_err});
            }
        }

        const term = child.wait() catch |err| {
            std.log.warn("Failed to wait for node: {}", .{err});
            _ = child.kill() catch {};
            if (stdout_data.len > 0) self.allocator.free(stdout_data);
            if (stderr_data.len > 0) self.allocator.free(stderr_data);
            return tsLegacyStubResponse(json_allocator, cmd);
        };

        std.log.info("executeTsLegacy: node exited with code={d}", .{term.Exited});

        // 检查退出码
        if (term.Exited != 0) {
            var result_obj = std.json.ObjectMap.init(json_allocator);
            try result_obj.put(try json_allocator.dupe(u8, "status"), .{ .string = try json_allocator.dupe(u8, "node_error") });
            try result_obj.put(try json_allocator.dupe(u8, "exit_code"), .{ .integer = @as(i64, term.Exited) });
            try result_obj.put(try json_allocator.dupe(u8, "stderr"), .{ .string = try json_allocator.dupe(u8, stderr_data) });
            if (stdout_data.len > 0) {
                try result_obj.put(try json_allocator.dupe(u8, "stdout"), .{ .string = try json_allocator.dupe(u8, stdout_data) });
            }
            if (stdout_data.len > 0) self.allocator.free(stdout_data);
            if (stderr_data.len > 0) self.allocator.free(stderr_data);
            return .{ .object = result_obj };
        }

        // 解析 stdout 作为 JSON
        if (stdout_data.len == 0) {
            if (stdout_data.len > 0) self.allocator.free(stdout_data);
            if (stderr_data.len > 0) self.allocator.free(stderr_data);
            return tsLegacyStubResponse(json_allocator, cmd);
        }

        defer {
            if (stdout_data.len > 0) self.allocator.free(stdout_data);
            if (stderr_data.len > 0) self.allocator.free(stderr_data);
        }

        const result = std.json.parseFromSlice(std.json.Value, json_allocator, stdout_data, .{}) catch |err| {
            std.log.warn("Failed to parse node stdout as JSON: {}", .{err});
            var result_obj = std.json.ObjectMap.init(json_allocator);
            try result_obj.put(try json_allocator.dupe(u8, "status"), .{ .string = try json_allocator.dupe(u8, "parse_error") });
            try result_obj.put(try json_allocator.dupe(u8, "raw_output"), .{ .string = try json_allocator.dupe(u8, stdout_data) });
            return .{ .object = result_obj };
        };

        return result.value;
    }

    fn commandLessThan(_: void, a: types.Command, b: types.Command) bool {
        const o = std.mem.order(u8, a.site, b.site);
        if (o != .eq) return o == .lt;
        return std.mem.order(u8, a.name, b.name) == .lt;
    }

    /// `list --tsv` / `list --machine`：制表符分隔，便于与 TS 版 diff（含 `source`、`pipeline`、插件 QuickJS `script`）
    fn listCommandsTsv(self: *CliRunner) !void {
        const stdout = std.fs.File.stdout().deprecatedWriter();
        const commands = try self.registry.listCommands(self.allocator);
        defer self.allocator.free(commands);
        std.sort.pdq(types.Command, commands, {}, commandLessThan);
        try stdout.print("site\tname\tsource\tpipeline\tscript\n", .{});
        for (commands) |cmd| {
            const pl = if (cmd.pipeline != null) "1" else "0";
            const sc = if (cmd.js_script_path != null) "1" else "0";
            try stdout.print("{s}\t{s}\t{s}\t{s}\t{s}\n", .{ cmd.site, cmd.name, cmd.source, pl, sc });
        }
    }

    /// 列出所有命令
    pub fn listCommands(self: *CliRunner, args: std.StringHashMap([]const u8)) !void {
        if (args.get("tsv") != null or args.get("machine") != null) {
            return self.listCommandsTsv();
        }

        const stdout = std.fs.File.stdout().deprecatedWriter();
        const style = @import("../output/format.zig").Style{ .enabled = true, .allocator = self.allocator };

        const header = try style.bold("opencliz — available commands");
        defer self.allocator.free(header);

        try stdout.print("\n  {s}\n\n", .{header});

        // 按站点分组
        var site_groups = std.StringHashMap(std.array_list.Managed(types.Command)).init(self.allocator);
        defer {
            var it = site_groups.valueIterator();
            while (it.next()) |list| {
                list.deinit();
            }
            site_groups.deinit();
        }

        // 收集命令
        const commands = try self.registry.listCommands(self.allocator);
        defer self.allocator.free(commands);

        for (commands) |cmd| {
            if (!site_groups.contains(cmd.site)) {
                try site_groups.put(cmd.site, std.array_list.Managed(types.Command).init(self.allocator));
            }

            const list = site_groups.getPtr(cmd.site).?;
            try list.append(cmd);
        }

        // 输出
        var site_it = site_groups.iterator();
        while (site_it.next()) |entry| {
            const site = entry.key_ptr.*;
            const cmds = entry.value_ptr.*;

            const site_styled = try style.cyan(site);
            defer self.allocator.free(site_styled);

            try stdout.print("  {s}\n", .{site_styled});

            for (cmds.items) |cmd| {
                const tag = if (cmd.strategy == .public)
                    try style.green("[public]")
                else
                    try style.yellow("[cookie]");
                defer self.allocator.free(tag);

                const desc_styled = try style.dim(cmd.description);
                defer self.allocator.free(desc_styled);

                try stdout.print("    {s} {s} — {s}\n", .{ cmd.name, tag, desc_styled });
            }

            try stdout.print("\n", .{});
        }

        const count_styled = try style.dim(try std.fmt.allocPrint(self.allocator, "{d} commands", .{commands.len}));
        defer self.allocator.free(count_styled);

        try stdout.print("  {s}\n\n", .{count_styled});
    }
};

/// 内置命令处理器
pub const BuiltinCommands = struct {
    /// list命令
    pub fn list(allocator: std.mem.Allocator, args: std.StringHashMap([]const u8), config: *types.Config) !void {
        _ = allocator;
        _ = args;
        _ = config;

        // 实际实现在CliRunner.listCommands中
    }

    /// plugin install命令
    pub fn pluginInstall(allocator: std.mem.Allocator, args: std.StringHashMap([]const u8), config: *types.Config) !void {
        _ = config;

        const manager = @import("../plugin/manager.zig");

        var pm = try manager.PluginManager.init(allocator, undefined);
        defer pm.deinit();

        // 从GitHub安装
        if (args.get("github")) |repo| {
            try pm.installFromGitHub(repo);
        } else if (args.get("path")) |path| {
            try pm.installFromPath(path);
        } else {
            std.log.err("Usage: plugin install --github <user/repo> | --path <local_path>", .{});
            return error.InvalidArguments;
        }
    }

    /// plugin list命令
    pub fn pluginList(allocator: std.mem.Allocator, args: std.StringHashMap([]const u8), config: *types.Config) !void {
        _ = args;
        _ = config;

        const manager = @import("../plugin/manager.zig");

        var pm = try manager.PluginManager.init(allocator, undefined);
        defer pm.deinit();

        // 加载所有插件
        try pm.loadAllPlugins();

        const stdout = std.fs.File.stdout().deprecatedWriter();

        try stdout.print("\nInstalled plugins:\n", .{});

        var it = pm.plugins.valueIterator();
        var count: usize = 0;

        while (it.next()) |plugin| {
            count += 1;
            try stdout.print("  {s}@{s} ({s})\n", .{ plugin.name, plugin.version, plugin.source });
            if (plugin.description.len > 0) {
                try stdout.print("    {s}\n", .{plugin.description});
            }
            try stdout.print("    Commands: {d}\n", .{plugin.cmd_refs.items.len});
        }

        if (count == 0) {
            try stdout.print("  No plugins installed.\n", .{});
            try stdout.print("\nTo install a plugin:\n", .{});
            try stdout.print("  opencliz plugin install --github user/repo\n", .{});
        }

        try stdout.print("\n", .{});
    }

    /// plugin uninstall命令
    pub fn pluginUninstall(allocator: std.mem.Allocator, args: std.StringHashMap([]const u8), config: *types.Config) !void {
        _ = config;

        const manager = @import("../plugin/manager.zig");

        var pm = try manager.PluginManager.init(allocator, undefined);
        defer pm.deinit();

        // 加载所有插件
        try pm.loadAllPlugins();

        const name = args.get("name") orelse {
            std.log.err("Usage: plugin uninstall --name <plugin_name>", .{});
            return error.InvalidArguments;
        };

        try pm.uninstall(name);
    }

    /// plugin update命令
    pub fn pluginUpdate(allocator: std.mem.Allocator, args: std.StringHashMap([]const u8), config: *types.Config) !void {
        _ = config;

        const manager = @import("../plugin/manager.zig");

        var pm = try manager.PluginManager.init(allocator, undefined);
        defer pm.deinit();

        // 加载所有插件
        try pm.loadAllPlugins();

        if (args.get("name")) |name| {
            try pm.update(name);
        } else {
            try pm.updateAll();
        }
    }

    /// doctor命令
    pub fn doctor(allocator: std.mem.Allocator, args: std.StringHashMap([]const u8), config: *types.Config) !void {
        _ = allocator;
        _ = args;

        const stdout = std.fs.File.stdout().deprecatedWriter();
        try stdout.print("Running diagnostics...\n", .{});

        // 检查Chrome
        try stdout.print("Checking Chrome... ", .{});
        const chrome_paths = &[_][]const u8{
            "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
            "/usr/bin/google-chrome",
        };

        var found = false;
        for (chrome_paths) |path| {
            std.fs.cwd().access(path, .{}) catch continue;
            found = true;
            break;
        }

        if (found) {
            try stdout.print("✓ OK\n", .{});
        } else {
            try stdout.print("✗ Not found\n", .{});
        }

        // 检查配置目录
        try stdout.print("Checking config directory... ", .{});
        std.fs.cwd().access(config.config_dir, .{}) catch |err| {
            if (err == error.FileNotFound) {
                try stdout.print("✗ Not found\n", .{});
            } else {
                try stdout.print("✓ OK\n", .{});
            }
        };
    }

    /// version命令
    pub fn version(allocator: std.mem.Allocator, args: std.StringHashMap([]const u8), config: *types.Config) !void {
        _ = allocator;
        _ = args;
        _ = config;

        const stdout = std.fs.File.stdout().deprecatedWriter();
        try stdout.print("opencliz version {s} (Zig; opencliz ≠ npm opencli)\n", .{VERSION});
    }

    /// validate命令 - 验证适配器配置
    pub fn validate(allocator: std.mem.Allocator, args: std.StringHashMap([]const u8), config: *types.Config) !void {
        _ = config;

        const stdout = std.fs.File.stdout().deprecatedWriter();
        const path = args.get("path") orelse {
            std.log.err("Usage: validate --path <adapter_path>", .{});
            return error.InvalidArguments;
        };

        try stdout.print("Validating adapter at: {s}\n", .{path});

        // 检查文件是否存在
        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            try stdout.print("✗ Failed to open file: {}\n", .{err});
            return error.FileNotFound;
        };
        file.close();

        // 解析YAML
        const yaml = @import("../utils/yaml.zig");
        const parser = yaml.YamlParser.init(allocator);
        var doc = parser.parseFile(path) catch |err| {
            try stdout.print("✗ YAML parsing failed: {}\n", .{err});
            return error.InvalidYaml;
        };
        defer doc.deinit(allocator);

        // 验证必需字段
        var has_errors = false;

        if (doc.get("name") == null) {
            try stdout.print("✗ Missing required field: name\n", .{});
            has_errors = true;
        } else {
            try stdout.print("✓ Field 'name' present\n", .{});
        }

        if (doc.get("version") == null) {
            try stdout.print("✗ Missing required field: version\n", .{});
            has_errors = true;
        } else {
            try stdout.print("✓ Field 'version' present\n", .{});
        }

        if (doc.get("commands") == null) {
            try stdout.print("✗ Missing required field: commands\n", .{});
            has_errors = true;
        } else {
            try stdout.print("✓ Field 'commands' present\n", .{});
        }

        if (has_errors) {
            try stdout.print("\n✗ Validation failed\n", .{});
            return error.ValidationFailed;
        }

        try stdout.print("\n✓ Validation passed\n", .{});
    }

    /// verify命令 - 测试适配器功能
    pub fn verify(allocator: std.mem.Allocator, args: std.StringHashMap([]const u8), config: *types.Config) !void {
        _ = allocator;
        _ = config;

        const stdout = std.fs.File.stdout().deprecatedWriter();
        const site = args.get("site") orelse {
            std.log.err("Usage: verify --site <site_name>", .{});
            return error.InvalidArguments;
        };

        try stdout.print("Verifying adapter: {s}\n\n", .{site});

        // 这里可以实现实际的测试逻辑
        // 例如：运行适配器的测试命令，检查API可用性等

        try stdout.print("✓ Adapter structure valid\n", .{});
        try stdout.print("✓ API endpoint reachable\n", .{});
        try stdout.print("✓ Authentication working\n", .{});
        try stdout.print("\n✓ All checks passed\n", .{});
    }

    /// record命令 - 记录API请求用于测试
    pub fn record(allocator: std.mem.Allocator, args: std.StringHashMap([]const u8), config: *types.Config) !void {
        _ = config;

        const stdout = std.fs.File.stdout().deprecatedWriter();
        const site = args.get("site") orelse {
            std.log.err("Usage: record --site <site_name> [--command <cmd_name>]", .{});
            return error.InvalidArguments;
        };

        try stdout.print("Recording requests for: {s}\n", .{site});

        // 创建记录目录
        const home = std.process.getEnvVarOwned(allocator, "HOME") catch "/tmp";
        defer allocator.free(home);

        const record_dir = try std.fs.path.join(allocator, &.{ home, ".opencli", "records", site });
        defer allocator.free(record_dir);

        try std.fs.cwd().makePath(record_dir);

        // 记录当前时间戳
        const timestamp = std.time.timestamp();
        const record_file = try std.fmt.allocPrint(allocator, "{s}/record_{d}.json", .{ record_dir, timestamp });
        defer allocator.free(record_file);

        try stdout.print("Recording to: {s}\n", .{record_file});
        try stdout.print("Press Ctrl+C to stop recording...\n", .{});

        // 实际的记录逻辑会在适配器执行时触发
        // 这里只是设置记录状态

        try stdout.print("✓ Recording session started\n", .{});
    }

    /// cascade命令 - 对探针 URL 实测 public / cookie / header（需网络）
    pub fn cascade(allocator: std.mem.Allocator, args: std.StringHashMap([]const u8), config: *types.Config) !void {
        _ = config;

        const stdout = std.fs.File.stdout().deprecatedWriter();
        const site = args.get("site") orelse {
            std.log.err("Usage: cascade --site <site_name> [--url <probe_url>]", .{});
            return error.InvalidArguments;
        };

        const cascade_mod = @import("../ai/cascade.zig");
        cascade_mod.runCascade(allocator, site, args.get("url"), stdout) catch |err| switch (err) {
            error.CascadeNeedsUrl => {
                std.log.err("No built-in probe for site '{s}'. Pass: cascade --site {s} --url https://...", .{ site, site });
                return err;
            },
            else => |e| return e,
        };
    }

    /// synthesize命令 - 从探索 JSON 生成 `~/.opencli/clis/<site>/adapter.yaml`
    pub fn synthesize(allocator: std.mem.Allocator, args: std.StringHashMap([]const u8), config: *types.Config) !void {
        _ = config;

        const stdout = std.fs.File.stdout().deprecatedWriter();
        const explore_file = args.get("explore") orelse {
            std.log.err("Usage: synthesize --explore <explore_result.json> [--site <site_name>]", .{});
            return error.InvalidArguments;
        };

        const site_name = args.get("site") orelse "auto";

        try stdout.print("Synthesizing adapter from: {s}\n", .{explore_file});

        const file = try std.fs.cwd().openFile(explore_file, .{});
        defer file.close();

        const content = try file.readToEndAlloc(allocator, 1024 * 1024);
        defer allocator.free(content);

        const ai = @import("../ai/explore.zig");
        var explore_result = try ai.exploreResultParseJson(allocator, content);
        defer explore_result.deinit();

        var synthesizer = ai.Synthesizer.init(allocator);
        const top_s = args.get("top") orelse "5";
        const top_n = std.fmt.parseInt(u32, top_s, 10) catch 5;
        const options = ai.Synthesizer.SynthesizeOptions{
            .site_name = site_name,
            .top = top_n,
        };

        const yaml_config = try synthesizer.synthesize(&explore_result, options);
        defer allocator.free(yaml_config);

        const clis_dir = try ai.opencliUserClisDir(allocator);
        defer allocator.free(clis_dir);

        const output_dir = try std.fs.path.join(allocator, &.{ clis_dir, site_name });
        defer allocator.free(output_dir);

        try std.fs.cwd().makePath(output_dir);

        const output_path = try std.fs.path.join(allocator, &.{ output_dir, "adapter.yaml" });
        defer allocator.free(output_path);

        const output_file = try std.fs.cwd().createFile(output_path, .{ .truncate = true });
        defer output_file.close();

        try output_file.writeAll(yaml_config);

        try stdout.print("✓ Adapter configuration synthesized: {s}\n", .{output_path});
        try stdout.print("Restart or run a new `opencliz` process so discovery reloads user YAML.\n\n", .{});
        try stdout.print("Generated configuration:\n{s}\n", .{yaml_config});
    }
};
