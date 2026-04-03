const std = @import("std");
const types = @import("../core/types.zig");
const http = @import("../http/client.zig");

/// API端点信息
pub const ApiEndpoint = struct {
    method: []const u8,
    url: []const u8,
    params: std.StringHashMap([]const u8),
    auth_type: AuthType,
    
    pub const AuthType = enum {
        none,
        cookie,
        header,
        query,
    };
};

/// 探索结果
pub const ExploreResult = struct {
    allocator: std.mem.Allocator,
    url: []const u8,
    title: []const u8,
    api_endpoints: std.array_list.Managed(ApiEndpoint),
    data_stores: std.array_list.Managed(DataStore),
    recommended_strategy: types.AuthStrategy,
    
    pub const DataStore = struct {
        name: []const u8,
        type: []const u8, // localStorage, sessionStorage, cookie, etc.
        keys: std.array_list.Managed([]const u8),
    };
    
    pub fn init(allocator: std.mem.Allocator, url: []const u8) !ExploreResult {
        return ExploreResult{
            .allocator = allocator,
            .url = try allocator.dupe(u8, url),
            .title = "",
            .api_endpoints = std.array_list.Managed(ApiEndpoint).init(allocator),
            .data_stores = std.array_list.Managed(DataStore).init(allocator),
            .recommended_strategy = .public,
        };
    }
    
    pub fn deinit(self: *ExploreResult) void {
        self.allocator.free(self.url);
        if (self.title.len > 0) self.allocator.free(self.title);
        
        for (self.api_endpoints.items) |*endpoint| {
            endpoint.params.deinit();
        }
        self.api_endpoints.deinit();
        
        for (self.data_stores.items) |*store| {
            for (store.keys.items) |key| {
                self.allocator.free(key);
            }
            store.keys.deinit();
        }
        self.data_stores.deinit();
    }
};

/// `~/.opencli/clis` 绝对路径（用于 generate / synthesize 落盘，避免字面值 `~` 在当前目录建目录）
pub fn opencliUserClisDir(allocator: std.mem.Allocator) ![]u8 {
    const home = std.process.getEnvVarOwned(allocator, "HOME") catch return error.NoHomeDir;
    defer allocator.free(home);
    return try std.fs.path.join(allocator, &.{ home, ".opencli", "clis" });
}

/// 从页面 URL 得到 origin（`https://host` 或带端口），供相对 API 路径拼接
pub fn pageOriginFromUrl(allocator: std.mem.Allocator, page_url: []const u8) ![]u8 {
    const sep = std.mem.indexOf(u8, page_url, "://") orelse return try allocator.dupe(u8, page_url);
    const after = page_url[sep + 3 ..];
    const path_or_end = std.mem.indexOfScalar(u8, after, '/') orelse after.len;
    return try std.fmt.allocPrint(allocator, "{s}{s}", .{ page_url[0 .. sep + 3], after[0..path_or_end] });
}

/// 将探索得到的相对路径或绝对 URL 转为 `fetch` 可用的绝对 URL
pub fn resolveAbsoluteFetchUrl(allocator: std.mem.Allocator, page_url: []const u8, path_or_url: []const u8) ![]u8 {
    const t = std.mem.trim(u8, path_or_url, " \t\r\n");
    if (t.len == 0) return try allocator.dupe(u8, page_url);
    if (std.mem.startsWith(u8, t, "http://") or std.mem.startsWith(u8, t, "https://"))
        return try allocator.dupe(u8, t);
    if (std.mem.startsWith(u8, t, "/")) {
        const origin = try pageOriginFromUrl(allocator, page_url);
        defer allocator.free(origin);
        return try std.fmt.allocPrint(allocator, "{s}{s}", .{ origin, t });
    }
    const origin = try pageOriginFromUrl(allocator, page_url);
    defer allocator.free(origin);
    return try std.fmt.allocPrint(allocator, "{s}/{s}", .{ origin, t });
}

