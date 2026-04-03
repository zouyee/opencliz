//! 对已知站点或 `--url` 做 HTTP 探测：按 **public → cookie → header** 顺序尝试，推荐最弱且成功的策略。
const std = @import("std");
const types = @import("../core/types.zig");
const http = @import("../http/client.zig");

fn siteTokenEnvKey(site: []const u8, buf: *[160]u8) ?[]const u8 {
    const prefix = "OPENCLI_";
    const suffix = "_TOKEN";
    if (prefix.len + site.len + suffix.len > buf.len) return null;
    var o: usize = 0;
    @memcpy(buf[o .. o + prefix.len], prefix);
    o += prefix.len;
    for (site) |c| {
        if (o + suffix.len > buf.len) return null;
        buf[o] = if (c == '-') '_' else std.ascii.toUpper(c);
        o += 1;
    }
    if (o + suffix.len > buf.len) return null;
    @memcpy(buf[o .. o + suffix.len], suffix);
    o += suffix.len;
    return buf[0..o];
}

/// 返回 **堆分配** 的 Bearer token，调用方 `free`；无则返回 null
fn bearerTokenForSite(allocator: std.mem.Allocator, site: []const u8) ?[]u8 {
    var key_buf: [160]u8 = undefined;
    if (siteTokenEnvKey(site, &key_buf)) |key| {
        if (std.process.getEnvVarOwned(allocator, key)) |v| {
            return v;
        } else |_| {}
    }
    if (std.mem.eql(u8, site, "github")) {
        if (std.process.getEnvVarOwned(allocator, "GITHUB_TOKEN")) |v| return v else |_| {}
    }
    if (std.process.getEnvVarOwned(allocator, "OPENCLI_BEARER_TOKEN")) |v| return v else |_| {}
    return null;
}

/// 内置若干公开读探针 URL（均为 GET）；未知站点须 `cascade --site x --url https://...`
fn defaultProbeUrl(site: []const u8) ?[]const u8 {
    const T = struct { []const u8, []const u8 };
    const rows: []const T = &.{
        .{ "github", "https://api.github.com/zen" },
        .{ "hackernews", "https://hacker-news.firebaseio.com/v0/maxitem.json" },
        .{ "v2ex", "https://www.v2ex.com/api/topics/hot.json" },
        .{ "npm", "https://registry.npmjs.org/-/v1/search?text=opencli&size=1" },
        .{ "pypi", "https://pypi.org/pypi/pip/json" },
        .{ "crates", "https://crates.io/api/v1/crates/serde" },
        .{ "stackoverflow", "https://api.stackexchange.com/2.3/questions?pagesize=1&order=desc&sort=activity&site=stackoverflow" },
        .{ "reddit", "https://www.reddit.com/r/rust/hot.json?limit=1" },
    };
    for (rows) |row| {
        if (std.mem.eql(u8, site, row[0])) return row[1];
    }
    return null;
}

fn probeOk(status: u16, body_len: usize) bool {
    return status >= 200 and status < 300 and body_len > 0;
}

const ProbeOutcome = struct { ok: bool, status: u16, body_len: usize };

fn tryPublic(allocator: std.mem.Allocator, url: []const u8) !ProbeOutcome {
    var client = try http.HttpClient.init(allocator);
    defer client.deinit();
    try client.setDefaultHeaders();
    var resp = try client.getWithoutSiteCookieFromUrl(url);
    defer {
        resp.headers.deinit();
        allocator.free(resp.body);
    }
    return .{ .ok = probeOk(resp.status, resp.body.len), .status = resp.status, .body_len = resp.body.len };
}

fn tryCookie(allocator: std.mem.Allocator, site: []const u8, url: []const u8) !ProbeOutcome {
    var client = try http.HttpClient.init(allocator);
    defer client.deinit();
    try client.setDefaultHeaders();
    try client.applyCookieFromEnv();
    try client.applySiteCookieFromEnv(site);
    var resp = try client.getWithoutSiteCookieFromUrl(url);
    defer {
        resp.headers.deinit();
        allocator.free(resp.body);
    }
    return .{ .ok = probeOk(resp.status, resp.body.len), .status = resp.status, .body_len = resp.body.len };
}

fn tryHeader(allocator: std.mem.Allocator, url: []const u8, token: []const u8) !ProbeOutcome {
    var client = try http.HttpClient.init(allocator);
    defer client.deinit();
    try client.setDefaultHeaders();
    const auth_val = try std.fmt.allocPrint(allocator, "Bearer {s}", .{token});
    defer allocator.free(auth_val);
    const auth_key = try allocator.dupe(u8, "Authorization");
    defer allocator.free(auth_key);
    try client.headers.put(auth_key, auth_val);
    var resp = try client.getWithoutSiteCookieFromUrl(url);
    defer {
        resp.headers.deinit();
        allocator.free(resp.body);
    }
    return .{ .ok = probeOk(resp.status, resp.body.len), .status = resp.status, .body_len = resp.body.len };
}

pub fn runCascade(allocator: std.mem.Allocator, site: []const u8, probe_url_override: ?[]const u8, stdout: anytype) !void {
    const url_owned: []const u8 = blk: {
        if (probe_url_override) |u| break :blk try allocator.dupe(u8, u);
        if (defaultProbeUrl(site)) |u| break :blk try allocator.dupe(u8, u);
        return error.CascadeNeedsUrl;
    };
    defer allocator.free(url_owned);

    try stdout.print("Cascade probe URL: {s}\n\n", .{url_owned});

    const pub_r = try tryPublic(allocator, url_owned);
    try stdout.print("public:  status={d} body_len={d} -> {s}\n", .{ pub_r.status, pub_r.body_len, if (pub_r.ok) "OK" else "no" });

    const cookie_r = try tryCookie(allocator, site, url_owned);
    try stdout.print("cookie:  status={d} body_len={d} -> {s}\n", .{ cookie_r.status, cookie_r.body_len, if (cookie_r.ok) "OK" else "no" });

    var header_r: ProbeOutcome = .{ .ok = false, .status = 0, .body_len = 0 };
    if (bearerTokenForSite(allocator, site)) |tok| {
        defer allocator.free(tok);
        header_r = try tryHeader(allocator, url_owned, tok);
        try stdout.print("header:  status={d} body_len={d} -> {s}\n", .{ header_r.status, header_r.body_len, if (header_r.ok) "OK" else "no" });
    } else {
        try stdout.print("header:  (no OPENCLI_<SITE>_TOKEN / GITHUB_TOKEN / OPENCLI_BEARER_TOKEN) -> skipped\n", .{});
    }

    // 推荐：能公开则公开，否则 cookie，再否则 header（与产品「逐级加码」一致）
    const rec: types.AuthStrategy = if (pub_r.ok)
        .public
    else if (cookie_r.ok)
        .cookie
    else if (header_r.ok)
        .header
    else
        .public;

    try stdout.print("\nRecommended strategy: {s}\n", .{rec.label()});
    try stdout.print("Hint: set OPENCLI_<SITE>_COOKIE or OPENCLI_<SITE>_TOKEN / GITHUB_TOKEN as needed; YAML `strategy` 可与上面对齐。\n", .{});
}
