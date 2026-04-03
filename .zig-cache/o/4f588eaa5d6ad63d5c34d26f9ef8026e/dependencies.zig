pub const packages = struct {
    pub const @"N-V-__8AAIZ_PAA7y10jIaLigzkK4qd5-jfKEoTOOfHCsIGM" = struct {
        pub const build_root = "/Users/zouyee/.cache/zig/p/N-V-__8AAIZ_PAA7y10jIaLigzkK4qd5-jfKEoTOOfHCsIGM";
        pub const deps: []const struct { []const u8, []const u8 } = &.{};
    };
    pub const @"quickjs_ng-0.0.0-0cZnA8XHAwCc95T1GAebWrw-SGEwp1Y0fUAmilP8xGuS" = struct {
        pub const build_root = "/Users/zouyee/.cache/zig/p/quickjs_ng-0.0.0-0cZnA8XHAwCc95T1GAebWrw-SGEwp1Y0fUAmilP8xGuS";
        pub const build_zig = @import("quickjs_ng-0.0.0-0cZnA8XHAwCc95T1GAebWrw-SGEwp1Y0fUAmilP8xGuS");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
            .{ "quickjs", "N-V-__8AAIZ_PAA7y10jIaLigzkK4qd5-jfKEoTOOfHCsIGM" },
        };
    };
};

pub const root_deps: []const struct { []const u8, []const u8 } = &.{
    .{ "quickjs_ng", "quickjs_ng-0.0.0-0cZnA8XHAwCc95T1GAebWrw-SGEwp1Y0fUAmilP8xGuS" },
};
