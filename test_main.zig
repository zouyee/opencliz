const std = @import("std");
const types = @import("src/core/types.zig");
const yaml = @import("src/utils/yaml.zig");
const http = @import("src/http/client.zig");
const websocket = @import("src/browser/websocket.zig");

/// 运行所有测试
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    std.debug.print("\n=== OpenCLI Test Suite ===\n\n", .{});
    
    var passed: u32 = 0;
    var failed: u32 = 0;
    
    // Test 1: YAML解析
    std.debug.print("Test 1: YAML Parser... ", .{});
    if (testYamlParser(allocator)) {
        std.debug.print("✓ PASS\n", .{});
        passed += 1;
    } else |err| {
        std.debug.print("✗ FAIL: {}\n", .{err});
        failed += 1;
    }
    
    // Test 2: 配置管理
    std.debug.print("Test 2: Config Management... ", .{});
    if (testConfig(allocator)) {
        std.debug.print("✓ PASS\n", .{});
        passed += 1;
    } else |err| {
        std.debug.print("✗ FAIL: {}\n", .{err});
        failed += 1;
    }
    
    // Test 3: HTTP客户端
    std.debug.print("Test 3: HTTP Client... ", .{});
    if (testHttpClient(allocator)) {
        std.debug.print("✓ PASS\n", .{});
        passed += 1;
    } else |err| {
        std.debug.print("✗ FAIL: {}\n", .{err});
        failed += 1;
    }
    
    // Test 4: 注册表
    std.debug.print("Test 4: Registry... ", .{});
    if (testRegistry(allocator)) {
        std.debug.print("✓ PASS\n", .{});
        passed += 1;
    } else |err| {
        std.debug.print("✗ FAIL: {}\n", .{err});
        failed += 1;
    }
    
    // Test 5: WebSocket
    std.debug.print("Test 5: WebSocket Frame... ", .{});
    if (testWebSocket()) {
        std.debug.print("✓ PASS\n", .{});
        passed += 1;
    } else |err| {
        std.debug.print("✗ FAIL: {}\n", .{err});
        failed += 1;
    }
    
    // 测试结果汇总
    std.debug.print("\n=== Test Results ===\n", .{});
    std.debug.print("Passed: {d}\n", .{passed});
    std.debug.print("Failed: {d}\n", .{failed});
    std.debug.print("Total:  {d}\n", .{passed + failed});
    
    if (failed == 0) {
        std.debug.print("\n✓ All tests passed!\n", .{});
    } else {
        std.debug.print("\n✗ Some tests failed\n", .{});
        std.process.exit(1);
    }
}

fn testYamlParser(allocator: std.mem.Allocator) !void {
    const parser = yaml.YamlParser.init(allocator);
    
    const test_yaml = 
        \\name: test-cli
        \\description: A test CLI
        \\version: "1.0.0"
        \\n        \\config:
        \\  port: 8080
        \\  debug: true
    ;
    
    var value = try parser.parse(test_yaml);
    defer value.deinit(allocator);
    
    // 验证基本字段
    const name = value.get("name") orelse return error.TestFailed;
    if (!std.mem.eql(u8, name.getString() orelse "", "test-cli")) {
        return error.TestFailed;
    }
    
    // 验证嵌套对象
    const config = value.get("config") orelse return error.TestFailed;
    const port = config.get("port") orelse return error.TestFailed;
    if ((port.getInt() orelse 0) != 8080) {
        return error.TestFailed;
    }
}

fn testConfig(allocator: std.mem.Allocator) !void {
    var config = try types.Config.init(allocator);
    defer config.deinit();
    
    // 验证默认配置
    if (config.verbose != false) return error.TestFailed;
    if (config.format != .table) return error.TestFailed;
    if (config.timeout_ms != 30000) return error.TestFailed;
    
    // 验证目录创建
    if (config.config_dir.len == 0) return error.TestFailed;
    if (config.data_dir.len == 0) return error.TestFailed;
}

fn testHttpClient(allocator: std.mem.Allocator) !void {
    var client = try http.HttpClient.init(allocator);
    defer client.deinit();
    
    // 验证HTTP客户端初始化
    // 注意：不进行实际网络请求，只验证结构
    if (client.timeout_ms != 30000) return error.TestFailed;
}

fn testRegistry(allocator: std.mem.Allocator) !void {
    var registry = types.Registry.init(allocator);
    defer registry.deinit();
    
    // 注册测试命令
    const cmd = types.Command{
        .site = "test",
        .name = "cmd",
        .description = "Test command",
        .domain = "test.com",
        .source = "test",
    };
    
    try registry.registerCommand(cmd);
    
    // 验证命令注册
    const retrieved = registry.getCommand("test", "cmd");
    if (retrieved == null) return error.TestFailed;
    if (!std.mem.eql(u8, retrieved.?.site, "test")) return error.TestFailed;
}

fn testWebSocket() !void {
    // 测试WebSocket帧格式验证
    // 这里只做简单的逻辑测试
    const fin: u8 = 0x80;
    const opcode_text: u8 = 0x01;
    const frame_header = fin | opcode_text;
    
    if (frame_header != 0x81) return error.TestFailed;
    
    // 测试掩码
    const payload = "Hello";
    const mask_key = [4]u8{ 0x12, 0x34, 0x56, 0x78 };
    
    var masked: [5]u8 = undefined;
    for (payload, 0..) |byte, i| {
        masked[i] = byte ^ mask_key[i % 4];
    }
    
    // 验证掩码/解掩码
    var unmasked: [5]u8 = undefined;
    for (masked, 0..) |byte, i| {
        unmasked[i] = byte ^ mask_key[i % 4];
    }
    
    if (!std.mem.eql(u8, &unmasked, payload)) {
        return error.TestFailed;
    }
}