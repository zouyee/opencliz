const std = @import("std");
const types = @import("../core/types.zig");
const http = @import("../http/client.zig");
const cli_runner = @import("../cli/runner.zig");

/// Daemon配置
pub const DaemonConfig = struct {
    port: u16 = 8080,
    host: []const u8 = "127.0.0.1",
    max_connections: u32 = 100,
    request_timeout_ms: u32 = 30000,
    /// `/execute` 内命令执行 wall-clock 超时（毫秒）。`0` 表示不限制。超时后返回 **504**，宿主仍会 **`join`** 工作线程（不取消子进程）。
    execute_timeout_ms: u32 = 0,
    enable_cors: bool = true,
    auth_token: ?[]const u8 = null,
};

const cache_util = @import("../utils/cache.zig");

const DaemonExecCtx = struct {
    runner: *cli_runner.CliRunner,
    site: []const u8,
    name: []const u8,
    args: *const std.StringHashMap([]const u8),
    done: std.Thread.ResetEvent = .{},
    exec_err: ?anyerror = null,
    /// 成功且非 null 结果时由 `c_allocator` 持有；消费者 `dupe` 后应释放本切片。
    json_body: ?[]u8 = null,
    null_ok: bool = false,
};

fn daemonExecWorker(ctx: *DaemonExecCtx) void {
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();
    const ja = arena.allocator();

    const res = ctx.runner.runAndGetResultWithAllocator(ctx.site, ctx.name, ctx.args.*, ja) catch |e| {
        ctx.exec_err = e;
        ctx.done.set();
        return;
    };
    if (res) |data| {
        const s = std.json.Stringify.valueAlloc(std.heap.c_allocator, data, .{ .whitespace = .indent_2 }) catch {
            ctx.exec_err = error.OutOfMemory;
            cache_util.destroyLeakyJsonValue(ja, data);
            ctx.done.set();
            return;
        };
        cache_util.destroyLeakyJsonValue(ja, data);
        ctx.json_body = s;
    } else {
        ctx.null_ok = true;
    }
    ctx.done.set();
}

fn trimAsciiOws(s: []const u8) []const u8 {
    return std.mem.trim(u8, s, " \t");
}

fn headerKeyEq(name: []const u8, want: []const u8) bool {
    return std.ascii.eqlIgnoreCase(name, want);
}

fn parseContentLengthFromHeaders(header_block: []const u8) ?usize {
    var it = std.mem.splitSequence(u8, header_block, "\r\n");
    _ = it.next() orelse return null; // request line
    while (it.next()) |line| {
        if (line.len == 0) break;
        if (std.mem.indexOfScalar(u8, line, ':')) |colon| {
            const key = trimAsciiOws(line[0..colon]);
            const val = trimAsciiOws(line[colon + 1 ..]);
            if (headerKeyEq(key, "content-length")) {
                return std.fmt.parseInt(usize, val, 10) catch null;
            }
        }
    }
    return null;
}

/// 从流读取完整 HTTP 请求（含 body），供 TCP 与测试使用。
/// `read_timeout_ms`：`0` 表示不限制单次连接读阶段总时长（与旧行为一致）；否则从首字节起算总超时（`poll` + `read`）。
pub fn readHttpRequestFromStream(
    allocator: std.mem.Allocator,
    stream: std.net.Stream,
    max_total: usize,
    read_timeout_ms: u32,
) ![]u8 {
    const start: ?std.time.Instant = if (read_timeout_ms > 0)
        try std.time.Instant.now()
    else
        null;
    const timeout_ns: u64 = @as(u64, read_timeout_ms) * std.time.ns_per_ms;

    var list = std.array_list.Managed(u8).init(allocator);
    errdefer list.deinit();
    var buf: [4096]u8 = undefined;

    while (true) {
        const header_end = std.mem.indexOf(u8, list.items, "\r\n\r\n");
        if (header_end) |he| {
            const body_start = he + 4;
            const cl = parseContentLengthFromHeaders(list.items[0..body_start]) orelse 0;
            if (list.items.len >= body_start + cl) {
                return try list.toOwnedSlice();
            }
        }
        if (list.items.len >= max_total) return error.RequestTooLarge;

        if (read_timeout_ms > 0) {
            const now = try std.time.Instant.now();
            if (now.since(start.?) >= timeout_ns) return error.ReadTimeout;
            const elapsed = now.since(start.?);
            const remaining_ns = timeout_ns - elapsed;
            const poll_ms: i32 = if (remaining_ns >= std.time.ns_per_ms)
                @intCast(@min(remaining_ns / std.time.ns_per_ms, 60_000))
            else
                1;

            var pfd = [_]std.posix.pollfd{.{
                .fd = stream.handle,
                .events = std.c.POLL.IN,
                .revents = 0,
            }};
            const nready = try std.posix.poll(&pfd, poll_ms);
            if (nready == 0) {
                const now2 = try std.time.Instant.now();
                if (now2.since(start.?) >= timeout_ns) return error.ReadTimeout;
                continue;
            }
            if (pfd[0].revents & std.c.POLL.ERR != 0) return error.IncompleteRequest;
            if (pfd[0].revents & std.c.POLL.NVAL != 0) return error.IncompleteRequest;
        }

        const n = try stream.read(&buf);
        if (n == 0) return error.IncompleteRequest;
        try list.appendSlice(buf[0..n]);
    }
}

