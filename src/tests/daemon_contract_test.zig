//! L7：Daemon HTTP 路由与 JSON 形状契约（对齐 docs/DAEMON_API.md；无监听、无网络）。
const std = @import("std");
const types = @import("../core/types.zig");
const daemon = @import("../daemon/daemon.zig");
const cli_runner = @import("../cli/runner.zig");

fn expectJsonString(obj: std.json.ObjectMap, key: []const u8, want: []const u8) !void {
    const v = obj.get(key) orelse {
        std.debug.print("missing key: {s}\n", .{key});
        return error.TestUnexpectedResult;
    };
    try std.testing.expect(v == .string);
    try std.testing.expectEqualStrings(want, v.string);
}

fn expectHttpStatusPrefix(raw: []const u8, want: u16) !void {
    var it = std.mem.splitScalar(u8, raw, ' ');
    _ = it.next() orelse return error.BadHttp;
    const code_str = it.next() orelse return error.BadHttp;
    const code = try std.fmt.parseInt(u16, code_str, 10);
    try std.testing.expectEqual(want, code);
}

test "daemon GET / matches DAEMON_API root shape" {
    const allocator = std.testing.allocator;
    var reg = types.Registry.init(allocator);
    defer reg.deinit();

    var dcfg = daemon.DaemonConfig{};
    var handler = daemon.RequestHandler.init(allocator, &reg, null, &dcfg);
    var res = try handler.handle(.{
        .method = "GET",
        .path = "/",
        .query = null,
        .body = null,
    });
    defer daemon.freeResponseBody(allocator, &res);
    try std.testing.expectEqual(@as(u16, 200), res.status);
    try std.testing.expectEqualStrings("application/json", res.content_type);

    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, res.body, .{});
    defer parsed.deinit();
    try std.testing.expect(parsed.value == .object);
    try expectJsonString(parsed.value.object, "name", "opencliz daemon");
    try expectJsonString(parsed.value.object, "version", "v0.0.1");
    try expectJsonString(parsed.value.object, "status", "running");
}

test "daemon GET /health matches DAEMON_API health shape" {
    const allocator = std.testing.allocator;
    var reg = types.Registry.init(allocator);
    defer reg.deinit();

    var dcfg = daemon.DaemonConfig{};
    var handler = daemon.RequestHandler.init(allocator, &reg, null, &dcfg);
    var res = try handler.handle(.{
        .method = "GET",
        .path = "/health",
        .query = null,
        .body = null,
    });
    defer daemon.freeResponseBody(allocator, &res);

    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, res.body, .{});
    defer parsed.deinit();
    try expectJsonString(parsed.value.object, "status", "healthy");
}

test "daemon GET /commands returns commands array" {
    const allocator = std.testing.allocator;
    var reg = types.Registry.init(allocator);
    defer reg.deinit();

    var dcfg = daemon.DaemonConfig{};
    var handler = daemon.RequestHandler.init(allocator, &reg, null, &dcfg);
    var res = try handler.handle(.{
        .method = "GET",
        .path = "/commands",
        .query = null,
        .body = null,
    });
    defer daemon.freeResponseBody(allocator, &res);
    try std.testing.expectEqual(@as(u16, 200), res.status);

    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, res.body, .{});
    defer parsed.deinit();
    const cmds = parsed.value.object.get("commands") orelse return error.TestUnexpectedResult;
    try std.testing.expect(cmds == .array);
    try std.testing.expectEqual(@as(usize, 0), cmds.array.items.len);
}

