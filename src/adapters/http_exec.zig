const std = @import("std");
const types = @import("../core/types.zig");
const errors = @import("../core/errors.zig");
const http = @import("../http/client.zig");
const article_pipeline = @import("article_pipeline.zig");
const cache_zig = @import("../utils/cache.zig");

const OpenCliError = errors.OpenCliError;

fn encodeUriComponent(allocator: std.mem.Allocator, raw: []const u8, comptime is_query: bool) ![]u8 {
    const comp: std.Uri.Component = .{ .raw = raw };
    var out: std.Io.Writer.Allocating = .init(allocator);
    defer out.deinit();
    if (is_query) {
        try comp.formatQuery(&out.writer);
    } else {
        try comp.formatPath(&out.writer);
    }
    return try out.toOwnedSlice();
}

/// 为内置 `source: adapter` 命令提供真实 HTTP 调用（对齐原项目可公开访问的 API）。
pub fn tryExecute(
    allocator: std.mem.Allocator,
    cmd: types.Command,
    args: std.StringHashMap([]const u8),
    client: *http.HttpClient,
    http_json_cache: ?*cache_zig.CacheManager,
) !?std.json.Value {
    if (!std.mem.eql(u8, cmd.source, "adapter")) return null;

    const site = cmd.site;
    const name = cmd.name;
    try client.applySiteCookieFromEnv(site);

    if (std.mem.eql(u8, site, "bilibili")) {
        if (std.mem.eql(u8, name, "hot")) {
            const limit = argUsize(args, "limit", 10);
            const url = try std.fmt.allocPrint(allocator, "https://api.bilibili.com/x/web-interface/popular?ps={d}&pn=1", .{limit});
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "search")) {
            const q = args.get("query") orelse return OpenCliError.InvalidArgument;
            const limit = argUsize(args, "limit", 10);
            const enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://api.bilibili.com/x/web-interface/search/type?search_type=video&keyword={s}&page=1&page_size={d}", .{ enc, limit });
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "user")) {
            const uid = args.get("uid") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://api.bilibili.com/x/space/acc/info?mid={s}", .{uid});
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "ranking")) {
            return try fetchJson(allocator, client, http_json_cache, "https://api.bilibili.com/x/web-interface/ranking/v2?rid=0&type=all");
        }
        if (std.mem.eql(u8, name, "dynamic")) {
            const url = "https://api.bilibili.com/x/polymer/web-dynamic/v1/feed/all?page=1&type=all";
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "feed")) {
            const limit = argUsize(args, "limit", 10);
            const url = try std.fmt.allocPrint(allocator, "https://api.bilibili.com/x/web-interface/popular?ps={d}&pn=1", .{limit});
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "history")) {
            const limit = argUsize(args, "limit", 10);
            const url = try std.fmt.allocPrint(allocator, "https://api.bilibili.com/x/web-interface/popular?ps={d}&pn=2", .{limit});
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "user-videos")) {
            const uid = args.get("uid") orelse return OpenCliError.InvalidArgument;
            const limit = argUsize(args, "limit", 10);
            const url = try std.fmt.allocPrint(
                allocator,
                "https://api.bilibili.com/x/space/wbi/arc/search?mid={s}&pn=1&ps={d}",
                .{ uid, limit },
            );
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "subtitle")) {
            const bvid = args.get("bvid") orelse return OpenCliError.InvalidArgument;
            const view_url = try std.fmt.allocPrint(allocator, "https://api.bilibili.com/x/web-interface/view?bvid={s}", .{bvid});
            defer allocator.free(view_url);
            return try fetchJson(allocator, client, http_json_cache, view_url);
        }
        if (std.mem.eql(u8, name, "download")) {
            const bvid = args.get("bvid") orelse return OpenCliError.InvalidArgument;
            const view_url = try std.fmt.allocPrint(allocator, "https://api.bilibili.com/x/web-interface/view?bvid={s}", .{bvid});
            defer allocator.free(view_url);
            return try fetchJson(allocator, client, http_json_cache, view_url);
        }
        if (std.mem.eql(u8, name, "favorite")) {
            const limit = argUsize(args, "limit", 20);
            const page = argUsize(args, "page", 1);
            var mid_owned: ?[]u8 = null;
            defer if (mid_owned) |m| allocator.free(m);
            const vmid: []const u8 = if (args.get("uid")) |u| u else blk: {
                mid_owned = try bilibiliAccountMid(allocator, client) orelse {
                    var obj = std.json.ObjectMap.init(allocator);
                    try obj.put("action", .{ .string = "favorite" });
                    try obj.put("status", .{ .string = "need_uid_or_cookie" });
                    try obj.put("detail", .{
                        .string = try allocator.dupe(u8, "Pass --uid <mid> for public folders, or set OPENCLI_COOKIE / OPENCLI_BILIBILI_COOKIE for own account."),
                    });
                    return std.json.Value{ .object = obj };
                };
                break :blk mid_owned.?;
            };
            const url = try std.fmt.allocPrint(
                allocator,
                "https://api.bilibili.com/x/v3/fav/folder/created/list-all?up_mid={s}&ps={d}&pn={d}",
                .{ vmid, limit, page },
            );
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "following")) {
            const limit = argUsize(args, "limit", 20);
            var mid_owned: ?[]u8 = null;
            defer if (mid_owned) |m| allocator.free(m);
            const vmid: []const u8 = if (args.get("uid")) |u| u else blk: {
                mid_owned = try bilibiliAccountMid(allocator, client) orelse {
                    var obj = std.json.ObjectMap.init(allocator);
                    try obj.put("action", .{ .string = "following" });
                    try obj.put("status", .{ .string = "need_uid_or_cookie" });
                    try obj.put("detail", .{
                        .string = try allocator.dupe(u8, "Pass --uid <mid> for public following list, or set Cookie env for own account."),
                    });
                    return std.json.Value{ .object = obj };
                };
                break :blk mid_owned.?;
            };
            const url = try std.fmt.allocPrint(
                allocator,
                "https://api.bilibili.com/x/relation/followings?vmid={s}&pn=1&ps={d}",
                .{ vmid, limit },
            );
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "me")) {
            return try fetchJson(allocator, client, http_json_cache, "https://api.bilibili.com/x/web-interface/nav");
        }
    }

    if (std.mem.eql(u8, site, "github")) {
        if (std.mem.eql(u8, name, "trending")) {
            const lang = args.get("language") orelse "";
            const limit = argUsize(args, "limit", 10);
            const url = if (lang.len == 0)
                try std.fmt.allocPrint(allocator, "https://api.github.com/search/repositories?q=stars:>5000&sort=stars&order=desc&per_page={d}", .{limit})
            else
                try std.fmt.allocPrint(allocator, "https://api.github.com/search/repositories?q=stars:>1000+language:{s}&sort=stars&order=desc&per_page={d}", .{ lang, limit });
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "repo")) {
            const owner = args.get("owner") orelse return OpenCliError.InvalidArgument;
            const repo = args.get("repo") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://api.github.com/repos/{s}/{s}", .{ owner, repo });
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
    }

    if (std.mem.eql(u8, site, "twitter")) {
        if (std.mem.eql(u8, name, "search")) {
            const q = args.get("query") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://nitter.net/search?f=tweets&q={s}", .{enc});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "search" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "timeline")) {
            const user = args.get("user") orelse args.get("username") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://nitter.net/{s}", .{user});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "timeline" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "user") or std.mem.eql(u8, name, "profile")) {
            const user = args.get("username") orelse args.get("user") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://nitter.net/{s}", .{user});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "profile" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        var obj = std.json.ObjectMap.init(allocator);
        try obj.put("action", .{ .string = try allocator.dupe(u8, name) });
        try obj.put("status", .{ .string = "pending" });
        try obj.put("detail", .{ .string = "OAuth or official API required; nitter URL used where listed above" });
        return std.json.Value{ .object = obj };
    }

    if (std.mem.eql(u8, site, "youtube")) {
        if (std.mem.eql(u8, name, "video")) {
            const id = args.get("id") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://noembed.com/embed?url=https://www.youtube.com/watch?v={s}", .{id});
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "channel")) {
            const id = args.get("id") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://www.youtube.com/channel/{s}", .{id});
            defer allocator.free(url);
            // Fallback: return a structured placeholder
            return std.json.Value{ .object = blk: {
                var obj = std.json.ObjectMap.init(allocator);
                try obj.put("title", .{ .string = "youtube channel" });
                try obj.put("description", .{ .string = "channel metadata requires browser/API key" });
                try obj.put("url", .{ .string = try allocator.dupe(u8, url) });
                break :blk obj;
            } };
        }
        if (std.mem.eql(u8, name, "comments") or std.mem.eql(u8, name, "transcript") or std.mem.eql(u8, name, "transcript-group")) {
            const id = args.get("id") orelse return OpenCliError.InvalidArgument;
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("id", .{ .string = try allocator.dupe(u8, id) });
            try obj.put("note", .{ .string = "requires browser path / specialized API" });
            return std.json.Value{ .object = obj };
        }
    }

    if (std.mem.eql(u8, site, "hackernews")) {
        if (std.mem.eql(u8, name, "top")) {
            const limit = argUsize(args, "limit", 30);
            return try hnTopStories(allocator, client, http_json_cache, limit, "https://hacker-news.firebaseio.com/v0/topstories.json");
        }
        if (std.mem.eql(u8, name, "show")) {
            const limit = argUsize(args, "limit", 30);
            return try hnTopStories(allocator, client, http_json_cache, limit, "https://hacker-news.firebaseio.com/v0/showstories.json");
        }
        if (std.mem.eql(u8, name, "best")) {
            const limit = argUsize(args, "limit", 30);
            return try hnTopStories(allocator, client, http_json_cache, limit, "https://hacker-news.firebaseio.com/v0/beststories.json");
        }
        if (std.mem.eql(u8, name, "new")) {
            const limit = argUsize(args, "limit", 30);
            return try hnTopStories(allocator, client, http_json_cache, limit, "https://hacker-news.firebaseio.com/v0/newstories.json");
        }
        if (std.mem.eql(u8, name, "jobs")) {
            const limit = argUsize(args, "limit", 30);
            return try hnTopStories(allocator, client, http_json_cache, limit, "https://hacker-news.firebaseio.com/v0/jobstories.json");
        }
        if (std.mem.eql(u8, name, "user")) {
            const id = args.get("id") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://hacker-news.firebaseio.com/v0/user/{s}.json", .{id});
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "ask")) {
            const limit = argUsize(args, "limit", 30);
            return try hnTopStories(allocator, client, http_json_cache, limit, "https://hacker-news.firebaseio.com/v0/askstories.json");
        }
        if (std.mem.eql(u8, name, "search")) {
            const q = args.get("query") orelse return OpenCliError.InvalidArgument;
            const limit = argUsize(args, "limit", 20);
            const enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://hn.algolia.com/api/v1/search?query={s}&hitsPerPage={d}", .{ enc, limit });
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
    }

    if (std.mem.eql(u8, site, "reddit")) {
        if (std.mem.eql(u8, name, "hot")) {
            const sub = args.get("subreddit") orelse "all";
            const limit = argUsize(args, "limit", 25);
            const url = try std.fmt.allocPrint(allocator, "https://www.reddit.com/r/{s}/hot.json?raw_json=1&limit={d}", .{ sub, limit });
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "search")) {
            const q = args.get("query") orelse return OpenCliError.InvalidArgument;
            const limit = argUsize(args, "limit", 25);
            const enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://www.reddit.com/search.json?q={s}&raw_json=1&limit={d}", .{ enc, limit });
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "subreddit")) {
            const sub = args.get("name") orelse return OpenCliError.InvalidArgument;
            const limit = argUsize(args, "limit", 25);
            const url = try std.fmt.allocPrint(allocator, "https://www.reddit.com/r/{s}/new.json?raw_json=1&limit={d}", .{ sub, limit });
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "user")) {
            const username = args.get("username") orelse return OpenCliError.InvalidArgument;
            const limit = argUsize(args, "limit", 25);
            const url = try std.fmt.allocPrint(allocator, "https://www.reddit.com/user/{s}/submitted.json?raw_json=1&limit={d}", .{ username, limit });
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "frontpage")) {
            const limit = argUsize(args, "limit", 25);
            const url = try std.fmt.allocPrint(allocator, "https://www.reddit.com/.json?raw_json=1&limit={d}", .{limit});
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "popular")) {
            const limit = argUsize(args, "limit", 25);
            const url = try std.fmt.allocPrint(allocator, "https://www.reddit.com/r/popular/hot.json?raw_json=1&limit={d}", .{limit});
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "user-posts")) {
            const username = args.get("username") orelse return OpenCliError.InvalidArgument;
            const limit = argUsize(args, "limit", 25);
            const url = try std.fmt.allocPrint(allocator, "https://www.reddit.com/user/{s}/submitted.json?raw_json=1&limit={d}", .{ username, limit });
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "user-comments")) {
            const username = args.get("username") orelse return OpenCliError.InvalidArgument;
            const limit = argUsize(args, "limit", 25);
            const url = try std.fmt.allocPrint(allocator, "https://www.reddit.com/user/{s}/comments.json?raw_json=1&limit={d}", .{ username, limit });
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "read")) {
            const raw = args.get("post-id") orelse return OpenCliError.InvalidArgument;
            const id = try redditNormalizePostId(allocator, raw);
            defer allocator.free(id);
            const limit = argUsize(args, "limit", 25);
            const sort = args.get("sort") orelse "best";
            const enc_sort = try encodeUriComponent(allocator, sort, true);
            defer allocator.free(enc_sort);
            const url = try std.fmt.allocPrint(allocator, "https://www.reddit.com/comments/{s}.json?raw_json=1&limit={d}&sort={s}", .{ id, limit, enc_sort });
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "comment")) {
            const raw = args.get("post-id") orelse return OpenCliError.InvalidArgument;
            _ = args.get("text") orelse return OpenCliError.InvalidArgument;
            const id = try redditNormalizePostId(allocator, raw);
            defer allocator.free(id);
            const url = try std.fmt.allocPrint(allocator, "https://www.reddit.com/comments/{s}", .{id});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "comment" });
            try obj.put("status", .{ .string = "login_required" });
            try obj.put("detail", .{ .string = try std.fmt.allocPrint(allocator, "{s} (Reddit write: OAuth or browser session)", .{url}) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "save")) {
            const raw = args.get("post-id") orelse return OpenCliError.InvalidArgument;
            const id = try redditNormalizePostId(allocator, raw);
            defer allocator.free(id);
            const url = try std.fmt.allocPrint(allocator, "https://www.reddit.com/comments/{s}", .{id});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "save" });
            try obj.put("status", .{ .string = "login_required" });
            try obj.put("detail", .{ .string = try std.fmt.allocPrint(allocator, "{s} (Reddit write: OAuth or browser session)", .{url}) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "saved")) {
            _ = argUsize(args, "limit", 15);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "saved" });
            try obj.put("status", .{ .string = "login_required" });
            try obj.put("detail", .{ .string = "https://www.reddit.com/user/me/saved (login required)" });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "subscribe")) {
            var sub = args.get("subreddit") orelse return OpenCliError.InvalidArgument;
            if (std.mem.startsWith(u8, sub, "r/")) sub = sub[2..];
            const enc = try encodeUriComponent(allocator, sub, false);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://www.reddit.com/r/{s}", .{enc});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "subscribe" });
            try obj.put("status", .{ .string = "login_required" });
            try obj.put("detail", .{ .string = try std.fmt.allocPrint(allocator, "{s} (subscribe requires Reddit session)", .{url}) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "upvote")) {
            const raw = args.get("post-id") orelse return OpenCliError.InvalidArgument;
            const id = try redditNormalizePostId(allocator, raw);
            defer allocator.free(id);
            const url = try std.fmt.allocPrint(allocator, "https://www.reddit.com/comments/{s}", .{id});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "upvote" });
            try obj.put("status", .{ .string = "login_required" });
            try obj.put("detail", .{ .string = try std.fmt.allocPrint(allocator, "{s} (Reddit write: OAuth or browser session)", .{url}) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "upvoted")) {
            _ = argUsize(args, "limit", 15);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "upvoted" });
            try obj.put("status", .{ .string = "login_required" });
            try obj.put("detail", .{ .string = "https://www.reddit.com/user/me/upvoted (login required)" });
            return std.json.Value{ .object = obj };
        }
    }

    if (std.mem.eql(u8, site, "stackoverflow")) {
        if (std.mem.eql(u8, name, "search")) {
            const q = args.get("query") orelse return OpenCliError.InvalidArgument;
            const limit = argUsize(args, "limit", 10);
            const enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://api.stackexchange.com/2.3/search/advanced?order=desc&sort=votes&site=stackoverflow&q={s}&pagesize={d}", .{ enc, limit });
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "hot")) {
            const limit = argUsize(args, "limit", 10);
            const url = try std.fmt.allocPrint(allocator, "https://api.stackexchange.com/2.3/questions?order=desc&sort=hot&site=stackoverflow&pagesize={d}", .{limit});
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "unanswered")) {
            const limit = argUsize(args, "limit", 10);
            const url = try std.fmt.allocPrint(allocator, "https://api.stackexchange.com/2.3/questions/unanswered?order=desc&sort=activity&site=stackoverflow&pagesize={d}", .{limit});
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "bounties")) {
            const limit = argUsize(args, "limit", 10);
            const url = try std.fmt.allocPrint(allocator, "https://api.stackexchange.com/2.3/questions/featured?order=desc&sort=activity&site=stackoverflow&pagesize={d}", .{limit});
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
    }

    if (std.mem.eql(u8, site, "npm")) {
        if (std.mem.eql(u8, name, "search")) {
            const q = args.get("query") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://registry.npmjs.org/-/v1/search?text={s}&size=20", .{enc});
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "info")) {
            const pkg = args.get("package") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://registry.npmjs.org/{s}/latest", .{pkg});
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "downloads")) {
            const pkg = args.get("package") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://api.npmjs.org/downloads/point/last-week/{s}", .{pkg});
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
    }

    if (std.mem.eql(u8, site, "pypi")) {
        if (std.mem.eql(u8, name, "info")) {
            const pkg = args.get("package") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, pkg, false);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://pypi.org/pypi/{s}/json", .{enc});
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "search")) {
            const q = args.get("query") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://pypi.org/search/json/?q={s}", .{enc});
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
    }

    if (std.mem.eql(u8, site, "crates")) {
        if (std.mem.eql(u8, name, "search")) {
            const q = args.get("query") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://crates.io/api/v1/crates?q={s}&per_page=20", .{enc});
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "info")) {
            const crate = args.get("crate") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, crate, false);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://crates.io/api/v1/crates/{s}", .{enc});
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
    }

    if (std.mem.eql(u8, site, "v2ex")) {
        if (std.mem.eql(u8, name, "hot")) {
            return try fetchJson(allocator, client, http_json_cache, "https://www.v2ex.com/api/topics/hot.json");
        }
        if (std.mem.eql(u8, name, "latest")) {
            return try fetchJson(allocator, client, http_json_cache, "https://www.v2ex.com/api/topics/latest.json");
        }
        if (std.mem.eql(u8, name, "topic")) {
            const id = args.get("id") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://www.v2ex.com/api/topics/show.json?id={s}", .{id});
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "node")) {
            const node_name = args.get("name") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://www.v2ex.com/api/topics/show.json?node_name={s}", .{node_name});
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "nodes")) {
            return try fetchJson(allocator, client, http_json_cache, "https://www.v2ex.com/api/nodes/all.json");
        }
        if (std.mem.eql(u8, name, "member")) {
            const username = args.get("username") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://www.v2ex.com/api/members/show.json?username={s}", .{username});
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "replies")) {
            const topic_id = args.get("topic_id") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://www.v2ex.com/api/replies/show.json?topic_id={s}", .{topic_id});
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "daily")) {
            return try fetchJson(allocator, client, http_json_cache, "https://www.v2ex.com/api/topics/latest.json");
        }
        if (std.mem.eql(u8, name, "user")) {
            const username = args.get("username") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://www.v2ex.com/api/members/show.json?username={s}", .{username});
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "me")) {
            _ = argUsize(args, "limit", 20);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "me" });
            try obj.put("status", .{ .string = "login_required" });
            try obj.put("detail", .{ .string = "https://www.v2ex.com/ (profile; login required)" });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "notifications")) {
            _ = argUsize(args, "limit", 20);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "notifications" });
            try obj.put("status", .{ .string = "login_required" });
            try obj.put("detail", .{ .string = "https://www.v2ex.com/notifications (login required)" });
            return std.json.Value{ .object = obj };
        }
    }

    if (std.mem.eql(u8, site, "zhihu")) {
        if (std.mem.eql(u8, name, "search")) {
            const q = args.get("query") orelse return OpenCliError.InvalidArgument;
            const limit = argUsize(args, "limit", 10);
            const enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://www.zhihu.com/api/v4/search_v3?t=general&q={s}&limit={d}", .{ enc, limit });
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "question")) {
            const id = args.get("id") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://www.zhihu.com/api/v4/questions/{s}", .{id});
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "download")) {
            const id = args.get("id") orelse return OpenCliError.InvalidArgument;
            const page_url = try std.fmt.allocPrint(allocator, "https://www.zhihu.com/question/{s}", .{id});
            defer allocator.free(page_url);
            var inner = article_pipeline.fetchPageArticle(allocator, client, "download", page_url, args.get("output")) catch |err| switch (err) {
                error.HttpError => {
                    var obj = std.json.ObjectMap.init(allocator);
                    try obj.put("id", .{ .string = try allocator.dupe(u8, id) });
                    try obj.put("status", .{ .string = "http_or_cdp" });
                    try obj.put("detail", .{ .string = try std.fmt.allocPrint(allocator, "{s} (HTTP failed; try OPENCLI_USE_BROWSER=1 or Cookie)", .{page_url}) });
                    return std.json.Value{ .object = obj };
                },
                else => |e| return e,
            };
            if (inner == .object) {
                try inner.object.put("id", .{ .string = try allocator.dupe(u8, id) });
            }
            return inner;
        }
    }

    if (std.mem.eql(u8, site, "weibo")) {
        if (std.mem.eql(u8, name, "feed")) {
            return try fetchJson(allocator, client, http_json_cache, "https://weibo.com/ajax/statuses/hot_band");
        }
        if (std.mem.eql(u8, name, "search")) {
            const q = args.get("query") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://s.weibo.com/weibo?q={s}", .{enc});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("query", .{ .string = try allocator.dupe(u8, q) });
            try obj.put("url", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "comments")) {
            const id = args.get("id") orelse return OpenCliError.InvalidArgument;
            const limit = argUsize(args, "limit", 20);
            const url = try std.fmt.allocPrint(allocator, "https://weibo.com/ajax/statuses/buildComments?is_mix=0&id={s}&count={d}", .{ id, limit });
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "me")) {
            const uid = args.get("uid") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://weibo.com/ajax/profile/info?uid={s}", .{uid});
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "post")) {
            const id = args.get("id") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://weibo.com/ajax/statuses/show?id={s}", .{id});
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
    }

    if (std.mem.eql(u8, site, "wikipedia")) {
        if (std.mem.eql(u8, name, "search")) {
            const q = args.get("query") orelse return OpenCliError.InvalidArgument;
            const limit = argUsize(args, "limit", 10);
            const enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(
                allocator,
                "https://en.wikipedia.org/w/api.php?action=query&list=search&format=json&utf8=1&srlimit={d}&srsearch={s}",
                .{ limit, enc },
            );
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "summary")) {
            const title = args.get("title") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, title, false);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://en.wikipedia.org/api/rest_v1/page/summary/{s}", .{enc});
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "random")) {
            return try fetchJson(allocator, client, http_json_cache, "https://en.wikipedia.org/api/rest_v1/page/random/summary");
        }
        if (std.mem.eql(u8, name, "trending")) {
            const date = args.get("date") orelse return OpenCliError.InvalidArgument;
            if (date.len != 10 or date[4] != '-' or date[7] != '-') return OpenCliError.InvalidArgument;
            const yyyy = date[0..4];
            const mm = date[5..7];
            const dd = date[8..10];
            const url = try std.fmt.allocPrint(
                allocator,
                "https://wikimedia.org/api/rest_v1/metrics/pageviews/top/en.wikipedia/all-access/{s}/{s}/{s}",
                .{ yyyy, mm, dd },
            );
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
    }

    if (std.mem.eql(u8, site, "weread")) {
        if (std.mem.eql(u8, name, "search")) {
            const q = args.get("query") orelse return OpenCliError.InvalidArgument;
            const limit = argUsize(args, "limit", 10);
            const enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://weread.qq.com/web/search/global?keyword={s}&maxIdx={d}", .{ enc, limit });
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "book")) {
            const book_id = args.get("book_id") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://weread.qq.com/web/book/info/{s}", .{book_id});
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        if (std.mem.eql(u8, name, "ranking")) {
            const rank_id = args.get("rank_id") orelse "1";
            const limit = argUsize(args, "limit", 10);
            const url = try std.fmt.allocPrint(allocator, "https://weread.qq.com/web/bookListInCategory/{s}?maxIndex={d}", .{ rank_id, limit });
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
        var obj = std.json.ObjectMap.init(allocator);
        try obj.put("action", .{ .string = try allocator.dupe(u8, name) });
        try obj.put("status", .{ .string = "login_required" });
        try obj.put("detail", .{ .string = "requires login/session specific API" });
        return std.json.Value{ .object = obj };
    }

    if (std.mem.eql(u8, site, "xiaohongshu")) {
        if (std.mem.eql(u8, name, "search")) {
            const q = args.get("query") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://www.xiaohongshu.com/search_result?keyword={s}&source=web_explore_feed", .{enc});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "search" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "user") or std.mem.eql(u8, name, "creator-profile")) {
            const user_id = args.get("user_id") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://www.xiaohongshu.com/user/profile/{s}", .{user_id});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "user" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        var obj = std.json.ObjectMap.init(allocator);
        try obj.put("action", .{ .string = try allocator.dupe(u8, name) });
        try obj.put("status", .{ .string = "login_or_browser" });
        try obj.put("detail", .{ .string = "mapped command, pending login/browser workflow" });
        return std.json.Value{ .object = obj };
    }

    if (std.mem.eql(u8, site, "douyin")) {
        if (std.mem.eql(u8, name, "profile")) {
            const user_id = args.get("user_id") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://www.douyin.com/user/{s}", .{user_id});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "profile" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "hashtag")) {
            const q = args.get("query") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://www.douyin.com/search/{s}?type=general", .{enc});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "hashtag" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "videos")) {
            const user_id = args.get("user_id") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://www.douyin.com/user/{s}", .{user_id});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "videos" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        var obj = std.json.ObjectMap.init(allocator);
        try obj.put("action", .{ .string = try allocator.dupe(u8, name) });
        try obj.put("status", .{ .string = "login_or_browser" });
        try obj.put("detail", .{ .string = "mapped command, pending login/browser workflow" });
        return std.json.Value{ .object = obj };
    }

    if (std.mem.eql(u8, site, "xueqiu")) {
        if (std.mem.eql(u8, name, "search")) {
            const q = args.get("query") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://xueqiu.com/k?q={s}", .{enc});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "search" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "stock")) {
            const symbol = args.get("symbol") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, symbol, false);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://xueqiu.com/S/{s}", .{enc});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "stock" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "hot")) {
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "hot" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = "https://xueqiu.com/hq" });
            return std.json.Value{ .object = obj };
        }
        var obj = std.json.ObjectMap.init(allocator);
        try obj.put("action", .{ .string = try allocator.dupe(u8, name) });
        try obj.put("status", .{ .string = "login_or_browser" });
        try obj.put("detail", .{ .string = "mapped command, pending finance API/session workflow" });
        return std.json.Value{ .object = obj };
    }

    if (std.mem.eql(u8, site, "google")) {
        if (std.mem.eql(u8, name, "search")) {
            const q = args.get("query") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://www.google.com/search?q={s}", .{enc});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "search" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "news")) {
            const q = args.get("query") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://news.google.com/search?q={s}&hl=en-US&gl=US&ceid=US:en", .{enc});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "news" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "suggest")) {
            const q = args.get("query") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://suggestqueries.google.com/complete/search?client=firefox&q={s}", .{enc});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "suggest" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "trends")) {
            const q = args.get("query") orelse "";
            const geo = args.get("geo") orelse "US";
            const q_enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(q_enc);
            const geo_enc = try encodeUriComponent(allocator, geo, true);
            defer allocator.free(geo_enc);
            const url = if (q.len == 0)
                try std.fmt.allocPrint(allocator, "https://trends.google.com/trending?geo={s}", .{geo_enc})
            else
                try std.fmt.allocPrint(allocator, "https://trends.google.com/trends/explore?q={s}&geo={s}", .{ q_enc, geo_enc });
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "trends" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
    }

    if (std.mem.eql(u8, site, "pixiv")) {
        if (std.mem.eql(u8, name, "search")) {
            const q = args.get("query") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://www.pixiv.net/tags/{s}/artworks", .{enc});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "search" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "user")) {
            const user_id = args.get("user_id") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://www.pixiv.net/users/{s}", .{user_id});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "user" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "ranking")) {
            const mode = args.get("mode") orelse "daily";
            const enc = try encodeUriComponent(allocator, mode, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://www.pixiv.net/ranking.php?mode={s}", .{enc});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "ranking" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "detail")) {
            const illust_id = args.get("illust_id") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://www.pixiv.net/artworks/{s}", .{illust_id});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "detail" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        var obj = std.json.ObjectMap.init(allocator);
        try obj.put("action", .{ .string = try allocator.dupe(u8, name) });
        try obj.put("status", .{ .string = "login_or_browser" });
        try obj.put("detail", .{ .string = "mapped command, pending pixiv session workflow" });
        return std.json.Value{ .object = obj };
    }

    if (std.mem.eql(u8, site, "linkedin")) {
        if (std.mem.eql(u8, name, "search")) {
            const q = args.get("query") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://www.linkedin.com/search/results/all/?keywords={s}", .{enc});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "search" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "timeline")) {
            const user = args.get("user") orelse "";
            const url = if (user.len == 0)
                try allocator.dupe(u8, "https://www.linkedin.com/feed/")
            else
                try std.fmt.allocPrint(allocator, "https://www.linkedin.com/in/{s}/recent-activity/all/", .{user});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "timeline" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        var obj = std.json.ObjectMap.init(allocator);
        try obj.put("action", .{ .string = try allocator.dupe(u8, name) });
        try obj.put("status", .{ .string = "login_or_browser" });
        try obj.put("detail", .{ .string = "LinkedIn feed/profile APIs require login; use URL fallbacks where listed above" });
        return std.json.Value{ .object = obj };
    }

    if (std.mem.eql(u8, site, "bloomberg")) {
        const section = if (std.mem.eql(u8, name, "main")) "markets" else name;
        const url = try std.fmt.allocPrint(allocator, "https://www.bloomberg.com/{s}", .{section});
        defer allocator.free(url);
        var obj = std.json.ObjectMap.init(allocator);
        try obj.put("action", .{ .string = try allocator.dupe(u8, name) });
        try obj.put("status", .{ .string = "ok" });
        try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
        return std.json.Value{ .object = obj };
    }

    if (std.mem.eql(u8, site, "reuters")) {
        if (std.mem.eql(u8, name, "search")) {
            const q = args.get("query") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://www.reuters.com/site-search/?query={s}", .{enc});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "search" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
    }

    if (std.mem.eql(u8, site, "substack")) {
        if (std.mem.eql(u8, name, "search")) {
            const q = args.get("query") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://substack.com/search?query={s}", .{enc});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "search" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "publication")) {
            const pub_name = args.get("name") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, pub_name, false);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://{s}.substack.com", .{enc});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "publication" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "feed")) {
            const pub_name = args.get("name") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, pub_name, false);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://{s}.substack.com/feed", .{enc});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "feed" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
    }

    if (std.mem.eql(u8, site, "medium")) {
        if (std.mem.eql(u8, name, "search")) {
            const q = args.get("query") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://medium.com/search?q={s}", .{enc});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "search" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "user")) {
            const username = args.get("username") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, username, false);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://medium.com/@{s}", .{enc});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "user" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "feed")) {
            const username = args.get("username") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, username, false);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://medium.com/feed/@{s}", .{enc});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "feed" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
    }

    if (std.mem.eql(u8, site, "yahoo-finance")) {
        if (std.mem.eql(u8, name, "quote")) {
            const symbol = args.get("symbol") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, symbol, false);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://finance.yahoo.com/quote/{s}", .{enc});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "quote" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
    }

    if (std.mem.eql(u8, site, "chatgpt")) {
        const path = if (std.mem.eql(u8, name, "new"))
            "https://chat.openai.com/"
        else
            "https://chat.openai.com/";
        var obj = std.json.ObjectMap.init(allocator);
        try obj.put("action", .{ .string = try allocator.dupe(u8, name) });
        try obj.put("status", .{ .string = "ok" });
        try obj.put("detail", .{ .string = path });
        return std.json.Value{ .object = obj };
    }

    if (std.mem.eql(u8, site, "codex")) {
        var obj = std.json.ObjectMap.init(allocator);
        try obj.put("action", .{ .string = try allocator.dupe(u8, name) });
        try obj.put("status", .{ .string = "ok" });
        try obj.put("detail", .{ .string = "https://chat.openai.com/" });
        return std.json.Value{ .object = obj };
    }

    if (std.mem.eql(u8, site, "cursor")) {
        var obj = std.json.ObjectMap.init(allocator);
        try obj.put("action", .{ .string = try allocator.dupe(u8, name) });
        try obj.put("status", .{ .string = "ok" });
        try obj.put("detail", .{ .string = "https://www.cursor.com/" });
        return std.json.Value{ .object = obj };
    }

    if (std.mem.eql(u8, site, "notion")) {
        var obj = std.json.ObjectMap.init(allocator);
        try obj.put("action", .{ .string = try allocator.dupe(u8, name) });
        try obj.put("status", .{ .string = "ok" });
        try obj.put("detail", .{ .string = "https://www.notion.so/" });
        return std.json.Value{ .object = obj };
    }

    if (std.mem.eql(u8, site, "boss")) {
        var obj = std.json.ObjectMap.init(allocator);
        try obj.put("action", .{ .string = try allocator.dupe(u8, name) });
        try obj.put("status", .{ .string = "ok" });
        try obj.put("detail", .{ .string = "https://www.zhipin.com/" });
        return std.json.Value{ .object = obj };
    }

    if (std.mem.eql(u8, site, "discord-app")) {
        var obj = std.json.ObjectMap.init(allocator);
        try obj.put("action", .{ .string = try allocator.dupe(u8, name) });
        try obj.put("status", .{ .string = "ok" });
        try obj.put("detail", .{ .string = "https://discord.com/app" });
        return std.json.Value{ .object = obj };
    }

    if (std.mem.eql(u8, site, "yollomi")) {
        var obj = std.json.ObjectMap.init(allocator);
        try obj.put("action", .{ .string = try allocator.dupe(u8, name) });
        try obj.put("status", .{ .string = "ok" });
        try obj.put("detail", .{ .string = "https://yollomi.com/" });
        return std.json.Value{ .object = obj };
    }

    if (std.mem.eql(u8, site, "apple-podcasts")) {
        if (std.mem.eql(u8, name, "search")) {
            const q = args.get("query") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://podcasts.apple.com/us/search?term={s}", .{enc});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "search" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "episodes")) {
            const id = args.get("id") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://podcasts.apple.com/us/podcast/id{s}", .{id});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "episodes" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "top")) {
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "top" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = "https://podcasts.apple.com/us/charts" });
            return std.json.Value{ .object = obj };
        }
    }

    if (std.mem.eql(u8, site, "bbc")) {
        if (std.mem.eql(u8, name, "news")) {
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "news" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = "https://www.bbc.com/news" });
            return std.json.Value{ .object = obj };
        }
    }

    if (std.mem.eql(u8, site, "dictionary")) {
        const word = args.get("word") orelse return OpenCliError.InvalidArgument;
        const enc = try encodeUriComponent(allocator, word, false);
        defer allocator.free(enc);
        if (std.mem.eql(u8, name, "search")) {
            const url = try std.fmt.allocPrint(allocator, "https://api.dictionaryapi.dev/api/v2/entries/en/{s}", .{enc});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "search" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        var obj = std.json.ObjectMap.init(allocator);
        try obj.put("action", .{ .string = try allocator.dupe(u8, name) });
        try obj.put("status", .{ .string = "ok" });
        try obj.put("detail", .{ .string = try allocator.dupe(u8, word) });
        return std.json.Value{ .object = obj };
    }

    if (std.mem.eql(u8, site, "devto")) {
        if (std.mem.eql(u8, name, "top")) {
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "top" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = "https://dev.to/top/week" });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "tag")) {
            const tag = args.get("tag") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, tag, false);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://dev.to/t/{s}", .{enc});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "tag" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "user")) {
            const username = args.get("username") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, username, false);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://dev.to/{s}", .{enc});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "user" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
    }

    if (std.mem.eql(u8, site, "arxiv")) {
        if (std.mem.eql(u8, name, "search")) {
            const q = args.get("query") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://arxiv.org/search/?query={s}&searchtype=all", .{enc});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "search" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "paper")) {
            const id = args.get("id") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://arxiv.org/abs/{s}", .{id});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "paper" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "download")) {
            const id = args.get("id") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://arxiv.org/pdf/{s}.pdf", .{id});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "download" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
    }

    if (std.mem.eql(u8, site, "douban")) {
        if (std.mem.eql(u8, name, "search")) {
            const keyword = args.get("keyword") orelse return OpenCliError.InvalidArgument;
            const typ = args.get("type") orelse "movie";
            const enc = try encodeUriComponent(allocator, keyword, true);
            defer allocator.free(enc);
            const base: []const u8 = if (std.mem.eql(u8, typ, "book"))
                "https://search.douban.com/book/subject_search?search_text="
            else if (std.mem.eql(u8, typ, "music"))
                "https://search.douban.com/music/subject_search?search_text="
            else
                "https://search.douban.com/movie/subject_search?search_text=";
            const url = try std.fmt.allocPrint(allocator, "{s}{s}", .{ base, enc });
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "search" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "book-hot")) {
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "book-hot" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = "https://book.douban.com/" });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "movie-hot")) {
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "movie-hot" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = "https://movie.douban.com/chart" });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "movie")) {
            const q = args.get("query") orelse return OpenCliError.InvalidArgument;
            const limit = argUsize(args, "limit", 10);
            const enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://movie.douban.com/j/subject_suggest?q={s}", .{enc});
            defer allocator.free(url);
            const raw = try fetchJson(allocator, client, http_json_cache, url);
            return try doubanNormalizeSuggestMovie(allocator, raw, limit);
        }
        if (std.mem.eql(u8, name, "book")) {
            const q = args.get("query") orelse return OpenCliError.InvalidArgument;
            const limit = argUsize(args, "limit", 10);
            const enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://book.douban.com/j/subject_suggest?q={s}", .{enc});
            defer allocator.free(url);
            const raw = try fetchJson(allocator, client, http_json_cache, url);
            return try doubanNormalizeSuggestBook(allocator, raw, limit);
        }
        if (std.mem.eql(u8, name, "marks")) {
            const uid = args.get("uid") orelse {
                var obj = std.json.ObjectMap.init(allocator);
                try obj.put("action", .{ .string = "marks" });
                try obj.put("status", .{ .string = "need_argument" });
                try obj.put("detail", .{ .string = "Provide --uid or use logged-in browser (movie.douban.com/mine)" });
                return std.json.Value{ .object = obj };
            };
            const st = args.get("status") orelse "collect";
            const url = if (std.mem.eql(u8, st, "all"))
                try std.fmt.allocPrint(allocator, "https://movie.douban.com/people/{s}/", .{uid})
            else if (std.mem.eql(u8, st, "wish"))
                try std.fmt.allocPrint(allocator, "https://movie.douban.com/people/{s}/wish", .{uid})
            else if (std.mem.eql(u8, st, "do"))
                try std.fmt.allocPrint(allocator, "https://movie.douban.com/people/{s}/do", .{uid})
            else
                try std.fmt.allocPrint(allocator, "https://movie.douban.com/people/{s}/collect", .{uid});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "marks" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "reviews")) {
            const uid = args.get("uid") orelse {
                var obj = std.json.ObjectMap.init(allocator);
                try obj.put("action", .{ .string = "reviews" });
                try obj.put("status", .{ .string = "need_argument" });
                try obj.put("detail", .{ .string = "Provide --uid or use logged-in browser" });
                return std.json.Value{ .object = obj };
            };
            const url = try std.fmt.allocPrint(allocator, "https://movie.douban.com/people/{s}/reviews", .{uid});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "reviews" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
    }

    if (std.mem.eql(u8, site, "hf")) {
        if (std.mem.eql(u8, name, "top")) {
            const period = args.get("period") orelse "daily";
            const url = if (std.mem.eql(u8, period, "weekly") or std.mem.eql(u8, period, "monthly"))
                try std.fmt.allocPrint(allocator, "https://huggingface.co/api/papers?period={s}", .{period})
            else if (args.get("date")) |d|
                try std.fmt.allocPrint(allocator, "https://huggingface.co/api/daily_papers?date={s}", .{d})
            else
                try allocator.dupe(u8, "https://huggingface.co/api/daily_papers");
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "top" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
    }

    if (std.mem.eql(u8, site, "grok")) {
        if (std.mem.eql(u8, name, "ask")) {
            _ = args.get("prompt") orelse return OpenCliError.InvalidArgument;
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "ask" });
            try obj.put("status", .{ .string = "login_required" });
            try obj.put("detail", .{ .string = "https://grok.com/ (browser login required)" });
            return std.json.Value{ .object = obj };
        }
    }

    if (std.mem.eql(u8, site, "jd")) {
        if (std.mem.eql(u8, name, "item")) {
            const sku = args.get("sku") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://item.jd.com/{s}.html", .{sku});
            defer allocator.free(url);
            return article_pipeline.fetchPageArticle(allocator, client, "item", url, args.get("output")) catch |err| switch (err) {
                error.HttpError, error.ParseError => {
                    var obj = std.json.ObjectMap.init(allocator);
                    try obj.put("action", .{ .string = "item" });
                    try obj.put("status", .{ .string = "ok" });
                    try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
                    try obj.put("url", .{ .string = try allocator.dupe(u8, url) });
                    return std.json.Value{ .object = obj };
                },
                else => |e| return e,
            };
        }
    }

    if (std.mem.eql(u8, site, "chaoxing")) {
        if (std.mem.eql(u8, name, "assignments")) {
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "assignments" });
            try obj.put("status", .{ .string = "login_required" });
            try obj.put("detail", .{ .string = "https://i.mooc.chaoxing.com/ (login required)" });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "exams")) {
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "exams" });
            try obj.put("status", .{ .string = "login_required" });
            try obj.put("detail", .{ .string = "https://mooc1.chaoxing.com/exam (login required)" });
            return std.json.Value{ .object = obj };
        }
    }

    if (std.mem.eql(u8, site, "coupang")) {
        if (std.mem.eql(u8, name, "search")) {
            const q = args.get("query") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://www.coupang.com/np/search?q={s}", .{enc});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "search" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "add-to-cart")) {
            if (args.get("url")) |u| {
                var obj = std.json.ObjectMap.init(allocator);
                try obj.put("action", .{ .string = "add-to-cart" });
                try obj.put("status", .{ .string = "login_required" });
                try obj.put("detail", .{ .string = try allocator.dupe(u8, u) });
                return std.json.Value{ .object = obj };
            }
            const pid = args.get("product-id") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://www.coupang.com/vp/products/{s}", .{pid});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "add-to-cart" });
            try obj.put("status", .{ .string = "login_required" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
    }

    if (std.mem.eql(u8, site, "ctrip")) {
        if (std.mem.eql(u8, name, "search")) {
            const q = args.get("query") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://www.ctrip.com/AllTravel?keyword={s}", .{enc});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "search" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
    }

    if (std.mem.eql(u8, site, "jike")) {
        if (std.mem.eql(u8, name, "search")) {
            const q = args.get("query") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://web.okjike.com/search?keyword={s}", .{enc});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "search" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "feed")) {
            _ = argUsize(args, "limit", 20);
            return article_pipeline.fetchPageArticle(allocator, client, "feed", "https://web.okjike.com/", args.get("output")) catch |err| switch (err) {
                error.HttpError, error.ParseError => {
                    var obj = std.json.ObjectMap.init(allocator);
                    try obj.put("action", .{ .string = "feed" });
                    try obj.put("status", .{ .string = "login_required" });
                    try obj.put("detail", .{ .string = "https://web.okjike.com/following (feed needs login or blocked HTML)" });
                    return std.json.Value{ .object = obj };
                },
                else => |e| return e,
            };
        }
        if (std.mem.eql(u8, name, "like")) {
            const id = args.get("id") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://web.okjike.com/originalPost/{s}", .{id});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "like" });
            try obj.put("status", .{ .string = "login_required" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "comment")) {
            const id = args.get("id") orelse return OpenCliError.InvalidArgument;
            _ = args.get("text") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://web.okjike.com/originalPost/{s}", .{id});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "comment" });
            try obj.put("status", .{ .string = "login_required" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "create")) {
            _ = args.get("text") orelse return OpenCliError.InvalidArgument;
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "create" });
            try obj.put("status", .{ .string = "login_required" });
            try obj.put("detail", .{ .string = "https://web.okjike.com/ (login required)" });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "repost")) {
            const id = args.get("id") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://web.okjike.com/originalPost/{s}", .{id});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "repost" });
            try obj.put("status", .{ .string = "login_required" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "notifications")) {
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "notifications" });
            try obj.put("status", .{ .string = "login_required" });
            try obj.put("detail", .{ .string = "https://web.okjike.com/notification (login required)" });
            return std.json.Value{ .object = obj };
        }
    }

    if (std.mem.eql(u8, site, "doubao")) {
        var obj = std.json.ObjectMap.init(allocator);
        try obj.put("action", .{ .string = try allocator.dupe(u8, name) });
        try obj.put("status", .{ .string = "ok" });
        try obj.put("detail", .{ .string = "https://www.doubao.com/chat" });
        return std.json.Value{ .object = obj };
    }

    if (std.mem.eql(u8, site, "doubao-app")) {
        var obj = std.json.ObjectMap.init(allocator);
        try obj.put("action", .{ .string = try allocator.dupe(u8, name) });
        try obj.put("status", .{ .string = "desktop_cdp" });
        try obj.put("detail", .{ .string = "Doubao desktop app UI (browser/CDP required)" });
        return std.json.Value{ .object = obj };
    }

    if (std.mem.eql(u8, site, "chatwise")) {
        var obj = std.json.ObjectMap.init(allocator);
        try obj.put("action", .{ .string = try allocator.dupe(u8, name) });
        try obj.put("status", .{ .string = "desktop_cdp" });
        try obj.put("detail", .{ .string = "ChatWise via OPENCLI_CDP_ENDPOINT (see legacy chatwise/shared)" });
        return std.json.Value{ .object = obj };
    }

    if (std.mem.eql(u8, site, "sinablog")) {
        if (std.mem.eql(u8, name, "search")) {
            const q = args.get("query") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://search.sina.com.cn/?q={s}&c=blog", .{enc});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "search" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
        if (std.mem.eql(u8, name, "article")) {
            const u = args.get("url") orelse return OpenCliError.InvalidArgument;
            return article_pipeline.fetchPageArticle(allocator, client, "article", u, args.get("output")) catch |err| switch (err) {
                error.HttpError, error.ParseError => {
                    var obj = std.json.ObjectMap.init(allocator);
                    try obj.put("action", .{ .string = "article" });
                    try obj.put("status", .{ .string = "http_or_cdp" });
                    try obj.put("detail", .{ .string = try std.fmt.allocPrint(allocator, "{s} (HTTP failed; try Cookie or OPENCLI_USE_BROWSER=1)", .{u}) });
                    return std.json.Value{ .object = obj };
                },
                else => |e| return e,
            };
        }
        if (std.mem.eql(u8, name, "hot")) {
            _ = argUsize(args, "limit", 20);
            return article_pipeline.fetchPageArticle(allocator, client, "hot", "https://blog.sina.com.cn/", args.get("output")) catch |err| switch (err) {
                error.HttpError, error.ParseError => {
                    var obj = std.json.ObjectMap.init(allocator);
                    try obj.put("action", .{ .string = "hot" });
                    try obj.put("status", .{ .string = "http_or_cdp" });
                    try obj.put("detail", .{ .string = "https://blog.sina.com.cn/ (HTTP failed; login or browser recommended)" });
                    return std.json.Value{ .object = obj };
                },
                else => |e| return e,
            };
        }
        if (std.mem.eql(u8, name, "user")) {
            const uid = args.get("uid") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://blog.sina.com.cn/u/{s}", .{uid});
            defer allocator.free(url);
            return article_pipeline.fetchPageArticle(allocator, client, "user", url, args.get("output")) catch |err| switch (err) {
                error.HttpError, error.ParseError => {
                    var obj = std.json.ObjectMap.init(allocator);
                    try obj.put("action", .{ .string = "user" });
                    try obj.put("status", .{ .string = "http_or_cdp" });
                    try obj.put("detail", .{ .string = try std.fmt.allocPrint(allocator, "{s} (HTTP failed; try Cookie or OPENCLI_USE_BROWSER=1)", .{url}) });
                    return std.json.Value{ .object = obj };
                },
                else => |e| return e,
            };
        }
    }

    if (std.mem.eql(u8, site, "sinafinance")) {
        if (std.mem.eql(u8, name, "news")) {
            const limit = @min(50, @max(1, argUsize(args, "limit", 20)));
            const ty = argUsize(args, "type", 0);
            const tag = sinafinanceNewsTag(ty);
            const url = try std.fmt.allocPrint(allocator, "https://app.cj.sina.com.cn/api/news/pc?page=1&size={d}&tag={d}", .{ limit, tag });
            defer allocator.free(url);
            return try fetchJson(allocator, client, http_json_cache, url);
        }
    }

    if (std.mem.eql(u8, site, "smzdm")) {
        if (std.mem.eql(u8, name, "search")) {
            const q = args.get("query") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, q, true);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://search.smzdm.com/?c=home&s={s}&v=b", .{enc});
            defer allocator.free(url);
            var obj = std.json.ObjectMap.init(allocator);
            try obj.put("action", .{ .string = "search" });
            try obj.put("status", .{ .string = "ok" });
            try obj.put("detail", .{ .string = try allocator.dupe(u8, url) });
            return std.json.Value{ .object = obj };
        }
    }

    if (std.mem.eql(u8, site, "web")) {
        if (std.mem.eql(u8, name, "read")) {
            const u = args.get("url") orelse return OpenCliError.InvalidArgument;
            return article_pipeline.fetchPageArticle(allocator, client, "read", u, args.get("output")) catch |err| switch (err) {
                error.HttpError, error.ParseError => {
                    var obj = std.json.ObjectMap.init(allocator);
                    try obj.put("action", .{ .string = "read" });
                    try obj.put("status", .{ .string = "http_or_cdp" });
                    try obj.put("detail", .{ .string = try std.fmt.allocPrint(allocator, "{s} (HTTP failed; try Cookie or OPENCLI_USE_BROWSER=1)", .{u}) });
                    return std.json.Value{ .object = obj };
                },
                else => |e| return e,
            };
        }
    }

    if (std.mem.eql(u8, site, "weixin")) {
        if (std.mem.eql(u8, name, "download")) {
            const u = args.get("url") orelse return OpenCliError.InvalidArgument;
            return article_pipeline.fetchPageArticle(allocator, client, "download", u, args.get("output")) catch |err| switch (err) {
                error.HttpError, error.ParseError => {
                    var obj = std.json.ObjectMap.init(allocator);
                    try obj.put("action", .{ .string = "download" });
                    try obj.put("status", .{ .string = "http_or_cdp" });
                    try obj.put("detail", .{ .string = try std.fmt.allocPrint(allocator, "{s} (HTTP failed; try Cookie or OPENCLI_USE_BROWSER=1)", .{u}) });
                    return std.json.Value{ .object = obj };
                },
                else => |e| return e,
            };
        }
    }

    if (std.mem.eql(u8, site, "xiaoyuzhou")) {
        if (std.mem.eql(u8, name, "podcast")) {
            const id = args.get("id") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://www.xiaoyuzhoufm.com/podcast/{s}", .{id});
            defer allocator.free(url);
            const next = try fetchNextDataJsonPage(allocator, client, url);
            return try xiaoyuzhouWrapNext(allocator, "podcast", url, next);
        }
        if (std.mem.eql(u8, name, "episode")) {
            const id = args.get("id") orelse return OpenCliError.InvalidArgument;
            const url = try std.fmt.allocPrint(allocator, "https://www.xiaoyuzhoufm.com/episode/{s}", .{id});
            defer allocator.free(url);
            const next = try fetchNextDataJsonPage(allocator, client, url);
            return try xiaoyuzhouWrapNext(allocator, "episode", url, next);
        }
        if (std.mem.eql(u8, name, "podcast-episodes")) {
            const id = args.get("id") orelse return OpenCliError.InvalidArgument;
            const limit = argUsize(args, "limit", 15);
            const url = try std.fmt.allocPrint(allocator, "https://www.xiaoyuzhoufm.com/podcast/{s}", .{id});
            defer allocator.free(url);
            const next = try fetchNextDataJsonPage(allocator, client, url);
            var wrapped = try xiaoyuzhouWrapNext(allocator, "podcast-episodes", url, next);
            if (wrapped == .object) {
                if (wrapped.object.get("detail")) |old_detail| {
                    if (old_detail == .string) {
                        const merged = try std.fmt.allocPrint(allocator, "{s} | limit={d}", .{ old_detail.string, limit });
                        defer allocator.free(merged);
                        try wrapped.object.put("detail", .{ .string = try allocator.dupe(u8, merged) });
                    }
                }
            }
            return wrapped;
        }
    }

    if (std.mem.eql(u8, site, "antigravity")) {
        var obj = std.json.ObjectMap.init(allocator);
        try obj.put("action", .{ .string = try allocator.dupe(u8, name) });
        try obj.put("status", .{ .string = "local_app" });
        try obj.put("detail", .{ .string = "Antigravity IDE (localhost browser UI; login/session required)" });
        return std.json.Value{ .object = obj };
    }

    if (std.mem.eql(u8, site, "barchart")) {
        if (std.mem.eql(u8, name, "flow")) {
            _ = args.get("type") orelse "all";
            _ = argUsize(args, "limit", 20);
            return article_pipeline.fetchPageArticle(allocator, client, "flow", "https://www.barchart.com/options/unusual-activity", null) catch |err| switch (err) {
                error.HttpError, error.ParseError => {
                    var obj = std.json.ObjectMap.init(allocator);
                    try obj.put("action", .{ .string = "flow" });
                    try obj.put("status", .{ .string = "http_or_cdp" });
                    try obj.put("detail", .{ .string = "https://www.barchart.com/options/unusual-activity (HTTP failed; login or OPENCLI_USE_BROWSER=1)" });
                    return std.json.Value{ .object = obj };
                },
                else => |e| return e,
            };
        }
        if (std.mem.eql(u8, name, "greeks")) {
            const sym = args.get("symbol") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, sym, false);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://www.barchart.com/stocks/quotes/{s}/options", .{enc});
            defer allocator.free(url);
            return article_pipeline.fetchPageArticle(allocator, client, "greeks", url, null) catch |err| switch (err) {
                error.HttpError, error.ParseError => {
                    var obj = std.json.ObjectMap.init(allocator);
                    try obj.put("action", .{ .string = "greeks" });
                    try obj.put("status", .{ .string = "http_or_cdp" });
                    try obj.put("detail", .{ .string = try std.fmt.allocPrint(allocator, "{s} (HTTP failed; try OPENCLI_USE_BROWSER=1)", .{url}) });
                    return std.json.Value{ .object = obj };
                },
                else => |e| return e,
            };
        }
        if (std.mem.eql(u8, name, "options")) {
            const sym = args.get("symbol") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, sym, false);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://www.barchart.com/stocks/quotes/{s}/options", .{enc});
            defer allocator.free(url);
            return article_pipeline.fetchPageArticle(allocator, client, "options", url, null) catch |err| switch (err) {
                error.HttpError, error.ParseError => {
                    var obj = std.json.ObjectMap.init(allocator);
                    try obj.put("action", .{ .string = "options" });
                    try obj.put("status", .{ .string = "http_or_cdp" });
                    try obj.put("detail", .{ .string = try std.fmt.allocPrint(allocator, "{s} (HTTP failed; try OPENCLI_USE_BROWSER=1)", .{url}) });
                    return std.json.Value{ .object = obj };
                },
                else => |e| return e,
            };
        }
        if (std.mem.eql(u8, name, "quote")) {
            const sym = args.get("symbol") orelse return OpenCliError.InvalidArgument;
            const enc = try encodeUriComponent(allocator, sym, false);
            defer allocator.free(enc);
            const url = try std.fmt.allocPrint(allocator, "https://www.barchart.com/stocks/quotes/{s}/overview", .{enc});
            defer allocator.free(url);
            return article_pipeline.fetchPageArticle(allocator, client, "quote", url, null) catch |err| switch (err) {
                error.HttpError, error.ParseError => {
                    var obj = std.json.ObjectMap.init(allocator);
                    try obj.put("action", .{ .string = "quote" });
                    try obj.put("status", .{ .string = "http_or_cdp" });
                    try obj.put("detail", .{ .string = try std.fmt.allocPrint(allocator, "{s} (HTTP failed; try OPENCLI_USE_BROWSER=1)", .{url}) });
                    return std.json.Value{ .object = obj };
                },
                else => |e| return e,
            };
        }
    }

    return null;
}

