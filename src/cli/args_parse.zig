const std = @import("std");

/// 不依赖 clap 的轻量 CLI 解析（兼容 Zig 0.14+）。所有字符串字段均由 `parse` 分配，`deinit` 释放。
pub const ParsedArgs = struct {
    help: bool = false,
    version: bool = false,
    verbose: bool = false,
    format: ?[]u8 = null,
    completions: ?[]u8 = null,
    explore: ?[]u8 = null,
    explore_out: ?[]u8 = null,
    generate: ?[]u8 = null,
    site: ?[]u8 = null,
    positionals: []const []const u8 = &.{},

    pub fn deinit(self: *ParsedArgs, allocator: std.mem.Allocator) void {
        if (self.format) |s| allocator.free(s);
        if (self.completions) |s| allocator.free(s);
        if (self.explore) |s| allocator.free(s);
        if (self.explore_out) |s| allocator.free(s);
        if (self.generate) |s| allocator.free(s);
        if (self.site) |s| allocator.free(s);
        for (self.positionals) |arg| {
            allocator.free(@constCast(arg));
        }
        if (self.positionals.len != 0) {
            allocator.free(@constCast(self.positionals));
        }
        self.* = .{};
    }
};

pub fn parse(allocator: std.mem.Allocator) !ParsedArgs {
    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);

    var fmt: ?[]u8 = null;
    var completions: ?[]u8 = null;
    var explore: ?[]u8 = null;
    var explore_out: ?[]u8 = null;
    var generate: ?[]u8 = null;
    var site: ?[]u8 = null;

    var disarm_optionals = false;
    defer {
        if (!disarm_optionals) {
            if (fmt) |s| allocator.free(s);
            if (completions) |s| allocator.free(s);
            if (explore) |s| allocator.free(s);
            if (explore_out) |s| allocator.free(s);
            if (generate) |s| allocator.free(s);
            if (site) |s| allocator.free(s);
        }
    }

    var help = false;
    var version = false;
    var verbose = false;

    var pos = std.array_list.Managed([]const u8).init(allocator);
    defer pos.deinit();
    errdefer {
        for (pos.items) |arg| {
            allocator.free(@constCast(arg));
        }
    }

    var i: usize = 1;
    while (i < argv.len) {
        const a = argv[i];
        if (std.mem.eql(u8, a, "-h") or std.mem.eql(u8, a, "--help")) {
            help = true;
            i += 1;
            continue;
        }
        if (std.mem.eql(u8, a, "-v") or std.mem.eql(u8, a, "--version")) {
            version = true;
            i += 1;
            continue;
        }
        if (std.mem.eql(u8, a, "--verbose")) {
            verbose = true;
            i += 1;
            continue;
        }
        if (std.mem.eql(u8, a, "-f") or std.mem.eql(u8, a, "--format")) {
            i += 1;
            if (i >= argv.len) return error.MissingArgument;
            fmt = try allocator.dupe(u8, argv[i]);
            i += 1;
            continue;
        }
        if (std.mem.eql(u8, a, "--completions")) {
            i += 1;
            if (i >= argv.len) return error.MissingArgument;
            completions = try allocator.dupe(u8, argv[i]);
            i += 1;
            continue;
        }
        if (std.mem.eql(u8, a, "--explore")) {
            i += 1;
            if (i >= argv.len) return error.MissingArgument;
            explore = try allocator.dupe(u8, argv[i]);
            i += 1;
            continue;
        }
        if (std.mem.eql(u8, a, "--explore-out")) {
            i += 1;
            if (i >= argv.len) return error.MissingArgument;
            explore_out = try allocator.dupe(u8, argv[i]);
            i += 1;
            continue;
        }
        if (std.mem.eql(u8, a, "--generate")) {
            i += 1;
            if (i >= argv.len) return error.MissingArgument;
            generate = try allocator.dupe(u8, argv[i]);
            i += 1;
            continue;
        }
        if (std.mem.eql(u8, a, "--site")) {
            i += 1;
            if (i >= argv.len) return error.MissingArgument;
            site = try allocator.dupe(u8, argv[i]);
            i += 1;
            continue;
        }
        if (std.mem.startsWith(u8, a, "-")) {
            try pos.append(try allocator.dupe(u8, a));
            i += 1;
            continue;
        }
        try pos.append(try allocator.dupe(u8, a));
        i += 1;
    }

    const owned_pos = try pos.toOwnedSlice();

    disarm_optionals = true;
    return ParsedArgs{
        .help = help,
        .version = version,
        .verbose = verbose,
        .format = fmt,
        .completions = completions,
        .explore = explore,
        .explore_out = explore_out,
        .generate = generate,
        .site = site,
        .positionals = owned_pos,
    };
}

/// 仅释放 `positionals`（兼容旧调用点；完整释放请用 `ParsedArgs.deinit`）。
pub fn deinitPositionals(allocator: std.mem.Allocator, p: *ParsedArgs) void {
    for (p.positionals) |arg| {
        allocator.free(@constCast(arg));
    }
    if (p.positionals.len != 0) {
        allocator.free(@constCast(p.positionals));
    }
    p.positionals = &.{};
}