test "daemon GET /commands includes registered command fields" {
    const allocator = std.testing.allocator;
    var reg = types.Registry.init(allocator);
    defer reg.deinit();

    try reg.registerCommand(.{
        .site = "demo",
        .name = "ping",
        .description = "pong",
        .domain = "example.com",
    });

    var dcfg = daemon.DaemonConfig{};
    var handler = daemon.RequestHandler.init(allocator, &reg, null, &dcfg);
    var res = try handler.handle(.{
        .method = "GET",
        .path = "/commands",
        .query = null,
        .body = null,
    });
    defer daemon.freeResponseBody(allocator, &res);

    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, res.body, .{});
    defer parsed.deinit();
    const cmds = parsed.value.object.get("commands").?.array;
    try std.testing.expectEqual(@as(usize, 1), cmds.items.len);
    const item = cmds.items[0].object;
    try expectJsonString(item, "site", "demo");
    try expectJsonString(item, "name", "ping");
    try expectJsonString(item, "description", "pong");
}

test "daemon unknown path 404 JSON" {
    const allocator = std.testing.allocator;
    var reg = types.Registry.init(allocator);
    defer reg.deinit();

    var dcfg = daemon.DaemonConfig{};
    var handler = daemon.RequestHandler.init(allocator, &reg, null, &dcfg);
    var res = try handler.handle(.{
        .method = "GET",
        .path = "/v1/no-such",
        .query = null,
        .body = null,
    });
    defer daemon.freeResponseBody(allocator, &res);
    try std.testing.expectEqual(@as(u16, 404), res.status);
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, res.body, .{});
    defer parsed.deinit();
    try expectJsonString(parsed.value.object, "error", "Not found");
}

test "daemon GET /execute unknown command without runner returns 404" {
    const allocator = std.testing.allocator;
    var reg = types.Registry.init(allocator);
    defer reg.deinit();

    var dcfg = daemon.DaemonConfig{};
    var handler = daemon.RequestHandler.init(allocator, &reg, null, &dcfg);
    var res = try handler.handle(.{
        .method = "GET",
        .path = "/execute/nope/cmd",
        .query = null,
        .body = null,
    });
    defer daemon.freeResponseBody(allocator, &res);
    try std.testing.expectEqual(@as(u16, 404), res.status);
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, res.body, .{});
    defer parsed.deinit();
    try expectJsonString(parsed.value.object, "error", "Command not found");
}

test "daemon GET /execute without runner returns 503" {
    const allocator = std.testing.allocator;
    var reg = types.Registry.init(allocator);
    defer reg.deinit();

    try reg.registerCommand(.{
        .site = "demo",
        .name = "ping",
        .description = "pong",
        .domain = "example.com",
    });

    var dcfg = daemon.DaemonConfig{};
    var handler = daemon.RequestHandler.init(allocator, &reg, null, &dcfg);
    var res = try handler.handle(.{
        .method = "GET",
        .path = "/execute/demo/ping",
        .query = null,
        .body = null,
    });
    defer daemon.freeResponseBody(allocator, &res);
    try std.testing.expectEqual(@as(u16, 503), res.status);
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, res.body, .{});
    defer parsed.deinit();
    try expectJsonString(parsed.value.object, "error", "Runner not initialized");
}

test "daemon GET /execute invalid path returns 400" {
    const allocator = std.testing.allocator;
    var reg = types.Registry.init(allocator);
    defer reg.deinit();

    var dcfg = daemon.DaemonConfig{};
    var handler = daemon.RequestHandler.init(allocator, &reg, null, &dcfg);
    var res = try handler.handle(.{
        .method = "GET",
        .path = "/execute/noslash",
        .query = null,
        .body = null,
    });
    defer daemon.freeResponseBody(allocator, &res);
    try std.testing.expectEqual(@as(u16, 400), res.status);
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, res.body, .{});
    defer parsed.deinit();
    try expectJsonString(parsed.value.object, "error", "Invalid command path");
}

test "daemon auth_token rejects missing credentials" {
    const allocator = std.testing.allocator;
    var reg = types.Registry.init(allocator);
    defer reg.deinit();

    var dcfg = daemon.DaemonConfig{ .auth_token = "secret" };
    var handler = daemon.RequestHandler.init(allocator, &reg, null, &dcfg);
    var res = try handler.handle(.{
        .method = "GET",
        .path = "/health",
        .query = null,
        .body = null,
    });
    defer daemon.freeResponseBody(allocator, &res);
    try std.testing.expectEqual(@as(u16, 401), res.status);
}