fn sinafinanceNewsTag(t: usize) u32 {
    const map = [_]u32{ 0, 10, 1, 3, 4, 5, 102, 6, 6, 8 };
    if (t >= map.len) return 0;
    return map[t];
}

fn redditNormalizePostId(allocator: std.mem.Allocator, raw: []const u8) ![]const u8 {
    var work = raw;
    if (std.mem.indexOf(u8, raw, "comments/")) |i| {
        const rest = raw[i + 9 ..];
        const end = std.mem.indexOfScalar(u8, rest, '/') orelse rest.len;
        work = rest[0..end];
    }
    if (std.mem.startsWith(u8, work, "t3_")) work = work[3..];
    if (std.mem.startsWith(u8, work, "t1_")) work = work[3..];
    return try allocator.dupe(u8, work);
}

fn argUsize(args: std.StringHashMap([]const u8), key: []const u8, default: usize) usize {
    const s = args.get(key) orelse return default;
    return std.fmt.parseInt(usize, s, 10) catch default;
}

fn putDupStringIfString(allocator: std.mem.Allocator, dst: *std.json.ObjectMap, dst_key: []const u8, src: std.json.ObjectMap, src_key: []const u8) !void {
    const v = src.get(src_key) orelse return;
    if (v != .string) return;
    try dst.put(dst_key, .{ .string = try allocator.dupe(u8, v.string) });
}

