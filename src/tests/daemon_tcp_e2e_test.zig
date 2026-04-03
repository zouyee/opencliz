//! Daemon：单连接 TCP 端到端（真实 accept/read/write）。
const std = @import("std");
const types = @import("../core/types.zig");
const daemon = @import("../daemon/daemon.zig");
const cli_runner = @import("../cli/runner.zig");

const ServeCtx = struct {
    server: *std.net.Server,
    reg: *types.Registry,
    runner: ?*cli_runner.CliRunner,
    dcfg: *daemon.DaemonConfig,
};

fn serveOneConnection(ctx: *ServeCtx) void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const a = gpa.allocator();

    const conn = ctx.server.accept() catch return;
    defer conn.stream.close();

    const raw = daemon.readHttpRequestFromStream(a, conn.stream, 1024 * 1024, 0) catch return;
    defer a.free(raw);

    const out = daemon.dispatchHttpRequest(a, ctx.reg, ctx.runner, ctx.dcfg, raw) catch return;
    defer a.free(out);

    conn.stream.writeAll(out) catch {};
}

test "daemon tcp GET / root end-to-end" {
    const allocator = std.testing.allocator;

    var reg = types.Registry.init(allocator);
    defer reg.deinit();

    var dcfg = daemon.DaemonConfig{};

    var address = try std.net.Address.parseIp("127.0.0.1", 0);
    var server = try address.listen(.{ .reuse_address = true });
    defer server.deinit();
    const port = server.listen_address.getPort();

    var ctx = ServeCtx{
        .server = &server,
        .reg = &reg,
        .runner = null,
        .dcfg = &dcfg,
    };

    const th = try std.Thread.spawn(.{}, serveOneConnection, .{&ctx});
    defer th.join();

    std.Thread.sleep(30 * std.time.ns_per_ms);

    var stream = try std.net.tcpConnectToHost(allocator, "127.0.0.1", port);
    defer stream.close();

    try stream.writeAll("GET / HTTP/1.1\r\nHost: localhost\r\n\r\n");

    var buf: [4096]u8 = undefined;
    const n = try stream.read(&buf);
    try std.testing.expect(n > 0);
    try std.testing.expect(std.mem.indexOf(u8, buf[0..n], "HTTP/1.1 200") != null);
    try std.testing.expect(std.mem.indexOf(u8, buf[0..n], "opencliz daemon") != null);
}

test "daemon tcp GET /health end-to-end" {
    const allocator = std.testing.allocator;

    var reg = types.Registry.init(allocator);
    defer reg.deinit();

    var dcfg = daemon.DaemonConfig{};

    var address = try std.net.Address.parseIp("127.0.0.1", 0);
    var server = try address.listen(.{ .reuse_address = true });
    defer server.deinit();
    const port = server.listen_address.getPort();

    var ctx = ServeCtx{
        .server = &server,
        .reg = &reg,
        .runner = null,
        .dcfg = &dcfg,
    };

    const th = try std.Thread.spawn(.{}, serveOneConnection, .{&ctx});
    defer th.join();

    std.Thread.sleep(30 * std.time.ns_per_ms);

    var stream = try std.net.tcpConnectToHost(allocator, "127.0.0.1", port);
    defer stream.close();

    try stream.writeAll("GET /health HTTP/1.1\r\nHost: localhost\r\n\r\n");

    var buf: [4096]u8 = undefined;
    const n = try stream.read(&buf);
    try std.testing.expect(n > 0);
    try std.testing.expect(std.mem.indexOf(u8, buf[0..n], "HTTP/1.1 200") != null);
    try std.testing.expect(std.mem.indexOf(u8, buf[0..n], "healthy") != null);
}

