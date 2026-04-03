const std = @import("std");
const types = @import("core/types.zig");
const helpers = @import("utils/helpers.zig");
const format = @import("output/format.zig");

// Integration / fixture tests（侧载以注册 test 块；避免顶层重复 `const _`）
comptime {
    _ = @import("tests/integration_tests.zig");
    _ = @import("tests/fixture_json_test.zig");
    _ = @import("tests/pipeline_fetch_cache_test.zig");
    _ = @import("tests/daemon_contract_test.zig");
    _ = @import("tests/daemon_tcp_e2e_test.zig");
    _ = @import("tests/ai_explore_golden_test.zig");
    _ = @import("plugin/quickjs_runtime.zig");
}

test "Config initialization" {
    const allocator = std.testing.allocator;

    var config = try types.Config.init(allocator);
    defer config.deinit();

    try std.testing.expect(config.verbose == false);
    try std.testing.expect(config.format == .table);
    try std.testing.expect(config.timeout_ms == 30000);
}

test "AuthStrategy parsing" {
    const public_strategy = types.AuthStrategy.fromString("public");
    try std.testing.expect(public_strategy == .public);

    const cookie = types.AuthStrategy.fromString("cookie");
    try std.testing.expect(cookie == .cookie);

    const oauth = types.AuthStrategy.fromString("oauth");
    try std.testing.expect(oauth == .oauth);
}

test "AuthStrategy label" {
    try std.testing.expectEqualStrings("public", types.AuthStrategy.label(.public));
    try std.testing.expectEqualStrings("cookie", types.AuthStrategy.label(.cookie));
    try std.testing.expectEqualStrings("header", types.AuthStrategy.label(.header));
    try std.testing.expectEqualStrings("oauth", types.AuthStrategy.label(.oauth));
    try std.testing.expectEqualStrings("api_key", types.AuthStrategy.label(.api_key));
}

test "StringUtils trim" {
    const trimmed = helpers.StringUtils.trim("  hello world  ");
    try std.testing.expectEqualStrings("hello world", trimmed);
}

test "StringUtils startsWith" {
    try std.testing.expect(helpers.StringUtils.startsWith("hello", "he"));
    try std.testing.expect(!helpers.StringUtils.startsWith("hello", "wo"));
}

test "StringUtils endsWith" {
    try std.testing.expect(helpers.StringUtils.endsWith("hello", "lo"));
    try std.testing.expect(!helpers.StringUtils.endsWith("hello", "he"));
}

test "StringUtils renderTemplate" {
    const allocator = std.testing.allocator;

    var vars = std.StringHashMap([]const u8).init(allocator);
    defer vars.deinit();

    try vars.put("name", "World");
    try vars.put("greeting", "Hello");

    const result = try helpers.StringUtils.renderTemplate(allocator, "{{greeting}}, {{name}}!", vars);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hello, World!", result);
}

test "FileUtils fileExists" {
    try std.testing.expect(helpers.FileUtils.fileExists("README.md"));
    try std.testing.expect(!helpers.FileUtils.fileExists("nonexistent_file_xyz.md"));
}

test "TimeUtils nowSeconds" {
    const now = helpers.TimeUtils.nowSeconds();
    try std.testing.expect(now > 0);
}

test "Command fullName" {
    const allocator = std.testing.allocator;

    const cmd = types.Command{
        .site = "bilibili",
        .name = "hot",
        .description = "Get trending videos",
        .domain = "bilibili.com",
    };

    const full_name = try cmd.fullName(allocator);
    defer allocator.free(full_name);

    try std.testing.expectEqualStrings("bilibili/hot", full_name);
}

test "Command fullName different allocator" {
    const allocator = std.testing.allocator;

    const cmd = types.Command{
        .site = "github",
        .name = "trending",
        .description = "Get trending repos",
        .domain = "github.com",
    };

    const full_name = try cmd.fullName(allocator);
    defer allocator.free(full_name);

    try std.testing.expectEqualStrings("github/trending", full_name);
}

test "Registry init and deinit" {
    const allocator = std.testing.allocator;

    var registry = types.Registry.init(allocator);
    defer registry.deinit();

    // Registry should be empty initially
    const count = registry.commands.count();
    try std.testing.expect(count == 0);
}

test "Registry registerCommand" {
    const allocator = std.testing.allocator;

    var registry = types.Registry.init(allocator);
    defer registry.deinit();

    const cmd = types.Command{
        .site = "test",
        .name = "cmd",
        .description = "Test command",
        .domain = "test.com",
    };

    try registry.registerCommand(cmd);

    const retrieved = registry.getCommand("test", "cmd");
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqualStrings("test", retrieved.?.site);
    try std.testing.expectEqualStrings("cmd", retrieved.?.name);
}

test "Registry getCommand not found" {
    const allocator = std.testing.allocator;

    var registry = types.Registry.init(allocator);
    defer registry.deinit();

    const retrieved = registry.getCommand("nonexistent", "command");
    try std.testing.expect(retrieved == null);
}

test "Registry unregisterCommand" {
    const allocator = std.testing.allocator;

    var registry = types.Registry.init(allocator);
    defer registry.deinit();

    const cmd = types.Command{
        .site = "test",
        .name = "cmd",
        .description = "Test command",
        .domain = "test.com",
    };

    try registry.registerCommand(cmd);
    try std.testing.expect(registry.getCommand("test", "cmd") != null);

    registry.unregisterCommand("test", "cmd");
    try std.testing.expect(registry.getCommand("test", "cmd") == null);
}

