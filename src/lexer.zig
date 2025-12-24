const std = @import("std");
const Err = @import("errors.zig").LexError;
const printErr = @import("errors.zig").errLex;
const lexeme = @import("lexeme.zig");

pub const Lexer = struct {
    src: []const u8,
    fName: []const u8,
    tokens: std.ArrayList(lexeme.Token) = .empty,
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator, fName: []const u8, src: []const u8) @This() {
        return .{
            .src = src,
            .fName = fName,
            .alloc = alloc,
        };
    }

    pub fn lex(self: *@This()) Err!void {
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
                const initIdx = idx;
                var arr: std.ArrayList(u8) = .empty;
                defer arr.deinit(self.alloc);
                while (idx < len and
                    (std.ascii.isAlphanumeric(src[idx]) or src[idx] == '_'))
                {
                    try arr.append(self.alloc, src[idx]);
                    idx += 1;
                }
                try self.tokens.append(self.alloc, try lexeme.getTextType(self.alloc, initIdx, arr.items));
            } else if (std.ascii.isDigit(src[idx])) {
                var arr: std.ArrayList(u8) = .empty;
                defer arr.deinit(self.alloc);
                const initIdx = idx;
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
                if (hasDot) {
                    const x = std.fmt.parseFloat(f64, arr.items) catch 0.0;
                    try self.tokens.append(self.alloc, .{ .idx = initIdx, .kind = .{ .FloatLiteral = x } });
                } else {
                    const x = std.fmt.parseInt(i64, arr.items, 10) catch 0;
                    try self.tokens.append(self.alloc, .{ .idx = initIdx, .kind = .{ .IntLiteral = x } });
                }
            } else if (src[idx] == '\"') {
                const initIdx = idx;
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
                try self.tokens.append(self.alloc, .{ .kind = .{ .StrLiteral = try self.alloc.dupe(u8, arr.items) }, .idx = initIdx });
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
                try self.tokens.append(self.alloc, .{ .kind = .{ .CharLiteral = char }, .idx = idx });
            } else if (lexeme.checkSymbol(src[idx])) {
                try self.tokens.append(self.alloc, try lexeme.getSymbol(src, &idx));
                idx += 1;
            } else {
                printErr(Err.UnknownChar, .{ .fName = self.fName, .idx = idx, .src = src });
                idx += 1;
            }
        }
    }
};
