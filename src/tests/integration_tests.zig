// Integration tests - tests the CLI end-to-end with real browser/API calls
const std = @import("std");
const types = @import("../core/types.zig");
const format = @import("../output/format.zig");
const http_client = @import("../http/client.zig");

/// Test helper: run CLI binary and capture output
fn runCli(args: []const []const u8) !struct { stdout: []u8, stderr: []u8, exit_code: u8 } {
    const allocator = std.testing.allocator;

    var child = std.process.Child.init(args, allocator);
    child.stdout_behavior = .pipe;
    child.stderr_behavior = .pipe;

    try child.spawn();

    const stdout = try child.stdout.?.readToEndAlloc(allocator, 1024 * 1024);
    errdefer allocator.free(stdout);

    const stderr = try child.stderr.?.readToEndAlloc(allocator, 1024 * 1024);
    errdefer allocator.free(stderr);

    const exit_code = try child.wait();

    return .{
        .stdout = stdout,
        .stderr = stderr,
        .exit_code = @as(u8, @intCast(exit_code)),
    };
}

// Test that the CLI binary exists and responds to --version
test "integration: CLI binary --version works" {
    const result = try runCli(&.{ "./zig-out/bin/opencli", "--version" });
    defer {
        std.testing.allocator.free(result.stdout);
        std.testing.allocator.free(result.stderr);
    }

    try std.testing.expect(result.exit_code == 0);
    try std.testing.expect(result.stdout.len > 0);
    // Version output should contain "opencli"
    try std.testing.expect(std.mem.containsAtLeast(u8, result.stdout, 1, "opencli"));
}

// Test that the CLI binary responds to --help
test "integration: CLI binary --help works" {
    const result = try runCli(&.{ "./zig-out/bin/opencli", "--help" });
    defer {
        std.testing.allocator.free(result.stdout);
        std.testing.allocator.free(result.stderr);
    }

    try std.testing.expect(result.exit_code == 0);
    try std.testing.expect(result.stdout.len > 0);
}

// Test that the CLI binary --list shows commands
test "integration: CLI list shows commands" {
    const result = try runCli(&.{ "./zig-out/bin/opencli", "list" });
    defer {
        std.testing.allocator.free(result.stdout);
        std.testing.allocator.free(result.stderr);
    }

    try std.testing.expect(result.exit_code == 0);
    // Should contain command groups like "bilibili", "github", etc.
    try std.testing.expect(std.mem.containsAtLeast(u8, result.stdout, 1, "bilibili"));
    try std.testing.expect(std.mem.containsAtLeast(u8, result.stdout, 1, "github"));
}

// Test bilibili hot command with real API call
test "integration: bilibili/hot returns data" {
    const result = try runCli(&.{ "./zig-out/bin/opencli", "bilibili/hot", "--limit", "3" });
    defer {
        std.testing.allocator.free(result.stdout);
        std.testing.allocator.free(result.stderr);
    }

    try std.testing.expect(result.exit_code == 0);
    // Should have some output
    try std.testing.expect(result.stdout.len > 0);
    // Table format should have headers
    try std.testing.expect(std.mem.containsAtLeast(u8, result.stdout, 1, "TITLE") or
        std.mem.containsAtLeast(u8, result.stdout, 1, "Title") or
        std.mem.containsAtLeast(u8, result.stdout, 1, "title"));
}

// Test bilibili/hot with JSON format
test "integration: bilibili/hot JSON format" {
    const result = try runCli(&.{ "./zig-out/bin/opencli", "bilibili/hot", "--limit", "2", "--format", "json" });
    defer {
        std.testing.allocator.free(result.stdout);
        std.testing.allocator.free(result.stderr);
    }

    try std.testing.expect(result.exit_code == 0);
    try std.testing.expect(result.stdout.len > 0);

    // Should be valid JSON (starts with [ or {)
    const trimmed = std.mem.trim(u8, result.stdout, " \n\r\t");
    try std.testing.expect(trimmed.len > 0);
    try std.testing.expect(trimmed[0] == '[' or trimmed[0] == '{');
}