fn parseFirstLine(line: []const u8) !struct { method: []const u8, path: []const u8, query: ?[]const u8 } {
    var parts = std.mem.splitScalar(u8, line, ' ');
    const method = parts.next() orelse return error.InvalidRequest;
    const path_and_query = parts.next() orelse return error.InvalidRequest;
    _ = parts.next() orelse return error.InvalidRequest;

    var path = path_and_query;
    var query: ?[]const u8 = null;
    if (std.mem.indexOfScalar(u8, path_and_query, '?')) |q| {
        path = path_and_query[0..q];
        query = path_and_query[q + 1 ..];
    }
    return .{ .method = method, .path = path, .query = query };
}

fn scanHeaders(header_block: []const u8, out: *http.Request) void {
    var it = std.mem.splitSequence(u8, header_block, "\r\n");
    _ = it.next() orelse return;
    while (it.next()) |line| {
        if (line.len == 0) break;
        if (std.mem.indexOfScalar(u8, line, ':')) |colon| {
            const key = trimAsciiOws(line[0..colon]);
            const val = trimAsciiOws(line[colon + 1 ..]);
            if (headerKeyEq(key, "authorization")) {
                const prefix = "Bearer ";
                if (val.len > prefix.len and std.ascii.eqlIgnoreCase(val[0..prefix.len], prefix)) {
                    out.authorization_bearer = val[prefix.len..];
                }
            } else if (headerKeyEq(key, "x-opencli-token")) {
                out.header_opencli_token = val;
            } else if (headerKeyEq(key, "content-type")) {
                out.content_type = val;
            }
        }
    }
}

/// 解析完整请求字节（含 body）；所有切片均指向 `raw`。
pub fn parseHttpRequest(raw: []const u8) !http.Request {
    const header_end = std.mem.indexOf(u8, raw, "\r\n\r\n") orelse return error.InvalidRequest;
    const body_start = header_end + 4;
    const header_block = raw[0..body_start];
    const first_line_end = std.mem.indexOf(u8, raw, "\r\n") orelse return error.InvalidRequest;
    const first_line = raw[0..first_line_end];

    const pl = try parseFirstLine(first_line);
    const cl = parseContentLengthFromHeaders(header_block) orelse 0;

    var req = http.Request{
        .method = pl.method,
        .path = pl.path,
        .query = pl.query,
        .body = null,
    };
    scanHeaders(header_block, &req);

    if (cl > 0) {
        const end = body_start + cl;
        if (end > raw.len) return error.InvalidRequest;
        req.body = raw[body_start..end];
    } else {
        req.body = if (body_start < raw.len) raw[body_start..raw.len] else null;
    }

    return req;
}

fn queryToken(query: ?[]const u8) ?[]const u8 {
    const q = query orelse return null;
    var it = std.mem.splitScalar(u8, q, '&');
    while (it.next()) |param| {
        if (std.mem.indexOfScalar(u8, param, '=')) |eq| {
            const k = param[0..eq];
            const v = param[eq + 1 ..];
            if (std.mem.eql(u8, k, "token")) return v;
        }
    }
    return null;
}

