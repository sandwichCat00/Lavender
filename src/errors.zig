const std = @import("std");
const Colors = @import("util.zig").Color;

pub const ArgError = error{
    InvalidArg,
    MissingFileName,
    OutOfMemory,
};

pub const ErrParameters = struct {
    fName: []const u8 = "",
    arg: []const u8 = "",
};

fn help() void {
    std.debug.print("lavender [OPTIONS] <Src | Bin File>\n", .{});
}

pub fn err(er: anyerror, par: ErrParameters) void {
    switch (er) {
        ArgError.InvalidArg => {
            std.debug.print("{s}Error{s}: ", .{ Colors.fg(.red), Colors.fg(.reset) });
            std.debug.print("Invalid argument: {s}\n", .{par.arg});
            help();
        },
        ArgError.MissingFileName => {
            std.debug.print("{s}Error{s}: File Name Expected.\n", .{ Colors.fg(.red), Colors.fg(.reset) });
            help();
        },
        else => {},
    }

    std.process.exit(1);
}