fn jsonEscapeString(allocator: std.mem.Allocator, s: []const u8) ![]u8 {
    var b = std.array_list.Managed(u8).init(allocator);
    errdefer b.deinit();
    try b.append('"');
    for (s) |c| {
        switch (c) {
            '\\' => try b.appendSlice("\\\\"),
            '"' => try b.appendSlice("\\\""),
            '\n' => try b.appendSlice("\\n"),
            '\r' => try b.appendSlice("\\r"),
            '\t' => try b.appendSlice("\\t"),
            else => try b.append(c),
        }
    }
    try b.append('"');
    return try b.toOwnedSlice();
}

/// 供 `--explore-out` / `synthesize --explore` 使用的 JSON（稳定字段）
pub fn exploreResultToJsonString(allocator: std.mem.Allocator, result: *const ExploreResult) ![]u8 {
    var list = std.array_list.Managed(u8).init(allocator);
    errdefer list.deinit();
    const w = list.writer();

    const ju = try jsonEscapeString(allocator, result.url);
    defer allocator.free(ju);
    const title_slice: []const u8 = if (result.title.len > 0) result.title else "";
    const jt = try jsonEscapeString(allocator, title_slice);
    defer allocator.free(jt);

    try w.writeAll("{\n");
    try w.print("  \"url\": {s},\n", .{ju});
    try w.print("  \"title\": {s},\n", .{jt});
    try w.print("  \"recommended_strategy\": \"{s}\",\n", .{result.recommended_strategy.label()});
    try w.writeAll("  \"api_endpoints\": [\n");
    for (result.api_endpoints.items, 0..) |ep, i| {
        const jm = try jsonEscapeString(allocator, ep.method);
        defer allocator.free(jm);
        const ju2 = try jsonEscapeString(allocator, ep.url);
        defer allocator.free(ju2);
        try w.writeAll("    { ");
        try w.print("\"method\": {s}, ", .{jm});
        try w.print("\"url\": {s}, ", .{ju2});
        try w.print("\"auth_type\": \"{s}\"", .{@tagName(ep.auth_type)});
        try w.writeAll(" }");
        if (i + 1 < result.api_endpoints.items.len) try w.writeAll(",");
        try w.writeAll("\n");
    }
    try w.writeAll("  ],\n");
    try w.writeAll("  \"data_stores\": [\n");
    for (result.data_stores.items, 0..) |ds, di| {
        try w.writeAll("    { \"name\": ");
        const jn = try jsonEscapeString(allocator, ds.name);
        defer allocator.free(jn);
        try w.print("{s}, ", .{jn});
        try w.writeAll("\"type\": ");
        const jty = try jsonEscapeString(allocator, ds.type);
        defer allocator.free(jty);
        try w.print("{s}, ", .{jty});
        try w.writeAll("\"keys\": [");
        for (ds.keys.items, 0..) |key, ki| {
            const jk = try jsonEscapeString(allocator, key);
            defer allocator.free(jk);
            try w.print("{s}", .{jk});
            if (ki + 1 < ds.keys.items.len) try w.writeAll(", ");
        }
        try w.writeAll("] }");
        if (di + 1 < result.data_stores.items.len) try w.writeAll(",");
        try w.writeAll("\n");
    }
    try w.writeAll("  ]\n}\n");
    return try list.toOwnedSlice();
}

fn authTypeFromJsonString(s: []const u8) ApiEndpoint.AuthType {
    if (std.mem.eql(u8, s, "cookie")) return .cookie;
    if (std.mem.eql(u8, s, "header")) return .header;
    if (std.mem.eql(u8, s, "query")) return .query;
    return .none;
}

/// 解析 `exploreResultToJsonString` 写出的 JSON（供 `synthesize` 使用）
pub fn exploreResultParseJson(allocator: std.mem.Allocator, json_slice: []const u8) !ExploreResult {
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_slice, .{});
    defer parsed.deinit();
    return try exploreResultFromJsonValue(allocator, parsed.value);
}

