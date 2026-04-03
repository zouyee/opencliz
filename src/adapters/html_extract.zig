const std = @import("std");
const errors = @import("../core/errors.zig");
const http = @import("../http/client.zig");

const OpenCliError = errors.OpenCliError;

/// 从 HTML 中取 `<title>...</title>` 内文本（简单扫描，不做完整解析）。
pub fn extractTitle(allocator: std.mem.Allocator, html: []const u8) ![]u8 {
    const t = std.mem.indexOf(u8, html, "<title") orelse return try allocator.dupe(u8, "");
    const gt = std.mem.indexOfScalarPos(u8, html, t, '>') orelse return try allocator.dupe(u8, "");
    const start = gt + 1;
    const end = std.mem.indexOfPos(u8, html, start, "</title>") orelse return try allocator.dupe(u8, "");
    return try allocator.dupe(u8, std.mem.trim(u8, html[start..end], " \t\r\n"));
}

/// 去掉标签后的可见文本（空白折叠）；`max_out` 控制上限，供摘要或长文导出共用。
pub fn extractPlainTextExcerpt(allocator: std.mem.Allocator, html: []const u8, max_out: usize) ![]u8 {
    var buf = std.array_list.Managed(u8).init(allocator);
    errdefer buf.deinit();
    var i: usize = 0;
    var in_tag = false;
    while (i < html.len and buf.items.len < max_out) {
        const c = html[i];
        if (c == '<') {
            in_tag = true;
            i += 1;
            continue;
        }
        if (in_tag) {
            if (c == '>') in_tag = false;
            i += 1;
            continue;
        }
        if (std.ascii.isWhitespace(c)) {
            if (buf.items.len > 0 and buf.items[buf.items.len - 1] != ' ')
                try buf.append(' ');
        } else {
            try buf.append(c);
        }
        i += 1;
    }
    return try buf.toOwnedSlice();
}

/// GET URL，返回 action/status/detail + title/excerpt（表格列仍为 action/status/detail 时可用 `-f json` 看全文）。
pub fn fetchPageSummary(
    allocator: std.mem.Allocator,
    client: *http.HttpClient,
    action: []const u8,
    page_url: []const u8,
) !std.json.Value {
    var response = try client.get(page_url);
    defer response.headers.deinit();
    if (response.status < 200 or response.status >= 400) {
        allocator.free(response.body);
        return OpenCliError.HttpError;
    }

    const title = try extractTitle(allocator, response.body);
    defer allocator.free(title);
    const excerpt = try extractPlainTextExcerpt(allocator, response.body, 12_000);
    defer allocator.free(excerpt);
    allocator.free(response.body);

    const detail_raw = try std.fmt.allocPrint(allocator, "{s}\n{s}", .{ title, excerpt });
    defer allocator.free(detail_raw);

    var obj = std.json.ObjectMap.init(allocator);
    try obj.put("action", .{ .string = try allocator.dupe(u8, action) });
    try obj.put("status", .{ .string = try allocator.dupe(u8, "ok") });
    try obj.put("detail", .{ .string = try allocator.dupe(u8, detail_raw) });
    try obj.put("title", .{ .string = try allocator.dupe(u8, title) });
    try obj.put("excerpt", .{ .string = try allocator.dupe(u8, excerpt) });
    try obj.put("url", .{ .string = try allocator.dupe(u8, page_url) });
    return std.json.Value{ .object = obj };
}
