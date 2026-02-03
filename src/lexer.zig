const std = @import("std");
const err = @import("util.zig").err;
const lexeme = @import("lexeme.zig");
const testing = std.testing;

var isTest = false;
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

    pub fn deinit(self: *@This()) void {
        for (self.tokens.items) |*tok| {
            tok.deinit(self.alloc);
        }
        self.tokens.deinit(self.alloc);
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
                const initIdx = idx;
                while (idx < len and
                    (std.ascii.isAlphanumeric(src[idx]) or src[idx] == '_'))
                {
                    idx += 1;
                }
                try self.tokens.append(self.alloc, try lexeme.getTextType(initIdx, src[initIdx..idx]));
            } else if (std.ascii.isDigit(src[idx])) {
                const initIdx = idx;
                var hasDot = false;
                while (idx < len and
                    (std.ascii.isDigit(src[idx]) or src[idx] == '.'))
                {
                    if (src[idx] == '.') {
                        if (hasDot) {
                            if (!isTest) {
                                err(self.fName, self.src, idx, "Invalid sufix to the numeric", .{});
                            } else return error.InvalidNumeric;
                        } else {
                            hasDot = true;
                        }
                    }
                    idx += 1;
                }
                if (hasDot and src[idx - 1] == '.') {
                    if (!isTest) {
                        err(self.fName, self.src, idx, "Invalid sufix to the numeric", .{});
                    } else return error.InvalidNumeric;
                }
                if (idx < len and
                    (std.ascii.isAlphanumeric(src[idx]) or src[idx] == '_'))
                {
                    if (!isTest) {
                        err(self.fName, self.src, idx, "Invalid sufix to the numeric", .{});
                    } else return error.InvalidNumeric;
                }
                if (hasDot) {
                    const x = std.fmt.parseFloat(f64, src[initIdx..idx]) catch 0.0;
                    try self.tokens.append(self.alloc, .{ .idx = initIdx, .kind = .{ .FloatLiteral = x } });
                } else {
                    const x = std.fmt.parseInt(u64, src[initIdx..idx], 10) catch 0;
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
                            if (!isTest) {
                                err(self.fName, self.src, idx, "Invalid escape sequence", .{});
                            } else return error.InvalidEscSeq;
                        }
                        try arr.append(self.alloc, switch (src[idx]) {
                            'n' => '\n',
                            't' => '\t',
                            '0' => 0,
                            'r' => '\r',
                            '\\', '\'', '\"', '\n' => src[idx],
                            else => {
                                if (!isTest) {
                                    err(self.fName, self.src, idx, "Invalid escape sequence", .{});
                                } else return error.InvalidEscSeq;

                                return undefined;
                            },
                        });
                    } else {
                        if (src[idx] == '\n')
                            if (!isTest) {
                                err(self.fName, self.src, idx, "Invalid character '\\n' in string literal", .{});
                            } else return error.InvalidStr;

                        try arr.append(self.alloc, src[idx]);
                    }
                    idx += 1;
                }
                if (idx >= len or src[idx] != '\"') {
                    if (!isTest) {
                        err(self.fName, self.src, idx, "Invalid string literal", .{});
                    } else return error.InvalidStr;
                }
                idx += 1;
                try self.tokens.append(self.alloc, .{ .kind = .{ .StrLiteral = try self.alloc.dupe(u8, arr.items) }, .idx = initIdx });
            } else if (src[idx] == '\'') {
                var char: u8 = 0;
                idx += 1;
                if (idx >= len or src[idx] == '\n') {
                    if (!isTest) {
                        err(self.fName, self.src, idx, "Invalid character literal", .{});
                    } else return error.InvalidChar;
                }
                if (src[idx] == '\\') {
                    idx += 1;
                    if (idx >= len) {
                        if (!isTest) {
                            err(self.fName, self.src, idx, "Invalid escape sequence", .{});
                        } else return error.InvalidEscSeq;
                    }
                    char = switch (src[idx]) {
                        'n' => '\n',
                        't' => '\t',
                        '0' => 0,
                        'r' => '\r',
                        '\\', '\'', '\"' => src[idx],
                        else => {
                            if (!isTest) {
                                err(self.fName, self.src, idx, "Invalid escape sequence", .{});
                            } else return error.InvalidEscSeq;

                            return undefined;
                        },
                    };
                } else {
                    char = src[idx];
                }
                idx += 1;
                if (idx >= len or src[idx] != '\'') {
                    if (!isTest) {
                        err(self.fName, self.src, idx, "Invalid character literal", .{});
                    } else return error.InvalidChar;
                }

                idx += 1;
                try self.tokens.append(self.alloc, .{ .kind = .{ .CharLiteral = char }, .idx = idx });
            } else if (lexeme.checkSymbol(src[idx])) {
                try self.tokens.append(self.alloc, try lexeme.getSymbol(src, &idx));
                idx += 1;
            } else {
                if (!isTest) {
                    err(self.fName, self.src, idx, "Unknown character found in src file: {c}", .{src[idx]});
                } else return error.UnknownChar;
                idx += 1;
            }
        }
    }

    pub fn deinitStatements(stats: *std.ArrayList(std.ArrayList(lexeme.Token)), alloc: std.mem.Allocator) void {
        for (stats.items) |*stat| {
            for (stat.items) |*tok| {
                tok.deinit(alloc);
            }
            stat.deinit(alloc);
        }
        stats.deinit(alloc);
    }

    pub fn toStatements(self: *@This(), alloc: std.mem.Allocator) error{OutOfMemory}!std.ArrayList(std.ArrayList(lexeme.Token)) {
        var idx: usize = 0;
        var stats: std.ArrayList(std.ArrayList(lexeme.Token)) = .empty;
        const tokens = self.tokens.items;

        while (idx < tokens.len) {
            var stat: std.ArrayList(lexeme.Token) = .empty;
            while (idx < tokens.len and tokens[idx].kind != .StatEnd) {
                if (tokens[idx].kind == .BraceOpen or tokens[idx].kind == .BraceClose) {
                    if (stat.items.len != 0)
                        try stats.append(alloc, stat);
                    stat = .empty;
                    try stat.append(alloc, tokens[idx]);
                    break;
                } else {
                    switch (tokens[idx].kind) {
                        .StrLiteral => |s| {
                            var tok = tokens[idx];
                            tok.kind = .{ .StrLiteral = try alloc.dupe(u8, s) };
                            try stat.append(alloc, tok);
                        },
                        else => {
                            try stat.append(alloc, tokens[idx]);
                        },
                    }
                }
                idx += 1;
            }
            if (stat.items.len != 0)
                try stats.append(alloc, stat);
            idx += 1;
        }
        return stats;
    }
};

