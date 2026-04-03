const std = @import("std");
const net = std.net;
const tls = std.crypto.tls;

/// WebSocket错误类型
pub const WebSocketError = error{
    ConnectionFailed,
    HandshakeFailed,
    InvalidFrame,
    ConnectionClosed,
    SendFailed,
    ReceiveFailed,
    OutOfMemory,
};

/// WebSocket操作码
const OpCode = enum(u4) {
    continuation = 0x0,
    text = 0x1,
    binary = 0x2,
    close = 0x8,
    ping = 0x9,
    pong = 0xA,
    
    fn isControl(self: OpCode) bool {
        return @intFromEnum(self) >= 0x8;
    }
};

/// WebSocket帧头
const FrameHeader = struct {
    fin: bool,
    rsv: u3,
    opcode: OpCode,
    masked: bool,
    payload_len: u64,
};

/// WebSocket客户端
pub const WebSocketClient = struct {
    allocator: std.mem.Allocator,
    stream: net.Stream,
    tls_client: ?*tls.Client = null,
    connected: bool = false,
    buffer: []u8,
    buffer_pos: usize = 0,
    
    pub fn init(allocator: std.mem.Allocator) WebSocketClient {
        return WebSocketClient{
            .allocator = allocator,
            .stream = undefined,
            .buffer = allocator.alloc(u8, 65536) catch unreachable,
        };
    }
    
    pub fn deinit(self: *WebSocketClient) void {
        self.disconnect();
        self.allocator.free(self.buffer);
    }
    
    /// 连接到WebSocket服务器（`ws://`；完整 path/query 会用于握手 GET 行）
    pub fn connect(self: *WebSocketClient, url: []const u8) WebSocketError!void {
        const uri = std.Uri.parse(url) catch return WebSocketError.HandshakeFailed;

        var host_buf: [std.Uri.host_name_max]u8 = undefined;
        const host = uri.getHost(&host_buf) catch return WebSocketError.HandshakeFailed;

        const port: u16 = blk: {
            if (uri.port) |p| break :blk p;
            const sch = uri.scheme;
            if (std.ascii.eqlIgnoreCase(sch, "ws")) break :blk 80;
            if (std.ascii.eqlIgnoreCase(sch, "wss")) break :blk 443;
            break :blk 9222;
        };

        if (std.ascii.eqlIgnoreCase(uri.scheme, "wss")) {
            std.log.err("wss:// CDP WebSocket is not supported yet; use ws:// (e.g. local Lightpanda) or terminate TLS with a proxy", .{});
            return WebSocketError.ConnectionFailed;
        }
        if (!std.ascii.eqlIgnoreCase(uri.scheme, "ws")) {
            std.log.err("CDP WebSocket URL must use ws:// scheme, got scheme '{s}'", .{uri.scheme});
            return WebSocketError.HandshakeFailed;
        }

        var path_req = std.array_list.Managed(u8).init(self.allocator);
        defer path_req.deinit();
        const path_raw = uri.path.percent_encoded;
        if (path_raw.len == 0) {
            try path_req.append('/');
        } else {
            try path_req.appendSlice(path_raw);
        }
        if (uri.query) |q| {
            try path_req.append('?');
            try path_req.appendSlice(q.percent_encoded);
        }

        self.stream = net.tcpConnectToHost(self.allocator, host, port) catch |err| {
            std.log.err("Failed to connect to {s}:{d}: {}", .{ host, port, err });
            return WebSocketError.ConnectionFailed;
        };

        try self.performHandshake(host, port, path_req.items);

        self.connected = true;
        std.log.info("WebSocket connected to {s}", .{url});
    }
    
    /// 执行WebSocket握手
    fn performHandshake(self: *WebSocketClient, host: []const u8, port: u16, path: []const u8) WebSocketError!void {
        const key = "dGhlIHNhbXBsZSBub25jZQ=="; // 示例key，实际应该随机生成
        
        var request = std.array_list.Managed(u8).init(self.allocator);
        defer request.deinit();
        
        // 构建HTTP升级请求
        try request.writer().print(
            "GET {s} HTTP/1.1\r\n" ++
            "Host: {s}:{d}\r\n" ++
            "Upgrade: websocket\r\n" ++
            "Connection: Upgrade\r\n" ++
            "Sec-WebSocket-Key: {s}\r\n" ++
            "Sec-WebSocket-Version: 13\r\n" ++
            "\r\n",
            .{ path, host, port, key }
        );
        
        // 发送请求
        _ = self.stream.write(request.items) catch |err| {
            std.log.err("Failed to send handshake: {}", .{err});
            return WebSocketError.HandshakeFailed;
        };
        
        // 读取响应
        var response_buf: [1024]u8 = undefined;
        const n = self.stream.read(&response_buf) catch |err| {
            std.log.err("Failed to read handshake response: {}", .{err});
            return WebSocketError.HandshakeFailed;
        };
        
        const response = response_buf[0..n];
        
        // 验证响应
        if (!std.mem.containsAtLeast(u8, response, 1, "HTTP/1.1 101")) {
            std.log.err("Invalid handshake response: {s}", .{response});
            return WebSocketError.HandshakeFailed;
        }
        
        std.log.info("WebSocket handshake successful", .{});
    }
    
    /// 断开连接
    pub fn disconnect(self: *WebSocketClient) void {
        if (self.connected) {
            // 发送关闭帧
            self.sendCloseFrame() catch {};
            self.stream.close();
            self.connected = false;
        }
    }
    
    /// 发送文本消息
    pub fn sendText(self: *WebSocketClient, text: []const u8) WebSocketError!void {
        try self.sendFrame(.text, text);
    }
    
    /// 发送二进制消息
    pub fn sendBinary(self: *WebSocketClient, data: []const u8) WebSocketError!void {
        try self.sendFrame(.binary, data);
    }
    
    /// 发送帧
    fn sendFrame(self: *WebSocketClient, opcode: OpCode, payload: []const u8) WebSocketError!void {
        if (!self.connected) return WebSocketError.ConnectionClosed;
        
        var frame = std.array_list.Managed(u8).init(self.allocator);
        defer frame.deinit();
        
        // 帧头
        const fin_opcode: u8 = 0x80 | @as(u8, @intFromEnum(opcode));
        try frame.append(fin_opcode);
        
        // 负载长度
        if (payload.len < 126) {
            try frame.append(@intCast(payload.len));
        } else if (payload.len < 65536) {
            try frame.append(126);
            try frame.writer().writeInt(u16, @intCast(payload.len), .big);
        } else {
            try frame.append(127);
            try frame.writer().writeInt(u64, payload.len, .big);
        }
        
        // 客户端必须掩码数据
        const mask_key = self.generateMaskKey();
        try frame.appendSlice(&mask_key);
        
        // 掩码负载
        for (payload, 0..) |byte, i| {
            try frame.append(byte ^ mask_key[i % 4]);
        }
        
        // 发送帧
        _ = self.stream.write(frame.items) catch |err| {
            std.log.err("Failed to send frame: {}", .{err});
            return WebSocketError.SendFailed;
        };
    }
    
    /// 生成掩码密钥
    fn generateMaskKey(self: *WebSocketClient) [4]u8 {
        _ = self;
        // 在实际应用中应该使用随机数
        return [4]u8{ 0x12, 0x34, 0x56, 0x78 };
    }
    
    /// 接收消息
    pub fn receive(self: *WebSocketClient, timeout_ms: u32) WebSocketError!?[]const u8 {
        if (!self.connected) return WebSocketError.ConnectionClosed;
        
        // 设置超时
        const timeout = std.time.milliTimestamp() + timeout_ms;
        
        while (std.time.milliTimestamp() < timeout) {
            // 尝试读取帧
            if (try self.readFrame()) |message| {
                return message;
            }
            
            // 短暂等待
            std.Thread.sleep(1 * std.time.ns_per_ms);
        }
        
        return null; // 超时
    }
    
    /// 读取帧
    fn readFrame(self: *WebSocketClient) WebSocketError!?[]const u8 {
        // 读取帧头（至少2字节）
        var header_buf: [14]u8 = undefined; // 最大帧头大小
        
        const n = self.stream.read(&header_buf) catch |err| {
            if (err == error.WouldBlock) return null;
            std.log.err("Failed to read frame header: {}", .{err});
            return WebSocketError.ReceiveFailed;
        };
        
        if (n < 2) return null;
        
        // 解析帧头（FIN 位保留供后续扩展）
        const fin = (header_buf[0] & 0x80) != 0;
        _ = fin;
        const opcode = @as(OpCode, @enumFromInt(header_buf[0] & 0x0F));
        const masked = (header_buf[1] & 0x80) != 0;
        var payload_len: u64 = header_buf[1] & 0x7F;
        var header_len: usize = 2;
        
        // 扩展负载长度
        if (payload_len == 126) {
            if (n < 4) return null;
            payload_len = std.mem.readInt(u16, header_buf[2..4], .big);
            header_len = 4;
        } else if (payload_len == 127) {
            if (n < 10) return null;
            payload_len = std.mem.readInt(u64, header_buf[2..10], .big);
            header_len = 10;
        }
        
        // 掩码密钥
        var mask_key: [4]u8 = undefined;
        if (masked) {
            @memcpy(&mask_key, header_buf[header_len..header_len + 4]);
            header_len += 4;
        }
        
        // 读取负载
        if (payload_len > self.buffer.len) {
            return WebSocketError.OutOfMemory;
        }
        
        var payload_read: usize = 0;
        while (payload_read < payload_len) {
            const remaining = payload_len - payload_read;
            const buf = self.buffer[payload_read..@min(payload_read + remaining, self.buffer.len)];
            
            const read_n = self.stream.read(buf) catch |err| {
                std.log.err("Failed to read payload: {}", .{err});
                return WebSocketError.ReceiveFailed;
            };
            
            if (read_n == 0) return null;
            payload_read += read_n;
        }
        
        // 解掩码
        if (masked) {
            for (self.buffer[0..payload_len], 0..) |*byte, i| {
                byte.* ^= mask_key[i % 4];
            }
        }
        
        // 处理控制帧
        switch (opcode) {
            .close => {
                self.connected = false;
                return WebSocketError.ConnectionClosed;
            },
            .ping => {
                // 自动回复pong
                try self.sendFrame(.pong, self.buffer[0..payload_len]);
                return null;
            },
            .pong => return null,
            else => {},
        }
        
        // 返回消息
        const message = try self.allocator.dupe(u8, self.buffer[0..payload_len]);
        return message;
    }
    
    /// 发送关闭帧
    fn sendCloseFrame(self: *WebSocketClient) WebSocketError!void {
        if (!self.connected) return;
        _ = self.sendFrame(.close, &[_]u8{}) catch {};
    }
};

