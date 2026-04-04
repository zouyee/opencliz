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
const zhihu_question_min = @embedFile("../../tests/fixtures/json/zhihu_question_min.json");
const weibo_feed_item_min = @embedFile("../../tests/fixtures/json/weibo_feed_item_min.json");
const npm_package_min = @embedFile("../../tests/fixtures/json/npm_package_min.json");
const twitter_timeline_item_min = @embedFile("../../tests/fixtures/json/twitter_timeline_item_min.json");
const douban_movie_min = @embedFile("../../tests/fixtures/json/douban_movie_min.json");
const wikipedia_search_min = @embedFile("../../tests/fixtures/json/wikipedia_search_min.json");
const youtube_transcript_min = @embedFile("../../tests/fixtures/json/youtube_transcript_min.json");
const bilibili_dynamic_archive_fallback_min = @embedFile("../../tests/fixtures/json/bilibili_dynamic_archive_fallback_min.json");
const reddit_read_comments_min = @embedFile("../../tests/fixtures/json/reddit_read_comments_min.json");
const npm_package_registry_meta_min = @embedFile("../../tests/fixtures/json/npm_package_registry_meta_min.json");
const github_trending_array_min = @embedFile("../../tests/fixtures/json/github_trending_array_min.json");
const stackoverflow_items_wrapper_min = @embedFile("../../tests/fixtures/json/stackoverflow_items_wrapper_min.json");
const hn_firebase_top_ids_min = @embedFile("../../tests/fixtures/json/hn_firebase_top_ids_min.json");
const opencli_status_login_required_min = @embedFile("../../tests/fixtures/json/opencli_status_login_required_min.json");
const opencli_status_http_or_cdp_min = @embedFile("../../tests/fixtures/json/opencli_status_http_or_cdp_min.json");
const hackernews_top_array_min = @embedFile("../../tests/fixtures/json/hackernews_top_array_min.json");
const v2ex_hot_array_min = @embedFile("../../tests/fixtures/json/v2ex_hot_array_min.json");

test "fixture hn_item_min matches hackernews field expectations" {
    const allocator = std.testing.allocator;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, hn_item_min, .{});
    defer parsed.deinit();

    try std.testing.expect(format.getNestedValue(parsed.value, "id").integer == 12345);
    const title = format.getNestedValue(parsed.value, "title");
    try std.testing.expect(title == .string);
    try std.testing.expectEqualStrings("Test Story", title.string);
    try std.testing.expectEqualStrings("https://example.com", format.getNestedValue(parsed.value, "url").string);
    try std.testing.expectEqualStrings("testuser", format.getNestedValue(parsed.value, "by").string);
    try std.testing.expect(format.getNestedValue(parsed.value, "time").integer == 1234567890);

    const score = format.getNestedValue(parsed.value, "score");
    try std.testing.expect(score == .integer);
    try std.testing.expect(score.integer == 100);
    try std.testing.expect(format.getNestedValue(parsed.value, "descendants").integer == 50);
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

test "fixture bilibili_dynamic_archive_fallback_min desc null and archive title" {
    const allocator = std.testing.allocator;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, bilibili_dynamic_archive_fallback_min, .{});
    defer parsed.deinit();

    const desc_text = format.getNestedValue(parsed.value, "modules.module_dynamic.desc.text");
    try std.testing.expect(desc_text == .null);

    const archive_title = format.getNestedValue(parsed.value, "modules.module_dynamic.major.archive.title");
    try std.testing.expectEqualStrings("Video title", archive_title.string);

    try std.testing.expectEqualStrings("Bob", format.getNestedValue(parsed.value, "modules.module_author.name").string);
    try std.testing.expect(format.getNestedValue(parsed.value, "modules.module_stat.like.count").integer == 3);
}

test "fixture github_trending_array_min first row matches trending extract paths" {
    const allocator = std.testing.allocator;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, github_trending_array_min, .{});
    defer parsed.deinit();

    try std.testing.expect(parsed.value == .array);
    const first = parsed.value.array.items[0];
    try std.testing.expectEqualStrings("owner/repo", format.getNestedValue(first, "fullName").string);
    try std.testing.expectEqualStrings("Test repo", format.getNestedValue(first, "description").string);
    try std.testing.expectEqualStrings("Rust", format.getNestedValue(first, "language").string);
    try std.testing.expect(format.getNestedValue(first, "stars").integer == 100);
}

