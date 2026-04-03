const std = @import("std");
const args_parse = @import("cli/args_parse.zig");
const types = @import("core/types.zig");
const errors = @import("core/errors.zig");
const discovery = @import("core/discovery.zig");
const runner = @import("cli/runner.zig");
const adapters = @import("adapters/builtins.zig");
const ai = @import("ai/explore.zig");
const logger = @import("utils/logger.zig");
const config_manager = @import("utils/config.zig");
const _ = @import("tests.zig");

const OpenCliError = errors.OpenCliError;
const VERSION = "2.2.0";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer {
        const leak_check = gpa.deinit();
        if (leak_check == .leak) {
            std.log.warn("Memory leak detected!", .{});
        }
    }
    const allocator = gpa.allocator();

    // 设置标准路径
    setupPath();

    // 加载配置
    var cfg_mgr = config_manager.ConfigManager.init(allocator);
    defer cfg_mgr.deinit();
    cfg_mgr.loadDefault() catch {};

    // 初始化日志
    const log_config = logger.LoggerConfig{
        .level = .info,
        .output = .stderr,
        .colored = true,
    };
    logger.initGlobalLogger(log_config);

    // 初始化hooks系统
    const hooks = @import("utils/hooks.zig");
    try hooks.initGlobalHooks(allocator);
    defer hooks.deinitGlobalHooks();

    var cli = try args_parse.parse(allocator);
    defer cli.deinit(allocator);

    if (cli.help) {
        try showHelp();
        return;
    }
    if (cli.version) {
        try showVersion();
        return;
    }
    if (cli.completions) |shell| {
        try generateCompletions(shell);
        return;
    }
    if (cli.explore) |url| {
        try exploreWebsite(allocator, url, &cli);
        return;
    }
    if (cli.generate) |url| {
        const site_name = cli.site orelse "auto";
        try generateAdapter(allocator, url, site_name);
        return;
    }

    // 初始化配置
    var config = try types.Config.init(allocator);
    defer config.deinit();

    if (cli.format) |fmt| {
        config.format = parseFormat(fmt);
    }

    config.verbose = cli.verbose;

    if (config.verbose) {
        logger.getGlobalLogger().setLevel(.debug);
    }

    const command = if (cli.positionals.len > 0) cli.positionals[0] else {
        try showHelp();
        return;
    };

    // 初始化注册表
    var registry = types.Registry.init(allocator);
    defer registry.deinit();

    // 先注册 Zig 内置适配器，再由 YAML 发现覆盖同名命令（对齐原项目「仓库 clis + 用户目录」行为）
    adapters.registerAllAdapters(allocator, &registry) catch |err| {
        std.log.err("Failed to register adapters: {}", .{err});
        return;
    };

    var disc = discovery.Discovery.init(allocator, &registry);

    const home = std.process.getEnvVarOwned(allocator, "HOME") catch "/tmp";
    defer allocator.free(home);

    const user_clis = try std.fs.path.join(allocator, &.{ home, ".opencli", "clis" });
    defer allocator.free(user_clis);

    const extra_clis = std.process.getEnvVarOwned(allocator, "OPENCLI_CLIS") catch null;
    if (extra_clis) |extra| {
        defer allocator.free(extra);
        disc.discoverFromDirs(&.{ user_clis, extra, "src/clis" }) catch |err| {
            if (config.verbose) std.log.warn("Adapter discovery: {}", .{err});
        };
    } else {
        disc.discoverFromDirs(&.{ user_clis, "src/clis" }) catch |err| {
            if (config.verbose) std.log.warn("Adapter discovery: {}", .{err});
        };
    }

    // 加载外部CLI配置
    const external_clis_path = try std.fs.path.join(allocator, &.{ home, ".opencli", "external-clis.yaml" });
    defer allocator.free(external_clis_path);
    disc.loadExternalClis(external_clis_path) catch |err| {
        if (config.verbose) std.log.warn("External CLIs loading: {}", .{err});
    };

    // 初始化运行器
    var cli_runner = runner.CliRunner.init(allocator, &config, &registry) catch |err| {
        std.log.err("Failed to initialize runner: {}", .{err});
        return;
    };
    defer cli_runner.deinit();

    // 注册内置命令
    try registerBuiltinCommands(&cli_runner);

    // Trigger on_startup hook
    if (hooks.getGlobalHooks()) |hooks_mgr| {
        const ctx = hooks.HookContext.init(.on_startup);
        hooks_mgr.trigger(ctx) catch |err| {
            std.log.warn("Startup hook error: {}", .{err});
        };
    }

    if (std.mem.eql(u8, command, "serve")) {
        try startDaemon(allocator, &registry);
        return;
    }

    // 解析并执行命令
    var cmd_index: usize = 1;
    const cmd_parts = try parseCommand(command, cli.positionals, &cmd_index);

    // 构建参数字典
    var args = std.StringHashMap([]const u8).init(allocator);
    defer args.deinit();

    // 收集位置参数
    var positional_buf: ?[]u8 = null;

    var i: usize = cmd_index;
    while (i < cli.positionals.len) : (i += 1) {
        const arg = cli.positionals[i];

        if (std.mem.startsWith(u8, arg, "--")) {
            const key = arg[2..];
            if (i + 1 < cli.positionals.len) {
                const next = cli.positionals[i + 1];
                if (!std.mem.startsWith(u8, next, "-")) {
                    try args.put(key, next);
                    i += 1;
                } else {
                    try args.put(key, "true");
                }
            } else {
                try args.put(key, "true");
            }
        } else if (std.mem.startsWith(u8, arg, "-")) {
            const key = arg[1..];
            if (i + 1 < cli.positionals.len) {
                const next = cli.positionals[i + 1];
                if (!std.mem.startsWith(u8, next, "-")) {
                    try args.put(key, next);
                    i += 1;
                } else {
                    try args.put(key, "true");
                }
            } else {
                try args.put(key, "true");
            }
        } else {
            // 位置参数 - 追加到缓冲区
            if (positional_buf == null) {
                positional_buf = try allocator.dupe(u8, arg);
            } else {
                const old = positional_buf.?;
                const new_len = old.len + 1 + arg.len;
                const new_buf = try allocator.alloc(u8, new_len);
                @memcpy(new_buf[0..old.len], old);
                new_buf[old.len] = ' ';
                @memcpy(new_buf[old.len + 1 ..], arg);
                allocator.free(old);
                positional_buf = new_buf;
            }
        }
    }

    // 将位置参数添加到args中
    if (positional_buf) |pos| {
        try args.put("_", pos);
    }

    // 执行命令
    executeCommand(
        &cli_runner,
        cmd_parts.site,
        cmd_parts.name,
        args,
        config.verbose,
    ) catch |err| {
        // 释放位置参数内存（如果有）
        if (positional_buf) |pos| {
            allocator.free(pos);
        }
        if (config.verbose) {
            std.log.err("Command failed: {}", .{err});
        }
        std.process.exit(1);
    };

    // 成功路径：释放位置参数内存（如果有）
    if (positional_buf) |pos| {
        allocator.free(pos);
    }
}

