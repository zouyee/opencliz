const std = @import("std");
const types = @import("../core/types.zig");

/// 颜色代码
pub const Colors = struct {
    pub const reset = "\x1b[0m";
    pub const bold = "\x1b[1m";
    pub const dim = "\x1b[2m";
    pub const red = "\x1b[31m";
    pub const green = "\x1b[32m";
    pub const yellow = "\x1b[33m";
    pub const blue = "\x1b[34m";
    pub const magenta = "\x1b[35m";
    pub const cyan = "\x1b[36m";
    pub const white = "\x1b[37m";
};

/// 样式输出
pub const Style = struct {
    enabled: bool = true,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Style {
        return Style{ .enabled = true, .allocator = allocator };
    }

    pub fn bold(self: Style, text: []const u8) ![]const u8 {
        if (!self.enabled) return self.allocator.dupe(u8, text);
        return std.fmt.allocPrint(self.allocator, "{s}{s}{s}", .{ Colors.bold, text, Colors.reset });
    }

    pub fn dim(self: Style, text: []const u8) ![]const u8 {
        if (!self.enabled) return self.allocator.dupe(u8, text);
        return std.fmt.allocPrint(self.allocator, "{s}{s}{s}", .{ Colors.dim, text, Colors.reset });
    }

    pub fn red(self: Style, text: []const u8) ![]const u8 {
        if (!self.enabled) return self.allocator.dupe(u8, text);
        return std.fmt.allocPrint(self.allocator, "{s}{s}{s}", .{ Colors.red, text, Colors.reset });
    }

    pub fn green(self: Style, text: []const u8) ![]const u8 {
        if (!self.enabled) return self.allocator.dupe(u8, text);
        return std.fmt.allocPrint(self.allocator, "{s}{s}{s}", .{ Colors.green, text, Colors.reset });
    }

    pub fn yellow(self: Style, text: []const u8) ![]const u8 {
        if (!self.enabled) return self.allocator.dupe(u8, text);
        return std.fmt.allocPrint(self.allocator, "{s}{s}{s}", .{ Colors.yellow, text, Colors.reset });
    }

    pub fn cyan(self: Style, text: []const u8) ![]const u8 {
        if (!self.enabled) return self.allocator.dupe(u8, text);
        return std.fmt.allocPrint(self.allocator, "{s}{s}{s}", .{ Colors.cyan, text, Colors.reset });
    }
};

/// 格式化输出
pub fn formatOutput(
    allocator: std.mem.Allocator,
    data: std.json.Value,
    format: types.Config.OutputFormat,
    columns: ?[]const types.ColumnDef,
) !void {
    _ = allocator; // Cleanup handled by caller (ArenaAllocator.destroy or destroyLeakyJsonValue)
    const stdout = std.fs.File.stdout().deprecatedWriter();

    switch (format) {
        .table => try formatTableImpl(data, columns, stdout),
        .json => try writeJson(stdout, data, true),
        .yaml => try formatYaml(data, stdout),
        .markdown => try formatMarkdown(data, stdout),
        .csv => try formatCsv(data, columns, stdout),
        .raw => try formatRaw(data, stdout),
    }

    try stdout.print("\n", .{});
}

/// 表格格式
fn formatTableImpl(
    data: std.json.Value,
    columns: ?[]const types.ColumnDef,
    writer: anytype,
) !void {
    switch (data) {
        .array => |arr| {
            if (arr.items.len == 0) {
                try writer.print("No data\n", .{});
                return;
            }

            const cols = columns orelse try inferColumns(arr.items[0]);
            if (cols.len == 0) {
                try writer.print("No columns to display\n", .{});
                return;
            }

            // 计算列宽
            var col_widths = try std.array_list.Managed(usize).initCapacity(std.heap.page_allocator, cols.len);
            defer col_widths.deinit();

            for (cols) |col| {
                try col_widths.append(col.name.len);
            }

            for (arr.items) |item| {
                for (cols, 0..) |col, i| {
                    const value = getNestedValue(item, col.key);
                    const len = jsonValueLen(value);
                    if (len > col_widths.items[i]) {
                        col_widths.items[i] = len;
                    }
                }
            }

            // 打印表头
            try writer.print("  ", .{});
            for (cols, 0..) |col, i| {
                if (i > 0) try writer.print(" | ", .{});
                try writer.print("{s}", .{col.name});
                try pad(writer, col_widths.items[i] - col.name.len);
            }
            try writer.print("\n", .{});

            // 打印分隔符
            try writer.print("  ", .{});
            for (cols, 0..) |col, i| {
                if (i > 0) try writer.print("-+-", .{});
                var j: usize = 0;
                while (j < col.name.len) : (j += 1) {
                    try writer.print("-", .{});
                }
                try pad(writer, col_widths.items[i] - col.name.len);
            }
            try writer.print("\n", .{});

            // 打印数据行
            for (arr.items) |item| {
                try writer.print("  ", .{});
                for (cols, 0..) |col, i| {
                    if (i > 0) try writer.print(" | ", .{});
                    const value = getNestedValue(item, col.key);
                    try printJsonValue(writer, value);
                    try pad(writer, col_widths.items[i] - jsonValueLen(value));
                }
                try writer.print("\n", .{});
            }
        },
        .object => {
            var it = data.object.iterator();
            while (it.next()) |entry| {
                try writer.print("{s}: ", .{entry.key_ptr.*});
                try writeJson(writer, entry.value_ptr.*, false);
                try writer.print("\n", .{});
            }
        },
        else => {
            try writeJson(writer, data, false);
        },
    }
}

