const std = @import("std");

/// CLI配置
pub const Config = struct {
    allocator: std.mem.Allocator,
    home_dir: []const u8,
    config_dir: []const u8,
    data_dir: []const u8,
    cache_dir: []const u8,
    verbose: bool = false,
    format: OutputFormat = .table,
    timeout_ms: u32 = 30000,
    browser: BrowserConfig = .{},

    pub const OutputFormat = enum {
        table,
        json,
        yaml,
        markdown,
        csv,
        raw,
    };

    pub const BrowserConfig = struct {
        enabled: bool = true,
        headless: bool = true,
        debugging_port: u16 = 9222,
        executable: ?[]const u8 = null,
        timeout_ms: u32 = 30000,
    };

    pub fn init(allocator: std.mem.Allocator) !Config {
        const home = try getHomeDir(allocator);

        const config_dir = try std.fs.path.join(allocator, &.{ home, ".opencli" });
        const data_dir = try std.fs.path.join(allocator, &.{ home, ".opencli", "data" });
        const cache_dir = try std.fs.path.join(allocator, &.{ home, ".opencli", "cache" });

        // 确保目录存在
        std.fs.cwd().makePath(config_dir) catch {};
        std.fs.cwd().makePath(data_dir) catch {};
        std.fs.cwd().makePath(cache_dir) catch {};

        return Config{
            .allocator = allocator,
            .home_dir = home,
            .config_dir = config_dir,
            .data_dir = data_dir,
            .cache_dir = cache_dir,
        };
    }

    pub fn deinit(self: *Config) void {
        self.allocator.free(self.home_dir);
        self.allocator.free(self.config_dir);
        self.allocator.free(self.data_dir);
        self.allocator.free(self.cache_dir);
    }

    fn getHomeDir(allocator: std.mem.Allocator) ![]const u8 {
        // 尝试从环境变量获取
        if (std.process.getEnvVarOwned(allocator, "HOME")) |home| {
            return home;
        } else |_| {}

        if (std.process.getEnvVarOwned(allocator, "USERPROFILE")) |home| {
            return home;
        } else |_| {}

        // 默认使用临时目录
        return allocator.dupe(u8, "/tmp");
    }
};

/// 认证策略
pub const AuthStrategy = enum {
    public,
    cookie,
    header,
    oauth,
    api_key,

    pub fn fromString(str: []const u8) AuthStrategy {
        if (std.mem.eql(u8, str, "public")) return .public;
        if (std.mem.eql(u8, str, "cookie")) return .cookie;
        if (std.mem.eql(u8, str, "header")) return .header;
        if (std.mem.eql(u8, str, "oauth")) return .oauth;
        if (std.mem.eql(u8, str, "api_key")) return .api_key;
        return .cookie;
    }

    pub fn label(self: AuthStrategy) []const u8 {
        return switch (self) {
            .public => "public",
            .cookie => "cookie",
            .header => "header",
            .oauth => "oauth",
            .api_key => "api_key",
        };
    }
};

/// 参数定义
pub const ArgDef = struct {
    name: []const u8,
    description: []const u8,
    required: bool = false,
    default: ?[]const u8 = null,
    arg_type: ArgType = .string,

    pub const ArgType = enum {
        string,
        integer,
        number,
        boolean,
        array,
        object,
    };
};

/// 列定义
pub const ColumnDef = struct {
    name: []const u8,
    key: []const u8,
    format: ?[]const u8 = null,
    width: ?u16 = null,
};

/// Pipeline定义
pub const PipelineDef = struct {
    steps: []const Step,

    pub const Step = struct {
        name: []const u8,
        step_type: StepType,
        config: std.StringHashMap([]const u8),

        pub const StepType = enum {
            fetch,
            browser,
            transform,
            download,
            tap,
            intercept,
            exec,
        };
    };
};