fn authMatches(want: []const u8, req: http.Request) bool {
    if (req.authorization_bearer) |t| {
        if (std.mem.eql(u8, t, want)) return true;
    }
    if (req.header_opencli_token) |t| {
        if (std.mem.eql(u8, t, want)) return true;
    }
    if (queryToken(req.query)) |t| {
        if (std.mem.eql(u8, t, want)) return true;
    }
    return false;
}

fn jsonValueToArgString(allocator: std.mem.Allocator, v: std.json.Value) ![]const u8 {
    return switch (v) {
        .string => |s| try allocator.dupe(u8, s),
        .integer => |i| try std.fmt.allocPrint(allocator, "{d}", .{i}),
        .float => |f| try std.fmt.allocPrint(allocator, "{d}", .{f}),
        .bool => |b| if (b) try allocator.dupe(u8, "true") else try allocator.dupe(u8, "false"),
        else => try std.json.Stringify.valueAlloc(allocator, v, .{}),
    };
}

fn mergeJsonBodyIntoArgs(allocator: std.mem.Allocator, args: *std.StringHashMap([]const u8), body: []const u8) !void {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, body, .{});
    defer parsed.deinit();
    if (parsed.value != .object) return error.InvalidJsonBody;
    var it = parsed.value.object.iterator();
    while (it.next()) |e| {
        const key = try allocator.dupe(u8, e.key_ptr.*);
        const val = try jsonValueToArgString(allocator, e.value_ptr.*);
        if (try args.fetchPut(key, val)) |prev| {
            allocator.free(prev.key);
            allocator.free(prev.value);
        }
    }
}

fn contentTypeLooksJson(ct: []const u8) bool {
    var buf: [128]u8 = undefined;
    if (ct.len > buf.len) return false;
    const lower = std.ascii.lowerString(buf[0..ct.len], ct);
    return std.mem.indexOf(u8, lower, "application/json") != null;
}

fn mergePostBodyArgs(allocator: std.mem.Allocator, method: []const u8, req: http.Request, args: *std.StringHashMap([]const u8)) !void {
    if (!std.mem.eql(u8, method, "POST") and !std.mem.eql(u8, method, "PUT") and !std.mem.eql(u8, method, "PATCH")) return;
    const body = req.body orelse return;
    if (body.len == 0) return;
    if (req.content_type) |ct| {
        if (!contentTypeLooksJson(ct)) return;
    }
    try mergeJsonBodyIntoArgs(allocator, args, body);
}

fn statusText(code: u16) []const u8 {
    return switch (code) {
        200 => "OK",
        204 => "No Content",
        400 => "Bad Request",
        401 => "Unauthorized",
        404 => "Not Found",
        500 => "Internal Server Error",
        503 => "Service Unavailable",
        else => "OK",
    };
}

fn unauthorizedResponse() http.Response {
    return .{
        .status = 401,
        .body = "{\"error\": \"Unauthorized\"}",
        .content_type = "application/json",
    };
}

