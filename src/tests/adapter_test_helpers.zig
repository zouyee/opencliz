const std = @import("std");
const types = @import("../core/types.zig");
const http = @import("../http/client.zig");

/// Mock response structure for testing HTTP responses
pub const MockResponse = struct {
    url: []const u8,
    status: u16,
    body: []const u8,
    content_type: []const u8 = "application/json",
};

/// Mock HTTP client for testing adapter execution
pub const MockHttpClient = struct {
    allocator: std.mem.Allocator,
    responses: std.ArrayList(MockResponse),
    request_log: std.ArrayList([]const u8),
    current_index: usize = 0,

    pub fn init(allocator: std.mem.Allocator) MockHttpClient {
        return .{
            .allocator = allocator,
            .responses = .empty,
            .request_log = .empty,
        };
    }

    pub fn deinit(self: *MockHttpClient) void {
        for (self.responses.items) |resp| {
            self.allocator.free(resp.url);
            self.allocator.free(resp.body);
        }
        self.responses.deinit(self.allocator);
        for (self.request_log.items) |url| {
            self.allocator.free(url);
        }
        self.request_log.deinit(self.allocator);
    }

    /// Add a mock response to be returned for requests matching the URL pattern
    pub fn addResponse(self: *MockHttpClient, url: []const u8, status: u16, body: []const u8) !void {
        try self.responses.append(self.allocator, .{
            .url = try self.allocator.dupe(u8, url),
            .status = status,
            .body = try self.allocator.dupe(u8, body),
        });
    }

    /// Add a mock JSON response
    pub fn addJsonResponse(self: *MockHttpClient, url: []const u8, body: []const u8) !void {
        try self.addResponse(url, 200, body);
    }

    /// Reset the response index to replay responses
    pub fn reset(self: *MockHttpClient) void {
        self.current_index = 0;
    }

    /// Get the next response (for sequential responses)
    pub fn getNextResponse(self: *MockHttpClient) ?MockResponse {
        if (self.current_index >= self.responses.items.len) {
            return null;
        }
        const resp = self.responses.items[self.current_index];
        self.current_index += 1;
        return resp;
    }

    /// Get all logged request URLs
    pub fn getRequestLog(self: *const MockHttpClient) []const []const u8 {
        return self.request_log.items;
    }
};

/// Create a test command with minimal configuration
pub fn createTestCommand(site: []const u8, name: []const u8) types.Command {
    return types.Command{
        .site = site,
        .name = name,
        .description = "Test command",
        .domain = try std.fmt.allocPrint(null, "{s}.com", .{site}) catch unreachable,
        .strategy = .public,
        .browser = false,
        .source = "adapter",
    };
}

/// Create a test command with arguments
pub fn createTestCommandWithArgs(
    site: []const u8,
    name: []const u8,
    args: []const types.ArgDef,
) types.Command {
    return types.Command{
        .site = site,
        .name = name,
        .description = "Test command",
        .domain = try std.fmt.allocPrint(null, "{s}.com", .{site}) catch unreachable,
        .strategy = .public,
        .browser = false,
        .args = args,
        .source = "adapter",
    };
}

/// Parse a JSON string into a std.json.Value
pub fn parseTestJson(allocator: std.mem.Allocator, json_str: []const u8) !std.json.Value {
    return try std.json.parseFromSliceLeaky(std.json.Value, allocator, json_str, .{});
}

/// Test helper to verify a JSON value contains expected fields
pub fn jsonHasField(value: std.json.Value, field_path: []const u8) bool {
    var parts = std.mem.splitScalar(u8, field_path, '.');
    var current: ?std.json.Value = value;

    while (parts.next()) |part| {
        if (current == null) return false;
        switch (current.?) {
            .object => |obj| {
                current = obj.get(part);
            },
            else => return false,
        }
    }
    return current != null;
}

/// Get a nested field value from JSON using dot notation
pub fn jsonGetNested(value: std.json.Value, field_path: []const u8) ?std.json.Value {
    var parts = std.mem.splitScalar(u8, field_path, '.');
    var current: ?std.json.Value = value;

    while (parts.next()) |part| {
        if (current == null) return null;
        switch (current.?) {
            .object => |obj| {
                current = obj.get(part);
            },
            .array => |arr| {
                const idx = std.fmt.parseInt(usize, part, 10) catch return null;
                if (idx >= arr.items.len) return null;
                current = arr.items[idx];
            },
            else => return null,
        }
    }
    return current;
}

/// Assert that two JSON values are deeply equal
pub fn expectJsonEqual(actual: std.json.Value, expected: std.json.Value) !void {
    switch (actual) {
        .null => {
            if (expected != .null) return error.TestFailed;
        },
        .bool => |v| {
            if (expected != .bool or v != expected.bool) return error.TestFailed;
        },
        .integer => |v| {
            if (expected != .integer or v != expected.integer) return error.TestFailed;
        },
        .float => |v| {
            if (expected != .float) {
                if (expected == .integer) {
                    if (@as(f64, v) != @as(f64, expected.integer)) return error.TestFailed;
                } else return error.TestFailed;
            }
        },
        .string => |v| {
            if (expected != .string or !std.mem.eql(u8, v, expected.string)) return error.TestFailed;
        },
        .array => |arr| {
            if (expected != .array) return error.TestFailed;
            if (arr.items.len != expected.array.items.len) return error.TestFailed;
            for (arr.items, expected.array.items) |a, e| {
                try expectJsonEqual(a, e);
            }
        },
        .object => |obj| {
            if (expected != .object) return error.TestFailed;
            if (obj.count() != expected.object.count()) return error.TestFailed;
            var it = obj.iterator();
            while (it.next()) |kv| {
                const expected_val = expected.object.get(kv.key_ptr.*) orelse return error.TestFailed;
                try expectJsonEqual(kv.value_ptr.*, expected_val);
            }
        },
    }
}
