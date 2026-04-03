const std = @import("std");
const types = @import("../core/types.zig");

/// JQ风格的查询操作符
pub const JqOperator = enum {
    select,      // .key - 选择字段
    index,       // .[n] - 数组索引
    iterator,    // .[] - 数组迭代
    pipe,        // | - 管道
    comma,       // , - 多个选择
    optional,    // ? - 可选
    recursive,   // .. - 递归下降
};

/// Transform操作类型
pub const TransformOp = union(enum) {
    // 选择操作
    select: []const u8,           // 选择字段 .field
    select_index: usize,          // 数组索引 .[0]
    select_all,                   // 选择所有 .[]
    
    // 过滤操作
    filter: FilterCondition,      // 条件过滤
    
    // 映射操作
    map: MapOperation,            // 数组映射
    
    // 聚合操作
    length,                       // 获取长度
    keys,                         // 获取键
    values,                       // 获取值
    
    // 字符串操作
    split: []const u8,            // 分割字符串
    join: []const u8,             // 连接字符串
    contains: []const u8,         // 包含子串
    
    // 数学操作
    add,                          // 求和
    min,                          // 最小值
    max,                          // 最大值
    avg,                          // 平均值
    
    // 类型转换
    to_string,                    // 转为字符串
    to_number,                    // 转为数字
    to_bool,                      // 转为布尔值
    to_array,                     // 转为数组
    
    // 自定义
    custom: CustomTransform,      // 自定义转换
};

/// 过滤条件
pub const FilterCondition = struct {
    field: []const u8,
    op: ComparisonOp,
    value: std.json.Value,
    
    pub const ComparisonOp = enum {
        eq,     // ==
        ne,     // !=
        gt,     // >
        ge,     // >=
        lt,     // <
        le,     // <=
        contains,
        starts_with,
        ends_with,
    };
};

/// 映射操作
pub const MapOperation = struct {
    input_field: []const u8,
    output_field: []const u8,
    // 使用指针打断递归定义，避免 union 自依赖
    transform: ?*TransformOp = null,
};

/// 最小可用：解析 `.` / `.field` 形式；返回 `null` 表示恒等（原样返回输入）
pub fn parseSimpleQuery(query: []const u8) ?TransformOp {
    const q = std.mem.trim(u8, query, " \t\r\n");
    if (q.len == 0 or std.mem.eql(u8, q, ".")) return null;
    if (q.len > 1 and q[0] == '.') {
        return TransformOp{ .select = q[1..] };
    }
    return null;
}

/// 自定义转换函数
pub const CustomTransform = struct {
    name: []const u8,
    params: std.StringHashMap(std.json.Value),
};