test "Registry listCommands" {
    const allocator = std.testing.allocator;

    var registry = types.Registry.init(allocator);
    defer registry.deinit();

    const cmd1 = types.Command{
        .site = "test1",
        .name = "cmd1",
        .description = "Test command 1",
        .domain = "test1.com",
    };

    const cmd2 = types.Command{
        .site = "test2",
        .name = "cmd2",
        .description = "Test command 2",
        .domain = "test2.com",
    };

    try registry.registerCommand(cmd1);
    try registry.registerCommand(cmd2);

    const list = try registry.listCommands(allocator);
    defer allocator.free(list);

    try std.testing.expect(list.len == 2);
}

test "OutputFormat enum values" {
    try std.testing.expect(types.Config.OutputFormat.table == .table);
    try std.testing.expect(types.Config.OutputFormat.json == .json);
    try std.testing.expect(types.Config.OutputFormat.yaml == .yaml);
    try std.testing.expect(types.Config.OutputFormat.markdown == .markdown);
    try std.testing.expect(types.Config.OutputFormat.csv == .csv);
    try std.testing.expect(types.Config.OutputFormat.raw == .raw);
}

test "ArgDef types" {
    try std.testing.expect(types.ArgDef.ArgType.string == .string);
    try std.testing.expect(types.ArgDef.ArgType.integer == .integer);
    try std.testing.expect(types.ArgDef.ArgType.number == .number);
    try std.testing.expect(types.ArgDef.ArgType.boolean == .boolean);
    try std.testing.expect(types.ArgDef.ArgType.array == .array);
    try std.testing.expect(types.ArgDef.ArgType.object == .object);
}

test "PipelineDef StepType values" {
    try std.testing.expect(types.PipelineDef.Step.StepType.fetch == .fetch);
    try std.testing.expect(types.PipelineDef.Step.StepType.browser == .browser);
    try std.testing.expect(types.PipelineDef.Step.StepType.transform == .transform);
    try std.testing.expect(types.PipelineDef.Step.StepType.download == .download);
    try std.testing.expect(types.PipelineDef.Step.StepType.tap == .tap);
    try std.testing.expect(types.PipelineDef.Step.StepType.intercept == .intercept);
}

test "Adapter AdapterType values" {
    try std.testing.expect(types.Adapter.AdapterType.yaml == .yaml);
    try std.testing.expect(types.Adapter.AdapterType.typescript == .typescript);
    try std.testing.expect(types.Adapter.AdapterType.zig == .zig);
    try std.testing.expect(types.Adapter.AdapterType.external == .external);
}

test "AuthStrategy fromString case sensitive" {
    // Test that fromString is case-sensitive (returns cookie default for unknown cases)
    try std.testing.expect(types.AuthStrategy.fromString("public") == .public);
    try std.testing.expect(types.AuthStrategy.fromString("cookie") == .cookie);
    try std.testing.expect(types.AuthStrategy.fromString("header") == .header);
    try std.testing.expect(types.AuthStrategy.fromString("oauth") == .oauth);
    try std.testing.expect(types.AuthStrategy.fromString("api_key") == .api_key);
    // Case-sensitive - unknown case returns default (cookie)
    try std.testing.expect(types.AuthStrategy.fromString("PUBLIC") == .cookie);
    try std.testing.expect(types.AuthStrategy.fromString("Cookie") == .cookie);
}

test "AuthStrategy default value" {
    // Unknown strings should return cookie as default
    try std.testing.expect(types.AuthStrategy.fromString("unknown") == .cookie);
    try std.testing.expect(types.AuthStrategy.fromString("") == .cookie);
}

test "Command default values" {
    const cmd = types.Command{
        .site = "test",
        .name = "cmd",
        .description = "Test",
        .domain = "test.com",
    };

    try std.testing.expect(cmd.strategy == .cookie);
    try std.testing.expect(cmd.browser == false);
    try std.testing.expect(cmd.args.len == 0);
    try std.testing.expect(cmd.columns == null);
    try std.testing.expect(cmd.pipeline == null);
    try std.testing.expect(cmd.timeout_seconds == null);
    try std.testing.expect(cmd.source.len > 0);
}

test "Config default browser config" {
    const allocator = std.testing.allocator;

    var config = try types.Config.init(allocator);
    defer config.deinit();

    try std.testing.expect(config.browser.enabled == true);
    try std.testing.expect(config.browser.headless == true);
    try std.testing.expect(config.browser.debugging_port == 9222);
    try std.testing.expect(config.browser.timeout_ms == 30000);
}

test "HttpResponse structure" {
    const allocator = std.testing.allocator;

    var headers = std.StringHashMap([]const u8).init(allocator);
    defer headers.deinit();

    try headers.put("content-type", "application/json");

    const response = types.HttpResponse{
        .status = 200,
        .headers = headers,
        .body = "{\"test\": true}",
    };

    try std.testing.expect(response.status == 200);
    try std.testing.expect(response.headers.get("content-type") != null);
}

test "HttpResponse deinit" {
    const allocator = std.testing.allocator;

    var headers = std.StringHashMap([]const u8).init(allocator);
    try headers.put("content-type", "application/json");

    var response = types.HttpResponse{
        .status = 200,
        .headers = headers,
        .body = try allocator.dupe(u8, "test body"),
    };

    // Verify content
    try std.testing.expectEqualStrings("test body", response.body);

    // Deinit should free the body
    response.deinit(allocator);
}

test "CDPMessage structure" {
    const msg = types.CDPMessage{
        .id = 1,
        .method = "Page.navigate",
        .params = null,
        .session_id = null,
    };

    try std.testing.expect(msg.id == 1);
    try std.testing.expectEqualStrings("Page.navigate", msg.method);
    try std.testing.expect(msg.params == null);
}

