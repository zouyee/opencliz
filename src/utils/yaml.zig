const std = @import("std");
const types = @import("../core/types.zig");

/// YAML解析错误
pub const YamlError = error{
    ParseError,
    InvalidSyntax,
    TypeMismatch,
    MissingField,
    OutOfMemory,
};

/// YAML值类型
pub const YamlValue = union(enum) {
    null,
    bool: bool,
    int: i64,
    float: f64,
    string: []const u8,
    array: []YamlValue,
    object: std.StringHashMap(YamlValue),

    pub fn deinit(self: *YamlValue, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .string => |s| allocator.free(s),
            .array => |arr| {
                for (arr) |*item| {
                    item.deinit(allocator);
                }
                allocator.free(arr);
            },
            .object => |*obj| {
                var it = obj.iterator();
                while (it.next()) |entry| {
                    allocator.free(entry.key_ptr.*);
                    entry.value_ptr.deinit(allocator);
                }
                obj.deinit();
            },
            else => {},
        }
    }

    pub fn getString(self: YamlValue) ?[]const u8 {
        return switch (self) {
            .string => |s| s,
            else => null,
        };
    }

    pub fn getBool(self: YamlValue) ?bool {
        return switch (self) {
            .bool => |b| b,
            else => null,
        };
    }

    pub fn getInt(self: YamlValue) ?i64 {
        return switch (self) {
            .int => |i| i,
            else => null,
        };
    }

    pub fn getObject(self: *const YamlValue) ?*const std.StringHashMap(YamlValue) {
        return switch (self.*) {
            .object => |*obj| obj,
            else => null,
        };
    }

    pub fn getArray(self: *const YamlValue) ?[]const YamlValue {
        return switch (self.*) {
            .array => |arr| arr,
            else => null,
        };
    }

    /// 从对象中获取字段
    pub fn get(self: YamlValue, key: []const u8) ?YamlValue {
        return switch (self) {
            .object => |obj| obj.get(key),
            else => null,
        };
    }
};

fn countLineIndent(raw: []const u8) usize {
    var i: usize = 0;
    while (i < raw.len) : (i += 1) {
        switch (raw[i]) {
            ' ', '\t' => {},
            else => return i,
        }
    }
    return raw.len;
}

const ParentKv = struct {
    parent: *std.StringHashMap(YamlValue),
    key: []const u8,
};

const ObjectFrame = struct {
    map: *std.StringHashMap(YamlValue),
    /// 属于本对象的键行至少要有此缩进（子块比声明行的 `key:` 多至少 1 列）
    min_indent: usize,
    /// 若非空：本 map 由 `parent[key]` 打开，可在首行 `- k: v` 时改为数组
    parent_kv: ?ParentKv = null,
};

const ArrayMapsFrame = struct {
    min_indent: usize,
    /// 父对象中待写入的最终 `commands: [...]` 槽位（解析完成前可能为 `.null`）
    parent_val: *YamlValue,
    items: std.array_list.Managed(YamlValue),
    /// 同层 `- ` 行的缩进（用于识别下一条列表项）
    dash_indent: usize,
    /// 当前列表项在 `items` 中的下标（避免 `items` 扩容使裸指针失效）
    merge_item_index: ?usize = null,
    /// 当前项首行 `- ...` 的缩进（续行须更大）
    merge_item_indent: usize = 0,
};

const ParseFrame = union(enum) {
    object: ObjectFrame,
    array_of_maps: ArrayMapsFrame,
    root_array: RootArrayFrame,
};

const RootArrayFrame = struct {
    min_indent: usize,
};

fn finalizeArrayMapsFrame(parser: YamlParser, af: *ArrayMapsFrame) YamlError!void {
    const slice = try af.items.toOwnedSlice();
    af.parent_val.deinit(parser.allocator);
    af.parent_val.* = YamlValue{ .array = slice };
}

/// `rest` 为 `- ` 之后，形如 `name: hot`
fn parseSingleKvObject(parser: YamlParser, rest: []const u8) YamlError!YamlValue {
    const colon = std.mem.indexOf(u8, rest, ": ") orelse return YamlError.InvalidSyntax;
    const key = std.mem.trim(u8, rest[0..colon], " ");
    const value_str = std.mem.trim(u8, rest[colon + 2 ..], " ");
    const val = try parser.parseValue(value_str);
    var obj = std.StringHashMap(YamlValue).init(parser.allocator);
    const kc = try parser.allocator.dupe(u8, key);
    try obj.put(kc, val);
    return YamlValue{ .object = obj };
}

