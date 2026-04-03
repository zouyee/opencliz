const std = @import("std");

fn envPageOwned(key: []const u8) ?[]u8 {
    return std.process.getEnvVarOwned(std.heap.page_allocator, key) catch null;
}

/// 是否跟随 HTTP 重定向（curl `-L`）。`OPENCLI_HTTP_FOLLOW_REDIRECTS=0` 关闭；默认开启。
pub fn httpFollowRedirectsFromEnv() bool {
    const e = envPageOwned("OPENCLI_HTTP_FOLLOW_REDIRECTS") orelse return true;
    defer std.heap.page_allocator.free(e);
    return !std.mem.eql(u8, std.mem.trim(u8, e, " \t"), "0");
}

/// `curl --max-redirs`；仅在跟随重定向时生效；默认 `10`。
pub fn httpMaxRedirectsFromEnv() u32 {
    const e = envPageOwned("OPENCLI_HTTP_MAX_REDIRECTS") orelse return 10;
    defer std.heap.page_allocator.free(e);
    if (e.len == 0) return 10;
    return std.fmt.parseInt(u32, e, 10) catch 10;
}

/// `Child.run` 的 `max_output_bytes`；默认 `20971520`（20 MiB）。
pub fn httpMaxOutputBytesFromEnv() usize {
    const e = envPageOwned("OPENCLI_HTTP_MAX_OUTPUT_BYTES") orelse return 20 * 1024 * 1024;
    defer std.heap.page_allocator.free(e);
    if (e.len == 0) return 20 * 1024 * 1024;
    return std.fmt.parseInt(usize, e, 10) catch 20 * 1024 * 1024;
}

