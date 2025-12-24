const std = @import("std");
const Err = @import("errors.zig").LexError;

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
    MulOp,
    DivOp,
    ModOp,

    Unset,
};

pub const Token = struct {
    idx: usize,
    kind: TokenKind,

    pub fn init(idx: usize) @This() {
        return .{ .idx = idx, .kind = .Unset };
    }

    pub fn toStr(
        self: *const @This(),
        alloc: std.mem.Allocator,
    ) ![]const u8 {
        return switch (self.kind) {
            // .Identifier => |x| try alloc.dupe(u8, x),
            // .StrLiteral => |x| try alloc.dupe(u8, x),

            .Identifier => |x| try std.fmt.allocPrint(alloc, "[IDNT: {s}]", .{x}),
            .StrLiteral => |x| try std.fmt.allocPrint(alloc, "[STR: {s}]", .{x}),
            .IntLiteral => |x| try std.fmt.allocPrint(alloc, "{}", .{x}),
            .FloatLiteral => |x| try std.fmt.allocPrint(alloc, "{}", .{x}),
            .CharLiteral => |x| try std.fmt.allocPrint(alloc, "'{c}'", .{x}),

            .Import => try alloc.dupe(u8, "import"),
            .As => try alloc.dupe(u8, "as"),
            .Let => try alloc.dupe(u8, "let"),
            .Def => try alloc.dupe(u8, "def"),
            .Public => try alloc.dupe(u8, "pub"),
            .Return => try alloc.dupe(u8, "return"),

            .IntType => try alloc.dupe(u8, "int"),
            .StrType => try alloc.dupe(u8, "str"),
            .CharType => try alloc.dupe(u8, "char"),
            .FloatType => try alloc.dupe(u8, "float"),

            .Declarative => try alloc.dupe(u8, "@"),
            .MemberOp => try alloc.dupe(u8, "."),
            .StatEnd => try alloc.dupe(u8, ";"),
            .TypeOf => try alloc.dupe(u8, ":"),
            .ParenOpen => try alloc.dupe(u8, "("),
            .ParenClose => try alloc.dupe(u8, ")"),
            .BrackOpen => try alloc.dupe(u8, "["),
            .BrackClose => try alloc.dupe(u8, "]"),
            .BraceOpen => try alloc.dupe(u8, "{"),
            .BraceClose => try alloc.dupe(u8, "}"),

            .Comma => try alloc.dupe(u8, ","),

            .AddOp => try alloc.dupe(u8, "+"),
            .EqlOp => try alloc.dupe(u8, "="),
            .SubOp => try alloc.dupe(u8, "-"),
            .MulOp => try alloc.dupe(u8, "*"),
            .DivOp => try alloc.dupe(u8, "/"),
            .ModOp => try alloc.dupe(u8, "%"),

            .Unset => try alloc.dupe(u8, "<UNSET>"),
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
        return Err.Unknown;

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

        else => return Err.InvalidChar,
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
