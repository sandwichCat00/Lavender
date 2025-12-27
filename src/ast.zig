const std = @import("std");
const lexeme = @import("lexeme.zig");

pub const Import = struct { path: std.ArrayList([]const u8), alias: []const u8 };

pub const AstNode = struct {
    tok: lexeme.Token,
    children: std.ArrayList(AstNode),
};

pub const DefDecl = struct {
    name: []const u8,
    parameters: std.ArrayList(struct { identifier: lexeme.Token, type: lexeme.Token }),
    statements: std.ArrayList(AstNode),

    pub fn init() @This() {
        return .{ .name = "", .statements = .empty, .parameters = .empty };
    }
};

pub const Module = struct {
    imports: std.ArrayList(Import),
    functions: std.ArrayList(DefDecl),
    pub fn deinit(self: *@This(), alloc: std.mem.Allocator) void {
        for (self.imports.items) |*imp| {
            imp.path.deinit(alloc);
        }
        self.imports.deinit(alloc);
        self.functions.deinit(alloc);
    }
};