// Test hackernews/top command with real API call
test "integration: hackernews/top returns data" {
    const result = try runCli(&.{ "./zig-out/bin/opencli", "hackernews/top", "--limit", "3" });
    defer {
        std.testing.allocator.free(result.stdout);
        std.testing.allocator.free(result.stderr);
    }

    try std.testing.expect(result.exit_code == 0);
    try std.testing.expect(result.stdout.len > 0);
}

// Test v2ex/hot command with real API call
test "integration: v2ex/hot returns data" {
    const result = try runCli(&.{ "./zig-out/bin/opencli", "v2ex/hot", "--limit", "3" });
    defer {
        std.testing.allocator.free(result.stdout);
        std.testing.allocator.free(result.stderr);
    }

    try std.testing.expect(result.exit_code == 0);
    try std.testing.expect(result.stdout.len > 0);
}

// Test reddit/hot command with real API call
test "integration: reddit/hot returns data" {
    const result = try runCli(&.{ "./zig-out/bin/opencli", "reddit/hot", "--limit", "3" });
    defer {
        std.testing.allocator.free(result.stdout);
        std.testing.allocator.free(result.stderr);
    }

    try std.testing.expect(result.exit_code == 0);
    try std.testing.expect(result.stdout.len > 0);
}

// Test stackoverflow/search command with real API call
test "integration: stackoverflow/search returns data" {
    const result = try runCli(&.{ "./zig-out/bin/opencli", "stackoverflow/search", "--query", "zig language", "--limit", "2" });
    defer {
        std.testing.allocator.free(result.stdout);
        std.testing.allocator.free(result.stderr);
    }

    try std.testing.expect(result.exit_code == 0);
    try std.testing.expect(result.stdout.len > 0);
}

// Test npm/search command with real API call
test "integration: npm/search returns data" {
    const result = try runCli(&.{ "./zig-out/bin/opencli", "npm/search", "--query", "zig", "--limit", "3" });
    defer {
        std.testing.allocator.free(result.stdout);
        std.testing.allocator.free(result.stderr);
    }

    try std.testing.expect(result.exit_code == 0);
    try std.testing.expect(result.stdout.len > 0);
}

// Test github/trending command with real API call
test "integration: github/trending returns data" {
    const result = try runCli(&.{ "./zig-out/bin/opencli", "github/trending", "--language", "rust", "--limit", "3" });
    defer {
        std.testing.allocator.free(result.stdout);
        std.testing.allocator.free(result.stderr);
    }

    try std.testing.expect(result.exit_code == 0);
    try std.testing.expect(result.stdout.len > 0);
}

// Test unknown command returns error
test "integration: unknown command returns error" {
    const result = try runCli(&.{ "./zig-out/bin/opencli", "unknown/site", "cmd" });
    defer {
        std.testing.allocator.free(result.stdout);
        std.testing.allocator.free(result.stderr);
    }

    // Should return non-zero exit code
    try std.testing.expect(result.exit_code != 0);
}

// Test with verbose flag
test "integration: verbose flag works" {
    const result = try runCli(&.{ "./zig-out/bin/opencli", "--verbose", "bilibili/hot", "--limit", "1" });
    defer {
        std.testing.allocator.free(result.stdout);
        std.testing.allocator.free(result.stderr);
    }

    try std.testing.expect(result.exit_code == 0);
    // Verbose should produce info messages to stderr
    try std.testing.expect(result.stderr.len > 0);
}

// HTTP Client integration tests
test "integration: HTTP client can fetch bilibili API" {
    const allocator = std.testing.allocator;

    var client = http_client.HttpClient.init(allocator);
    defer client.deinit();

    // Test fetching bilibili hot API
    var response = try client.get("https://api.bilibili.com/x/web-interface/ranking/v2?rid=0&type=all", null);
    defer response.deinit();

    try std.testing.expect(response.status == 200);
    try std.testing.expect(response.body.len > 0);

    // Body should be JSON
    const trimmed = std.mem.trim(u8, response.body, " \n\r\t");
    try std.testing.expect(trimmed[0] == '{');
}

