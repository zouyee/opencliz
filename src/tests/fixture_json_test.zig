//! L2：fixture JSON 形状校验（无网络；与 TS 侧同结构片段可对齐）。
const std = @import("std");
const format = @import("../output/format.zig");

const hn_item_min = @embedFile("../../tests/fixtures/json/hn_item_min.json");
const bilibili_hot_item_min = @embedFile("../../tests/fixtures/json/bilibili_hot_item_min.json");
const bilibili_dynamic_item_min = @embedFile("../../tests/fixtures/json/bilibili_dynamic_item_min.json");
const github_repo_min = @embedFile("../../tests/fixtures/json/github_repo_min.json");
const v2ex_topic_min = @embedFile("../../tests/fixtures/json/v2ex_topic_min.json");
const stackoverflow_item_min = @embedFile("../../tests/fixtures/json/stackoverflow_item_min.json");
const reddit_hot_item_min = @embedFile("../../tests/fixtures/json/reddit_hot_item_min.json");
const youtube_video_item_min = @embedFile("../../tests/fixtures/json/youtube_video_item_min.json");
const npm_search_item_min = @embedFile("../../tests/fixtures/json/npm_search_item_min.json");
const pypi_info_item_min = @embedFile("../../tests/fixtures/json/pypi_info_item_min.json");
const crates_info_item_min = @embedFile("../../tests/fixtures/json/crates_info_item_min.json");
const bilibili_user_item_min = @embedFile("../../tests/fixtures/json/bilibili_user_item_min.json");
const bilibili_search_item_min = @embedFile("../../tests/fixtures/json/bilibili_search_item_min.json");
const v2ex_member_item_min = @embedFile("../../tests/fixtures/json/v2ex_member_item_min.json");

test "fixture hn_item_min matches hackernews field expectations" {
    const allocator = std.testing.allocator;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, hn_item_min, .{});
    defer parsed.deinit();

    const title = format.getNestedValue(parsed.value, "title");
    try std.testing.expect(title == .string);
    try std.testing.expectEqualStrings("Test Story", title.string);

    const score = format.getNestedValue(parsed.value, "score");
    try std.testing.expect(score == .integer);
    try std.testing.expect(score.integer == 100);
}

test "fixture bilibili_hot_item_min nested paths" {
    const allocator = std.testing.allocator;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, bilibili_hot_item_min, .{});
    defer parsed.deinit();

    const title = format.getNestedValue(parsed.value, "title");
    try std.testing.expectEqualStrings("Test Video", title.string);

    const author = format.getNestedValue(parsed.value, "owner.name");
    try std.testing.expectEqualStrings("TestUser", author.string);

    const views = format.getNestedValue(parsed.value, "stat.view");
    try std.testing.expect(views == .integer);
    try std.testing.expect(views.integer == 1000);
}

test "fixture bilibili_dynamic_item_min nested paths" {
    const allocator = std.testing.allocator;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, bilibili_dynamic_item_min, .{});
    defer parsed.deinit();

    const id = format.getNestedValue(parsed.value, "id_str");
    try std.testing.expectEqualStrings("123", id.string);

    const author = format.getNestedValue(parsed.value, "modules.module_author.name");
    try std.testing.expectEqualStrings("Alice", author.string);

    const text = format.getNestedValue(parsed.value, "modules.module_dynamic.desc.text");
    try std.testing.expectEqualStrings("hello world", text.string);

    const likes = format.getNestedValue(parsed.value, "modules.module_stat.like.count");
    try std.testing.expect(likes == .integer);
    try std.testing.expect(likes.integer == 9);
}

test "fixture github_repo_min column keys" {
    const allocator = std.testing.allocator;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, github_repo_min, .{});
    defer parsed.deinit();

    try std.testing.expectEqualStrings("owner/repo", format.getNestedValue(parsed.value, "fullName").string);
    try std.testing.expectEqualStrings("Test repo", format.getNestedValue(parsed.value, "description").string);
    try std.testing.expectEqualStrings("Rust", format.getNestedValue(parsed.value, "language").string);
    const stars = format.getNestedValue(parsed.value, "stars");
    try std.testing.expect(stars == .integer);
    try std.testing.expect(stars.integer == 100);
}

test "fixture v2ex_topic_min nested paths" {
    const allocator = std.testing.allocator;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, v2ex_topic_min, .{});
    defer parsed.deinit();

    const id = format.getNestedValue(parsed.value, "id");
    try std.testing.expect(id == .integer);
    try std.testing.expectEqualStrings("Test Topic", format.getNestedValue(parsed.value, "title").string);
    try std.testing.expectEqualStrings("programming", format.getNestedValue(parsed.value, "node.name").string);
    try std.testing.expectEqualStrings("user1", format.getNestedValue(parsed.value, "author.name").string);
    const replies = format.getNestedValue(parsed.value, "replies");
    try std.testing.expect(replies == .integer);
    try std.testing.expect(replies.integer == 25);
}