/// CLI命令定义
pub const Command = struct {
    site: []const u8,
    name: []const u8,
    description: []const u8,
    domain: []const u8,
    strategy: AuthStrategy = .cookie,
    browser: bool = false,
    args: []const ArgDef = &.{},
    columns: ?[]const ColumnDef = null,
    pipeline: ?PipelineDef = null,
    timeout_seconds: ?u32 = null,
    navigate_before: ?[]const u8 = null,
    source: []const u8 = "builtin",

    // 内部命令特有字段
    is_internal: bool = false,
    module_path: ?[]const u8 = null,
    handler: ?CommandHandler = null,
    /// `source=plugin` 时可选：插件目录下 JS 文件绝对路径，由 QuickJS 执行（见 `plugin/quickjs_runtime.zig`）
    js_script_path: ?[]const u8 = null,

    pub const CommandHandler = *const fn (
        allocator: std.mem.Allocator,
        args: std.StringHashMap([]const u8),
        config: *Config,
    ) anyerror!void;

    pub fn fullName(self: Command, allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator, "{s}/{s}", .{ self.site, self.name });
    }
};

/// Release heap allocations under `PipelineDef` (step names and string config map).
pub fn pipelineDefDeinit(allocator: std.mem.Allocator, p: PipelineDef) void {
    for (p.steps) |step| {
        allocator.free(step.name);
        var cfg = step.config;
        var it = cfg.iterator();
        while (it.next()) |e| {
            allocator.free(e.key_ptr.*);
            allocator.free(e.value_ptr.*);
        }
        cfg.deinit();
    }
    allocator.free(p.steps);
}

/// Frees `Command` fields loaded from YAML plugins or per-command YAML (`source` = plugin | yaml).
pub fn destroyHeapCommandIfNeeded(allocator: std.mem.Allocator, cmd: Command) void {
    const src = cmd.source;
    if (!std.mem.eql(u8, src, "plugin") and
        !std.mem.eql(u8, src, "yaml") and
        !std.mem.eql(u8, src, "manifest_yaml") and
        !std.mem.eql(u8, src, "ts_legacy")) return;

    allocator.free(cmd.site);
    allocator.free(cmd.name);
    allocator.free(cmd.description);
    allocator.free(cmd.domain);

    if (cmd.pipeline) |pl| {
        pipelineDefDeinit(allocator, pl);
    }

    for (cmd.args) |a| {
        allocator.free(a.name);
        allocator.free(a.description);
        if (a.default) |d| allocator.free(d);
    }
    if (cmd.args.len > 0) {
        allocator.free(cmd.args);
    }

    if (cmd.columns) |cols| {
        for (cols) |c| {
            allocator.free(c.name);
            allocator.free(c.key);
            if (c.format) |f| allocator.free(f);
        }
        allocator.free(cols);
    }

    if (cmd.module_path) |m| allocator.free(m);
    if (cmd.navigate_before) |n| allocator.free(n);
    if (cmd.js_script_path) |j| allocator.free(j);
}

/// 适配器定义
pub const Adapter = struct {
    name: []const u8,
    description: []const u8,
    site: []const u8,
    version: []const u8 = "1.0.0",
    adapter_type: AdapterType,
    commands: std.array_list.Managed(Command),

    pub const AdapterType = enum {
        yaml,
        typescript,
        zig,
        external,
    };

    pub fn init(allocator: std.mem.Allocator, name: []const u8, adapter_type: AdapterType) Adapter {
        return Adapter{
            .name = name,
            .description = "",
            .site = name,
            .adapter_type = adapter_type,
            .commands = std.array_list.Managed(Command).init(allocator),
        };
    }

    pub fn deinit(self: *Adapter) void {
        self.commands.deinit();
    }

    pub fn addCommand(self: *Adapter, cmd: Command) !void {
        try self.commands.append(cmd);
    }
};

/// 外部CLI定义
pub const ExternalCli = struct {
    name: []const u8,
    description: []const u8,
    binary: []const u8,
    install_cmd: ?[]const u8 = null,
    is_installed: bool = false,

    /// 将ExternalCli转换为Command
    pub fn toCommand(self: ExternalCli) Command {
        return Command{
            .site = "external",
            .name = self.name,
            .description = self.description,
            .domain = self.binary,
            .source = "external",
        };
    }
};

