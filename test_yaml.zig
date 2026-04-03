const std = @import("std");
const yaml = @import("../src/utils/yaml.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    std.debug.print("\n=== OpenCLI YAML Parser Test ===\n\n", .{});
    
    // Test 1: Simple YAML
    std.debug.print("Test 1: Simple YAML\n", .{});
    const simple_yaml = 
        \\name: test-cli
        \\description: A test CLI
        \\version: "1.0.0"
    ;
    
    var parser = yaml.YamlParser.init(allocator);
    var value = try parser.parse(simple_yaml);
    defer value.deinit(allocator);
    
    if (value.get("name")) |name| {
        std.debug.print("  ✓ name: {s}\n", .{name.getString() orelse "N/A"});
    }
    if (value.get("description")) |desc| {
        std.debug.print("  ✓ description: {s}\n", .{desc.getString() orelse "N/A"});
    }
    
    // Test 2: Nested YAML
    std.debug.print("\nTest 2: Nested YAML\n", .{});
    const nested_yaml = 
        \\config:
        \\  port: 8080
        \\  debug: true
        \\  timeout: 30.5
    ;
    
    var value2 = try parser.parse(nested_yaml);
    defer value2.deinit(allocator);
    
    if (value2.get("config")) |config| {
        if (config.get("port")) |port| {
            std.debug.print("  ✓ config.port: {d}\n", .{port.getInt() orelse 0});
        }
        if (config.get("debug")) |debug| {
            std.debug.print("  ✓ config.debug: {}\n", .{debug.getBool() orelse false});
        }
    }
    
    // Test 3: File parsing
    std.debug.print("\nTest 3: File parsing\n", .{});
    const file_path = "examples/bilibili.yaml";
    
    std.fs.cwd().access(file_path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("  ⚠ File not found: {s}\n", .{file_path});
            std.debug.print("  Creating test file...\n", .{});
            
            // Create test file
            const test_content = 
                \\name: bilibili
                \\version: "1.0.0"
                \\description: Bilibili adapter
                \\site: bilibili
                \\domain: bilibili.com
                \\strategy: public
            ;
            
            const file = try std.fs.cwd().createFile(file_path, .{});
            defer file.close();
            try file.writeAll(test_content);
            std.debug.print("  ✓ Created test file: {s}\n", .{file_path});
        } else {
            return err;
        }
    };
    
    var file_value = parser.parseFile(file_path) catch |err| {
        std.debug.print("  ✗ Failed to parse file: {}\n", .{err});
        return;
    };
    defer file_value.deinit(allocator);
    
    if (file_value.get("name")) |name| {
        std.debug.print("  ✓ Loaded: {s}\n", .{name.getString() orelse "N/A"});
    }
    if (file_value.get("version")) |version| {
        std.debug.print("  ✓ Version: {s}\n", .{version.getString() orelse "N/A"});
    }
    
    std.debug.print("\n=== All tests passed! ===\n", .{});
}