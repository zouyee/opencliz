const std = @import("std");

/// 释放 `parseFromSliceLeaky`（或等价地 stringify→leaky parse）生成的 `std.json.Value` 子树。
/// 约定：对象键与 `.string` / `.number_string` 均由同一 `allocator` 分配；勿用于含静态切片键的树。
pub fn destroyLeakyJsonValue(allocator: std.mem.Allocator, v: std.json.Value) void {
    switch (v) {
        .object => |o| {
            var m = o;
            while (m.count() > 0) {
                const k0 = m.keys()[0];
                if (m.fetchSwapRemove(k0)) |kv| {
                    destroyLeakyJsonValue(allocator, kv.value);
                    allocator.free(kv.key);
                } else break;
            }
            m.deinit();
        },
        .array => |a| {
            var list = a;
            for (list.items) |item| {
                destroyLeakyJsonValue(allocator, item);
            }
            list.deinit();
        },
        .string => |s| allocator.free(@constCast(s)),
        .number_string => |s| allocator.free(@constCast(s)),
        else => {},
    }
}

fn destroyHttpBody(allocator: std.mem.Allocator, body: []const u8) void {
    allocator.free(@constCast(body));
}

/// 缓存项
pub fn CacheItem(T: type) type {
    return struct {
        value: T,
        expires_at: i64,
        access_count: u32 = 0,

        pub fn isExpired(self: @This()) bool {
            return std.time.milliTimestamp() > self.expires_at;
        }
    };
}

/// 简单内存缓存；`free_value_opt` 在删除/淘汰/清空时释放 `T`（HTTP body、JSON 树等）。
pub fn Cache(comptime T: type, comptime free_value_opt: ?*const fn (std.mem.Allocator, T) void) type {
    return struct {
        const Self = @This();
        const Item = CacheItem(T);

        allocator: std.mem.Allocator,
        store: std.StringHashMap(Item),
        default_ttl_ms: i64,
        max_size: usize,

        pub fn init(allocator: std.mem.Allocator, default_ttl_ms: i64, max_size: usize) Self {
            return Self{
                .allocator = allocator,
                .store = std.StringHashMap(Item).init(allocator),
                .default_ttl_ms = default_ttl_ms,
                .max_size = max_size,
            };
        }

        pub fn deinit(self: *Self) void {
            self.clear();
            self.store.deinit();
        }

        /// 获取缓存值
        pub fn get(self: *Self, key: []const u8) ?T {
            if (self.store.get(key)) |item| {
                if (!item.isExpired()) {
                    var mutable_item = item;
                    mutable_item.access_count += 1;
                    self.store.put(key, mutable_item) catch {};
                    return item.value;
                } else {
                    if (self.store.fetchRemove(key)) |kv| {
                        if (free_value_opt) |fv| {
                            fv(self.allocator, kv.value.value);
                        }
                        self.allocator.free(kv.key);
                    }
                }
            }
            return null;
        }

        /// 设置缓存值
        pub fn set(self: *Self, key: []const u8, value: T) !void {
            if (self.store.count() >= self.max_size) {
                try self.evict();
            }

            const expires_at = std.time.milliTimestamp() + self.default_ttl_ms;
            const item = Item{
                .value = value,
                .expires_at = expires_at,
            };

            const key_copy = try self.allocator.dupe(u8, key);
            try self.store.put(key_copy, item);
        }

        /// 设置缓存值（带自定义TTL）
        pub fn setWithTTL(self: *Self, key: []const u8, value: T, ttl_ms: i64) !void {
            if (self.store.count() >= self.max_size) {
                try self.evict();
            }

            const expires_at = std.time.milliTimestamp() + ttl_ms;
            const item = Item{
                .value = value,
                .expires_at = expires_at,
            };

            const key_copy = try self.allocator.dupe(u8, key);
            try self.store.put(key_copy, item);
        }

        /// 删除缓存项
        pub fn delete(self: *Self, key: []const u8) void {
            if (self.store.fetchRemove(key)) |kv| {
                if (free_value_opt) |fv| {
                    fv(self.allocator, kv.value.value);
                }
                self.allocator.free(kv.key);
            }
        }

        /// 清空缓存（释放键与值）
        pub fn clear(self: *Self) void {
            var keys = std.array_list.Managed([]const u8).init(self.allocator);
            defer keys.deinit();
            var kit = self.store.keyIterator();
            while (kit.next()) |k| {
                keys.append(k.*) catch return;
            }
            for (keys.items) |k| {
                self.delete(k);
            }
        }

        /// 清理过期项
        pub fn cleanup(self: *Self) void {
            var to_remove = std.array_list.Managed([]const u8).init(self.allocator);
            defer to_remove.deinit();

            var it = self.store.iterator();
            while (it.next()) |entry| {
                if (entry.value_ptr.isExpired()) {
                    to_remove.append(entry.key_ptr.*) catch return;
                }
            }

            for (to_remove.items) |key| {
                self.delete(key);
            }
        }

        /// 淘汰策略（LRU）
        fn evict(self: *Self) !void {
            var min_access: u32 = std.math.maxInt(u32);
            var key_to_remove: ?[]const u8 = null;

            var it = self.store.iterator();
            while (it.next()) |entry| {
                if (entry.value_ptr.access_count < min_access) {
                    min_access = entry.value_ptr.access_count;
                    key_to_remove = entry.key_ptr.*;
                }
            }

            if (key_to_remove) |key| {
                self.delete(key);
            }
        }

        pub fn size(self: *Self) usize {
            return self.store.count();
        }

        pub fn has(self: *Self, key: []const u8) bool {
            if (self.store.get(key)) |item| {
                return !item.isExpired();
            }
            return false;
        }
    };
}

