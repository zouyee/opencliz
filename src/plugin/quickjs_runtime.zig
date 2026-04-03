//! QuickJS-ng 封装（依赖 [mitchellh/zig-quickjs-ng](https://github.com/mitchellh/zig-quickjs-ng)）。
const std = @import("std");
const quickjs = @import("quickjs");
const http_client = @import("../http/client.zig");

const Value = quickjs.Value;
const Context = quickjs.Context;
const qjs_c = quickjs.c;

/// 插件命令脚本可见的 `opencli.version`（与应用 semver 独立，仅表示 QuickJS 宿主 API 级别）。
pub const opencli_plugin_api_version = "0.2.3";

/// URL 白名单检测结果
const UrlCheckResult = enum {
    ok,
    not_https,
    not_whitelisted,
};

/// 检查 URL 是否在白名单中
fn checkUrlWhitelist(url: []const u8, allowed_domains: []const []const u8) UrlCheckResult {
    // 必须以 https:// 开头
    if (!std.mem.startsWith(u8, url, "https://")) {
        return .not_https;
    }

    // 如果没有配置白名单，默认拒绝
    if (allowed_domains.len == 0) {
        return .not_whitelisted;
    }

    // 解析 host
    const after_https = url[8..];
    const path_start = std.mem.indexOfScalar(u8, after_https, '/') orelse after_https.len;
    const host = after_https[0..path_start];

    // 检查是否在白名单中
    for (allowed_domains) |domain| {
        if (std.mem.endsWith(u8, host, domain) or std.mem.eql(u8, host, domain)) {
            return .ok;
        }
    }

    return .not_whitelisted;
}

/// 从环境变量读取白名单
fn getAllowedDomains(allocator: std.mem.Allocator) ![]const []const u8 {
    const env_val = std.process.getEnvVarOwned(allocator, "OPENCLI_PLUGIN_ALLOWED_DOMAINS") catch return &.{};
    defer allocator.free(env_val);

    if (env_val.len == 0) return &.{};

    var domains: std.ArrayList([]const u8) = .empty;
    defer domains.deinit(allocator);
    var iter = std.mem.splitScalar(u8, env_val, ',');
    while (iter.next()) |domain| {
        const trimmed = std.mem.trim(u8, domain, " \t");
        if (trimmed.len > 0) {
            try domains.append(allocator, try allocator.dupe(u8, trimmed));
        }
    }
    return try domains.toOwnedSlice(allocator);
}

fn freeAllowedDomains(allocator: std.mem.Allocator, list: []const []const u8) void {
    if (list.len == 0) return;
    for (list) |d| allocator.free(d);
    allocator.free(list);
}

/// 原生 HTTP 回调使用的分配器（与 QuickJS 单次求值生命周期匹配；短生命周期请求体）。
fn pluginHttpAllocator() std.mem.Allocator {
    return std.heap.page_allocator;
}

fn jsonErrValue(ctx: *Context, msg: []const u8) Value {
    return Value.initStringLen(ctx, msg);
}

fn nativeHttpGet(ctx_opt: ?*Context, _: Value, argv: []const qjs_c.JSValue) Value {
    const ctx = ctx_opt.?;
    if (argv.len < 1) return jsonErrValue(ctx, "{\"error\":\"missing_url\"}");

    const url_val = Value.fromCVal(argv[0]);
    const url_cs = url_val.toCStringLen(ctx) orelse return jsonErrValue(ctx, "{\"error\":\"url_not_string\"}");
    const url = url_cs.ptr[0..url_cs.len];

    const a = pluginHttpAllocator();
    const allowed = getAllowedDomains(a) catch return jsonErrValue(ctx, "{\"error\":\"oom\"}");
    defer freeAllowedDomains(a, allowed);

    const json_out = httpGetSync(a, url, allowed) catch |err| switch (err) {
        error.UrlNotHttps => return jsonErrValue(ctx, "{\"error\":\"url_not_https\"}"),
        error.UrlNotWhitelisted => return jsonErrValue(ctx, "{\"error\":\"url_not_whitelisted\"}"),
        error.ResponseBodyTooLarge => return jsonErrValue(ctx, "{\"error\":\"body_too_large\"}"),
        error.HttpError => return jsonErrValue(ctx, "{\"error\":\"http_error\"}"),
        else => return jsonErrValue(ctx, "{\"error\":\"request_failed\"}"),
    };
    defer a.free(json_out);
    return Value.initStringLen(ctx, json_out);
}