/// 将 URL host（已小写）映射到适配器 `site` 字段，用于查找 `OPENCLI_<SITE>_COOKIE`。
fn hostToSiteKey(host: []const u8) ?[]const u8 {
    if (std.mem.endsWith(u8, host, "app.cj.sina.com.cn")) return "sinafinance";
    if (std.mem.endsWith(u8, host, "finance.sina.com.cn")) return "sinafinance";
    if (std.mem.endsWith(u8, host, "sina.com.cn")) return "sinablog";
    if (std.mem.endsWith(u8, host, "b23.tv")) return "bilibili";
    if (std.mem.endsWith(u8, host, "bilibili.com")) return "bilibili";
    if (std.mem.endsWith(u8, host, "zhihu.com")) return "zhihu";
    if (std.mem.endsWith(u8, host, "weibo.com") or std.mem.endsWith(u8, host, "weibo.cn")) return "weibo";
    if (std.mem.endsWith(u8, host, "douban.com")) return "douban";
    if (std.mem.endsWith(u8, host, "reddit.com")) return "reddit";
    if (std.mem.endsWith(u8, host, "jd.com") or std.mem.endsWith(u8, host, "jd.hk")) return "jd";
    if (std.mem.endsWith(u8, host, "okjike.com")) return "jike";
    if (std.mem.endsWith(u8, host, "xiaohongshu.com")) return "xiaohongshu";
    if (std.mem.endsWith(u8, host, "douyin.com")) return "douyin";
    if (std.mem.endsWith(u8, host, "pixiv.net")) return "pixiv";
    if (std.mem.endsWith(u8, host, "smzdm.com")) return "smzdm";
    if (std.mem.endsWith(u8, host, "stackoverflow.com")) return "stackoverflow";
    if (std.mem.endsWith(u8, host, "stackexchange.com")) return "stackoverflow";
    if (std.mem.endsWith(u8, host, "registry.npmjs.org")) return "npm";
    if (std.mem.endsWith(u8, host, "api.npmjs.org")) return "npm";
    if (std.mem.endsWith(u8, host, "npmjs.org")) return "npm";
    if (std.mem.endsWith(u8, host, "juejin.cn")) return "juejin";
    if (std.mem.endsWith(u8, host, "producthunt.com")) return "producthunt";
    if (std.mem.endsWith(u8, host, "unsplash.com")) return "unsplash";
    if (std.mem.endsWith(u8, host, "hn.algolia.com")) return "hackernews";
    if (std.mem.endsWith(u8, host, "noembed.com")) return "youtube";
    if (std.mem.endsWith(u8, host, "twitter.com") or std.mem.endsWith(u8, host, "x.com")) return "twitter";
    if (std.mem.endsWith(u8, host, "youtube.com") or std.mem.endsWith(u8, host, "youtu.be")) return "youtube";
    if (std.mem.endsWith(u8, host, "linkedin.com")) return "linkedin";
    if (std.mem.endsWith(u8, host, "instagram.com")) return "instagram";
    if (std.mem.endsWith(u8, host, "facebook.com")) return "facebook";
    if (std.mem.endsWith(u8, host, "news.google.com")) return "google";
    if (std.mem.endsWith(u8, host, "suggestqueries.google.com")) return "google";
    if (std.mem.endsWith(u8, host, "trends.google.com")) return "google";
    if (std.mem.endsWith(u8, host, "google.com")) return "google";
    if (std.mem.endsWith(u8, host, "wikipedia.org")) return "wikipedia";
    if (std.mem.endsWith(u8, host, "wikimedia.org")) return "wikipedia";
    if (std.mem.endsWith(u8, host, "substack.com")) return "substack";
    if (std.mem.endsWith(u8, host, "medium.com")) return "medium";
    if (std.mem.endsWith(u8, host, "finance.yahoo.com")) return "yahoo-finance";
    if (std.mem.endsWith(u8, host, "yahoo.com")) return "yahoo-finance";
    if (std.mem.endsWith(u8, host, "dictionaryapi.dev")) return "dictionary";
    if (std.mem.endsWith(u8, host, "podcasts.apple.com")) return "apple-podcasts";
    if (std.mem.endsWith(u8, host, "zhipin.com")) return "boss";
    if (std.mem.endsWith(u8, host, "notion.so")) return "notion";
    if (std.mem.endsWith(u8, host, "discord.com")) return "discord-app";
    if (std.mem.endsWith(u8, host, "yollomi.com")) return "yollomi";
    if (std.mem.endsWith(u8, host, "cursor.com")) return "cursor";
    if (std.mem.endsWith(u8, host, "dev.to")) return "devto";
    if (std.mem.endsWith(u8, host, "news.ycombinator.com")) return "hackernews";
    if (std.mem.endsWith(u8, host, "v2ex.com")) return "v2ex";
    if (std.mem.endsWith(u8, host, "ctrip.com")) return "ctrip";
    if (std.mem.endsWith(u8, host, "coupang.com")) return "coupang";
    if (std.mem.endsWith(u8, host, "github.com") or std.mem.endsWith(u8, host, "api.github.com")) return "github";
    if (std.mem.endsWith(u8, host, "weread.qq.com")) return "weread";
    if (std.mem.endsWith(u8, host, "xiaoyuzhoufm.com")) return "xiaoyuzhou";
    if (std.mem.endsWith(u8, host, "bloomberg.com")) return "bloomberg";
    if (std.mem.endsWith(u8, host, "reuters.com")) return "reuters";
    if (std.mem.endsWith(u8, host, "bbc.com") or std.mem.endsWith(u8, host, "bbc.co.uk")) return "bbc";
    if (std.mem.endsWith(u8, host, "chaoxing.com") or std.mem.endsWith(u8, host, "chaoxing.cn")) return "chaoxing";
    if (std.mem.endsWith(u8, host, "huggingface.co")) return "hf";
    if (std.mem.endsWith(u8, host, "arxiv.org")) return "arxiv";
    if (std.mem.endsWith(u8, host, "npmjs.com")) return "npm";
    if (std.mem.endsWith(u8, host, "pypi.org")) return "pypi";
    if (std.mem.endsWith(u8, host, "crates.io")) return "crates";
    if (std.mem.endsWith(u8, host, "barchart.com")) return "barchart";
    if (std.mem.endsWith(u8, host, "xueqiu.com")) return "xueqiu";
    if (std.mem.endsWith(u8, host, "mp.weixin.qq.com")) return "weixin";
    if (std.mem.endsWith(u8, host, "doubao.com")) return "doubao";
    if (std.mem.endsWith(u8, host, "grok.com")) return "grok";
    if (std.mem.endsWith(u8, host, "openai.com")) return "chatgpt";
    if (std.mem.endsWith(u8, host, "nitter.net")) return "twitter";
    if (std.mem.endsWith(u8, host, "firebaseio.com")) return "hackernews";
    return null;
}