/// CSV格式
fn formatCsv(
    data: std.json.Value,
    columns: ?[]const types.ColumnDef,
    writer: anytype,
) !void {
    switch (data) {
        .array => |arr| {
            if (arr.items.len == 0) return;

            const cols = columns orelse try inferColumns(arr.items[0]);

            // 表头
            for (cols, 0..) |col, i| {
                if (i > 0) try writer.print(",", .{});
                try writer.print("\"{s}\"", .{col.name});
            }
            try writer.print("\n", .{});

            // 数据行
            for (arr.items) |item| {
                for (cols, 0..) |col, i| {
                    if (i > 0) try writer.print(",", .{});
                    const value = getNestedValue(item, col.key);
                    try writer.print("\"", .{});
                    try printJsonValue(writer, value);
                    try writer.print("\"", .{});
                }
                try writer.print("\n", .{});
            }
        },
        else => try writeJson(writer, data, false),
    }
}

/// 原始格式
fn formatRaw(data: std.json.Value, writer: anytype) !void {
    switch (data) {
        .string => |s| try writer.print("{s}", .{s}),
        else => try writeJson(writer, data, false),
    }
}

fn writeJson(writer: anytype, value: std.json.Value, pretty: bool) !void {
    const opts: std.json.Stringify.Options = if (pretty) .{ .whitespace = .indent_2 } else .{};
    const s = try std.json.Stringify.valueAlloc(std.heap.page_allocator, value, opts);
    defer std.heap.page_allocator.free(s);
    try writer.print("{s}", .{s});
}

/// YAML格式
fn formatYaml(data: std.json.Value, writer: anytype) !void {
    try writeYamlValue(data, writer, 0);
}

fn writeYamlValue(data: std.json.Value, writer: anytype, indent: usize) !void {
    switch (data) {
        .null => try writer.print("null", .{}),
        .bool => |b| try writer.print("{s}", .{if (b) "true" else "false"}),
        .integer => |i| try writer.print("{d}", .{i}),
        .float => |f| try writer.print("{d}", .{f}),
        .number_string => |s| try writer.print("{s}", .{s}),
        .string => |s| {
            // Check if string needs quoting
            if (std.mem.indexOfAny(u8, s, ":\n\"'") != null or s.len == 0) {
                try writer.print("\"{s}\"", .{s});
            } else {
                try writer.print("{s}", .{s});
            }
        },
        .array => |arr| {
            if (arr.items.len == 0) {
                try writer.print("[]", .{});
                return;
            }
            for (arr.items) |item| {
                try writer.print("\n", .{});
                try pad(writer, indent);
                try writer.print("- ", .{});

                // For simple values, print inline; for complex, indent
                switch (item) {
                    .null, .bool, .integer, .float, .number_string, .string => {
                        try writeYamlValue(item, writer, indent + 1);
                    },
                    .array, .object => {
                        try writeYamlValue(item, writer, indent + 1);
                    },
                }
            }
        },
        .object => |obj| {
            if (obj.count() == 0) {
                try writer.print("{{}}", .{});
                return;
            }

            var it = obj.iterator();
            var first = true;
            while (it.next()) |entry| {
                if (!first) try writer.print("\n", .{});
                first = false;

                try pad(writer, indent);
                try writer.print("{s}: ", .{entry.key_ptr.*});

                switch (entry.value_ptr.*) {
                    .array, .object => {
                        try writeYamlValue(entry.value_ptr.*, writer, indent + 1);
                    },
                    else => {
                        try writeYamlValue(entry.value_ptr.*, writer, indent);
                    },
                }
            }
        },
    }
}