fn nativeHttpHead(ctx_opt: ?*Context, _: Value, argv: []const qjs_c.JSValue) Value {
    const ctx = ctx_opt.?;
    if (argv.len < 1) return jsonErrValue(ctx, "{\"error\":\"missing_url\"}");

    const url_val = Value.fromCVal(argv[0]);
    const url_cs = url_val.toCStringLen(ctx) orelse return jsonErrValue(ctx, "{\"error\":\"url_not_string\"}");
    const url = url_cs.ptr[0..url_cs.len];

    const a = pluginHttpAllocator();
    const allowed = getAllowedDomains(a) catch return jsonErrValue(ctx, "{\"error\":\"oom\"}");
    defer freeAllowedDomains(a, allowed);

    const json_out = httpHeadSync(a, url, allowed) catch |err| switch (err) {
        error.UrlNotHttps => return jsonErrValue(ctx, "{\"error\":\"url_not_https\"}"),
        error.UrlNotWhitelisted => return jsonErrValue(ctx, "{\"error\":\"url_not_whitelisted\"}"),
        error.ResponseBodyTooLarge => return jsonErrValue(ctx, "{\"error\":\"body_too_large\"}"),
        error.HttpError => return jsonErrValue(ctx, "{\"error\":\"http_error\"}"),
        else => return jsonErrValue(ctx, "{\"error\":\"request_failed\"}"),
    };
    defer a.free(json_out);
    return Value.initStringLen(ctx, json_out);
}

fn nativeHttpPost(ctx_opt: ?*Context, _: Value, argv: []const qjs_c.JSValue) Value {
    const ctx = ctx_opt.?;
    if (argv.len < 2) return jsonErrValue(ctx, "{\"error\":\"missing_url_or_body\"}");

    const url_val = Value.fromCVal(argv[0]);
    const body_val = Value.fromCVal(argv[1]);
    const url_cs = url_val.toCStringLen(ctx) orelse return jsonErrValue(ctx, "{\"error\":\"url_not_string\"}");
    const url = url_cs.ptr[0..url_cs.len];
    const body_cs = body_val.toCStringLen(ctx) orelse return jsonErrValue(ctx, "{\"error\":\"body_not_string\"}");
    const body = body_cs.ptr[0..body_cs.len];

    const a = pluginHttpAllocator();
    const allowed = getAllowedDomains(a) catch return jsonErrValue(ctx, "{\"error\":\"oom\"}");
    defer freeAllowedDomains(a, allowed);

    const json_out = httpPostSync(a, url, body, allowed) catch |err| switch (err) {
        error.UrlNotHttps => return jsonErrValue(ctx, "{\"error\":\"url_not_https\"}"),
        error.UrlNotWhitelisted => return jsonErrValue(ctx, "{\"error\":\"url_not_whitelisted\"}"),
        error.ResponseBodyTooLarge => return jsonErrValue(ctx, "{\"error\":\"body_too_large\"}"),
        error.HttpError => return jsonErrValue(ctx, "{\"error\":\"http_error\"}"),
        else => return jsonErrValue(ctx, "{\"error\":\"request_failed\"}"),
    };
    defer a.free(json_out);
    return Value.initStringLen(ctx, json_out);
}

fn nativeHttpRequest(ctx_opt: ?*Context, _: Value, argv: []const qjs_c.JSValue) Value {
    const ctx = ctx_opt.?;
    if (argv.len < 2) return jsonErrValue(ctx, "{\"error\":\"missing_method_or_url\"}");

    const m_val = Value.fromCVal(argv[0]);
    const u_val = Value.fromCVal(argv[1]);
    const m_cs = m_val.toCStringLen(ctx) orelse return jsonErrValue(ctx, "{\"error\":\"method_not_string\"}");
    _ = u_val.toCStringLen(ctx) orelse return jsonErrValue(ctx, "{\"error\":\"url_not_string\"}");
    const method = m_cs.ptr[0..m_cs.len];

    var body: []const u8 = "";
    if (argv.len >= 3) {
        const b_val = Value.fromCVal(argv[2]);
        if (b_val.toCStringLen(ctx)) |bc| {
            body = bc.ptr[0..bc.len];
        } else {
            return jsonErrValue(ctx, "{\"error\":\"body_not_string\"}");
        }
    }

    if (std.ascii.eqlIgnoreCase(method, "GET")) {
        return nativeHttpGet(ctx_opt, Value.@"undefined", &.{argv[1]});
    }
    if (std.ascii.eqlIgnoreCase(method, "POST")) {
        if (argv.len < 3) return jsonErrValue(ctx, "{\"error\":\"post_body_required\"}");
        return nativeHttpPost(ctx_opt, Value.@"undefined", &.{ argv[1], argv[2] });
    }
    if (std.ascii.eqlIgnoreCase(method, "HEAD")) {
        return nativeHttpHead(ctx_opt, Value.@"undefined", &.{argv[1]});
    }
    return jsonErrValue(ctx, "{\"error\":\"method_not_allowed\"}");
}