fn siteCookieEnvKey(site: []const u8, buf: *[160]u8) ?[]const u8 {
    const prefix = "OPENCLI_";
    const suffix = "_COOKIE";
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

/// HTTP客户端
pub const HttpClient = struct {
    allocator: std.mem.Allocator,
    client: std.http.Client,
    headers: std.StringHashMap([]const u8),
    cookie_jar: CookieJar,
    timeout_ms: u32 = 30000,
    
    pub fn init(allocator: std.mem.Allocator) !HttpClient {
        return HttpClient{
            .allocator = allocator,
            .client = std.http.Client{ .allocator = allocator },
            .headers = std.StringHashMap([]const u8).init(allocator),
            .cookie_jar = try CookieJar.init(allocator),
        };
    }
    
    pub fn deinit(self: *HttpClient) void {
        self.headers.deinit();
        self.cookie_jar.deinit();
        self.client.deinit();
    }
    
    /// 设置默认请求头
    pub fn setDefaultHeaders(self: *HttpClient) !void {
        try self.headers.put("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36");
        try self.headers.put("Accept", "application/json, text/plain, */*");
        try self.headers.put("Accept-Language", "zh-CN,zh;q=0.9,en;q=0.8");
        try self.headers.put("Connection", "keep-alive");
    }

    fn putCookieHeader(self: *HttpClient, value: []const u8) !void {
        if (self.headers.fetchRemove("Cookie")) |kv| {
            self.allocator.free(kv.value);
        }
        const dup = try self.allocator.dupe(u8, value);
        try self.headers.put("Cookie", dup);
    }

    /// 从环境注入 Cookie（阶段 C / 迁移方案）：`OPENCLI_COOKIE_FILE` 先读首行；`OPENCLI_COOKIE` 后设置（可覆盖文件）。
    pub fn applyCookieFromEnv(self: *HttpClient) !void {
        if (std.process.getEnvVarOwned(self.allocator, "OPENCLI_COOKIE_FILE")) |path| {
            defer self.allocator.free(path);
            var file = try std.fs.cwd().openFile(path, .{});
            defer file.close();
            const max: usize = 64 * 1024;
            const contents = try file.readToEndAlloc(self.allocator, max);
            defer self.allocator.free(contents);
            var line: []const u8 = contents;
            if (std.mem.indexOfScalar(u8, contents, '\n')) |nl| {
                line = std.mem.trim(u8, contents[0..nl], " \t\r");
            } else {
                line = std.mem.trim(u8, contents, " \t\r\n");
            }
            if (line.len > 0) {
                try self.putCookieHeader(line);
            }
        } else |_| {}

        if (std.process.getEnvVarOwned(self.allocator, "OPENCLI_COOKIE")) |raw| {
            defer self.allocator.free(raw);
            try self.putCookieHeader(std.mem.trim(u8, raw, " \t\r\n"));
        } else |_| {}
    }

    /// 按站点覆盖 Cookie：`OPENCLI_<SITE>_COOKIE`，其中 `<SITE>` 为大写且 `-` 换成 `_`（如 `OPENCLI_BILIBILI_COOKIE`）。
    pub fn applySiteCookieFromEnv(self: *HttpClient, site: []const u8) !void {
        var key_buf: [160]u8 = undefined;
        if (siteCookieEnvKey(site, &key_buf)) |key| {
            if (std.process.getEnvVarOwned(self.allocator, key)) |raw| {
                defer self.allocator.free(raw);
                try self.putCookieHeader(std.mem.trim(u8, raw, " \t\r\n"));
            } else |_| {}
        }
    }

    /// 从绝对 URL 解析 host，映射到 `opencli` 站点名后调用 `applySiteCookieFromEnv`（供 YAML `fetch`/`download` 与 adapter 行为对齐）。
    pub fn applySiteCookieFromUrl(self: *HttpClient, url: []const u8) !void {
        const u = std.Uri.parse(url) catch return;
        var host_buf: [std.Uri.host_name_max]u8 = undefined;
        const host = u.getHost(&host_buf) catch return;
        var lc_buf: [std.Uri.host_name_max]u8 = undefined;
        if (host.len > lc_buf.len) return;
        for (host, 0..) |c, i| lc_buf[i] = std.ascii.toLower(c);
        const h = lc_buf[0..host.len];
        const site = hostToSiteKey(h) orelse return;
        try self.applySiteCookieFromEnv(site);
    }
    
    /// GET请求（会按 URL host 注入 `OPENCLI_<SITE>_COOKIE` 等，与 `request` 一致）
    pub fn get(self: *HttpClient, url: []const u8) !HttpResponse {
        return self.request(.GET, url, null, null, true);
    }

    /// GET 且不调用 `applySiteCookieFromUrl`（供 cascade 等做「纯公开」探测；仍带当前 `headers` 里已有 Cookie）
    pub fn getWithoutSiteCookieFromUrl(self: *HttpClient, url: []const u8) !HttpResponse {
        return self.request(.GET, url, null, null, false);
    }
    
    /// POST请求
    pub fn post(self: *HttpClient, url: []const u8, body: ?[]const u8, content_type: ?[]const u8) !HttpResponse {
        return self.request(.POST, url, body, content_type, true);
    }

    /// HEAD 请求（curl **`-I`**；`body` 为响应头文本块，非实体 body）。
    pub fn head(self: *HttpClient, url: []const u8) !HttpResponse {
        return self.request(.HEAD, url, null, null, true);
    }
    
    /// 通用HTTP请求；`apply_site_cookie_from_url` 为 false 时不按 URL 映射注入站点 Cookie（cascade 公开探测用）
    fn request(
        self: *HttpClient,
        method: std.http.Method,
        url: []const u8,
        body: ?[]const u8,
        content_type: ?[]const u8,
        apply_site_cookie_from_url: bool,
    ) !HttpResponse {
        if (apply_site_cookie_from_url) {
            try self.applySiteCookieFromUrl(url);
        }

        // 使用 curl 作为后端，规避 Zig 不同版本 std.http API 差异。
        var argv: std.ArrayList([]const u8) = .empty;
        defer argv.deinit(self.allocator);

        var owned: std.ArrayList([]u8) = .empty;
        defer {
            for (owned.items) |x| self.allocator.free(x);
            owned.deinit(self.allocator);
        }

        try argv.append(self.allocator, "curl");
        try argv.append(self.allocator, "-sS");
        if (httpFollowRedirectsFromEnv()) {
            try argv.append(self.allocator, "-L");
            const mr = httpMaxRedirectsFromEnv();
            const mr_s = try std.fmt.allocPrint(self.allocator, "{d}", .{mr});
            try owned.append(self.allocator, mr_s);
            try argv.append(self.allocator, "--max-redirs");
            try argv.append(self.allocator, mr_s);
        }
        if (method == .HEAD) {
            try argv.append(self.allocator, "-I");
        } else {
            try argv.append(self.allocator, "-X");
            try argv.append(self.allocator, @tagName(method));
        }

        var it = self.headers.iterator();
        while (it.next()) |entry| {
            const h = try std.fmt.allocPrint(self.allocator, "{s}: {s}", .{ entry.key_ptr.*, entry.value_ptr.* });
            try owned.append(self.allocator, h);
            try argv.append(self.allocator, "-H");
            try argv.append(self.allocator, h);
        }

        if (method != .HEAD) {
            if (content_type) |ct| {
                const h = try std.fmt.allocPrint(self.allocator, "Content-Type: {s}", .{ct});
                try owned.append(self.allocator, h);
                try argv.append(self.allocator, "-H");
                try argv.append(self.allocator, h);
            }

            if (body) |b| {
                try argv.append(self.allocator, "--data-binary");
                try argv.append(self.allocator, b);
            }
        }

        try argv.append(self.allocator, "-w");
        try argv.append(self.allocator, "\n__OPENCLI_STATUS__:%{http_code}");
        try argv.append(self.allocator, url);

        const result = try std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = argv.items,
            .max_output_bytes = httpMaxOutputBytesFromEnv(),
        });
        defer self.allocator.free(result.stderr);

        var response_headers = std.StringHashMap([]const u8).init(self.allocator);

        const marker = "\n__OPENCLI_STATUS__:";
        const idx_opt = std.mem.lastIndexOf(u8, result.stdout, marker);
        if (idx_opt == null) {
            // 没拿到状态行，按 curl 失败处理。
            self.allocator.free(result.stdout);
            response_headers.deinit();
            return error.HttpError;
        }

        const idx = idx_opt.?;
        const body_content = try self.allocator.dupe(u8, result.stdout[0..idx]);
        const status_str = result.stdout[idx + marker.len ..];
        const status = std.fmt.parseInt(u16, std.mem.trim(u8, status_str, "\r\n "), 10) catch 0;
        self.allocator.free(result.stdout);

        return HttpResponse{
            .status = status,
            .headers = response_headers,
            .body = body_content,
        };
    }
    
    /// 下载文件
    pub fn download(self: *HttpClient, url: []const u8, output_path: []const u8) !void {
        var response = try self.get(url);
        defer {
            response.headers.deinit();
            self.allocator.free(response.body);
        }
        
        if (response.status < 200 or response.status >= 300) {
            return error.HttpError;
        }
        
        const file = try std.fs.cwd().createFile(output_path, .{});
        defer file.close();
        
        try file.writeAll(response.body);
    }
};

