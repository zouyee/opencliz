//! 对齐旧版 Node：对 `browser: true` 的适配器命令，在设置 `OPENCLI_USE_BROWSER=1` 时用 CDP 拉取渲染后 DOM，再走 `article_pipeline`（与 HTTP 路径同构）。
const std = @import("std");
const types = @import("../core/types.zig");
const cdp = @import("../browser/cdp.zig");
const pipeline = @import("../pipeline/executor.zig");
const article_pipeline = @import("article_pipeline.zig");

/// CDP 内执行后应得到 `JSON.stringify({title,text})`，减轻整页 outerHTML 体积（阶段 D 中期）。
const evaluate_title_text = "JSON.stringify({title:(document.title||''),text:((document.body&&document.body.innerText)||'')})";

const TitleTextPair = struct {
    title: []u8,
    text: []u8,
};

const BrowserProfile = struct {
    wait_for: ?[]const u8 = null,
    /// `waitFor` 超时（毫秒）
    wait_timeout_ms: u32 = 30_000,
    /// 若设置：在 wait 后 `Runtime.evaluate`，解析 `title`/`text` 合成伪 HTML 再走文章管道；失败则回退 outerHTML。
    evaluate_light: ?[]const u8 = null,
};

/// 按站点/命令选择 CDP 等待选择器（阶段 D），减轻白屏或懒加载。
fn browserProfile(site: []const u8, name: []const u8) BrowserProfile {
    if (std.mem.eql(u8, site, "weixin") and std.mem.eql(u8, name, "download"))
        return .{ .wait_for = "#js_content", .wait_timeout_ms = 45_000, .evaluate_light = evaluate_title_text };
    if (std.mem.eql(u8, site, "web") and std.mem.eql(u8, name, "read"))
        return .{ .wait_for = "body", .wait_timeout_ms = 15_000, .evaluate_light = evaluate_title_text };
    if (std.mem.eql(u8, site, "zhihu") and std.mem.eql(u8, name, "download"))
        return .{ .wait_for = ".QuestionHeader, body", .wait_timeout_ms = 20_000, .evaluate_light = evaluate_title_text };
    if (std.mem.eql(u8, site, "sinablog") and std.mem.eql(u8, name, "article"))
        return .{ .wait_for = "body", .wait_timeout_ms = 15_000, .evaluate_light = evaluate_title_text };
    if (std.mem.eql(u8, site, "jd") and std.mem.eql(u8, name, "item"))
        return .{ .wait_for = "body", .wait_timeout_ms = 20_000, .evaluate_light = evaluate_title_text };
    return .{};
}

fn extractTitleTextPair(allocator: std.mem.Allocator, map: std.json.ObjectMap) !?TitleTextPair {
    const t = map.get("title") orelse return null;
    const x = map.get("text") orelse return null;
    if (t != .string or x != .string) return null;
    return .{
        .title = try allocator.dupe(u8, t.string),
        .text = try allocator.dupe(u8, x.string),
    };
}

fn titleTextFromEvaluateJson(allocator: std.mem.Allocator, root: std.json.Value) !?TitleTextPair {
    return switch (root) {
        .object => |map| try extractTitleTextPair(allocator, map),
        .string => |s| {
            const parsed = try std.json.parseFromSlice(std.json.Value, allocator, s, .{});
            defer parsed.deinit();
            return switch (parsed.value) {
                .object => |map| try extractTitleTextPair(allocator, map),
                else => null,
            };
        },
        else => null,
    };
}

fn firstHttpUrlInString(s: []const u8) ?[]const u8 {
    const needle = "http";
    var pos: usize = 0;
    while (pos < s.len) {
        if (std.mem.indexOfPos(u8, s, pos, needle)) |i| {
            var j = i;
            while (j < s.len) {
                const c = s[j];
                if (c == ' ' or c == '\t' or c == '\n' or c == '\r' or c == '|' or c == ')')
                    break;
                j += 1;
            }
            if (j > i) return s[i..j];
            pos = i + 1;
        } else break;
    }
    return null;
}