/// 简化的YAML解析器（缩进对象 + `key:\\n  - a: 1\\n    b: 2` 式对象数组）
pub const YamlParser = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) YamlParser {
        return YamlParser{ .allocator = allocator };
    }

    /// 解析YAML字符串
    pub fn parse(self: YamlParser, content: []const u8) YamlError!YamlValue {
        var lines = std.mem.splitScalar(u8, content, '\n');

        // 检查是否以根级数组开始 (- 开头)
        var first_real_line_indent: usize = 0;
        var starts_with_array = false;
        {
            var peek_lines = std.mem.splitScalar(u8, content, '\n');
            while (peek_lines.next()) |raw_line| {
                const trimmed = std.mem.trim(u8, raw_line, " \t\r");
                if (trimmed.len == 0 or trimmed[0] == '#') continue;
                first_real_line_indent = countLineIndent(raw_line);
                starts_with_array = (trimmed.len > 1 and trimmed[0] == '-' and trimmed[1] == ' ');
                break;
            }
        }

        var stack = std.array_list.Managed(ParseFrame).init(self.allocator);
        defer stack.deinit();

        // 存储根数组的items，直到解析完成才转换为slice
        var root_array_items: ?std.array_list.Managed(YamlValue) = null;

        var root: YamlValue = if (starts_with_array) blk: {
            root_array_items = std.array_list.Managed(YamlValue).init(self.allocator);
            try stack.append(.{ .root_array = .{
                .min_indent = first_real_line_indent,
            } });
            // 暂时设置为一个空数组占位，解析完成后会替换
            break :blk YamlValue{ .array = &.{} };
        } else blk: {
            break :blk YamlValue{ .object = std.StringHashMap(YamlValue).init(self.allocator) };
        };

        if (!starts_with_array) {
            try stack.append(.{ .object = .{
                .map = &root.object,
                .min_indent = 0,
                .parent_kv = null,
            } });
        }

        var last_key: ?[]const u8 = null;

        while (lines.next()) |raw_line| {
            const trimmed = std.mem.trim(u8, raw_line, " \t\r");
            if (trimmed.len == 0 or trimmed[0] == '#') continue;

            const indent = countLineIndent(raw_line);

            while (stack.items.len > 1) {
                const should_pop = switch (stack.items[stack.items.len - 1]) {
                    .object => |o| indent < o.min_indent,
                    .array_of_maps => |a| indent < a.min_indent,
                    .root_array => |ra| indent < ra.min_indent,
                };
                if (!should_pop) break;
                switch (stack.items[stack.items.len - 1]) {
                    .object => {},
                    .array_of_maps => |*af| try finalizeArrayMapsFrame(self, af),
                    .root_array => {},
                }
                _ = stack.pop();
                last_key = null;
            }

            switch (stack.items[stack.items.len - 1]) {
                .root_array => |*ra| {
                    // Root array: each `- ` starts a new object in the array
                    const dash_item = trimmed[0] == '-' and trimmed.len > 1 and trimmed[1] == ' ';
                    if (dash_item and indent == ra.min_indent) {
                        const rest = std.mem.trim(u8, trimmed[2..], " ");
                        const item_obj = try parseSingleKvObject(self, rest);
                        try root_array_items.?.append(item_obj);
                        last_key = null;
                        continue;
                    }
                    // If not a dash item at root indent, it might be a nested value for the last item
                    if (root_array_items.?.items.len > 0 and indent > ra.min_indent) {
                        const last_obj = &root_array_items.?.items[root_array_items.?.items.len - 1];
                        if (last_obj.* == .object) {
                            if (std.mem.indexOf(u8, trimmed, ": ")) |colon_idx| {
                                const key = std.mem.trim(u8, trimmed[0..colon_idx], " ");
                                const value_str = std.mem.trim(u8, trimmed[colon_idx + 2 ..], " ");
                                const value = try self.parseValue(value_str);
                                const key_copy = try self.allocator.dupe(u8, key);
                                try last_obj.object.put(key_copy, value);
                                last_key = key_copy;
                                continue;
                            } else if (std.mem.endsWith(u8, trimmed, ":")) {
                                // Nested block within array item
                                const key = std.mem.trim(u8, trimmed[0 .. trimmed.len - 1], " ");
                                if (key.len == 0) return YamlError.InvalidSyntax;
                                const nested = YamlValue{ .object = std.StringHashMap(YamlValue).init(self.allocator) };
                                const key_copy = try self.allocator.dupe(u8, key);
                                try last_obj.object.put(key_copy, nested);
                                const vptr = last_obj.object.getPtr(key_copy).?;
                                try stack.append(.{ .object = .{
                                    .map = &vptr.object,
                                    .min_indent = indent + 1,
                                    .parent_kv = .{ .parent = &last_obj.object, .key = key_copy },
                                } });
                                last_key = null;
                                continue;
                            }
                        }
                    }
                    return YamlError.InvalidSyntax;
                },
                .array_of_maps => |*af| {
                    const dash_item = trimmed[0] == '-' and trimmed.len > 1 and trimmed[1] == ' ';
                    if (dash_item and indent == af.dash_indent) {
                        const rest = std.mem.trim(u8, trimmed[2..], " ");
                        const item_obj = try parseSingleKvObject(self, rest);
                        try af.items.append(item_obj);
                        af.merge_item_index = af.items.items.len - 1;
                        af.merge_item_indent = indent;
                        last_key = null;
                        continue;
                    }
                    if (af.merge_item_index) |idx| {
                        if (indent > af.merge_item_indent) {
                            if (std.mem.indexOf(u8, trimmed, ": ")) |colon_idx| {
                                const mm = &af.items.items[idx].object;
                                const key = std.mem.trim(u8, trimmed[0..colon_idx], " ");
                                const value_str = std.mem.trim(u8, trimmed[colon_idx + 2 ..], " ");
                                const value = try self.parseValue(value_str);
                                const key_copy = try self.allocator.dupe(u8, key);
                                try mm.put(key_copy, value);
                                last_key = key_copy;
                                continue;
                            } else if (std.mem.endsWith(u8, trimmed, ":")) {
                                // `commands:\n  - name: x\n    args:\n      - name: q` — 列表项内嵌套块
                                const key = std.mem.trim(u8, trimmed[0 .. trimmed.len - 1], " ");
                                if (key.len == 0) return YamlError.InvalidSyntax;
                                const mm = &af.items.items[idx].object;
                                const nested = YamlValue{ .object = std.StringHashMap(YamlValue).init(self.allocator) };
                                const key_copy = try self.allocator.dupe(u8, key);
                                try mm.put(key_copy, nested);
                                const vptr = mm.getPtr(key_copy).?;
                                try stack.append(.{ .object = .{
                                    .map = &vptr.object,
                                    .min_indent = indent + 1,
                                    .parent_kv = .{ .parent = mm, .key = key_copy },
                                } });
                                last_key = null;
                                continue;
                            }
                        }
                    }
                    return YamlError.InvalidSyntax;
                },
                .object => {},
            }

            const current_map = stack.items[stack.items.len - 1].object.map;

            // 必须先识别 `- k: v` 列表项：否则 `- name: hot` 会被当成键 `"- name"` 写入 map，
            // 导致 `commands:` 下空 object 无法转为 array_of_maps。
            if (trimmed[0] == '-' and trimmed.len > 1 and trimmed[1] == ' ') {
                const rest = std.mem.trim(u8, trimmed[2..], " ");
                const can_be_array_of_maps = std.mem.indexOf(u8, rest, ": ") != null;

                if (can_be_array_of_maps) switch (stack.items[stack.items.len - 1]) {
                    .object => |*of| {
                        if (of.map.count() == 0) if (of.parent_kv) |pk| {
                            const frame_min = of.min_indent;
                            var vp = pk.parent.getPtr(pk.key).?;
                            vp.deinit(self.allocator);
                            vp.* = YamlValue{ .null = {} };

                            var items = std.array_list.Managed(YamlValue).init(self.allocator);
                            const first = try parseSingleKvObject(self, rest);
                            try items.append(first);

                            _ = stack.pop();

                            try stack.append(.{ .array_of_maps = .{
                                .min_indent = frame_min,
                                .parent_val = vp,
                                .items = items,
                                .dash_indent = indent,
                                .merge_item_index = 0,
                                .merge_item_indent = indent,
                            } });
                            last_key = null;
                            continue;
                        };
                    },
                    else => {},
                } else {}

                const value = try self.parseValue(rest);

                if (last_key) |key| {
                    if (current_map.getPtr(key)) |existing| {
                        if (existing.* != .array) {
                            var arr = std.array_list.Managed(YamlValue).init(self.allocator);
                            defer arr.deinit();
                            try arr.append(existing.*);
                            try arr.append(value);
                            existing.* = YamlValue{ .array = try arr.toOwnedSlice() };
                        } else {
                            var arr = std.array_list.Managed(YamlValue).init(self.allocator);
                            defer arr.deinit();
                            try arr.appendSlice(existing.array);
                            try arr.append(value);
                            self.allocator.free(existing.array);
                            existing.* = YamlValue{ .array = try arr.toOwnedSlice() };
                        }
                    }
                }
            } else if (std.mem.indexOf(u8, trimmed, ": ")) |colon_idx| {
                const key = std.mem.trim(u8, trimmed[0..colon_idx], " ");
                const value_str = std.mem.trim(u8, trimmed[colon_idx + 2 ..], " ");

                const value = try self.parseValue(value_str);

                const key_copy = try self.allocator.dupe(u8, key);
                try current_map.put(key_copy, value);
                last_key = key_copy;
            } else if (std.mem.endsWith(u8, trimmed, ":")) {
                const key = std.mem.trim(u8, trimmed[0 .. trimmed.len - 1], " ");
                const nested = YamlValue{ .object = std.StringHashMap(YamlValue).init(self.allocator) };

                const key_copy = try self.allocator.dupe(u8, key);
                try current_map.put(key_copy, nested);
                last_key = key_copy;

                const vptr = current_map.getPtr(key_copy).?;
                try stack.append(.{ .object = .{
                    .map = &vptr.object,
                    .min_indent = indent + 1,
                    .parent_kv = .{ .parent = current_map, .key = key_copy },
                } });
            }
        }

        while (stack.items.len > 1) {
            switch (stack.items[stack.items.len - 1]) {
                .object => {},
                .array_of_maps => |*af| try finalizeArrayMapsFrame(self, af),
                .root_array => {},
            }
            _ = stack.pop();
        }

        // 最终化根数组
        if (starts_with_array) {
            const slice = try root_array_items.?.toOwnedSlice();
            root.array = slice;
        }

        return root;
    }

    fn parseValue(self: YamlParser, str: []const u8) YamlError!YamlValue {
        const trimmed = std.mem.trim(u8, str, " ");

        if (trimmed.len == 0) return YamlValue{ .null = {} };

        // 布尔值
        if (std.mem.eql(u8, trimmed, "true")) return YamlValue{ .bool = true };
        if (std.mem.eql(u8, trimmed, "false")) return YamlValue{ .bool = false };
        if (std.mem.eql(u8, trimmed, "null") or std.mem.eql(u8, trimmed, "~")) return YamlValue{ .null = {} };

        // 字符串（带引号）
        if (trimmed.len >= 2 and ((trimmed[0] == '"' and trimmed[trimmed.len - 1] == '"') or
            (trimmed[0] == '\'' and trimmed[trimmed.len - 1] == '\'')))
        {
            const unquoted = trimmed[1 .. trimmed.len - 1];
            const copy = try self.allocator.dupe(u8, unquoted);
            return YamlValue{ .string = copy };
        }

        // 整数
        if (std.fmt.parseInt(i64, trimmed, 10)) |int_val| {
            return YamlValue{ .int = int_val };
        } else |_| {}

        // 浮点数
        if (std.fmt.parseFloat(f64, trimmed)) |float_val| {
            return YamlValue{ .float = float_val };
        } else |_| {}

        // 普通字符串
        const copy = try self.allocator.dupe(u8, trimmed);
        return YamlValue{ .string = copy };
    }

    /// 从文件解析YAML
    pub fn parseFile(self: YamlParser, path: []const u8) !YamlValue {
        const content = try std.fs.cwd().readFileAlloc(self.allocator, path, 1024 * 1024);
        defer self.allocator.free(content);
        return self.parse(content);
    }
};

