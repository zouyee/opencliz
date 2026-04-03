const std = @import("std");
const types = @import("../core/types.zig");

/// 知乎适配器
pub const ZhihuAdapter = struct {
    pub const name = "zhihu";
    pub const description = "Zhihu Q&A platform";
    pub const domain = "zhihu.com";
    
    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        
        // hot命令 - 热门话题
        const hot_cmd = types.Command{
            .site = name,
            .name = "hot",
            .description = "Get trending topics",
            .domain = domain,
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{
                    .name = "limit",
                    .description = "Number of topics",
                    .required = false,
                    .default = "10",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "target.title" },
                .{ .name = "Heat", .key = "detail_text" },
                .{ .name = "Excerpt", .key = "target.excerpt" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(hot_cmd);
        
        // search命令 - 搜索
        const search_cmd = types.Command{
            .site = name,
            .name = "search",
            .description = "Search questions",
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
                    .name = "type",
                    .description = "Search type (question, answer, article)",
                    .required = false,
                    .default = "question",
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
                .{ .name = "Author", .key = "author.name" },
                .{ .name = "Votes", .key = "voteup_count" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(search_cmd);
        
        // question命令 - 获取问题
        const question_cmd = types.Command{
            .site = name,
            .name = "question",
            .description = "Get question details",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "id",
                    .description = "Question ID",
                    .required = true,
                    .arg_type = .string,
                },
                .{
                    .name = "limit",
                    .description = "Number of answers",
                    .required = false,
                    .default = "5",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "title" },
                .{ .name = "Author", .key = "author.name" },
                .{ .name = "Content", .key = "content" },
                .{ .name = "Votes", .key = "voteup_count" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(question_cmd);
        
        // user命令 - 用户信息
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
                    .description = "User URL token",
                    .required = true,
                    .arg_type = .string,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Name", .key = "name" },
                .{ .name = "Headline", .key = "headline" },
                .{ .name = "Followers", .key = "follower_count" },
                .{ .name = "Answers", .key = "answer_count" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(user_cmd);

        const download_cmd = types.Command{
            .site = name,
            .name = "download",
            .description = "Download question page as Markdown (HTTP; optional CDP via OPENCLI_USE_BROWSER=1)",
            .domain = domain,
            .strategy = .public,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "id", .description = "Question ID", .required = true, .arg_type = .string },
                .{ .name = "output", .description = "Output directory for .md", .required = false, .default = "./zhihu-articles", .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "ID", .key = "id" },
                .{ .name = "Status", .key = "status" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(download_cmd);

    }
};

/// 知乎日报适配器
pub const DailyZhihuAdapter = struct {
    pub const name = "daily";
    pub const description = "Zhihu Daily curated content";
    pub const domain = "daily.zhihu.com";
    
    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        
        // latest命令 - 最新日报
        const latest_cmd = types.Command{
            .site = name,
            .name = "latest",
            .description = "Get latest daily stories",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "limit",
                    .description = "Number of stories",
                    .required = false,
                    .default = "10",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "title" },
                .{ .name = "Hint", .key = "hint" },
                .{ .name = "URL", .key = "url" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(latest_cmd);
    }
};

/// 微博适配器
pub const WeiboAdapter = struct {
    pub const name = "weibo";
    pub const description = "Weibo microblogging platform";
    pub const domain = "weibo.com";
    
    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        
        // hot命令 - 热搜榜
        const hot_cmd = types.Command{
            .site = name,
            .name = "hot",
            .description = "Get trending topics",
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
                .{ .name = "Rank", .key = "rank" },
                .{ .name = "Topic", .key = "topic" },
                .{ .name = "Heat", .key = "heat" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(hot_cmd);
        
        // user命令 - 用户信息
        const user_cmd = types.Command{
            .site = name,
            .name = "user",
            .description = "Get user information",
            .domain = domain,
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{
                    .name = "uid",
                    .description = "User ID",
                    .required = true,
                    .arg_type = .string,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Name", .key = "screen_name" },
                .{ .name = "Description", .key = "description" },
                .{ .name = "Followers", .key = "followers_count" },
                .{ .name = "Posts", .key = "statuses_count" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(user_cmd);

        const feed_cmd = types.Command{
            .site = name,
            .name = "feed",
            .description = "Get feed timeline",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "limit", .description = "Number of posts", .required = false, .default = "20", .arg_type = .integer },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Text", .key = "text" },
                .{ .name = "User", .key = "user.screen_name" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(feed_cmd);

        const search_posts_cmd = types.Command{
            .site = name,
            .name = "search",
            .description = "Search posts",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "query", .description = "Search query", .required = true, .arg_type = .string },
                .{ .name = "limit", .description = "Number of posts", .required = false, .default = "20", .arg_type = .integer },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Text", .key = "text" },
                .{ .name = "User", .key = "user.screen_name" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(search_posts_cmd);

        const comments_cmd = types.Command{
            .site = name,
            .name = "comments",
            .description = "Get comments by post id",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "id", .description = "Post ID", .required = true, .arg_type = .string },
                .{ .name = "limit", .description = "Number of comments", .required = false, .default = "20", .arg_type = .integer },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "User", .key = "user.screen_name" },
                .{ .name = "Text", .key = "text" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(comments_cmd);

        const me_cmd = types.Command{
            .site = name,
            .name = "me",
            .description = "Alias of user",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "uid", .description = "User ID", .required = true, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Name", .key = "screen_name" },
                .{ .name = "Followers", .key = "followers_count" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(me_cmd);

        const post_cmd = types.Command{
            .site = name,
            .name = "post",
            .description = "Get post by id",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "id", .description = "Post ID", .required = true, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Text", .key = "text" },
                .{ .name = "User", .key = "user.screen_name" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(post_cmd);
    }
};

/// Product Hunt适配器
pub const ProductHuntAdapter = struct {
    pub const name = "producthunt";
    pub const description = "Product Hunt tech products";
    pub const domain = "producthunt.com";
    
    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        
        // trending命令
        const trending_cmd = types.Command{
            .site = name,
            .name = "trending",
            .description = "Get trending products",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "date",
                    .description = "Date (YYYY-MM-DD)",
                    .required = false,
                    .arg_type = .string,
                },
                .{
                    .name = "limit",
                    .description = "Number of products",
                    .required = false,
                    .default = "10",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Name", .key = "name" },
                .{ .name = "Tagline", .key = "tagline" },
                .{ .name = "Votes", .key = "votes_count" },
                .{ .name = "Maker", .key = "maker.name" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(trending_cmd);
        
        // search命令
        const search_cmd = types.Command{
            .site = name,
            .name = "search",
            .description = "Search products",
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
                .{ .name = "Name", .key = "name" },
                .{ .name = "Tagline", .key = "tagline" },
                .{ .name = "Votes", .key = "votes_count" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(search_cmd);
    }
};

/// 掘金适配器
pub const JuejinAdapter = struct {
    pub const name = "juejin";
    pub const description = "Juejin technical community";
    pub const domain = "juejin.cn";
    
    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        
        // hot命令 - 热门文章
        const hot_cmd = types.Command{
            .site = name,
            .name = "hot",
            .description = "Get trending articles",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "category",
                    .description = "Category (frontend, backend, android, ios, ai)",
                    .required = false,
                    .default = "recommended",
                    .arg_type = .string,
                },
                .{
                    .name = "limit",
                    .description = "Number of articles",
                    .required = false,
                    .default = "20",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "article_info.title" },
                .{ .name = "Author", .key = "author_user_info.user_name" },
                .{ .name = "Views", .key = "article_info.view_count" },
                .{ .name = "Likes", .key = "article_info.digg_count" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(hot_cmd);
    }
};

/// 豆瓣适配器
pub const DoubanAdapter = struct {
    pub const name = "douban";
    pub const description = "Douban movie/book/music platform";
    pub const domain = "douban.com";
    
    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        
        // movie命令 - 电影搜索
        const movie_cmd = types.Command{
            .site = name,
            .name = "movie",
            .description = "Search movies",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "query",
                    .description = "Movie title",
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
                .{ .name = "Rating", .key = "rating.average" },
                .{ .name = "Year", .key = "year" },
                .{ .name = "Directors", .key = "directors" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(movie_cmd);
        
        // book命令 - 图书搜索
        const book_cmd = types.Command{
            .site = name,
            .name = "book",
            .description = "Search books",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "query",
                    .description = "Book title or author",
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
                .{ .name = "Rating", .key = "rating.average" },
                .{ .name = "Publisher", .key = "publisher" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(book_cmd);

        const search_cmd = types.Command{
            .site = name,
            .name = "search",
            .description = "Search Douban movie, book, or music",
            .domain = "search.douban.com",
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "type", .description = "movie | book | music", .required = false, .default = "movie", .arg_type = .string },
                .{ .name = "keyword", .description = "Search keyword", .required = true, .arg_type = .string },
                .{ .name = "limit", .description = "Result limit (informational)", .required = false, .default = "20", .arg_type = .integer },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(search_cmd);

        const book_hot_cmd = types.Command{
            .site = name,
            .name = "book-hot",
            .description = "Douban book hot / charts entry",
            .domain = "book.douban.com",
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "limit", .description = "Number of items (informational)", .required = false, .default = "20", .arg_type = .integer },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(book_hot_cmd);

        const movie_hot_cmd = types.Command{
            .site = name,
            .name = "movie-hot",
            .description = "Douban movie charts entry",
            .domain = "movie.douban.com",
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "limit", .description = "Number of items (informational)", .required = false, .default = "20", .arg_type = .integer },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(movie_hot_cmd);

        const marks_cmd = types.Command{
            .site = name,
            .name = "marks",
            .description = "Personal movie marks (browser / login)",
            .domain = "movie.douban.com",
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "status", .description = "collect | wish | do | all", .required = false, .default = "collect", .arg_type = .string },
                .{ .name = "limit", .description = "Max rows (informational)", .required = false, .default = "50", .arg_type = .integer },
                .{ .name = "uid", .description = "Douban user id", .required = false, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(marks_cmd);

        const reviews_cmd = types.Command{
            .site = name,
            .name = "reviews",
            .description = "Personal movie reviews (browser / login)",
            .domain = "movie.douban.com",
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "limit", .description = "Max rows (informational)", .required = false, .default = "20", .arg_type = .integer },
                .{ .name = "uid", .description = "Douban user id", .required = false, .arg_type = .string },
                .{ .name = "full", .description = "Fetch full content", .required = false, .default = "false", .arg_type = .boolean },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(reviews_cmd);
    }
};

/// 微信读书适配器
pub const WeReadAdapter = struct {
    pub const name = "weread";
    pub const description = "WeRead books and notes";
    pub const domain = "weread.qq.com";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;

        const search_cmd = types.Command{
            .site = name,
            .name = "search",
            .description = "Search books",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "query", .description = "Search keyword", .required = true, .arg_type = .string },
                .{ .name = "limit", .description = "Result size", .required = false, .default = "10", .arg_type = .integer },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "title" },
                .{ .name = "Author", .key = "author" },
                .{ .name = "BookId", .key = "bookId" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(search_cmd);

        const book_cmd = types.Command{
            .site = name,
            .name = "book",
            .description = "Get book detail",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "book_id", .description = "Book id", .required = true, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "BookId", .key = "bookId" },
                .{ .name = "Title", .key = "title" },
                .{ .name = "Author", .key = "author" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(book_cmd);

        const ranking_cmd = types.Command{
            .site = name,
            .name = "ranking",
            .description = "Get ranking books",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "rank_id", .description = "Ranking id", .required = false, .default = "1", .arg_type = .string },
                .{ .name = "limit", .description = "Result size", .required = false, .default = "10", .arg_type = .integer },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "title" },
                .{ .name = "Author", .key = "author" },
                .{ .name = "Score", .key = "score" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(ranking_cmd);

        const placeholder_names = [_][]const u8{ "shelf", "notes", "highlights", "notebooks" };
        for (placeholder_names) |n| {
            const cmd = types.Command{
                .site = name,
                .name = n,
                .description = "WeRead command",
                .domain = domain,
                .strategy = .public,
                .browser = false,
                .args = &[_]types.ArgDef{
                    .{ .name = "user_id", .description = "User id", .required = false, .arg_type = .string },
                    .{ .name = "book_id", .description = "Book id", .required = false, .arg_type = .string },
                    .{ .name = "limit", .description = "Result size", .required = false, .default = "20", .arg_type = .integer },
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

/// 小红书适配器
pub const XiaohongshuAdapter = struct {
    pub const name = "xiaohongshu";
    pub const description = "Xiaohongshu social platform";
    pub const domain = "xiaohongshu.com";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;

        const search_cmd = types.Command{
            .site = name,
            .name = "search",
            .description = "Search notes",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "query", .description = "Search keyword", .required = true, .arg_type = .string },
                .{ .name = "limit", .description = "Result size", .required = false, .default = "20", .arg_type = .integer },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(search_cmd);

        const user_cmd = types.Command{
            .site = name,
            .name = "user",
            .description = "Get user profile by user id",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "user_id", .description = "User id", .required = true, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(user_cmd);

        const command_names = [_][]const u8{
            "creator-note-detail",
            "creator-notes-summary",
            "creator-notes",
            "creator-profile",
            "creator-stats",
            "download",
            "publish",
            "feed",
            "notifications",
        };
        for (command_names) |n| {
            const cmd = types.Command{
                .site = name,
                .name = n,
                .description = "Xiaohongshu command",
                .domain = domain,
                .strategy = .public,
                .browser = false,
                .args = &[_]types.ArgDef{
                    .{ .name = "user_id", .description = "User id", .required = false, .arg_type = .string },
                    .{ .name = "note_id", .description = "Note id", .required = false, .arg_type = .string },
                    .{ .name = "query", .description = "Search query", .required = false, .arg_type = .string },
                    .{ .name = "limit", .description = "Result size", .required = false, .default = "20", .arg_type = .integer },
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

/// 抖音适配器
pub const DouyinAdapter = struct {
    pub const name = "douyin";
    pub const description = "Douyin short video platform";
    pub const domain = "douyin.com";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;

        const profile_cmd = types.Command{
            .site = name,
            .name = "profile",
            .description = "Get creator profile",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "user_id", .description = "Douyin user id", .required = true, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(profile_cmd);

        const hashtag_cmd = types.Command{
            .site = name,
            .name = "hashtag",
            .description = "Search hashtag",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "query", .description = "Hashtag keyword", .required = true, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(hashtag_cmd);

        const videos_cmd = types.Command{
            .site = name,
            .name = "videos",
            .description = "List user videos",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "user_id", .description = "Douyin user id", .required = true, .arg_type = .string },
                .{ .name = "limit", .description = "Result size", .required = false, .default = "20", .arg_type = .integer },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(videos_cmd);

        const command_names = [_][]const u8{
            "activities",
            "collections",
            "delete",
            "draft",
            "drafts",
            "location",
            "publish",
            "stats",
            "update",
        };
        for (command_names) |n| {
            const cmd = types.Command{
                .site = name,
                .name = n,
                .description = "Douyin command",
                .domain = domain,
                .strategy = .public,
                .browser = false,
                .args = &[_]types.ArgDef{
                    .{ .name = "user_id", .description = "User id", .required = false, .arg_type = .string },
                    .{ .name = "video_id", .description = "Video id", .required = false, .arg_type = .string },
                    .{ .name = "query", .description = "Search query", .required = false, .arg_type = .string },
                    .{ .name = "limit", .description = "Result size", .required = false, .default = "20", .arg_type = .integer },
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

/// 雪球适配器
pub const XueqiuAdapter = struct {
    pub const name = "xueqiu";
    pub const description = "Xueqiu finance platform";
    pub const domain = "xueqiu.com";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;

        const search_cmd = types.Command{
            .site = name,
            .name = "search",
            .description = "Search stocks and topics",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "query", .description = "Search keyword", .required = true, .arg_type = .string },
                .{ .name = "limit", .description = "Result size", .required = false, .default = "20", .arg_type = .integer },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(search_cmd);

        const stock_cmd = types.Command{
            .site = name,
            .name = "stock",
            .description = "Get stock page by symbol",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "symbol", .description = "Stock symbol, e.g. SH600519", .required = true, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(stock_cmd);

        const hot_cmd = types.Command{
            .site = name,
            .name = "hot",
            .description = "Get hot market topics",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "limit", .description = "Result size", .required = false, .default = "20", .arg_type = .integer },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(hot_cmd);

        const command_names = [_][]const u8{
            "earnings-date",
            "feed",
            "fund-holdings",
            "fund-snapshot",
            "hot-stock",
            "watchlist",
        };
        for (command_names) |n| {
            const cmd = types.Command{
                .site = name,
                .name = n,
                .description = "Xueqiu command",
                .domain = domain,
                .strategy = .public,
                .browser = false,
                .args = &[_]types.ArgDef{
                    .{ .name = "symbol", .description = "Stock symbol", .required = false, .arg_type = .string },
                    .{ .name = "fund_code", .description = "Fund code", .required = false, .arg_type = .string },
                    .{ .name = "query", .description = "Search query", .required = false, .arg_type = .string },
                    .{ .name = "limit", .description = "Result size", .required = false, .default = "20", .arg_type = .integer },
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

/// Google 适配器
pub const GoogleAdapter = struct {
    pub const name = "google";
    pub const description = "Google search services";
    pub const domain = "google.com";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;

        const search_cmd = types.Command{
            .site = name,
            .name = "search",
            .description = "Web search",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "query", .description = "Search query", .required = true, .arg_type = .string },
                .{ .name = "limit", .description = "Result size", .required = false, .default = "10", .arg_type = .integer },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(search_cmd);

        const news_cmd = types.Command{
            .site = name,
            .name = "news",
            .description = "Google News search",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "query", .description = "News query", .required = true, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(news_cmd);

        const suggest_cmd = types.Command{
            .site = name,
            .name = "suggest",
            .description = "Search suggestion",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "query", .description = "Suggestion query", .required = true, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(suggest_cmd);

        const trends_cmd = types.Command{
            .site = name,
            .name = "trends",
            .description = "Google Trends explore",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "query", .description = "Trend query", .required = false, .arg_type = .string },
                .{ .name = "geo", .description = "Geo code", .required = false, .default = "US", .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(trends_cmd);
    }
};

/// Pixiv 适配器
pub const PixivAdapter = struct {
    pub const name = "pixiv";
    pub const description = "Pixiv illustrations platform";
    pub const domain = "pixiv.net";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;

        const search_cmd = types.Command{
            .site = name,
            .name = "search",
            .description = "Search illustrations",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "query", .description = "Search query", .required = true, .arg_type = .string },
                .{ .name = "limit", .description = "Result size", .required = false, .default = "20", .arg_type = .integer },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(search_cmd);

        const user_cmd = types.Command{
            .site = name,
            .name = "user",
            .description = "Get user profile",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "user_id", .description = "Pixiv user id", .required = true, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(user_cmd);

        const ranking_cmd = types.Command{
            .site = name,
            .name = "ranking",
            .description = "Get ranking list",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "mode", .description = "Ranking mode", .required = false, .default = "daily", .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(ranking_cmd);

        const detail_cmd = types.Command{
            .site = name,
            .name = "detail",
            .description = "Get illustration detail",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "illust_id", .description = "Illustration id", .required = true, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(detail_cmd);

        const command_names = [_][]const u8{ "download", "illusts" };
        for (command_names) |n| {
            const cmd = types.Command{
                .site = name,
                .name = n,
                .description = "Pixiv command",
                .domain = domain,
                .strategy = .public,
                .browser = false,
                .args = &[_]types.ArgDef{
                    .{ .name = "illust_id", .description = "Illustration id", .required = false, .arg_type = .string },
                    .{ .name = "user_id", .description = "User id", .required = false, .arg_type = .string },
                    .{ .name = "query", .description = "Query", .required = false, .arg_type = .string },
                    .{ .name = "limit", .description = "Result size", .required = false, .default = "20", .arg_type = .integer },
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

/// LinkedIn 适配器
pub const LinkedInAdapter = struct {
    pub const name = "linkedin";
    pub const description = "LinkedIn professional network";
    pub const domain = "linkedin.com";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;

        const search_cmd = types.Command{
            .site = name,
            .name = "search",
            .description = "Search people or content",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "query", .description = "Search query", .required = true, .arg_type = .string },
                .{ .name = "limit", .description = "Result size", .required = false, .default = "10", .arg_type = .integer },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(search_cmd);

        const timeline_cmd = types.Command{
            .site = name,
            .name = "timeline",
            .description = "Get timeline feed",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "user", .description = "Optional username", .required = false, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(timeline_cmd);
    }
};

/// Bloomberg 适配器
pub const BloombergAdapter = struct {
    pub const name = "bloomberg";
    pub const description = "Bloomberg finance and news";
    pub const domain = "bloomberg.com";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;

        const command_names = [_][]const u8{
            "businessweek",
            "economics",
            "feeds",
            "industries",
            "main",
            "markets",
            "news",
            "opinions",
            "politics",
            "tech",
        };
        for (command_names) |n| {
            const cmd = types.Command{
                .site = name,
                .name = n,
                .description = "Bloomberg command",
                .domain = domain,
                .strategy = .public,
                .browser = false,
                .args = &[_]types.ArgDef{
                    .{ .name = "query", .description = "Optional query", .required = false, .arg_type = .string },
                    .{ .name = "limit", .description = "Result size", .required = false, .default = "20", .arg_type = .integer },
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

/// Reuters 适配器
pub const ReutersAdapter = struct {
    pub const name = "reuters";
    pub const description = "Reuters world news";
    pub const domain = "reuters.com";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;

        const search_cmd = types.Command{
            .site = name,
            .name = "search",
            .description = "Search Reuters news",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "query", .description = "Search query", .required = true, .arg_type = .string },
                .{ .name = "limit", .description = "Result size", .required = false, .default = "20", .arg_type = .integer },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(search_cmd);
    }
};

/// Substack 适配器
pub const SubstackAdapter = struct {
    pub const name = "substack";
    pub const description = "Substack newsletters";
    pub const domain = "substack.com";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;

        const search_cmd = types.Command{
            .site = name,
            .name = "search",
            .description = "Search publications",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "query", .description = "Search query", .required = true, .arg_type = .string },
                .{ .name = "limit", .description = "Result size", .required = false, .default = "20", .arg_type = .integer },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(search_cmd);

        const publication_cmd = types.Command{
            .site = name,
            .name = "publication",
            .description = "Open publication homepage",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "name", .description = "Publication name", .required = true, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(publication_cmd);

        const feed_cmd = types.Command{
            .site = name,
            .name = "feed",
            .description = "Open publication feed",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "name", .description = "Publication name", .required = true, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(feed_cmd);
    }
};

/// Medium 适配器
pub const MediumAdapter = struct {
    pub const name = "medium";
    pub const description = "Medium publications and users";
    pub const domain = "medium.com";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;

        const search_cmd = types.Command{
            .site = name,
            .name = "search",
            .description = "Search Medium content",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "query", .description = "Search query", .required = true, .arg_type = .string },
                .{ .name = "limit", .description = "Result size", .required = false, .default = "20", .arg_type = .integer },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(search_cmd);

        const user_cmd = types.Command{
            .site = name,
            .name = "user",
            .description = "Open Medium user profile",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "username", .description = "Medium username", .required = true, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(user_cmd);

        const feed_cmd = types.Command{
            .site = name,
            .name = "feed",
            .description = "Open Medium user feed",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "username", .description = "Medium username", .required = true, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(feed_cmd);
    }
};

/// Yahoo Finance 适配器
pub const YahooFinanceAdapter = struct {
    pub const name = "yahoo-finance";
    pub const description = "Yahoo Finance market quote";
    pub const domain = "finance.yahoo.com";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;

        const quote_cmd = types.Command{
            .site = name,
            .name = "quote",
            .description = "Get symbol quote page",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "symbol", .description = "Stock symbol", .required = true, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(quote_cmd);
    }
};

/// ChatGPT 适配器
pub const ChatgptAdapter = struct {
    pub const name = "chatgpt";
    pub const description = "ChatGPT conversation helper";
    pub const domain = "chat.openai.com";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;

        const command_names = [_][]const u8{ "ask", "ax", "new", "read", "send", "status" };
        for (command_names) |n| {
            const cmd = types.Command{
                .site = name,
                .name = n,
                .description = "ChatGPT command",
                .domain = domain,
                .strategy = .public,
                .browser = false,
                .args = &[_]types.ArgDef{
                    .{ .name = "prompt", .description = "Prompt text", .required = false, .arg_type = .string },
                    .{ .name = "id", .description = "Conversation id", .required = false, .arg_type = .string },
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

/// Codex 适配器
pub const CodexAdapter = struct {
    pub const name = "codex";
    pub const description = "Codex coding assistant helper";
    pub const domain = "chat.openai.com";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;

        const command_names = [_][]const u8{
            "ask", "dump", "export", "extract-diff", "history", "model", "new", "read", "screenshot", "send", "status",
        };
        for (command_names) |n| {
            const cmd = types.Command{
                .site = name,
                .name = n,
                .description = "Codex command",
                .domain = domain,
                .strategy = .public,
                .browser = false,
                .args = &[_]types.ArgDef{
                    .{ .name = "prompt", .description = "Prompt text", .required = false, .arg_type = .string },
                    .{ .name = "id", .description = "Session id", .required = false, .arg_type = .string },
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

/// Cursor 适配器
pub const CursorAdapter = struct {
    pub const name = "cursor";
    pub const description = "Cursor IDE assistant helper";
    pub const domain = "cursor.com";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;

        const command_names = [_][]const u8{
            "ask", "composer", "dump", "export", "extract-code", "history", "model", "new", "read", "screenshot", "send", "status",
        };
        for (command_names) |n| {
            const cmd = types.Command{
                .site = name,
                .name = n,
                .description = "Cursor command",
                .domain = domain,
                .strategy = .public,
                .browser = false,
                .args = &[_]types.ArgDef{
                    .{ .name = "prompt", .description = "Prompt text", .required = false, .arg_type = .string },
                    .{ .name = "id", .description = "Session id", .required = false, .arg_type = .string },
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

/// Notion 适配器
pub const NotionAdapter = struct {
    pub const name = "notion";
    pub const description = "Notion workspace helper";
    pub const domain = "notion.so";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;

        const command_names = [_][]const u8{ "export", "favorites", "new", "read", "search", "sidebar", "status", "write" };
        for (command_names) |n| {
            const cmd = types.Command{
                .site = name,
                .name = n,
                .description = "Notion command",
                .domain = domain,
                .strategy = .public,
                .browser = false,
                .args = &[_]types.ArgDef{
                    .{ .name = "query", .description = "Search or content", .required = false, .arg_type = .string },
                    .{ .name = "id", .description = "Page id", .required = false, .arg_type = .string },
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

/// BOSS 直聘适配器
pub const BossAdapter = struct {
    pub const name = "boss";
    pub const description = "BOSS Zhipin job platform";
    pub const domain = "zhipin.com";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;

        const command_names = [_][]const u8{
            "batchgreet", "chatlist", "chatmsg", "detail", "exchange", "greet", "invite", "joblist", "mark", "recommend", "resume", "search", "send", "stats",
        };
        for (command_names) |n| {
            const cmd = types.Command{
                .site = name,
                .name = n,
                .description = "Boss command",
                .domain = domain,
                .strategy = .public,
                .browser = false,
                .args = &[_]types.ArgDef{
                    .{ .name = "query", .description = "Search keyword", .required = false, .arg_type = .string },
                    .{ .name = "id", .description = "Job or chat id", .required = false, .arg_type = .string },
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

/// Discord Desktop 适配器
pub const DiscordAppAdapter = struct {
    pub const name = "discord-app";
    pub const description = "Discord desktop companion";
    pub const domain = "discord.com";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;

        const command_names = [_][]const u8{ "channels", "members", "read", "search", "send", "servers", "status" };
        for (command_names) |n| {
            const cmd = types.Command{
                .site = name,
                .name = n,
                .description = "Discord command",
                .domain = domain,
                .strategy = .public,
                .browser = false,
                .args = &[_]types.ArgDef{
                    .{ .name = "query", .description = "Search or message text", .required = false, .arg_type = .string },
                    .{ .name = "id", .description = "Server/channel/message id", .required = false, .arg_type = .string },
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

/// Yollomi 适配器
pub const YollomiAdapter = struct {
    pub const name = "yollomi";
    pub const description = "Yollomi media toolkit";
    pub const domain = "yollomi.com";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;

        const command_names = [_][]const u8{
            "background", "edit", "face-swap", "generate", "models", "object-remover", "remove-bg", "restore", "try-on", "upload", "upscale", "video",
        };
        for (command_names) |n| {
            const cmd = types.Command{
                .site = name,
                .name = n,
                .description = "Yollomi command",
                .domain = domain,
                .strategy = .public,
                .browser = false,
                .args = &[_]types.ArgDef{
                    .{ .name = "prompt", .description = "Prompt or task input", .required = false, .arg_type = .string },
                    .{ .name = "id", .description = "Task or asset id", .required = false, .arg_type = .string },
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

/// Apple Podcasts 适配器
pub const ApplePodcastsAdapter = struct {
    pub const name = "apple-podcasts";
    pub const description = "Apple Podcasts directory";
    pub const domain = "podcasts.apple.com";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;

        const search_cmd = types.Command{
            .site = name,
            .name = "search",
            .description = "Search podcasts",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "query", .description = "Search keyword", .required = true, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(search_cmd);

        const episodes_cmd = types.Command{
            .site = name,
            .name = "episodes",
            .description = "Open podcast episodes page",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "id", .description = "Podcast id", .required = true, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(episodes_cmd);

        const top_cmd = types.Command{
            .site = name,
            .name = "top",
            .description = "Open top podcast charts",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{},
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(top_cmd);
    }
};

/// BBC 适配器
pub const BbcAdapter = struct {
    pub const name = "bbc";
    pub const description = "BBC news platform";
    pub const domain = "bbc.com";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        const news_cmd = types.Command{
            .site = name,
            .name = "news",
            .description = "Open BBC News homepage",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{},
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(news_cmd);
    }
};

/// Dictionary 适配器
pub const DictionaryAdapter = struct {
    pub const name = "dictionary";
    pub const description = "Dictionary reference helper";
    pub const domain = "dictionaryapi.dev";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;

        const command_names = [_][]const u8{ "search", "synonyms", "examples" };
        for (command_names) |n| {
            const cmd = types.Command{
                .site = name,
                .name = n,
                .description = "Dictionary command",
                .domain = domain,
                .strategy = .public,
                .browser = false,
                .args = &[_]types.ArgDef{
                    .{ .name = "word", .description = "Word to query", .required = true, .arg_type = .string },
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

/// Dev.to 适配器
pub const DevtoAdapter = struct {
    pub const name = "devto";
    pub const description = "Dev.to developer community";
    pub const domain = "dev.to";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;

        const top_cmd = types.Command{
            .site = name,
            .name = "top",
            .description = "Open top stories",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{},
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(top_cmd);

        const tag_cmd = types.Command{
            .site = name,
            .name = "tag",
            .description = "Open tag page",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "tag", .description = "Tag name", .required = true, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(tag_cmd);

        const user_cmd = types.Command{
            .site = name,
            .name = "user",
            .description = "Open user profile",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "username", .description = "Dev.to username", .required = true, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(user_cmd);
    }
};

/// Hugging Face Daily Papers（对齐 src/clis/hf/top）
pub const HfAdapter = struct {
    pub const name = "hf";
    pub const description = "Hugging Face papers";
    pub const domain = "huggingface.co";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        const top_cmd = types.Command{
            .site = name,
            .name = "top",
            .description = "Top Hugging Face daily papers (API / web entry)",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "limit", .description = "Max papers (informational)", .required = false, .default = "20", .arg_type = .integer },
                .{ .name = "all", .description = "Ignore limit", .required = false, .default = "false", .arg_type = .boolean },
                .{ .name = "date", .description = "YYYY-MM-DD (daily)", .required = false, .arg_type = .string },
                .{ .name = "period", .description = "daily | weekly | monthly", .required = false, .default = "daily", .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(top_cmd);
    }
};

/// xAI Grok（对齐 src/clis/grok/ask）
pub const GrokAdapter = struct {
    pub const name = "grok";
    pub const description = "Grok assistant";
    pub const domain = "grok.com";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        const ask_cmd = types.Command{
            .site = name,
            .name = "ask",
            .description = "Send a message to Grok (browser / login)",
            .domain = domain,
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "prompt", .description = "Prompt text", .required = true, .arg_type = .string },
                .{ .name = "timeout", .description = "Seconds to wait", .required = false, .default = "120", .arg_type = .integer },
                .{ .name = "new", .description = "Start new chat", .required = false, .default = "false", .arg_type = .boolean },
                .{ .name = "web", .description = "Use grok.com web flow", .required = false, .default = "false", .arg_type = .boolean },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(ask_cmd);
    }
};

/// 京东商品（对齐 src/clis/jd/item）
pub const JdAdapter = struct {
    pub const name = "jd";
    pub const description = "JD.com product pages";
    pub const domain = "item.jd.com";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        const item_cmd = types.Command{
            .site = name,
            .name = "item",
            .description = "JD product page: HTTP article excerpt; optional --output for .md (browser deepens if OPENCLI_USE_BROWSER=1)",
            .domain = domain,
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "sku", .description = "Product SKU id", .required = true, .arg_type = .string },
                .{ .name = "output", .description = "Directory to write Markdown (optional)", .required = false, .arg_type = .string },
                .{ .name = "images", .description = "Detail image count (informational)", .required = false, .default = "10", .arg_type = .integer },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(item_cmd);
    }
};

/// 超星学习通（对齐 src/clis/chaoxing/*）
pub const ChaoxingAdapter = struct {
    pub const name = "chaoxing";
    pub const description = "Chaoxing / Xuexitong";
    pub const domain = "chaoxing.com";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        const assignments_cmd = types.Command{
            .site = name,
            .name = "assignments",
            .description = "Assignments list (browser / login)",
            .domain = "mooc2-ans.chaoxing.com",
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "course", .description = "Filter by course name", .required = false, .arg_type = .string },
                .{ .name = "status", .description = "all | pending | submitted | graded", .required = false, .default = "all", .arg_type = .string },
                .{ .name = "limit", .description = "Max rows", .required = false, .default = "20", .arg_type = .integer },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(assignments_cmd);

        const exams_cmd = types.Command{
            .site = name,
            .name = "exams",
            .description = "Exams (browser / login)",
            .domain = "chaoxing.com",
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
        try registry.registerCommand(exams_cmd);
    }
};

/// Coupang（对齐 src/clis/coupang/*）
pub const CoupangAdapter = struct {
    pub const name = "coupang";
    pub const description = "Coupang e-commerce";
    pub const domain = "coupang.com";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        const search_cmd = types.Command{
            .site = name,
            .name = "search",
            .description = "Search Coupang",
            .domain = domain,
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "query", .description = "Search keyword", .required = true, .arg_type = .string },
                .{ .name = "page", .description = "Result page", .required = false, .default = "1", .arg_type = .integer },
                .{ .name = "limit", .description = "Max results", .required = false, .default = "20", .arg_type = .integer },
                .{ .name = "filter", .description = "Optional filter (e.g. rocket)", .required = false, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(search_cmd);

        const cart_cmd = types.Command{
            .site = name,
            .name = "add-to-cart",
            .description = "Product / add-to-cart entry (browser)",
            .domain = domain,
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "product-id", .description = "Coupang product id", .required = false, .arg_type = .string },
                .{ .name = "url", .description = "Product URL", .required = false, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(cart_cmd);
    }
};

/// 携程（对齐 src/clis/ctrip/search）
pub const CtripAdapter = struct {
    pub const name = "ctrip";
    pub const description = "Ctrip travel search";
    pub const domain = "ctrip.com";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        const search_cmd = types.Command{
            .site = name,
            .name = "search",
            .description = "Ctrip search entry",
            .domain = "www.ctrip.com",
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "query", .description = "City or attraction keyword", .required = true, .arg_type = .string },
                .{ .name = "limit", .description = "Max results (informational)", .required = false, .default = "15", .arg_type = .integer },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(search_cmd);
    }
};

/// 即刻 Jike（对齐 src/clis/jike/*）
pub const JikeAdapter = struct {
    pub const name = "jike";
    pub const description = "Jike / okjike social";
    pub const domain = "web.okjike.com";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;

        const search_cmd = types.Command{
            .site = name,
            .name = "search",
            .description = "Search Jike posts (web entry)",
            .domain = domain,
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "query", .description = "Search keyword", .required = true, .arg_type = .string },
                .{ .name = "limit", .description = "Max results (informational)", .required = false, .default = "20", .arg_type = .integer },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(search_cmd);

        const feed_cmd = types.Command{
            .site = name,
            .name = "feed",
            .description = "Following feed (login)",
            .domain = domain,
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "limit", .description = "Max posts (informational)", .required = false, .default = "20", .arg_type = .integer },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(feed_cmd);

        const like_cmd = types.Command{
            .site = name,
            .name = "like",
            .description = "Like a post (browser)",
            .domain = domain,
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "id", .description = "Post id", .required = true, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(like_cmd);

        const comment_cmd = types.Command{
            .site = name,
            .name = "comment",
            .description = "Comment on a post (browser)",
            .domain = domain,
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "id", .description = "Post id", .required = true, .arg_type = .string },
                .{ .name = "text", .description = "Comment text", .required = true, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(comment_cmd);

        const create_cmd = types.Command{
            .site = name,
            .name = "create",
            .description = "Create a post (browser)",
            .domain = domain,
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "text", .description = "Post body", .required = true, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(create_cmd);

        const repost_cmd = types.Command{
            .site = name,
            .name = "repost",
            .description = "Repost (browser)",
            .domain = domain,
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "id", .description = "Post id", .required = true, .arg_type = .string },
                .{ .name = "text", .description = "Optional note", .required = false, .arg_type = .string },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(repost_cmd);

        const notif_cmd = types.Command{
            .site = name,
            .name = "notifications",
            .description = "Notifications (login)",
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
        try registry.registerCommand(notif_cmd);
    }
};