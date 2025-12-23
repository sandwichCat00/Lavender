const std = @import("std");
const Err = @import("errors.zig").LexError;
const printErr = @import("errors.zig").errLex;

pub const Lexer = struct {
    src: []const u8,
    fName: []const u8,
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator, fName: []const u8, src: []const u8) @This() {
        return .{ .src = src, .fName = fName, .alloc = alloc };
    }

    fn isSymbol(self: *@This(), idx: usize) bool {
        if (idx >= self.src.len)
            return false;
        switch (self.src[idx]) {
            '@', '=', '.', ',', ':', ';', '(', ')', '{', '}' => return true,
            '+', '-', '*', '/', '%' => return true,
            else => return false,
        }
    }

    pub fn lex(self: *@This()) !void {
        var idx: usize = 0;
        const len: usize = self.src.len;
        const src = self.src;
        while (idx < len) {
            if (std.ascii.isWhitespace(src[idx])) {
                while (idx < len and std.ascii.isWhitespace(src[idx])) {
                    idx += 1;
                }
            }
            if (idx >= len) return;
            if (std.ascii.isAlphabetic(src[idx]) or src[idx] == '_') {
                var arr: std.ArrayList(u8) = .empty;
                defer arr.deinit(self.alloc);
                while (idx < len and
                    (std.ascii.isAlphanumeric(src[idx]) or src[idx] == '_'))
                {
                    try arr.append(self.alloc, src[idx]);
                    idx += 1;
                }
                std.debug.print("{s}\n", .{try arr.toOwnedSlice(self.alloc)});
            } else if (std.ascii.isDigit(src[idx])) {
                var arr: std.ArrayList(u8) = .empty;
                defer arr.deinit(self.alloc);

                var hasDot = false;
                while (idx < len and
                    (std.ascii.isDigit(src[idx]) or src[idx] == '.'))
                {
                    if (src[idx] == '.') {
                        if (hasDot) {
                            printErr(Err.InvalidNumeric, .{ .fName = self.fName, .idx = idx, .src = src });
                        } else {
                            hasDot = true;
                        }
                    }
                    try arr.append(self.alloc, src[idx]);
                    idx += 1;
                }
                if (hasDot and arr.items[arr.items.len - 1] == '.') {
                    printErr(Err.InvalidNumeric, .{ .fName = self.fName, .idx = idx, .src = src });
                }
                if (idx < len and
                    (std.ascii.isAlphanumeric(src[idx]) or src[idx] == '_'))
                {
                    printErr(Err.InvalidNumeric, .{ .fName = self.fName, .idx = idx, .src = src });
                }
                std.debug.print("{s}\n", .{try arr.toOwnedSlice(self.alloc)});
            } else if (src[idx] == '\"') {
                idx += 1;
                var arr: std.ArrayList(u8) = .empty;
                defer arr.deinit(self.alloc);

                while (idx < len and src[idx] != '\"') {
                    if (src[idx] == '\\') {
                        idx += 1;
                        if (idx >= len) {
                            printErr(Err.InvalidEscSeq, .{ .fName = self.fName, .idx = idx, .src = src });
                        }
                        try arr.append(self.alloc, switch (src[idx]) {
                            'n' => '\n',
                            't' => '\t',
                            '0' => 0,
                            'r' => '\r',
                            '\\', '\'', '\"', '\n' => src[idx],
                            else => {
                                printErr(Err.InvalidEscSeq, .{ .fName = self.fName, .idx = idx, .src = src });
                                return undefined;
                            },
                        });
                    } else {
                        if (src[idx] == '\n')
                            printErr(Err.InvalidStr, .{ .fName = self.fName, .idx = idx, .src = src });
                        try arr.append(self.alloc, src[idx]);
                    }
                    idx += 1;
                }
                if (idx >= len or src[idx] != '\"') {
                    printErr(Err.InvalidStr, .{ .fName = self.fName, .idx = idx, .src = src });
                }
                idx += 1;
                std.debug.print("{s}\n", .{try arr.toOwnedSlice(self.alloc)});
            } else if (src[idx] == '\'') {
                var char: u8 = 0;
                idx += 1;
                if (idx >= len) {
                    printErr(Err.InvalidChar, .{ .fName = self.fName, .idx = idx, .src = src });
                }
                if (src[idx] == '\\') {
                    idx += 1;
                    if (idx >= len) {
                        printErr(Err.InvalidEscSeq, .{ .fName = self.fName, .idx = idx, .src = src });
                    }
                    char = switch (src[idx]) {
                        'n' => '\n',
                        't' => '\t',
                        '0' => 0,
                        'r' => '\r',
                        '\\', '\'', '\"', '\n' => src[idx],
                        else => {
                            printErr(Err.InvalidEscSeq, .{ .fName = self.fName, .idx = idx, .src = src });
                            return undefined;
                        },
                    };
                } else {
                    char = src[idx];
                }
                idx += 1;
                if (idx >= len or src[idx] != '\'') {
                    printErr(Err.InvalidChar, .{ .fName = self.fName, .idx = idx, .src = src });
                }

                idx += 1;
                std.debug.print("{c}\n", .{char});
            } else if (self.isSymbol(idx)) {
                std.debug.print("{c}\n", .{src[idx]});
                idx += 1;
            } else {
                printErr(Err.UnknownChar, .{ .fName = self.fName, .idx = idx, .src = src });
                idx += 1;
            }
        }
    }
};