/// Transform执行器
pub const TransformExecutor = struct {
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) TransformExecutor {
        return TransformExecutor{ .allocator = allocator };
    }

    pub fn deinit(_: *TransformExecutor) void {}
    
    /// 执行单个转换操作（显式 anyerror：map 内递归调用需固定错误集）
    pub fn execute(self: *TransformExecutor, data: std.json.Value, op: TransformOp) anyerror!std.json.Value {
        return switch (op) {
            .select => |field| try self.selectField(data, field),
            .select_index => |idx| try self.selectIndex(data, idx),
            .select_all => try self.selectAll(data),
            .filter => |condition| try self.filterData(data, condition),
            .map => |map_op| try self.mapData(data, map_op),
            .length => try self.getLength(data),
            .keys => try self.getKeys(data),
            .values => try self.getValues(data),
            .split => |delimiter| try self.splitString(data, delimiter),
            .join => |delimiter| try self.joinArray(data, delimiter),
            .contains => |substring| try self.containsString(data, substring),
            .add => try self.aggregate(data, .add),
            .min => try self.aggregate(data, .min),
            .max => try self.aggregate(data, .max),
            .avg => try self.aggregate(data, .avg),
            .to_string => try self.toString(data),
            .to_number => try self.toNumber(data),
            .to_bool => try self.toBool(data),
            .to_array => try self.toArray(data),
            .custom => |custom| try self.executeCustom(data, custom),
        };
    }
    
    /// 选择字段 .field
    fn selectField(self: *TransformExecutor, data: std.json.Value, field: []const u8) !std.json.Value {
        _ = self;
        
        switch (data) {
            .object => |obj| {
                if (obj.get(field)) |value| {
                    return value;
                }
                return std.json.Value{ .null = {} };
            },
            else => return std.json.Value{ .null = {} },
        }
    }
    
    /// 选择数组索引 .[n]
    fn selectIndex(self: *TransformExecutor, data: std.json.Value, idx: usize) !std.json.Value {
        _ = self;
        
        switch (data) {
            .array => |arr| {
                if (idx < arr.items.len) {
                    return arr.items[idx];
                }
                return std.json.Value{ .null = {} };
            },
            else => return std.json.Value{ .null = {} },
        }
    }
    
    /// 选择所有数组元素 .[]
    fn selectAll(_: *TransformExecutor, data: std.json.Value) !std.json.Value {
        switch (data) {
            .array => |arr| {
                // 返回数组本身（保持原样）
                return std.json.Value{ .array = arr };
            },
            else => return data,
        }
    }
    
    /// 过滤数据
    fn filterData(self: *TransformExecutor, data: std.json.Value, condition: FilterCondition) !std.json.Value {
        switch (data) {
            .array => |arr| {
                var result = std.json.Array.init(self.allocator);
                
                for (arr.items) |item| {
                    if (try self.matchesCondition(item, condition)) {
                        try result.append(item);
                    }
                }
                
                return std.json.Value{ .array = result };
            },
            else => return data,
        }
    }
    
    /// 检查是否匹配条件
    fn matchesCondition(self: *TransformExecutor, data: std.json.Value, condition: FilterCondition) !bool {
        _ = self;
        
        const field_value = switch (data) {
            .object => |obj| obj.get(condition.field),
            else => null,
        };
        
        if (field_value == null) return false;
        
        return switch (condition.op) {
            .eq => jsonValueEqual(field_value.?, condition.value),
            .ne => !jsonValueEqual(field_value.?, condition.value),
            .gt => jsonValueGreater(field_value.?, condition.value),
            .ge => jsonValueGreaterOrEqual(field_value.?, condition.value),
            .lt => jsonValueLess(field_value.?, condition.value),
            .le => jsonValueLessOrEqual(field_value.?, condition.value),
            else => false,
        };
    }
    
    /// 映射数据
    fn mapData(self: *TransformExecutor, data: std.json.Value, map_op: MapOperation) !std.json.Value {
        switch (data) {
            .array => |arr| {
                var result = std.json.Array.init(self.allocator);
                
                for (arr.items) |item| {
                    const value = switch (item) {
                        .object => |obj| obj.get(map_op.input_field),
                        else => null,
                    };
                    
                    if (value) |v| {
                        if (map_op.transform) |transform| {
                            const transformed = try self.execute(v, transform.*);
                            try result.append(transformed);
                        } else {
                            try result.append(v);
                        }
                    }
                }
                
                return std.json.Value{ .array = result };
            },
            else => return data,
        }
    }
    
    /// 获取长度
    fn getLength(self: *TransformExecutor, data: std.json.Value) !std.json.Value {
        _ = self;
        
        const len: i64 = switch (data) {
            .array => |arr| @intCast(arr.items.len),
            .object => |obj| @intCast(obj.count()),
            .string => |s| @intCast(s.len),
            else => 0,
        };
        
        return std.json.Value{ .integer = len };
    }
    
    /// 获取键
    fn getKeys(self: *TransformExecutor, data: std.json.Value) !std.json.Value {
        switch (data) {
            .object => |obj| {
                var result = std.json.Array.init(self.allocator);
                var it = obj.iterator();
                
                while (it.next()) |entry| {
                    try result.append(std.json.Value{ .string = entry.key_ptr.* });
                }
                
                return std.json.Value{ .array = result };
            },
            else => return std.json.Value{ .array = std.json.Array.init(self.allocator) },
        }
    }
    
    /// 获取值
    fn getValues(self: *TransformExecutor, data: std.json.Value) !std.json.Value {
        switch (data) {
            .object => |obj| {
                var result = std.json.Array.init(self.allocator);
                var it = obj.iterator();
                
                while (it.next()) |entry| {
                    try result.append(entry.value_ptr.*);
                }
                
                return std.json.Value{ .array = result };
            },
            else => return std.json.Value{ .array = std.json.Array.init(self.allocator) },
        }
    }
    
    /// 分割字符串
    fn splitString(self: *TransformExecutor, data: std.json.Value, delimiter: []const u8) !std.json.Value {
        switch (data) {
            .string => |s| {
                var result = std.json.Array.init(self.allocator);
                var it = std.mem.splitSequence(u8, s, delimiter);
                
                while (it.next()) |part| {
                    try result.append(std.json.Value{ .string = part });
                }
                
                return std.json.Value{ .array = result };
            },
            else => return data,
        }
    }
    
    /// 连接数组
    fn joinArray(self: *TransformExecutor, data: std.json.Value, delimiter: []const u8) !std.json.Value {
        _ = self;
        
        switch (data) {
            .array => |arr| {
                var result = std.array_list.Managed(u8).init(std.heap.page_allocator);
                defer result.deinit();
                
                for (arr.items, 0..) |item, i| {
                    if (i > 0) try result.appendSlice(delimiter);
                    
                    switch (item) {
                        .string => |s| try result.appendSlice(s),
                        .integer => |n| try result.writer().print("{d}", .{n}),
                        .float => |n| try result.writer().print("{d}", .{n}),
                        .bool => |b| try result.writer().print("{}", .{b}),
                        else => {},
                    }
                }
                
                return std.json.Value{ .string = try std.heap.page_allocator.dupe(u8, result.items) };
            },
            else => return data,
        }
    }
    
    /// 包含子串
    fn containsString(self: *TransformExecutor, data: std.json.Value, substring: []const u8) !std.json.Value {
        _ = self;
        
        switch (data) {
            .string => |s| {
                return std.json.Value{ .bool = std.mem.indexOf(u8, s, substring) != null };
            },
            else => return std.json.Value{ .bool = false },
        }
    }
    
    /// 聚合操作
    fn aggregate(_: *TransformExecutor, data: std.json.Value, op: enum { add, min, max, avg }) !std.json.Value {
        switch (data) {
            .array => |arr| {
                if (arr.items.len == 0) return std.json.Value{ .integer = 0 };
                
                var sum: f64 = 0;
                var min: f64 = std.math.inf(f64);
                var max: f64 = -std.math.inf(f64);
                var count: usize = 0;
                
                for (arr.items) |item| {
                    const value: f64 = switch (item) {
                        .integer => |n| @floatFromInt(n),
                        .float => |n| n,
                        else => continue,
                    };
                    
                    sum += value;
                    if (value < min) min = value;
                    if (value > max) max = value;
                    count += 1;
                }
                
                return switch (op) {
                    .add => std.json.Value{ .float = sum },
                    .min => std.json.Value{ .float = min },
                    .max => std.json.Value{ .float = max },
                    .avg => std.json.Value{ .float = if (count > 0) sum / @as(f64, @floatFromInt(count)) else 0 },
                };
            },
            else => return data,
        }
    }
    
    /// 类型转换
    fn toString(self: *TransformExecutor, data: std.json.Value) !std.json.Value {
        const str = try std.json.Stringify.valueAlloc(self.allocator, data, .{});
        return std.json.Value{ .string = str };
    }
    
    fn toNumber(_: *TransformExecutor, data: std.json.Value) !std.json.Value {
        return switch (data) {
            .string => |s| {
                if (std.fmt.parseInt(i64, s, 10)) |n| {
                    return std.json.Value{ .integer = n };
                } else |_| {
                    if (std.fmt.parseFloat(f64, s)) |n| {
                        return std.json.Value{ .float = n };
                    } else |_| {
                        return std.json.Value{ .null = {} };
                    }
                }
            },
            .bool => |b| std.json.Value{ .integer = if (b) 1 else 0 },
            else => data,
        };
    }
    
    fn toBool(_: *TransformExecutor, data: std.json.Value) !std.json.Value {
        return switch (data) {
            .null => std.json.Value{ .bool = false },
            .bool => |b| std.json.Value{ .bool = b },
            .integer => |n| std.json.Value{ .bool = n != 0 },
            .float => |n| std.json.Value{ .bool = n != 0 },
            .number_string => |s| std.json.Value{ .bool = s.len > 0 and !std.mem.eql(u8, s, "0") },
            .string => |s| std.json.Value{ .bool = s.len > 0 },
            .array => |arr| std.json.Value{ .bool = arr.items.len > 0 },
            .object => |obj| std.json.Value{ .bool = obj.count() > 0 },
        };
    }
    
    fn toArray(self: *TransformExecutor, data: std.json.Value) !std.json.Value {
        var result = std.json.Array.init(self.allocator);
        try result.append(data);
        return std.json.Value{ .array = result };
    }
    
    /// 执行自定义转换
    fn executeCustom(self: *TransformExecutor, data: std.json.Value, custom: CustomTransform) !std.json.Value {
        // Built-in custom transforms
        if (std.mem.eql(u8, custom.name, "uppercase")) {
            return try self.transformString(data, struct {
                pub fn transform(s: []const u8) []const u8 {
                    // Simple uppercase conversion for ASCII
                    return s; // In real implementation, would convert to uppercase
                }
            }.transform);
        } else if (std.mem.eql(u8, custom.name, "lowercase")) {
            return try self.transformString(data, struct {
                pub fn transform(s: []const u8) []const u8 {
                    return s; // In real implementation, would convert to lowercase
                }
            }.transform);
        } else if (std.mem.eql(u8, custom.name, "reverse")) {
            return try self.reverseArrayOrString(data);
        } else if (std.mem.eql(u8, custom.name, "sort")) {
            return try self.sortArray(data);
        } else if (std.mem.eql(u8, custom.name, "unique")) {
            return try self.uniqueArray(data);
        }
        
        // Unknown custom transform, return data unchanged
        std.log.warn("Unknown custom transform: {s}", .{custom.name});
        return data;
    }
    
    fn transformString(self: *TransformExecutor, data: std.json.Value, comptime transform_fn: fn ([]const u8) []const u8) !std.json.Value {
        switch (data) {
            .string => |s| {
                const transformed = transform_fn(s);
                return std.json.Value{ .string = transformed };
            },
            .array => |arr| {
                var result = std.json.Array.init(self.allocator);
                for (arr.items) |item| {
                    const transformed = try self.transformString(item, transform_fn);
                    try result.append(transformed);
                }
                return std.json.Value{ .array = result };
            },
            else => return data,
        }
    }
    
    fn reverseArrayOrString(self: *TransformExecutor, data: std.json.Value) !std.json.Value {
        switch (data) {
            .string => |s| {
                var result = try self.allocator.alloc(u8, s.len);
                for (s, 0..) |c, i| {
                    result[s.len - 1 - i] = c;
                }
                return std.json.Value{ .string = result };
            },
            .array => |arr| {
                var result = std.json.Array.init(self.allocator);
                var i: usize = arr.items.len;
                while (i > 0) {
                    i -= 1;
                    try result.append(arr.items[i]);
                }
                return std.json.Value{ .array = result };
            },
            else => return data,
        }
    }
    
    fn sortArray(self: *TransformExecutor, data: std.json.Value) !std.json.Value {
        switch (data) {
            .array => |arr| {
                var result = std.json.Array.init(self.allocator);
                for (arr.items) |item| {
                    try result.append(item);
                }
                
                // Simple bubble sort for demonstration
                var i: usize = 0;
                while (i < result.items.len) : (i += 1) {
                    var j: usize = i + 1;
                    while (j < result.items.len) : (j += 1) {
                        const should_swap = switch (result.items[i]) {
                            .integer => |a| a > result.items[j].integer,
                            .float => |a| a > result.items[j].float,
                            .string => |a| std.mem.order(u8, a, result.items[j].string) == .gt,
                            else => false,
                        };
                        
                        if (should_swap) {
                            const temp = result.items[i];
                            result.items[i] = result.items[j];
                            result.items[j] = temp;
                        }
                    }
                }
                
                return std.json.Value{ .array = result };
            },
            else => return data,
        }
    }
    
    fn uniqueArray(self: *TransformExecutor, data: std.json.Value) !std.json.Value {
        switch (data) {
            .array => |arr| {
                var result = std.json.Array.init(self.allocator);
                var seen = std.StringHashMap(void).init(self.allocator);
                defer seen.deinit();
                
                for (arr.items) |item| {
                    const key = try std.json.Stringify.valueAlloc(self.allocator, item, .{});
                    defer self.allocator.free(key);
                    
                    if (!seen.contains(key)) {
                        try seen.put(key, {});
                        try result.append(item);
                    }
                }
                
                return std.json.Value{ .array = result };
            },
            else => return data,
        }
    }
};

/// JSON值比较辅助函数
fn jsonValueEqual(a: std.json.Value, b: std.json.Value) bool {
    if (@intFromEnum(a) != @intFromEnum(b)) return false;
    
    return switch (a) {
        .null => true,
        .bool => |va| va == b.bool,
        .integer => |va| va == b.integer,
        .float => |va| va == b.float,
        .string => |va| std.mem.eql(u8, va, b.string),
        else => false,
    };
}

fn jsonValueGreater(a: std.json.Value, b: std.json.Value) bool {
    return switch (a) {
        .integer => |va| va > b.integer,
        .float => |va| va > b.float,
        else => false,
    };
}

fn jsonValueGreaterOrEqual(a: std.json.Value, b: std.json.Value) bool {
    return jsonValueGreater(a, b) or jsonValueEqual(a, b);
}

fn jsonValueLess(a: std.json.Value, b: std.json.Value) bool {
    return switch (a) {
        .integer => |va| va < b.integer,
        .float => |va| va < b.float,
        else => false,
    };
}

fn jsonValueLessOrEqual(a: std.json.Value, b: std.json.Value) bool {
    return jsonValueLess(a, b) or jsonValueEqual(a, b);
}