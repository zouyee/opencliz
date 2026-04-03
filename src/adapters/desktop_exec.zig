//! 桌面 / Electron 类站点：在 JSON 上合并 CDP 提示（阶段 F），与 `http_exec` 入口 URL 互补。
const std = @import("std");

fn isDesktopSite(site: []const u8) bool {
    const sites = [_][]const u8{ "doubao-app", "chatwise", "cursor", "codex" };
    for (sites) |s| {
        if (std.mem.eql(u8, site, s)) return true;
    }
    return false;
}

/// 若未设置 `OPENCLI_CDP_ENDPOINT`，为对象结果附加 `cdp_hint`，便于与旧版 Node CDP 链路对齐。
pub fn mergeIfDesktopHints(allocator: std.mem.Allocator, site: []const u8, result: *std.json.Value) !void {
    if (!isDesktopSite(site)) return;
    if (result.* != .object) return;

    if (std.process.getEnvVarOwned(allocator, "OPENCLI_CDP_ENDPOINT")) |ep| {
        defer allocator.free(ep);
        try result.object.put("cdp_endpoint_set", .{ .bool = ep.len > 0 });
    } else |_| {
        try result.object.put("cdp_endpoint_set", .{ .bool = false });
        try result.object.put("cdp_hint", .{
            .string = try allocator.dupe(u8, "Set OPENCLI_CDP_ENDPOINT to the app WebSocket debugger URL (see docs/advanced/cdp.md)."),
        });
    }
}
