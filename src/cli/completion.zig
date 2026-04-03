const std = @import("std");
const types = @import("../core/types.zig");

/// Shell补全生成器
pub const CompletionGenerator = struct {
    allocator: std.mem.Allocator,
    commands: std.array_list.Managed([]const u8),
    options: std.array_list.Managed([]const u8),
    
    pub fn init(allocator: std.mem.Allocator) CompletionGenerator {
        return CompletionGenerator{
            .allocator = allocator,
            .commands = std.array_list.Managed([]const u8).init(allocator),
            .options = std.array_list.Managed([]const u8).init(allocator),
        };
    }
    
    pub fn deinit(self: *CompletionGenerator) void {
        self.commands.deinit();
        self.options.deinit();
    }
    
    /// 添加命令
    pub fn addCommand(self: *CompletionGenerator, name: []const u8) !void {
        try self.commands.append(name);
    }
    
    /// 添加选项
    pub fn addOption(self: *CompletionGenerator, name: []const u8) !void {
        try self.options.append(name);
    }
    
    /// 生成Bash补全脚本
    pub fn generateBash(self: *CompletionGenerator) ![]const u8 {
        var script = std.array_list.Managed(u8).init(self.allocator);
        defer script.deinit();
        
        try script.appendSlice(
            \\\\_opencli_completions() {
            \\\\    local cur prev opts
            \\\\    COMPREPLY=()
            \\\\    cur="${COMP_WORDS[COMP_CWORD]}"
            \\\\    prev="${COMP_WORDS[COMP_CWORD-1]}"
            \\\\n            \\\\    opts="
        );
        
        // 添加所有命令和选项
        for (self.commands.items) |cmd| {
            try script.appendSlice(cmd);
            try script.append(' ');
        }
        
        for (self.options.items) |opt| {
            try script.appendSlice(opt);
            try script.append(' ');
        }
        
        try script.appendSlice(
            \\\""
            \\\\n    
            \\\\    if [[ ${cur} == -* ]] ; then
            \\\\        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            \\\\        return 0
            \\\\    fi
            \\\\}
            \\\\complete -F _opencli_completions opencli
        );
        
        return script.toOwnedSlice();
    }
    
    /// 生成Zsh补全脚本
    pub fn generateZsh(self: *CompletionGenerator) ![]const u8 {
        var script = std.array_list.Managed(u8).init(self.allocator);
        defer script.deinit();
        
        try script.appendSlice("#compdef opencli\n\n");
        try script.appendSlice("_opencli() {\n");
        try script.appendSlice("    local curcontext=\"$curcontext\" state line\n");
        try script.appendSlice("    typeset -A opt_args\n\n");
        try script.appendSlice("    _arguments -C \\\n");
        
        // 添加选项
        for (self.options.items) |opt| {
            try script.appendSlice("        '");
            try script.appendSlice(opt);
            try script.appendSlice("' \\\n");
        }
        
        // 添加命令
        try script.appendSlice("        '1: :->command' \\\n");
        try script.appendSlice("        '*::arg:->args'\n\n");
        
        try script.appendSlice("    case \"$state\" in\n");
        try script.appendSlice("        command)\n");
        try script.appendSlice("            _alternative 'commands:");
        
        for (self.commands.items) |cmd| {
            try script.appendSlice(cmd);
            try script.appendSlice(" ");
        }
        
        try script.appendSlice("'\n");
        try script.appendSlice("            ;;\n");
        try script.appendSlice("    esac\n");
        try script.appendSlice("}\n\n");
        try script.appendSlice("_opencli \"$@\"\n");
        
        return script.toOwnedSlice();
    }
    
    /// 生成Fish补全脚本
    pub fn generateFish(self: *CompletionGenerator) ![]const u8 {
        var script = std.array_list.Managed(u8).init(self.allocator);
        defer script.deinit();
        
        // 添加命令补全
        for (self.commands.items) |cmd| {
            try script.appendSlice("complete -c opencli -f -n '__fish_use_subcommand' -a '");
            try script.appendSlice(cmd);
            try script.appendSlice("'\n");
        }
        
        // 添加选项补全
        for (self.options.items) |opt| {
            try script.appendSlice("complete -c opencli -f -n '__fish_seen_subcommand_from ");
            
            // 为所有命令添加选项
            for (self.commands.items) |cmd| {
                try script.appendSlice(cmd);
                try script.appendSlice(" ");
            }
            
            try script.appendSlice("' -l '");
            
            // 移除 -- 前缀
            const opt_name = if (std.mem.startsWith(u8, opt, "--"))
                opt[2..]
            else if (std.mem.startsWith(u8, opt, "-"))
                opt[1..]
            else
                opt;
            
            try script.appendSlice(opt_name);
            try script.appendSlice("'\n");
        }
        
        return script.toOwnedSlice();
    }
    
    /// 生成补全建议
    pub fn getCompletions(self: *CompletionGenerator, prefix: []const u8) ![][]const u8 {
        var matches = std.array_list.Managed([]const u8).init(self.allocator);
        
        for (self.commands.items) |cmd| {
            if (std.mem.startsWith(u8, cmd, prefix)) {
                try matches.append(cmd);
            }
        }
        
        for (self.options.items) |opt| {
            if (std.mem.startsWith(u8, opt, prefix)) {
                try matches.append(opt);
            }
        }
        
        return matches.toOwnedSlice();
    }
};

