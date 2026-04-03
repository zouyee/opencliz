//! 对齐旧版 Node `article-download` 的简化流水线：去 script/style → 标题 → 正文纯文本 → Markdown 文件（frontmatter）.
const std = @import("std");
const errors = @import("../core/errors.zig");
const http = @import("../http/client.zig");
const html_extract = @import("html_extract.zig");
const html_to_md_simple = @import("html_to_md_simple.zig");

const OpenCliError = errors.OpenCliError;

pub const ArticleOpts = struct {
    /// 若设置且 `OPENCLI_ARTICLE_DOWNLOAD_IMAGES=1` 且存在 `output_dir`，则从原始 HTML 中抓取 `http(s)` 图链并写入 `output_dir/article-images/`。
    http_client: ?*http.HttpClient = null,
};

fn envArticleImagesEnabled() bool {
    const v = std.posix.getenv("OPENCLI_ARTICLE_DOWNLOAD_IMAGES") orelse return false;
    return std.mem.eql(u8, v, "1");
}

fn envBuiltinHtmlToMd() bool {
    const v = std.posix.getenv("OPENCLI_BUILTIN_HTML_TO_MD") orelse return false;
    return std.mem.eql(u8, v, "1");
}

fn collectAbsoluteImageUrls(allocator: std.mem.Allocator, html: []const u8, max_n: usize) ![][]const u8 {
    var list = std.array_list.Managed([]const u8).init(allocator);
    errdefer {
        for (list.items) |u| allocator.free(u);
        list.deinit();
    }
    var i: usize = 0;
    while (i < html.len and list.items.len < max_n) {
        const needle = "src=\"";
        if (std.mem.indexOfPos(u8, html, i, needle)) |j| {
            const start = j + needle.len;
            const end_rel = std.mem.indexOfScalar(u8, html[start..], '"') orelse break;
            const raw = html[start .. start + end_rel];
            i = start + end_rel + 1;
            if (std.mem.startsWith(u8, raw, "http://") or std.mem.startsWith(u8, raw, "https://")) {
                try list.append(try allocator.dupe(u8, raw));
            }
        } else break;
    }
    return try list.toOwnedSlice();
}

fn extFromUrlOrDefault(u: []const u8) []const u8 {
    const base = if (std.mem.lastIndexOfScalar(u8, u, '?')) |q| u[0..q] else u;
    if (std.mem.lastIndexOfScalar(u8, base, '.')) |dot| {
        const e = base[dot + 1 ..];
        if (e.len > 0 and e.len <= 5) {
            for (e) |c| {
                if (!std.ascii.isAlphanumeric(c)) return "img";
            }
            return e;
        }
    }
    return "img";
}

/// 在 `output_dir/article-images/` 下拉图并在 Markdown 末尾追加图片引用（阶段 E）。
fn maybeAppendDownloadedImages(
    allocator: std.mem.Allocator,
    client: *http.HttpClient,
    page_url: []const u8,
    html: []const u8,
    output_dir: []const u8,
    md_in: []const u8,
) ![]u8 {
    _ = page_url;
    const urls = try collectAbsoluteImageUrls(allocator, html, 16);
    defer {
        for (urls) |u| allocator.free(u);
        allocator.free(urls);
    }
    if (urls.len == 0) return try allocator.dupe(u8, md_in);

    const img_dir = try std.fs.path.join(allocator, &.{ output_dir, "article-images" });
    defer allocator.free(img_dir);
    std.fs.cwd().makePath(img_dir) catch {};

    var extra = std.array_list.Managed(u8).init(allocator);
    defer extra.deinit();

    for (urls, 0..) |img_url, idx| {
        var resp = client.get(img_url) catch continue;
        defer {
            resp.headers.deinit();
            allocator.free(resp.body);
        }
        if (resp.status < 200 or resp.status >= 400) continue;
        if (resp.body.len == 0) continue;

        const ext = extFromUrlOrDefault(img_url);
        const fname = try std.fmt.allocPrint(allocator, "img_{d}.{s}", .{ idx, ext });
        defer allocator.free(fname);
        const fpath = try std.fs.path.join(allocator, &.{ img_dir, fname });
        defer allocator.free(fpath);

        var wf = std.fs.cwd().createFile(fpath, .{}) catch continue;
        wf.writeAll(resp.body) catch {
            wf.close();
            continue;
        };
        wf.close();

        try extra.appendSlice("\n\n![](");
        try extra.appendSlice("article-images/");
        try extra.appendSlice(fname);
        try extra.appendSlice(")\n");
    }

    if (extra.items.len == 0) return try allocator.dupe(u8, md_in);

    var out = std.array_list.Managed(u8).init(allocator);
    errdefer out.deinit();
    try out.appendSlice(md_in);
    try out.appendSlice(extra.items);
    return try out.toOwnedSlice();
}

