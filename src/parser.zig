const std = @import("std");
const ast = @import("ast.zig");
const lexeme = @import("lexeme.zig");
const Err = @import("errors.zig").ParsError;
const printErr = @import("errors.zig").errParse;

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
            }
            self.idx += 1;
        }
        return mod;
    }

    pub fn parseDeclarative(self: *@This(), mod: *ast.Module) !void {
        self.idy += 1;
        const stat = self.statements.items[self.idx].items;
        if (self.idy >= stat.len)
            printErr(Err.ExpectedDecl, .{
                .idx = stat[self.idy - 1].idx,
                .fName = self.fName,
                .src = self.src,
            });
        if (stat[self.idy].kind == .Import) {
            var import: ast.Import = .{ .path = .empty, .alias = "" };
            self.idy += 1;
            if (self.idy >= stat.len)
                printErr(Err.ExpectedMod, .{
                    .idx = stat[self.idy - 1].idx,
                    .fName = self.fName,
                    .src = self.src,
                });
            switch (stat[self.idy].kind) {
                .Identifier => |s| try import.path.append(self.alloc, s),
                else => printErr(Err.InvalidMod, .{
                    .idx = stat[self.idy].idx,
                    .fName = self.fName,
                    .keyword = try stat[self.idy].toStr(self.alloc),
                    .src = self.src,
                }),
            }
            self.idy += 1;
            while (self.idy < stat.len and stat[self.idy].kind == .MemberOp) {
                self.idy += 1;
                if (self.idy >= stat.len)
                    printErr(Err.ExpectedMod, .{
                        .idx = stat[self.idy - 1].idx,
                        .fName = self.fName,
                        .src = self.src,
                    });

                switch (stat[self.idy].kind) {
                    .Identifier => |s| try import.path.append(self.alloc, s),
                    else => printErr(Err.InvalidMod, .{
                        .idx = stat[self.idy].idx,
                        .fName = self.fName,
                        .keyword = try stat[self.idy].toStr(self.alloc),
                        .src = self.src,
                    }),
                }
                self.idy += 1;
            }
            if (self.idy >= stat.len and import.path.items.len > 1)
                printErr(Err.ExpectedAlias, .{
                    .idx = stat[self.idy - 1].idx,
                    .fName = self.fName,
                    .src = self.src,
                });

            if (self.idy < stat.len) {
                switch (stat[self.idy].kind) {
                    .As => {
                        self.idy += 1;
                        if (self.idy >= stat.len) {
                            printErr(Err.ExpectedAlias, .{
                                .idx = stat[self.idy].idx,
                                .fName = self.fName,
                                .keyword = try stat[self.idy].toStr(self.alloc),
                                .src = self.src,
                            });
                        }
                        switch (stat[self.idy].kind) {
                            .Identifier => |s| {
                                import.alias = s;
                                self.idy += 1;
                            },
                            else => {
                                printErr(Err.ExpectedAlias, .{
                                    .idx = stat[self.idy].idx,
                                    .fName = self.fName,
                                    .src = self.src,
                                });
                            },
                        }
                    },
                    else => {
                        printErr(Err.InvalidToken, .{
                            .idx = stat[self.idy].idx,
                            .fName = self.fName,
                            .keyword = try stat[self.idy].toStr(self.alloc),
                            .src = self.src,
                        });
                    },
                }
            } else {
                import.alias = import.path.items[0];
            }
            if (self.idy < stat.len)
                printErr(Err.InvalidToken, .{
                    .idx = stat[self.idy].idx,
                    .fName = self.fName,
                    .keyword = try stat[self.idy].toStr(self.alloc),
                    .src = self.src,
                });
            try mod.*.imports.append(self.alloc, import);
        } else {
            printErr(Err.InvalidDecl, .{
                .idx = stat[self.idy].idx,
                .fName = self.fName,
                .keyword = try stat[self.idy].toStr(self.alloc),
                .src = self.src,
            });
        }
    }
};

const testing = std.testing;

test "parse import statements" {
    var lex = @import("lexer.zig").Lexer.init(testing.allocator, "",
        \\@import std;
        \\@import std.math as math;
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