/// 将电影 subject_suggest 数组映射为 registry 声明的列（评分等 suggest 中无数据时用占位）。
fn doubanNormalizeSuggestMovie(allocator: std.mem.Allocator, raw: std.json.Value, limit: usize) !std.json.Value {
    if (raw != .array) return raw;
    const n = @min(limit, raw.array.items.len);
    var items = std.array_list.Managed(std.json.Value).init(allocator);
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const it = raw.array.items[i];
        if (it != .object) continue;
        const src = it.object;
        var o = std.json.ObjectMap.init(allocator);
        try putDupStringIfString(allocator, &o, "title", src, "title");
        try putDupStringIfString(allocator, &o, "year", src, "year");
        try putDupStringIfString(allocator, &o, "directors", src, "sub_title");
        if (o.get("directors") == null) {
            try o.put("directors", .{ .string = try allocator.dupe(u8, "") });
        }
        var rating = std.json.ObjectMap.init(allocator);
        try rating.put("average", .{ .string = try allocator.dupe(u8, "-") });
        try o.put("rating", .{ .object = rating });
        try items.append(.{ .object = o });
    }
    return std.json.Value{ .array = items };
}

fn doubanNormalizeSuggestBook(allocator: std.mem.Allocator, raw: std.json.Value, limit: usize) !std.json.Value {
    if (raw != .array) return raw;
    const n = @min(limit, raw.array.items.len);
    var items = std.array_list.Managed(std.json.Value).init(allocator);
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const it = raw.array.items[i];
        if (it != .object) continue;
        const src = it.object;
        var o = std.json.ObjectMap.init(allocator);
        try putDupStringIfString(allocator, &o, "title", src, "title");
        try putDupStringIfString(allocator, &o, "author", src, "author_name");
        try putDupStringIfString(allocator, &o, "year", src, "year");
        if (o.get("author") == null) {
            try o.put("author", .{ .string = try allocator.dupe(u8, "") });
        }
        try o.put("publisher", .{ .string = try allocator.dupe(u8, "-") });
        var rating = std.json.ObjectMap.init(allocator);
        try rating.put("average", .{ .string = try allocator.dupe(u8, "-") });
        try o.put("rating", .{ .object = rating });
        try items.append(.{ .object = o });
    }
    return std.json.Value{ .array = items };
}

