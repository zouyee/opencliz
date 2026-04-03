const std = @import("std");
const types = @import("../core/types.zig");
const social = @import("social.zig");
const chinese = @import("chinese.zig");
const dev = @import("dev.zig");
const tools = @import("tools.zig");
const more = @import("more_sites.zig");

/// Bilibili适配器
pub const BilibiliAdapter = struct {
    pub const name = "bilibili";
    pub const description = "Bilibili video platform";
    pub const domain = "bilibili.com";
    
    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        
        // hot命令
        const hot_cmd = types.Command{
            .site = name,
            .name = "hot",
            .description = "Get trending videos",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "limit",
                    .description = "Number of videos to show",
                    .required = false,
                    .default = "10",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "title" },
                .{ .name = "Author", .key = "owner.name" },
                .{ .name = "Views", .key = "stat.view" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(hot_cmd);
        
        // search命令
        const search_cmd = types.Command{
            .site = name,
            .name = "search",
            .description = "Search for videos",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "query",
                    .description = "Search query",
                    .required = true,
                    .arg_type = .string,
                },
                .{
                    .name = "limit",
                    .description = "Number of results",
                    .required = false,
                    .default = "10",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "title" },
                .{ .name = "Author", .key = "author" },
                .{ .name = "Views", .key = "play" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(search_cmd);
        
        // user命令
        const user_cmd = types.Command{
            .site = name,
            .name = "user",
            .description = "Get user information",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "uid",
                    .description = "User ID",
                    .required = true,
                    .arg_type = .string,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Name", .key = "name" },
                .{ .name = "Followers", .key = "follower" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(user_cmd);

        const ranking_cmd = types.Command{
            .site = name,
            .name = "ranking",
            .description = "Get ranking videos",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "limit",
                    .description = "Number of videos",
                    .required = false,
                    .default = "10",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "title" },
                .{ .name = "Author", .key = "owner.name" },
                .{ .name = "Views", .key = "stat.view" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(ranking_cmd);

        const dynamic_cmd = types.Command{
            .site = name,
            .name = "dynamic",
            .description = "Get dynamic feed",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "limit",
                    .description = "Number of items",
                    .required = false,
                    .default = "10",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Type", .key = "type" },
                .{ .name = "Description", .key = "modules.module_dynamic.desc.text" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(dynamic_cmd);

        const feed_cmd = types.Command{
            .site = name,
            .name = "feed",
            .description = "Get recommendation feed",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "limit",
                    .description = "Number of videos",
                    .required = false,
                    .default = "10",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "title" },
                .{ .name = "Author", .key = "owner.name" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(feed_cmd);

        const history_cmd = types.Command{
            .site = name,
            .name = "history",
            .description = "Get watch history (public fallback)",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "limit",
                    .description = "Number of videos",
                    .required = false,
                    .default = "10",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "title" },
                .{ .name = "Author", .key = "owner.name" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(history_cmd);

        const user_videos_cmd = types.Command{
            .site = name,
            .name = "user-videos",
            .description = "Get user uploaded videos",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "uid",
                    .description = "User ID",
                    .required = true,
                    .arg_type = .string,
                },
                .{
                    .name = "limit",
                    .description = "Number of videos",
                    .required = false,
                    .default = "10",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "title" },
                .{ .name = "Play", .key = "play" },
                .{ .name = "BVID", .key = "bvid" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(user_videos_cmd);

        const subtitle_cmd = types.Command{
            .site = name,
            .name = "subtitle",
            .description = "Get video subtitle metadata",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "bvid",
                    .description = "Video BVID",
                    .required = true,
                    .arg_type = .string,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "BVID", .key = "bvid" },
                .{ .name = "CID", .key = "cid" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(subtitle_cmd);

        const download_cmd = types.Command{
            .site = name,
            .name = "download",
            .description = "Get downloadable stream metadata",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "bvid",
                    .description = "Video BVID",
                    .required = true,
                    .arg_type = .string,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Quality", .key = "quality" },
                .{ .name = "URL", .key = "url" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(download_cmd);

        const favorite_cmd = types.Command{
            .site = name,
            .name = "favorite",
            .description = "Favorite folders (public with --uid, or Cookie for own account)",
            .domain = domain,
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "uid", .description = "User mid (optional; omit when Cookie is set)", .required = false, .arg_type = .string },
                .{ .name = "limit", .description = "Number of results", .required = false, .default = "20", .arg_type = .integer },
                .{ .name = "page", .description = "Page number", .required = false, .default = "1", .arg_type = .integer },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(favorite_cmd);

        const following_cmd = types.Command{
            .site = name,
            .name = "following",
            .description = "Following list (public with --uid, or Cookie for own account)",
            .domain = domain,
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "uid", .description = "User mid (optional; omit when Cookie is set)", .required = false, .arg_type = .string },
                .{ .name = "limit", .description = "Number of results", .required = false, .default = "20", .arg_type = .integer },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(following_cmd);

        const me_cmd = types.Command{
            .site = name,
            .name = "me",
            .description = "Current account home (login)",
            .domain = domain,
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{},
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(me_cmd);
    }
};

/// GitHub适配器
pub const GitHubAdapter = struct {
    pub const name = "github";
    pub const description = "GitHub code repository";
    pub const domain = "github.com";
    
    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        
        // trending命令
        const trending_cmd = types.Command{
            .site = name,
            .name = "trending",
            .description = "Get trending repositories",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "language",
                    .description = "Programming language filter",
                    .required = false,
                    .default = "",
                    .arg_type = .string,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Repository", .key = "full_name" },
                .{ .name = "Stars", .key = "stargazers_count" },
                .{ .name = "Language", .key = "language" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(trending_cmd);
        
        // repo命令
        const repo_cmd = types.Command{
            .site = name,
            .name = "repo",
            .description = "Get repository information",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "owner",
                    .description = "Repository owner",
                    .required = true,
                    .arg_type = .string,
                },
                .{
                    .name = "repo",
                    .description = "Repository name",
                    .required = true,
                    .arg_type = .string,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Name", .key = "full_name" },
                .{ .name = "Stars", .key = "stargazers_count" },
                .{ .name = "Forks", .key = "forks_count" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(repo_cmd);
    }
};

/// 注册所有内置适配器
pub fn registerAllAdapters(allocator: std.mem.Allocator, registry: *types.Registry) !void {
    // 视频平台
    try BilibiliAdapter.register(allocator, registry);
    try social.YouTubeAdapter.register(allocator, registry);
    
    // 代码/技术
    try GitHubAdapter.register(allocator, registry);
    try social.HackerNewsAdapter.register(allocator, registry);
    try chinese.JuejinAdapter.register(allocator, registry);
    try dev.StackOverflowAdapter.register(allocator, registry);
    try dev.NpmAdapter.register(allocator, registry);
    try dev.PyPIAdapter.register(allocator, registry);
    try dev.CratesAdapter.register(allocator, registry);
    
    // 社交媒体
    try social.TwitterAdapter.register(allocator, registry);
    try social.RedditAdapter.register(allocator, registry);
    try social.V2exAdapter.register(allocator, registry);
    try chinese.WeiboAdapter.register(allocator, registry);
    
    // 知识/问答
    try chinese.ZhihuAdapter.register(allocator, registry);
    try chinese.DailyZhihuAdapter.register(allocator, registry);
    
    // 娱乐/文化
    try chinese.DoubanAdapter.register(allocator, registry);
    try chinese.WeReadAdapter.register(allocator, registry);
    try chinese.XiaohongshuAdapter.register(allocator, registry);
    try chinese.DouyinAdapter.register(allocator, registry);
    try chinese.XueqiuAdapter.register(allocator, registry);
    try chinese.GoogleAdapter.register(allocator, registry);
    try chinese.PixivAdapter.register(allocator, registry);
    try chinese.LinkedInAdapter.register(allocator, registry);
    try chinese.BloombergAdapter.register(allocator, registry);
    try chinese.ReutersAdapter.register(allocator, registry);
    try chinese.SubstackAdapter.register(allocator, registry);
    try chinese.MediumAdapter.register(allocator, registry);
    try chinese.YahooFinanceAdapter.register(allocator, registry);
    try chinese.ChatgptAdapter.register(allocator, registry);
    try chinese.CodexAdapter.register(allocator, registry);
    try chinese.CursorAdapter.register(allocator, registry);
    try chinese.NotionAdapter.register(allocator, registry);
    try chinese.BossAdapter.register(allocator, registry);
    try chinese.DiscordAppAdapter.register(allocator, registry);
    try chinese.YollomiAdapter.register(allocator, registry);
    try chinese.ApplePodcastsAdapter.register(allocator, registry);
    try chinese.BbcAdapter.register(allocator, registry);
    try chinese.DictionaryAdapter.register(allocator, registry);
    try chinese.DevtoAdapter.register(allocator, registry);
    try chinese.HfAdapter.register(allocator, registry);
    try chinese.GrokAdapter.register(allocator, registry);
    try chinese.JdAdapter.register(allocator, registry);
    try chinese.ChaoxingAdapter.register(allocator, registry);
    try chinese.CoupangAdapter.register(allocator, registry);
    try chinese.CtripAdapter.register(allocator, registry);
    try chinese.JikeAdapter.register(allocator, registry);
    try more.DoubaoAdapter.register(allocator, registry);
    try more.DoubaoAppAdapter.register(allocator, registry);
    try more.ChatwiseAdapter.register(allocator, registry);
    try more.SinablogAdapter.register(allocator, registry);
    try more.SinafinanceAdapter.register(allocator, registry);
    try more.SmzdmAdapter.register(allocator, registry);
    try more.WebAdapter.register(allocator, registry);
    try more.WeixinAdapter.register(allocator, registry);
    try more.XiaoyuzhouAdapter.register(allocator, registry);
    try more.AntigravityAdapter.register(allocator, registry);
    try more.BarchartAdapter.register(allocator, registry);
    
    // 学术/工具
    try tools.ArxivAdapter.register(allocator, registry);
    try tools.UnsplashAdapter.register(allocator, registry);
    try tools.WeatherAdapter.register(allocator, registry);
    try tools.NewsAdapter.register(allocator, registry);
    try tools.WikipediaAdapter.register(allocator, registry);
    
    std.log.info("Registered built-in adapters", .{});
}