test "ExecutionResult success" {
    const result = types.ExecutionResult{
        .success = true,
        .data = .{ .string = "test data" },
        .error_message = null,
        .output = null,
    };

    try std.testing.expect(result.success == true);
    try std.testing.expect(result.error_message == null);
}

test "ExecutionResult failure" {
    const err_msg = try std.testing.allocator.dupe(u8, "Network error");
    defer std.testing.allocator.free(err_msg);

    const result = types.ExecutionResult{
        .success = false,
        .data = null,
        .error_message = err_msg,
        .output = null,
    };

    try std.testing.expect(result.success == false);
    try std.testing.expect(result.error_message != null);
}

test "ColumnDef structure" {
    const col = types.ColumnDef{
        .name = "Title",
        .key = "title",
        .format = null,
        .width = null,
    };

    try std.testing.expectEqualStrings("Title", col.name);
    try std.testing.expectEqualStrings("title", col.key);
    try std.testing.expect(col.format == null);
    try std.testing.expect(col.width == null);
}

test "ColumnDef with format and width" {
    const col = types.ColumnDef{
        .name = "Price",
        .key = "price",
        .format = try std.testing.allocator.dupe(u8, "${{value}}"),
        .width = 10,
    };
    defer std.testing.allocator.free(col.format.?);

    try std.testing.expectEqualStrings("${{value}}", col.format.?);
    try std.testing.expect(col.width.? == 10);
}

test "ArgDef structure" {
    const arg = types.ArgDef{
        .name = "limit",
        .description = "Number of items",
        .required = false,
        .default = try std.testing.allocator.dupe(u8, "10"),
        .arg_type = .integer,
    };
    defer std.testing.allocator.free(arg.default.?);

    try std.testing.expectEqualStrings("limit", arg.name);
    try std.testing.expect(arg.required == false);
    try std.testing.expectEqualStrings("10", arg.default.?);
    try std.testing.expect(arg.arg_type == .integer);
}

test "ArgDef required string" {
    const arg = types.ArgDef{
        .name = "query",
        .description = "Search query",
        .required = true,
        .default = null,
        .arg_type = .string,
    };

    try std.testing.expect(arg.required == true);
    try std.testing.expect(arg.default == null);
    try std.testing.expect(arg.arg_type == .string);
}

test "ExternalCli structure" {
    const cli = types.ExternalCli{
        .name = "gh",
        .description = "GitHub CLI",
        .binary = "gh",
        .install_cmd = try std.testing.allocator.dupe(u8, "brew install gh"),
        .is_installed = false,
    };
    defer std.testing.allocator.free(cli.install_cmd.?);

    try std.testing.expectEqualStrings("gh", cli.name);
    try std.testing.expect(cli.is_installed == false);
}

test "ExternalCli installed" {
    const cli = types.ExternalCli{
        .name = "docker",
        .description = "Docker CLI",
        .binary = "docker",
        .install_cmd = null,
        .is_installed = true,
    };

    try std.testing.expect(cli.is_installed == true);
    try std.testing.expect(cli.install_cmd == null);
}

test "Adapter init and deinit" {
    const allocator = std.testing.allocator;

    var adapter = types.Adapter.init(allocator, "test", .yaml);
    defer adapter.deinit();

    try std.testing.expectEqualStrings("test", adapter.name);
    try std.testing.expectEqualStrings("test", adapter.site);
    try std.testing.expect(adapter.adapter_type == .yaml);
    try std.testing.expect(adapter.commands.items.len == 0);
}

test "Adapter addCommand" {
    const allocator = std.testing.allocator;

    var adapter = types.Adapter.init(allocator, "test", .yaml);
    defer adapter.deinit();

    const cmd = types.Command{
        .site = "test",
        .name = "cmd",
        .description = "Test command",
        .domain = "test.com",
    };

    try adapter.addCommand(cmd);
    try std.testing.expect(adapter.commands.items.len == 1);
}

test "AdapterType enum values" {
    try std.testing.expect(types.Adapter.AdapterType.yaml == .yaml);
    try std.testing.expect(types.Adapter.AdapterType.typescript == .typescript);
    try std.testing.expect(types.Adapter.AdapterType.zig == .zig);
    try std.testing.expect(types.Adapter.AdapterType.external == .external);
}

test "Config init creates directories" {
    const allocator = std.testing.allocator;

    var config = try types.Config.init(allocator);
    defer config.deinit();

    // Config directories should be set
    try std.testing.expect(config.config_dir.len > 0);
    try std.testing.expect(config.data_dir.len > 0);
    try std.testing.expect(config.cache_dir.len > 0);
}

test "Config BrowserConfig defaults" {
    const allocator = std.testing.allocator;

    var config = try types.Config.init(allocator);
    defer config.deinit();

    // Browser defaults
    try std.testing.expect(config.browser.enabled == true);
    try std.testing.expect(config.browser.headless == true);
    try std.testing.expect(config.browser.debugging_port == 9222);
}

test "StringUtils template with missing var" {
    const allocator = std.testing.allocator;

    var vars = std.StringHashMap([]const u8).init(allocator);
    defer vars.deinit();

    // Don't set any variables
    const result = try helpers.StringUtils.renderTemplate(allocator, "Hello {{name}}!", vars);
    defer allocator.free(result);

    // Missing variable should keep the placeholder
    try std.testing.expectEqualStrings("Hello {{name}}!", result);
}

test "StringUtils template with empty value" {
    const allocator = std.testing.allocator;

    var vars = std.StringHashMap([]const u8).init(allocator);
    defer vars.deinit();

    try vars.put("name", "");

    const result = try helpers.StringUtils.renderTemplate(allocator, "Hello {{name}}!", vars);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hello !", result);
}