/// 获取 HTTP 超时时间（毫秒）
fn getHttpTimeout() u32 {
    const env_val = std.process.getEnvVarOwned(std.heap.page_allocator, "OPENCLI_PLUGIN_HTTP_TIMEOUT") catch return 30000;
    defer std.heap.page_allocator.free(env_val);
    return std.fmt.parseInt(u32, env_val, 10) catch 30000;
}

/// 检查是否启用插件 HTTP
fn isPluginHttpEnabled() bool {
    const env_val = std.process.getEnvVarOwned(std.heap.page_allocator, "OPENCLI_PLUGIN_HTTP") catch return false;
    defer std.heap.page_allocator.free(env_val);
    return std.mem.eql(u8, env_val, "1");
}

/// 插件 HTTP 响应体最大字节数（防止 OOM）。`OPENCLI_PLUGIN_HTTP_MAX_BODY_BYTES`，默认 **2 MiB**。
fn getPluginHttpMaxResponseBodyBytes() usize {
    const env_val = std.process.getEnvVarOwned(std.heap.page_allocator, "OPENCLI_PLUGIN_HTTP_MAX_BODY_BYTES") catch return 2 * 1024 * 1024;
    defer std.heap.page_allocator.free(env_val);
    if (env_val.len == 0) return 2 * 1024 * 1024;
    return std.fmt.parseInt(usize, env_val, 10) catch 2 * 1024 * 1024;
}

/// 执行 HTTP GET 请求并返回 JSON 响应
fn httpGetSync(allocator: std.mem.Allocator, url: []const u8, allowed_domains: []const []const u8) ![]const u8 {
    switch (checkUrlWhitelist(url, allowed_domains)) {
        .not_https => return error.UrlNotHttps,
        .not_whitelisted => return error.UrlNotWhitelisted,
        .ok => {},
    }

    var client = try http_client.HttpClient.init(allocator);
    defer client.deinit();

    const timeout = getHttpTimeout();
    client.timeout_ms = timeout;

    var response = try client.get(url);
    defer {
        response.headers.deinit();
        allocator.free(response.body);
    }

    const max_body = getPluginHttpMaxResponseBodyBytes();
    if (response.body.len > max_body) {
        return error.ResponseBodyTooLarge;
    }

    var result = std.json.ObjectMap.init(allocator);
    defer result.deinit();

    try result.put("status", .{ .integer = response.status });
    try result.put("body", .{ .string = response.body });
    try result.put("url", .{ .string = url });

    const json_str = try std.json.Stringify.valueAlloc(allocator, std.json.Value{ .object = result }, .{});
    return json_str;
}

/// HEAD 请求；返回 JSON 含 **`status`**、**`url`**；**`body`** 为 curl **`-I`** 打印的**响应头原文**（非实体 body）。
fn httpHeadSync(allocator: std.mem.Allocator, url: []const u8, allowed_domains: []const []const u8) ![]const u8 {
    switch (checkUrlWhitelist(url, allowed_domains)) {
        .not_https => return error.UrlNotHttps,
        .not_whitelisted => return error.UrlNotWhitelisted,
        .ok => {},
    }

    var client = try http_client.HttpClient.init(allocator);
    defer client.deinit();

    const timeout = getHttpTimeout();
    client.timeout_ms = timeout;

    var response = try client.head(url);
    defer {
        response.headers.deinit();
        allocator.free(response.body);
    }

    const max_body = getPluginHttpMaxResponseBodyBytes();
    if (response.body.len > max_body) {
        return error.ResponseBodyTooLarge;
    }

    var result = std.json.ObjectMap.init(allocator);
    defer result.deinit();

    try result.put("status", .{ .integer = response.status });
    try result.put("body", .{ .string = response.body });
    try result.put("url", .{ .string = url });

    const json_str = try std.json.Stringify.valueAlloc(allocator, std.json.Value{ .object = result }, .{});
    return json_str;
}

