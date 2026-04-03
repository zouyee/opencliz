const std = @import("std");
const types = @import("../core/types.zig");

const ac = [_]types.ColumnDef{
    .{ .name = "Action", .key = "action" },
    .{ .name = "Status", .key = "status" },
    .{ .name = "Detail", .key = "detail" },
};

/// 豆包网页端（对齐 src/clis/doubao/*）
pub const DoubaoAdapter = struct {
    pub const name = "doubao";
    pub const description = "Doubao chat (web)";
    pub const domain = "www.doubao.com";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        inline for (.{
            .{ "ask", "Send a prompt to Doubao web chat", &[_]types.ArgDef{
                .{ .name = "text", .description = "Prompt text", .required = true, .arg_type = .string },
                .{ .name = "timeout", .description = "Seconds to wait", .required = false, .default = "60", .arg_type = .integer },
            } },
            .{ "new", "Start a new Doubao conversation", &[_]types.ArgDef{} },
            .{ "read", "Read current conversation (browser)", &[_]types.ArgDef{} },
            .{ "send", "Send a message in current chat", &[_]types.ArgDef{
                .{ .name = "text", .description = "Message text", .required = true, .arg_type = .string },
            } },
            .{ "status", "Doubao page / login state", &[_]types.ArgDef{} },
        }) |item| {
            const cmd = types.Command{
                .site = name,
                .name = item.@"0",
                .description = item.@"1",
                .domain = domain,
                .strategy = .cookie,
                .browser = true,
                .args = item.@"2",
                .columns = &ac,
                .source = "adapter",
            };
            try registry.registerCommand(cmd);
        }
    }
};

/// 豆包桌面客户端（对齐 src/clis/doubao-app/*）
pub const DoubaoAppAdapter = struct {
    pub const name = "doubao-app";
    pub const description = "Doubao desktop app UI";
    pub const domain = "doubao-app";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        inline for (.{
            .{ "ask", "Send message to Doubao app", &[_]types.ArgDef{
                .{ .name = "text", .description = "Prompt", .required = true, .arg_type = .string },
                .{ .name = "timeout", .description = "Seconds", .required = false, .default = "30", .arg_type = .integer },
            } },
            .{ "dump", "Dump app DOM for debugging", &[_]types.ArgDef{} },
            .{ "new", "New conversation in app", &[_]types.ArgDef{} },
            .{ "read", "Read conversation in app", &[_]types.ArgDef{} },
            .{ "screenshot", "Screenshot app window", &[_]types.ArgDef{
                .{ .name = "output", .description = "Output path", .required = false, .arg_type = .string },
            } },
            .{ "send", "Send message", &[_]types.ArgDef{
                .{ .name = "text", .description = "Message", .required = true, .arg_type = .string },
            } },
            .{ "status", "App status", &[_]types.ArgDef{} },
        }) |item| {
            const cmd = types.Command{
                .site = name,
                .name = item.@"0",
                .description = item.@"1",
                .domain = domain,
                .strategy = .cookie,
                .browser = true,
                .args = item.@"2",
                .columns = &ac,
                .source = "adapter",
            };
            try registry.registerCommand(cmd);
        }
    }
};

/// ChatWise（对齐 src/clis/chatwise/*，需 CDP）
pub const ChatwiseAdapter = struct {
    pub const name = "chatwise";
    pub const description = "ChatWise desktop (CDP)";
    pub const domain = "localhost";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        inline for (.{
            .{ "ask", "Send prompt and wait for response", &[_]types.ArgDef{
                .{ .name = "text", .description = "Prompt", .required = true, .arg_type = .string },
                .{ .name = "timeout", .description = "Seconds", .required = false, .default = "30", .arg_type = .integer },
            } },
            .{ "export", "Export conversation", &[_]types.ArgDef{} },
            .{ "history", "Conversation history", &[_]types.ArgDef{} },
            .{ "model", "Model selector", &[_]types.ArgDef{} },
            .{ "new", "New chat", &[_]types.ArgDef{} },
            .{ "read", "Read messages", &[_]types.ArgDef{} },
            .{ "screenshot", "Screenshot", &[_]types.ArgDef{
                .{ .name = "output", .description = "Output path", .required = false, .arg_type = .string },
            } },
            .{ "send", "Send message", &[_]types.ArgDef{
                .{ .name = "text", .description = "Text", .required = true, .arg_type = .string },
            } },
            .{ "status", "ChatWise status", &[_]types.ArgDef{} },
        }) |item| {
            const cmd = types.Command{
                .site = name,
                .name = item.@"0",
                .description = item.@"1",
                .domain = domain,
                .strategy = .cookie,
                .browser = true,
                .args = item.@"2",
                .columns = &ac,
                .source = "adapter",
            };
            try registry.registerCommand(cmd);
        }
    }
};