/// HTTP请求处理器
pub const RequestHandler = struct {
    allocator: std.mem.Allocator,
    registry: *types.Registry,
    runner: ?*cli_runner.CliRunner,
    config: *const DaemonConfig,

    pub fn init(allocator: std.mem.Allocator, reg: *types.Registry, r: ?*cli_runner.CliRunner, cfg: *const DaemonConfig) RequestHandler {
        return RequestHandler{
            .allocator = allocator,
            .registry = reg,
            .runner = r,
            .config = cfg,
        };
    }

    pub fn handle(self: *RequestHandler, request: http.Request) !http.Response {
        if (std.mem.eql(u8, request.method, "OPTIONS")) {
            return http.Response{
                .status = 204,
                .body = "",
                .content_type = "text/plain",
            };
        }

        if (self.config.auth_token) |want| {
            if (!authMatches(want, request)) {
                return unauthorizedResponse();
            }
        }

        const path = request.path;

        if (std.mem.eql(u8, path, "/")) {
            return try self.handleRoot();
        } else if (std.mem.eql(u8, path, "/health")) {
            return try self.handleHealth();
        } else if (std.mem.eql(u8, path, "/commands")) {
            return try self.handleCommands();
        } else if (std.mem.startsWith(u8, path, "/execute/")) {
            const command_path = path[9..];
            return try self.handleExecute(command_path, request);
        } else {
            return http.Response{
                .status = 404,
                .body = "{\"error\": \"Not found\"}",
                .content_type = "application/json",
            };
        }
    }

    fn handleRoot(self: *RequestHandler) !http.Response {
        _ = self;
        return http.Response{
            .status = 200,
            .body = "{\"name\": \"opencliz daemon\", \"version\": \"v0.0.1\", \"status\": \"running\"}",
            .content_type = "application/json",
        };
    }

    fn handleHealth(self: *RequestHandler) !http.Response {
        _ = self;
        return http.Response{
            .status = 200,
            .body = "{\"status\": \"healthy\"}",
            .content_type = "application/json",
        };
    }

    fn handleCommands(self: *RequestHandler) !http.Response {
        var list = std.array_list.Managed(u8).init(self.allocator);
        defer list.deinit();

        const writer = list.writer();
        try writer.print("{{\"commands\": [", .{});

        const commands = try self.registry.listCommands(self.allocator);
        defer self.allocator.free(commands);

        for (commands, 0..) |cmd, i| {
            if (i > 0) try writer.print(", ", .{});
            try writer.print("{{\"site\": \"{s}\", \"name\": \"{s}\", \"description\": \"{s}\"}}", .{ cmd.site, cmd.name, cmd.description });
        }

        try writer.print("]}}", .{});

        return http.Response{
            .status = 200,
            .body = try self.allocator.dupe(u8, list.items),
            .content_type = "application/json",
            .body_owned = true,
        };
    }

    fn handleExecute(self: *RequestHandler, command_path: []const u8, request: http.Request) !http.Response {
        if (std.mem.indexOfScalar(u8, command_path, '/')) |idx| {
            const site = command_path[0..idx];
            const name = command_path[idx + 1 ..];

            var args = std.StringHashMap([]const u8).init(self.allocator);
            defer {
                var ait = args.iterator();
                while (ait.next()) |e| {
                    self.allocator.free(e.key_ptr.*);
                    self.allocator.free(e.value_ptr.*);
                }
                args.deinit();
            }

            if (request.query) |query| {
                var it = std.mem.splitSequence(u8, query, "&");
                while (it.next()) |param| {
                    if (std.mem.indexOfScalar(u8, param, '=')) |eq_idx| {
                        const key = try self.allocator.dupe(u8, param[0..eq_idx]);
                        const value = try self.allocator.dupe(u8, param[eq_idx + 1 ..]);
                        if (try args.fetchPut(key, value)) |prev| {
                            self.allocator.free(prev.key);
                            self.allocator.free(prev.value);
                        }
                    }
                }
            }

            mergePostBodyArgs(self.allocator, request.method, request, &args) catch {
                return http.Response{
                    .status = 400,
                    .body = "{\"error\": \"Invalid JSON body\"}",
                    .content_type = "application/json",
                };
            };

            if (self.registry.getCommand(site, name) == null) {
                return http.Response{
                    .status = 404,
                    .body = "{\"error\": \"Command not found\"}",
                    .content_type = "application/json",
                };
            }

            if (self.runner) |r| {
                if (self.config.execute_timeout_ms > 0) {
                    var ctx: DaemonExecCtx = .{
                        .runner = r,
                        .site = site,
                        .name = name,
                        .args = &args,
                    };
                    const worker = try std.Thread.spawn(.{}, daemonExecWorker, .{&ctx});
                    const timeout_ns = @as(u64, self.config.execute_timeout_ms) * std.time.ns_per_ms;
                    const timed_out = blk: {
                        ctx.done.timedWait(timeout_ns) catch |werr| switch (werr) {
                            error.Timeout => break :blk true,
                        };
                        break :blk false;
                    };
                    if (timed_out) {
                        ctx.done.wait();
                        worker.join();
                        if (ctx.json_body) |b| std.heap.c_allocator.free(b);
                        return http.Response{
                            .status = 504,
                            .body = try self.allocator.dupe(u8, "{\"error\":\"Execute timeout\"}"),
                            .content_type = "application/json",
                            .body_owned = true,
                        };
                    }
                    worker.join();
                    defer if (ctx.json_body) |b| std.heap.c_allocator.free(b);

                    if (ctx.exec_err) |err| {
                        if (err == error.CommandNotFound) {
                            return http.Response{
                                .status = 404,
                                .body = "{\"error\": \"Command not found\"}",
                                .content_type = "application/json",
                            };
                        }
                        const error_msg = try std.fmt.allocPrint(self.allocator, "{{\"error\": \"Command execution failed: {}\"}}", .{err});
                        return http.Response{
                            .status = 500,
                            .body = error_msg,
                            .content_type = "application/json",
                            .body_owned = true,
                        };
                    }

                    if (ctx.null_ok) {
                        return http.Response{
                            .status = 200,
                            .body = try self.allocator.dupe(u8, "{\"status\": \"success\"}"),
                            .content_type = "application/json",
                            .body_owned = true,
                        };
                    }

                    const jb = ctx.json_body orelse {
                        return http.Response{
                            .status = 200,
                            .body = try self.allocator.dupe(u8, "{\"status\": \"success\"}"),
                            .content_type = "application/json",
                            .body_owned = true,
                        };
                    };
                    const dup = try self.allocator.dupe(u8, jb);
                    return http.Response{
                        .status = 200,
                        .body = dup,
                        .content_type = "application/json",
                        .body_owned = true,
                    };
                }

                const result = r.runAndGetResult(site, name, args) catch |err| {
                    if (err == error.CommandNotFound) {
                        return http.Response{
                            .status = 404,
                            .body = "{\"error\": \"Command not found\"}",
                            .content_type = "application/json",
                        };
                    }
                    const error_msg = try std.fmt.allocPrint(self.allocator, "{{\"error\": \"Command execution failed: {}\"}}", .{err});
                    return http.Response{
                        .status = 500,
                        .body = error_msg,
                        .content_type = "application/json",
                        .body_owned = true,
                    };
                };

                var output = std.array_list.Managed(u8).init(self.allocator);
                defer output.deinit();

                if (result) |data| {
                    const json_str = try std.json.Stringify.valueAlloc(self.allocator, data, .{ .whitespace = .indent_2 });
                    defer self.allocator.free(json_str);
                    try output.appendSlice(json_str);
                    cache_util.destroyLeakyJsonValue(self.allocator, data);
                } else {
                    try output.writer().print("{{\"status\": \"success\"}}", .{});
                }

                return http.Response{
                    .status = 200,
                    .body = try self.allocator.dupe(u8, output.items),
                    .content_type = "application/json",
                    .body_owned = true,
                };
            } else {
                return http.Response{
                    .status = 503,
                    .body = "{\"error\": \"Runner not initialized\"}",
                    .content_type = "application/json",
                };
            }
        }

        return http.Response{
            .status = 400,
            .body = "{\"error\": \"Invalid command path\"}",
            .content_type = "application/json",
        };
    }
};