/// 执行 HTTP POST 请求并返回 JSON 响应
fn httpPostSync(allocator: std.mem.Allocator, url: []const u8, body: []const u8, allowed_domains: []const []const u8) ![]const u8 {
    switch (checkUrlWhitelist(url, allowed_domains)) {
        .not_https => return error.UrlNotHttps,
        .not_whitelisted => return error.UrlNotWhitelisted,
        .ok => {},
    }

    var client = try http_client.HttpClient.init(allocator);
    defer client.deinit();

    const timeout = getHttpTimeout();
    client.timeout_ms = timeout;

    var response = try client.post(url, body, "application/json");
    defer {
        response.headers.deinit();
        allocator.free(response.body);
    }

    const max_body = getPluginHttpMaxResponseBodyBytes();
    if (response.body.len > max_body) {
        return error.ResponseBodyTooLarge;
    }

    var result = std.json.ObjectMap.init(allocator);
    defer result.deinit();

    try result.put("status", .{ .integer = response.status });
    try result.put("body", .{ .string = response.body });
    try result.put("url", .{ .string = url });

    const json_str = try std.json.Stringify.valueAlloc(allocator, std.json.Value{ .object = result }, .{});
    return json_str;
}

/// 在独立 Runtime 中执行一段 JS，将返回值转为字符串（`toString` 语义）。
pub fn evalExpressionToString(allocator: std.mem.Allocator, source: []const u8) error{ JsException, JsNotString, OutOfMemory, JSError }![]const u8 {
    return evalExpressionToStringWithHttp(allocator, source, false);
}

fn evalExpressionToStringWithHttp(allocator: std.mem.Allocator, source: []const u8, register_plugin_http: bool) error{ JsException, JsNotString, OutOfMemory, JSError }![]const u8 {
    const rt = try quickjs.Runtime.init();
    defer rt.deinit();
    const ctx = try quickjs.Context.init(rt);
    defer ctx.deinit();

    if (register_plugin_http) {
        const global = ctx.getGlobalObject();
        defer global.deinit(ctx);

        const f_get = Value.initCFunction(ctx, &nativeHttpGet, "__opencli_http_get", 1);
        defer f_get.deinit(ctx);
        try global.setPropertyStr(ctx, "__opencli_http_get", f_get.dup(ctx));

        const f_post = Value.initCFunction(ctx, &nativeHttpPost, "__opencli_http_post", 2);
        defer f_post.deinit(ctx);
        try global.setPropertyStr(ctx, "__opencli_http_post", f_post.dup(ctx));

        const f_req = Value.initCFunction(ctx, &nativeHttpRequest, "__opencli_http_request", 3);
        defer f_req.deinit(ctx);
        try global.setPropertyStr(ctx, "__opencli_http_request", f_req.dup(ctx));
    }

    var result = ctx.eval(source, "<opencli>", .{});
    defer result.deinit(ctx);
    if (result.isException()) return error.JsException;

    const as_str = result.toStringValue(ctx);
    defer as_str.deinit(ctx);
    const z = as_str.toZigSlice(ctx) orelse return error.JsNotString;
    return try allocator.dupe(u8, z[0..z.len]);
}