/// 移除 `<script>` / `<style>` 块（大小写不敏感），减轻噪声与体积。
pub fn stripScriptAndStyle(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var out = std.array_list.Managed(u8).init(allocator);
    errdefer out.deinit();
    var i: usize = 0;
    while (i < input.len) {
        const rest = input[i..];
        if (std.ascii.startsWithIgnoreCase(rest, "<script")) {
            if (std.mem.indexOfPos(u8, input, i, "</script>")) |end_tag| {
                i = end_tag + "</script>".len;
                continue;
            }
        }
        if (std.ascii.startsWithIgnoreCase(rest, "<style")) {
            if (std.mem.indexOfPos(u8, input, i, "</style>")) |end_tag| {
                i = end_tag + "</style>".len;
                continue;
            }
        }
        try out.append(input[i]);
        i += 1;
    }
    return try out.toOwnedSlice();
}

/// 可选阶段 E：环境变量 `OPENCLI_HTML_TO_MD_SCRIPT` 指向可执行文件，参数为单一路径（写入 `.opencli/article-html-input.html` 的 HTML）；stdout 作为 Markdown 正文。
fn runHtmlToMdScript(allocator: std.mem.Allocator, html: []const u8) !?[]u8 {
    const script = std.process.getEnvVarOwned(allocator, "OPENCLI_HTML_TO_MD_SCRIPT") catch return null;
    defer allocator.free(script);
    if (script.len == 0) return null;

    try std.fs.cwd().makePath(".opencli");
    const in_path = ".opencli/article-html-input.html";
    {
        var f = try std.fs.cwd().createFile(in_path, .{});
        defer f.close();
        try f.writeAll(html);
    }

    const argv = [_][]const u8{ script, in_path };
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &argv,
        .max_output_bytes = 8 * 1024 * 1024,
    });
    defer allocator.free(result.stderr);
    if (result.term != .Exited or result.term.Exited != 0) {
        allocator.free(result.stdout);
        return null;
    }
    const trimmed = std.mem.trim(u8, result.stdout, " \t\r\n");
    const out = try allocator.dupe(u8, trimmed);
    allocator.free(result.stdout);
    return out;
}

fn sanitizeFilename(allocator: std.mem.Allocator, title: []const u8) ![]u8 {
    var b = std.array_list.Managed(u8).init(allocator);
    errdefer b.deinit();
    for (title) |c| {
        if (c == '/' or c == '\\' or c == ':' or c == '?' or c == '*' or c == '"' or c == '<' or c == '>' or c == '|')
            try b.append('_')
        else if (c < 32 or c == 127)
            continue
        else
            try b.append(c);
    }
    if (b.items.len > 120) b.shrinkRetainingCapacity(120);
    if (b.items.len == 0) try b.appendSlice("article");
    try b.appendSlice(".md");
    return try b.toOwnedSlice();
}

