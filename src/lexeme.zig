const std = @import("std");
const ast = @import("ast.zig");
pub const TokenKind = union(enum) {
    Identifier: []const u8,
    IntLiteral: u64,
    FloatLiteral: f64,
    CharLiteral: u8,
    StrLiteral: []const u8,
    True,
    False,

    Import,
    As,
    Def,
    Public,
    Let,
    Return,
    If,
    Else,
    While,
    Break,

    IntType,
    BoolType,
    FloatType,
    StrType,
    CharType,
    VoidType,

    Declarative,
    MemberOp,
    StatEnd,
    TypeOf,
    ParenOpen,
    ParenClose,
    BrackOpen,
    BrackClose,
    BraceOpen,
    BraceClose,

    Comma,

    EqlOp,

    AddEqlOp,
    SubEqlOp,
    MulEqlOp,
    DivEqlOp,
    ModEqlOp,

    AddOp,
    SubOp,
    MulOp,
    DivOp,
    ModOp,

    IsEqlOp,
    IsGrterOp,
    IsLessOp,

    SignSubOp,
    Unset,

    DefCall: []const u8,

    pub fn toStr(
        self: @This(),
        alloc: std.mem.Allocator,
    ) []const u8 {
        return switch (self) {
            .Identifier => |x| alloc.dupe(u8, x) catch "error",
            .StrLiteral => |x| std.fmt.allocPrint(alloc, "\"{s}\"", .{x}) catch "error",
            .IntLiteral => |x| std.fmt.allocPrint(alloc, "{}", .{x}) catch "error",
            .FloatLiteral => |x| std.fmt.allocPrint(alloc, "{}", .{x}) catch "error",
            .CharLiteral => |x| std.fmt.allocPrint(alloc, "'{c}'", .{x}) catch "error",

            .Import => alloc.dupe(u8, "import") catch "error",
            .As => alloc.dupe(u8, "as") catch "error",
            .Let => alloc.dupe(u8, "let") catch "error",
            .Def => alloc.dupe(u8, "def") catch "error",
            .Public => alloc.dupe(u8, "pub") catch "error",
            .Return => alloc.dupe(u8, "return") catch "error",
            .If => alloc.dupe(u8, "if") catch "error",
            .Else => alloc.dupe(u8, "else") catch "error",
            .While => alloc.dupe(u8, "while") catch "error",
            .Break => alloc.dupe(u8, "break") catch "error",
            .True => alloc.dupe(u8, "true") catch "error",
            .False => alloc.dupe(u8, "false") catch "error",

            .IntType => alloc.dupe(u8, "int") catch "error",
            .StrType => alloc.dupe(u8, "str") catch "error",
            .CharType => alloc.dupe(u8, "char") catch "error",
            .FloatType => alloc.dupe(u8, "float") catch "error",
            .BoolType => alloc.dupe(u8, "bool") catch "error",
            .VoidType => alloc.dupe(u8, "void") catch "error",

            .Declarative => alloc.dupe(u8, "@") catch "error",
            .MemberOp => alloc.dupe(u8, ".") catch "error",
            .StatEnd => alloc.dupe(u8, ";") catch "error",
            .TypeOf => alloc.dupe(u8, ":") catch "error",
            .ParenOpen => alloc.dupe(u8, "(") catch "error",
            .ParenClose => alloc.dupe(u8, ")") catch "error",
            .BrackOpen => alloc.dupe(u8, "[") catch "error",
            .BrackClose => alloc.dupe(u8, "]") catch "error",
            .BraceOpen => alloc.dupe(u8, "{") catch "error",
            .BraceClose => alloc.dupe(u8, "}") catch "error",

            .Comma => alloc.dupe(u8, ",") catch "error",

            .AddEqlOp => alloc.dupe(u8, "+=") catch "error",
            .SubEqlOp => alloc.dupe(u8, "-=") catch "error",
            .MulEqlOp => alloc.dupe(u8, "*=") catch "error",
            .DivEqlOp => alloc.dupe(u8, "/=") catch "error",
            .ModEqlOp => alloc.dupe(u8, "%=") catch "error",

            .AddOp => alloc.dupe(u8, "+") catch "error",
            .EqlOp => alloc.dupe(u8, "=") catch "error",
            .SubOp => alloc.dupe(u8, "-") catch "error",
            .SignSubOp => alloc.dupe(u8, "-") catch "error",
            .MulOp => alloc.dupe(u8, "*") catch "error",
            .DivOp => alloc.dupe(u8, "/") catch "error",
            .ModOp => alloc.dupe(u8, "%") catch "error",

            .IsEqlOp => alloc.dupe(u8, "==") catch "error",
            .IsGrterOp => alloc.dupe(u8, ">") catch "error",
            .IsLessOp => alloc.dupe(u8, "<") catch "error",

            .DefCall => |x| std.fmt.allocPrint(alloc, "{s}()", .{x}) catch "error",
            .Unset => alloc.dupe(u8, "<UNSET>") catch "error",
        };
    }

    pub fn prec(self: @This()) u8 {
        return switch (self) {
            .EqlOp, .SubEqlOp, .AddEqlOp, .MulEqlOp, .DivEqlOp, .ModEqlOp => 1,
            .IsEqlOp, .IsGrterOp, .IsLessOp => 4,
            .AddOp, .SubOp => 5,
            .MulOp, .DivOp, .ModOp => 10,
            else => 0,
        };
    }

    pub fn isLiteral(self: @This()) bool {
        return switch (self) {
            .IntLiteral,
            .FloatLiteral,
            .StrLiteral,
            .CharLiteral,
            .False,
            .True,
            => true,
            else => false,
        };
    }

    pub fn isUnmodifiedUniOp(self: @This()) bool {
        return switch (self) {
            .SubOp => true,
            else => false,
        };
    }

    pub fn isUniOp(self: @This()) bool {
        return switch (self) {
            .SignSubOp => true,
            else => false,
        };
    }
    pub fn isBinOp(self: @This()) bool {
        return switch (self) {
            .EqlOp, .AddEqlOp, .SubEqlOp, .MulEqlOp, .DivEqlOp, .ModEqlOp => true,
            .AddOp, .SubOp, .MulOp, .DivOp, .ModOp => true,
            .IsEqlOp, .IsGrterOp, .IsLessOp => true,
            else => false,
        };
    }

    pub fn isEqlOp(self: @This()) bool {
        return switch (self) {
            .EqlOp, .AddEqlOp, .SubEqlOp, .MulEqlOp, .DivEqlOp, .ModEqlOp => true,
            else => false,
        };
    }

    pub fn isType(self: @This()) bool {
        return switch (self) {
            .IntType,
            .FloatType,
            .StrType,
            .CharType,
            .VoidType,
            .BoolType,
            => true,
            else => false,
        };
    }
};