/// CDP消息
pub const CDPMessage = struct {
    id: u32,
    method: []const u8,
    params: ?std.json.ObjectMap = null,
    
    pub fn toJson(self: CDPMessage, allocator: std.mem.Allocator) ![]const u8 {
        var obj = std.json.ObjectMap.init(allocator);
        defer obj.deinit();
        try obj.put("id", std.json.Value{ .integer = @intCast(self.id) });
        try obj.put("method", std.json.Value{ .string = self.method });
        
        if (self.params) |params| {
            try obj.put("params", std.json.Value{ .object = params });
        }
        return try std.json.Stringify.valueAlloc(allocator, std.json.Value{ .object = obj }, .{});
    }
};

/// CDP客户端
pub const CDPClient = struct {
    allocator: std.mem.Allocator,
    ws_client: WebSocketClient,
    message_id: std.atomic.Value(u32),
    target_id: ?[]const u8 = null,
    session_id: ?[]const u8 = null,
    
    pub fn init(allocator: std.mem.Allocator) CDPClient {
        return CDPClient{
            .allocator = allocator,
            .ws_client = WebSocketClient.init(allocator),
            .message_id = std.atomic.Value(u32).init(0),
        };
    }
    
    pub fn deinit(self: *CDPClient) void {
        self.disconnect();
        self.ws_client.deinit();
        if (self.target_id) |id| self.allocator.free(id);
        if (self.session_id) |id| self.allocator.free(id);
    }
    
    /// 连接到CDP
    pub fn connect(self: *CDPClient, ws_url: []const u8) !void {
        try self.ws_client.connect(ws_url);
        std.log.info("CDP client connected", .{});
    }
    
    /// 断开连接
    pub fn disconnect(self: *CDPClient) void {
        self.ws_client.disconnect();
    }
    
    /// 发送CDP命令
    pub fn send(self: *CDPClient, method: []const u8, params: ?std.json.ObjectMap) !void {
        const id = self.message_id.fetchAdd(1, .monotonic);
        
        const msg = CDPMessage{
            .id = id,
            .method = method,
            .params = params,
        };
        
        const json_str = try msg.toJson(self.allocator);
        defer self.allocator.free(json_str);
        
        try self.ws_client.sendText(json_str);
        std.log.debug("CDP send: {s}", .{json_str});
    }
    
    /// 接收消息
    pub fn receive(self: *CDPClient, timeout_ms: u32) !?[]const u8 {
        if (try self.ws_client.receive(timeout_ms)) |message| {
            std.log.debug("CDP receive: {s}", .{message});
            return message;
        }
        return null;
    }
    
    /// 导航到URL
    pub fn navigate(self: *CDPClient, url: []const u8) !void {
        var params = std.json.ObjectMap.init(self.allocator);
        try params.put("url", std.json.Value{ .string = url });
        defer params.deinit();
        
        try self.send("Page.navigate", params);
    }
    
    /// 执行JavaScript
    pub fn evaluate(self: *CDPClient, expression: []const u8) !void {
        var params = std.json.ObjectMap.init(self.allocator);
        try params.put("expression", std.json.Value{ .string = expression });
        try params.put("returnByValue", std.json.Value{ .bool = true });
        defer params.deinit();
        
        try self.send("Runtime.evaluate", params);
    }
    
    /// 查询元素
    pub fn querySelector(self: *CDPClient, selector: []const u8) !void {
        const expr = try std.fmt.allocPrint(self.allocator, "document.querySelector('{s}')", .{selector});
        defer self.allocator.free(expr);
        
        try self.evaluate(expr);
    }
    
    /// 点击元素
    pub fn click(self: *CDPClient, selector: []const u8) !void {
        const expr = try std.fmt.allocPrint(self.allocator, "document.querySelector('{s}').click()", .{selector});
        defer self.allocator.free(expr);
        
        try self.evaluate(expr);
    }
    
    /// 输入文本
    pub fn typeText(self: *CDPClient, selector: []const u8, text: []const u8) !void {
        const expr = try std.fmt.allocPrint(
            self.allocator,
            "document.querySelector('{s}').value = '{s}'; document.querySelector('{s}').dispatchEvent(new Event('input', {{ bubbles: true }}))",
            .{ selector, text, selector }
        );
        defer self.allocator.free(expr);
        
        try self.evaluate(expr);
    }
};

