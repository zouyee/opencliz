const std = @import("std");
const yaml = @import("yaml.zig");

/// 全局配置
pub const GlobalConfig = struct {
    allocator: std.mem.Allocator,
    
    // 通用设置
    default_format: []const u8 = "table",
    default_timeout_ms: u32 = 30000,
    verbose: bool = false,
    
    // 浏览器设置
    browser: BrowserConfig = .{},
    
    // 缓存设置
    cache: CacheConfig = .{},
    
    // 日志设置
    log: LogConfig = .{},
    
    // HTTP设置
    http: HttpConfig,
    
    // 适配器设置
    adapters: std.StringHashMap(AdapterConfig),
    
    pub const BrowserConfig = struct {
        enabled: bool = true,
        headless: bool = true,
        debugging_port: u16 = 9222,
        executable: ?[]const u8 = null,
        timeout_ms: u32 = 30000,
        window_width: u32 = 1920,
        window_height: u32 = 1080,
    };
    
    pub const CacheConfig = struct {
        enabled: bool = true,
        ttl_seconds: u32 = 300,
        max_size: usize = 100,
        directory: ?[]const u8 = null,
    };
    
    pub const LogConfig = struct {
        level: []const u8 = "info",
        output: []const u8 = "stderr",
        file: ?[]const u8 = null,
        colored: bool = true,
    };
    
    pub const HttpConfig = struct {
        timeout_ms: u32 = 30000,
        retry_count: u32 = 3,
        retry_delay_ms: u32 = 1000,
        user_agent: []const u8 = "OpenCLI/2.0.0",
        default_headers: std.StringHashMap([]const u8),
    };
    
    pub const AdapterConfig = struct {
        enabled: bool = true,
        timeout_ms: ?u32 = null,
        custom_headers: ?std.StringHashMap([]const u8) = null,
        custom_options: std.StringHashMap([]const u8),
    };
    
    pub fn init(allocator: std.mem.Allocator) GlobalConfig {
        return GlobalConfig{
            .allocator = allocator,
            .adapters = std.StringHashMap(AdapterConfig).init(allocator),
            .http = .{
                .timeout_ms = 30000,
                .retry_count = 3,
                .retry_delay_ms = 1000,
                .user_agent = "OpenCLI/2.0.0",
                .default_headers = std.StringHashMap([]const u8).init(allocator),
            },
        };
    }
    
    pub fn deinit(self: *GlobalConfig) void {
        if (self.browser.executable) |exe| {
            self.allocator.free(exe);
        }
        
        if (self.cache.directory) |dir| {
            self.allocator.free(dir);
        }
        
        if (self.log.file) |file| {
            self.allocator.free(file);
        }

        self.http.default_headers.deinit();
        
        var it = self.adapters.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.custom_options.deinit();
            if (entry.value_ptr.custom_headers) |*headers| {
                headers.deinit();
            }
        }
        self.adapters.deinit();
    }
    
    /// 从YAML加载配置
    pub fn loadFromFile(self: *GlobalConfig, path: []const u8) !void {
        const parser = yaml.YamlParser.init(self.allocator);
        
        var yaml_value = try parser.parseFile(path);
        defer yaml_value.deinit(self.allocator);
        
        if (yaml_value.getObject()) |obj| {
            // 加载通用设置
            if (obj.get("default_format")) |v| {
                if (v.getString()) |s| {
                    self.default_format = try self.allocator.dupe(u8, s);
                }
            }
            
            if (obj.get("default_timeout_ms")) |v| {
                if (v.getInt()) |n| {
                    self.default_timeout_ms = @intCast(n);
                }
            }
            
            if (obj.get("verbose")) |v| {
                if (v.getBool()) |b| {
                    self.verbose = b;
                }
            }
            
            // 加载浏览器设置
            if (obj.get("browser")) |browser_val| {
                var browser_obj = browser_val;
                if (browser_obj.getObject()) |browser| {
                    if (browser.get("enabled")) |v| {
                        if (v.getBool()) |b| self.browser.enabled = b;
                    }
                    if (browser.get("headless")) |v| {
                        if (v.getBool()) |b| self.browser.headless = b;
                    }
                    if (browser.get("debugging_port")) |v| {
                        if (v.getInt()) |n| self.browser.debugging_port = @intCast(n);
                    }
                    if (browser.get("executable")) |v| {
                        if (v.getString()) |s| {
                            self.browser.executable = try self.allocator.dupe(u8, s);
                        }
                    }
                }
            }
            
            // 加载缓存设置
            if (obj.get("cache")) |cache_val| {
                var cache_obj = cache_val;
                if (cache_obj.getObject()) |cache| {
                    if (cache.get("enabled")) |v| {
                        if (v.getBool()) |b| self.cache.enabled = b;
                    }
                    if (cache.get("ttl_seconds")) |v| {
                        if (v.getInt()) |n| self.cache.ttl_seconds = @intCast(n);
                    }
                    if (cache.get("max_size")) |v| {
                        if (v.getInt()) |n| self.cache.max_size = @intCast(n);
                    }
                }
            }
            
            // 加载日志设置
            if (obj.get("log")) |log_val| {
                var log_obj = log_val;
                if (log_obj.getObject()) |log| {
                    if (log.get("level")) |v| {
                        if (v.getString()) |s| {
                            self.allocator.free(self.log.level);
                            self.log.level = try self.allocator.dupe(u8, s);
                        }
                    }
                    if (log.get("output")) |v| {
                        if (v.getString()) |s| {
                            self.allocator.free(self.log.output);
                            self.log.output = try self.allocator.dupe(u8, s);
                        }
                    }
                    if (log.get("colored")) |v| {
                        if (v.getBool()) |b| self.log.colored = b;
                    }
                }
            }
            
            // 加载适配器设置
            if (obj.get("adapters")) |adapters_val| {
                var adapters_obj = adapters_val;
                if (adapters_obj.getObject()) |adapters| {
                    var it = adapters.iterator();
                    while (it.next()) |entry| {
                        const adapter_name = entry.key_ptr.*;
                        
                        if (entry.value_ptr.getObject()) |adapter_config| {
                            var config = AdapterConfig{
                                .custom_options = std.StringHashMap([]const u8).init(self.allocator),
                            };
                            
                            if (adapter_config.get("enabled")) |v| {
                                if (v.getBool()) |b| config.enabled = b;
                            }
                            
                            if (adapter_config.get("timeout_ms")) |v| {
                                if (v.getInt()) |n| config.timeout_ms = @intCast(n);
                            }
                            
                            const name_copy = try self.allocator.dupe(u8, adapter_name);
                            try self.adapters.put(name_copy, config);
                        }
                    }
                }
            }
        }
    }
    
    /// 保存配置到YAML文件
    pub fn saveToFile(self: *GlobalConfig, path: []const u8) !void {
        var output = std.array_list.Managed(u8).init(self.allocator);
        defer output.deinit();
        
        const writer = output.writer();
        
        // 写入配置头
        try writer.print("# OpenCLI Configuration\n", .{});
        try writer.print("# Auto-generated\n\n", .{});
        
        // 通用设置
        try writer.print("default_format: {s}\n", .{self.default_format});
        try writer.print("default_timeout_ms: {d}\n", .{self.default_timeout_ms});
        try writer.print("verbose: {}\n\n", .{self.verbose});
        
        // 浏览器设置
        try writer.print("browser:\n", .{});
        try writer.print("  enabled: {}\n", .{self.browser.enabled});
        try writer.print("  headless: {}\n", .{self.browser.headless});
        try writer.print("  debugging_port: {d}\n", .{self.browser.debugging_port});
        if (self.browser.executable) |exe| {
            try writer.print("  executable: \"{s}\"\n", .{exe});
        }
        try writer.print("\n", .{});
        
        // 缓存设置
        try writer.print("cache:\n", .{});
        try writer.print("  enabled: {}\n", .{self.cache.enabled});
        try writer.print("  ttl_seconds: {d}\n", .{self.cache.ttl_seconds});
        try writer.print("  max_size: {d}\n\n", .{self.cache.max_size});
        
        // 日志设置
        try writer.print("log:\n", .{});
        try writer.print("  level: {s}\n", .{self.log.level});
        try writer.print("  output: {s}\n", .{self.log.output});
        try writer.print("  colored: {}\n\n", .{self.log.colored});
        
        // 适配器设置
        if (self.adapters.count() > 0) {
            try writer.print("adapters:\n", .{});
            var it = self.adapters.iterator();
            while (it.next()) |entry| {
                try writer.print("  {s}:\n", .{entry.key_ptr.*});
                try writer.print("    enabled: {}\n", .{entry.value_ptr.enabled});
                if (entry.value_ptr.timeout_ms) |timeout| {
                    try writer.print("    timeout_ms: {d}\n", .{timeout});
                }
            }
        }
        
        // 写入文件
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        
        try file.writeAll(output.items);
    }
    
    /// 获取适配器配置
    pub fn getAdapterConfig(self: *GlobalConfig, name: []const u8) ?AdapterConfig {
        return self.adapters.get(name);
    }
    
    /// 设置适配器配置
    pub fn setAdapterConfig(self: *GlobalConfig, name: []const u8, config: AdapterConfig) !void {
        const name_copy = try self.allocator.dupe(u8, name);
        try self.adapters.put(name_copy, config);
    }
};

