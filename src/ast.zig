const std = @import("std");
const lexeme = @import("lexeme.zig");

pub const Import = struct {
    path: std.ArrayList([]const u8),
    alias: []const u8,
};

pub const AstNode = struct {
    tok: lexeme.Token,
    children: std.ArrayList(AstNode),

    pub fn deinit(self: *@This(), alloc: std.mem.Allocator) void {
        for (self.children.items) |*node| {
            node.deinit(alloc);
        }
        self.tok.deinit(alloc);
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

pub const Statement = union(enum) {
    Exp: AstNode,
    If: struct { condition: AstNode, stats: std.ArrayList(Statement), els: std.ArrayList(Statement) },
    While: struct { condition: AstNode, stats: std.ArrayList(Statement), els: std.ArrayList(Statement) },
    Ret: AstNode,
    Let: AstNode,
    Break: lexeme.Token,
    pub fn print(self: @This(), alloc: std.mem.Allocator) void {
        switch (self) {
            .Exp => |e| e.print(0, alloc),
            .If => |e| {
                std.debug.print("if: ", .{});
                e.condition.print(0, alloc);
                std.debug.print("....\n", .{});
                for (e.stats.items) |st| {
                    st.print(alloc);
                }
                std.debug.print("....\nelse\n....\n", .{});
                for (e.els.items) |st| {
                    st.print(alloc);
                }
                std.debug.print("....\n", .{});
            },
            .While => |e| {
                std.debug.print("while: ", .{});
                e.condition.print(0, alloc);
                std.debug.print("....\n", .{});
                for (e.stats.items) |st| {
                    st.print(alloc);
                }
                std.debug.print("....\nelse\n....\n", .{});
                for (e.els.items) |st| {
                    st.print(alloc);
                }
                std.debug.print("....\n", .{});
            },
            .Break => std.debug.print("Break\n", .{}),
            .Ret => |r| {
                std.debug.print("return ", .{});
                r.print(0, alloc);
            },
            .Let => |l| {
                std.debug.print("let ", .{});
                l.print(0, alloc);
            },
        }
    }

    pub fn deinit(self: *@This(), alloc: std.mem.Allocator) void {
        switch (self.*) {
            .If => |x| {
                var y = x;
                y.condition.deinit(alloc);
                for (y.stats.items) |*stt| {
                    stt.deinit(alloc);
                }
                y.stats.deinit(alloc);
                for (y.els.items) |*els| {
                    els.deinit(alloc);
                }
                y.els.deinit(alloc);
            },
            .While => |x| {
                var y = x;
                y.condition.deinit(alloc);
                for (y.stats.items) |*stt| {
                    stt.deinit(alloc);
                }
                y.stats.deinit(alloc);
                for (y.els.items) |*els| {
                    els.deinit(alloc);
                }
                y.els.deinit(alloc);
            },
            .Ret, .Let, .Exp => |x| {
                var y = x;
                y.deinit(alloc);
            },
            .Break => {},
        }
    }
};

pub const DefDecl = struct {
    name: lexeme.Token = .{ .idx = 0, .kind = .Unset },
    dtype: lexeme.TokenKind = .Unset,
    varLen: bool = false,
    parameters: std.ArrayList(struct { identifier: lexeme.Token, type: lexeme.Token }) = .empty,
    statements: std.ArrayList(Statement) = .empty,
    isBuiltIn: bool = false,
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
            for (fun.statements.items) |*stat| {
                stat.print(alloc);
                std.debug.print("--\n", .{});
            }
        }
    }

    pub fn deinit(self: *@This(), alloc: std.mem.Allocator) void {
        for (self.imports.items) |*imp| {
            for (imp.path.items) |idf| {
                alloc.free(idf);
            }
            alloc.free(imp.alias);
            imp.path.deinit(alloc);
        }
        self.imports.deinit(alloc);
        for (self.functions.items) |*fun| {
            if (fun.isBuiltIn == true)
                continue;
            fun.name.deinit(alloc);
            for (fun.parameters.items) |*st| {
                st.identifier.deinit(alloc);
                st.type.deinit(alloc);
            }
            fun.parameters.deinit(alloc);
            for (fun.statements.items) |*stat| {
                stat.deinit(alloc);
            }
            fun.statements.deinit(alloc);
        }
        self.functions.deinit(alloc);
    }
};