test "fixture stackoverflow_items_wrapper_min items[0] paths" {
    const allocator = std.testing.allocator;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, stackoverflow_items_wrapper_min, .{});
    defer parsed.deinit();

    const items = parsed.value.object.get("items").?;
    const first = items.array.items[0];
    try std.testing.expect(format.getNestedValue(first, "question_id").integer == 12345);
    try std.testing.expectEqualStrings("Test Question", format.getNestedValue(first, "title").string);
    try std.testing.expectEqualStrings("user1", format.getNestedValue(first, "owner.display_name").string);
    try std.testing.expect(format.getNestedValue(first, "answer_count").integer == 5);
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

test "fixture reddit_read_comments_min thread array shape" {
    const allocator = std.testing.allocator;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, reddit_read_comments_min, .{});
    defer parsed.deinit();

    try std.testing.expect(parsed.value == .array);
    const first = parsed.value.array.items[0];
    try std.testing.expectEqualStrings("POST", format.getNestedValue(first, "type").string);
    try std.testing.expectEqualStrings("alice", format.getNestedValue(first, "author").string);
    try std.testing.expect(format.getNestedValue(first, "score").integer == 10);
    const second = parsed.value.array.items[1];
    try std.testing.expectEqualStrings("L0", format.getNestedValue(second, "type").string);
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

test "fixture zhihu_question_min nested paths" {
    const allocator = std.testing.allocator;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, zhihu_question_min, .{});
    defer parsed.deinit();

    try std.testing.expectEqual(@as(i64, 12345), format.getNestedValue(parsed.value, "question_id").integer);
    try std.testing.expectEqualStrings("Test Question", format.getNestedValue(parsed.value, "title").string);
    try std.testing.expectEqualStrings("TestUser", format.getNestedValue(parsed.value, "author.name").string);
    try std.testing.expectEqual(@as(i64, 5), format.getNestedValue(parsed.value, "answer_count").integer);
    try std.testing.expectEqual(@as(i64, 10), format.getNestedValue(parsed.value, "score").integer);
}

test "fixture weibo_feed_item_min nested paths" {
    const allocator = std.testing.allocator;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, weibo_feed_item_min, .{});
    defer parsed.deinit();

    try std.testing.expectEqualStrings("9876543210", format.getNestedValue(parsed.value, "id").string);
    try std.testing.expectEqualStrings("Test weibo post content", format.getNestedValue(parsed.value, "text").string);
    try std.testing.expectEqualStrings("TestUser", format.getNestedValue(parsed.value, "user.name").string);
    try std.testing.expectEqual(@as(i64, 42), format.getNestedValue(parsed.value, "reposts_count").integer);
    try std.testing.expectEqual(@as(i64, 15), format.getNestedValue(parsed.value, "comments_count").integer);
    try std.testing.expectEqual(@as(i64, 100), format.getNestedValue(parsed.value, "attitudes_count").integer);
}

test "fixture npm_package_min nested paths" {
    const allocator = std.testing.allocator;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, npm_package_min, .{});
    defer parsed.deinit();

    try std.testing.expectEqualStrings("express", format.getNestedValue(parsed.value, "name").string);
    try std.testing.expectEqualStrings("4.18.2", format.getNestedValue(parsed.value, "version").string);
    try std.testing.expectEqualStrings("Fast, unopinionated, minimalist web framework", format.getNestedValue(parsed.value, "description").string);
    try std.testing.expectEqualStrings("4.18.2", format.getNestedValue(parsed.value, "dist-tags.latest").string);
}

test "fixture npm_package_registry_meta_min time.modified path" {
    const allocator = std.testing.allocator;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, npm_package_registry_meta_min, .{});
    defer parsed.deinit();

    try std.testing.expectEqualStrings("test-package", format.getNestedValue(parsed.value, "name").string);
    try std.testing.expectEqualStrings("1.0.0", format.getNestedValue(parsed.value, "version").string);
    try std.testing.expectEqualStrings("Test package description", format.getNestedValue(parsed.value, "description").string);
    try std.testing.expectEqualStrings("2024-01-01T00:00:00Z", format.getNestedValue(parsed.value, "time.modified").string);
}

test "fixture twitter_timeline_item_min nested paths" {
    const allocator = std.testing.allocator;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, twitter_timeline_item_min, .{});
    defer parsed.deinit();

    try std.testing.expectEqualStrings("123", format.getNestedValue(parsed.value, "rest_id").string);
    try std.testing.expectEqualStrings("Hello tweet", format.getNestedValue(parsed.value, "legacy.full_text").string);
    try std.testing.expect(format.getNestedValue(parsed.value, "legacy.favorite_count").integer == 5);
    try std.testing.expectEqualStrings("alice", format.getNestedValue(parsed.value, "core.user_results.result.legacy.screen_name").string);
}

