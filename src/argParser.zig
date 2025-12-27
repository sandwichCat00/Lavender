const std = @import("std");
const err = @import("util.zig").err;

pub const ArgParser = struct {
    fileName: []const u8,

    fn help() []const u8 {
        std.debug.print("lavender [OPTION] <SrcFile|BinFile>\n", .{});
        return "";
    }

    pub fn init(alloc: std.mem.Allocator) error{OutOfMemory}!ArgParser {
        var ret: ArgParser = .{ .fileName = "" };
        var args = std.process.args();
        _ = args.next();
        while (args.next()) |arg| {
            if (ret.fileName.len == 0) {
                ret.fileName = try alloc.dupe(u8, arg);
            } else err("", "", 0, "Invalid argument: {s}{s}", .{ arg, help() });
        }

        if (ret.fileName.len == 0) {
            err("", "", 0, "Expected src file name{s}", .{help()});
        }

        return ret;
    }
};