test "StringUtils template multiple same_var" {
    const allocator = std.testing.allocator;

    var vars = std.StringHashMap([]const u8).init(allocator);
    defer vars.deinit();

    try vars.put("name", "World");

    const result = try helpers.StringUtils.renderTemplate(allocator, "{{name}} - {{name}} - {{name}}", vars);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("World - World - World", result);
}

test "StringUtils template no placeholders" {
    const allocator = std.testing.allocator;

    var vars = std.StringHashMap([]const u8).init(allocator);
    defer vars.deinit();

    try vars.put("name", "World");

    const result = try helpers.StringUtils.renderTemplate(allocator, "Hello World!", vars);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hello World!", result);
}

test "TimeUtils sleep" {
    const start = std.time.milliTimestamp();
    helpers.TimeUtils.sleepMillis(10);
    const end = std.time.milliTimestamp();

    // Should have slept at least 10ms
    try std.testing.expect(end - start >= 10);
}

// ============================================
// Pipeline Transform Tests
// ============================================

const transform = @import("pipeline/transform.zig");

test "parseSimpleQuery with dot notation" {
    const q = "name";
    const result = transform.parseSimpleQuery(q);
    try std.testing.expect(result != null);
    if (result) |op| {
        try std.testing.expect(std.mem.eql(u8, op.select, "name"));
    }
}

test "parseSimpleQuery with empty string" {
    const q = "";
    const result = transform.parseSimpleQuery(q);
    try std.testing.expect(result == null);
}

test "parseSimpleQuery with single dot" {
    const q = ".";
    const result = transform.parseSimpleQuery(q);
    try std.testing.expect(result == null);
}

test "parseSimpleQuery with whitespace" {
    const q = "  name  ";
    const result = transform.parseSimpleQuery(q);
    try std.testing.expect(result != null);
    if (result) |op| {
        try std.testing.expect(std.mem.eql(u8, op.select, "name"));
    }
}

test "TransformExecutor selectField on object" {
    const allocator = std.testing.allocator;

    var executor = transform.TransformExecutor.init(allocator);
    defer executor.deinit();

    const data = std.json.Value{
        .object = std.json.ObjectMap.init(allocator),
    };

    var obj = data.object;
    try obj.put(try allocator.dupe(u8, "name"), .{ .string = try allocator.dupe(u8, "test") });
    try obj.put(try allocator.dupe(u8, "age"), .{ .integer = 25 });

    const result = try executor.execute(data, .{ .select = "name" });

    try std.testing.expect(result == .string);
    try std.testing.expectEqualStrings("test", result.string);
}

test "TransformExecutor selectField not found" {
    const allocator = std.testing.allocator;

    var executor = transform.TransformExecutor.init(allocator);
    defer executor.deinit();

    const data = std.json.Value{
        .object = std.json.ObjectMap.init(allocator),
    };

    const result = try executor.execute(data, .{ .select = "nonexistent" });

    try std.testing.expect(result == .null);
}

test "TransformExecutor selectField on non-object returns null" {
    const allocator = std.testing.allocator;

    var executor = transform.TransformExecutor.init(allocator);
    defer executor.deinit();

    const data = std.json.Value{ .string = try allocator.dupe(u8, "test") };

    const result = try executor.execute(data, .{ .select = "name" });

    try std.testing.expect(result == .null);
}

test "TransformExecutor selectIndex on array" {
    const allocator = std.testing.allocator;

    var executor = transform.TransformExecutor.init(allocator);
    defer executor.deinit();

    var arr = std.json.Array.init(allocator);
    try arr.append(.{ .string = try allocator.dupe(u8, "first") });
    try arr.append(.{ .string = try allocator.dupe(u8, "second") });
    try arr.append(.{ .string = try allocator.dupe(u8, "third") });

    const data = std.json.Value{ .array = arr };

    const result = try executor.execute(data, .{ .select_index = 1 });

    try std.testing.expect(result == .string);
    try std.testing.expectEqualStrings("second", result.string);
}

test "TransformExecutor selectIndex out of bounds" {
    const allocator = std.testing.allocator;

    var executor = transform.TransformExecutor.init(allocator);
    defer executor.deinit();

    var arr = std.json.Array.init(allocator);
    try arr.append(.{ .string = try allocator.dupe(u8, "first") });

    const data = std.json.Value{ .array = arr };

    const result = try executor.execute(data, .{ .select_index = 10 });

    try std.testing.expect(result == .null);
}

test "TransformExecutor getLength on array" {
    const allocator = std.testing.allocator;

    var executor = transform.TransformExecutor.init(allocator);
    defer executor.deinit();

    var arr = std.json.Array.init(allocator);
    try arr.append(.{ .integer = 1 });
    try arr.append(.{ .integer = 2 });
    try arr.append(.{ .integer = 3 });

    const data = std.json.Value{ .array = arr };

    const op = transform.TransformOp{ .length = {} };
    const result = try executor.execute(data, op);

    try std.testing.expect(result == .integer);
    try std.testing.expect(result.integer == 3);
}

test "TransformExecutor getLength on string" {
    const allocator = std.testing.allocator;

    var executor = transform.TransformExecutor.init(allocator);
    defer executor.deinit();

    const data = std.json.Value{ .string = try allocator.dupe(u8, "hello") };

    const op = transform.TransformOp{ .length = {} };
    const result = try executor.execute(data, op);

    try std.testing.expect(result == .integer);
    try std.testing.expect(result.integer == 5);
}