fn match(items: []lexeme.Token, kinds: []const lexeme.TokenKind) !void {
    try testing.expect(items.len == kinds.len);
    for (items, 0..) |tok, idx| {
        switch (tok.kind) {
            .FloatLiteral => |x| switch (kinds[idx]) {
                .FloatLiteral => |y| try testing.expect(x == y),
                else => return error.x,
            },
            .CharLiteral => |x| switch (kinds[idx]) {
                .CharLiteral => |y| try testing.expect(x == y),
                else => return error.x,
            },
            .StrLiteral => |x| switch (kinds[idx]) {
                .StrLiteral => |y| try testing.expect(std.mem.eql(u8, x, y)),
                else => return error.x,
            },
            .Identifier => |x| switch (kinds[idx]) {
                .Identifier => |y| try testing.expect(std.mem.eql(u8, x, y)),
                else => return error.x,
            },

            .IntLiteral => |x| switch (kinds[idx]) {
                .IntLiteral => |y| try testing.expect(x == y),
                else => return error.x,
            },
            else => {
                const tag = std.meta.activeTag(tok.kind);

                try testing.expect(tag == kinds[idx]);
            },
        }
    }
}

fn matchX(tok: lexeme.Token, kind: lexeme.TokenKind) !void {
    switch (tok.kind) {
        .FloatLiteral => |x| switch (kind) {
            .FloatLiteral => |y| try testing.expect(x == y),
            else => return error.x,
        },
        .CharLiteral => |x| switch (kind) {
            .CharLiteral => |y| try testing.expect(x == y),
            else => return error.x,
        },
        .StrLiteral => |x| switch (kind) {
            .StrLiteral => |y| try testing.expect(std.mem.eql(u8, x, y)),
            else => return error.x,
        },
        .Identifier => |x| switch (kind) {
            .Identifier => |y| try testing.expect(std.mem.eql(u8, x, y)),
            else => return error.x,
        },

        .IntLiteral => |x| switch (kind) {
            .IntLiteral => |y| try testing.expect(x == y),
            else => return error.x,
        },
        else => {
            const tag = std.meta.activeTag(tok.kind);

            try testing.expect(tag == kind);
        },
    }
}

