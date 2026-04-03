const std = @import("std");
const types = @import("../core/types.zig");

/// 钩子类型
pub const HookType = enum {
    on_startup,           // CLI启动时
    on_before_execute,    // 命令执行前
    on_after_execute,     // 命令执行后
    on_error,            // 发生错误时
    on_shutdown,         // CLI关闭时
};

/// 钩子上下文
pub const HookContext = struct {
    hook_type: HookType,
    command: ?types.Command,
    args: ?std.StringHashMap([]const u8),
    result: ?std.json.Value,
    error_info: ?[]const u8,
    timestamp: i64,
    
    pub fn init(hook_type: HookType) HookContext {
        return HookContext{
            .hook_type = hook_type,
            .command = null,
            .args = null,
            .result = null,
            .error_info = null,
            .timestamp = std.time.timestamp(),
        };
    }
};

/// 钩子函数类型
pub const HookFn = *const fn (ctx: HookContext) anyerror!void;

/// 钩子处理器
pub const HookHandler = struct {
    hook_type: HookType,
    handler: HookFn,
    priority: i32,  // 优先级，数字越小优先级越高
    name: []const u8,
    
    pub fn init(hook_type: HookType, handler: HookFn, name: []const u8, priority: i32) HookHandler {
        return HookHandler{
            .hook_type = hook_type,
            .handler = handler,
            .priority = priority,
            .name = name,
        };
    }
};

/// 钩子管理器
pub const HooksManager = struct {
    allocator: std.mem.Allocator,
    handlers: std.array_list.Managed(HookHandler),
    enabled: bool = true,
    
    pub fn init(allocator: std.mem.Allocator) HooksManager {
        return HooksManager{
            .allocator = allocator,
            .handlers = std.array_list.Managed(HookHandler).init(allocator),
            .enabled = true,
        };
    }
    
    pub fn deinit(self: *HooksManager) void {
        self.handlers.deinit();
    }
    
    /// 注册钩子处理器
    pub fn register(self: *HooksManager, handler: HookHandler) !void {
        try self.handlers.append(handler);
        
        // 按优先级排序
        std.mem.sort(HookHandler, self.handlers.items, {}, 
            struct {
                pub fn lessThan(_: void, a: HookHandler, b: HookHandler) bool {
                    return a.priority < b.priority;
                }
            }.lessThan);
    }
    
    /// 注销钩子处理器
    pub fn unregister(self: *HooksManager, name: []const u8) void {
        for (self.handlers.items, 0..) |handler, i| {
            if (std.mem.eql(u8, handler.name, name)) {
                _ = self.handlers.orderedRemove(i);
                return;
            }
        }
    }
    
    /// 触发钩子
    pub fn trigger(self: *HooksManager, ctx: HookContext) !void {
        if (!self.enabled) return;
        
        for (self.handlers.items) |handler| {
            if (handler.hook_type == ctx.hook_type) {
                handler.handler(ctx) catch |err| {
                    std.log.warn("Hook '{s}' failed: {}", .{ handler.name, err });
                    // 继续执行其他钩子，不中断
                };
            }
        }
    }
    
    /// 启用/禁用钩子系统
    pub fn setEnabled(self: *HooksManager, enabled: bool) void {
        self.enabled = enabled;
    }
    
    /// 获取特定类型的钩子处理器
    pub fn getHandlersForType(self: *HooksManager, hook_type: HookType) []HookHandler {
        var result = std.array_list.Managed(HookHandler).init(self.allocator);
        defer result.deinit();
        
        for (self.handlers.items) |handler| {
            if (handler.hook_type == hook_type) {
                result.append(handler) catch continue;
            }
        }
        
        return result.toOwnedSlice() catch &[]HookHandler{};
    }
    
    /// 内置钩子：日志记录
    pub fn loggingHook(ctx: HookContext) !void {
        switch (ctx.hook_type) {
            .on_startup => std.log.info("[Hook] CLI starting up", .{}),
            .on_before_execute => if (ctx.command) |cmd| {
                std.log.info("[Hook] About to execute: {s}/{s}", .{ cmd.site, cmd.name });
            },
            .on_after_execute => if (ctx.command) |cmd| {
                std.log.info("[Hook] Finished executing: {s}/{s}", .{ cmd.site, cmd.name });
            },
            .on_error => if (ctx.error_info) |err| {
                std.log.err("[Hook] Error occurred: {s}", .{err});
            },
            .on_shutdown => std.log.info("[Hook] CLI shutting down", .{}),
        }
    }
    
    /// 内置钩子：性能计时
    pub fn timingHook(ctx: HookContext) !void {
        switch (ctx.hook_type) {
            .on_before_execute => {
                // 可以在这里记录开始时间
                std.log.debug("[Hook] Timing started", .{});
            },
            .on_after_execute => {
                std.log.debug("[Hook] Timing ended", .{});
            },
            else => {},
        }
    }
    
    /// 内置钩子：命令验证
    pub fn validationHook(ctx: HookContext) !void {
        if (ctx.hook_type == .on_before_execute) {
            if (ctx.command) |cmd| {
                // 验证命令配置
                if (cmd.site.len == 0 or cmd.name.len == 0) {
                    return error.InvalidCommandConfig;
                }
            }
        }
    }
    
    /// 初始化默认钩子
    pub fn initDefaultHooks(self: *HooksManager) !void {
        // 注册日志钩子
        try self.register(HookHandler.init(
            .on_startup,
            loggingHook,
            "logging",
            100,
        ));
        
        try self.register(HookHandler.init(
            .on_before_execute,
            loggingHook,
            "logging_before",
            100,
        ));
        
        try self.register(HookHandler.init(
            .on_after_execute,
            loggingHook,
            "logging_after",
            100,
        ));
        
        try self.register(HookHandler.init(
            .on_error,
            loggingHook,
            "logging_error",
            100,
        ));
        
        try self.register(HookHandler.init(
            .on_shutdown,
            loggingHook,
            "logging_shutdown",
            100,
        ));
        
        // 注册验证钩子
        try self.register(HookHandler.init(
            .on_before_execute,
            validationHook,
            "validation",
            10,
        ));
    }
};

/// 全局钩子管理器实例
var global_hooks_manager: ?HooksManager = null;

/// 初始化全局钩子管理器
pub fn initGlobalHooks(allocator: std.mem.Allocator) !void {
    if (global_hooks_manager == null) {
        global_hooks_manager = HooksManager.init(allocator);
        try global_hooks_manager.?.initDefaultHooks();
    }
}

/// 获取全局钩子管理器
pub fn getGlobalHooks() ?*HooksManager {
    return if (global_hooks_manager) |*mgr| mgr else null;
}

/// 关闭全局钩子管理器
pub fn deinitGlobalHooks() void {
    if (global_hooks_manager) |*mgr| {
        mgr.deinit();
        global_hooks_manager = null;
    }
}