test "TransformExecutor getKeys on object" {
    const allocator = std.testing.allocator;

    var executor = transform.TransformExecutor.init(allocator);
    defer executor.deinit();

    var obj = std.json.ObjectMap.init(allocator);
    try obj.put(try allocator.dupe(u8, "name"), .{ .string = "test" });
    try obj.put(try allocator.dupe(u8, "age"), .{ .integer = 25 });

    const data = std.json.Value{ .object = obj };

    const op = transform.TransformOp{ .keys = {} };
    const result = try executor.execute(data, op);

    try std.testing.expect(result == .array);
    try std.testing.expect(result.array.items.len == 2);
}

test "TransformExecutor toString" {
    const allocator = std.testing.allocator;

    var executor = transform.TransformExecutor.init(allocator);
    defer executor.deinit();

    const data = std.json.Value{ .integer = 42 };

    const op = transform.TransformOp{ .to_string = {} };
    const result = try executor.execute(data, op);

    try std.testing.expect(result == .string);
    try std.testing.expectEqualStrings("42", result.string);
}

test "TransformExecutor toNumber from string" {
    const allocator = std.testing.allocator;

    var executor = transform.TransformExecutor.init(allocator);
    defer executor.deinit();

    const data = std.json.Value{ .string = try allocator.dupe(u8, "123") };

    const op = transform.TransformOp{ .to_number = {} };
    const result = try executor.execute(data, op);

    try std.testing.expect(result == .integer);
    try std.testing.expect(result.integer == 123);
}

test "TransformExecutor toNumber from float string" {
    const allocator = std.testing.allocator;

    var executor = transform.TransformExecutor.init(allocator);
    defer executor.deinit();

    const data = std.json.Value{ .string = try allocator.dupe(u8, "3.14") };

    const op = transform.TransformOp{ .to_number = {} };
    const result = try executor.execute(data, op);

    try std.testing.expect(result == .float);
}

test "TransformExecutor toBool true" {
    const allocator = std.testing.allocator;

    var executor = transform.TransformExecutor.init(allocator);
    defer executor.deinit();

    const data = std.json.Value{ .bool = true };

    const op = transform.TransformOp{ .to_bool = {} };
    const result = try executor.execute(data, op);

    try std.testing.expect(result == .bool);
    try std.testing.expect(result.bool == true);
}

test "TransformExecutor toBool from integer zero" {
    const allocator = std.testing.allocator;

    var executor = transform.TransformExecutor.init(allocator);
    defer executor.deinit();

    const data = std.json.Value{ .integer = 0 };

    const op = transform.TransformOp{ .to_bool = {} };
    const result = try executor.execute(data, op);

    try std.testing.expect(result == .bool);
    try std.testing.expect(result.bool == false);
}

test "TransformExecutor containsString true" {
    const allocator = std.testing.allocator;

    var executor = transform.TransformExecutor.init(allocator);
    defer executor.deinit();

    const data = std.json.Value{ .string = try allocator.dupe(u8, "hello world") };

    const result = try executor.execute(data, .{ .contains = "world" });

    try std.testing.expect(result == .bool);
    try std.testing.expect(result.bool == true);
}

test "TransformExecutor containsString false" {
    const allocator = std.testing.allocator;

    var executor = transform.TransformExecutor.init(allocator);
    defer executor.deinit();

    const data = std.json.Value{ .string = try allocator.dupe(u8, "hello world") };

    const result = try executor.execute(data, .{ .contains = "foo" });

    try std.testing.expect(result == .bool);
    try std.testing.expect(result.bool == false);
}

test "TransformExecutor aggregate add" {
    const allocator = std.testing.allocator;

    var executor = transform.TransformExecutor.init(allocator);
    defer executor.deinit();

    var arr = std.json.Array.init(allocator);
    try arr.append(.{ .integer = 1 });
    try arr.append(.{ .integer = 2 });
    try arr.append(.{ .integer = 3 });

    const data = std.json.Value{ .array = arr };

    const op = transform.TransformOp{ .add = {} };
    const result = try executor.execute(data, op);

    try std.testing.expect(result == .float);
    try std.testing.expect(result.float == 6.0);
}

test "TransformExecutor aggregate min" {
    const allocator = std.testing.allocator;

    var executor = transform.TransformExecutor.init(allocator);
    defer executor.deinit();

    var arr = std.json.Array.init(allocator);
    try arr.append(.{ .integer = 3 });
    try arr.append(.{ .integer = 1 });
    try arr.append(.{ .integer = 2 });

    const data = std.json.Value{ .array = arr };

    const op = transform.TransformOp{ .min = {} };
    const result = try executor.execute(data, op);

    try std.testing.expect(result == .float);
    try std.testing.expect(result.float == 1.0);
}

test "TransformExecutor aggregate max" {
    const allocator = std.testing.allocator;

    var executor = transform.TransformExecutor.init(allocator);
    defer executor.deinit();

    var arr = std.json.Array.init(allocator);
    try arr.append(.{ .integer = 3 });
    try arr.append(.{ .integer = 1 });
    try arr.append(.{ .integer = 2 });

    const data = std.json.Value{ .array = arr };

    const op = transform.TransformOp{ .max = {} };
    const result = try executor.execute(data, op);

    try std.testing.expect(result == .float);
    try std.testing.expect(result.float == 3.0);
}

test "TransformExecutor aggregate avg" {
    const allocator = std.testing.allocator;

    var executor = transform.TransformExecutor.init(allocator);
    defer executor.deinit();

    var arr = std.json.Array.init(allocator);
    try arr.append(.{ .integer = 2 });
    try arr.append(.{ .integer = 4 });
    try arr.append(.{ .integer = 6 });

    const data = std.json.Value{ .array = arr };

    const op = transform.TransformOp{ .avg = {} };
    const result = try executor.execute(data, op);

    try std.testing.expect(result == .float);
    try std.testing.expect(result.float == 4.0);
}