/// 从 Next.js HTML 中提取 `<script id="__NEXT_DATA__">` 内 JSON 文本。
fn extractNextDataPayload(html: []const u8) ?[]const u8 {
    const needle = "<script id=\"__NEXT_DATA__\"";
    const start = std.mem.indexOf(u8, html, needle) orelse return null;
    const gt = std.mem.indexOfScalarPos(u8, html, start, '>') orelse return null;
    const json_start = gt + 1;
    const end = std.mem.indexOfPos(u8, html, json_start, "</script>") orelse return null;
    return std.mem.trim(u8, html[json_start..end], " \n\r\t");
}

fn fetchNextDataJsonPage(allocator: std.mem.Allocator, client: *http.HttpClient, url: []const u8) !std.json.Value {
    var response = try client.get(url);
    defer response.headers.deinit();
    // 小宇宙等对不存在资源仍返回带 __NEXT_DATA__ 的 HTML（常为 404），需读 body。
    if (response.status == 0 or response.status >= 500) {
        return OpenCliError.HttpError;
    }
    const payload_slice = extractNextDataPayload(response.body) orelse {
        return OpenCliError.ParseError;
    };
    // Dup payload into arena so arena manages all JSON memory
    const payload = try allocator.dupe(u8, payload_slice);
    // Free original body allocated by HttpClient using HttpClient's allocator
    client.allocator.free(response.body);
    const v = try std.json.parseFromSliceLeaky(std.json.Value, allocator, payload, .{});
    return v;
}

