//! L2：`executeFetch` GET JSON 缓存 + **`test_fetch_get`** mock（不入网）。
const std = @import("std");
const types = @import("../core/types.zig");
const executor_mod = @import("../pipeline/executor.zig");
const cache_mod = @import("../utils/cache.zig");

var mock_fetch_calls: usize = 0;

fn mockFetchGet(exec: *executor_mod.PipelineExecutor, url: []const u8) !executor_mod.TestFetchGetResponse {
    _ = url;
    mock_fetch_calls += 1;
    const body = try std.fmt.allocPrint(exec.allocator, "{{\"call\":{d}}}", .{mock_fetch_calls});
    return .{ .status = 200, .body = body };
}

fn makeFetchPipeline(allocator: std.mem.Allocator, url: []const u8, extract: ?[]const u8) !types.PipelineDef {
    var step_cfg = std.StringHashMap([]const u8).init(allocator);
    try step_cfg.put(try allocator.dupe(u8, "url"), try allocator.dupe(u8, url));
    if (extract) |ep| {
        try step_cfg.put(try allocator.dupe(u8, "extract"), try allocator.dupe(u8, ep));
    }
    const steps = try allocator.alloc(types.PipelineDef.Step, 1);
    steps[0] = .{
        .name = try allocator.dupe(u8, "fetch1"),
        .step_type = .fetch,
        .config = step_cfg,
    };
    return .{ .steps = steps };
}

test "executeFetch GET second execute uses json cache mock not called twice" {
    const a = std.testing.allocator;

    var cfg = try types.Config.init(a);
    defer cfg.deinit();

    var exec = try executor_mod.PipelineExecutor.initForTesting(a, &cfg, true);
    defer exec.deinit();
    exec.test_fetch_get = &mockFetchGet;

    mock_fetch_calls = 0;
    const url = "https://mock.pipeline.test/resource";

    const pipeline = try makeFetchPipeline(a, url, null);
    defer types.pipelineDefDeinit(a, pipeline);

    var args = std.StringHashMap([]const u8).init(a);
    defer args.deinit();

    const r1 = try exec.execute(pipeline, args);
    defer if (r1) |v| cache_mod.destroyLeakyJsonValue(a, v);
    try std.testing.expectEqual(@as(usize, 1), mock_fetch_calls);
    try std.testing.expect(r1 != null);
    try std.testing.expectEqual(@as(i64, 1), r1.?.object.get("call").?.integer);

    const r2 = try exec.execute(pipeline, args);
    defer if (r2) |v| cache_mod.destroyLeakyJsonValue(a, v);
    try std.testing.expectEqual(@as(usize, 1), mock_fetch_calls);
    try std.testing.expect(r2 != null);
    try std.testing.expectEqual(@as(i64, 1), r2.?.object.get("call").?.integer);
}

test "executeFetch cache hit still applies extract" {
    const a = std.testing.allocator;

    var cfg = try types.Config.init(a);
    defer cfg.deinit();

    var exec = try executor_mod.PipelineExecutor.initForTesting(a, &cfg, true);
    defer exec.deinit();

    mock_fetch_calls = 0;
    const url = "https://mock.pipeline.test/nested";

    const pipeline = try makeFetchPipeline(a, url, "data.id");
    defer types.pipelineDefDeinit(a, pipeline);

    var args = std.StringHashMap([]const u8).init(a);
    defer args.deinit();

    exec.test_fetch_get = struct {
        fn get(e: *executor_mod.PipelineExecutor, u: []const u8) !executor_mod.TestFetchGetResponse {
            _ = u;
            mock_fetch_calls += 1;
            const body = try std.fmt.allocPrint(e.allocator, "{{\"data\":{{\"id\":{d}}}}}", .{mock_fetch_calls});
            return .{ .status = 200, .body = body };
        }
    }.get;

    const r1 = try exec.execute(pipeline, args);
    defer if (r1) |v| cache_mod.destroyLeakyJsonValue(a, v);
    try std.testing.expectEqual(@as(usize, 1), mock_fetch_calls);
    try std.testing.expect(r1 != null);
    try std.testing.expectEqual(@as(i64, 1), r1.?.integer);

    const r2 = try exec.execute(pipeline, args);
    defer if (r2) |v| cache_mod.destroyLeakyJsonValue(a, v);
    try std.testing.expectEqual(@as(usize, 1), mock_fetch_calls);
    try std.testing.expect(r2 != null);
    try std.testing.expectEqual(@as(i64, 1), r2.?.integer);
}
