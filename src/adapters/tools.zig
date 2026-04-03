const std = @import("std");
const types = @import("../core/types.zig");

/// ArXiv适配器
pub const ArxivAdapter = struct {
    pub const name = "arxiv";
    pub const description = "ArXiv scientific papers";
    pub const domain = "arxiv.org";
    
    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        
        // search命令
        const search_cmd = types.Command{
            .site = name,
            .name = "search",
            .description = "Search papers",
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
                    .name = "category",
                    .description = "Category (cs, math, physics, etc.)",
                    .required = false,
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
                .{ .name = "Authors", .key = "authors" },
                .{ .name = "Published", .key = "published" },
                .{ .name = "ID", .key = "id" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(search_cmd);

        const paper_cmd = types.Command{
            .site = name,
            .name = "paper",
            .description = "Open arXiv abstract page by id",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "id",
                    .description = "arXiv paper id (e.g. 2301.07041)",
                    .required = true,
                    .arg_type = .string,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Action", .key = "action" },
                .{ .name = "Status", .key = "status" },
                .{ .name = "Detail", .key = "detail" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(paper_cmd);
        
        // download命令
        const download_cmd = types.Command{
            .site = name,
            .name = "download",
            .description = "Download paper PDF",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "id",
                    .description = "Paper ID",
                    .required = true,
                    .arg_type = .string,
                },
                .{
                    .name = "output",
                    .description = "Output path",
                    .required = false,
                    .default = "paper.pdf",
                    .arg_type = .string,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "File", .key = "file" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(download_cmd);
    }
};

/// Unsplash适配器
pub const UnsplashAdapter = struct {
    pub const name = "unsplash";
    pub const description = "Unsplash free photos";
    pub const domain = "unsplash.com";
    
    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        
        // search命令
        const search_cmd = types.Command{
            .site = name,
            .name = "search",
            .description = "Search photos",
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
                    .name = "orientation",
                    .description = "Orientation (landscape, portrait, squarish)",
                    .required = false,
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
                .{ .name = "Description", .key = "description" },
                .{ .name = "Author", .key = "user.name" },
                .{ .name = "Likes", .key = "likes" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(search_cmd);
        
        // random命令
        const random_cmd = types.Command{
            .site = name,
            .name = "random",
            .description = "Get random photo",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "query",
                    .description = "Optional search query",
                    .required = false,
                    .arg_type = .string,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Description", .key = "description" },
                .{ .name = "Author", .key = "user.name" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(random_cmd);
    }
};

/// OpenWeather适配器
pub const WeatherAdapter = struct {
    pub const name = "weather";
    pub const description = "OpenWeather weather data";
    pub const domain = "openweathermap.org";
    
    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        
        // current命令
        const current_cmd = types.Command{
            .site = name,
            .name = "current",
            .description = "Get current weather",
            .domain = domain,
            .strategy = .api_key,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "city",
                    .description = "City name",
                    .required = true,
                    .arg_type = .string,
                },
                .{
                    .name = "units",
                    .description = "Units (metric, imperial, kelvin)",
                    .required = false,
                    .default = "metric",
                    .arg_type = .string,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "City", .key = "name" },
                .{ .name = "Temp", .key = "main.temp" },
                .{ .name = "Weather", .key = "weather.0.description" },
                .{ .name = "Humidity", .key = "main.humidity" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(current_cmd);
        
        // forecast命令
        const forecast_cmd = types.Command{
            .site = name,
            .name = "forecast",
            .description = "Get weather forecast",
            .domain = domain,
            .strategy = .api_key,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "city",
                    .description = "City name",
                    .required = true,
                    .arg_type = .string,
                },
                .{
                    .name = "days",
                    .description = "Number of days",
                    .required = false,
                    .default = "5",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Date", .key = "dt_txt" },
                .{ .name = "Temp", .key = "main.temp" },
                .{ .name = "Weather", .key = "weather.0.description" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(forecast_cmd);
    }
};

/// NewsAPI适配器
pub const NewsAdapter = struct {
    pub const name = "news";
    pub const description = "NewsAPI news aggregator";
    pub const domain = "newsapi.org";
    
    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        
        // top命令 - 头条新闻
        const top_cmd = types.Command{
            .site = name,
            .name = "top",
            .description = "Get top headlines",
            .domain = domain,
            .strategy = .api_key,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "country",
                    .description = "Country code (us, gb, etc.)",
                    .required = false,
                    .default = "us",
                    .arg_type = .string,
                },
                .{
                    .name = "category",
                    .description = "Category (business, tech, sports, etc.)",
                    .required = false,
                    .arg_type = .string,
                },
                .{
                    .name = "limit",
                    .description = "Number of articles",
                    .required = false,
                    .default = "10",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "title" },
                .{ .name = "Source", .key = "source.name" },
                .{ .name = "Published", .key = "publishedAt" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(top_cmd);
        
        // search命令
        const search_cmd = types.Command{
            .site = name,
            .name = "search",
            .description = "Search news",
            .domain = domain,
            .strategy = .api_key,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "query",
                    .description = "Search query",
                    .required = true,
                    .arg_type = .string,
                },
                .{
                    .name = "from",
                    .description = "From date (YYYY-MM-DD)",
                    .required = false,
                    .arg_type = .string,
                },
                .{
                    .name = "to",
                    .description = "To date (YYYY-MM-DD)",
                    .required = false,
                    .arg_type = .string,
                },
                .{
                    .name = "limit",
                    .description = "Number of articles",
                    .required = false,
                    .default = "10",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "title" },
                .{ .name = "Source", .key = "source.name" },
                .{ .name = "Published", .key = "publishedAt" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(search_cmd);
    }
};

/// Wikipedia 适配器
pub const WikipediaAdapter = struct {
    pub const name = "wikipedia";
    pub const description = "Wikipedia public knowledge base";
    pub const domain = "wikipedia.org";

    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;

        const search_cmd = types.Command{
            .site = name,
            .name = "search",
            .description = "Search encyclopedia entries",
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
                .{ .name = "Snippet", .key = "snippet" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(search_cmd);

        const summary_cmd = types.Command{
            .site = name,
            .name = "summary",
            .description = "Get page summary",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "title",
                    .description = "Page title",
                    .required = true,
                    .arg_type = .string,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "title" },
                .{ .name = "Description", .key = "description" },
                .{ .name = "Extract", .key = "extract" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(summary_cmd);

        const random_cmd = types.Command{
            .site = name,
            .name = "random",
            .description = "Get random page summary",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{},
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "title" },
                .{ .name = "Description", .key = "description" },
                .{ .name = "Extract", .key = "extract" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(random_cmd);

        const trending_cmd = types.Command{
            .site = name,
            .name = "trending",
            .description = "Get top viewed pages (date required)",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "date",
                    .description = "Date in YYYY-MM-DD",
                    .required = true,
                    .arg_type = .string,
                },
                .{
                    .name = "limit",
                    .description = "Number of pages",
                    .required = false,
                    .default = "10",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "article" },
                .{ .name = "Views", .key = "views" },
                .{ .name = "Rank", .key = "rank" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(trending_cmd);
    }
};