// ----- Pipeline / runtime command helpers (same module as `YamlValue` to avoid import cycles) -----

pub const ParsePipelineFromYamlError = error{ InvalidPipelineStep, OutOfMemory };

fn yamlScalarToPipelineConfigString(allocator: std.mem.Allocator, v: YamlValue) ![]const u8 {
    return switch (v) {
        .string => |s| try allocator.dupe(u8, s),
        .int => |i| try std.fmt.allocPrint(allocator, "{d}", .{i}),
        .float => |f| try std.fmt.allocPrint(allocator, "{d}", .{f}),
        .bool => |b| try allocator.dupe(u8, if (b) "true" else "false"),
        .null => try allocator.dupe(u8, ""),
        else => try allocator.dupe(u8, ""),
    };
}

fn parseStepConfigStringMap(allocator: std.mem.Allocator, cfg_val: YamlValue) !std.StringHashMap([]const u8) {
    var map = std.StringHashMap([]const u8).init(allocator);
    errdefer {
        var it = map.iterator();
        while (it.next()) |e| {
            allocator.free(e.key_ptr.*);
            allocator.free(e.value_ptr.*);
        }
        map.deinit();
    }
    const obj = cfg_val.getObject() orelse return map;
    var it = obj.iterator();
    while (it.next()) |e| {
        const k = try allocator.dupe(u8, e.key_ptr.*);
        const v = try yamlScalarToPipelineConfigString(allocator, e.value_ptr.*);
        try map.put(k, v);
    }
    return map;
}

