const std = @import("std");
const ast = @import("ast.zig");
const lexeme = @import("lexeme.zig");
const err = @import("util.zig").err;

pub const Parser = struct {
    statements: std.ArrayList(std.ArrayList(lexeme.Token)),
    alloc: std.mem.Allocator,
    fName: []const u8,
    src: []const u8,
    idx: usize = 0,
    idy: usize = 0,
    pub fn init(alloc: std.mem.Allocator, src: []const u8, fName: []const u8, stats: std.ArrayList(std.ArrayList(lexeme.Token))) @This() {
        return .{
            .statements = stats,
            .alloc = alloc,
            .src = src,
            .fName = fName,
        };
    }

    pub fn parse(self: *@This()) !ast.Module {
        var mod: ast.Module = .{ .imports = .empty, .functions = .empty };
        const stats = self.statements.items;
        while (self.idx < stats.len) {
            self.idy = 0;
            if (stats[self.idx].items[0].kind == .Declarative) {
                try self.parseDeclarative(&mod);
            } else {
                err(
                    self.fName,
                    self.src,
                    stats[self.idx].items[0].idx,
                    "Unexpected token caught: {s}, expected 'def' or <declarative>",
                    .{try stats[self.idx].items[0].toStr(self.alloc)},
                );
            }
            self.idx += 1;
        }
        return mod;
    }

    pub fn parseDeclarative(self: *@This(), mod: *ast.Module) !void {
        self.idy += 1;
        const stat = self.statements.items[self.idx].items;
        if (self.idy >= stat.len)
            err(
                self.fName,
                self.src,
                stat[self.idy - 1].idx,
                "Expected declarative command, found <None>",
                .{},
            );

        if (stat[self.idy].kind == .Import) {
            var import: ast.Import = .{ .path = .empty, .alias = "" };
            self.idy += 1;
            if (self.idy >= stat.len)
                err(
                    self.fName,
                    self.src,
                    stat[self.idy - 1].idx,
                    "Expected module name, found <None>",
                    .{},
                );

            switch (stat[self.idy].kind) {
                .Identifier => |s| try import.path.append(self.alloc, s),
                else => err(
                    self.fName,
                    self.src,
                    stat[self.idy].idx,
                    "Invalid module name used {s}",
                    .{try stat[self.idy].toStr(self.alloc)},
                ),
            }
            self.idy += 1;
            while (self.idy < stat.len and stat[self.idy].kind == .MemberOp) {
                self.idy += 1;
                if (self.idy >= stat.len)
                    err(
                        self.fName,
                        self.src,
                        stat[self.idy - 1].idx,
                        "Expected sub-module name, found <None>",
                        .{},
                    );

                switch (stat[self.idy].kind) {
                    .Identifier => |s| try import.path.append(self.alloc, s),
                    else => err(
                        self.fName,
                        self.src,
                        stat[self.idy].idx,
                        "Invalid module name used: {s}",
                        .{try stat[self.idy].toStr(self.alloc)},
                    ),
                }
                self.idy += 1;
            }
            if (self.idy >= stat.len and import.path.items.len > 1)
                err(
                    self.fName,
                    self.src,
                    stat[self.idy - 1].idx,
                    "Expected alias for nested module imports",
                    .{},
                );

            if (self.idy < stat.len) {
                switch (stat[self.idy].kind) {
                    .As => {
                        self.idy += 1;
                        if (self.idy >= stat.len) {
                            err(
                                self.fName,
                                self.src,
                                stat[self.idy - 1].idx,
                                "Expected alias identifier as 'as'",
                                .{},
                            );
                        }
                        switch (stat[self.idy].kind) {
                            .Identifier => |s| {
                                import.alias = s;
                                self.idy += 1;
                            },
                            else => {
                                err(
                                    self.fName,
                                    self.src,
                                    stat[self.idy].idx,
                                    "Invalid alias identifier found: {s}",
                                    .{try stat[self.idy].toStr(self.alloc)},
                                );
                            },
                        }
                    },
                    else => {
                        err(
                            self.fName,
                            self.src,
                            stat[self.idy].idx,
                            "Invalid token used: {s}",
                            .{try stat[self.idy].toStr(self.alloc)},
                        );
                    },
                }
            } else {
                import.alias = import.path.items[0];
            }
            if (self.idy < stat.len)
                err(
                    self.fName,
                    self.src,
                    stat[self.idy].idx,
                    "Invalid token used: {s}",
                    .{try stat[self.idy].toStr(self.alloc)},
                );
            try mod.*.imports.append(self.alloc, import);
        } else {
            err(
                self.fName,
                self.src,
                stat[self.idy].idx,
                "Unknown declarative command used: {s}",
                .{try stat[self.idy].toStr(self.alloc)},
            );
        }
    }
};

const testing = std.testing;

test "parse import statements" {
    var lex = @import("lexer.zig").Lexer.init(testing.allocator, "",
        \\@import std;
        \\@import std.math as math;
        \\ def add(a: int, b: int) {}
    );
    defer lex.deinit();

    try lex.lex();
    var stats = try lex.toStatements(testing.allocator);

    defer {
        for (stats.items) |*stat| {
            for (stat.items) |tok| {
                switch (tok.kind) {
                    .StrLiteral => |s| testing.allocator.free(s),
                    else => {},
                }
            }
            stat.*.deinit(testing.allocator);
        }
        stats.deinit(testing.allocator);
    }
    var parser = Parser.init(testing.allocator, lex.src, lex.fName, stats);

    var mod = try parser.parse();
    for (mod.imports.items) |imp| {
        for (imp.path.items) |pat| {
            std.debug.print("{s} ", .{pat});
        }
        std.debug.print("-> {s}\n", .{imp.alias});
    }
    mod.deinit(testing.allocator);
}