/// HTTP 结果之后调用：若启用浏览器且能解析到 URL，则用 CDP 取 `outerHTML` 再生成与 `fetchPageArticle` 一致的结构。
pub fn maybeBrowserDeepen(
    allocator: std.mem.Allocator,
    config: *types.Config,
    cmd: types.Command,
    args: std.StringHashMap([]const u8),
    http_result: std.json.Value,
    exec: *pipeline.PipelineExecutor,
) !std.json.Value {
    if (!cmd.browser) return http_result;
    if (!config.browser.enabled) return http_result;
    const use = std.process.getEnvVarOwned(allocator, "OPENCLI_USE_BROWSER") catch return http_result;
    defer allocator.free(use);
    if (!std.mem.eql(u8, use, "1")) return http_result;

    var page_url: ?[]const u8 = args.get("url");
    if (page_url == null and http_result == .object) {
        if (http_result.object.get("detail")) |d| {
            if (d == .string) page_url = firstHttpUrlInString(d.string);
        }
    }
    if (page_url == null and http_result == .object) {
        if (http_result.object.get("url")) |u| {
            if (u == .string and std.mem.startsWith(u8, u.string, "http")) page_url = u.string;
        }
    }
    const u = page_url orelse return http_result;

    const out_dir = args.get("output");

    if (exec.browser_executor == null) {
        exec.browser_executor = cdp.BrowserStepExecutor.init(allocator);
    }
    const be = &exec.browser_executor.?;

    // 对齐 execution.ts `resolvePreNav`：cookie/header 策略先打开站点根域。
    if (cmd.strategy == .cookie and cmd.domain.len > 0) {
        const pre = try std.fmt.allocPrint(allocator, "https://{s}", .{cmd.domain});
        defer allocator.free(pre);
        var pre_map = std.StringHashMap([]const u8).init(allocator);
        defer pre_map.deinit();
        try pre_map.put("url", pre);
        _ = be.execute(pre_map) catch {};
        std.Thread.sleep(2 * std.time.ns_per_s);
    }

    const prof = browserProfile(cmd.site, cmd.name);
    const article_opts = article_pipeline.ArticleOpts{ .http_client = &exec.context.http_client };

    if (prof.evaluate_light) |js_exp| {
        var ev_map = std.StringHashMap([]const u8).init(allocator);
        defer ev_map.deinit();
        try ev_map.put("url", u);
        if (prof.wait_for) |wf| {
            try ev_map.put("waitFor", wf);
            var tbuf: [12]u8 = undefined;
            const ts = std.fmt.bufPrint(&tbuf, "{d}", .{prof.wait_timeout_ms}) catch return http_result;
            try ev_map.put("timeout", ts);
        }
        try ev_map.put("evaluate", js_exp);

        if (be.execute(ev_map)) |ev_maybe| {
            if (ev_maybe) |ev_root| {
                if (try titleTextFromEvaluateJson(allocator, ev_root)) |pair| {
                    defer allocator.free(pair.title);
                    defer allocator.free(pair.text);
                    var syn = std.array_list.Managed(u8).init(allocator);
                    errdefer syn.deinit();
                    try syn.appendSlice("<!DOCTYPE html><html><head><title>");
                    try syn.appendSlice(pair.title);
                    try syn.appendSlice("</title></head><body><article>");
                    try syn.appendSlice(pair.text);
                    try syn.appendSlice("</article></body></html>");
                    const syn_html = try syn.toOwnedSlice();
                    defer allocator.free(syn_html);
                    return article_pipeline.processHtmlArticle(allocator, cmd.name, u, syn_html, out_dir, article_opts) catch http_result;
                }
            }
        } else |_| {}
    }

    var nav_map = std.StringHashMap([]const u8).init(allocator);
    defer nav_map.deinit();
    try nav_map.put("url", u);

    if (prof.wait_for) |wf| {
        try nav_map.put("waitFor", wf);
        var tbuf2: [12]u8 = undefined;
        const ts2 = std.fmt.bufPrint(&tbuf2, "{d}", .{prof.wait_timeout_ms}) catch return http_result;
        try nav_map.put("timeout", ts2);
    }

    try nav_map.put("extract", "1");

    const html_val = be.execute(nav_map) catch return http_result;
    const html_s = html_val orelse return http_result;
    if (html_s != .string) return http_result;

    return article_pipeline.processHtmlArticle(allocator, cmd.name, u, html_s.string, out_dir, article_opts) catch http_result;
}