test "daemon auth_token accepts Bearer header" {
    const allocator = std.testing.allocator;
    var reg = types.Registry.init(allocator);
    defer reg.deinit();

    var dcfg = daemon.DaemonConfig{ .auth_token = "secret" };
    var handler = daemon.RequestHandler.init(allocator, &reg, null, &dcfg);
    var res = try handler.handle(.{
        .method = "GET",
        .path = "/health",
        .query = null,
        .body = null,
        .authorization_bearer = "secret",
    });
    defer daemon.freeResponseBody(allocator, &res);
    try std.testing.expectEqual(@as(u16, 200), res.status);
}

test "daemon auth_token accepts query token" {
    const allocator = std.testing.allocator;
    var reg = types.Registry.init(allocator);
    defer reg.deinit();

    var dcfg = daemon.DaemonConfig{ .auth_token = "secret" };
    var handler = daemon.RequestHandler.init(allocator, &reg, null, &dcfg);
    var res = try handler.handle(.{
        .method = "GET",
        .path = "/health",
        .query = "token=secret",
        .body = null,
    });
    defer daemon.freeResponseBody(allocator, &res);
    try std.testing.expectEqual(@as(u16, 200), res.status);
}

test "daemon auth_token accepts X-OpenCLI-Token header" {
    const allocator = std.testing.allocator;
    var reg = types.Registry.init(allocator);
    defer reg.deinit();

    var dcfg = daemon.DaemonConfig{ .auth_token = "secret" };
    var handler = daemon.RequestHandler.init(allocator, &reg, null, &dcfg);
    var res = try handler.handle(.{
        .method = "GET",
        .path = "/health",
        .query = null,
        .body = null,
        .header_opencli_token = "secret",
    });
    defer daemon.freeResponseBody(allocator, &res);
    try std.testing.expectEqual(@as(u16, 200), res.status);
}

test "daemon auth_token rejects wrong Bearer" {
    const allocator = std.testing.allocator;
    var reg = types.Registry.init(allocator);
    defer reg.deinit();

    var dcfg = daemon.DaemonConfig{ .auth_token = "secret" };
    var handler = daemon.RequestHandler.init(allocator, &reg, null, &dcfg);
    var res = try handler.handle(.{
        .method = "GET",
        .path = "/health",
        .query = null,
        .body = null,
        .authorization_bearer = "wrong-token",
    });
    defer daemon.freeResponseBody(allocator, &res);
    try std.testing.expectEqual(@as(u16, 401), res.status);
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, res.body, .{});
    defer parsed.deinit();
    try expectJsonString(parsed.value.object, "error", "Unauthorized");
}

test "daemon OPTIONS skips auth when token configured" {
    const allocator = std.testing.allocator;
    var reg = types.Registry.init(allocator);
    defer reg.deinit();

    var dcfg = daemon.DaemonConfig{ .auth_token = "secret" };
    var handler = daemon.RequestHandler.init(allocator, &reg, null, &dcfg);
    var res = try handler.handle(.{
        .method = "OPTIONS",
        .path = "/execute/demo/ping",
        .query = null,
        .body = null,
    });
    defer daemon.freeResponseBody(allocator, &res);
    try std.testing.expectEqual(@as(u16, 204), res.status);
}