fn stepTypeEnumFromYamlObject(step_obj: *const std.StringHashMap(YamlValue)) ?types.PipelineDef.Step.StepType {
    const t = blk: {
        if (step_obj.get("type")) |tv| {
            if (tv.getString()) |s| break :blk s;
        }
        if (step_obj.get("step_type")) |tv| {
            if (tv.getString()) |s| break :blk s;
        }
        return null;
    };
    return std.meta.stringToEnum(types.PipelineDef.Step.StepType, t);
}

/// Parse optional `pipeline:` block into `types.PipelineDef`.
pub fn parsePipelineDefFromYaml(allocator: std.mem.Allocator, pipeline_val: ?YamlValue) ParsePipelineFromYamlError!?types.PipelineDef {
    const root = pipeline_val orelse return null;
    const obj = root.getObject() orelse return null;
    const steps_v = obj.get("steps") orelse return null;
    const steps_arr = steps_v.getArray() orelse return null;

    var steps_list = std.array_list.Managed(types.PipelineDef.Step).init(allocator);
    errdefer {
        for (steps_list.items) |st| {
            allocator.free(st.name);
            var cfg = st.config;
            var cit = cfg.iterator();
            while (cit.next()) |e| {
                allocator.free(e.key_ptr.*);
                allocator.free(e.value_ptr.*);
            }
            cfg.deinit();
        }
        steps_list.deinit();
    }

    for (steps_arr) |step_item| {
        const step_obj = step_item.getObject() orelse return error.InvalidPipelineStep;
        const name_v = step_obj.get("name") orelse return error.InvalidPipelineStep;
        const step_name = name_v.getString() orelse return error.InvalidPipelineStep;
        const stype = stepTypeEnumFromYamlObject(step_obj) orelse return error.InvalidPipelineStep;

        const config = if (step_obj.get("config")) |cv|
            try parseStepConfigStringMap(allocator, cv)
        else
            std.StringHashMap([]const u8).init(allocator);

        try steps_list.append(.{
            .name = try allocator.dupe(u8, step_name),
            .step_type = stype,
            .config = config,
        });
    }

    const owned = try steps_list.toOwnedSlice();
    return types.PipelineDef{ .steps = owned };
}