test "fixture douban_movie_min nested paths" {
    const allocator = std.testing.allocator;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, douban_movie_min, .{});
    defer parsed.deinit();

    try std.testing.expectEqualStrings("12345", format.getNestedValue(parsed.value, "id").string);
    try std.testing.expectEqualStrings("Test Movie", format.getNestedValue(parsed.value, "title").string);
    const rating = format.getNestedValue(parsed.value, "rating.value");
    try std.testing.expect(rating == .float);
    try std.testing.expect(rating.float == 8.5);
    try std.testing.expectEqualStrings("Director 1", format.getNestedValue(parsed.value, "director_name").string);
    try std.testing.expect(format.getNestedValue(parsed.value, "year").integer == 2024);
}

test "fixture wikipedia_search_min nested paths" {
    const allocator = std.testing.allocator;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, wikipedia_search_min, .{});
    defer parsed.deinit();

    const pages = parsed.value.object.get("query").?.object.get("pages").?;
    const first = pages.array.items[0];
    try std.testing.expect(format.getNestedValue(first, "pageid").integer == 12345);
    try std.testing.expectEqualStrings("Test Article", format.getNestedValue(first, "title").string);
    try std.testing.expectEqualStrings("Test extract text...", format.getNestedValue(first, "extract").string);
}

test "fixture youtube_transcript_min segment paths" {
    const allocator = std.testing.allocator;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, youtube_transcript_min, .{});
    defer parsed.deinit();

    const segments = parsed.value.object.get("segments").?;
    const first = segments.array.items[0];
    const start = format.getNestedValue(first, "start");
    try std.testing.expect(start == .integer or start == .float);
    try std.testing.expectEqualStrings("Hello there.", format.getNestedValue(first, "text").string);
}

test "fixture hn_firebase_top_ids_min is id array" {
    const allocator = std.testing.allocator;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, hn_firebase_top_ids_min, .{});
    defer parsed.deinit();
    try std.testing.expect(parsed.value == .array);
    try std.testing.expectEqual(@as(usize, 3), parsed.value.array.items.len);
    try std.testing.expect(parsed.value.array.items[0] == .integer);
    try std.testing.expectEqual(@as(i64, 9128456), parsed.value.array.items[0].integer);
    try std.testing.expectEqual(@as(i64, 9128455), parsed.value.array.items[1].integer);
}

test "fixture opencli_status_login_required_min paths" {
    const allocator = std.testing.allocator;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, opencli_status_login_required_min, .{});
    defer parsed.deinit();
    try std.testing.expectEqualStrings("login_required", format.getNestedValue(parsed.value, "status").string);
    try std.testing.expectEqualStrings("Cookie or token required for this endpoint", format.getNestedValue(parsed.value, "message").string);
}

test "fixture opencli_status_http_or_cdp_min paths" {
    const allocator = std.testing.allocator;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, opencli_status_http_or_cdp_min, .{});
    defer parsed.deinit();
    try std.testing.expectEqualStrings("http_or_cdp", format.getNestedValue(parsed.value, "status").string);
    try std.testing.expectEqualStrings("Shell HTML or anti-bot; try OPENCLI_USE_BROWSER=1", format.getNestedValue(parsed.value, "message").string);
}

test "fixture hackernews_top_array_min matches hnTopStories output shape" {
    const allocator = std.testing.allocator;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, hackernews_top_array_min, .{});
    defer parsed.deinit();
    try std.testing.expect(parsed.value == .array);
    try std.testing.expectEqual(@as(usize, 2), parsed.value.array.items.len);
    const a0 = parsed.value.array.items[0];
    try std.testing.expectEqual(@as(i64, 111), format.getNestedValue(a0, "id").integer);
    try std.testing.expectEqualStrings("First Story", format.getNestedValue(a0, "title").string);
    const a1 = parsed.value.array.items[1];
    try std.testing.expectEqual(@as(i64, 222), format.getNestedValue(a1, "id").integer);
    try std.testing.expectEqualStrings("Second Story", format.getNestedValue(a1, "title").string);
}

test "fixture v2ex_hot_array_min matches v2ex hot API array shape" {
    const allocator = std.testing.allocator;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, v2ex_hot_array_min, .{});
    defer parsed.deinit();
    try std.testing.expect(parsed.value == .array);
    try std.testing.expectEqual(@as(usize, 2), parsed.value.array.items.len);
    const t0 = parsed.value.array.items[0];
    try std.testing.expectEqualStrings("Hot Topic A", format.getNestedValue(t0, "title").string);
    try std.testing.expectEqualStrings("programming", format.getNestedValue(t0, "node.name").string);
    try std.testing.expectEqualStrings("alice", format.getNestedValue(t0, "author.name").string);
    try std.testing.expect(format.getNestedValue(t0, "replies").integer == 5);
}