/// 探索网站（`-f json` 仅 stdout JSON；`--explore-out` 另写文件；二者可同时使用）
fn exploreWebsite(allocator: std.mem.Allocator, url: []const u8, cli: *const args_parse.ParsedArgs) !void {
    std.log.info("Exploring website: {s}", .{url});

    var explorer = try ai.Explorer.init(allocator);
    defer explorer.deinit();

    const options = ai.Explorer.ExploreOptions{
        .depth = 1,
        .wait_seconds = 3,
        .auto_fuzzing = false,
    };

    var result = try explorer.explore(url, options);
    defer result.deinit();

    const json_str = try ai.exploreResultToJsonString(allocator, &result);
    defer allocator.free(json_str);

    const stdout = std.fs.File.stdout().deprecatedWriter();

    if (cli.format) |fmt| {
        if (std.mem.eql(u8, fmt, "json")) {
            try stdout.print("{s}", .{json_str});
            if (!std.mem.endsWith(u8, json_str, "\n")) try stdout.writeAll("\n");
            if (cli.explore_out) |out_path| {
                var f = try std.fs.cwd().createFile(out_path, .{ .truncate = true });
                defer f.close();
                try f.writeAll(json_str);
                std.log.info("Also wrote explore JSON to {s}", .{out_path});
            }
            return;
        }
    }

    try stdout.print("\n=== Exploration Result ===\n", .{});
    try stdout.print("Title: {s}\n", .{result.title});
    try stdout.print("URL: {s}\n", .{result.url});
    try stdout.print("Recommended Strategy: {s}\n", .{result.recommended_strategy.label()});
    try stdout.print("\nFound {d} API endpoints:\n", .{result.api_endpoints.items.len});

    for (result.api_endpoints.items) |endpoint| {
        try stdout.print("  - {s} {s}\n", .{ endpoint.method, endpoint.url });
    }

    try stdout.print("\nFound {d} data stores:\n", .{result.data_stores.items.len});
    for (result.data_stores.items) |store| {
        try stdout.print("  - {s} ({s})\n", .{ store.name, store.type });
    }

    try stdout.print("\n(JSON for synthesize: use -f json and/or --explore-out <path>)\n", .{});

    if (cli.explore_out) |out_path| {
        var f = try std.fs.cwd().createFile(out_path, .{ .truncate = true });
        defer f.close();
        try f.writeAll(json_str);
        std.log.info("Wrote explore JSON to {s}", .{out_path});
    }
}