fn exploreResultFromJsonValue(allocator: std.mem.Allocator, root: std.json.Value) !ExploreResult {
    const o = switch (root) {
        .object => |m| m,
        else => return error.BadExploreJson,
    };
    const url_val = o.get("url") orelse return error.BadExploreJson;
    const url_str = switch (url_val) {
        .string => |s| s,
        else => return error.BadExploreJson,
    };

    var er = try ExploreResult.init(allocator, url_str);
    errdefer er.deinit();

    if (o.get("title")) |tv| {
        switch (tv) {
            .string => |s| {
                if (er.title.len > 0) allocator.free(er.title);
                er.title = try allocator.dupe(u8, s);
            },
            else => {},
        }
    }

    if (o.get("recommended_strategy")) |rv| {
        switch (rv) {
            .string => |s| er.recommended_strategy = types.AuthStrategy.fromString(s),
            else => {},
        }
    }

    if (o.get("api_endpoints")) |av| {
        switch (av) {
            .array => |arr| {
                for (arr.items) |item| {
                    const eo = switch (item) {
                        .object => |m| m,
                        else => continue,
                    };
                    const method_v = eo.get("method") orelse continue;
                    const url_v = eo.get("url") orelse continue;
                    const method = switch (method_v) {
                        .string => |s| try allocator.dupe(u8, s),
                        else => continue,
                    };
                    const ep_url = switch (url_v) {
                        .string => |s| try allocator.dupe(u8, s),
                        else => {
                            allocator.free(method);
                            continue;
                        },
                    };
                    var auth_t: ApiEndpoint.AuthType = .none;
                    if (eo.get("auth_type")) |atv| {
                        if (atv == .string) auth_t = authTypeFromJsonString(atv.string);
                    }
                    try er.api_endpoints.append(.{
                        .method = method,
                        .url = ep_url,
                        .params = std.StringHashMap([]const u8).init(allocator),
                        .auth_type = auth_t,
                    });
                }
            },
            else => {},
        }
    }

    if (o.get("data_stores")) |dv| {
        switch (dv) {
            .array => |arr| {
                for (arr.items) |item| {
                    const eo = switch (item) {
                        .object => |m| m,
                        else => continue,
                    };
                    const name_v = eo.get("name") orelse continue;
                    const type_v = eo.get("type") orelse continue;
                    const name_s = switch (name_v) {
                        .string => |s| try allocator.dupe(u8, s),
                        else => continue,
                    };
                    const type_s = switch (type_v) {
                        .string => |s| try allocator.dupe(u8, s),
                        else => {
                            allocator.free(name_s);
                            continue;
                        },
                    };
                    var keys = std.array_list.Managed([]const u8).init(allocator);
                    if (eo.get("keys")) |kv| {
                        if (kv == .array) {
                            for (kv.array.items) |ki| {
                                if (ki == .string) {
                                    try keys.append(try allocator.dupe(u8, ki.string));
                                }
                            }
                        }
                    }
                    try er.data_stores.append(.{
                        .name = name_s,
                        .type = type_s,
                        .keys = keys,
                    });
                }
            },
            else => {},
        }
    }

    return er;
}