test "TransformExecutor split string" {
    const allocator = std.testing.allocator;

    var executor = transform.TransformExecutor.init(allocator);
    defer executor.deinit();

    const data = std.json.Value{ .string = try allocator.dupe(u8, "a,b,c") };

    const result = try executor.execute(data, .{ .split = "," });

    try std.testing.expect(result == .array);
    try std.testing.expect(result.array.items.len == 3);
}

test "TransformExecutor toArray wraps scalar" {
    const allocator = std.testing.allocator;

    var executor = transform.TransformExecutor.init(allocator);
    defer executor.deinit();

    const data = std.json.Value{ .string = try allocator.dupe(u8, "test") };

    const op = transform.TransformOp{ .to_array = {} };
    const result = try executor.execute(data, op);

    try std.testing.expect(result == .array);
    try std.testing.expect(result.array.items.len == 1);
}

test "JqOperator enum values" {
    try std.testing.expect(@as(transform.JqOperator, .select) == .select);
    try std.testing.expect(@as(transform.JqOperator, .index) == .index);
    try std.testing.expect(@as(transform.JqOperator, .iterator) == .iterator);
    try std.testing.expect(@as(transform.JqOperator, .pipe) == .pipe);
    try std.testing.expect(@as(transform.JqOperator, .comma) == .comma);
    try std.testing.expect(@as(transform.JqOperator, .optional) == .optional);
    try std.testing.expect(@as(transform.JqOperator, .recursive) == .recursive);
}

test "FilterCondition ComparisonOp values" {
    const cond = transform.FilterCondition{
        .field = try std.testing.allocator.dupe(u8, "age"),
        .op = .gt,
        .value = .{ .integer = 18 },
    };

    try std.testing.expect(cond.op == .gt);
    try std.testing.expect(cond.value == .integer);
}

test "getNestedValue: simple field" {
    const allocator = std.testing.allocator;
    const json_str = "{\"name\": \"test\", \"value\": 42}";
    var json = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer json.deinit();

    const result = format.getNestedValue(json.value, "name");

    try std.testing.expect(result == .string);
    try std.testing.expectEqualStrings("test", result.string);
}

test "getNestedValue: nested field" {
    const allocator = std.testing.allocator;
    const json_str = "{\"modules\": {\"module_author\": {\"name\": \"Alice\"}, \"module_dynamic\": {\"desc\": {\"text\": \"hello world\"}}}}";
    var json = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer json.deinit();

    const result = format.getNestedValue(json.value, "modules.module_author.name");

    try std.testing.expect(result == .string);
    try std.testing.expectEqualStrings("Alice", result.string);
}

test "getNestedValue: missing field returns null" {
    const allocator = std.testing.allocator;
    const json_str = "{\"modules\": {\"module_author\": {\"name\": \"Alice\"}}}";
    var json = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer json.deinit();

    const result = format.getNestedValue(json.value, "modules.module_dynamic.desc.text");

    try std.testing.expect(result == .null);
}

test "bilibili dynamic: expected output structure" {
    const allocator = std.testing.allocator;

    // Raw API response structure
    const zig_raw_response = "{\"code\":0,\"data\":{\"items\":[{\"id_str\":\"123\",\"modules\":{\"module_author\":{\"name\":\"Alice\"},\"module_dynamic\":{\"desc\":{\"text\":\"hello world\"}},\"module_stat\":{\"like\":{\"count\":9}}}}]}}";

    var raw = try std.json.parseFromSlice(std.json.Value, allocator, zig_raw_response, .{});
    defer raw.deinit();

    // The first item in the items array
    const data = raw.value.object.get("data").?;
    const items = data.object.get("items").?;
    const item = items.array.items[0];

    // Extract fields using the Zig format layer approach (dot notation)
    const extracted_id = format.getNestedValue(item, "id_str");
    const extracted_author = format.getNestedValue(item, "modules.module_author.name");
    const extracted_text = format.getNestedValue(item, "modules.module_dynamic.desc.text");
    const extracted_likes = format.getNestedValue(item, "modules.module_stat.like.count");

    // Verify extracted values match TypeScript expected output
    try std.testing.expect(extracted_id == .string);
    try std.testing.expectEqualStrings("123", extracted_id.string);

    try std.testing.expect(extracted_author == .string);
    try std.testing.expectEqualStrings("Alice", extracted_author.string);

    try std.testing.expect(extracted_text == .string);
    try std.testing.expectEqualStrings("hello world", extracted_text.string);

    try std.testing.expect(extracted_likes == .integer);
    try std.testing.expect(extracted_likes.integer == 9);
}

test "bilibili dynamic: fallback to archive title" {
    const allocator = std.testing.allocator;

    // When desc.text is missing but archive title exists
    const raw_response = "{\"id_str\":\"456\",\"modules\":{\"module_author\":{\"name\":\"Bob\"},\"module_dynamic\":{\"major\":{\"archive\":{\"title\":\"Video title\"}}},\"module_stat\":{\"like\":{\"count\":3}}}}";

    var raw = try std.json.parseFromSlice(std.json.Value, allocator, raw_response, .{});
    defer raw.deinit();

    // First try desc.text (will be null)
    const desc_text = format.getNestedValue(raw.value, "modules.module_dynamic.desc.text");
    try std.testing.expect(desc_text == .null);

    // Then try archive title as fallback
    const archive_title = format.getNestedValue(raw.value, "modules.module_dynamic.major.archive.title");
    try std.testing.expect(archive_title == .string);
    try std.testing.expectEqualStrings("Video title", archive_title.string);
}

