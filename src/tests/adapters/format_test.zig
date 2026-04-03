const std = @import("std");
const format = @import("../../output/format.zig");

fn parseJson(allocator: std.mem.Allocator, json_str: []const u8) !std.json.Value {
    return try std.json.parseFromSliceLeaky(std.json.Value, allocator, json_str, .{});
}

test "getNestedValue: simple field" {
    const allocator = std.testing.allocator;
    const json = try parseJson(allocator,
        \\{"name": "test", "value": 42}
    );
    defer json.deinit(allocator);

    const result = format.getNestedValue(json, "name");
    defer result.deinit(allocator);

    try std.testing.expect(result == .string);
    try std.testing.expectEqualStrings("test", result.string);
}

test "getNestedValue: nested field" {
    const allocator = std.testing.allocator;
    const json = try parseJson(allocator,
        \\{"modules": {"module_author": {"name": "Alice"}, "module_dynamic": {"desc": {"text": "hello world"}}}}
    );
    defer json.deinit(allocator);

    const result = format.getNestedValue(json, "modules.module_author.name");
    defer result.deinit(allocator);

    try std.testing.expect(result == .string);
    try std.testing.expectEqualStrings("Alice", result.string);
}

test "getNestedValue: missing field returns null" {
    const allocator = std.testing.allocator;
    const json = try parseJson(allocator,
        \\{"modules": {"module_author": {"name": "Alice"}}}
    );
    defer json.deinit(allocator);

    const result = format.getNestedValue(json, "modules.module_dynamic.desc.text");
    defer result.deinit(allocator);

    try std.testing.expect(result == .null);
}

test "bilibili dynamic: expected output structure" {
    const allocator = std.testing.allocator;

    // This is what the TypeScript bilibili/dynamic.func returns:
    const typescript_expected =
        \\[{"id":"123","author":"Alice","text":"hello world","likes":9,"url":"https://t.bilibili.com/123"}]
    ;

    // The Zig version returns raw API response, not the mapped structure
    const zig_raw_response =
        \\{"code":0,"data":{"items":[{"id_str":"123","modules":{"module_author":{"name":"Alice"},"module_dynamic":{"desc":{"text":"hello world"}},"module_stat":{"like":{"count":9}}}}]}}
    ;

    // Parse both
    const expected = try parseJson(allocator, typescript_expected);
    defer expected.deinit(allocator);

    const raw = try parseJson(allocator, zig_raw_response);
    defer raw.deinit(allocator);

    // The first item in the items array
    const item = raw.object.get("data").?.object.get("items").?.array.items[0];

    // Extract fields using the Zig format layer approach (dot notation)
    const extracted_id = format.getNestedValue(item, "id_str");
    defer extracted_id.deinit(allocator);

    const extracted_author = format.getNestedValue(item, "modules.module_author.name");
    defer extracted_author.deinit(allocator);

    const extracted_text = format.getNestedValue(item, "modules.module_dynamic.desc.text");
    defer extracted_text.deinit(allocator);

    const extracted_likes = format.getNestedValue(item, "modules.module_stat.like.count");
    defer extracted_likes.deinit(allocator);

    // Verify extracted values match TypeScript expected output
    try std.testing.expect(extracted_id == .string);
    try std.testing.expectEqualStrings("123", extracted_id.string);

    try std.testing.expect(extracted_author == .string);
    try std.testing.expectEqualStrings("Alice", extracted_author.string);

    try std.testing.expect(extracted_text == .string);
    try std.testing.expectEqualStrings("hello world", extracted_text.string);

    try std.testing.expect(extracted_likes == .integer);
    try std.testing.expect(extracted_likes.integer == 9);
}

test "bilibili dynamic: fallback to archive title" {
    const allocator = std.testing.allocator;

    // When desc.text is missing but archive title exists
    const raw_response =
        \\{"id_str":"456","modules":{"module_author":{"name":"Bob"},"module_dynamic":{"major":{"archive":{"title":"Video title"}}},"module_stat":{"like":{"count":3}}}}
    ;

    const raw = try parseJson(allocator, raw_response);
    defer raw.deinit(allocator);

    // First try desc.text (will be null)
    const desc_text = format.getNestedValue(raw, "modules.module_dynamic.desc.text");
    defer desc_text.deinit(allocator);

    try std.testing.expect(desc_text == .null);

    // Then try archive title as fallback
    const archive_title = format.getNestedValue(raw, "modules.module_dynamic.major.archive.title");
    defer archive_title.deinit(allocator);

    try std.testing.expect(archive_title == .string);
    try std.testing.expectEqualStrings("Video title", archive_title.string);
}

test "bilibili hot: expected fields exist" {
    const allocator = std.testing.allocator;

    // Simplified bilibili hot response structure
    const hot_response =
        \\{"code":0,"data":{"list":[{"aid":123,"title":"Test Video","owner":{"name":"TestUser"},"stat":{"view":1000}}]}}
    ;

    const raw = try parseJson(allocator, hot_response);
    defer raw.deinit(allocator);

    // Get the first item from list
    const list = raw.object.get("data").?.object.get("list").?;
    try std.testing.expect(list == .array);

    if (list.array.items.len > 0) {
        const item = list.array.items[0];

        // Extract fields that would be used for output
        const title = format.getNestedValue(item, "title");
        defer title.deinit(allocator);

        const author = format.getNestedValue(item, "owner.name");
        defer author.deinit(allocator);

        const views = format.getNestedValue(item, "stat.view");
        defer views.deinit(allocator);

        try std.testing.expect(title == .string);
        try std.testing.expectEqualStrings("Test Video", title.string);

        try std.testing.expect(author == .string);
        try std.testing.expectEqualStrings("TestUser", author.string);

        try std.testing.expect(views == .integer);
        try std.testing.expect(views.integer == 1000);
    }
}
