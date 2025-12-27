const std = @import("std");

pub const Color = enum {
    black,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    white,
    reset,

    pub fn fg(self: Color) []const u8 {
        return switch (self) {
            .black => "\x1b[30m",
            .red => "\x1b[31m",
            .green => "\x1b[32m",
            .yellow => "\x1b[33m",
            .blue => "\x1b[34m",
            .magenta => "\x1b[35m",
            .cyan => "\x1b[36m",
            .white => "\x1b[37m",
            .reset => "\x1b[0m",
        };
    }
};

fn getLineCol(src: []const u8, idx: usize) struct { usize, usize } {
    if (src.len == 0)
        return .{ 0, 0 };
    const id = if (idx >= src.len) src.len - 1 else idx;
    var col: usize = 1;
    var line: usize = 1;
    var i: usize = 0;
    while (i < id) {
        if (src[i] == '\n') {
            line += 1;
            col = 1;
        } else {
            col += 1;
        }
        i += 1;
    }
    return .{ line, col };
}

fn getLineAtIndex(src: []const u8, idx_: usize) []const u8 {
    if (src.len == 0) return "";

    const idx = if (idx_ >= src.len) src.len - 1 else idx_;

    var start: usize = idx;
    while (start > 0 and src[start - 1] != '\n') {
        start -= 1;
    }

    var end: usize = idx;
    while (end < src.len and src[end] != '\n') {
        end += 1;
    }

    return src[start..end];
}
pub fn err(fName: []const u8, src: []const u8, idx: usize, comptime msg: []const u8, args: anytype) void {
    std.debug.print("{s}Error{s}: ", .{ Color.fg(.red), Color.fg(.reset) });
    if (fName.len != 0)
        std.debug.print("{s}{s}{s}", .{ Color.fg(.yellow), fName, Color.fg(.reset) });

    const lineCol = getLineCol(src, idx);
    if (src.len != 0) {
        std.debug.print("({s}{d}{s}:", .{ Color.fg(.green), lineCol[0], Color.fg(.reset) });
        std.debug.print("{s}{d}{s}): ", .{ Color.fg(.green), lineCol[1], Color.fg(.reset) });
    } else if (fName.len != 0)
        std.debug.print(": ", .{});
    std.debug.print(msg, args);
    if (src.len != 0) {
        std.debug.print("\n  {s}\n  ", .{getLineAtIndex(src, idx)});
        var temp = lineCol[1];
        while (temp != 1) : (temp -= 1) {
            std.debug.print(" ", .{});
        }
        std.debug.print("{s}^{s}\n", .{ Color.fg(.red), Color.fg(.reset) });
    } else {
        std.debug.print("\n", .{});
    }
    std.process.exit(1);
}