/// 生成适配器
fn generateAdapter(allocator: std.mem.Allocator, url: []const u8, site_name: []const u8) !void {
    std.log.info("Generating adapter for: {s}", .{url});

    var generator = try ai.Generator.init(allocator);
    defer generator.deinit();

    const options = ai.Generator.GenerateOptions{
        .site_name = site_name,
        .output_dir = "",
        .depth = 1,
        .wait_seconds = 3,
        .top = 3,
    };

    try generator.generate(url, options);

    std.log.info("Adapter generation complete!", .{});
}

/// 启动Daemon（`OPENCLI_DAEMON_PORT` / `OPENCLI_DAEMON_HOST` / `OPENCLI_DAEMON_AUTH_TOKEN`）
fn startDaemon(allocator: std.mem.Allocator, reg: *types.Registry) !void {
    const dmod = @import("daemon/daemon.zig");

    std.log.info("Starting OpenCLI daemon...", .{});

    var port: u16 = 8080;
    if (std.process.getEnvVarOwned(allocator, "OPENCLI_DAEMON_PORT")) |s| {
        defer allocator.free(s);
        port = std.fmt.parseInt(u16, s, 10) catch 8080;
    } else |_| {}

    var host_owned: ?[]u8 = null;
    defer if (host_owned) |h| allocator.free(h);
    var host: []const u8 = "127.0.0.1";
    if (std.process.getEnvVarOwned(allocator, "OPENCLI_DAEMON_HOST")) |h| {
        host_owned = h;
        host = h;
    } else |_| {}

    var auth_owned: ?[]u8 = null;
    defer if (auth_owned) |t| allocator.free(t);
    var auth_token: ?[]const u8 = null;
    if (std.process.getEnvVarOwned(allocator, "OPENCLI_DAEMON_AUTH_TOKEN")) |t| {
        auth_owned = t;
        auth_token = t;
    } else |_| {}

    var request_timeout_ms: u32 = 30_000;
    if (std.process.getEnvVarOwned(allocator, "OPENCLI_DAEMON_REQUEST_TIMEOUT_MS")) |s| {
        defer allocator.free(s);
        request_timeout_ms = std.fmt.parseInt(u32, s, 10) catch 30_000;
    } else |_| {}

    var execute_timeout_ms: u32 = 0;
    if (std.process.getEnvVarOwned(allocator, "OPENCLI_DAEMON_EXECUTE_TIMEOUT_MS")) |s| {
        defer allocator.free(s);
        execute_timeout_ms = std.fmt.parseInt(u32, s, 10) catch 0;
    } else |_| {}

    const config = dmod.DaemonConfig{
        .port = port,
        .host = host,
        .max_connections = 100,
        .request_timeout_ms = request_timeout_ms,
        .execute_timeout_ms = execute_timeout_ms,
        .auth_token = auth_token,
    };

    var d = dmod.Daemon.init(allocator, config, reg);
    defer d.deinit();

    std.log.info("Daemon listening on http://{s}:{d}", .{ host, port });
    if (auth_token != null) std.log.info("Daemon auth token is set (use Authorization: Bearer or X-OpenCLI-Token or ?token=)", .{});
    std.log.info("Press Ctrl+C to stop", .{});

    try d.start();
}

