//! explore / synthesize 的 golden 测试（无网络）。
const std = @import("std");
const ai = @import("../ai/explore.zig");

const explore_html = @embedFile("../../tests/fixtures/html/explore_sample.html");
const explore_edge_html = @embedFile("../../tests/fixtures/html/explore_edge_min.html");
const synthesizer_golden = @embedFile("../../tests/fixtures/golden/synthesizer_golden.yaml");

test "exploreFromHtml parses title and finds api path from fixture HTML" {
    const allocator = std.testing.allocator;

    var explorer = try ai.Explorer.init(allocator);
    defer explorer.deinit();

    var result = try explorer.exploreFromHtml("https://example.test", explore_html, .{});
    defer result.deinit();

    try std.testing.expectEqualStrings("Golden Explore Page", result.title);
    try std.testing.expect(result.api_endpoints.items.len >= 1);
    const first = result.api_endpoints.items[0];
    try std.testing.expect(std.mem.startsWith(u8, first.url, "/api/"));
}

test "exploreFromHtml edge fixture title only no api hints" {
    const allocator = std.testing.allocator;

    var explorer = try ai.Explorer.init(allocator);
    defer explorer.deinit();

    var result = try explorer.exploreFromHtml("https://edge.test", explore_edge_html, .{});
    defer result.deinit();

    try std.testing.expectEqualStrings("Edge Only Page", result.title);
    try std.testing.expectEqual(@as(usize, 0), result.api_endpoints.items.len);
}

test "exploreResult JSON roundtrip preserves endpoints" {
    const allocator = std.testing.allocator;

    var explorer = try ai.Explorer.init(allocator);
    defer explorer.deinit();

    var result = try explorer.exploreFromHtml("https://example.test", explore_html, .{});
    defer result.deinit();

    const js = try ai.exploreResultToJsonString(allocator, &result);
    defer allocator.free(js);

    var back = try ai.exploreResultParseJson(allocator, js);
    defer back.deinit();

    try std.testing.expectEqualStrings(result.url, back.url);
    try std.testing.expectEqual(result.api_endpoints.items.len, back.api_endpoints.items.len);
}

test "synthesizer output matches golden YAML fixture" {
    const allocator = std.testing.allocator;

    var result = try ai.ExploreResult.init(allocator, "https://example.test");
    defer result.deinit();

    result.title = try allocator.dupe(u8, "Golden Explore Page");

    try result.api_endpoints.append(.{
        .method = "GET",
        .url = try allocator.dupe(u8, "/api/v1/widgets"),
        .params = std.StringHashMap([]const u8).init(allocator),
        .auth_type = .none,
    });

    var syn = ai.Synthesizer.init(allocator);
    const out = try syn.synthesize(&result, .{ .site_name = "golden", .top = 3 });
    defer allocator.free(out);

    try std.testing.expectEqualStrings(synthesizer_golden, out);
}