fn runtimeArgTypeFromString(s: []const u8) types.ArgDef.ArgType {
    if (std.mem.eql(u8, s, "integer") or std.mem.eql(u8, s, "int")) return .integer;
    if (std.mem.eql(u8, s, "number") or std.mem.eql(u8, s, "float")) return .number;
    if (std.mem.eql(u8, s, "boolean") or std.mem.eql(u8, s, "bool")) return .boolean;
    if (std.mem.eql(u8, s, "array")) return .array;
    if (std.mem.eql(u8, s, "object")) return .object;
    return .string;
}

/// `args:` list → `[]types.ArgDef` (heap slice; empty → static empty slice).
pub fn parseRuntimeArgsFromYaml(allocator: std.mem.Allocator, args_val: ?YamlValue) ![]const types.ArgDef {
    const av = args_val orelse return &[_]types.ArgDef{};
    const arr = av.getArray() orelse return &[_]types.ArgDef{};

    var list = std.array_list.Managed(types.ArgDef).init(allocator);
    errdefer {
        for (list.items) |*a| {
            allocator.free(a.name);
            allocator.free(a.description);
            if (a.default) |d| allocator.free(d);
        }
        list.deinit();
    }

    for (arr) |item| {
        const ao = item.getObject() orelse continue;
        const an = ao.get("name") orelse continue;
        const nm = an.getString() orelse continue;
        const adesc = ao.get("description") orelse YamlValue{ .string = "" };
        const ds = adesc.getString() orelse "";
        const req = ao.get("required") orelse YamlValue{ .bool = false };
        const def_v = ao.get("default");
        const atyp = ao.get("arg_type") orelse ao.get("type") orelse YamlValue{ .string = "string" };
        const typ_s = atyp.getString() orelse "string";

        const def_owned: ?[]const u8 = if (def_v) |dv|
            try yamlScalarToPipelineConfigString(allocator, dv)
        else
            null;

        try list.append(.{
            .name = try allocator.dupe(u8, nm),
            .description = try allocator.dupe(u8, ds),
            .required = req.getBool() orelse false,
            .default = def_owned,
            .arg_type = runtimeArgTypeFromString(typ_s),
        });
    }

    if (list.items.len == 0) return &[_]types.ArgDef{};
    return try list.toOwnedSlice();
}

/// `columns:` list → heap slice or null.
pub fn parseRuntimeColumnsFromYaml(allocator: std.mem.Allocator, cols_val: ?YamlValue) !?[]const types.ColumnDef {
    const cv = cols_val orelse return null;
    const arr = cv.getArray() orelse return null;

    var list = std.array_list.Managed(types.ColumnDef).init(allocator);
    errdefer {
        for (list.items) |*c| {
            allocator.free(c.name);
            allocator.free(c.key);
            if (c.format) |f| allocator.free(f);
        }
        list.deinit();
    }

    for (arr) |item| {
        const co = item.getObject() orelse continue;
        const cn = co.get("name") orelse continue;
        const ck = co.get("key") orelse continue;
        const name_s = cn.getString() orelse continue;
        const key_s = ck.getString() orelse continue;
        var fmt_owned: ?[]const u8 = null;
        if (co.get("format")) |fv| {
            if (fv.getString()) |fs| fmt_owned = try allocator.dupe(u8, fs);
        }
        var width_v: ?u16 = null;
        if (co.get("width")) |wv| {
            if (wv.getInt()) |wi| {
                if (wi >= 0) width_v = @intCast(wi);
            }
        }
        try list.append(.{
            .name = try allocator.dupe(u8, name_s),
            .key = try allocator.dupe(u8, key_s),
            .format = fmt_owned,
            .width = width_v,
        });
    }

    if (list.items.len == 0) return null;
    return try list.toOwnedSlice();
}