/// 探索器 - 分析网站API
pub const Explorer = struct {
    allocator: std.mem.Allocator,
    http_client: http.HttpClient,
    
    pub fn init(allocator: std.mem.Allocator) !Explorer {
        var http_client = try http.HttpClient.init(allocator);
        try http_client.setDefaultHeaders();
        
        return Explorer{
            .allocator = allocator,
            .http_client = http_client,
        };
    }
    
    pub fn deinit(self: *Explorer) void {
        self.http_client.deinit();
    }
    
    /// 探索URL
    pub fn explore(self: *Explorer, url: []const u8, options: ExploreOptions) !ExploreResult {
        var response = try self.http_client.get(url);
        defer {
            response.headers.deinit();
            self.allocator.free(response.body);
        }

        if (response.status != 200) {
            return try ExploreResult.init(self.allocator, url);
        }
        return self.exploreFromHtml(url, response.body, options);
    }

    /// 对已取得的 HTML 做与 `explore` 相同的解析（无网络；供测试与 golden）。
    pub fn exploreFromHtml(self: *Explorer, url: []const u8, html: []const u8, options: ExploreOptions) !ExploreResult {
        _ = options;
        var result = try ExploreResult.init(self.allocator, url);
        result.title = try self.extractTitle(html);
        try self.analyzeApiEndpoints(&result, html);
        try self.analyzeDataStores(&result, html);
        result.recommended_strategy = try self.recommendStrategy(&result);
        return result;
    }
    
    /// 探索选项
    pub const ExploreOptions = struct {
        depth: u32 = 1,
        wait_seconds: u32 = 3,
        auto_fuzzing: bool = false,
    };
    
    /// 提取页面标题
    fn extractTitle(self: *Explorer, html: []const u8) ![]const u8 {
        const title_start = std.mem.indexOf(u8, html, "<title>");
        const title_end = std.mem.indexOf(u8, html, "</title>");
        
        if (title_start != null and title_end != null) {
            const start = title_start.? + 7;
            const end = title_end.?;
            if (end > start) {
                return try self.allocator.dupe(u8, html[start..end]);
            }
        }
        
        return try self.allocator.dupe(u8, "Unknown");
    }
    
    /// 分析API端点
    fn analyzeApiEndpoints(self: *Explorer, result: *ExploreResult, html: []const u8) !void {
        // 查找常见的API模式
        const api_patterns = &[_][]const u8{
            "/api/",
            "/v1/",
            "/v2/",
            "/graphql",
            "/rest/",
        };
        
        for (api_patterns) |pattern| {
            var pos: usize = 0;
            while (std.mem.indexOfPos(u8, html, pos, pattern)) |idx| {
                // 提取API路径
                const start = if (idx > 10) idx - 10 else 0;
                const end = @min(idx + 50, html.len);
                const context = html[start..end];
                
                // 查找引号内的URL
                if (std.mem.indexOf(u8, context, "\"")) |quote_start| {
                    if (std.mem.indexOfPos(u8, context, quote_start + 1, "\"")) |quote_end| {
                        const api_path = context[quote_start + 1 .. quote_end];
                        if (api_path.len > 0 and std.mem.startsWith(u8, api_path, "/")) {
                            const endpoint = ApiEndpoint{
                                .method = "GET",
                                .url = try self.allocator.dupe(u8, api_path),
                                .params = std.StringHashMap([]const u8).init(self.allocator),
                                .auth_type = .none,
                            };
                            try result.api_endpoints.append(endpoint);
                        }
                    }
                }
                
                pos = idx + pattern.len;
                if (result.api_endpoints.items.len >= 10) break;
            }
        }
    }
    
    /// 分析数据存储
    fn analyzeDataStores(self: *Explorer, result: *ExploreResult, html: []const u8) !void {
        _ = html;
        
        // 检查localStorage/sessionStorage使用
        var store = ExploreResult.DataStore{
            .name = "localStorage",
            .type = "localStorage",
            .keys = std.array_list.Managed([]const u8).init(self.allocator),
        };
        
        // 添加常见的localStorage键
        try store.keys.append(try self.allocator.dupe(u8, "token"));
        try store.keys.append(try self.allocator.dupe(u8, "user"));
        try store.keys.append(try self.allocator.dupe(u8, "session"));
        
        try result.data_stores.append(store);
    }
    
    /// 推荐认证策略
    fn recommendStrategy(self: *Explorer, result: *ExploreResult) !types.AuthStrategy {
        _ = self;
        
        // 根据发现的端点推荐策略
        for (result.api_endpoints.items) |endpoint| {
            if (endpoint.auth_type != .none) {
                return .cookie;
            }
        }
        
        // 检查是否有登录相关的端点
        for (result.api_endpoints.items) |endpoint| {
            if (std.mem.indexOf(u8, endpoint.url, "login") != null or
                std.mem.indexOf(u8, endpoint.url, "auth") != null) {
                return .cookie;
            }
        }
        
        return .public;
    }
};