fn executeCommand(
    cli_runner: *runner.CliRunner,
    site: []const u8,
    name: []const u8,
    args: std.StringHashMap([]const u8),
    verbose: bool,
) !void {
    // 处理内置命令
    if (std.mem.eql(u8, site, "opencli")) {
        if (std.mem.eql(u8, name, "list")) {
            try cli_runner.listCommands(args);
            return;
        } else if (std.mem.eql(u8, name, "doctor")) {
            try runner.BuiltinCommands.doctor(cli_runner.allocator, args, cli_runner.config);
            return;
        } else if (std.mem.eql(u8, name, "version")) {
            try runner.BuiltinCommands.version(cli_runner.allocator, args, cli_runner.config);
            return;
        } else if (std.mem.eql(u8, name, "plugin/install")) {
            try runner.BuiltinCommands.pluginInstall(cli_runner.allocator, args, cli_runner.config);
            return;
        } else if (std.mem.eql(u8, name, "plugin/list")) {
            try runner.BuiltinCommands.pluginList(cli_runner.allocator, args, cli_runner.config);
            return;
        } else if (std.mem.eql(u8, name, "plugin/uninstall")) {
            try runner.BuiltinCommands.pluginUninstall(cli_runner.allocator, args, cli_runner.config);
            return;
        } else if (std.mem.eql(u8, name, "plugin/update")) {
            try runner.BuiltinCommands.pluginUpdate(cli_runner.allocator, args, cli_runner.config);
            return;
        } else if (std.mem.eql(u8, name, "validate")) {
            try runner.BuiltinCommands.validate(cli_runner.allocator, args, cli_runner.config);
            return;
        } else if (std.mem.eql(u8, name, "verify")) {
            try runner.BuiltinCommands.verify(cli_runner.allocator, args, cli_runner.config);
            return;
        } else if (std.mem.eql(u8, name, "record")) {
            try runner.BuiltinCommands.record(cli_runner.allocator, args, cli_runner.config);
            return;
        } else if (std.mem.eql(u8, name, "cascade")) {
            try runner.BuiltinCommands.cascade(cli_runner.allocator, args, cli_runner.config);
            return;
        } else if (std.mem.eql(u8, name, "synthesize")) {
            try runner.BuiltinCommands.synthesize(cli_runner.allocator, args, cli_runner.config);
            return;
        }
    }

    // 执行普通命令
    try cli_runner.run(site, name, args);

    if (verbose) {
        std.log.info("Command completed successfully", .{});
    }
}

fn setupPath() void {
    const is_windows = @import("builtin").os.tag == .windows;
    if (is_windows) return;
    // Zig 0.15 起 std.process 不再提供 setEnvVar；原逻辑为扩展 PATH，多数环境下系统 PATH 已足够。
    _ = std.posix.getenv("PATH");
}