test "bilibili hot: expected fields exist" {
    const allocator = std.testing.allocator;

    // Simplified bilibili hot response structure
    const hot_response = "{\"code\":0,\"data\":{\"list\":[{\"aid\":123,\"title\":\"Test Video\",\"owner\":{\"name\":\"TestUser\"},\"stat\":{\"view\":1000}}]}}";

    var raw = try std.json.parseFromSlice(std.json.Value, allocator, hot_response, .{});
    defer raw.deinit();

    // Get the first item from list
    const data = raw.value.object.get("data").?;
    const list = data.object.get("list").?;
    try std.testing.expect(list == .array);

    if (list.array.items.len > 0) {
        const item = list.array.items[0];

        // Extract fields that would be used for output
        const title = format.getNestedValue(item, "title");
        const author = format.getNestedValue(item, "owner.name");
        const views = format.getNestedValue(item, "stat.view");

        try std.testing.expect(title == .string);
        try std.testing.expectEqualStrings("Test Video", title.string);

        try std.testing.expect(author == .string);
        try std.testing.expectEqualStrings("TestUser", author.string);

        try std.testing.expect(views == .integer);
        try std.testing.expect(views.integer == 1000);
    }
}

test "hackernews top: expected fields exist" {
    const allocator = std.testing.allocator;

    // HackerNews API response structure
    const hn_response = "{\"id\":12345,\"title\":\"Test Story\",\"url\":\"https://example.com\",\"by\":\"testuser\",\"time\":1234567890,\"score\":100,\"descendants\":50}";

    var raw = try std.json.parseFromSlice(std.json.Value, allocator, hn_response, .{});
    defer raw.deinit();

    // Extract fields that would be used for output
    const id = format.getNestedValue(raw.value, "id");
    const title = format.getNestedValue(raw.value, "title");
    const url = format.getNestedValue(raw.value, "url");
    const author = format.getNestedValue(raw.value, "by");
    const time = format.getNestedValue(raw.value, "time");
    const score = format.getNestedValue(raw.value, "score");
    const descendants = format.getNestedValue(raw.value, "descendants");

    try std.testing.expect(id == .integer);
    try std.testing.expectEqualStrings("Test Story", title.string);
    try std.testing.expectEqualStrings("https://example.com", url.string);
    try std.testing.expectEqualStrings("testuser", author.string);
    try std.testing.expect(time == .integer);
    try std.testing.expect(score == .integer);
    try std.testing.expect(descendants == .integer);
}

test "v2ex hot: expected fields exist" {
    const allocator = std.testing.allocator;

    // V2EX API response structure (simplified)
    const v2ex_response = "{\"id\":12345,\"title\":\"Test Topic\",\"node\":{\"name\":\"programming\",\"title\":\"Programming\"},\"author\":{\"name\":\"user1\"},\"replies\":25,\"created\":1234567890}";

    var raw = try std.json.parseFromSlice(std.json.Value, allocator, v2ex_response, .{});
    defer raw.deinit();

    const id = format.getNestedValue(raw.value, "id");
    const title = format.getNestedValue(raw.value, "title");
    const node_name = format.getNestedValue(raw.value, "node.name");
    const author = format.getNestedValue(raw.value, "author.name");
    const replies = format.getNestedValue(raw.value, "replies");

    try std.testing.expect(id == .integer);
    try std.testing.expectEqualStrings("Test Topic", title.string);
    try std.testing.expectEqualStrings("programming", node_name.string);
    try std.testing.expectEqualStrings("user1", author.string);
    try std.testing.expect(replies == .integer);
}

test "reddit read: expected fields exist" {
    const allocator = std.testing.allocator;

    // Reddit comments structure (simplified)
    const reddit_response = "[{\"type\":\"POST\",\"author\":\"alice\",\"score\":10,\"body\":\"Test post\"},{\"type\":\"L0\",\"author\":\"bob\",\"score\":5,\"body\":\"Test comment\"}]";

    var raw = try std.json.parseFromSlice(std.json.Value, allocator, reddit_response, .{});
    defer raw.deinit();

    try std.testing.expect(raw.value == .array);

    const first = raw.value.array.items[0];
    const post_type = format.getNestedValue(first, "type");
    const post_author = format.getNestedValue(first, "author");
    const post_score = format.getNestedValue(first, "score");

    try std.testing.expectEqualStrings("POST", post_type.string);
    try std.testing.expectEqualStrings("alice", post_author.string);
    try std.testing.expect(post_score == .integer);
}

test "twitter timeline: expected fields exist" {
    const allocator = std.testing.allocator;

    // Twitter timeline response structure (simplified)
    const twitter_response = "{\"rest_id\":\"123\",\"legacy\":{\"full_text\":\"Hello tweet\",\"favorite_count\":5,\"retweet_count\":2,\"reply_count\":1},\"core\":{\"user_results\":{\"result\":{\"legacy\":{\"screen_name\":\"alice\"}}}}}";

    var raw = try std.json.parseFromSlice(std.json.Value, allocator, twitter_response, .{});
    defer raw.deinit();

    const tweet_id = format.getNestedValue(raw.value, "rest_id");
    const text = format.getNestedValue(raw.value, "legacy.full_text");
    const likes = format.getNestedValue(raw.value, "legacy.favorite_count");
    const author = format.getNestedValue(raw.value, "core.user_results.result.legacy.screen_name");

    try std.testing.expectEqualStrings("123", tweet_id.string);
    try std.testing.expectEqualStrings("Hello tweet", text.string);
    try std.testing.expect(likes == .integer);
    try std.testing.expectEqualStrings("alice", author.string);
}