/// 合成器 - 生成适配器代码
pub const Synthesizer = struct {
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) Synthesizer {
        return Synthesizer{ .allocator = allocator };
    }
    
    /// 从探索结果生成适配器
    pub fn synthesize(self: *Synthesizer, result: *const ExploreResult, options: SynthesizeOptions) ![]const u8 {
        var output = std.array_list.Managed(u8).init(self.allocator);
        defer output.deinit();

        var used_cmd_names = std.array_list.Managed([]const u8).init(self.allocator);
        defer {
            for (used_cmd_names.items) |n| self.allocator.free(n);
            used_cmd_names.deinit();
        }

        const writer = output.writer();

        // 生成YAML配置
        try writer.print("# Auto-generated adapter for {s}\n", .{result.title});
        try writer.print("name: {s}\n", .{options.site_name});
        try writer.print("version: \"1.0.0\"\n", .{});
        try writer.print("description: Auto-generated adapter for {s}\n", .{result.title});
        try writer.print("site: {s}\n", .{options.site_name});
        try writer.print("domain: {s}\n", .{result.url});
        try writer.print("strategy: {s}\n\n", .{@tagName(result.recommended_strategy)});

        if (result.api_endpoints.items.len == 0) {
            try writer.writeAll("commands: {}\n");
        } else {
            try writer.print("commands:\n", .{});
            for (result.api_endpoints.items, 0..) |endpoint, i| {
                if (i >= options.top) break;

                const abs_url = try resolveAbsoluteFetchUrl(self.allocator, result.url, endpoint.url);
                defer self.allocator.free(abs_url);

                const cmd_name = try self.allocUniqueCommandName(endpoint.url, &used_cmd_names);

                try writer.print("  {s}:\n", .{cmd_name});
                try writer.print("    name: {s}\n", .{cmd_name});
                try writer.print("    description: Auto-generated command\n", .{});
                try writer.print("    args: []\n", .{});
                try writer.print("    pipeline:\n", .{});
                try writer.print("      steps:\n", .{});
                try writer.print("        - name: fetch_{s}\n", .{cmd_name});
                try writer.print("          type: fetch\n", .{});
                try writer.print("          config:\n", .{});
                try writer.print("            url: \"{s}\"\n", .{abs_url});
                try writer.print("            method: {s}\n\n", .{endpoint.method});
            }
        }

        return try self.allocator.dupe(u8, output.items);
    }

    /// 在单次 `synthesize` 内保证 YAML 键唯一（`used` 取得所有权并负责释放元素）
    fn allocUniqueCommandName(self: *Synthesizer, path_url: []const u8, used: *std.array_list.Managed([]const u8)) ![]const u8 {
        const base = try self.generateCommandName(path_url);
        defer self.allocator.free(base);
        var suffix: u32 = 0;
        while (suffix < 4096) {
            const candidate = if (suffix == 0)
                try self.allocator.dupe(u8, base)
            else
                try std.fmt.allocPrint(self.allocator, "{s}_{d}", .{ base, suffix });

            var clash = false;
            for (used.items) |u| {
                if (std.mem.eql(u8, u, candidate)) {
                    clash = true;
                    break;
                }
            }
            if (!clash) {
                try used.append(candidate);
                return candidate;
            }
            self.allocator.free(candidate);
            suffix += 1;
        }
        return error.TooManyDuplicateCommandNames;
    }
    
    /// 合成选项
    pub const SynthesizeOptions = struct {
        site_name: []const u8,
        top: u32 = 3,
    };
    
    /// 生成命令名称
    fn generateCommandName(self: *Synthesizer, url: []const u8) ![]const u8 {
        // 从URL路径生成命令名
        var parts = std.mem.splitSequence(u8, url, "/");
        var last_part: []const u8 = "api";
        
        while (parts.next()) |part| {
            if (part.len > 0) {
                last_part = part;
            }
        }
        
        return try self.allocator.dupe(u8, last_part);
    }
};