/// Markdown格式
fn formatMarkdown(data: std.json.Value, writer: anytype) !void {
    switch (data) {
        .array => |arr| {
            if (arr.items.len == 0) {
                try writer.print("*No data*\n", .{});
                return;
            }

            // Generate table header from first item
            if (arr.items[0] == .object) {
                const first = arr.items[0];

                // Header
                try writer.print("| ", .{});
                var it = first.object.iterator();
                var col_count: usize = 0;
                while (it.next()) |entry| {
                    if (col_count > 0) try writer.print(" | ", .{});
                    try writer.print("{s}", .{entry.key_ptr.*});
                    col_count += 1;
                }
                try writer.print(" |\n", .{});

                // Separator
                try writer.print("|", .{});
                var i: usize = 0;
                while (i < col_count) : (i += 1) {
                    try writer.print(" --- |", .{});
                }
                try writer.print("\n", .{});

                // Data rows
                for (arr.items) |item| {
                    try writer.print("| ", .{});
                    var col_it = item.object.iterator();
                    var first_col = true;
                    while (col_it.next()) |entry| {
                        if (!first_col) try writer.print(" | ", .{});
                        first_col = false;

                        switch (entry.value_ptr.*) {
                            .string => |s| {
                                try writer.print("{s}", .{s});
                            },
                            else => try printJsonValue(writer, entry.value_ptr.*),
                        }
                    }
                    try writer.print(" |\n", .{});
                }
            } else {
                // Simple array - use list
                for (arr.items) |item| {
                    try writer.print("- ", .{});
                    try writeMarkdownValue(item, writer);
                    try writer.print("\n", .{});
                }
            }
        },
        .object => |obj| {
            // Object as definition list
            var it = obj.iterator();
            while (it.next()) |entry| {
                try writer.print("**{s}**: ", .{entry.key_ptr.*});
                try writeMarkdownValue(entry.value_ptr.*, writer);
                try writer.print("\n\n", .{});
            }
        },
        else => {
            try writeMarkdownValue(data, writer);
            try writer.print("\n", .{});
        },
    }
}

fn writeMarkdownValue(data: std.json.Value, writer: anytype) !void {
    switch (data) {
        .null => try writer.print("*null*", .{}),
        .bool => |b| try writer.print("{s}", .{if (b) "true" else "false"}),
        .integer => |i| try writer.print("{d}", .{i}),
        .float => |f| try writer.print("{d}", .{f}),
        .number_string => |s| try writer.print("{s}", .{s}),
        .string => |s| try writer.print("{s}", .{s}),
        .array => |arr| {
            for (arr.items, 0..) |item, idx| {
                if (idx > 0) try writer.print(", ", .{});
                try writeMarkdownValue(item, writer);
            }
        },
        .object => |obj| {
            var first = true;
            var it = obj.iterator();
            while (it.next()) |entry| {
                if (!first) try writer.print(", ", .{});
                first = false;
                try writer.print("{s}: ", .{entry.key_ptr.*});
                try writeMarkdownValue(entry.value_ptr.*, writer);
            }
        },
    }
}

// 辅助函数

fn inferColumns(value: std.json.Value) ![]const types.ColumnDef {
    var cols = std.array_list.Managed(types.ColumnDef).init(std.heap.page_allocator);

    if (value == .object) {
        var it = value.object.iterator();
        while (it.next()) |entry| {
            try cols.append(types.ColumnDef{
                .name = entry.key_ptr.*,
                .key = entry.key_ptr.*,
            });
        }
    }

    return cols.toOwnedSlice();
}

pub fn getNestedValue(value: std.json.Value, key: []const u8) std.json.Value {
    var current = value;
    var it = std.mem.splitScalar(u8, key, '.');

    while (it.next()) |k| {
        switch (current) {
            .object => |obj| {
                if (obj.get(k)) |v| {
                    current = v;
                } else {
                    return std.json.Value{ .null = {} };
                }
            },
            else => return std.json.Value{ .null = {} },
        }
    }

    return current;
}

fn jsonValueLen(value: std.json.Value) usize {
    return switch (value) {
        .string => |s| s.len,
        .integer => |i| std.fmt.count("{d}", .{i}),
        .float => |f| std.fmt.count("{d}", .{@as(f64, f)}),
        .number_string => |s| s.len,
        .bool => |b| if (b) 4 else 5,
        .null => 4,
        else => 8,
    };
}

fn printJsonValue(writer: anytype, value: std.json.Value) !void {
    switch (value) {
        .string => |s| try writer.print("{s}", .{s}),
        .integer => |i| try writer.print("{d}", .{i}),
        .float => |f| try writer.print("{d}", .{@as(f64, f)}),
        .number_string => |s| try writer.print("{s}", .{s}),
        .bool => |b| try writer.print("{s}", .{if (b) "true" else "false"}),
        .null => try writer.print("null", .{}),
        else => try writer.print("[complex]", .{}),
    }
}

fn pad(writer: anytype, n: usize) !void {
    var i: usize = 0;
    while (i < n) : (i += 1) {
        try writer.print(" ", .{});
    }
}

/// 集成测试用：将 JSON 写入 writer（带缩进）。
pub fn formatJsonValue(_: std.mem.Allocator, value: std.json.Value, writer: anytype) !void {
    try writeJson(writer, value, true);
}

/// 集成测试用：表格输出（签名与测试一致）。
pub fn formatTable(_: std.mem.Allocator, data: std.json.Value, writer: anytype, columns: ?[]const types.ColumnDef) !void {
    try formatTableImpl(data, columns, writer);
}