/// 新浪博客（对齐 src/clis/sinablog/*）
pub const SinablogAdapter = struct {
    pub const name = "sinablog";
    pub const description = "Sina blog";
    pub const domain = "blog.sina.com.cn";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        const article_cmd = types.Command{
            .site = name,
            .name = "article",
            .description = "Load a blog article by URL",
            .domain = domain,
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "url", .description = "Article URL", .required = true, .arg_type = .string },
            },
            .columns = &ac,
            .source = "adapter",
        };
        try registry.registerCommand(article_cmd);

        const hot_cmd = types.Command{
            .site = name,
            .name = "hot",
            .description = "Hot / recommended articles",
            .domain = domain,
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "limit", .description = "Max rows", .required = false, .default = "20", .arg_type = .integer },
            },
            .columns = &ac,
            .source = "adapter",
        };
        try registry.registerCommand(hot_cmd);

        const search_cmd = types.Command{
            .site = name,
            .name = "search",
            .description = "Search Sina blogs",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "query", .description = "Keyword", .required = true, .arg_type = .string },
                .{ .name = "limit", .description = "Max results", .required = false, .default = "20", .arg_type = .integer },
            },
            .columns = &ac,
            .source = "adapter",
        };
        try registry.registerCommand(search_cmd);

        const user_cmd = types.Command{
            .site = name,
            .name = "user",
            .description = "List articles for a blog user id",
            .domain = domain,
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "uid", .description = "Blog user id", .required = true, .arg_type = .string },
                .{ .name = "limit", .description = "Max rows", .required = false, .default = "20", .arg_type = .integer },
            },
            .columns = &ac,
            .source = "adapter",
        };
        try registry.registerCommand(user_cmd);
    }
};

/// 新浪财经 7x24（对齐 src/clis/sinafinance/news）
pub const SinafinanceAdapter = struct {
    pub const name = "sinafinance";
    pub const description = "Sina Finance live news";
    pub const domain = "finance.sina.com.cn";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        const news_cmd = types.Command{
            .site = name,
            .name = "news",
            .description = "Sina Finance 7x24 news (API)",
            .domain = "app.cj.sina.com.cn",
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "limit", .description = "Max items (1-50)", .required = false, .default = "20", .arg_type = .integer },
                .{ .name = "type", .description = "Category 0-9", .required = false, .default = "0", .arg_type = .integer },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "id", .key = "id" },
                .{ .name = "time", .key = "time" },
                .{ .name = "content", .key = "content" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(news_cmd);
    }
};

/// 什么值得买（对齐 src/clis/smzdm/search）
pub const SmzdmAdapter = struct {
    pub const name = "smzdm";
    pub const description = "SMZDM deals search";
    pub const domain = "www.smzdm.com";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        const search_cmd = types.Command{
            .site = name,
            .name = "search",
            .description = "Search SMZDM deals",
            .domain = domain,
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "query", .description = "Keyword", .required = true, .arg_type = .string },
                .{ .name = "limit", .description = "Max results", .required = false, .default = "20", .arg_type = .integer },
            },
            .columns = &ac,
            .source = "adapter",
        };
        try registry.registerCommand(search_cmd);
    }
};

/// 通用网页（对齐 src/clis/web/read）
pub const WebAdapter = struct {
    pub const name = "web";
    pub const description = "Generic web page reader";
    pub const domain = "";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        const read_cmd = types.Command{
            .site = name,
            .name = "read",
            .description = "Fetch URL and export Markdown (browser)",
            .domain = "",
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "url", .description = "Page URL", .required = true, .arg_type = .string },
                .{ .name = "output", .description = "Output directory", .required = false, .default = "./web-articles", .arg_type = .string },
                .{ .name = "download-images", .description = "Download images", .required = false, .default = "true", .arg_type = .boolean },
                .{ .name = "wait", .description = "Seconds after load", .required = false, .default = "3", .arg_type = .integer },
            },
            .columns = &ac,
            .source = "adapter",
        };
        try registry.registerCommand(read_cmd);
    }
};

/// 微信文章（对齐 src/clis/weixin/download）
pub const WeixinAdapter = struct {
    pub const name = "weixin";
    pub const description = "WeChat official article export";
    pub const domain = "mp.weixin.qq.com";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        const dl_cmd = types.Command{
            .site = name,
            .name = "download",
            .description = "Download WeChat article as Markdown",
            .domain = domain,
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "url", .description = "mp.weixin.qq.com article URL", .required = true, .arg_type = .string },
                .{ .name = "output", .description = "Output directory", .required = false, .default = "./weixin-articles", .arg_type = .string },
                .{ .name = "download-images", .description = "Download images", .required = false, .default = "true", .arg_type = .boolean },
            },
            .columns = &ac,
            .source = "adapter",
        };
        try registry.registerCommand(dl_cmd);
    }
};