/// 浏览器管理器
pub const BrowserManager = struct {
    allocator: std.mem.Allocator,
    cdp_client: CDPClient,
    process: ?std.process.Child = null,
    debugging_port: u16 = 9222,
    
    pub fn init(allocator: std.mem.Allocator) BrowserManager {
        return BrowserManager{
            .allocator = allocator,
            .cdp_client = CDPClient.init(allocator),
            .process = null,
        };
    }
    
    pub fn deinit(self: *BrowserManager) void {
        self.stop();
        self.cdp_client.deinit();
    }
    
    /// 启动浏览器
    /// 若环境变量 `OPENCLI_CDP_WEBSOCKET` 为非空，则**不**启动本机 Chrome，直接连接该 `ws://` URL（如 Lightpanda `serve` 暴露的端点）。
    pub fn start(self: *BrowserManager, headless: bool) !void {
        if (std.process.getEnvVarOwned(self.allocator, "OPENCLI_CDP_WEBSOCKET")) |owned| {
            defer self.allocator.free(owned);
            const trimmed = std.mem.trim(u8, owned, " \t\r\n");
            if (trimmed.len > 0) {
                try self.cdp_client.connect(trimmed);
                std.log.info("CDP via OPENCLI_CDP_WEBSOCKET (no local Chrome spawn)", .{});
                return;
            }
        } else |_| {}

        const chrome_path = try self.findChrome();
        
        var args = std.array_list.Managed([]const u8).init(self.allocator);
        defer {
            for (args.items) |arg| {
                self.allocator.free(arg);
            }
            args.deinit();
        }
        
        try args.append(try self.allocator.dupe(u8, chrome_path));
        try args.append(try std.fmt.allocPrint(self.allocator, "--remote-debugging-port={d}", .{self.debugging_port}));
        try args.append(try self.allocator.dupe(u8, "--no-first-run"));
        try args.append(try self.allocator.dupe(u8, "--no-default-browser-check"));
        try args.append(try self.allocator.dupe(u8, "--disable-default-apps"));
        try args.append(try self.allocator.dupe(u8, "--disable-extensions"));
        try args.append(try self.allocator.dupe(u8, "--disable-features=Translate"));
        
        if (headless) {
            try args.append(try self.allocator.dupe(u8, "--headless"));
        }
        
        // 启动Chrome进程
        var child = std.process.Child.init(args.items, self.allocator);
        child.stdout_behavior = .Ignore;
        child.stderr_behavior = .Ignore;
        
        try child.spawn();
        self.process = child;
        
        // 等待Chrome启动
        std.Thread.sleep(2 * std.time.ns_per_s);
        
        // 连接到CDP
        const ws_url = try std.fmt.allocPrint(self.allocator, "ws://localhost:{d}/devtools/browser", .{self.debugging_port});
        defer self.allocator.free(ws_url);
        
        try self.cdp_client.connect(ws_url);
        std.log.info("Browser started and connected", .{});
    }
    
    /// 停止浏览器
    pub fn stop(self: *BrowserManager) void {
        self.cdp_client.disconnect();
        
        if (self.process) |*child| {
            _ = child.kill() catch {};
            self.process = null;
        }
    }
    
    /// 查找Chrome可执行文件
    fn findChrome(self: *BrowserManager) ![]const u8 {
        const candidates = &[_][]const u8{
            "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
            "/usr/bin/google-chrome",
            "/usr/bin/chromium",
            "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
        };
        
        for (candidates) |path| {
            std.fs.cwd().access(path, .{}) catch continue;
            return try self.allocator.dupe(u8, path);
        }
        
        // 检查环境变量
        if (std.process.getEnvVarOwned(self.allocator, "CHROME_BIN")) |path| {
            return path;
        } else |_| {}
        
        return error.BinaryNotFound;
    }
    
    /// 获取CDP客户端
    pub fn getCDP(self: *BrowserManager) *CDPClient {
        return &self.cdp_client;
    }
    
    /// 导航到URL
    pub fn navigate(self: *BrowserManager, url: []const u8) !void {
        try self.cdp_client.navigate(url);
    }
    
    /// 执行JavaScript
    pub fn evaluate(self: *BrowserManager, expression: []const u8) !void {
        try self.cdp_client.evaluate(expression);
    }
    
    /// 截图功能
    pub fn screenshot(self: *BrowserManager, output_path: []const u8, options: ScreenshotOptions) !void {
        // 构建CDP命令
        var params = std.json.ObjectMap.init(self.allocator);
        defer params.deinit();
        
        // 设置截图格式
        try params.put("format", std.json.Value{ .string = switch (options.format) {
            .png => "png",
            .jpeg => "jpeg",
            .webp => "webp",
        }});
        
        // JPEG质量
        if (options.format == .jpeg and options.quality) |quality| {
            try params.put("quality", std.json.Value{ .integer = @intCast(quality) });
        }
        
        // 是否捕获完整页面
        if (options.full_page) {
            try params.put("fromSurface", std.json.Value{ .bool = true });
        }
        
        // 裁剪区域
        if (options.clip) |clip| {
            var clip_obj = std.json.ObjectMap.init(self.allocator);
            try clip_obj.put("x", std.json.Value{ .float = clip.x });
            try clip_obj.put("y", std.json.Value{ .float = clip.y });
            try clip_obj.put("width", std.json.Value{ .float = clip.width });
            try clip_obj.put("height", std.json.Value{ .float = clip.height });
            try clip_obj.put("scale", std.json.Value{ .float = clip.scale });
            try params.put("clip", std.json.Value{ .object = clip_obj });
        }
        
        // 发送截图命令
        try self.cdp_client.send("Page.captureScreenshot", params);
        
        // 等待响应
        if (try self.cdp_client.receive(10000)) |response| {
            defer self.allocator.free(response);
            
            // 解析响应获取base64数据
            const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response, .{});
            defer parsed.deinit();
            
            if (parsed.value.object.get("result")) |result| {
                if (result.object.get("data")) |data| {
                    // 解码base64并保存
                    const base64_data = data.string;
                    try self.saveBase64Image(base64_data, output_path);
                    std.log.info("Screenshot saved to: {s}", .{output_path});
                    return;
                }
            }
        }
        
        return error.ScreenshotFailed;
    }
    
    /// 保存base64图片
    fn saveBase64Image(self: *BrowserManager, base64_data: []const u8, output_path: []const u8) !void {
        // 解码base64
        const decoded_len = try std.base64.standard.Decoder.calcSizeForSlice(base64_data);
        const decoded = try self.allocator.alloc(u8, decoded_len);
        defer self.allocator.free(decoded);
        
        try std.base64.standard.Decoder.decode(decoded, base64_data);
        
        // 保存到文件
        const file = try std.fs.cwd().createFile(output_path, .{});
        defer file.close();
        
        try file.writeAll(decoded);
    }
    
    /// 截图选项
    pub const ScreenshotOptions = struct {
        format: ImageFormat = .png,
        quality: ?u8 = null, // 0-100, for jpeg only
        full_page: bool = false,
        clip: ?ClipRegion = null,
        
        pub const ImageFormat = enum {
            png,
            jpeg,
            webp,
        };
        
        pub const ClipRegion = struct {
            x: f64,
            y: f64,
            width: f64,
            height: f64,
            scale: f64 = 1.0,
        };
    };
    
    /// PDF导出
    pub fn printToPDF(self: *BrowserManager, output_path: []const u8, options: PDFOptions) !void {
        var params = std.json.ObjectMap.init(self.allocator);
        defer params.deinit();
        
        try params.put("landscape", std.json.Value{ .bool = options.landscape });
        try params.put("printBackground", std.json.Value{ .bool = options.print_background });
        try params.put("preferCSSPageSize", std.json.Value{ .bool = options.prefer_css_page_size });
        
        if (options.paper_width) |width| {
            try params.put("paperWidth", std.json.Value{ .float = width });
        }
        if (options.paper_height) |height| {
            try params.put("paperHeight", std.json.Value{ .float = height });
        }
        if (options.margin_top) |margin| {
            try params.put("marginTop", std.json.Value{ .float = margin });
        }
        if (options.margin_bottom) |margin| {
            try params.put("marginBottom", std.json.Value{ .float = margin });
        }
        if (options.margin_left) |margin| {
            try params.put("marginLeft", std.json.Value{ .float = margin });
        }
        if (options.margin_right) |margin| {
            try params.put("marginRight", std.json.Value{ .float = margin });
        }
        
        // 发送PDF命令
        try self.cdp_client.send("Page.printToPDF", params);
        
        // 等待响应
        if (try self.cdp_client.receive(30000)) |response| {
            defer self.allocator.free(response);
            
            const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response, .{});
            defer parsed.deinit();
            
            if (parsed.value.object.get("result")) |result| {
                if (result.object.get("data")) |data| {
                    try self.saveBase64Image(data.string, output_path);
                    std.log.info("PDF saved to: {s}", .{output_path});
                    return;
                }
            }
        }
        
        return error.PDFFailed;
    }
    
    /// PDF选项
    pub const PDFOptions = struct {
        landscape: bool = false,
        print_background: bool = true,
        prefer_css_page_size: bool = false,
        paper_width: ?f64 = null, // inches
        paper_height: ?f64 = null, // inches
        margin_top: ?f64 = null, // inches
        margin_bottom: ?f64 = null,
        margin_left: ?f64 = null,
        margin_right: ?f64 = null,
    };
};