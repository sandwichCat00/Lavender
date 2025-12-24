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
