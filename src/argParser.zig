const std = @import("std");
const Err = @import("errors.zig").ArgError;
const printErr = @import("errors.zig").err;
pub const ArgParser = struct {
    fileName: []const u8,

    pub fn init(alloc: std.mem.Allocator) Err!void {
        var ret: ArgParser = .{ .fileName = "" };
        var args = std.process.args();
        _ = args.next();
        while (args.next()) |arg| {
            if (ret.fileName.len == 0) {
                ret.fileName = try alloc.dupe(u8, arg);
            } else {
                printErr(Err.InvalidArg, .{ .arg = arg });
            }
        }

        if (ret.fileName.len == 0) {
            printErr(Err.MissingFileName, .{});
        }
    }
};
