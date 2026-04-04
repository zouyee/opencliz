const std = @import("std");
const types = @import("types.zig");
const errors = @import("errors.zig");
const yaml_module = @import("../utils/yaml.zig");

const OpenCliError = errors.OpenCliError;
const YamlParser = yaml_module.YamlParser;
const YamlValue = yaml_module.YamlValue;

/// 发现模块 - 发现和加载CLI适配器
pub const Discovery = struct {
    allocator: std.mem.Allocator,
    registry: *types.Registry,

    pub fn init(allocator: std.mem.Allocator, registry: *types.Registry) Discovery {
        return Discovery{
            .allocator = allocator,
            .registry = registry,
        };
    }

    /// 从多个目录发现适配器
    pub fn discoverFromDirs(self: *Discovery, dirs: []const []const u8) !void {
        for (dirs) |dir| {
            try self.discoverFromDir(dir);
        }

        // 发现插件
        try self.discoverPlugins();
    }

    /// 从单个目录发现适配器
    pub fn discoverFromDir(self: *Discovery, dir: []const u8) !void {
        // 首先尝试从manifest加载
        const manifest_path = try std.fs.path.join(self.allocator, &.{ dir, "..", "cli-manifest.json" });
        defer self.allocator.free(manifest_path);

        std.fs.cwd().access(manifest_path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                // 回退到文件系统扫描
                try self.scanDirectory(dir);
                return;
            }
            return err;
        };

        try self.loadFromManifest(manifest_path, dir);
    }

    /// 从manifest加载
    fn loadFromManifest(self: *Discovery, manifest_path: []const u8, clis_dir: []const u8) !void {
        const content = try std.fs.cwd().readFileAlloc(self.allocator, manifest_path, 10 * 1024 * 1024);
        defer self.allocator.free(content);

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, content, .{});
        defer parsed.deinit();

        const manifest = parsed.value;

        if (manifest != .array) return;

        for (manifest.array.items) |entry| {
            if (entry != .object) continue;

            const obj = entry.object;
            const entry_type = obj.get("type") orelse continue;

            if (std.mem.eql(u8, entry_type.string, "yaml")) {
                try self.loadYamlEntry(obj);
            } else if (std.mem.eql(u8, entry_type.string, "ts")) {
                try self.loadTsEntry(obj, clis_dir);
            }
        }
    }

    /// 扫描目录
    fn scanDirectory(self: *Discovery, dir: []const u8) !void {
        var d = std.fs.cwd().openDir(dir, .{ .iterate = true }) catch |err| {
            if (err == error.FileNotFound) return;
            return err;
        };
        defer d.close();

        var it = d.iterate();
        while (try it.next()) |entry| {
            if (entry.kind == .directory) {
                const site_dir = try std.fs.path.join(self.allocator, &.{ dir, entry.name });
                defer self.allocator.free(site_dir);

                try self.scanSiteDir(entry.name, site_dir);
            }
        }
    }

    /// 扫描站点目录
    fn scanSiteDir(self: *Discovery, site: []const u8, dir: []const u8) !void {
        var d = std.fs.cwd().openDir(dir, .{ .iterate = true }) catch return;
        defer d.close();

        var it = d.iterate();
        while (try it.next()) |entry| {
            if (entry.kind == .file) {
                // YAML文件
                if (std.mem.endsWith(u8, entry.name, ".yaml") or
                    std.mem.endsWith(u8, entry.name, ".yml"))
                {
                    const cmd_name = entry.name[0 .. entry.name.len - 5];
                    const file_path = try std.fs.path.join(self.allocator, &.{ dir, entry.name });
                    defer self.allocator.free(file_path);

                    try self.loadYamlFile(site, cmd_name, file_path);
                }
            }
        }
    }

    /// 加载YAML文件（单命令：`name.yaml` 根即命令体；多命令：根级 `commands:` 为 **map** 或 **array**）
    fn loadYamlFile(self: *Discovery, site: []const u8, name: []const u8, path: []const u8) !void {
        const parser = YamlParser.init(self.allocator);

        var yaml_value = parser.parseFile(path) catch |err| {
            std.log.warn("Failed to parse YAML file {s}: {}", .{ path, err });
            return;
        };
        defer yaml_value.deinit(self.allocator);

        var yaml_mut = yaml_value;
        const obj = yaml_mut.getObject() orelse {
            std.log.warn("YAML root is not an object for {s}/{s}", .{ site, name });
            return;
        };

        if (obj.get("commands")) |cv| {
            if (cv.getObject()) |cmap| {
                const site_str = if (obj.get("site")) |sv|
                    sv.getString() orelse site
                else
                    site;
                var it = cmap.iterator();
                while (it.next()) |ent| {
                    const val = ent.value_ptr.*;
                    const co = val.getObject() orelse continue;
                    const map_key = ent.key_ptr.*;
                    const named = if (co.get("name")) |nv|
                        nv.getString() orelse map_key
                    else
                        map_key;
                    const cmd = try self.commandFromYamlObject(site_str, named, co, obj);
                    try self.registry.registerCommand(cmd);
                    std.log.info("Loaded YAML command: {s}/{s} (from multi-command file)", .{ site_str, named });
                }
                return;
            }
            if (cv.getArray()) |carr| {
                const site_str = if (obj.get("site")) |sv|
                    sv.getString() orelse site
                else
                    site;
                for (carr) |item| {
                    const co = item.getObject() orelse continue;
                    const cn = co.get("name") orelse continue;
                    const cname = cn.getString() orelse continue;
                    const cmd = try self.commandFromYamlObject(site_str, cname, co, obj);
                    try self.registry.registerCommand(cmd);
                    std.log.info("Loaded YAML command: {s}/{s} (from multi-command file)", .{ site_str, cname });
                }
                return;
            }
        }

        const cmd = try self.yamlToCommand(site, name, yaml_mut);
        try self.registry.registerCommand(cmd);
        std.log.info("Loaded YAML command: {s}/{s}", .{ site, name });
    }

    /// 单文件单命令：`yaml_val` 根对象即命令体（无顶层 `commands:`）
    fn yamlToCommand(self: *Discovery, site: []const u8, name: []const u8, yaml_val: YamlValue) !types.Command {
        var yaml_mut = yaml_val;
        const obj = yaml_mut.getObject() orelse {
            std.log.warn("YAML root is not an object for {s}/{s}", .{ site, name });
            return types.Command{
                .site = try self.allocator.dupe(u8, site),
                .name = try self.allocator.dupe(u8, name),
                .description = try self.allocator.dupe(u8, ""),
                .domain = try self.allocator.dupe(u8, ""),
                .source = "yaml",
            };
        };
        return self.commandFromYamlObject(site, name, obj, null);
    }

    /// 从命令 object 构建 `Command`；`inherit_root` 为适配器根时继承 `domain`/`strategy`/`browser`/`description`（子项优先）
    fn commandFromYamlObject(
        self: *Discovery,
        site: []const u8,
        cmd_name: []const u8,
        cmd_obj: *const std.StringHashMap(YamlValue),
        inherit_root: ?*const std.StringHashMap(YamlValue),
    ) !types.Command {
        const desc_cmd = if (cmd_obj.get("description")) |d|
            d.getString() orelse ""
        else
            "";
        const desc_inh = if (inherit_root) |root| if (root.get("description")) |d|
            d.getString() orelse ""
        else
            ""
        else
            "";
        const desc_raw = if (desc_cmd.len > 0) desc_cmd else desc_inh;

        const domain_cmd = if (cmd_obj.get("domain")) |d|
            d.getString() orelse ""
        else
            "";
        const domain_inh = if (inherit_root) |root| if (root.get("domain")) |d|
            d.getString() orelse ""
        else
            ""
        else
            "";
        const domain_raw = if (domain_cmd.len > 0) domain_cmd else domain_inh;

        var strategy = types.AuthStrategy.public;
        if (cmd_obj.get("strategy")) |sv| {
            if (sv.getString()) |ss| strategy = types.AuthStrategy.fromString(ss);
        } else if (inherit_root) |root| {
            if (root.get("strategy")) |sv| {
                if (sv.getString()) |ss| strategy = types.AuthStrategy.fromString(ss);
            }
        }

        var browser_b = false;
        if (cmd_obj.get("browser")) |bv| {
            browser_b = bv.getBool() orelse false;
        } else if (inherit_root) |root| {
            if (root.get("browser")) |bv| {
                browser_b = bv.getBool() orelse false;
            }
        }

        const pipeline = try yaml_module.parsePipelineDefFromYaml(self.allocator, cmd_obj.get("pipeline"));
        const args = try yaml_module.parseRuntimeArgsFromYaml(self.allocator, cmd_obj.get("args"));
        const columns = try yaml_module.parseRuntimeColumnsFromYaml(self.allocator, cmd_obj.get("columns"));

        return types.Command{
            .site = try self.allocator.dupe(u8, site),
            .name = try self.allocator.dupe(u8, cmd_name),
            .description = try self.allocator.dupe(u8, desc_raw),
            .domain = try self.allocator.dupe(u8, domain_raw),
            .strategy = strategy,
            .browser = browser_b,
            .args = args,
            .columns = columns,
            .pipeline = pipeline,
            .source = "yaml",
        };
    }

    /// 从manifest加载YAML条目（堆拷贝字符串，避免 JSON 解析缓冲区释放后悬垂）
    fn loadYamlEntry(self: *Discovery, entry: std.json.ObjectMap) !void {
        const site = entry.get("site") orelse return;
        const name = entry.get("name") orelse return;
        const description = entry.get("description") orelse std.json.Value{ .string = "" };
        const domain = entry.get("domain") orelse std.json.Value{ .string = "" };

        const cmd = types.Command{
            .site = try self.allocator.dupe(u8, site.string),
            .name = try self.allocator.dupe(u8, name.string),
            .description = try self.allocator.dupe(u8, description.string),
            .domain = try self.allocator.dupe(u8, domain.string),
            .source = "manifest_yaml",
        };

        try self.registry.registerCommand(cmd);
    }

    /// 从 manifest 加载 `type: ts` 条目：注册为 `ts_legacy`；默认不执行（stub）。若 `OPENCLI_ENABLE_BUN_SUBPROCESS=1` 且 bun 在 PATH，则由 `runner` 用 **Bun** 子进程执行（见 `docs/PLUGIN_QUICKJS.md`）。
    fn loadTsEntry(self: *Discovery, entry: std.json.ObjectMap, clis_dir: []const u8) !void {
        const site = entry.get("site") orelse return;
        const name = entry.get("name") orelse return;
        const module_path = entry.get("modulePath") orelse return;

        const full_path = try std.fs.path.join(self.allocator, &.{ clis_dir, module_path.string });

        const cmd = types.Command{
            .site = try self.allocator.dupe(u8, site.string),
            .name = try self.allocator.dupe(u8, name.string),
            .description = try self.allocator.dupe(u8, "TypeScript legacy adapter (stub unless OPENCLI_ENABLE_BUN_SUBPROCESS=1 + bun)"),
            .domain = try self.allocator.dupe(u8, ""),
            .module_path = full_path,
            .source = "ts_legacy",
        };

        try self.registry.registerCommand(cmd);
    }

    /// 发现插件
    fn discoverPlugins(self: *Discovery) !void {
        const home = std.process.getEnvVarOwned(self.allocator, "HOME") catch return;
        defer self.allocator.free(home);
        const plugins_dir = try std.fs.path.join(self.allocator, &.{ home, ".opencli", "plugins" });
        defer self.allocator.free(plugins_dir);

        var d = std.fs.cwd().openDir(plugins_dir, .{ .iterate = true }) catch return;
        defer d.close();

        var it = d.iterate();
        while (try it.next()) |entry| {
            if (entry.kind == .file and (std.mem.endsWith(u8, entry.name, ".yaml") or std.mem.endsWith(u8, entry.name, ".yml") or std.mem.endsWith(u8, entry.name, ".json"))) {
                const path = try std.fs.path.join(self.allocator, &.{ plugins_dir, entry.name });
                defer self.allocator.free(path);

                try self.loadPlugin(path);
            }
        }
    }

    /// 加载插件
    fn loadPlugin(self: *Discovery, path: []const u8) !void {
        // 目前只支持 .yaml 或 .json 格式的插件配置
        if (std.mem.endsWith(u8, path, ".yaml") or std.mem.endsWith(u8, path, ".yml")) {
            try self.loadYamlPlugin(path);
        } else if (std.mem.endsWith(u8, path, ".json")) {
            try self.loadJsonPlugin(path);
        } else {
            std.log.warn("Unsupported plugin format: {s}", .{path});
        }
    }

    /// 从 YAML 加载插件
    fn loadYamlPlugin(self: *Discovery, path: []const u8) !void {
        const manager = @import("../plugin/manager.zig");

        var pm = try manager.PluginManager.init(self.allocator, self.registry);
        defer pm.deinit();

        // 获取插件目录（文件所在目录）
        const plugin_dir = std.fs.path.dirname(path) orelse return error.InvalidPath;

        try pm.loadPlugin(plugin_dir, plugin_dir);

        std.log.info("Loaded YAML plugin from: {s}", .{path});
    }

    /// 从 JSON 加载插件
    fn loadJsonPlugin(self: *Discovery, path: []const u8) !void {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 1024 * 1024); // 1MB max
        defer self.allocator.free(content);

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, content, .{});
        defer parsed.deinit();

        // 解析插件配置并注册命令
        if (parsed.value.object.get("name")) |name_val| {
            const plugin_name = name_val.string;

            if (parsed.value.object.get("commands")) |commands_val| {
                if (commands_val == .array) {
                    for (commands_val.array.items) |cmd_val| {
                        if (cmd_val != .object) continue;
                        const cmd_obj = cmd_val.object;
                        const cmd_name = (cmd_obj.get("name") orelse continue).string;
                        const cmd_desc = if (cmd_obj.get("description")) |d| d.string else "";

                        const cmd = types.Command{
                            .site = plugin_name,
                            .name = cmd_name,
                            .description = cmd_desc,
                            .domain = "",
                            .strategy = .public,
                            .browser = false,
                            .source = "plugin",
                        };

                        try self.registry.registerCommand(cmd);
                    }
                }
            }
        }

        std.log.info("Loaded JSON plugin from: {s}", .{path});
    }

    /// 从 external-clis.yaml 加载外部CLI配置
    pub fn loadExternalClis(self: *Discovery, path: []const u8) !void {
        const yaml = @import("../utils/yaml.zig");
        const parser = yaml.YamlParser.init(self.allocator);

        var yaml_value = parser.parseFile(path) catch |err| {
            std.log.warn("Failed to parse external-clis.yaml: {}", .{err});
            return;
        };
        defer yaml_value.deinit(self.allocator);

        // 解析外部CLI数组
        const arr = yaml_value.getArray() orelse {
            std.log.warn("external-clis.yaml root is not an array", .{});
            return;
        };

        for (arr) |item| {
            const obj = item.getObject() orelse continue;

            // Get name (required)
            const name_node = obj.get("name") orelse continue;
            const name_str = name_node.getString() orelse continue;
            const name_copy = try self.allocator.dupe(u8, name_str);
            errdefer self.allocator.free(name_copy);

            // Get binary (required)
            const binary_node = obj.get("binary") orelse continue;
            const binary_str = binary_node.getString() orelse continue;
            const binary_copy = try self.allocator.dupe(u8, binary_str);
            errdefer self.allocator.free(binary_copy);

            // Description is optional - default to empty string
            var desc_copy: []const u8 = try self.allocator.dupe(u8, "");
            errdefer self.allocator.free(desc_copy);
            if (obj.get("description")) |desc_node| {
                if (desc_node.getString()) |desc_str| {
                    self.allocator.free(desc_copy);
                    desc_copy = try self.allocator.dupe(u8, desc_str);
                }
            }

            // Install command is optional
            var install_cmd_copy: ?[]const u8 = null;
            if (obj.get("install")) |install_node| {
                if (install_node.getObject()) |install_map| {
                    if (install_map.get("mac")) |mac_node| {
                        if (mac_node.getString()) |mac_cmd| {
                            install_cmd_copy = try self.allocator.dupe(u8, mac_cmd);
                        }
                    }
                }
            }

            // 检查是否已安装
            const is_installed = self.checkBinaryExists(binary_str);

            const cli = types.ExternalCli{
                .name = name_copy,
                .description = desc_copy,
                .binary = binary_copy,
                .install_cmd = install_cmd_copy,
                .is_installed = is_installed,
            };

            // 传递所有权给 registry
            try self.registry.registerExternalCli(cli);
            std.log.info("Loaded external CLI: {s} (binary: {s}, installed: {s})", .{ name_str, binary_str, if (is_installed) "yes" else "no" });
        }
    }

    /// 检查二进制是否存在于PATH中
    fn checkBinaryExists(self: *Discovery, binary: []const u8) bool {
        const result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "which", binary },
        }) catch return false;
        defer {
            self.allocator.free(result.stdout);
            self.allocator.free(result.stderr);
        }
        return result.term.Exited == 0;
    }
};
