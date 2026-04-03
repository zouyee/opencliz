const std = @import("std");

/// 日志级别
pub const LogLevel = enum {
    debug,
    info,
    warn,
    err,
    fatal,
    
    pub fn asString(self: LogLevel) []const u8 {
        return switch (self) {
            .debug => "DEBUG",
            .info => "INFO",
            .warn => "WARN",
            .err => "ERROR",
            .fatal => "FATAL",
        };
    }
    
    pub fn asInt(self: LogLevel) u3 {
        return switch (self) {
            .debug => 0,
            .info => 1,
            .warn => 2,
            .err => 3,
            .fatal => 4,
        };
    }
};

/// 日志配置
pub const LoggerConfig = struct {
    level: LogLevel = .info,
    output: Output = .stderr,
    colored: bool = true,
    timestamp_format: []const u8 = "{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}",
    
    pub const Output = enum {
        stdout,
        stderr,
        file,
    };
};

/// 日志记录器
pub const Logger = struct {
    config: LoggerConfig,
    file: ?std.fs.File = null,
    
    pub fn init(config: LoggerConfig) Logger {
        return Logger{
            .config = config,
            .file = null,
        };
    }
    
    pub fn initWithFile(config: LoggerConfig, file_path: []const u8) !Logger {
        const file = try std.fs.cwd().createFile(file_path, .{ .truncate = false });
        try file.seekFromEnd(0);
        
        return Logger{
            .config = config,
            .file = file,
        };
    }
    
    pub fn deinit(self: *Logger) void {
        if (self.file) |file| {
            file.close();
        }
    }
    
    /// 设置日志级别
    pub fn setLevel(self: *Logger, level: LogLevel) void {
        self.config.level = level;
    }
    
    /// 检查是否应该记录该级别
    fn shouldLog(self: *Logger, level: LogLevel) bool {
        return level.asInt() >= self.config.level.asInt();
    }
    
    /// 获取颜色代码
    fn getColorCode(level: LogLevel) []const u8 {
        return switch (level) {
            .debug => "\x1b[36m", // Cyan
            .info => "\x1b[32m",  // Green
            .warn => "\x1b[33m",  // Yellow
            .err => "\x1b[31m", // Red
            .fatal => "\x1b[35m", // Magenta
        };
    }
    
    /// 记录日志
    pub fn log(self: *Logger, level: LogLevel, comptime fmt: []const u8, args: anytype) void {
        if (!self.shouldLog(level)) return;
        
        const now = std.time.timestamp();
        const epoch = std.time.epoch.EpochSeconds{ .secs = @intCast(now) };
        const dt = epoch.getEpochDay();
        const year_day = dt.calculateYearDay();
        const month_day = year_day.calculateMonthDay();
        const day_seconds = epoch.getDaySeconds();
        
        // 格式化时间戳
        var timestamp_buf: [32]u8 = undefined;
        const timestamp = std.fmt.bufPrint(
            &timestamp_buf,
            self.config.timestamp_format,
            .{
                year_day.year,
                month_day.month.numeric(),
                month_day.day_index + 1,
                day_seconds.getHoursIntoDay(),
                day_seconds.getMinutesIntoHour(),
                day_seconds.getSecondsIntoMinute(),
            },
        ) catch "0000-00-00 00:00:00";
        
        // 格式化消息
        var message_buf: [4096]u8 = undefined;
        const message = std.fmt.bufPrint(&message_buf,
            fmt,
            args,
        ) catch "[format error]";
        
        // 构建日志行
        if (self.config.colored) {
            const color = getColorCode(level);
            const reset = "\x1b[0m";
            const log_line = std.fmt.bufPrint(
                &message_buf,
                "{s} [{s}{s}{s}] {s}\n",
                .{ timestamp, color, level.asString(), reset, message },
            ) catch return;
            
            self.write(log_line);
        } else {
            const log_line = std.fmt.bufPrint(
                &message_buf,
                "{s} [{s}] {s}\n",
                .{ timestamp, level.asString(), message },
            ) catch return;
            
            self.write(log_line);
        }
    }
    
    /// 写入日志
    fn write(self: *Logger, log_line: []const u8) void {
        switch (self.config.output) {
            .stdout => {
                const stdout = std.fs.File.stdout().deprecatedWriter();
                stdout.print("{s}", .{log_line}) catch {};
            },
            .stderr => {
                const stderr = std.fs.File.stderr().deprecatedWriter();
                stderr.print("{s}", .{log_line}) catch {};
            },
            .file => {
                if (self.file) |file| {
                    file.writeAll(log_line) catch {};
                }
            },
        }
    }
    
    /// 快捷方法
    pub fn debug(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.debug, fmt, args);
    }
    
    pub fn info(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.info, fmt, args);
    }
    
    pub fn warn(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.warn, fmt, args);
    }
    
    pub fn err(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.err, fmt, args);
    }
    
    pub fn fatal(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.fatal, fmt, args);
    }
};

/// 全局日志记录器
var global_logger: ?Logger = null;

/// 初始化全局日志记录器
pub fn initGlobalLogger(config: LoggerConfig) void {
    global_logger = Logger.init(config);
}

/// 获取全局日志记录器
pub fn getGlobalLogger() *Logger {
    if (global_logger == null) {
        global_logger = Logger.init(.{});
    }
    return &global_logger.?;
}

/// 全局日志快捷方法
pub fn debug(comptime fmt: []const u8, args: anytype) void {
    if (global_logger) |*logger| {
        logger.debug(fmt, args);
    }
}

pub fn info(comptime fmt: []const u8, args: anytype) void {
    if (global_logger) |*logger| {
        logger.info(fmt, args);
    }
}

pub fn warn(comptime fmt: []const u8, args: anytype) void {
    if (global_logger) |*logger| {
        logger.warn(fmt, args);
    }
}

pub fn err(comptime fmt: []const u8, args: anytype) void {
    if (global_logger) |*logger| {
        logger.err(fmt, args);
    }
}

pub fn fatal(comptime fmt: []const u8, args: anytype) void {
    if (global_logger) |*logger| {
        logger.fatal(fmt, args);
    }
}