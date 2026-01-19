const std = @import("std");

pub const TokenKind = union(enum) {
    Identifier: []const u8,
    IntLiteral: i64,
    FloatLiteral: f64,
    CharLiteral: u8,
    StrLiteral: []const u8,

    Import,
    As,
    Def,
    Public,
    Let,
    Return,

    IntType,
    FloatType,
    StrType,
    CharType,

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
    AddOp,
    SubOp,
    SignSubOp,
    MulOp,
    DivOp,
    ModOp,

    Unset,

    pub fn prec(self: @This()) u8 {
        return switch (self) {
            .AddOp, .SubOp => 1,
            .MulOp, .DivOp, .ModOp => 2,
            else => 0,
        };
    }

    pub fn isLiteral(self: @This()) bool {
        return switch (self) {
            .IntLiteral,
            .FloatLiteral,
            .StrLiteral,
            .CharLiteral,
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
            .EqlOp,
            .AddOp,
            .SubOp,
            .MulOp,
            .DivOp,
            .ModOp,
            => true,
            else => false,
        };
    }
    pub fn isType(self: @This()) bool {
        return switch (self) {
            .IntType,
            .FloatType,
            .StrType,
            .CharType,
            => true,
            else => false,
        };
    }
};

pub const Token = struct {
    idx: usize,
    kind: TokenKind,

    pub fn toStr(
        self: *const @This(),
        alloc: std.mem.Allocator,
    ) []const u8 {
        return switch (self.kind) {
            .Identifier => |x| alloc.dupe(u8, x) catch "error",
            // .StrLiteral => |x| alloc.dupe(u8, x) catch "error",

            // .Identifier => |x| std.fmt.allocPrint(alloc, "[IDNT: {s}]", .{x}) catch "error",
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

            .IntType => alloc.dupe(u8, "int") catch "error",
            .StrType => alloc.dupe(u8, "str") catch "error",
            .CharType => alloc.dupe(u8, "char") catch "error",
            .FloatType => alloc.dupe(u8, "float") catch "error",

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

            .AddOp => alloc.dupe(u8, "+") catch "error",
            .EqlOp => alloc.dupe(u8, "=") catch "error",
            .SubOp => alloc.dupe(u8, "-") catch "error",
            .SignSubOp => alloc.dupe(u8, "-") catch "error",
            .MulOp => alloc.dupe(u8, "*") catch "error",
            .DivOp => alloc.dupe(u8, "/") catch "error",
            .ModOp => alloc.dupe(u8, "%") catch "error",

            .Unset => alloc.dupe(u8, "<UNSET>") catch "error",
        };
    }
};

pub fn checkSymbol(char: u8) bool {
    switch (char) {
        '@', '=', '.', ',', ':', ';', '(', ')', '{', '}' => return true,
        '+', '-', '*', '/', '%' => return true,
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

        '=' => .EqlOp,

        '+' => .AddOp,
        '-' => .SubOp,
        '*' => .MulOp,
        '/' => .DivOp,
        '%' => .ModOp,

        else => return error.InvalidChar,
    };

    return .{ .kind = kind, .idx = idx.* };
}

pub fn getTextType(idx: usize, txt: []const u8) !Token {
    if (std.mem.eql(u8, txt, "import"))
        return .{ .idx = idx, .kind = .Import };
    if (std.mem.eql(u8, txt, "as"))
        return .{ .idx = idx, .kind = .As };
    if (std.mem.eql(u8, txt, "def"))
        return .{ .idx = idx, .kind = .Def };
    if (std.mem.eql(u8, txt, "int"))
        return .{ .idx = idx, .kind = .IntType };
    if (std.mem.eql(u8, txt, "float"))
        return .{ .idx = idx, .kind = .FloatType };
    if (std.mem.eql(u8, txt, "str"))
        return .{ .idx = idx, .kind = .StrType };
    if (std.mem.eql(u8, txt, "pub"))
        return .{ .idx = idx, .kind = .Public };
    if (std.mem.eql(u8, txt, "let"))
        return .{ .idx = idx, .kind = .Let };
    if (std.mem.eql(u8, txt, "return"))
        return .{ .idx = idx, .kind = .Return };

    return .{ .idx = idx, .kind = .{ .Identifier = txt } };
}
