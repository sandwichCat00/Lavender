const std = @import("std");
const lexeme = @import("lexeme.zig");

pub const Import = struct {
    path: std.ArrayList([]const u8),
    alias: []const u8,
};

pub const DefCall = struct {
    callee: []const u8,
    parameters: std.ArrayList(AstNode),

    pub fn print(self: @This(), alloc: std.mem.Allocator) void {
        std.debug.print("{s}: ", .{self.callee});
        for (self.parameters.items) |par| {
            par.print(0, alloc);
        }
        std.debug.print("\n", .{});
    }

    pub fn deinit(self: *@This(), alloc: std.mem.Allocator) void {
        for (self.parameters.items) |*par| {
            par.deinit(alloc);
        }
        self.parameters.deinit(alloc);
    }
};

pub const AstNode = struct {
    tok: lexeme.Token,
    children: std.ArrayList(AstNode),

    pub fn deinit(self: *@This(), alloc: std.mem.Allocator) void {
        for (self.children.items) |*node| {
            node.deinit(alloc);
        }
        switch (self.tok.kind) {
            .DefCall => |def| {
                var par = def.parameters;
                for (par.items) |*parr| {
                    parr.deinit(alloc);
                }

                par.deinit(alloc);
            },
            else => {},
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

    pub fn print(self: *@This(), alloc: std.mem.Allocator) void {
        for (self.imports.items) |import| {
            for (import.path.items) |str| {
                std.debug.print("{s} ", .{str});
            }
            std.debug.print("-> {s}\n", .{import.alias});
        }

        for (self.functions.items) |fun| {
            const name = fun.name.toStr(alloc);
            defer alloc.free(name);
            std.debug.print("{s}: ", .{name});
            for (fun.parameters.items) |par| {
                const idf = par.identifier.toStr(alloc);
                defer alloc.free(idf);
                const typ = par.type.toStr(alloc);
                defer alloc.free(typ);
                std.debug.print("[{s}:{s}] ", .{ idf, typ });
            }
            std.debug.print("\n--\n", .{});
            for (fun.statements.items) |stat| {
                stat.print(0, alloc);
                std.debug.print("--\n", .{});
            }
        }
    }

    pub fn deinit(self: *@This(), alloc: std.mem.Allocator) void {
        for (self.imports.items) |*imp| {
            imp.path.deinit(alloc);
        }
        self.imports.deinit(alloc);
        for (self.functions.items) |*fun| {
            fun.parameters.deinit(alloc);
            for (fun.statements.items) |*stats| {
                stats.deinit(alloc);
            }
            fun.statements.deinit(alloc);
        }
        self.functions.deinit(alloc);
    }
};