/// CLI定义YAML结构（`fromYaml` 分配的字段由 `deinit` 释放）
pub const CliDefinition = struct {
    name: []const u8,
    description: []const u8,
    version: []const u8,
    commands: []CommandDefinition,

    pub const CommandDefinition = struct {
        name: []const u8,
        description: []const u8,
        args: []ArgDefinition,
        pipeline: ?types.PipelineDef = null,

        pub const ArgDefinition = struct {
            name: []const u8,
            description: []const u8,
            required: bool = false,
            default: ?[]const u8 = null,
            arg_type: []const u8,
        };

        pub fn deinit(self: *CommandDefinition, allocator: std.mem.Allocator) void {
            allocator.free(self.name);
            allocator.free(self.description);
            for (self.args) |*arg| {
                allocator.free(arg.name);
                allocator.free(arg.description);
                if (arg.default) |d| allocator.free(d);
                allocator.free(arg.arg_type);
            }
            allocator.free(self.args);
            if (self.pipeline) |p| types.pipelineDefDeinit(allocator, p);
            self.* = .{
                .name = "",
                .description = "",
                .args = &[_]ArgDefinition{},
                .pipeline = null,
            };
        }
    };

    pub fn deinit(self: *CliDefinition, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.description);
        allocator.free(self.version);
        for (self.commands) |*cmd| {
            cmd.deinit(allocator);
        }
        allocator.free(self.commands);
        self.* = .{
            .name = "",
            .description = "",
            .version = "",
            .commands = &.{},
        };
    }

    fn parseCommandArgs(allocator: std.mem.Allocator, cmd_val: YamlValue) (YamlError || std.mem.Allocator.Error)![]CommandDefinition.ArgDefinition {
        const args_val = cmd_val.get("args") orelse return try allocator.alloc(CommandDefinition.ArgDefinition, 0);
        const arr = args_val.getArray() orelse return YamlError.TypeMismatch;

        var list = std.array_list.Managed(CommandDefinition.ArgDefinition).init(allocator);
        defer {
            for (list.items) |*ad| {
                allocator.free(ad.name);
                allocator.free(ad.description);
                if (ad.default) |d| allocator.free(d);
                allocator.free(ad.arg_type);
            }
            list.deinit();
        }

        for (arr) |item| {
            const ao = item.getObject() orelse return YamlError.TypeMismatch;
            const an = ao.get("name") orelse return YamlError.MissingField;
            const adesc = ao.get("description") orelse YamlValue{ .string = "" };
            const req = ao.get("required") orelse YamlValue{ .bool = false };
            const def_v = ao.get("default");
            const atyp = ao.get("arg_type") orelse YamlValue{ .string = "string" };

            const nm = an.getString() orelse return YamlError.TypeMismatch;
            const ds = adesc.getString() orelse "";
            const typ_s = atyp.getString() orelse "string";

            const def_owned: ?[]const u8 = if (def_v) |dv|
                try allocator.dupe(u8, dv.getString() orelse return YamlError.TypeMismatch)
            else
                null;

            try list.append(.{
                .name = try allocator.dupe(u8, nm),
                .description = try allocator.dupe(u8, ds),
                .required = req.getBool() orelse false,
                .default = def_owned,
                .arg_type = try allocator.dupe(u8, typ_s),
            });
        }

        return try list.toOwnedSlice();
    }

    /// 从 Yaml 树深拷贝为 `CliDefinition`（`commands` / `args` / `pipeline` 等均分配在堆上）
    pub fn fromYaml(allocator: std.mem.Allocator, yaml_val: YamlValue) (YamlError || ParsePipelineFromYamlError || std.mem.Allocator.Error)!CliDefinition {
        const obj = yaml_val.getObject() orelse return YamlError.TypeMismatch;

        const name_v = obj.get("name") orelse return YamlError.MissingField;
        const desc_v = obj.get("description") orelse YamlValue{ .string = "" };
        const version_v = obj.get("version") orelse YamlValue{ .string = "1.0.0" };

        const name_s = name_v.getString() orelse return YamlError.TypeMismatch;
        const desc_s = desc_v.getString() orelse "";
        const ver_s = version_v.getString() orelse "1.0.0";

        var cmds = std.array_list.Managed(CommandDefinition).init(allocator);
        defer {
            for (cmds.items) |*c| c.deinit(allocator);
            cmds.deinit();
        }

        if (obj.get("commands")) |cv| {
            const arr = cv.getArray() orelse return YamlError.TypeMismatch;
            for (arr) |cmd_val| {
                const cmdo = cmd_val.getObject() orelse return YamlError.TypeMismatch;
                const cn = cmdo.get("name") orelse return YamlError.MissingField;
                const cd = cmdo.get("description") orelse YamlValue{ .string = "" };
                const cname = cn.getString() orelse return YamlError.TypeMismatch;
                const cdesc = cd.getString() orelse "";

                const args_slice = try parseCommandArgs(allocator, cmd_val);
                const pl = try parsePipelineDefFromYaml(allocator, cmdo.get("pipeline"));

                try cmds.append(.{
                    .name = try allocator.dupe(u8, cname),
                    .description = try allocator.dupe(u8, cdesc),
                    .args = args_slice,
                    .pipeline = pl,
                });
            }
        }

        const owned_cmds = try cmds.toOwnedSlice();

        return CliDefinition{
            .name = try allocator.dupe(u8, name_s),
            .description = try allocator.dupe(u8, desc_s),
            .version = try allocator.dupe(u8, ver_s),
            .commands = owned_cmds,
        };
    }
};