test "lexer empty" {
    isTest = true;

    var lex = Lexer.init(testing.allocator, "", "");
    try lex.lex();
    defer lex.deinit();
    try testing.expect(lex.tokens.items.len == 0);
}

test "lexer whitespace only" {
    isTest = true;

    var lex = Lexer.init(testing.allocator, "", "   \n\t\r   ");

    try lex.lex();
    defer lex.deinit();
    try testing.expect(lex.tokens.items.len == 0);
}

test "lexer single identifier" {
    isTest = true;

    var lex = Lexer.init(testing.allocator, "", "a");
    defer lex.deinit();

    try lex.lex();

    try testing.expect(lex.tokens.items.len == 1);
    try testing.expect(lex.tokens.items[0].kind == .Identifier);
}

test "lexer @" {
    isTest = true;

    var lex = Lexer.init(testing.allocator, "", "@");
    try lex.lex();
    defer lex.deinit();
    try testing.expect(lex.tokens.items.len == 1);
    try testing.expect(lex.tokens.items[0].kind == .Declarative);
}

test "lexer keyword pub" {
    isTest = true;

    var lex = Lexer.init(testing.allocator, "", "pub");
    defer lex.deinit();

    try lex.lex();

    try testing.expect(lex.tokens.items.len == 1);
    try testing.expect(lex.tokens.items[0].kind == .Public);
}

test "lexer keywords" {
    isTest = true;
    const kinds = [_]lexeme.TokenKind{ .{ .Identifier = "a" }, .{ .FloatLiteral = 1.1 }, .{ .Identifier = "defx" }, .Let, .Def, .Public, .Import };
    var lex = Lexer.init(testing.allocator, "", "a 1.1 defx let def    pub import    ");
    defer lex.deinit();

    try lex.lex();
    try match(lex.tokens.items, &kinds);
}

test "lexer error UnknownChar" {
    isTest = true;

    var lex = Lexer.init(testing.allocator, "", "#");
    try testing.expectError(error.UnknownChar, lex.lex());
    lex.deinit();

    lex = Lexer.init(testing.allocator, "", "λ");
    try testing.expectError(error.UnknownChar, lex.lex());
    lex.deinit();
}
test "lexer error Invalid Numeric" {
    isTest = true;

    var lex = Lexer.init(testing.allocator, "", "1.2.1");
    try testing.expectError(error.InvalidNumeric, lex.lex());
    lex.deinit();

    lex = Lexer.init(testing.allocator, "", "1.2.");
    try testing.expectError(error.InvalidNumeric, lex.lex());
    lex.deinit();

    lex = Lexer.init(testing.allocator, "", "123abc");
    try testing.expectError(error.InvalidNumeric, lex.lex());
    lex.deinit();
}

test "lexer error Invalid String" {
    isTest = true;

    var lex = Lexer.init(testing.allocator, "", "\"hello");
    try testing.expectError(error.InvalidStr, lex.lex());
    lex.deinit();

    lex = Lexer.init(testing.allocator, "", "\"");
    try testing.expectError(error.InvalidStr, lex.lex());
    lex.deinit();
    lex = Lexer.init(testing.allocator, "", "\"hello\nworld\"");
    try testing.expectError(error.InvalidStr, lex.lex());
    lex.deinit();

    lex = Lexer.init(testing.allocator, "", "\"\\x\"");
    try testing.expectError(error.InvalidEscSeq, lex.lex());
    lex.deinit();
    lex = Lexer.init(testing.allocator, "", "\"\\");
    try testing.expectError(error.InvalidEscSeq, lex.lex());
    lex.deinit();
}
test "lexer error Invalid Char" {
    isTest = true;

    var lex = Lexer.init(testing.allocator, "", "\'");
    try testing.expectError(error.InvalidChar, lex.lex());
    lex.deinit();

    lex = Lexer.init(testing.allocator, "", "''");
    try testing.expectError(error.InvalidChar, lex.lex());
    lex.deinit();
    lex = Lexer.init(testing.allocator, "", "'\n'");
    try testing.expectError(error.InvalidChar, lex.lex());
    lex.deinit();

    lex = Lexer.init(testing.allocator, "", "'ab'");
    try testing.expectError(error.InvalidChar, lex.lex());
    lex.deinit();
    lex = Lexer.init(testing.allocator, "", "'a");
    try testing.expectError(error.InvalidChar, lex.lex());
    lex.deinit();
}

