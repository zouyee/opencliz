const std = @import("std");
const types = @import("../core/types.zig");
const errors = @import("../core/errors.zig");
const yaml = @import("../utils/yaml.zig");

const OpenCliError = errors.OpenCliError;

/// 插件信息
pub const PluginCmdRef = struct {
    site: []const u8,
    name: []const u8,

    pub fn deinit(self: *PluginCmdRef, allocator: std.mem.Allocator) void {
        allocator.free(self.site);
        allocator.free(self.name);
    }
};

pub const PluginInfo = struct {
    name: []const u8,
    version: []const u8,
    description: []const u8,
    author: ?[]const u8,
    source: []const u8, // github:user/repo 或本地路径
    /// 已注册到 `Registry` 的命令（仅 site/name，堆分配；卸载时用于 unregister）
    cmd_refs: std.array_list.Managed(PluginCmdRef),
    installed_at: i64,
    updated_at: i64,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, version: []const u8, source: []const u8) PluginInfo {
        return PluginInfo{
            .name = name,
            .version = version,
            .description = "",
            .author = null,
            .source = source,
            .cmd_refs = std.array_list.Managed(PluginCmdRef).init(allocator),
            .installed_at = std.time.timestamp(),
            .updated_at = std.time.timestamp(),
        };
    }

    pub fn deinit(self: *PluginInfo, allocator: std.mem.Allocator) void {
        for (self.cmd_refs.items) |*r| r.deinit(allocator);
        self.cmd_refs.deinit();
        allocator.free(self.name);
        allocator.free(self.version);
        allocator.free(self.description);
        if (self.author) |author| allocator.free(author);
        allocator.free(self.source);
    }
};

