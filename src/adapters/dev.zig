const std = @import("std");
const types = @import("../core/types.zig");

/// StackOverflow适配器
pub const StackOverflowAdapter = struct {
    pub const name = "stackoverflow";
    pub const description = "StackOverflow Q&A platform";
    pub const domain = "stackoverflow.com";
    
    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        
        // search命令 - 搜索问题
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
                    .name = "tagged",
                    .description = "Tags (comma separated)",
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
                .{ .name = "Score", .key = "score" },
                .{ .name = "Answers", .key = "answer_count" },
                .{ .name = "Views", .key = "view_count" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(search_cmd);
        
        // question命令 - 获取问题详情
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
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "title" },
                .{ .name = "Body", .key = "body" },
                .{ .name = "Score", .key = "score" },
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
                    .name = "id",
                    .description = "User ID",
                    .required = true,
                    .arg_type = .string,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Name", .key = "display_name" },
                .{ .name = "Reputation", .key = "reputation" },
                .{ .name = "Gold", .key = "badge_counts.gold" },
                .{ .name = "Silver", .key = "badge_counts.silver" },
                .{ .name = "Bronze", .key = "badge_counts.bronze" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(user_cmd);

        const hot_cmd = types.Command{
            .site = name,
            .name = "hot",
            .description = "Get hot questions",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "limit",
                    .description = "Number of questions",
                    .required = false,
                    .default = "10",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "title" },
                .{ .name = "Score", .key = "score" },
                .{ .name = "Answers", .key = "answer_count" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(hot_cmd);

        const unanswered_cmd = types.Command{
            .site = name,
            .name = "unanswered",
            .description = "Get unanswered questions",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "limit",
                    .description = "Number of questions",
                    .required = false,
                    .default = "10",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "title" },
                .{ .name = "Answers", .key = "answer_count" },
                .{ .name = "Views", .key = "view_count" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(unanswered_cmd);

        const bounties_cmd = types.Command{
            .site = name,
            .name = "bounties",
            .description = "Get featured bounty questions",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "limit",
                    .description = "Number of questions",
                    .required = false,
                    .default = "10",
                    .arg_type = .integer,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Title", .key = "title" },
                .{ .name = "Bounty", .key = "bounty_amount" },
                .{ .name = "Score", .key = "score" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(bounties_cmd);
    }
};

/// NPM适配器
pub const NpmAdapter = struct {
    pub const name = "npm";
    pub const description = "NPM package registry";
    pub const domain = "npmjs.com";
    
    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        
        // search命令
        const search_cmd = types.Command{
            .site = name,
            .name = "search",
            .description = "Search packages",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "query",
                    .description = "Package name or keyword",
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
                .{ .name = "Name", .key = "package.name" },
                .{ .name = "Version", .key = "package.version" },
                .{ .name = "Description", .key = "package.description" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(search_cmd);
        
        // info命令
        const info_cmd = types.Command{
            .site = name,
            .name = "info",
            .description = "Get package information",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "package",
                    .description = "Package name",
                    .required = true,
                    .arg_type = .string,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Name", .key = "name" },
                .{ .name = "Version", .key = "version" },
                .{ .name = "Author", .key = "author.name" },
                .{ .name = "License", .key = "license" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(info_cmd);
        
        // downloads命令
        const downloads_cmd = types.Command{
            .site = name,
            .name = "downloads",
            .description = "Get package download stats",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "package",
                    .description = "Package name",
                    .required = true,
                    .arg_type = .string,
                },
                .{
                    .name = "period",
                    .description = "Period (day, week, month, year)",
                    .required = false,
                    .default = "month",
                    .arg_type = .string,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Package", .key = "package" },
                .{ .name = "Downloads", .key = "downloads" },
                .{ .name = "Period", .key = "period" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(downloads_cmd);
    }
};

/// PyPI适配器
pub const PyPIAdapter = struct {
    pub const name = "pypi";
    pub const description = "Python Package Index";
    pub const domain = "pypi.org";
    
    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        
        // search命令
        const search_cmd = types.Command{
            .site = name,
            .name = "search",
            .description = "Search packages",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "query",
                    .description = "Package name",
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
                .{ .name = "Version", .key = "version" },
                .{ .name = "Description", .key = "summary" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(search_cmd);
        
        // info命令
        const info_cmd = types.Command{
            .site = name,
            .name = "info",
            .description = "Get package information",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "package",
                    .description = "Package name",
                    .required = true,
                    .arg_type = .string,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Name", .key = "info.name" },
                .{ .name = "Version", .key = "info.version" },
                .{ .name = "Author", .key = "info.author" },
                .{ .name = "License", .key = "info.license" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(info_cmd);
    }
};

/// crates.io适配器 (Rust)
pub const CratesAdapter = struct {
    pub const name = "crates";
    pub const description = "Rust crates registry";
    pub const domain = "crates.io";
    
    pub fn register(allocator: std.mem.Allocator, registry: *types.Registry) !void {
        _ = allocator;
        
        // search命令
        const search_cmd = types.Command{
            .site = name,
            .name = "search",
            .description = "Search crates",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "query",
                    .description = "Crate name",
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
                .{ .name = "Version", .key = "newest_version" },
                .{ .name = "Downloads", .key = "downloads" },
                .{ .name = "Description", .key = "description" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(search_cmd);
        
        // info命令
        const info_cmd = types.Command{
            .site = name,
            .name = "info",
            .description = "Get crate information",
            .domain = domain,
            .strategy = .public,
            .browser = false,
            .args = &[_]types.ArgDef{
                .{
                    .name = "crate",
                    .description = "Crate name",
                    .required = true,
                    .arg_type = .string,
                },
            },
            .columns = &[_]types.ColumnDef{
                .{ .name = "Name", .key = "crate.name" },
                .{ .name = "Version", .key = "crate.newest_version" },
                .{ .name = "Downloads", .key = "crate.downloads" },
                .{ .name = "License", .key = "crate.license" },
            },
            .source = "adapter",
        };
        try registry.registerCommand(info_cmd);
    }
};