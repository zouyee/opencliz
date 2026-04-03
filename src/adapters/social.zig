const std = @import("std");
const types = @import("../core/types.zig");

/// Twitter/X适配器
pub const TwitterAdapter = struct {
    pub const name = "twitter";
    pub const description = "Twitter social platform";
    pub const domain = "twitter.com";
    
    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        
        // timeline命令
        const timeline_cmd = types.Command{
            .site = name,
            .name = "timeline",
            .description = "Get user timeline",
            .domain = domain,
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{
                    .name = "user",
                    .description = "Username",
                    .required = false,
                    .arg_type = .string,
                },
                .{
                    .name = "limit",
                    .description = "Number of tweets",
                    .required = false,
                    .default = "20",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Time", .key = "created_at" },
                .{ .name = "User", .key = "user.name" },
                .{ .name = "Tweet", .key = "text" },
                .{ .name = "Likes", .key = "favorite_count" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(timeline_cmd);
        
        // search命令
        const search_cmd = types.Command{
            .site = name,
            .name = "search",
            .description = "Search tweets",
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
                    .default = "20",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Time", .key = "created_at" },
                .{ .name = "User", .key = "user.screen_name" },
                .{ .name = "Tweet", .key = "text" },
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
                    .name = "username",
                    .description = "Twitter username",
                    .required = true,
                    .arg_type = .string,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Name", .key = "name" },
                .{ .name = "Handle", .key = "screen_name" },
                .{ .name = "Followers", .key = "followers_count" },
                .{ .name = "Following", .key = "friends_count" },
                .{ .name = "Tweets", .key = "statuses_count" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(user_cmd);

        const alias_names = [_][]const u8{
            "profile", "trending", "notifications", "followers", "following", "bookmarks",
            "bookmark", "unbookmark", "like", "follow", "unfollow", "block", "unblock",
            "accept", "hide-reply", "post", "reply", "reply-dm", "thread", "article",
            "delete", "download",
        };
        for (alias_names) |n| {
            const cmd = types.Command{
                .site = name,
                .name = n,
                .description = "Twitter command",
                .domain = domain,
                .strategy = .public,
                .browser = false,
                .args = &[_]types.ArgDef{
                    .{ .name = "id", .description = "Optional identifier", .required = false, .arg_type = .string },
                    .{ .name = "query", .description = "Optional query", .required = false, .arg_type = .string },
                    .{ .name = "user", .description = "Optional user", .required = false, .arg_type = .string },
                    .{ .name = "username", .description = "Optional username", .required = false, .arg_type = .string },
                    .{ .name = "text", .description = "Optional content", .required = false, .arg_type = .string },
                    .{ .name = "limit", .description = "Optional limit", .required = false, .default = "20", .arg_type = .integer },
                },
                .columns = &[_]types.ColumnDef{
                    .{ .name = "Action", .key = "action" },
                    .{ .name = "Status", .key = "status" },
                    .{ .name = "Detail", .key = "detail" },
                },
                .source = "adapter",
            };
            try registry.registerCommand(cmd);
        }

    }
};

/// YouTube适配器
pub const YouTubeAdapter = struct {
    pub const name = "youtube";
    pub const description = "YouTube video platform";
    pub const domain = "youtube.com";
    
    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        
        // trending命令
        const trending_cmd = types.Command{
            .site = name,
            .name = "trending",
            .description = "Get trending videos",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "region",
                    .description = "Region code",
                    .required = false,
                    .default = "US",
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
                .{ .name = "Title", .key = "snippet.title" },
                .{ .name = "Channel", .key = "snippet.channelTitle" },
                .{ .name = "Views", .key = "statistics.viewCount" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(trending_cmd);
        
        // search命令
        const search_cmd = types.Command{
            .site = name,
            .name = "search",
            .description = "Search videos",
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
                .{ .name = "Title", .key = "snippet.title" },
                .{ .name = "Channel", .key = "snippet.channelTitle" },
                .{ .name = "Published", .key = "snippet.publishedAt" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(search_cmd);

        const video_cmd = types.Command{
            .site = name,
            .name = "video",
            .description = "Get video metadata",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "id", .description = "Video ID", .required = true, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "title" },
                .{ .name = "Author", .key = "author_name" },
                .{ .name = "URL", .key = "url" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(video_cmd);

        const channel_cmd = types.Command{
            .site = name,
            .name = "channel",
            .description = "Get channel metadata",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "id", .description = "Channel ID", .required = true, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "title" },
                .{ .name = "Description", .key = "description" },
                .{ .name = "URL", .key = "url" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(channel_cmd);

        const comments_cmd = types.Command{
            .site = name,
            .name = "comments",
            .description = "Get video comments",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "id", .description = "Video ID", .required = true, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Author", .key = "author" },
                .{ .name = "Text", .key = "text" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(comments_cmd);

        const transcript_cmd = types.Command{
            .site = name,
            .name = "transcript",
            .description = "Get video transcript",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "id", .description = "Video ID", .required = true, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Text", .key = "text" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(transcript_cmd);

        const transcript_group_cmd = types.Command{
            .site = name,
            .name = "transcript-group",
            .description = "Get grouped transcript",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "id", .description = "Video ID", .required = true, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Text", .key = "text" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(transcript_group_cmd);
    }
};

/// HackerNews适配器
pub const HackerNewsAdapter = struct {
    pub const name = "hackernews";
    pub const description = "Hacker News tech forum";
    pub const domain = "news.ycombinator.com";
    
    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        
        // top命令
        const top_cmd = types.Command{
            .site = name,
            .name = "top",
            .description = "Get top stories",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "limit",
                    .description = "Number of stories",
                    .required = false,
                    .default = "30",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "title" },
                .{ .name = "Score", .key = "score" },
                .{ .name = "By", .key = "by" },
                .{ .name = "Comments", .key = "descendants" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(top_cmd);
        
        // show命令
        const show_cmd = types.Command{
            .site = name,
            .name = "show",
            .description = "Get Show HN stories",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "limit",
                    .description = "Number of stories",
                    .required = false,
                    .default = "30",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "title" },
                .{ .name = "Score", .key = "score" },
                .{ .name = "By", .key = "by" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(show_cmd);

        const best_cmd = types.Command{
            .site = name,
            .name = "best",
            .description = "Get best stories",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "limit",
                    .description = "Number of stories",
                    .required = false,
                    .default = "30",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "title" },
                .{ .name = "Score", .key = "score" },
                .{ .name = "By", .key = "by" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(best_cmd);

        const new_cmd = types.Command{
            .site = name,
            .name = "new",
            .description = "Get new stories",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "limit",
                    .description = "Number of stories",
                    .required = false,
                    .default = "30",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "title" },
                .{ .name = "Score", .key = "score" },
                .{ .name = "By", .key = "by" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(new_cmd);

        const jobs_cmd = types.Command{
            .site = name,
            .name = "jobs",
            .description = "Get job stories",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "limit",
                    .description = "Number of stories",
                    .required = false,
                    .default = "30",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "title" },
                .{ .name = "By", .key = "by" },
                .{ .name = "URL", .key = "url" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(jobs_cmd);

        const user_cmd = types.Command{
            .site = name,
            .name = "user",
            .description = "Get user profile",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "id",
                    .description = "HN user id",
                    .required = true,
                    .arg_type = .string,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "ID", .key = "id" },
                .{ .name = "Karma", .key = "karma" },
                .{ .name = "Created", .key = "created" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(user_cmd);

        const ask_cmd = types.Command{
            .site = name,
            .name = "ask",
            .description = "Get Ask HN stories",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "limit",
                    .description = "Number of stories",
                    .required = false,
                    .default = "30",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "title" },
                .{ .name = "Score", .key = "score" },
                .{ .name = "By", .key = "by" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(ask_cmd);

        const search_cmd = types.Command{
            .site = name,
            .name = "search",
            .description = "Search stories by keyword",
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
                    .description = "Number of stories",
                    .required = false,
                    .default = "20",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "title" },
                .{ .name = "URL", .key = "url" },
                .{ .name = "Points", .key = "points" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(search_cmd);
    }
};

/// Reddit适配器
pub const RedditAdapter = struct {
    pub const name = "reddit";
    pub const description = "Reddit social forum";
    pub const domain = "reddit.com";
    
    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        
        // hot命令
        const hot_cmd = types.Command{
            .site = name,
            .name = "hot",
            .description = "Get hot posts",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "subreddit",
                    .description = "Subreddit name",
                    .required = false,
                    .default = "all",
                    .arg_type = .string,
                },
                .{
                    .name = "limit",
                    .description = "Number of posts",
                    .required = false,
                    .default = "25",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "data.title" },
                .{ .name = "Subreddit", .key = "data.subreddit" },
                .{ .name = "Score", .key = "data.score" },
                .{ .name = "Comments", .key = "data.num_comments" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(hot_cmd);

        const search_cmd = types.Command{
            .site = name,
            .name = "search",
            .description = "Search posts",
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
                    .description = "Number of posts",
                    .required = false,
                    .default = "25",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "data.title" },
                .{ .name = "Subreddit", .key = "data.subreddit" },
                .{ .name = "Score", .key = "data.score" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(search_cmd);

        const subreddit_cmd = types.Command{
            .site = name,
            .name = "subreddit",
            .description = "Get subreddit posts",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "name",
                    .description = "Subreddit name",
                    .required = true,
                    .arg_type = .string,
                },
                .{
                    .name = "limit",
                    .description = "Number of posts",
                    .required = false,
                    .default = "25",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "data.title" },
                .{ .name = "Score", .key = "data.score" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(subreddit_cmd);

        const user_cmd = types.Command{
            .site = name,
            .name = "user",
            .description = "Get user submitted posts",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "username",
                    .description = "Reddit username",
                    .required = true,
                    .arg_type = .string,
                },
                .{
                    .name = "limit",
                    .description = "Number of posts",
                    .required = false,
                    .default = "25",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "data.title" },
                .{ .name = "Subreddit", .key = "data.subreddit" },
                .{ .name = "Score", .key = "data.score" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(user_cmd);

        const frontpage_cmd = types.Command{
            .site = name,
            .name = "frontpage",
            .description = "Get frontpage posts",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "limit",
                    .description = "Number of posts",
                    .required = false,
                    .default = "25",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "data.title" },
                .{ .name = "Subreddit", .key = "data.subreddit" },
                .{ .name = "Score", .key = "data.score" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(frontpage_cmd);

        const popular_cmd = types.Command{
            .site = name,
            .name = "popular",
            .description = "Get popular posts",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "limit",
                    .description = "Number of posts",
                    .required = false,
                    .default = "25",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "data.title" },
                .{ .name = "Subreddit", .key = "data.subreddit" },
                .{ .name = "Score", .key = "data.score" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(popular_cmd);

        const user_posts_cmd = types.Command{
            .site = name,
            .name = "user-posts",
            .description = "Get user submitted posts",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "username",
                    .description = "Reddit username",
                    .required = true,
                    .arg_type = .string,
                },
                .{
                    .name = "limit",
                    .description = "Number of posts",
                    .required = false,
                    .default = "25",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "data.title" },
                .{ .name = "Subreddit", .key = "data.subreddit" },
                .{ .name = "Score", .key = "data.score" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(user_posts_cmd);

        const user_comments_cmd = types.Command{
            .site = name,
            .name = "user-comments",
            .description = "Get user comments",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "username",
                    .description = "Reddit username",
                    .required = true,
                    .arg_type = .string,
                },
                .{
                    .name = "limit",
                    .description = "Number of comments",
                    .required = false,
                    .default = "25",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Subreddit", .key = "data.subreddit" },
                .{ .name = "Score", .key = "data.score" },
                .{ .name = "Body", .key = "data.body" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(user_comments_cmd);

        const read_cmd = types.Command{
            .site = name,
            .name = "read",
            .description = "Read a post and comments (public .json API)",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "post-id", .description = "Post id, t3_ id, or Reddit post URL", .required = true, .arg_type = .string },
                .{ .name = "sort", .description = "Comment sort", .required = false, .default = "best", .arg_type = .string },
                .{ .name = "limit", .description = "Top-level comment limit", .required = false, .default = "25", .arg_type = .integer },
                .{ .name = "depth", .description = "Depth (informational)", .required = false, .default = "2", .arg_type = .integer },
                .{ .name = "replies", .description = "Replies per level (informational)", .required = false, .default = "5", .arg_type = .integer },
                .{ .name = "max-length", .description = "Max body length (informational)", .required = false, .default = "2000", .arg_type = .integer },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "data.title" },
                .{ .name = "Subreddit", .key = "data.subreddit" },
                .{ .name = "Score", .key = "data.score" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(read_cmd);

        const comment_cmd = types.Command{
            .site = name,
            .name = "comment",
            .description = "Post a comment (browser / login)",
            .domain = domain,
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "post-id", .description = "Post id or URL", .required = true, .arg_type = .string },
                .{ .name = "text", .description = "Comment body", .required = true, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(comment_cmd);

        const save_cmd = types.Command{
            .site = name,
            .name = "save",
            .description = "Save or unsave a post (browser / login)",
            .domain = domain,
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "post-id", .description = "Post id or URL", .required = true, .arg_type = .string },
                .{ .name = "undo", .description = "Unsave", .required = false, .default = "false", .arg_type = .boolean },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(save_cmd);

        const saved_cmd = types.Command{
            .site = name,
            .name = "saved",
            .description = "Browse saved posts (browser / login)",
            .domain = domain,
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "limit", .description = "Max items", .required = false, .default = "15", .arg_type = .integer },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(saved_cmd);

        const subscribe_cmd = types.Command{
            .site = name,
            .name = "subscribe",
            .description = "Subscribe or unsubscribe from a subreddit (browser / login)",
            .domain = domain,
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "subreddit", .description = "Subreddit name (e.g. python)", .required = true, .arg_type = .string },
                .{ .name = "undo", .description = "Unsubscribe", .required = false, .default = "false", .arg_type = .boolean },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(subscribe_cmd);

        const upvote_cmd = types.Command{
            .site = name,
            .name = "upvote",
            .description = "Vote on a post (browser / login)",
            .domain = domain,
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "post-id", .description = "Post id or URL", .required = true, .arg_type = .string },
                .{ .name = "direction", .description = "up | down | none", .required = false, .default = "up", .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(upvote_cmd);

        const upvoted_cmd = types.Command{
            .site = name,
            .name = "upvoted",
            .description = "Browse upvoted posts (browser / login)",
            .domain = domain,
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "limit", .description = "Max items", .required = false, .default = "15", .arg_type = .integer },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(upvoted_cmd);
    }
};

/// V2EX 社区（与仓库 src/clis/v2ex 对齐，HTTP 实现在 adapters/http_exec.zig）
pub const V2exAdapter = struct {
    pub const name = "v2ex";
    pub const description = "V2EX tech community";
    pub const domain = "v2ex.com";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;

        const hot_cmd = types.Command{
            .site = name,
            .name = "hot",
            .description = "V2EX 热门话题",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "limit",
                    .description = "Number of topics",
                    .required = false,
                    .default = "20",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "title" },
                .{ .name = "Replies", .key = "replies" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(hot_cmd);

        const latest_cmd = types.Command{
            .site = name,
            .name = "latest",
            .description = "V2EX 最新话题",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "limit",
                    .description = "Number of topics",
                    .required = false,
                    .default = "20",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "title" },
                .{ .name = "Replies", .key = "replies" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(latest_cmd);

        const topic_cmd = types.Command{
            .site = name,
            .name = "topic",
            .description = "V2EX 话题详情",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "id",
                    .description = "Topic ID",
                    .required = true,
                    .arg_type = .string,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "title" },
                .{ .name = "Replies", .key = "replies" },
                .{ .name = "URL", .key = "url" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(topic_cmd);

        const node_cmd = types.Command{
            .site = name,
            .name = "node",
            .description = "V2EX 节点话题列表",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "name",
                    .description = "Node name",
                    .required = true,
                    .arg_type = .string,
                },
                .{
                    .name = "limit",
                    .description = "Number of topics",
                    .required = false,
                    .default = "20",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "title" },
                .{ .name = "Replies", .key = "replies" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(node_cmd);

        const nodes_cmd = types.Command{
            .site = name,
            .name = "nodes",
            .description = "V2EX 全部节点",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{},
            .columns = &[_]types.ColumnDef{
                .{ .name = "Name", .key = "name" },
                .{ .name = "Title", .key = "title" },
                .{ .name = "Topics", .key = "topics" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(nodes_cmd);

        const member_cmd = types.Command{
            .site = name,
            .name = "member",
            .description = "V2EX 用户信息",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "username",
                    .description = "Username",
                    .required = true,
                    .arg_type = .string,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Username", .key = "username" },
                .{ .name = "Bio", .key = "bio" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(member_cmd);

        const replies_cmd = types.Command{
            .site = name,
            .name = "replies",
            .description = "V2EX 话题回复",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "topic_id",
                    .description = "Topic ID",
                    .required = true,
                    .arg_type = .string,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Member", .key = "member.username" },
                .{ .name = "Content", .key = "content" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(replies_cmd);

        const daily_cmd = types.Command{
            .site = name,
            .name = "daily",
            .description = "V2EX 日报（fallback to latest）",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "limit",
                    .description = "Number of topics",
                    .required = false,
                    .default = "20",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "title" },
                .{ .name = "Replies", .key = "replies" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(daily_cmd);

        const user_cmd = types.Command{
            .site = name,
            .name = "user",
            .description = "V2EX 用户信息（alias of member）",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "username",
                    .description = "Username",
                    .required = true,
                    .arg_type = .string,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Username", .key = "username" },
                .{ .name = "Bio", .key = "bio" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(user_cmd);

        const me_cmd = types.Command{
            .site = name,
            .name = "me",
            .description = "V2EX profile / balance (login)",
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

        const notifications_cmd = types.Command{
            .site = name,
            .name = "notifications",
            .description = "V2EX notifications (login)",
            .domain = domain,
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "limit", .description = "Number of notifications", .required = false, .default = "20", .arg_type = .integer },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(notifications_cmd);
    }
};