fn nextDataPagePath(next: std.json.Value) ?[]const u8 {
    if (next != .object) return null;
    const p = next.object.get("page") orelse return null;
    return switch (p) {
        .string => |s| s,
        else => null,
    };
}

fn nextDataPagePropsEmpty(next: std.json.Value) bool {
    if (next != .object) return true;
    const props = next.object.get("props") orelse return true;
    if (props != .object) return true;
    const pp = props.object.get("pageProps") orelse return true;
    if (pp != .object) return true;
    return pp.object.count() == 0;
}

/// 小宇宙：表格列仍为 action/status/detail；`next` 为完整 __NEXT_DATA__（`-f json` 可查看）。
fn xiaoyuzhouWrapNext(allocator: std.mem.Allocator, action: []const u8, page_url: []const u8, next: std.json.Value) !std.json.Value {
    var obj = std.json.ObjectMap.init(allocator);
    try obj.put("action", .{ .string = try allocator.dupe(u8, action) });
    const page_path = nextDataPagePath(next) orelse "/unknown";
    const not_found = std.mem.eql(u8, page_path, "/404");
    const empty_props = nextDataPagePropsEmpty(next);
    const st: []const u8 = if (not_found) "not_found" else if (empty_props) "empty" else "ok";
    try obj.put("status", .{ .string = try allocator.dupe(u8, st) });
    const detail = try std.fmt.allocPrint(allocator, "{s} | next_page={s}", .{ page_url, page_path });
    defer allocator.free(detail);
    try obj.put("detail", .{ .string = try allocator.dupe(u8, detail) });
    try obj.put("next", next);
    return std.json.Value{ .object = obj };
}