/// 补全处理器
pub const CompletionHandler = struct {
    allocator: std.mem.Allocator,
    generator: CompletionGenerator,
    
    pub fn init(allocator: std.mem.Allocator) CompletionHandler {
        var generator = CompletionGenerator.init(allocator);
        
        // 添加默认命令
        generator.addCommand("list") catch {};
        generator.addCommand("doctor") catch {};
        generator.addCommand("version") catch {};
        generator.addCommand("explore") catch {};
        generator.addCommand("synthesize") catch {};
        generator.addCommand("generate") catch {};
        generator.addCommand("cascade") catch {};
        generator.addCommand("plugin") catch {};
        generator.addCommand("register") catch {};
        
        // 添加默认选项
        generator.addOption("--help") catch {};
        generator.addOption("-h") catch {};
        generator.addOption("--version") catch {};
        generator.addOption("-v") catch {};
        generator.addOption("--format") catch {};
        generator.addOption("-f") catch {};
        generator.addOption("--verbose") catch {};
        generator.addOption("--get-completions") catch {};
        generator.addOption("--cursor") catch {};
        
        return CompletionHandler{
            .allocator = allocator,
            .generator = generator,
        };
    }
    
    pub fn deinit(self: *CompletionHandler) void {
        self.generator.deinit();
    }
    
    /// 处理补全请求
    pub fn handleCompletion(self: *CompletionHandler, words: [][]const u8, cursor: usize) !void {
        const stdout = std.fs.File.stdout().deprecatedWriter();
        
        if (cursor == 0 or cursor > words.len) {
            // 显示所有命令
            for (self.generator.commands.items) |cmd| {
                try stdout.print("{s}\n", .{cmd});
            }
            return;
        }
        
        const current_word = words[cursor - 1];
        
        // 获取匹配的建议
        const suggestions = try self.generator.getCompletions(current_word);
        defer self.allocator.free(suggestions);
        
        for (suggestions) |suggestion| {
            try stdout.print("{s}\n", .{suggestion});
        }
    }
    
    /// 打印补全脚本
    pub fn printCompletionScript(self: *CompletionHandler, shell: []const u8) !void {
        const stdout = std.fs.File.stdout().deprecatedWriter();
        
        var script: []const u8 = undefined;
        
        if (std.mem.eql(u8, shell, "bash")) {
            script = try self.generator.generateBash();
        } else if (std.mem.eql(u8, shell, "zsh")) {
            script = try self.generator.generateZsh();
        } else if (std.mem.eql(u8, shell, "fish")) {
            script = try self.generator.generateFish();
        } else {
            try stdout.print("Unsupported shell: {s}\n", .{shell});
            try stdout.print("Supported shells: bash, zsh, fish\n", .{});
            return;
        }
        
        defer self.allocator.free(script);
        try stdout.print("{s}\n", .{script});
    }
};