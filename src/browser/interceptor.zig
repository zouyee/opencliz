const std = @import("std");
const types = @import("../core/types.zig");
const errors = @import("../core/errors.zig");
const http = @import("../http/client.zig");
const cdp = @import("./cdp.zig");

const OpenCliError = errors.OpenCliError;

/// 拦截的请求类型
pub const InterceptType = enum {
    request,      // 拦截请求
    response,     // 拦截响应
    all,          // 拦截所有
};

/// 拦截规则
pub const InterceptRule = struct {
    id: u32,
    pattern: []const u8,           // URL匹配模式 (支持通配符)
    intercept_type: InterceptType,
    action: Action,
    enabled: bool = true,
    
    pub const Action = union(enum) {
        block,                      // 阻止请求
        modify: Modification,      // 修改请求/响应
        log,                        // 仅记录
        callback: CallbackFn,      // 回调函数
        
        pub const Modification = struct {
            headers: ?std.StringHashMap([]const u8) = null,
            body: ?[]const u8 = null,
            status_code: ?u16 = null,
        };
        
        pub const CallbackFn = *const fn (
            allocator: std.mem.Allocator,
            request: *http.Request,
            response: ?*http.Response,
        ) anyerror!void;
    };
};

/// 拦截的请求信息
pub const InterceptedRequest = struct {
    id: u32,
    timestamp: i64,
    method: []const u8,
    url: []const u8,
    headers: std.StringHashMap([]const u8),
    body: ?[]const u8,
    
    pub fn deinit(self: *InterceptedRequest, allocator: std.mem.Allocator) void {
        self.headers.deinit();
        if (self.body) |body| {
            allocator.free(body);
        }
    }
};

/// 拦截的响应信息
pub const InterceptedResponse = struct {
    request_id: u32,
    timestamp: i64,
    status: u16,
    headers: std.StringHashMap([]const u8),
    body: ?[]const u8,
    
    pub fn deinit(self: *InterceptedResponse, allocator: std.mem.Allocator) void {
        self.headers.deinit();
        if (self.body) |body| {
            allocator.free(body);
        }
    }
};