/// 插件管理器
pub const PluginManager = struct {
    allocator: std.mem.Allocator,
    plugins_dir: []const u8,
    plugins: std.StringHashMap(PluginInfo),
    registry: *types.Registry,
    
    pub fn init(allocator: std.mem.Allocator, registry: *types.Registry) !PluginManager {
        const home = std.process.getEnvVarOwned(allocator, "HOME") catch "/tmp";
        defer allocator.free(home);
        
        const plugins_dir = try std.fs.path.join(allocator, &.{ home, ".opencli", "plugins" });
        
        // 确保目录存在
        std.fs.cwd().makePath(plugins_dir) catch {};
        
        return PluginManager{
            .allocator = allocator,
            .plugins_dir = plugins_dir,
            .plugins = std.StringHashMap(PluginInfo).init(allocator),
            .registry = registry,
        };
    }
    
    pub fn deinit(self: *PluginManager) void {
        var it = self.plugins.valueIterator();
        while (it.next()) |plugin| {
            plugin.deinit(self.allocator);
        }
        self.plugins.deinit();
        self.allocator.free(self.plugins_dir);
    }
    
    /// 从GitHub安装插件
    pub fn installFromGitHub(self: *PluginManager, repo: []const u8) !void {
        std.log.info("Installing plugin from GitHub: {s}", .{repo});
        
        // 解析 repo (格式: user/repo)
        if (std.mem.indexOf(u8, repo, "/")) |idx| {
            const user = repo[0..idx];
            const name = repo[idx + 1 ..];
            
            // 构建下载URL
            const url = try std.fmt.allocPrint(
                self.allocator,
                "https://github.com/{s}/{s}/archive/refs/heads/main.zip",
                .{ user, name }
            );
            defer self.allocator.free(url);
            
            // 下载插件
            const temp_file = "/tmp/opencli-plugin.zip";
            try self.downloadFile(url, temp_file);
            
            // 解压到插件目录
            const plugin_dir = try std.fs.path.join(self.allocator, &.{ self.plugins_dir, name });
            defer self.allocator.free(plugin_dir);
            
            try self.extractZip(temp_file, plugin_dir);
            
            // 加载插件
            try self.loadPlugin(plugin_dir, repo);
            
            std.log.info("Plugin installed successfully: {s}", .{name});
        } else {
            return error.InvalidRepoFormat;
        }
    }
    
    /// 从本地路径安装插件
    pub fn installFromPath(self: *PluginManager, path: []const u8) !void {
        std.log.info("Installing plugin from path: {s}", .{path});
        
        // 获取插件名称
        const name = std.fs.path.basename(path);
        
        // 复制到插件目录
        const dest_dir = try std.fs.path.join(self.allocator, &.{ self.plugins_dir, name });
        defer self.allocator.free(dest_dir);
        
        try self.copyDirectory(path, dest_dir);
        
        // 加载插件
        try self.loadPlugin(dest_dir, path);
        
        std.log.info("Plugin installed successfully: {s}", .{name});
    }
    
    /// 卸载插件
    pub fn uninstall(self: *PluginManager, name: []const u8) !void {
        std.log.info("Uninstalling plugin: {s}", .{name});
        
        // 从注册表移除命令
        if (self.plugins.fetchRemove(name)) |kv| {
            var plugin = kv.value;
            for (plugin.cmd_refs.items) |r| {
                self.registry.unregisterCommand(r.site, r.name);
            }
            plugin.deinit(self.allocator);
        }
        
        // 删除插件目录
        const plugin_dir = try std.fs.path.join(self.allocator, &.{ self.plugins_dir, name });
        defer self.allocator.free(plugin_dir);
        
        std.fs.cwd().deleteTree(plugin_dir) catch |e| {
            std.log.warn("Failed to delete plugin directory: {}", .{e});
        };
        
        std.log.info("Plugin uninstalled: {s}", .{name});
    }
    
    /// 更新插件
    pub fn update(self: *PluginManager, name: []const u8) !void {
        std.log.info("Updating plugin: {s}", .{name});
        
        if (self.plugins.get(name)) |plugin| {
            // 重新安装
            if (std.mem.startsWith(u8, plugin.source, "github:")) {
                const repo = plugin.source[7..]; // 移除 "github:" 前缀
                try self.uninstall(name);
                try self.installFromGitHub(repo);
            } else {
                try self.uninstall(name);
                try self.installFromPath(plugin.source);
            }
            
            std.log.info("Plugin updated: {s}", .{name});
        } else {
            return error.PluginNotFound;
        }
    }
    
    /// 更新所有插件
    pub fn updateAll(self: *PluginManager) !void {
        std.log.info("Updating all plugins...", .{});
        
        var it = self.plugins.keyIterator();
        while (it.next()) |name| {
            self.update(name.*) catch |e| {
                std.log.err("Failed to update plugin {s}: {}", .{ name.*, e });
            };
        }
    }
    
    /// 加载插件
    pub fn loadPlugin(self: *PluginManager, path: []const u8, source: []const u8) !void {
        // 读取插件配置
        const config_path = try std.fs.path.join(self.allocator, &.{ path, "plugin.yaml" });
        defer self.allocator.free(config_path);
        
        const parser = yaml.YamlParser.init(self.allocator);
        var config = parser.parseFile(config_path) catch {
            std.log.warn("Plugin config not found: {s}", .{config_path});
            return;
        };
        defer config.deinit(self.allocator);
        
        // 解析插件信息
        const name_obj = config.get("name") orelse return error.InvalidPluginConfig;
        const name = name_obj.getString() orelse return error.InvalidPluginConfig;
        
        const version_obj = config.get("version") orelse return error.InvalidPluginConfig;
        const version = version_obj.getString() orelse return error.InvalidPluginConfig;
        
        var plugin = PluginInfo.init(self.allocator, name, version, source);
        
        // 描述
        if (config.get("description")) |desc_obj| {
            if (desc_obj.getString()) |desc| {
                plugin.description = try self.allocator.dupe(u8, desc);
            }
        }
        
        // 作者
        if (config.get("author")) |author_obj| {
            if (author_obj.getString()) |author| {
                plugin.author = try self.allocator.dupe(u8, author);
            }
        }

        // 可选：插件根目录下 QuickJS 启动脚本（相对路径，如 init.js）
        if (config.get("js_init")) |jv| {
            js_init: {
                const rel = jv.getString() orelse break :js_init;
                const js_path = try std.fs.path.join(self.allocator, &.{ path, rel });
                defer self.allocator.free(js_path);
                const body = std.fs.cwd().readFileAlloc(self.allocator, js_path, 2 * 1024 * 1024) catch |err| {
                    std.log.warn("plugin js_init read {s}: {}", .{ js_path, err });
                    break :js_init;
                };
                defer self.allocator.free(body);
                const qjs = @import("quickjs_runtime.zig");
                const out = qjs.evalExpressionToString(self.allocator, body) catch |err| {
                    std.log.warn("plugin js_init eval {s}: {}", .{ js_path, err });
                    break :js_init;
                };
                defer self.allocator.free(out);
                std.log.info("Plugin {s} js_init ok (output len {d})", .{ name, out.len });
            }
        }

        // 加载命令
        if (config.get("commands")) |commands_obj| {
            if (commands_obj.getArray()) |commands_array| {
                for (commands_array) |cmd_obj| {
                    if (cmd_obj.getObject()) |cmd_map| {
                        const cmd = try self.parseCommand(cmd_map, name, path);
                        try self.registry.registerCommand(cmd);
                        errdefer self.registry.unregisterCommand(cmd.site, cmd.name);
                        try plugin.cmd_refs.append(.{
                            .site = try self.allocator.dupe(u8, cmd.site),
                            .name = try self.allocator.dupe(u8, cmd.name),
                        });
                    }
                }
            }
        }
        
        // 保存插件信息
        const name_copy = try self.allocator.dupe(u8, name);
        try self.plugins.put(name_copy, plugin);
    }
    
    /// 解析命令配置（堆分配字段；`source=plugin` 由 Registry 卸载时释放）
    fn parseCommand(self: *PluginManager, cmd_map: *const std.StringHashMap(yaml.YamlValue), plugin_name: []const u8, plugin_dir: []const u8) !types.Command {
        const name_obj = cmd_map.get("name") orelse return error.InvalidCommandConfig;
        const name_raw = name_obj.getString() orelse return error.InvalidCommandConfig;

        const desc_obj = cmd_map.get("description") orelse yaml.YamlValue{ .string = "" };
        const desc_raw = desc_obj.getString() orelse "";

        const domain_raw = if (cmd_map.get("domain")) |dv|
            dv.getString() orelse ""
        else
            "";
        const domain_owned = try self.allocator.dupe(u8, domain_raw);

        var strategy = types.AuthStrategy.public;
        if (cmd_map.get("strategy")) |sv| {
            if (sv.getString()) |ss| strategy = types.AuthStrategy.fromString(ss);
        }
        var browser_b = false;
        if (cmd_map.get("browser")) |bv| {
            browser_b = bv.getBool() orelse false;
        }

        const pipeline = try yaml.parsePipelineDefFromYaml(self.allocator, cmd_map.get("pipeline"));
        const args = try yaml.parseRuntimeArgsFromYaml(self.allocator, cmd_map.get("args"));
        const columns = try yaml.parseRuntimeColumnsFromYaml(self.allocator, cmd_map.get("columns"));

        var js_script_path: ?[]const u8 = null;
        if (cmd_map.get("script")) |sv| {
            if (sv.getString()) |rel| {
                js_script_path = try std.fs.path.join(self.allocator, &.{ plugin_dir, rel });
            }
        }

        return types.Command{
            .site = try self.allocator.dupe(u8, plugin_name),
            .name = try self.allocator.dupe(u8, name_raw),
            .description = try self.allocator.dupe(u8, desc_raw),
            .domain = domain_owned,
            .strategy = strategy,
            .browser = browser_b,
            .args = args,
            .columns = columns,
            .pipeline = pipeline,
            .js_script_path = js_script_path,
            .source = "plugin",
        };
    }
    
    /// 加载所有已安装的插件
    pub fn loadAllPlugins(self: *PluginManager) !void {
        var dir = std.fs.cwd().openDir(self.plugins_dir, .{ .iterate = true }) catch {
            return;
        };
        defer dir.close();
        
        var it = dir.iterate();
        while (try it.next()) |entry| {
            if (entry.kind == .directory) {
                const plugin_path = try std.fs.path.join(self.allocator, &.{ self.plugins_dir, entry.name });
                defer self.allocator.free(plugin_path);
                
                self.loadPlugin(plugin_path, plugin_path) catch |e| {
                    std.log.warn("Failed to load plugin {s}: {}", .{ entry.name, e });
                };
            }
        }
    }
    
    /// 列出所有插件
    pub fn listPlugins(self: *PluginManager) []const PluginInfo {
        var list = std.array_list.Managed(PluginInfo).init(self.allocator);
        var it = self.plugins.valueIterator();
        while (it.next()) |plugin| {
            list.append(plugin.*) catch continue;
        }
        return list.toOwnedSlice() catch &[]PluginInfo{};
    }
    
    /// 获取插件信息
    pub fn getPlugin(self: *PluginManager, name: []const u8) ?PluginInfo {
        return self.plugins.get(name);
    }
    
    /// 下载文件
    fn downloadFile(self: *PluginManager, url: []const u8, output_path: []const u8) !void {
        const http_client = @import("../http/client.zig");
        
        var client = try http_client.HttpClient.init(self.allocator);
        defer client.deinit();
        
        try client.setDefaultHeaders();
        try client.download(url, output_path);
        
        std.log.info("Downloaded from {s} to {s}", .{ url, output_path });
    }
    
    /// 解压zip文件
    fn extractZip(self: *PluginManager, zip_path: []const u8, output_dir: []const u8) !void {
        // 读取zip文件
        const zip_file = try std.fs.cwd().openFile(zip_path, .{});
        defer zip_file.close();

        const zip_data = try zip_file.readToEndAlloc(self.allocator, 100 * 1024 * 1024); // 100MB max
        defer self.allocator.free(zip_data);

        // 确保输出目录存在
        try std.fs.cwd().makePath(output_dir);

        // 使用tar命令解压 (简化实现)
        const result = try std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &.{ "unzip", "-o", zip_path, "-d", output_dir },
        });
        defer {
            self.allocator.free(result.stdout);
            self.allocator.free(result.stderr);
        }

        if (result.term.Exited != 0) {
            std.log.err("Failed to extract zip: {s}", .{result.stderr});
            return error.ZipExtractionFailed;
        }

        std.log.info("Extracted {s} to {s}", .{ zip_path, output_dir });
    }
    
    /// 复制目录
    fn copyDirectory(self: *PluginManager, src: []const u8, dest: []const u8) !void {
        // 打开源目录
        var src_dir = try std.fs.cwd().openDir(src, .{ .iterate = true });
        defer src_dir.close();

        // 创建目标目录
        try std.fs.cwd().makePath(dest);
        var dest_dir = try std.fs.cwd().openDir(dest, .{});
        defer dest_dir.close();

        // 遍历源目录中的所有条目
        var it = src_dir.iterate();
        while (try it.next()) |entry| {
            const src_path = try std.fs.path.join(self.allocator, &.{ src, entry.name });
            defer self.allocator.free(src_path);
            
            const dest_path = try std.fs.path.join(self.allocator, &.{ dest, entry.name });
            defer self.allocator.free(dest_path);

            switch (entry.kind) {
                .file => {
                    // 复制文件
                    try src_dir.copyFile(entry.name, dest_dir, entry.name, .{});
                },
                .directory => {
                    // 递归复制子目录
                    try self.copyDirectory(src_path, dest_path);
                },
                else => {},
            }
        }

        std.log.info("Copied directory from {s} to {s}", .{ src, dest });
    }
};