fn showHelp() !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();
    try stdout.print(
        \\
        \\        opencli — Make any website your CLI. AI-powered.
        \\
        \\        Usage: opencli [OPTIONS] <COMMAND> [ARGS...]
        \\
        \\        Options:
        \\          -h, --help                    Display this help and exit
        \\          -v, --version                 Display version and exit
        \\          -f, --format <FMT>          Output format: table, json, yaml, md, csv
        \\          --verbose                     Enable verbose output
        \\          --completions <SHELL>       Generate completion script for shell
        \\          --explore <URL>             Explore a website for APIs
        \\          --explore-out <FILE>        Also write explore JSON (with human output or with -f json)
        \\          --generate <URL>            Explore + synthesize → ~/.opencli/clis/<site>/adapter.yaml + ~/.opencli/explore/<site>.json
        \\          --site <NAME>               Site name for --generate / default for synthesize
        \\
        \\        Commands:
        \\          list [--tsv|--machine]        List commands (TSV: site, name, source, pipeline, script)
        \\          doctor                        Diagnose and auto-start services
        \\          version                       Show version information
        \\          plugin                        Plugin management commands
        \\            plugin install <--github user/repo|--path local>
        \\            plugin list                 List installed plugins
        \\            plugin uninstall <name>    Uninstall a plugin
        \\            plugin update [<name>]      Update all or specific plugin
        \\          validate --path <file>        Validate adapter configuration
        \\          verify --site <name>          Verify adapter functionality
        \\          record --site <name>          Record API requests for testing
        \\          cascade --site <name> [--url]  Probe public→cookie→header (built-in URL or --url)
        \\          synthesize --explore <file> [--site] [--top N]  → ~/.opencli/clis/<site>/adapter.yaml
        \\          <site>/<command>              Run a site-specific command
        \\
        \\        Examples:
        \\          opencli list
        \\          opencli bilibili/hot --limit 5
        \\          opencli github/trending -f json
        \\          opencli twitter/timeline --user elonmusk
        \\          opencli plugin install --github user/my-plugin
        \\          opencli plugin list
        \\          opencli plugin update
        \\          opencli validate --path ./adapters/my-cli.yaml
        \\          opencli verify --site github
        \\          opencli record --site github --command trending
        \\          opencli cascade --site github
        \\          opencli cascade --site myapi --url https://api.example.com/v1/health
        \\          opencli --explore https://example.com --explore-out ./ex.json
        \\          opencli -f json --explore https://example.com > ex.json
        \\          opencli synthesize --explore ./ex.json --site myapi
        \\          opencli --generate https://api.example.com --site myapi
        \\
    , .{});
}

fn showVersion() !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();
    try stdout.print("opencli version {s} (Zig rewrite)\n", .{VERSION});
}