/// 测试
const testing = std.testing;

test "parse simple yaml" {
    const allocator = testing.allocator;
    const parser = YamlParser.init(allocator);

    const yaml_content =
        \\name: test-cli
        \\description: A test CLI
        \\version: "1.0.0"
    ;

    var value = try parser.parse(yaml_content);
    defer value.deinit(allocator);

    try testing.expectEqualStrings("test-cli", value.get("name").?.getString().?);
    try testing.expectEqualStrings("A test CLI", value.get("description").?.getString().?);
}

test "parse nested yaml with indent" {
    const allocator = testing.allocator;
    const parser = YamlParser.init(allocator);

    const yaml_content =
        \\config:
        \\  port: 8080
        \\  debug: true
    ;

    var value = try parser.parse(yaml_content);
    defer value.deinit(allocator);

    const config = value.get("config").?;
    try testing.expect(config.get("port").?.getInt().? == 8080);
    try testing.expect(config.get("debug").?.getBool().? == true);
}

test "parse flat top-level keys" {
    const allocator = testing.allocator;
    const parser = YamlParser.init(allocator);

    const yaml_content =
        \\port: 8080
        \\debug: true
    ;

    var value = try parser.parse(yaml_content);
    defer value.deinit(allocator);

    try testing.expect(value.get("port").?.getInt().? == 8080);
    try testing.expect(value.get("debug").?.getBool().? == true);
}

test "parse double nested yaml" {
    const allocator = testing.allocator;
    const parser = YamlParser.init(allocator);

    const yaml_content =
        \\a:
        \\  b:
        \\    c: 42
    ;

    var value = try parser.parse(yaml_content);
    defer value.deinit(allocator);

    const a = value.get("a").?;
    const b = a.get("b").?;
    try testing.expect(b.get("c").?.getInt().? == 42);
}

test "CliDefinition fromYaml without commands" {
    const allocator = testing.allocator;
    const parser = YamlParser.init(allocator);

    const yaml_content =
        \\name: mycli
        \\description: A test CLI
        \\version: "1.0.0"
    ;

    var value = try parser.parse(yaml_content);
    defer value.deinit(allocator);

    var def = try CliDefinition.fromYaml(allocator, value);
    defer def.deinit(allocator);

    try testing.expectEqualStrings("mycli", def.name);
    try testing.expectEqualStrings("A test CLI", def.description);
    try testing.expectEqualStrings("1.0.0", def.version);
    try testing.expectEqual(@as(usize, 0), def.commands.len);
}

test "CliDefinition fromYaml with commands tree" {
    const allocator = testing.allocator;

    var cmd0 = YamlValue{ .object = std.StringHashMap(YamlValue).init(allocator) };
    try cmd0.object.put(try allocator.dupe(u8, "name"), .{ .string = try allocator.dupe(u8, "hot") });
    try cmd0.object.put(try allocator.dupe(u8, "description"), .{ .string = try allocator.dupe(u8, "Trending") });

    var arg0 = YamlValue{ .object = std.StringHashMap(YamlValue).init(allocator) };
    try arg0.object.put(try allocator.dupe(u8, "name"), .{ .string = try allocator.dupe(u8, "query") });
    try arg0.object.put(try allocator.dupe(u8, "description"), .{ .string = try allocator.dupe(u8, "Search text") });
    try arg0.object.put(try allocator.dupe(u8, "required"), .{ .bool = true });
    try arg0.object.put(try allocator.dupe(u8, "arg_type"), .{ .string = try allocator.dupe(u8, "string") });

    var cmd1 = YamlValue{ .object = std.StringHashMap(YamlValue).init(allocator) };
    try cmd1.object.put(try allocator.dupe(u8, "name"), .{ .string = try allocator.dupe(u8, "search") });
    try cmd1.object.put(try allocator.dupe(u8, "description"), .{ .string = try allocator.dupe(u8, "Search") });
    const args1 = try allocator.alloc(YamlValue, 1);
    args1[0] = arg0;
    try cmd1.object.put(try allocator.dupe(u8, "args"), .{ .array = args1 });

    const cmd_slice = try allocator.alloc(YamlValue, 2);
    cmd_slice[0] = cmd0;
    cmd_slice[1] = cmd1;

    var root = YamlValue{ .object = std.StringHashMap(YamlValue).init(allocator) };
    defer root.deinit(allocator);
    try root.object.put(try allocator.dupe(u8, "name"), .{ .string = try allocator.dupe(u8, "demo") });
    try root.object.put(try allocator.dupe(u8, "description"), .{ .string = try allocator.dupe(u8, "d") });
    try root.object.put(try allocator.dupe(u8, "version"), .{ .string = try allocator.dupe(u8, "0.1.0") });
    try root.object.put(try allocator.dupe(u8, "commands"), .{ .array = cmd_slice });

    var def = try CliDefinition.fromYaml(allocator, root);
    defer def.deinit(allocator);

    try testing.expectEqualStrings("demo", def.name);
    try testing.expectEqual(@as(usize, 2), def.commands.len);
    try testing.expectEqualStrings("hot", def.commands[0].name);
    try testing.expectEqual(@as(usize, 0), def.commands[0].args.len);
    try testing.expectEqualStrings("search", def.commands[1].name);
    try testing.expectEqual(@as(usize, 1), def.commands[1].args.len);
    try testing.expectEqualStrings("query", def.commands[1].args[0].name);
    try testing.expect(def.commands[1].args[0].required);
}