/// HTTP响应缓存
pub const HttpCache = Cache([]const u8, destroyHttpBody);

/// JSON数据缓存
pub const JsonCache = Cache(std.json.Value, destroyLeakyJsonValue);

/// `OPENCLI_CACHE=0` 时关闭 **`http_exec` → `fetchJson`** 的 JSON 响应内存缓存（与脚本 **`OPENCLI_CACHE=0`** 对齐 TS diff 习惯）。
pub fn adapterHttpJsonCacheDisabledByEnv() bool {
    const e = std.process.getEnvVarOwned(std.heap.page_allocator, "OPENCLI_CACHE") catch return false;
    defer std.heap.page_allocator.free(e);
    return std.mem.eql(u8, std.mem.trim(u8, e, " \t\r\n"), "0");
}

fn envI64Or(key: []const u8, default: i64) i64 {
    const e = std.process.getEnvVarOwned(std.heap.page_allocator, key) catch return default;
    defer std.heap.page_allocator.free(e);
    if (e.len == 0) return default;
    return std.fmt.parseInt(i64, e, 10) catch default;
}

fn envUsizeOr(key: []const u8, default: usize) usize {
    const e = std.process.getEnvVarOwned(std.heap.page_allocator, key) catch return default;
    defer std.heap.page_allocator.free(e);
    if (e.len == 0) return default;
    return std.fmt.parseInt(usize, e, 10) catch default;
}