/// 由已得 HTML 构建与 `fetchPageArticle` 相同结构的 JSON，并可选写 Markdown 文件。
pub fn processHtmlArticle(
    allocator: std.mem.Allocator,
    action: []const u8,
    page_url: []const u8,
    html: []const u8,
    output_dir: ?[]const u8,
    opts: ArticleOpts,
) !std.json.Value {
    const cleaned = try stripScriptAndStyle(allocator, html);
    defer allocator.free(cleaned);

    const title = try html_extract.extractTitle(allocator, html);
    defer allocator.free(title);
    const body_txt = try html_extract.extractPlainTextExcerpt(allocator, cleaned, 500_000);
    defer allocator.free(body_txt);

    var body_for_md: []const u8 = body_txt;
    var body_from_script: ?[]const u8 = null;
    defer if (body_from_script) |b| allocator.free(b);
    if (try runHtmlToMdScript(allocator, cleaned)) |pipe_out| {
        body_from_script = pipe_out;
        body_for_md = pipe_out;
    } else if (envBuiltinHtmlToMd()) {
        const md_b = try html_to_md_simple.convert(allocator, cleaned);
        body_from_script = md_b;
        body_for_md = md_b;
    }

    const md = try std.fmt.allocPrint(
        allocator,
        "---\n原文链接: {s}\n---\n\n# {s}\n\n{s}\n",
        .{ page_url, title, body_for_md },
    );
    defer allocator.free(md);

    var md_final_owned: ?[]u8 = null;
    defer if (md_final_owned) |m| allocator.free(m);

    if (output_dir) |dir| {
        if (opts.http_client) |hc| {
            if (envArticleImagesEnabled()) {
                md_final_owned = try maybeAppendDownloadedImages(allocator, hc, page_url, html, dir, md);
            }
        }
    }
    const md_out = md_final_owned orelse md;

    var output_file_str: []const u8 = "";
    var output_owned: ?[]u8 = null;
    defer if (output_owned) |o| allocator.free(o);

    if (output_dir) |dir| {
        std.fs.cwd().makePath(dir) catch {};
        const fname = try sanitizeFilename(allocator, title);
        defer allocator.free(fname);
        const full = try std.fs.path.join(allocator, &.{ dir, fname });
        defer allocator.free(full);
        const f = try std.fs.cwd().createFile(full, .{});
        defer f.close();
        try f.writeAll(md_out);
        output_owned = try allocator.dupe(u8, full);
        output_file_str = output_owned.?;
    }

    const excerpt = try html_extract.extractPlainTextExcerpt(allocator, cleaned, 12_000);
    defer allocator.free(excerpt);

    const detail_raw = try std.fmt.allocPrint(allocator, "{s}\n{s}", .{ title, excerpt });
    defer allocator.free(detail_raw);

    const md_for_json = try allocator.dupe(u8, md_out);
    errdefer allocator.free(md_for_json);

    var obj = std.json.ObjectMap.init(allocator);
    try obj.put("action", .{ .string = try allocator.dupe(u8, action) });
    try obj.put("status", .{ .string = try allocator.dupe(u8, "ok") });
    try obj.put("detail", .{ .string = try allocator.dupe(u8, detail_raw) });
    try obj.put("title", .{ .string = try allocator.dupe(u8, title) });
    try obj.put("excerpt", .{ .string = try allocator.dupe(u8, excerpt) });
    try obj.put("markdown", .{ .string = md_for_json });
    try obj.put("url", .{ .string = try allocator.dupe(u8, page_url) });
    try obj.put("output_file", .{ .string = try allocator.dupe(u8, output_file_str) });
    return std.json.Value{ .object = obj };
}

/// GET 页面后走文章流水线（对齐 web/read、weixin/download 等）。
pub fn fetchPageArticle(
    allocator: std.mem.Allocator,
    client: *http.HttpClient,
    action: []const u8,
    page_url: []const u8,
    output_dir: ?[]const u8,
) !std.json.Value {
    var response = try client.get(page_url);
    defer response.headers.deinit();
    if (response.status < 200 or response.status >= 400) {
        allocator.free(response.body);
        return OpenCliError.HttpError;
    }
    defer allocator.free(response.body);
    return processHtmlArticle(allocator, action, page_url, response.body, output_dir, .{ .http_client = client });
}

test "stripScriptAndStyle removes script and style" {
    const a = std.testing.allocator;
    const html = "<html><script>x</script><p>ok</p><style>a{}</style>tail</html>";
    const out = try stripScriptAndStyle(a, html);
    defer a.free(out);
    try std.testing.expect(std.mem.indexOf(u8, out, "script") == null);
    try std.testing.expect(std.mem.indexOf(u8, out, "style") == null);
    try std.testing.expect(std.mem.indexOf(u8, out, "ok") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "tail") != null);
}