test "integration: HTTP client can fetch hackernews API" {
    const allocator = std.testing.allocator;

    var client = http_client.HttpClient.init(allocator);
    defer client.deinit();

    // Test fetching hackernews top stories
    var response = try client.get("https://hacker-news.firebaseio.com/v0/topstories.json", null);
    defer response.deinit();

    try std.testing.expect(response.status == 200);
    try std.testing.expect(response.body.len > 0);

    // Body should be JSON array
    const trimmed = std.mem.trim(u8, response.body, " \n\r\t");
    try std.testing.expect(trimmed[0] == '[');
}

test "integration: HTTP client can fetch v2ex API" {
    const allocator = std.testing.allocator;

    var client = http_client.HttpClient.init(allocator);
    defer client.deinit();

    // Test fetching v2ex hot
    var response = try client.get("https://www.v2ex.com/api/topics/latest.json", null);
    defer response.deinit();

    try std.testing.expect(response.status == 200);
    try std.testing.expect(response.body.len > 0);
}

test "integration: HTTP client follows redirects" {
    const allocator = std.testing.allocator;

    var client = http_client.HttpClient.init(allocator);
    defer client.deinit();

    // GitHub may redirect, should follow
    var response = try client.get("https://github.com/jackwener/opencli", null);
    defer response.deinit();

    // Should get 200 after following redirect
    try std.testing.expect(response.status == 200);
}

// Format output integration tests
test "integration: JSON format output is valid" {
    const allocator = std.testing.allocator;

    const json_str = "[{\"name\":\"test\",\"value\":42},{\"name\":\"test2\",\"value\":100}]";
    var json = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer json.deinit();

    // Format as JSON
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);

    try format.formatJsonValue(allocator, json.value, &output.writer(allocator));

    const result = try output.toOwnedSlice(allocator);
    defer allocator.free(result);

    // Should be valid JSON
    try std.testing.expect(result.len > 0);
    try std.testing.expect(result[0] == '[');
}

test "integration: Table format output has headers" {
    const allocator = std.testing.allocator;

    const json_str = "[{\"name\":\"test\",\"value\":42}]";
    var json = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer json.deinit();

    const columns = &[_]types.ColumnDef{
        .{ .name = "Name", .key = "name" },
        .{ .name = "Value", .key = "value" },
    };

    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);

    try format.formatTable(allocator, json.value, &output.writer(allocator), columns);

    const result = try output.toOwnedSlice(allocator);
    defer allocator.free(result);

    // Should contain header
    try std.testing.expect(std.mem.containsAtLeast(u8, result, 1, "Name"));
    try std.testing.expect(std.mem.containsAtLeast(u8, result, 1, "Value"));
}

// Error handling integration tests
test "integration: Invalid URL returns error" {
    const allocator = std.testing.allocator;

    var client = http_client.HttpClient.init(allocator);
    defer client.deinit();

    // Invalid URL should fail
    const result = client.get("not-a-valid-url", null);
    try std.testing.expect(result == error.InvalidUrl);
}

test "integration: Non-existent host returns error" {
    const allocator = std.testing.allocator;

    var client = http_client.HttpClient.init(allocator);
    defer client.deinit();

    // Non-existent domain should fail
    const result = client.get("http://this-domain-does-not-exist-xyz123.com/", null);
    try std.testing.expect(result == error.ConnectionFailed or result == error.DnsResolutionFailed);
}

// Performance benchmark test
test "integration: CLI startup time is fast" {
    const timer = std.time.Timer.start() catch @panic("Timer init failed");

    const result = try runCli(&.{ "./zig-out/bin/opencli", "--version" });
    defer {
        std.testing.allocator.free(result.stdout);
        std.testing.allocator.free(result.stderr);
    }

    const elapsed_ns = timer.read();
    const elapsed_ms = elapsed_ns / 1_000_000;

    // Startup should be under 100ms (much faster than TypeScript's 500ms)
    try std.testing.expect(elapsed_ms < 100);
    try std.testing.expect(result.exit_code == 0);
}