fn generateCompletions(shell: []const u8) !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();

    if (std.mem.eql(u8, shell, "bash")) {
        try stdout.writeAll(
            \\
            \\_opencli_completions() {
            \\    local cur prev opts
            \\    COMPREPLY=()
            \\    cur="${COMP_WORDS[COMP_CWORD]}"
            \\    prev="${COMP_WORDS[COMP_CWORD-1]}"
            \\
            \\    local main_commands="list doctor version serve plugin validate verify record cascade synthesize bilibili github twitter youtube hackernews reddit zhihu weibo producthunt juejin douban v2ex"
            \\    local plugin_commands="install list uninstall update"
            \\
            \\    if [[ ${prev} == "plugin" ]] ; then
            \\        COMPREPLY=( $(compgen -W "${plugin_commands}" -- ${cur}) )
            \\        return 0
            \\    fi
            \\
            \\    case "${prev}" in
            \\        validate)
            \\            COMPREPLY=( $(compgen -W "--path" -- ${cur}) )
            \\            return 0
            \\            ;;
            \\        verify|record|cascade)
            \\            COMPREPLY=( $(compgen -W "--site" -- ${cur}) )
            \\            return 0
            \\            ;;
            \\        synthesize)
            \\            COMPREPLY=( $(compgen -W "--explore --site" -- ${cur}) )
            \\            return 0
            \\            ;;
            \\    esac
            \\
            \\    if [[ ${cur} == -* ]] ; then
            \\        COMPREPLY=( $(compgen -W "-h -v -f --help --version --format --verbose --explore --generate --site --github --path --name" -- ${cur}) )
            \\        return 0
            \\    fi
            \\
            \\    COMPREPLY=( $(compgen -W "${main_commands}" -- ${cur}) )
            \\}
            \\complete -F _opencli_completions opencli
            \\
        );
    } else if (std.mem.eql(u8, shell, "zsh")) {
        try stdout.print("#compdef opencli\n\n# Add completions for opencli\n", .{});
    } else if (std.mem.eql(u8, shell, "fish")) {
        try stdout.writeAll(
            \\complete -c opencli -f
            \\complete -c opencli -n '__fish_use_subcommand' -a 'list doctor version serve plugin validate verify record cascade synthesize'
            \\complete -c opencli -n '__fish_seen_subcommand_from plugin' -a 'install list uninstall update'
            \\complete -c opencli -n '__fish_seen_subcommand_from plugin' -l github -d 'Install from GitHub (user/repo)'
            \\complete -c opencli -n '__fish_seen_subcommand_from plugin' -l path -d 'Install from local path'
            \\complete -c opencli -n '__fish_seen_subcommand_from plugin' -l name -d 'Plugin name for uninstall/update'
            \\complete -c opencli -n '__fish_seen_subcommand_from validate' -l path -d 'Adapter YAML path'
            \\complete -c opencli -n '__fish_seen_subcommand_from verify' -l site -d 'Site name to verify'
            \\complete -c opencli -n '__fish_seen_subcommand_from record' -l site -d 'Site name to record'
            \\complete -c opencli -n '__fish_seen_subcommand_from cascade' -l site -d 'Site name to test'
            \\complete -c opencli -n '__fish_seen_subcommand_from synthesize' -l explore -d 'Explore result JSON file'
            \\complete -c opencli -n '__fish_seen_subcommand_from synthesize' -l site -d 'Site name for adapter'
            \\complete -c opencli -n '__fish_use_subcommand' -a 'bilibili' -d 'Bilibili video platform'
            \\complete -c opencli -n '__fish_seen_subcommand_from bilibili' -a 'hot search user'
            \\complete -c opencli -n '__fish_use_subcommand' -a 'github' -d 'GitHub code repository'
            \\complete -c opencli -n '__fish_seen_subcommand_from github' -a 'trending repo'
            \\complete -c opencli -n '__fish_use_subcommand' -a 'zhihu' -d 'Zhihu Q&A platform'
            \\complete -c opencli -n '__fish_seen_subcommand_from zhihu' -a 'hot search question user'
            \\complete -c opencli -n '__fish_use_subcommand' -a 'v2ex' -d 'V2EX'
            \\complete -c opencli -n '__fish_seen_subcommand_from v2ex' -a 'hot'
            \\complete -c opencli -l help -s h -d 'Display help'
            \\complete -c opencli -l version -s v -d 'Display version'
            \\complete -c opencli -l format -s f -d 'Output format' -xa 'table json yaml csv'
            \\complete -c opencli -l verbose -d 'Enable verbose output'
            \\complete -c opencli -l explore -d 'Explore website'
            \\complete -c opencli -l generate -d 'Generate adapter'
            \\complete -c opencli -l site -d 'Site name'
            \\
        );
    } else {
        try stdout.print("Unsupported shell: {s}\nSupported shells: bash, zsh, fish\n", .{shell});
    }
}

fn parseFormat(fmt: []const u8) types.Config.OutputFormat {
    if (std.mem.eql(u8, fmt, "table")) return .table;
    if (std.mem.eql(u8, fmt, "json")) return .json;
    if (std.mem.eql(u8, fmt, "yaml")) return .yaml;
    if (std.mem.eql(u8, fmt, "md")) return .markdown;
    if (std.mem.eql(u8, fmt, "markdown")) return .markdown;
    if (std.mem.eql(u8, fmt, "csv")) return .csv;
    if (std.mem.eql(u8, fmt, "raw")) return .raw;
    return .table;
}

const CommandParts = struct {
    site: []const u8,
    name: []const u8,
};

fn parseCommand(command: []const u8, positionals: []const []const u8, index: *usize) !CommandParts {
    const builtin_commands = &[_][]const u8{
        "list", "doctor", "version", "plugin", "validate", "verify", "record", "cascade", "synthesize",
    };

    for (builtin_commands) |cmd| {
        if (std.mem.eql(u8, command, cmd)) {
            // Check if this is the "plugin" command with a subcommand
            if (std.mem.eql(u8, command, "plugin")) {
                if (index.* < positionals.len) {
                    const subcmd = positionals[index.*];
                    index.* += 1;
                    const full_name = try std.fmt.allocPrint(std.heap.page_allocator, "plugin/{s}", .{subcmd});
                    return CommandParts{
                        .site = "opencli",
                        .name = full_name,
                    };
                }
                // No subcommand provided, default to "list"
                return CommandParts{
                    .site = "opencli",
                    .name = "plugin/list",
                };
            }

            return CommandParts{
                .site = "opencli",
                .name = command,
            };
        }
    }

    // 解析 site/name 格式
    if (std.mem.indexOf(u8, command, "/")) |idx| {
        return CommandParts{
            .site = command[0..idx],
            .name = command[idx + 1 ..],
        };
    }

    return CommandParts{
        .site = "opencli",
        .name = command,
    };
}