/// 将命令脚本作为函数体执行：脚本内应使用 `return`；`opencliArgs` 为 CLI 实参对象（`args_json` 须为合法 JSON 对象字面量）。
/// 注入 **`opencli`**：`opencli.args` 与 `opencliArgs` 相同；`opencli.version` 为 [`opencli_plugin_api_version`]；**`opencli.log(m)`** 经 QuickJS **`print`** 输出（前缀 `[opencli] `），不进入 JSON 返回值。
/// 可选注入 **`opencli.http`**：当 `OPENCLI_PLUGIN_HTTP=1` 时注入，提供 `get(url)` / `post(url, body)` / `request(method, url, options)` 方法（**`method`** 支持 **GET** / **POST** / **HEAD**；带 URL 白名单验证）。
pub fn evalPluginHandlerBody(
    allocator: std.mem.Allocator,
    user_script_body: []const u8,
    args_json: []const u8,
) error{ JsException, JsNotString, OutOfMemory, JSError }![]const u8 {
    const http_enabled = isPluginHttpEnabled();

    var code: std.ArrayList(u8) = .empty;
    defer code.deinit(allocator);

    // 构建 opencli 对象开头
    try code.appendSlice(allocator, "JSON.stringify((function(opencliArgs){ var opencli={args:opencliArgs,version:\"");
    try code.appendSlice(allocator, opencli_plugin_api_version);
    try code.appendSlice(allocator, "\",log:function(_m){try{print('[opencli] '+String(_m));}catch(_e){}}}; ");

    // 如果启用了 HTTP：由宿主注册全局 `__opencli_http_*` 原生函数（见 `evalExpressionToStringWithHttp`）
    if (http_enabled) {
        try code.appendSlice(allocator, "opencli.http={get:function(url){try{var r=__opencli_http_get(url);return JSON.parse(r);}catch(e){return {error:String(e),url:url};}},post:function(url,body){try{var r=__opencli_http_post(url,String(body));return JSON.parse(r);}catch(e){return {error:String(e),url:url};}},request:function(method,url,options){try{var b=(options&&options.body!==void 0)?String(options.body):'';var r=__opencli_http_request(String(method),url,b);return JSON.parse(r);}catch(e){return {error:String(e),url:url};}}}; ");
    }

    // 用户脚本
    try code.appendSlice(allocator, user_script_body);
    try code.appendSlice(allocator, " })(");
    try code.appendSlice(allocator, args_json);
    try code.appendSlice(allocator, "));");

    const slice = try code.toOwnedSlice(allocator);
    defer allocator.free(slice);
    return evalExpressionToStringWithHttp(allocator, slice, http_enabled);
}

test "quickjs basic eval" {
    const testing = std.testing;
    const s = try evalExpressionToString(testing.allocator, "21 * 2");
    defer testing.allocator.free(s);
    try testing.expectEqualStrings("42", s);
}

test "plugin handler wrap returns json string" {
    const testing = std.testing;
    const body = "return { doubled: opencliArgs.n * 2 };";
    const args = "{\"n\":21}";
    const s = try evalPluginHandlerBody(testing.allocator, body, args);
    defer testing.allocator.free(s);
    const v = try std.json.parseFromSliceLeaky(std.json.Value, testing.allocator, s, .{});
    const obj = v.object;
    try testing.expectEqual(@as(i64, 42), obj.get("doubled").?.integer);
}

test "opencli api args and version in plugin handler" {
    const testing = std.testing;
    const body = "return { v: opencli.version, x: opencli.args.k };";
    const args = "{\"k\":\"val\"}";
    const s = try evalPluginHandlerBody(testing.allocator, body, args);
    defer testing.allocator.free(s);
    const v = try std.json.parseFromSliceLeaky(std.json.Value, testing.allocator, s, .{});
    const obj = v.object;
    try testing.expectEqualStrings(opencli_plugin_api_version, obj.get("v").?.string);
    try testing.expectEqualStrings("val", obj.get("x").?.string);
}

test "opencli.log callable without breaking return value" {
    const testing = std.testing;
    const body = "opencli.log('dbg'); return { ok: true };";
    const args = "{}";
    const s = try evalPluginHandlerBody(testing.allocator, body, args);
    defer testing.allocator.free(s);
    const v = try std.json.parseFromSliceLeaky(std.json.Value, testing.allocator, s, .{});
    try std.testing.expect(v == .object);
    try std.testing.expect(v.object.get("ok").?.bool == true);
}

test "httpGetSync rejects non-https" {
    const testing = std.testing;
    const allowed = [_][]const u8{"example.com"};
    try testing.expectError(error.UrlNotHttps, httpGetSync(testing.allocator, "http://example.com/", &allowed));
}

test "httpGetSync rejects when whitelist empty" {
    const testing = std.testing;
    try testing.expectError(error.UrlNotWhitelisted, httpGetSync(testing.allocator, "https://example.com/", &.{}));
}

test "httpPostSync rejects when whitelist empty" {
    const testing = std.testing;
    try testing.expectError(error.UrlNotWhitelisted, httpPostSync(testing.allocator, "https://example.com/", "{}", &.{}));
}

test "httpHeadSync rejects non-https" {
    const testing = std.testing;
    const allowed = [_][]const u8{"example.com"};
    try testing.expectError(error.UrlNotHttps, httpHeadSync(testing.allocator, "http://example.com/", &allowed));
}

test "httpHeadSync rejects when whitelist empty" {
    const testing = std.testing;
    try testing.expectError(error.UrlNotWhitelisted, httpHeadSync(testing.allocator, "https://example.com/", &.{}));
}