test "fixture stackoverflow_item_min nested paths" {
    const allocator = std.testing.allocator;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, stackoverflow_item_min, .{});
    defer parsed.deinit();

    try std.testing.expect(format.getNestedValue(parsed.value, "question_id").integer == 12345);
    try std.testing.expectEqualStrings("Test Question", format.getNestedValue(parsed.value, "title").string);
    try std.testing.expectEqualStrings("user1", format.getNestedValue(parsed.value, "owner.display_name").string);
    try std.testing.expect(format.getNestedValue(parsed.value, "answer_count").integer == 5);
    try std.testing.expect(format.getNestedValue(parsed.value, "score").integer == 10);
}

test "fixture reddit_hot_item_min nested paths" {
    const allocator = std.testing.allocator;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, reddit_hot_item_min, .{});
    defer parsed.deinit();

    try std.testing.expectEqualStrings("Test Reddit Post", format.getNestedValue(parsed.value, "data.title").string);
    try std.testing.expectEqualStrings("programming", format.getNestedValue(parsed.value, "data.subreddit").string);
    const score = format.getNestedValue(parsed.value, "data.score");
    try std.testing.expect(score == .integer);
    try std.testing.expect(score.integer == 100);
    const num_comments = format.getNestedValue(parsed.value, "data.num_comments");
    try std.testing.expect(num_comments == .integer);
    try std.testing.expect(num_comments.integer == 42);
}

test "fixture youtube_video_item_min nested paths" {
    const allocator = std.testing.allocator;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, youtube_video_item_min, .{});
    defer parsed.deinit();

    try std.testing.expectEqualStrings("Test YouTube Video", format.getNestedValue(parsed.value, "title").string);
    try std.testing.expectEqualStrings("TestChannel", format.getNestedValue(parsed.value, "author_name").string);
    try std.testing.expectEqualStrings("https://youtube.com/watch?v=test123", format.getNestedValue(parsed.value, "url").string);
}

test "fixture npm_search_item_min nested paths" {
    const allocator = std.testing.allocator;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, npm_search_item_min, .{});
    defer parsed.deinit();

    try std.testing.expectEqualStrings("test-package", format.getNestedValue(parsed.value, "package.name").string);
    try std.testing.expectEqualStrings("1.0.0", format.getNestedValue(parsed.value, "package.version").string);
    try std.testing.expectEqualStrings("A test package", format.getNestedValue(parsed.value, "package.description").string);
}

test "fixture pypi_info_item_min nested paths" {
    const allocator = std.testing.allocator;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, pypi_info_item_min, .{});
    defer parsed.deinit();

    try std.testing.expectEqualStrings("test-package", format.getNestedValue(parsed.value, "info.name").string);
    try std.testing.expectEqualStrings("1.0.0", format.getNestedValue(parsed.value, "info.version").string);
    try std.testing.expectEqualStrings("A test Python package", format.getNestedValue(parsed.value, "info.summary").string);
}

test "fixture crates_info_item_min nested paths" {
    const allocator = std.testing.allocator;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, crates_info_item_min, .{});
    defer parsed.deinit();

    try std.testing.expectEqualStrings("test-crate", format.getNestedValue(parsed.value, "name").string);
    try std.testing.expectEqualStrings("0.1.0", format.getNestedValue(parsed.value, "version").string);
    try std.testing.expectEqualStrings("A test Rust crate", format.getNestedValue(parsed.value, "description").string);
    const downloads = format.getNestedValue(parsed.value, "downloads");
    try std.testing.expect(downloads == .integer);
    try std.testing.expect(downloads.integer == 12345);
}

test "fixture bilibili_user_item_min nested paths" {
    const allocator = std.testing.allocator;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, bilibili_user_item_min, .{});
    defer parsed.deinit();

    try std.testing.expectEqualStrings("TestUser", format.getNestedValue(parsed.value, "name").string);
    try std.testing.expectEqualStrings("123456", format.getNestedValue(parsed.value, "mid").string);
    const follower = format.getNestedValue(parsed.value, "follower");
    try std.testing.expect(follower == .integer);
    try std.testing.expect(follower.integer == 1000);
}

test "fixture bilibili_search_item_min nested paths" {
    const allocator = std.testing.allocator;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, bilibili_search_item_min, .{});
    defer parsed.deinit();

    try std.testing.expectEqualStrings("Test Search Video", format.getNestedValue(parsed.value, "title").string);
    try std.testing.expectEqualStrings("SearchAuthor", format.getNestedValue(parsed.value, "author").string);
    const play = format.getNestedValue(parsed.value, "play");
    try std.testing.expect(play == .integer);
    try std.testing.expect(play.integer == 500);
}

test "fixture v2ex_member_item_min nested paths" {
    const allocator = std.testing.allocator;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, v2ex_member_item_min, .{});
    defer parsed.deinit();

    try std.testing.expectEqualStrings("testuser", format.getNestedValue(parsed.value, "username").string);
    try std.testing.expectEqualStrings("Test user bio", format.getNestedValue(parsed.value, "bio").string);
}