/// 生成器 - 一键生成完整适配器
pub const Generator = struct {
    allocator: std.mem.Allocator,
    explorer: Explorer,
    synthesizer: Synthesizer,
    
    pub fn init(allocator: std.mem.Allocator) !Generator {
        return Generator{
            .allocator = allocator,
            .explorer = try Explorer.init(allocator),
            .synthesizer = Synthesizer.init(allocator),
        };
    }
    
    pub fn deinit(self: *Generator) void {
        self.explorer.deinit();
    }
    
    /// 生成完整适配器
    pub fn generate(self: *Generator, url: []const u8, options: GenerateOptions) !void {
        std.log.info("Generating adapter for: {s}", .{url});

        const out_base = if (options.output_dir.len > 0)
            try self.allocator.dupe(u8, options.output_dir)
        else
            try opencliUserClisDir(self.allocator);
        defer self.allocator.free(out_base);

        // 1. 探索网站
        const explore_options = Explorer.ExploreOptions{
            .depth = options.depth,
            .wait_seconds = options.wait_seconds,
            .auto_fuzzing = options.auto_fuzz,
        };

        var result = try self.explorer.explore(url, explore_options);
        defer result.deinit();

        std.log.info("Found {d} API endpoints", .{result.api_endpoints.items.len});

        // 1b. 探索 JSON 侧车（供 synthesize 与排错）
        const explore_json = try exploreResultToJsonString(self.allocator, &result);
        defer self.allocator.free(explore_json);
        const explore_dir = try std.fs.path.join(self.allocator, &.{ out_base, "..", "explore" });
        defer self.allocator.free(explore_dir);
        try std.fs.cwd().makePath(explore_dir);
        const explore_name = try std.fmt.allocPrint(self.allocator, "{s}.json", .{options.site_name});
        defer self.allocator.free(explore_name);
        const explore_path = try std.fs.path.join(self.allocator, &.{ explore_dir, explore_name });
        defer self.allocator.free(explore_path);
        {
            const ef = try std.fs.cwd().createFile(explore_path, .{ .truncate = true });
            defer ef.close();
            try ef.writeAll(explore_json);
        }
        std.log.info("Explore JSON: {s}", .{explore_path});

        // 2. 合成适配器代码
        const synthesize_options = Synthesizer.SynthesizeOptions{
            .site_name = options.site_name,
            .top = options.top,
        };

        const yaml_config = try self.synthesizer.synthesize(&result, synthesize_options);
        defer self.allocator.free(yaml_config);

        // 3. 保存到 ~/.opencli/clis/<site>/adapter.yaml（多命令根级 commands:，discovery 会展开注册）
        const output_path = try std.fs.path.join(self.allocator, &.{
            out_base,
            options.site_name,
            "adapter.yaml",
        });
        defer self.allocator.free(output_path);

        const dir_path = try std.fs.path.join(self.allocator, &.{
            out_base,
            options.site_name,
        });
        defer self.allocator.free(dir_path);

        try std.fs.cwd().makePath(dir_path);

        const file = try std.fs.cwd().createFile(output_path, .{ .truncate = true });
        defer file.close();

        try file.writeAll(yaml_config);

        std.log.info("Adapter saved to: {s}", .{output_path});
        std.log.info("Registry loads user YAML at startup; run `opencliz list` or any command in a new process to pick up new adapters.", .{});
    }

    /// 生成选项（`output_dir` 空则使用本机 `~/.opencli/clis`）
    pub const GenerateOptions = struct {
        site_name: []const u8,
        output_dir: []const u8 = "",
        depth: u32 = 1,
        wait_seconds: u32 = 3,
        auto_fuzz: bool = false,
        top: u32 = 3,
    };
};