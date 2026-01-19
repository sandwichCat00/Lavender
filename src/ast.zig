const std = @import("std");
const lexeme = @import("lexeme.zig");

pub const Import = struct { path: std.ArrayList([]const u8), alias: []const u8 };

pub const AstNode = struct {
    tok: lexeme.Token,
    children: std.ArrayList(AstNode),

    pub fn deinit(self: *@This(), alloc: std.mem.Allocator) void {
        for (self.children.items) |*node| {
            node.deinit(alloc);
        }
        self.children.deinit(alloc);
    }

    pub fn print(self: @This(), lev: u8, alloc: std.mem.Allocator) void {
        for (0..lev) |x| {
            _ = x;
            std.debug.print(".", .{});
        }
        const s = self.tok.toStr(alloc);
        defer alloc.free(s);
        std.debug.print("{s}\n", .{s});

        for (self.children.items) |child|
            child.print(lev + 1, alloc);
    }
};

pub const DefDecl = struct {
    name: lexeme.Token,
    parameters: std.ArrayList(struct { identifier: lexeme.Token, type: lexeme.Token }),
    statements: std.ArrayList(AstNode),

    pub fn init() @This() {
        return .{ .name = .{ .idx = 0, .kind = .Unset }, .statements = .empty, .parameters = .empty };
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
        for (self.functions.items) |*fun| {
            fun.parameters.deinit(alloc);
            fun.statements.deinit(alloc);
        }
        self.functions.deinit(alloc);
    }
};