pub fn freeResponseBody(allocator: std.mem.Allocator, res: *http.Response) void {
    if (res.body_owned) {
        allocator.free(res.body);
        res.body_owned = false;
    }
}

/// 解析原始 HTTP 请求并返回完整响应字节（含状态行与头），供测试与 `readAndDispatch` 使用。
pub fn dispatchHttpRequest(
    allocator: std.mem.Allocator,
    registry: *types.Registry,
    runner: ?*cli_runner.CliRunner,
    cfg: *const DaemonConfig,
    raw: []const u8,
) ![]u8 {
    const request = try parseHttpRequest(raw);
    var handler = RequestHandler.init(allocator, registry, runner, cfg);
    var res = try handler.handle(request);
    defer freeResponseBody(allocator, &res);
    return try formatHttpResponse(allocator, res, cfg);
}

/// Daemon服务
pub const Daemon = struct {
    allocator: std.mem.Allocator,
    config: DaemonConfig,
    server: ?std.net.Server = null,
    running: bool = false,
    registry: *types.Registry,
    runner: ?*cli_runner.CliRunner = null,
    /// `CliRunner` 持有的 `Config` 堆指针（`ensureRunner` 创建）
    app_config: ?*types.Config = null,

    pub fn init(allocator: std.mem.Allocator, cfg: DaemonConfig, reg: *types.Registry) Daemon {
        return Daemon{
            .allocator = allocator,
            .config = cfg,
            .registry = reg,
        };
    }

    pub fn deinit(self: *Daemon) void {
        self.stop();
        if (self.runner) |r| {
            r.deinit();
            self.allocator.destroy(r);
            self.runner = null;
        }
        if (self.app_config) |c| {
            c.deinit();
            self.allocator.destroy(c);
            self.app_config = null;
        }
    }

    /// 确保 Runner 已创建（与 `start` 前半段一致，供测试在 accept 前调用）。
    pub fn ensureRunner(self: *Daemon) !void {
        if (self.runner != null) return;

        const cfg_ptr = try self.allocator.create(types.Config);
        cfg_ptr.* = try types.Config.init(self.allocator);
        cfg_ptr.format = .json;
        self.app_config = cfg_ptr;

        const r = try self.allocator.create(cli_runner.CliRunner);
        r.* = try cli_runner.CliRunner.init(self.allocator, cfg_ptr, self.registry);
        self.runner = r;
    }

    /// 启动Daemon
    pub fn start(self: *Daemon) !void {
        if (self.running) return;

        try self.ensureRunner();

        const address = try std.net.Address.parseIp(self.config.host, self.config.port);

        self.server = try address.listen(.{
            .reuse_address = true,
        });

        self.running = true;

        std.log.info("Daemon started on {s}:{d}", .{ self.config.host, self.config.port });

        while (self.running) {
            const conn = self.server.?.accept() catch |err| {
                if (!self.running) break;
                std.log.err("Accept error: {}", .{err});
                continue;
            };

            self.readAndDispatch(conn.stream) catch |err| {
                std.log.err("Connection error: {}", .{err});
            };
        }
    }

    /// 停止Daemon
    pub fn stop(self: *Daemon) void {
        self.running = false;
        if (self.server) |*server| {
            server.deinit();
            self.server = null;
        }
        std.log.info("Daemon stopped", .{});
    }

    /// 从流读取一条 HTTP 请求并写入响应（单连接）。
    pub fn readAndDispatch(self: *Daemon, stream: std.net.Stream) !void {
        const max_len = 1024 * 1024;
        const raw = readHttpRequestFromStream(self.allocator, stream, max_len, self.config.request_timeout_ms) catch |err| switch (err) {
            error.ReadTimeout => {
                const msg = "HTTP/1.1 408 Request Timeout\r\nContent-Type: application/json\r\nContent-Length: 46\r\nConnection: close\r\n\r\n{\"error\": \"Request read timeout\"}";
                stream.writeAll(msg) catch {};
                return;
            },
            else => |e| return e,
        };
        defer self.allocator.free(raw);

        const response_text = try dispatchHttpRequest(self.allocator, self.registry, self.runner, &self.config, raw);
        defer self.allocator.free(response_text);

        try stream.writeAll(response_text);
    }
};

pub fn formatHttpResponse(allocator: std.mem.Allocator, response: http.Response, cfg: *const DaemonConfig) ![]u8 {
    var result = std.array_list.Managed(u8).init(allocator);
    const writer = result.writer();

    try writer.print("HTTP/1.1 {d} {s}\r\n", .{ response.status, statusText(response.status) });
    try writer.print("Content-Type: {s}\r\n", .{response.content_type});
    try writer.print("Content-Length: {d}\r\n", .{response.body.len});
    if (cfg.enable_cors) {
        try writer.print("Access-Control-Allow-Origin: *\r\n", .{});
        try writer.print("Access-Control-Allow-Methods: GET, POST, PUT, PATCH, OPTIONS\r\n", .{});
        try writer.print("Access-Control-Allow-Headers: Content-Type, Authorization, X-OpenCLI-Token\r\n", .{});
        try writer.print("Access-Control-Max-Age: 86400\r\n", .{});
    }
    try writer.print("Connection: close\r\n", .{});
    try writer.print("\r\n", .{});
    try writer.print("{s}", .{response.body});

    return result.toOwnedSlice();
}