fn registerBuiltinCommands(cli_runner: *runner.CliRunner) !void {
    const list_cmd = types.Command{
        .site = "opencli",
        .name = "list",
        .description = "List all available commands",
        .domain = "",
        .handler = runner.BuiltinCommands.list,
        .source = "builtin",
    };
    try cli_runner.registerCommand(list_cmd);

    const doctor_cmd = types.Command{
        .site = "opencli",
        .name = "doctor",
        .description = "Diagnose and auto-start services",
        .domain = "",
        .handler = runner.BuiltinCommands.doctor,
        .source = "builtin",
    };
    try cli_runner.registerCommand(doctor_cmd);

    const version_cmd = types.Command{
        .site = "opencli",
        .name = "version",
        .description = "Show version information",
        .domain = "",
        .handler = runner.BuiltinCommands.version,
        .source = "builtin",
    };
    try cli_runner.registerCommand(version_cmd);

    // Plugin commands
    const plugin_install_cmd = types.Command{
        .site = "opencli",
        .name = "plugin/install",
        .description = "Install a plugin from GitHub or local path",
        .domain = "",
        .handler = runner.BuiltinCommands.pluginInstall,
        .source = "builtin",
    };
    try cli_runner.registerCommand(plugin_install_cmd);

    const plugin_list_cmd = types.Command{
        .site = "opencli",
        .name = "plugin/list",
        .description = "List all installed plugins",
        .domain = "",
        .handler = runner.BuiltinCommands.pluginList,
        .source = "builtin",
    };
    try cli_runner.registerCommand(plugin_list_cmd);

    const plugin_uninstall_cmd = types.Command{
        .site = "opencli",
        .name = "plugin/uninstall",
        .description = "Uninstall a plugin",
        .domain = "",
        .handler = runner.BuiltinCommands.pluginUninstall,
        .source = "builtin",
    };
    try cli_runner.registerCommand(plugin_uninstall_cmd);

    const plugin_update_cmd = types.Command{
        .site = "opencli",
        .name = "plugin/update",
        .description = "Update installed plugins",
        .domain = "",
        .handler = runner.BuiltinCommands.pluginUpdate,
        .source = "builtin",
    };
    try cli_runner.registerCommand(plugin_update_cmd);

    // Validation and verification commands
    const validate_cmd = types.Command{
        .site = "opencli",
        .name = "validate",
        .description = "Validate adapter configuration",
        .domain = "",
        .handler = runner.BuiltinCommands.validate,
        .source = "builtin",
    };
    try cli_runner.registerCommand(validate_cmd);

    const verify_cmd = types.Command{
        .site = "opencli",
        .name = "verify",
        .description = "Verify adapter functionality",
        .domain = "",
        .handler = runner.BuiltinCommands.verify,
        .source = "builtin",
    };
    try cli_runner.registerCommand(verify_cmd);

    const record_cmd = types.Command{
        .site = "opencli",
        .name = "record",
        .description = "Record API requests for testing",
        .domain = "",
        .handler = runner.BuiltinCommands.record,
        .source = "builtin",
    };
    try cli_runner.registerCommand(record_cmd);

    const cascade_cmd = types.Command{
        .site = "opencli",
        .name = "cascade",
        .description = "Test authentication strategies",
        .domain = "",
        .handler = runner.BuiltinCommands.cascade,
        .source = "builtin",
    };
    try cli_runner.registerCommand(cascade_cmd);

    const synthesize_cmd = types.Command{
        .site = "opencli",
        .name = "synthesize",
        .description = "Generate adapter from explore results",
        .domain = "",
        .handler = runner.BuiltinCommands.synthesize,
        .source = "builtin",
    };
    try cli_runner.registerCommand(synthesize_cmd);
}

test {
    _ = @import("adapters/article_pipeline.zig");
    _ = @import("utils/cache.zig");
    _ = @import("utils/yaml.zig");
}