test "toStatements empty" {
    isTest = true;

    var lex = Lexer.init(testing.allocator, "", "");
    try lex.lex();
    var stats = try lex.toStatements(testing.allocator);
    defer Lexer.deinitStatements(&stats, testing.allocator);

    lex.deinit();
    try testing.expect(stats.items.len == 0);
}

test "toStatements text" {
    isTest = true;
    const stat0 = [_]lexeme.Token{
        .{ .idx = 0, .kind = .Declarative },
        .{ .idx = 0, .kind = .Import },
        .{ .idx = 0, .kind = .{ .Identifier = "std" } },
    };

    const stat1 = [_]lexeme.Token{
        .{ .idx = 0, .kind = .Declarative },
        .{ .idx = 0, .kind = .Import },
        .{ .idx = 0, .kind = .{ .Identifier = "std" } },
        .{ .idx = 0, .kind = .MemberOp },
        .{ .idx = 0, .kind = .{ .Identifier = "math" } },
        .{ .idx = 0, .kind = .As },
        .{ .idx = 0, .kind = .{ .Identifier = "math" } },
    };

    const stat2 = [_]lexeme.Token{
        .{ .idx = 0, .kind = .Def },
        .{ .idx = 0, .kind = .{ .Identifier = "add" } },
        .{ .idx = 0, .kind = .ParenOpen },
        .{ .idx = 0, .kind = .{ .Identifier = "a" } },
        .{ .idx = 0, .kind = .TypeOf },
        .{ .idx = 0, .kind = .IntType },
        .{ .idx = 0, .kind = .Comma },
        .{ .idx = 0, .kind = .{ .Identifier = "b" } },
        .{ .idx = 0, .kind = .TypeOf },
        .{ .idx = 0, .kind = .IntType },
        .{ .idx = 0, .kind = .ParenClose },
    };

    const stat3 = [_]lexeme.Token{
        .{ .idx = 0, .kind = .BraceOpen },
    };

    const stat4 = [_]lexeme.Token{
        .{ .idx = 0, .kind = .Return },
        .{ .idx = 0, .kind = .{ .Identifier = "math" } },
        .{ .idx = 0, .kind = .MemberOp },
        .{ .idx = 0, .kind = .{ .Identifier = "max" } },
        .{ .idx = 0, .kind = .ParenOpen },
        .{ .idx = 0, .kind = .{ .Identifier = "a" } },
        .{ .idx = 0, .kind = .Comma },
        .{ .idx = 0, .kind = .{ .Identifier = "b" } },
        .{ .idx = 0, .kind = .ParenClose },
        .{ .idx = 0, .kind = .AddOp },
        .{ .idx = 0, .kind = .{ .Identifier = "a" } },
    };

    const stat5 = [_]lexeme.Token{
        .{ .idx = 0, .kind = .BraceClose },
    };
    const expectedStats = [_][]const lexeme.Token{
        stat0[0..],
        stat1[0..],
        stat2[0..],
        stat3[0..],
        stat4[0..],
        stat5[0..],
    };

    var lex = Lexer.init(testing.allocator, "",
        \\@import std;
        \\@import std.math as math;
        \\def add(a:int, b:int) {
        \\    return math.max(a, b)  + a; 
        \\}
    );
    try lex.lex();
    defer lex.deinit();
    var stats = try lex.toStatements(testing.allocator);
    defer Lexer.deinitStatements(&stats, testing.allocator);
    try testing.expect(stats.items.len == expectedStats.len);
    for (stats.items, 0..) |stat, idx| {
        try testing.expect(stat.items.len == expectedStats[idx].len);
        for (stat.items, 0..) |tok, idy| {
            try matchX(tok, expectedStats[idx][idy].kind);
        }
    }
}