/// 网络拦截器
pub const NetworkInterceptor = struct {
    allocator: std.mem.Allocator,
    rules: std.array_list.Managed(InterceptRule),
    intercepted_requests: std.array_list.Managed(InterceptedRequest),
    intercepted_responses: std.array_list.Managed(InterceptedResponse),
    browser_controller: ?*cdp.BrowserController,
    next_rule_id: u32 = 1,
    
    pub fn init(allocator: std.mem.Allocator) NetworkInterceptor {
        return NetworkInterceptor{
            .allocator = allocator,
            .rules = std.array_list.Managed(InterceptRule).init(allocator),
            .intercepted_requests = std.array_list.Managed(InterceptedRequest).init(allocator),
            .intercepted_responses = std.array_list.Managed(InterceptedResponse).init(allocator),
            .browser_controller = null,
        };
    }
    
    pub fn deinit(self: *NetworkInterceptor) void {
        // 清理拦截的请求
        for (self.intercepted_requests.items) |*req| {
            req.deinit(self.allocator);
        }
        self.intercepted_requests.deinit();
        
        // 清理拦截的响应
        for (self.intercepted_responses.items) |*res| {
            res.deinit(self.allocator);
        }
        self.intercepted_responses.deinit();
        
        // 清理规则
        for (self.rules.items) |*rule| {
            self.allocator.free(rule.pattern);
            switch (rule.action) {
                .modify => |*mod| {
                    if (mod.headers) |*headers| {
                        headers.deinit();
                    }
                    if (mod.body) |body| {
                        self.allocator.free(body);
                    }
                },
                else => {},
            }
        }
        self.rules.deinit();
    }
    
    /// 设置浏览器控制器
    pub fn setBrowserController(self: *NetworkInterceptor, controller: *cdp.BrowserController) void {
        self.browser_controller = controller;
    }
    
    /// 添加拦截规则
    pub fn addRule(
        self: *NetworkInterceptor,
        pattern: []const u8,
        intercept_type: InterceptType,
        action: InterceptRule.Action,
    ) !u32 {
        const id = self.next_rule_id;
        self.next_rule_id += 1;
        
        const pattern_copy = try self.allocator.dupe(u8, pattern);
        
        const rule = InterceptRule{
            .id = id,
            .pattern = pattern_copy,
            .intercept_type = intercept_type,
            .action = action,
            .enabled = true,
        };
        
        try self.rules.append(rule);
        
        // 如果浏览器控制器存在，启用CDP网络拦截
        if (self.browser_controller) |controller| {
            try self.enableCDPInterception(controller, pattern);
        }
        
        return id;
    }
    
    /// 移除拦截规则
    pub fn removeRule(self: *NetworkInterceptor, rule_id: u32) void {
        for (self.rules.items, 0..) |*rule, i| {
            if (rule.id == rule_id) {
                self.allocator.free(rule.pattern);
                _ = self.rules.orderedRemove(i);
                return;
            }
        }
    }
    
    /// 启用/禁用规则
    pub fn toggleRule(self: *NetworkInterceptor, rule_id: u32, enabled: bool) void {
        for (self.rules.items) |*rule| {
            if (rule.id == rule_id) {
                rule.enabled = enabled;
                return;
            }
        }
    }
    
    /// 检查URL是否匹配规则
    fn urlMatchesPattern(url: []const u8, pattern: []const u8) bool {
        // 简单通配符匹配: * 匹配任意字符
        if (std.mem.indexOf(u8, pattern, "*")) |star_pos| {
            const prefix = pattern[0..star_pos];
            const suffix = pattern[star_pos + 1 ..];
            
            if (!std.mem.startsWith(u8, url, prefix)) {
                return false;
            }
            
            if (suffix.len > 0) {
                if (!std.mem.endsWith(u8, url, suffix)) {
                    return false;
                }
            }
            
            return true;
        }
        
        // 精确匹配
        return std.mem.eql(u8, url, pattern);
    }
    
    /// 处理请求拦截
    pub fn interceptRequest(self: *NetworkInterceptor, request: *http.Request) !?http.Response {
        for (self.rules.items) |rule| {
            if (!rule.enabled) continue;
            
            if (rule.intercept_type != .request and rule.intercept_type != .all) {
                continue;
            }
            
            if (!urlMatchesPattern(request.url, rule.pattern)) {
                continue;
            }
            
            // 记录拦截的请求
            try self.logRequest(request);
            
            switch (rule.action) {
                .block => {
                    // 返回阻止响应
                    return http.Response{
                        .status = 403,
                        .headers = std.StringHashMap([]const u8).init(self.allocator),
                        .body = try self.allocator.dupe(u8, "Blocked by interceptor"),
                    };
                },
                .modify => |mod| {
                    // 修改请求
                    if (mod.headers) |headers| {
                        var it = headers.iterator();
                        while (it.next()) |entry| {
                            try request.headers.put(entry.key_ptr.*, entry.value_ptr.*);
                        }
                    }
                    if (mod.body) |body| {
                        request.body = try self.allocator.dupe(u8, body);
                    }
                },
                .log => {
                    // 仅记录，继续请求
                    std.log.info("[INTERCEPT] Request: {s} {s}", .{ request.method, request.url });
                },
                .callback => |callback| {
                    // 执行回调
                    try callback(self.allocator, request, null);
                },
            }
        }
        
        return null; // 不拦截
    }
    
    /// 处理响应拦截
    pub fn interceptResponse(
        self: *NetworkInterceptor,
        request: *http.Request,
        response: *http.Response,
    ) !void {
        for (self.rules.items) |rule| {
            if (!rule.enabled) continue;
            
            if (rule.intercept_type != .response and rule.intercept_type != .all) {
                continue;
            }
            
            if (!urlMatchesPattern(request.url, rule.pattern)) {
                continue;
            }
            
            // 记录拦截的响应
            try self.logResponse(request, response);
            
            switch (rule.action) {
                .block => {
                    // 修改响应为错误
                    response.status = 403;
                    response.body = try self.allocator.dupe(u8, "Blocked by interceptor");
                },
                .modify => |mod| {
                    // 修改响应
                    if (mod.headers) |headers| {
                        var it = headers.iterator();
                        while (it.next()) |entry| {
                            try response.headers.put(entry.key_ptr.*, entry.value_ptr.*);
                        }
                    }
                    if (mod.status_code) |code| {
                        response.status = code;
                    }
                    if (mod.body) |body| {
                        self.allocator.free(response.body);
                        response.body = try self.allocator.dupe(u8, body);
                    }
                },
                .log => {
                    // 仅记录
                    std.log.info("[INTERCEPT] Response: {d} for {s}", .{ response.status, request.url });
                },
                .callback => |callback| {
                    // 执行回调
                    try callback(self.allocator, request, response);
                },
            }
        }
    }
    
    /// 启用CDP网络拦截
    fn enableCDPInterception(self: *NetworkInterceptor, controller: *cdp.BrowserController, pattern: []const u8) !void {
        // 通过CDP启用网络拦截
        // 首先启用Network域
        var enable_params = std.json.ObjectMap.init(self.allocator);
        defer enable_params.deinit();
        
        try controller.browser_manager.cdp_client.send("Network.enable", enable_params);
        
        // 设置请求拦截模式
        var interception_params = std.json.ObjectMap.init(self.allocator);
        defer interception_params.deinit();
        
        // 创建拦截模式数组
        var patterns = std.json.Array.init(self.allocator);
        defer {
            for (patterns.items) |*item| {
                if (item.* == .object) {
                    item.*.object.deinit();
                }
            }
            patterns.deinit();
        }
        
        // 创建单个拦截模式
        var pattern_obj = std.json.ObjectMap.init(self.allocator);
        try pattern_obj.put("urlPattern", std.json.Value{ .string = pattern });
        try pattern_obj.put("resourceType", std.json.Value{ .string = "Document" });
        try pattern_obj.put("interceptionStage", std.json.Value{ .string = "HeadersReceived" });
        try patterns.append(std.json.Value{ .object = pattern_obj });
        
        try interception_params.put("patterns", std.json.Value{ .array = patterns });
        
        try controller.browser_manager.cdp_client.send("Network.setRequestInterception", interception_params);
        
        std.log.info("CDP network interception enabled for pattern: {s}", .{pattern});
    }
    
    /// 处理CDP拦截的请求
    pub fn handleCDPRequest(self: *NetworkInterceptor, request_id: []const u8, request: std.json.ObjectMap) !void {
        if (self.browser_controller) |controller| {
            // 获取请求URL
            if (request.get("url")) |url_value| {
                const url = url_value.string;
                
                // 检查是否匹配任何规则
                for (self.rules.items) |rule| {
                    if (!rule.enabled) continue;
                    if (!urlMatchesPattern(url, rule.pattern)) continue;
                    
                    // 根据规则执行操作
                    switch (rule.action) {
                        .block => {
                            // 阻止请求
                            var params = std.json.ObjectMap.init(self.allocator);
                            defer params.deinit();
                            try params.put("interceptionId", std.json.Value{ .string = request_id });
                            try params.put("errorReason", std.json.Value{ .string = "Aborted" });
                            try controller.browser_manager.cdp_client.send("Network.continueInterceptedRequest", params);
                            return;
                        },
                        .log => {
                            std.log.info("[CDP INTERCEPT] Blocked: {s}", .{url});
                        },
                        else => {},
                    }
                }
            }
            
            // 继续请求
            var params = std.json.ObjectMap.init(self.allocator);
            defer params.deinit();
            try params.put("interceptionId", std.json.Value{ .string = request_id });
            try controller.browser_manager.cdp_client.send("Network.continueInterceptedRequest", params);
        }
    }
    
    /// 记录请求
    fn logRequest(self: *NetworkInterceptor, request: *http.Request) !void {
        var req_copy = InterceptedRequest{
            .id = @intCast(self.intercepted_requests.items.len),
            .timestamp = std.time.milliTimestamp(),
            .method = try self.allocator.dupe(u8, request.method),
            .url = try self.allocator.dupe(u8, request.url),
            .headers = std.StringHashMap([]const u8).init(self.allocator),
            .body = null,
        };
        
        // 复制headers
        var it = request.headers.iterator();
        while (it.next()) |entry| {
            const key = try self.allocator.dupe(u8, entry.key_ptr.*);
            const value = try self.allocator.dupe(u8, entry.value_ptr.*);
            try req_copy.headers.put(key, value);
        }
        
        // 复制body
        if (request.body) |body| {
            req_copy.body = try self.allocator.dupe(u8, body);
        }
        
        try self.intercepted_requests.append(req_copy);
        
        // 限制存储数量
        if (self.intercepted_requests.items.len > 1000) {
            var old_req = self.intercepted_requests.orderedRemove(0);
            old_req.deinit(self.allocator);
        }
    }
    
    /// 记录响应
    fn logResponse(self: *NetworkInterceptor, _: *http.Request, response: *http.Response) !void {
        var res_copy = InterceptedResponse{
            .request_id = @intCast(self.intercepted_responses.items.len),
            .timestamp = std.time.milliTimestamp(),
            .status = response.status,
            .headers = std.StringHashMap([]const u8).init(self.allocator),
            .body = null,
        };
        
        // 复制headers
        var it = response.headers.iterator();
        while (it.next()) |entry| {
            const key = try self.allocator.dupe(u8, entry.key_ptr.*);
            const value = try self.allocator.dupe(u8, entry.value_ptr.*);
            try res_copy.headers.put(key, value);
        }
        
        // 复制body (限制大小)
        if (response.body.len < 10000) {
            res_copy.body = try self.allocator.dupe(u8, response.body);
        } else {
            res_copy.body = try self.allocator.dupe(u8, "[Body too large]");
        }
        
        try self.intercepted_responses.append(res_copy);
        
        // 限制存储数量
        if (self.intercepted_responses.items.len > 1000) {
            var old_res = self.intercepted_responses.orderedRemove(0);
            old_res.deinit(self.allocator);
        }
    }
    
    /// 获取拦截的请求列表
    pub fn getInterceptedRequests(self: *NetworkInterceptor) []const InterceptedRequest {
        return self.intercepted_requests.items;
    }
    
    /// 获取拦截的响应列表
    pub fn getInterceptedResponses(self: *NetworkInterceptor) []const InterceptedResponse {
        return self.intercepted_responses.items;
    }
    
    /// 清空拦截记录
    pub fn clearLogs(self: *NetworkInterceptor) void {
        for (self.intercepted_requests.items) |*req| {
            req.deinit(self.allocator);
        }
        self.intercepted_requests.clearRetainingCapacity();
        
        for (self.intercepted_responses.items) |*res| {
            res.deinit(self.allocator);
        }
        self.intercepted_responses.clearRetainingCapacity();
    }
    
    /// 导出HAR格式的日志
    pub fn exportHAR(self: *NetworkInterceptor, output_path: []const u8) !void {
        var har = std.array_list.Managed(u8).init(self.allocator);
        defer har.deinit();
        
        const writer = har.writer();
        
        try writer.print("{{\n", .{});
        try writer.print("  \"log\": {{\n", .{});
        try writer.print("    \"version\": \"1.2\",\n", .{});
        try writer.print("    \"creator\": {{\"name\": \"opencliz\", \"version\": \"v0.0.1\"}},\n", .{});
        try writer.print("    \"entries\": [\n", .{});
        
        var first = true;
        for (self.intercepted_requests.items) |req| {
            if (!first) try writer.print(",\n", .{});
            first = false;
            
            try writer.print("      {{\n", .{});
            try writer.print("        \"request\": {{\n", .{});
            try writer.print("          \"method\": \"{s}\",\n", .{req.method});
            try writer.print("          \"url\": \"{s}\"\n", .{req.url});
            try writer.print("        }}\n", .{});
            try writer.print("      }}", .{});
        }
        
        try writer.print("\n    ]\n", .{});
        try writer.print("  }}\n", .{});
        try writer.print("}}\n", .{});
        
        const file = try std.fs.cwd().createFile(output_path, .{});
        defer file.close();
        
        try file.writeAll(har.items);
        
        std.log.info("HAR exported to: {s}", .{output_path});
    }
};