/// 配置管理器
pub const ConfigManager = struct {
    allocator: std.mem.Allocator,
    config: GlobalConfig,
    config_path: ?[]const u8 = null,
    
    pub fn init(allocator: std.mem.Allocator) ConfigManager {
        return ConfigManager{
            .allocator = allocator,
            .config = GlobalConfig.init(allocator),
        };
    }
    
    pub fn deinit(self: *ConfigManager) void {
        self.config.deinit();
        if (self.config_path) |path| {
            self.allocator.free(path);
        }
    }
    
    /// 加载默认配置
    pub fn loadDefault(self: *ConfigManager) !void {
        // 尝试从多个位置加载配置
        const paths = &[_][]const u8{
            "./.openclirc.yaml",
            "~/.opencli/config.yaml",
            "/etc/opencli/config.yaml",
        };
        
        for (paths) |path| {
            if (std.mem.startsWith(u8, path, "~/")) {
                const home = std.process.getEnvVarOwned(self.allocator, "HOME") catch continue;
                defer self.allocator.free(home);
                
                const expanded = try std.fs.path.join(self.allocator, &.{ home, path[2..] });
                defer self.allocator.free(expanded);
                
                std.fs.cwd().access(expanded, .{}) catch continue;
                try self.loadFromFile(expanded);
                return;
            } else {
                std.fs.cwd().access(path, .{}) catch continue;
                try self.loadFromFile(path);
                return;
            }
        }
    }
    
    /// 从文件加载配置
    pub fn loadFromFile(self: *ConfigManager, path: []const u8) !void {
        try self.config.loadFromFile(path);
        
        if (self.config_path) |old_path| {
            self.allocator.free(old_path);
        }
        self.config_path = try self.allocator.dupe(u8, path);
    }
    
    /// 保存配置
    pub fn save(self: *ConfigManager) !void {
        if (self.config_path) |path| {
            try self.config.saveToFile(path);
        } else {
            // 保存到默认位置
            const home = try std.process.getEnvVarOwned(self.allocator, "HOME");
            defer self.allocator.free(home);
            
            const config_dir = try std.fs.path.join(self.allocator, &.{ home, ".opencli" });
            defer self.allocator.free(config_dir);
            
            try std.fs.cwd().makePath(config_dir);
            
            const config_path = try std.fs.path.join(self.allocator, &.{ config_dir, "config.yaml" });
            defer self.allocator.free(config_path);
            
            try self.config.saveToFile(config_path);
            self.config_path = try self.allocator.dupe(u8, config_path);
        }
    }
    
    /// 获取配置
    pub fn getConfig(self: *ConfigManager) *GlobalConfig {
        return &self.config;
    }
};