test "parse commands array with dash name and merged continuation then fromYaml" {
    const allocator = testing.allocator;
    const parser = YamlParser.init(allocator);

    const yaml_content =
        \\name: demo
        \\description: d
        \\version: "0.1.0"
        \\commands:
        \\  - name: hot
        \\    description: Trending
        \\  - name: search
        \\    description: Find
    ;

    var value = try parser.parse(yaml_content);
    defer value.deinit(allocator);

    const cmds_val = value.get("commands").?;
    const arr = cmds_val.getArray().?;
    try testing.expectEqual(@as(usize, 2), arr.len);
    try testing.expectEqualStrings("hot", arr[0].get("name").?.getString().?);
    try testing.expectEqualStrings("Trending", arr[0].get("description").?.getString().?);
    try testing.expectEqualStrings("search", arr[1].get("name").?.getString().?);
    try testing.expectEqualStrings("Find", arr[1].get("description").?.getString().?);

    var def = try CliDefinition.fromYaml(allocator, value);
    defer def.deinit(allocator);

    try testing.expectEqualStrings("demo", def.name);
    try testing.expectEqual(@as(usize, 2), def.commands.len);
    try testing.expectEqualStrings("hot", def.commands[0].name);
    try testing.expectEqualStrings("Trending", def.commands[0].description);
    try testing.expectEqualStrings("search", def.commands[1].name);
    try testing.expectEqualStrings("Find", def.commands[1].description);
}

test "parse commands with nested args array then fromYaml" {
    const allocator = testing.allocator;
    const parser = YamlParser.init(allocator);

    const yaml_content =
        \\name: demo
        \\description: d
        \\version: "0.1.0"
        \\commands:
        \\  - name: search
        \\    description: Search
        \\    args:
        \\      - name: query
        \\        description: Search text
        \\        required: true
        \\        arg_type: string
    ;

    var value = try parser.parse(yaml_content);
    defer value.deinit(allocator);

    var def = try CliDefinition.fromYaml(allocator, value);
    defer def.deinit(allocator);

    try testing.expectEqual(@as(usize, 1), def.commands.len);
    try testing.expectEqualStrings("search", def.commands[0].name);
    try testing.expectEqual(@as(usize, 1), def.commands[0].args.len);
    try testing.expectEqualStrings("query", def.commands[0].args[0].name);
    try testing.expectEqualStrings("Search text", def.commands[0].args[0].description);
    try testing.expect(def.commands[0].args[0].required);
    try testing.expectEqualStrings("string", def.commands[0].args[0].arg_type);
}

test "parse commands block then sibling top-level key" {
    const allocator = testing.allocator;
    const parser = YamlParser.init(allocator);

    const yaml_content =
        \\name: demo
        \\commands:
        \\  - name: hot
        \\    description: Hi
        \\extra: 42
    ;

    var value = try parser.parse(yaml_content);
    defer value.deinit(allocator);

    try testing.expectEqual(@as(i64, 42), value.get("extra").?.getInt().?);
    const arr = value.get("commands").?.getArray().?;
    try testing.expectEqual(@as(usize, 1), arr.len);
    try testing.expectEqualStrings("hot", arr[0].get("name").?.getString().?);
}

test "parse two commands first with nested args second plain" {
    const allocator = testing.allocator;
    const parser = YamlParser.init(allocator);

    const yaml_content =
        \\name: demo
        \\commands:
        \\  - name: search
        \\    args:
        \\      - name: q
        \\        description: Q
        \\        arg_type: string
        \\  - name: hot
        \\    description: Trending
    ;

    var value = try parser.parse(yaml_content);
    defer value.deinit(allocator);

    var def = try CliDefinition.fromYaml(allocator, value);
    defer def.deinit(allocator);

    try testing.expectEqual(@as(usize, 2), def.commands.len);
    try testing.expectEqualStrings("search", def.commands[0].name);
    try testing.expectEqual(@as(usize, 1), def.commands[0].args.len);
    try testing.expectEqualStrings("q", def.commands[0].args[0].name);
    try testing.expectEqualStrings("hot", def.commands[1].name);
    try testing.expectEqual(@as(usize, 0), def.commands[1].args.len);
}