/// 缓存管理器
pub const CacheManager = struct {
    allocator: std.mem.Allocator,
    http_cache: HttpCache,
    json_cache: JsonCache,

    pub fn init(allocator: std.mem.Allocator) CacheManager {
        return CacheManager{
            .allocator = allocator,
            .http_cache = HttpCache.init(allocator, 5 * 60 * 1000, 100),
            .json_cache = JsonCache.init(allocator, 10 * 60 * 1000, 200),
        };
    }

    /// 从环境读取 TTL / 上限（供将来在适配器或 pipeline 中接线时使用）。
    /// `OPENCLI_CACHE_HTTP_TTL_MS`、`OPENCLI_CACHE_JSON_TTL_MS`、`OPENCLI_CACHE_HTTP_MAX`、`OPENCLI_CACHE_JSON_MAX`；解析失败则用内置默认。
    pub fn initFromEnv(allocator: std.mem.Allocator) CacheManager {
        const http_ttl = envI64Or("OPENCLI_CACHE_HTTP_TTL_MS", 5 * 60 * 1000);
        const json_ttl = envI64Or("OPENCLI_CACHE_JSON_TTL_MS", 10 * 60 * 1000);
        const http_max = envUsizeOr("OPENCLI_CACHE_HTTP_MAX", 100);
        const json_max = envUsizeOr("OPENCLI_CACHE_JSON_MAX", 200);
        return CacheManager{
            .allocator = allocator,
            .http_cache = HttpCache.init(allocator, http_ttl, http_max),
            .json_cache = JsonCache.init(allocator, json_ttl, json_max),
        };
    }

    pub fn deinit(self: *CacheManager) void {
        self.http_cache.deinit();
        self.json_cache.deinit();
    }

    pub fn cacheHttpResponse(self: *CacheManager, url: []const u8, response: []const u8) !void {
        const response_copy = try self.allocator.dupe(u8, response);
        try self.http_cache.set(url, response_copy);
    }

    pub fn getCachedHttpResponse(self: *CacheManager, url: []const u8) ?[]const u8 {
        return self.http_cache.get(url);
    }

    pub fn cacheJson(self: *CacheManager, key: []const u8, value: std.json.Value) !void {
        const json_str = try std.json.Stringify.valueAlloc(self.allocator, value, .{});
        defer self.allocator.free(json_str);

        const v = try std.json.parseFromSliceLeaky(std.json.Value, self.allocator, json_str, .{});
        try self.json_cache.set(key, v);
    }

    pub fn getCachedJson(self: *CacheManager, key: []const u8) ?std.json.Value {
        return self.json_cache.get(key);
    }

    pub fn cleanup(self: *CacheManager) void {
        self.http_cache.cleanup();
        self.json_cache.cleanup();
    }

    pub fn clearAll(self: *CacheManager) void {
        self.http_cache.clear();
        self.json_cache.clear();
    }
};

const testing = std.testing;

test "destroyLeakyJsonValue nested" {
    const a = testing.allocator;
    var inner = std.json.ObjectMap.init(a);
    try inner.put(try a.dupe(u8, "k"), .{ .string = try a.dupe(u8, "v") });
    var root = std.json.ObjectMap.init(a);
    try root.put(try a.dupe(u8, "o"), .{ .object = inner });
    destroyLeakyJsonValue(a, .{ .object = root });
}

test "CacheManager http and json lifecycle" {
    const a = testing.allocator;
    var mgr = CacheManager.init(a);
    defer mgr.deinit();

    try mgr.cacheHttpResponse("https://a.example/", "ok");
    try testing.expectEqualStrings("ok", mgr.getCachedHttpResponse("https://a.example/").?);

    try mgr.cacheJson("j1", .{ .bool = true });
    try testing.expectEqual(true, mgr.getCachedJson("j1").?.bool);
}

test "CacheManager initFromEnv builds empty manager" {
    const a = testing.allocator;
    var mgr = CacheManager.initFromEnv(a);
    defer mgr.deinit();
    try testing.expectEqual(@as(usize, 0), mgr.http_cache.size());
}

test "getCachedJson hit can be cloned to another allocator (adapter hit path)" {
    const a = testing.allocator;
    var mgr = CacheManager.init(a);
    defer mgr.deinit();

    try mgr.cacheJson("https://example.test/api", .{ .bool = true });
    const cached = mgr.getCachedJson("https://example.test/api").?;
    const json_str = try std.json.Stringify.valueAlloc(a, cached, .{});
    defer a.free(json_str);
    var parsed = try std.json.parseFromSlice(std.json.Value, a, json_str, .{});
    defer parsed.deinit();
    try std.testing.expect(parsed.value.bool);
}