test "daemon tcp auth Bearer and execute ts_legacy stub" {
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

    var dcfg = daemon.DaemonConfig{ .auth_token = "tok123" };

    var address = try std.net.Address.parseIp("127.0.0.1", 0);
    var server = try address.listen(.{ .reuse_address = true });
    defer server.deinit();
    const port = server.listen_address.getPort();

    var ctx = ServeCtx{
        .server = &server,
        .reg = &reg,
        .runner = r_ptr,
        .dcfg = &dcfg,
    };

    const th = try std.Thread.spawn(.{}, serveOneConnection, .{&ctx});
    defer th.join();

    std.Thread.sleep(30 * std.time.ns_per_ms);

    var stream = try std.net.tcpConnectToHost(allocator, "127.0.0.1", port);
    defer stream.close();

    const req = "POST /execute/fixture/legacy HTTP/1.1\r\nHost: localhost\r\nAuthorization: Bearer tok123\r\nContent-Type: application/json\r\nContent-Length: 22\r\n\r\n{\"language\":\"python\"}";
    try stream.writeAll(req);

    var buf: [8192]u8 = undefined;
    const n = try stream.read(&buf);
    try std.testing.expect(n > 0);
    try std.testing.expect(std.mem.indexOf(u8, buf[0..n], "HTTP/1.1 200") != null);
    try std.testing.expect(std.mem.indexOf(u8, buf[0..n], "ts_adapter_not_supported") != null);
}

test "daemon tcp missing auth returns 401 when OPENCLI_DAEMON_AUTH_TOKEN set" {
    const allocator = std.testing.allocator;

    var reg = types.Registry.init(allocator);
    defer reg.deinit();

    var dcfg = daemon.DaemonConfig{ .auth_token = "only-me" };

    var address = try std.net.Address.parseIp("127.0.0.1", 0);
    var server = try address.listen(.{ .reuse_address = true });
    defer server.deinit();
    const port = server.listen_address.getPort();

    var ctx = ServeCtx{
        .server = &server,
        .reg = &reg,
        .runner = null,
        .dcfg = &dcfg,
    };

    const th = try std.Thread.spawn(.{}, serveOneConnection, .{&ctx});
    defer th.join();

    std.Thread.sleep(30 * std.time.ns_per_ms);

    var stream = try std.net.tcpConnectToHost(allocator, "127.0.0.1", port);
    defer stream.close();

    try stream.writeAll("GET /health HTTP/1.1\r\nHost: localhost\r\n\r\n");

    var buf: [4096]u8 = undefined;
    const n = try stream.read(&buf);
    try std.testing.expect(n > 0);
    try std.testing.expect(std.mem.indexOf(u8, buf[0..n], "HTTP/1.1 401") != null);
    try std.testing.expect(std.mem.indexOf(u8, buf[0..n], "Unauthorized") != null);
}

test "daemon tcp X-OpenCLI-Token header satisfies auth" {
    const allocator = std.testing.allocator;

    var reg = types.Registry.init(allocator);
    defer reg.deinit();

    var dcfg = daemon.DaemonConfig{ .auth_token = "hdr-secret" };

    var address = try std.net.Address.parseIp("127.0.0.1", 0);
    var server = try address.listen(.{ .reuse_address = true });
    defer server.deinit();
    const port = server.listen_address.getPort();

    var ctx = ServeCtx{
        .server = &server,
        .reg = &reg,
        .runner = null,
        .dcfg = &dcfg,
    };

    const th = try std.Thread.spawn(.{}, serveOneConnection, .{&ctx});
    defer th.join();

    std.Thread.sleep(30 * std.time.ns_per_ms);

    var stream = try std.net.tcpConnectToHost(allocator, "127.0.0.1", port);
    defer stream.close();

    try stream.writeAll("GET /health HTTP/1.1\r\nHost: localhost\r\nX-OpenCLI-Token: hdr-secret\r\n\r\n");

    var buf: [4096]u8 = undefined;
    const n = try stream.read(&buf);
    try std.testing.expect(n > 0);
    try std.testing.expect(std.mem.indexOf(u8, buf[0..n], "HTTP/1.1 200") != null);
    try std.testing.expect(std.mem.indexOf(u8, buf[0..n], "healthy") != null);
}