/// Cookie管理器
const CookieJar = struct {
    allocator: std.mem.Allocator,
    cookies: std.StringHashMap(std.StringHashMap([]const u8)),
    
    fn init(allocator: std.mem.Allocator) !CookieJar {
        return CookieJar{
            .allocator = allocator,
            .cookies = std.StringHashMap(std.StringHashMap([]const u8)).init(allocator),
        };
    }
    
    fn deinit(self: *CookieJar) void {
        var it = self.cookies.valueIterator();
        while (it.next()) |domain_cookies| {
            domain_cookies.deinit();
        }
        self.cookies.deinit();
    }
};

/// HTTP响应
pub const HttpResponse = struct {
    status: u16,
    headers: std.StringHashMap([]const u8),
    body: []const u8,
};

/// 守护进程等使用的极简 HTTP 请求/响应视图（由字节解析得到）
pub const Request = struct {
    method: []const u8,
    path: []const u8,
    query: ?[]const u8,
    body: ?[]const u8,
    /// `Authorization: Bearer …` 的 token 段（指向原始请求缓冲）
    authorization_bearer: ?[]const u8 = null,
    /// `X-OpenCLI-Token: …`（指向原始请求缓冲）
    header_opencli_token: ?[]const u8 = null,
    /// 原始 `Content-Type` 头值（小写比较用，指向原始请求缓冲）
    content_type: ?[]const u8 = null,
};

pub const Response = struct {
    status: u16,
    body: []const u8,
    content_type: []const u8 = "application/json",
    /// 为 true 时 `body` 由堆分配，发送后应 `allocator.free(body)`
    body_owned: bool = false,
};