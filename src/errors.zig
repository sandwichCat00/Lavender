const std = @import("std");
const Colors = @import("util.zig").Color;

pub const ArgError = error{
    InvalidArg,
    MissingFileName,
    OutOfMemory,
    FileNotFound,
    FileTooBig,
};
pub const LexError = error{
    UnknownChar,
    InvalidNumeric,
    InvalidStr,
    InvalidEscSeq,
    InvalidChar,
    OutOfMemory,
};

pub const ErrParameters = struct {
    fName: []const u8 = "",
    arg: []const u8 = "",
    src: []const u8 = "",
    idx: usize = 0,
};

fn help() void {
    std.debug.print("lavender [OPTIONS] <Src | Bin File>\n", .{});
}

pub fn errArg(er: ArgError, par: ErrParameters) void {
    switch (er) {
        ArgError.InvalidArg => {
            std.debug.print("{s}Error{s}: ", .{ Colors.fg(.red), Colors.fg(.reset) });
            std.debug.print("Invalid argument: {s}.\n", .{par.arg});
            help();
        },
        ArgError.MissingFileName => {
            std.debug.print("{s}Error{s}: File name expected.\n", .{ Colors.fg(.red), Colors.fg(.reset) });
            help();
        },
        ArgError.FileNotFound => {
            std.debug.print("{s}Error{s}: ", .{ Colors.fg(.red), Colors.fg(.reset) });
            std.debug.print("{s}{s}{s}: ", .{ Colors.fg(.yellow), par.fName, Colors.fg(.reset) });
            std.debug.print("File not found.", .{});
        },
        ArgError.FileTooBig => {
            std.debug.print("{s}Error{s}: ", .{ Colors.fg(.red), Colors.fg(.reset) });
            std.debug.print("{s}{s}{s}: ", .{ Colors.fg(.yellow), par.fName, Colors.fg(.reset) });
            std.debug.print("File too big.", .{});
        },

        else => {
            std.debug.print("{s}Error{s}: Invalid error.\n", .{ Colors.fg(.red), Colors.fg(.reset) });
        },
    }

    std.process.exit(1);
}

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
pub fn errLex(er: LexError, par: ErrParameters) void {
    std.debug.print("{s}Error{s}: ", .{ Colors.fg(.red), Colors.fg(.reset) });
    std.debug.print("{s}{s}{s}", .{ Colors.fg(.yellow), par.fName, Colors.fg(.reset) });
    const lineCol = getLineCol(par.src, par.idx);
    std.debug.print("({s}{d}{s}:", .{ Colors.fg(.green), lineCol[0], Colors.fg(.reset) });
    std.debug.print("{s}{d}{s}): ", .{ Colors.fg(.green), lineCol[1], Colors.fg(.reset) });

    switch (er) {
        LexError.UnknownChar => std.debug.print("Use of unknown character.\n", .{}),
        LexError.InvalidNumeric => std.debug.print("Invalid digit suffix '{c}'", .{par.src[par.idx]}),
        LexError.InvalidStr => std.debug.print("Invalid string literal", .{}),
        LexError.InvalidEscSeq => std.debug.print("Invalid escape sequence '\\{c}'", .{par.src[par.idx]}),
        LexError.InvalidChar => std.debug.print("Invalid char literal", .{}),
        LexError.OutOfMemory => std.debug.print("Unknown error", .{}),
    }

    std.debug.print("\n  {s}\n  ", .{getLineAtIndex(par.src, par.idx)});
    var temp = lineCol[1];
    while (temp != 1) : (temp -= 1) {
        std.debug.print(" ", .{});
    }
    std.debug.print("{s}^{s}\n", .{ Colors.fg(.red), Colors.fg(.reset) });
    std.process.exit(1);
}