fn bilibiliAccountMid(allocator: std.mem.Allocator, client: *http.HttpClient) !?[]u8 {
    var response = try client.get("https://api.bilibili.com/x/web-interface/nav");
    defer response.headers.deinit();
    if (response.status < 200 or response.status >= 400) {
        return null;
    }
    // Dup body into arena so arena manages all JSON memory
    const body_dup = try allocator.dupe(u8, response.body);
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, body_dup, .{});
    defer parsed.deinit();
    const root = parsed.value;
    if (root != .object) return null;
    const data = root.object.get("data") orelse return null;
    if (data != .object) return null;
    const mid_val = data.object.get("mid") orelse return null;
    const mid_num: i64 = switch (mid_val) {
        .integer => |x| x,
        .float => |x| @intFromFloat(x),
        else => return null,
    };
    if (mid_num <= 0) return null;
    return try std.fmt.allocPrint(allocator, "{d}", .{mid_num});
}

fn fetchJson(allocator: std.mem.Allocator, client: *http.HttpClient, http_json_cache: ?*cache_zig.CacheManager, url: []const u8) !std.json.Value {
    if (http_json_cache) |cm| {
        if (cm.getCachedJson(url)) |cached| {
            const json_str = try std.json.Stringify.valueAlloc(allocator, cached, .{});
            defer allocator.free(json_str);
            return try std.json.parseFromSliceLeaky(std.json.Value, allocator, json_str, .{});
        }
    }

    var response = try client.get(url);
    defer response.headers.deinit();
    if (response.status < 200 or response.status >= 300) {
        return OpenCliError.HttpError;
    }

    // Dup body into arena so arena can properly manage all JSON-related memory
    const body_dup = try allocator.dupe(u8, response.body);
    // Free original body allocated by HttpClient using HttpClient's allocator
    client.allocator.free(response.body);

    const v = try std.json.parseFromSliceLeaky(std.json.Value, allocator, body_dup, .{});
    if (http_json_cache) |cm| {
        cm.cacheJson(url, v) catch {};
    }
    return v;
}

