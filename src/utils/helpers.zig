const std = @import("std");

/// 字符串工具函数
pub const StringUtils = struct {
    /// 检查字符串是否以指定前缀开头
    pub fn startsWith(str: []const u8, prefix: []const u8) bool {
        return std.mem.startsWith(u8, str, prefix);
    }
    
    /// 检查字符串是否以指定后缀结尾
    pub fn endsWith(str: []const u8, suffix: []const u8) bool {
        return std.mem.endsWith(u8, str, suffix);
    }
    
    /// 去除字符串两端的空白字符
    pub fn trim(str: []const u8) []const u8 {
        return std.mem.trim(u8, str, &std.ascii.whitespace);
    }
    
    /// 模板替换
    pub fn renderTemplate(
        allocator: std.mem.Allocator,
        template: []const u8,
        vars: std.StringHashMap([]const u8),
    ) ![]const u8 {
        var result = std.array_list.Managed(u8).init(allocator);
        defer result.deinit();
        
        var i: usize = 0;
        while (i < template.len) {
            if (std.mem.startsWith(u8, template[i..], "{{")) {
                if (std.mem.indexOf(u8, template[i..], "}}")) |end| {
                    const var_name = trim(template[i + 2 .. i + end]);
                    
                    if (vars.get(var_name)) |value| {
                        try result.appendSlice(value);
                    } else {
                        try result.appendSlice(template[i..i + end + 2]);
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

/// 文件系统工具函数
pub const FileUtils = struct {
    /// 确保目录存在
    pub fn ensureDir(path: []const u8) !void {
        std.fs.cwd().makePath(path) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };
    }
    
    /// 检查文件是否存在
    pub fn fileExists(path: []const u8) bool {
        std.fs.cwd().access(path, .{}) catch return false;
        return true;
    }
};

/// 时间工具函数
pub const TimeUtils = struct {
    /// 获取当前时间戳（秒）
    pub fn nowSeconds() i64 {
        return std.time.timestamp();
    }
    
    /// 睡眠指定毫秒
    pub fn sleepMillis(ms: u64) void {
        std.Thread.sleep(ms * std.time.ns_per_ms);
    }
};

/// JSON工具函数
pub const JsonUtils = struct {
    /// 从JSON对象安全获取值
    pub fn getValue(obj: std.json.ObjectMap, key: []const u8) ?std.json.Value {
        return obj.get(key);
    }
    
    /// 从JSON对象获取字符串
    pub fn getString(obj: std.json.ObjectMap, key: []const u8) ?[]const u8 {
        if (obj.get(key)) |v| {
            if (v == .string) return v.string;
        }
        return null;
    }
};