pub const Token = struct {
    idx: usize,
    kind: TokenKind,

    pub fn toStr(self: @This(), alloc: std.mem.Allocator) []const u8 {
        return self.kind.toStr(alloc);
    }

    pub fn toOwned(self: @This(), alloc: std.mem.Allocator) !@This() {
        var tok = self;
        switch (tok.kind) {
            .StrLiteral => |s| tok.kind = .{ .StrLiteral = try alloc.dupe(u8, s) },
            else => {},
        }
        return tok;
    }

    pub fn deinit(self: *@This(), alloc: std.mem.Allocator) void {
        switch (self.kind) {
            .StrLiteral => |s| alloc.free(s),
            .DefCall => |s| alloc.free(s),
            else => {},
        }
    }
};

pub fn checkSymbol(char: u8) bool {
    switch (char) {
        '@', '=', '.', ',', ':', ';', '(', ')', '{', '}' => return true,
        '+', '-', '*', '/', '%' => return true,
        '>', '<' => return true,
        else => return false,
    }
}

pub fn getSymbol(src: []const u8, idx: *usize) !Token {
    if (idx.* >= src.len)
        return error.Unknown;

    const kind: TokenKind = switch (src[idx.*]) {
        '@' => .Declarative,

        '.' => .MemberOp,
        ';' => .StatEnd,
        ':' => .TypeOf,
        ',' => .Comma,

        '(' => .ParenOpen,
        ')' => .ParenClose,
        '[' => .BrackOpen,
        ']' => .BrackClose,
        '{' => .BraceOpen,
        '}' => .BraceClose,

        '+' => lp: {
            if (idx.* < src.len - 1 and src[idx.* + 1] == '=') {
                idx.* += 1;
                return .{ .kind = .AddEqlOp, .idx = idx.* - 1 };
            }
            break :lp .AddOp;
        },
        '-' => lp: {
            if (idx.* < src.len - 1 and src[idx.* + 1] == '=') {
                idx.* += 1;
                return .{ .kind = .SubEqlOp, .idx = idx.* - 1 };
            }
            break :lp .SubOp;
        },
        '*' => lp: {
            if (idx.* < src.len - 1 and src[idx.* + 1] == '=') {
                idx.* += 1;
                return .{ .kind = .MulEqlOp, .idx = idx.* - 1 };
            }
            break :lp .MulOp;
        },

        '/' => lp: {
            if (idx.* < src.len - 1 and src[idx.* + 1] == '=') {
                idx.* += 1;
                return .{ .kind = .DivEqlOp, .idx = idx.* - 1 };
            }
            break :lp .DivOp;
        },
        '%' => lp: {
            if (idx.* < src.len - 1 and src[idx.* + 1] == '=') {
                idx.* += 1;
                return .{ .kind = .ModEqlOp, .idx = idx.* - 1 };
            }
            break :lp .ModOp;
        },

        '=' => lp: {
            if (idx.* < src.len and src[idx.* + 1] == '=') {
                idx.* += 1;
                return .{ .kind = .IsEqlOp, .idx = idx.* - 1 };
            }
            break :lp .EqlOp;
        },
        '>' => .IsGrterOp,
        '<' => .IsLessOp,

        else => return error.InvalidChar,
    };

    return .{ .kind = kind, .idx = idx.* };
}

const Keyword = struct {
    text: []const u8,
    kind: TokenKind,
};

const keywords = [_]Keyword{
    .{ .text = "import", .kind = .Import },
    .{ .text = "as", .kind = .As },
    .{ .text = "def", .kind = .Def },
    .{ .text = "pub", .kind = .Public },
    .{ .text = "let", .kind = .Let },
    .{ .text = "return", .kind = .Return },

    .{ .text = "int", .kind = .IntType },
    .{ .text = "float", .kind = .FloatType },
    .{ .text = "str", .kind = .StrType },
    .{ .text = "bool", .kind = .BoolType },
    .{ .text = "void", .kind = .VoidType },

    .{ .text = "if", .kind = .If },
    .{ .text = "else", .kind = .Else },
    .{ .text = "while", .kind = .While },
    .{ .text = "break", .kind = .Break },

    .{ .text = "true", .kind = .True },
    .{ .text = "false", .kind = .False },
};

pub fn getTextType(idx: usize, txt: []const u8) !Token {
    for (keywords) |kw|
        if (std.mem.eql(u8, kw.text, txt))
            return .{ .idx = idx, .kind = kw.kind };

    return .{ .idx = idx, .kind = .{ .Identifier = txt } };
}