/// 注册表，存储所有命令
pub const Registry = struct {
    allocator: std.mem.Allocator,
    commands: std.StringHashMap(Command),
    adapters: std.StringHashMap(Adapter),
    external_clis: std.array_list.Managed(ExternalCli),

    pub fn init(allocator: std.mem.Allocator) Registry {
        return Registry{
            .allocator = allocator,
            .commands = std.StringHashMap(Command).init(allocator),
            .adapters = std.StringHashMap(Adapter).init(allocator),
            .external_clis = std.array_list.Managed(ExternalCli).init(allocator),
        };
    }

    pub fn deinit(self: *Registry) void {
        var keys_dup = std.array_list.Managed([]const u8).init(self.allocator);
        defer {
            for (keys_dup.items) |k| self.allocator.free(k);
            keys_dup.deinit();
        }
        var kit = self.commands.keyIterator();
        while (kit.next()) |key| {
            const kc = self.allocator.dupe(u8, key.*) catch continue;
            keys_dup.append(kc) catch {
                self.allocator.free(kc);
            };
        }
        for (keys_dup.items) |k| {
            if (self.commands.fetchRemove(k)) |kv| {
                destroyHeapCommandIfNeeded(self.allocator, kv.value);
                self.allocator.free(kv.key);
            }
        }
        self.commands.deinit();
        var adapter_it = self.adapters.valueIterator();
        while (adapter_it.next()) |adapter| {
            adapter.deinit();
        }
        self.adapters.deinit();
        self.external_clis.deinit();
    }

    pub fn registerCommand(self: *Registry, cmd: Command) !void {
        const full_name = try cmd.fullName(self.allocator);
        errdefer self.allocator.free(full_name);
        try self.commands.put(full_name, cmd);
    }

    pub fn getCommand(self: *Registry, site: []const u8, name: []const u8) ?Command {
        var buf: [256]u8 = undefined;
        const full_name = std.fmt.bufPrint(&buf, "{s}/{s}", .{ site, name }) catch return null;
        return self.commands.get(full_name);
    }

    pub fn listCommands(self: *Registry, allocator: std.mem.Allocator) ![]Command {
        var list = std.array_list.Managed(Command).init(allocator);
        var it = self.commands.valueIterator();
        while (it.next()) |cmd| {
            try list.append(cmd.*);
        }
        return list.toOwnedSlice();
    }

    pub fn unregisterCommand(self: *Registry, site: []const u8, name: []const u8) void {
        var buf: [256]u8 = undefined;
        const full_name = std.fmt.bufPrint(&buf, "{s}/{s}", .{ site, name }) catch return;
        if (self.commands.fetchRemove(full_name)) |kv| {
            destroyHeapCommandIfNeeded(self.allocator, kv.value);
            self.allocator.free(kv.key);
        }
    }

    /// 注册外部CLI（添加到列表并注册为命令）
    pub fn registerExternalCli(self: *Registry, cli: ExternalCli) !void {
        // 添加到外部CLI列表
        try self.external_clis.append(cli);
        // 转换为命令并注册
        const cmd = cli.toCommand();
        try self.registerCommand(cmd);
    }

    /// 获取外部CLI列表
    pub fn getExternalClis(self: *Registry) []const ExternalCli {
        return self.external_clis.items;
    }
};

/// HTTP响应
pub const HttpResponse = struct {
    status: u16,
    headers: std.StringHashMap([]const u8),
    body: []const u8,

    pub fn deinit(self: *HttpResponse, allocator: std.mem.Allocator) void {
        self.headers.deinit();
        allocator.free(self.body);
    }
};

/// CDP消息
pub const CDPMessage = struct {
    id: u32,
    method: []const u8,
    params: ?std.json.Value = null,
    session_id: ?[]const u8 = null,
};

/// 执行结果
pub const ExecutionResult = struct {
    success: bool,
    data: ?std.json.Value = null,
    error_message: ?[]const u8 = null,
    output: ?[]const u8 = null,
};