/// 小宇宙播客（对齐 src/clis/xiaoyuzhou/*）
pub const XiaoyuzhouAdapter = struct {
    pub const name = "xiaoyuzhou";
    pub const description = "Xiaoyuzhou FM";
    pub const domain = "www.xiaoyuzhoufm.com";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        const podcast_cmd = types.Command{
            .site = name,
            .name = "podcast",
            .description = "Podcast profile",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "id", .description = "Podcast id", .required = true, .arg_type = .string },
            },
            .columns = &ac,
            .source = "adapter",
        };
        try registry.registerCommand(podcast_cmd);

        const episode_cmd = types.Command{
            .site = name,
            .name = "episode",
            .description = "Episode detail",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "id", .description = "Episode id", .required = true, .arg_type = .string },
            },
            .columns = &ac,
            .source = "adapter",
        };
        try registry.registerCommand(episode_cmd);

        const pe_cmd = types.Command{
            .site = name,
            .name = "podcast-episodes",
            .description = "List podcast episodes",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{ .name = "id", .description = "Podcast id", .required = true, .arg_type = .string },
                .{ .name = "limit", .description = "Max episodes", .required = false, .default = "15", .arg_type = .integer },
            },
            .columns = &ac,
            .source = "adapter",
        };
        try registry.registerCommand(pe_cmd);
    }
};

/// Antigravity IDE（对齐 src/clis/antigravity/*）
pub const AntigravityAdapter = struct {
    pub const name = "antigravity";
    pub const description = "Antigravity IDE (browser UI)";
    pub const domain = "localhost";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        inline for (.{
            "dump", "extract-code", "model", "new", "read", "send", "serve", "status", "watch",
        }) |n| {
            const cmd = types.Command{
                .site = name,
                .name = n,
                .description = "Antigravity command",
                .domain = domain,
                .strategy = .cookie,
                .browser = true,
                .args = &[_]types.ArgDef{
                    .{ .name = "id", .description = "Optional id", .required = false, .arg_type = .string },
                    .{ .name = "text", .description = "Optional text", .required = false, .arg_type = .string },
                },
                .columns = &ac,
                .source = "adapter",
            };
            try registry.registerCommand(cmd);
        }
    }
};

/// Barchart（对齐 src/clis/barchart/*）
pub const BarchartAdapter = struct {
    pub const name = "barchart";
    pub const description = "Barchart market data";
    pub const domain = "www.barchart.com";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        const flow_cmd = types.Command{
            .site = name,
            .name = "flow",
            .description = "Unusual options activity",
            .domain = domain,
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "type", .description = "all | call | put", .required = false, .default = "all", .arg_type = .string },
                .{ .name = "limit", .description = "Max rows", .required = false, .default = "20", .arg_type = .integer },
            },
            .columns = &ac,
            .source = "adapter",
        };
        try registry.registerCommand(flow_cmd);

        const greeks_cmd = types.Command{
            .site = name,
            .name = "greeks",
            .description = "Options greeks",
            .domain = domain,
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "symbol", .description = "Ticker", .required = true, .arg_type = .string },
                .{ .name = "expiration", .description = "YYYY-MM-DD", .required = false, .arg_type = .string },
                .{ .name = "limit", .description = "Strikes", .required = false, .default = "10", .arg_type = .integer },
            },
            .columns = &ac,
            .source = "adapter",
        };
        try registry.registerCommand(greeks_cmd);

        const options_cmd = types.Command{
            .site = name,
            .name = "options",
            .description = "Options chain",
            .domain = domain,
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "symbol", .description = "Ticker", .required = true, .arg_type = .string },
                .{ .name = "type", .description = "Call | Put", .required = false, .default = "Call", .arg_type = .string },
                .{ .name = "limit", .description = "Max strikes", .required = false, .default = "20", .arg_type = .integer },
            },
            .columns = &ac,
            .source = "adapter",
        };
        try registry.registerCommand(options_cmd);

        const quote_cmd = types.Command{
            .site = name,
            .name = "quote",
            .description = "Stock quote",
            .domain = domain,
            .strategy = .cookie,
            .browser = true,
            .args = &[_]types.ArgDef{
                .{ .name = "symbol", .description = "Ticker", .required = true, .arg_type = .string },
            },
            .columns = &ac,
            .source = "adapter",
        };
        try registry.registerCommand(quote_cmd);
    }
};
