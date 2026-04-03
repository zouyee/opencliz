const std = @import("std");
const types = @import("../core/types.zig");
const errors = @import("../core/errors.zig");
const websocket = @import("websocket.zig");

const OpenCliError = errors.OpenCliError;

/// 浏览器控制 - 使用CDP
pub const BrowserController = struct {
    allocator: std.mem.Allocator,
    browser_manager: websocket.BrowserManager,
    
    pub fn init(allocator: std.mem.Allocator) BrowserController {
        return BrowserController{
            .allocator = allocator,
            .browser_manager = websocket.BrowserManager.init(allocator),
        };
    }
    
    pub fn deinit(self: *BrowserController) void {
        self.browser_manager.deinit();
    }
    
    /// 启动浏览器
    pub fn start(self: *BrowserController, headless: bool) !void {
        try self.browser_manager.start(headless);
    }
    
    /// 停止浏览器
    pub fn stop(self: *BrowserController) void {
        self.browser_manager.stop();
    }
    
    /// 导航到URL
    pub fn navigate(self: *BrowserController, url: []const u8) !void {
        try self.browser_manager.navigate(url);
    }
    
    /// 执行JavaScript
    pub fn evaluate(self: *BrowserController, expression: []const u8) ![]const u8 {
        try self.browser_manager.evaluate(expression);
        
        // 等待并获取结果
        if (try self.browser_manager.getCDP().receive(5000)) |message| {
            defer self.allocator.free(message);
            return try self.allocator.dupe(u8, message);
        }
        
        return try self.allocator.dupe(u8, "{}");
    }
    
    /// 点击元素
    pub fn click(self: *BrowserController, selector: []const u8) !void {
        try self.browser_manager.getCDP().click(selector);
    }
    
    /// 输入文本
    pub fn typeText(self: *BrowserController, selector: []const u8, text: []const u8) !void {
        try self.browser_manager.getCDP().typeText(selector, text);
    }
    
    /// 等待元素出现
    pub fn waitForSelector(self: *BrowserController, selector: []const u8, timeout_ms: u32) !void {
        const start_time = std.time.milliTimestamp();
        
        while (std.time.milliTimestamp() - start_time < timeout_ms) {
            const expr = try std.fmt.allocPrint(
                self.allocator,
                "document.querySelector('{s}') !== null",
                .{selector}
            );
            defer self.allocator.free(expr);
            
            const result = try self.evaluate(expr);
            defer self.allocator.free(result);
            
            if (std.mem.containsAtLeast(u8, result, 1, "true")) {
                return;
            }
            
            std.Thread.sleep(100 * std.time.ns_per_ms);
        }
        
        return OpenCliError.Timeout;
    }
    
    /// 获取页面内容
    pub fn getContent(self: *BrowserController) ![]const u8 {
        return try self.evaluate("document.documentElement.outerHTML");
    }
    
    /// 截图
    pub fn screenshot(self: *BrowserController, output_path: []const u8) !void {
        try self.browser_manager.screenshot(output_path, .{});
    }
};

/// 简化的浏览器步骤执行器
pub const BrowserStepExecutor = struct {
    allocator: std.mem.Allocator,
    controller: BrowserController,
    
    pub fn init(allocator: std.mem.Allocator) BrowserStepExecutor {
        return BrowserStepExecutor{
            .allocator = allocator,
            .controller = BrowserController.init(allocator),
        };
    }
    
    pub fn deinit(self: *BrowserStepExecutor) void {
        self.controller.deinit();
    }
    
    /// 执行浏览器步骤
    pub fn execute(self: *BrowserStepExecutor, step_config: std.StringHashMap([]const u8)) !?std.json.Value {
        // 确保浏览器已启动
        try self.controller.start(true);
        
        // 导航到URL
        if (step_config.get("url")) |url| {
            try self.controller.navigate(url);
            std.log.info("Navigated to: {s}", .{url});
        }
        
        // 等待元素
        if (step_config.get("waitFor")) |selector| {
            const timeout = if (step_config.get("timeout")) |t|
                try std.fmt.parseInt(u32, t, 10)
            else
                30000;
            
            try self.controller.waitForSelector(selector, timeout);
            std.log.info("Element found: {s}", .{selector});
        }
        
        // 点击元素
        if (step_config.get("click")) |selector| {
            try self.controller.click(selector);
            std.log.info("Clicked: {s}", .{selector});
        }
        
        // 输入文本
        if (step_config.get("type")) |selector| {
            if (step_config.get("value")) |value| {
                try self.controller.typeText(selector, value);
                std.log.info("Typed into: {s}", .{selector});
            }
        }
        
        // 执行JavaScript
        if (step_config.get("evaluate")) |script| {
            const result = try self.controller.evaluate(script);
            defer self.allocator.free(result);
            
            return try std.json.parseFromSliceLeaky(std.json.Value, self.allocator, result, .{});
        }
        
        // 获取页面内容
        if (step_config.get("extract")) |_| {
            const content = try self.controller.getContent();
            defer self.allocator.free(content);
            const owned = try self.allocator.dupe(u8, content);
            return std.json.Value{ .string = owned };
        }
        
        return null;
    }
};