test "youtube transcript: segment grouping structure" {
    const allocator = std.testing.allocator;

    // YouTube transcript response structure (simplified)
    const transcript_response = "{\"segments\":[{\"start\":0,\"text\":\"Hello there.\"},{\"start\":2,\"text\":\"How are you?\"},{\"start\":5,\"text\":\"I am fine.\"}]}";

    var raw = try std.json.parseFromSlice(std.json.Value, allocator, transcript_response, .{});
    defer raw.deinit();

    const segments = raw.value.object.get("segments").?;
    try std.testing.expect(segments == .array);

    const first_seg = segments.array.items[0];
    const start = format.getNestedValue(first_seg, "start");
    const text = format.getNestedValue(first_seg, "text");

    // start can be integer or float depending on JSON value
    try std.testing.expect(start == .integer or start == .float);
    try std.testing.expectEqualStrings("Hello there.", text.string);
}

test "github trending: expected fields exist" {
    const allocator = std.testing.allocator;

    // GitHub API response structure (simplified)
    const github_response = "[{\"fullName\":\"owner/repo\",\"description\":\"Test repo\",\"language\":\"Rust\",\"stars\":100,\"forks\":10,\"todayStars\":5}]";

    var raw = try std.json.parseFromSlice(std.json.Value, allocator, github_response, .{});
    defer raw.deinit();

    try std.testing.expect(raw.value == .array);

    const first = raw.value.array.items[0];
    const full_name = format.getNestedValue(first, "fullName");
    const description = format.getNestedValue(first, "description");
    const language = format.getNestedValue(first, "language");
    const stars = format.getNestedValue(first, "stars");

    try std.testing.expectEqualStrings("owner/repo", full_name.string);
    try std.testing.expectEqualStrings("Test repo", description.string);
    try std.testing.expectEqualStrings("Rust", language.string);
    try std.testing.expect(stars == .integer);
}

test "stackoverflow: expected fields exist" {
    const allocator = std.testing.allocator;

    // StackOverflow API response structure (simplified)
    const so_response = "{\"items\":[{\"question_id\":12345,\"title\":\"Test Question\",\"owner\":{\"display_name\":\"user1\",\"reputation\":100},\"answer_count\":5,\"score\":10,\"is_answered\":true}]}";

    var raw = try std.json.parseFromSlice(std.json.Value, allocator, so_response, .{});
    defer raw.deinit();

    const items = raw.value.object.get("items").?;
    const first = items.array.items[0];

    const qid = format.getNestedValue(first, "question_id");
    const title = format.getNestedValue(first, "title");
    const owner = format.getNestedValue(first, "owner.display_name");
    const answers = format.getNestedValue(first, "answer_count");
    const score = format.getNestedValue(first, "score");

    try std.testing.expect(qid == .integer);
    try std.testing.expectEqualStrings("Test Question", title.string);
    try std.testing.expectEqualStrings("user1", owner.string);
    try std.testing.expect(answers == .integer);
    try std.testing.expect(score == .integer);
}

test "douban movie: expected fields exist" {
    const allocator = std.testing.allocator;

    // Douban API response structure (simplified)
    const douban_response = "{\"id\":\"12345\",\"title\":\"Test Movie\",\"rating\":{\"value\":8.5},\"director_name\":\"Director 1\",\"year\":2024}";

    var raw = try std.json.parseFromSlice(std.json.Value, allocator, douban_response, .{});
    defer raw.deinit();

    const id = format.getNestedValue(raw.value, "id");
    const title = format.getNestedValue(raw.value, "title");
    const rating = format.getNestedValue(raw.value, "rating.value");
    const director = format.getNestedValue(raw.value, "director_name");
    const year = format.getNestedValue(raw.value, "year");

    try std.testing.expectEqualStrings("12345", id.string);
    try std.testing.expectEqualStrings("Test Movie", title.string);
    try std.testing.expect(rating == .float);
    try std.testing.expectEqualStrings("Director 1", director.string);
    try std.testing.expect(year == .integer);
}

test "wikipedia search: expected fields exist" {
    const allocator = std.testing.allocator;

    // Wikipedia API response structure (simplified)
    const wiki_response = "{\"query\":{\"pages\":[{\"pageid\":12345,\"title\":\"Test Article\",\"extract\":\"Test extract text...\"}]}}";

    var raw = try std.json.parseFromSlice(std.json.Value, allocator, wiki_response, .{});
    defer raw.deinit();

    const pages = raw.value.object.get("query").?.object.get("pages").?;
    const first = pages.array.items[0];

    const pageid = format.getNestedValue(first, "pageid");
    const title = format.getNestedValue(first, "title");
    const extract = format.getNestedValue(first, "extract");

    try std.testing.expect(pageid == .integer);
    try std.testing.expectEqualStrings("Test Article", title.string);
    try std.testing.expectEqualStrings("Test extract text...", extract.string);
}

test "npm package: expected fields exist" {
    const allocator = std.testing.allocator;

    // NPM API response structure (simplified)
    const npm_response = "{\"name\":\"test-package\",\"version\":\"1.0.0\",\"description\":\"Test package description\",\"time\":{\"modified\":\"2024-01-01T00:00:00Z\"}}";

    var raw = try std.json.parseFromSlice(std.json.Value, allocator, npm_response, .{});
    defer raw.deinit();

    const name = format.getNestedValue(raw.value, "name");
    const version = format.getNestedValue(raw.value, "version");
    const description = format.getNestedValue(raw.value, "description");
    const modified = format.getNestedValue(raw.value, "time.modified");

    try std.testing.expectEqualStrings("test-package", name.string);
    try std.testing.expectEqualStrings("1.0.0", version.string);
    try std.testing.expectEqualStrings("Test package description", description.string);
    try std.testing.expectEqualStrings("2024-01-01T00:00:00Z", modified.string);
}