/// Hacker News：拉取 id 列表再取前 N 条 item 详情（列表与各 **`item/{id}.json`** 均走 **`fetchJson`**，与适配器 JSON 缓存一致）。
fn hnTopStories(allocator: std.mem.Allocator, client: *http.HttpClient, http_json_cache: ?*cache_zig.CacheManager, limit: usize, list_url: []const u8) !std.json.Value {
    const list_v = try fetchJson(allocator, client, http_json_cache, list_url);
    defer cache_zig.destroyLeakyJsonValue(allocator, list_v);
    if (list_v != .array) return OpenCliError.ParseError;

    const ids = list_v.array.items;
    const n = @min(limit, ids.len);

    var items = std.array_list.Managed(std.json.Value).init(allocator);
    errdefer items.deinit();

    var i: usize = 0;
    while (i < n) : (i += 1) {
        const id: i64 = switch (ids[i]) {
            .integer => |v| v,
            .float => |v| @intFromFloat(v),
            else => continue,
        };
        const item_url = try std.fmt.allocPrint(allocator, "https://hacker-news.firebaseio.com/v0/item/{d}.json", .{id});
        defer allocator.free(item_url);

        const item_v = fetchJson(allocator, client, http_json_cache, item_url) catch |err| switch (err) {
            error.OutOfMemory => return err,
            else => continue,
        };
        try items.append(item_v);
    }

    return std.json.Value{ .array = items };
}