test "daemon GET /execute unknown command returns 404" {
    const allocator = std.testing.allocator;
    var reg = types.Registry.init(allocator);
    defer reg.deinit();

    const cfg_ptr = try allocator.create(types.Config);
    defer {
        cfg_ptr.deinit();
        allocator.destroy(cfg_ptr);
    }
    cfg_ptr.* = try types.Config.init(allocator);
    cfg_ptr.format = .json;

    const r_ptr = try allocator.create(cli_runner.CliRunner);
    defer {
        r_ptr.deinit();
        allocator.destroy(r_ptr);
    }
    r_ptr.* = try cli_runner.CliRunner.init(allocator, cfg_ptr, &reg);

    var dcfg = daemon.DaemonConfig{};
    var handler = daemon.RequestHandler.init(allocator, &reg, r_ptr, &dcfg);
    var res = try handler.handle(.{
        .method = "GET",
        .path = "/execute/ghost_site/ghost_cmd",
        .query = null,
        .body = null,
    });
    defer daemon.freeResponseBody(allocator, &res);
    try std.testing.expectEqual(@as(u16, 404), res.status);
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, res.body, .{});
    defer parsed.deinit();
    try expectJsonString(parsed.value.object, "error", "Command not found");
}

test "daemon OPTIONS returns 204 with CORS in full wire response" {
    const allocator = std.testing.allocator;
    var reg = types.Registry.init(allocator);
    defer reg.deinit();

    var dcfg = daemon.DaemonConfig{};
    const raw = "OPTIONS /execute/github/trending HTTP/1.1\r\nHost: localhost\r\n\r\n";
    const out = try daemon.dispatchHttpRequest(allocator, &reg, null, &dcfg, raw);
    defer allocator.free(out);
    try expectHttpStatusPrefix(out, 204);
    try std.testing.expect(std.mem.indexOf(u8, out, "Access-Control-Allow-Origin") != null);
}

test "daemon parseHttpRequest POST JSON body" {
    const raw = "POST /execute/fixture/legacy HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/json\r\nContent-Length: 22\r\n\r\n{\"language\":\"python\"}";
    const req = try daemon.parseHttpRequest(raw);
    try std.testing.expectEqualStrings("POST", req.method);
    try std.testing.expectEqualStrings("/execute/fixture/legacy", req.path);
    try std.testing.expect(req.body != null);
    try std.testing.expectEqualStrings("{\"language\":\"python\"}", req.body.?);
}

test "daemon POST /execute merges JSON body into args (ts_legacy stub)" {
    const allocator = std.testing.allocator;
    var reg = types.Registry.init(allocator);
    defer reg.deinit();

    try reg.registerCommand(.{
        .site = "fixture",
        .name = "legacy",
        .description = "stub",
        .domain = "example.com",
        .source = "ts_legacy",
    });

    const cfg_ptr = try allocator.create(types.Config);
    defer {
        cfg_ptr.deinit();
        allocator.destroy(cfg_ptr);
    }
    cfg_ptr.* = try types.Config.init(allocator);
    cfg_ptr.format = .json;

    const r_ptr = try allocator.create(cli_runner.CliRunner);
    defer {
        r_ptr.deinit();
        allocator.destroy(r_ptr);
    }
    r_ptr.* = try cli_runner.CliRunner.init(allocator, cfg_ptr, &reg);

    var dcfg = daemon.DaemonConfig{};
    var handler = daemon.RequestHandler.init(allocator, &reg, r_ptr, &dcfg);

    const body = "{\"language\":\"python\"}";
    var res = try handler.handle(.{
        .method = "POST",
        .path = "/execute/fixture/legacy",
        .query = null,
        .body = body,
        .content_type = "application/json",
    });
    defer daemon.freeResponseBody(allocator, &res);
    try std.testing.expectEqual(@as(u16, 200), res.status);
    try std.testing.expect(std.mem.indexOf(u8, res.body, "ts_adapter_not_supported") != null);
}

test "daemon dispatchHttpRequest GET health wire format" {
    const allocator = std.testing.allocator;
    var reg = types.Registry.init(allocator);
    defer reg.deinit();

    var dcfg = daemon.DaemonConfig{};
    const raw = "GET /health HTTP/1.1\r\nHost: localhost\r\n\r\n";
    const out = try daemon.dispatchHttpRequest(allocator, &reg, null, &dcfg, raw);
    defer allocator.free(out);
    try expectHttpStatusPrefix(out, 200);
    try std.testing.expect(std.mem.indexOf(u8, out, "\r\n\r\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "healthy") != null);
}
