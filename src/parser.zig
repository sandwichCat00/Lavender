const std = @import("std");
const ast = @import("ast.zig");
const lexeme = @import("lexeme.zig");
const err = @import("util.zig").err;

pub const Parser = struct {
    statements: std.ArrayList(std.ArrayList(lexeme.Token)),
    alloc: std.mem.Allocator,
    fName: []const u8,
    src: []const u8,
    statIdx: usize = 0,
    tokIdx: usize = 0,
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
        while (self.statIdx < stats.len) {
            self.tokIdx = 0;
            if (stats[self.statIdx].items[0].kind == .Declarative) {
                try self.parseDeclarative(&mod);
            } else if (stats[self.statIdx].items[0].kind == .Def) {
                try self.parseDef(&mod);
            } else {
                err(
                    self.fName,
                    self.src,
                    stats[self.statIdx].items[0].idx,
                    "Unexpected token caught: {s}, expected 'def' or <declarative>",
                    .{stats[self.statIdx].items[0].toStr(self.alloc)},
                );
            }
            self.statIdx += 1;
        }
        return mod;
    }

    pub fn parseDef(self: *@This(), mod: *ast.Module) !void {
        const stat = self.statements.items[self.statIdx].items;
        self.tokIdx += 1;
        if (self.tokIdx >= stat.len) {
            err(
                self.fName,
                self.src,
                stat[self.tokIdx - 1].idx,
                "Early end of statement: expected function name",
                .{},
            );
        }
        var defDecl = ast.DefDecl.init();
        switch (stat[self.tokIdx].kind) {
            .Identifier => defDecl.name = stat[self.tokIdx],
            else => err(
                self.fName,
                self.src,
                stat[self.tokIdx].idx,
                "Invalid function name: '{s}'",
                .{stat[self.tokIdx].toStr(self.alloc)},
            ),
        }
        self.tokIdx += 1;
        if (self.tokIdx >= stat.len) {
            err(
                self.fName,
                self.src,
                stat[self.tokIdx - 1].idx,
                "Early end of statement: expected '('",
                .{},
            );
        } else if (stat[self.tokIdx].kind != .ParenOpen) {
            err(
                self.fName,
                self.src,
                stat[self.tokIdx].idx,
                "Expected '(', found '{s}'",
                .{stat[self.tokIdx].toStr(self.alloc)},
            );
        }
        self.tokIdx += 1;
        while (self.tokIdx < stat.len and stat[self.tokIdx].kind != .ParenClose) {
            var paraName: lexeme.Token = .{ .idx = 0, .kind = .Unset };
            var paraType: lexeme.Token = .{ .idx = 0, .kind = .Unset };
            if (stat[self.tokIdx].kind != .Identifier) {
                err(
                    self.fName,
                    self.src,
                    stat[self.tokIdx].idx,
                    "Expected parameter name, found '{s}'",
                    .{stat[self.tokIdx].toStr(self.alloc)},
                );
            }
            paraName = stat[self.tokIdx];
            self.tokIdx += 1;

            if (self.tokIdx >= stat.len) {
                err(
                    self.fName,
                    self.src,
                    stat[self.tokIdx - 1].idx,
                    "Early end of statement: expected ':'",
                    .{},
                );
            } else if (stat[self.tokIdx].kind != .TypeOf) {
                err(
                    self.fName,
                    self.src,
                    stat[self.tokIdx].idx,
                    "Expected ':', found '{s}'",
                    .{stat[self.tokIdx].toStr(self.alloc)},
                );
            }

            self.tokIdx += 1;

            if (self.tokIdx >= stat.len) {
                err(
                    self.fName,
                    self.src,
                    stat[self.tokIdx - 1].idx,
                    "Early end of statement: expected parameter type",
                    .{},
                );
            } else if (!stat[self.tokIdx].kind.isType()) {
                err(
                    self.fName,
                    self.src,
                    stat[self.tokIdx].idx,
                    "Expected parameter type, found '{s}'",
                    .{stat[self.tokIdx].toStr(self.alloc)},
                );
            }
            paraType = stat[self.tokIdx];
            try defDecl.parameters.append(self.alloc, .{ .identifier = paraName, .type = paraType });

            self.tokIdx += 1;

            if (self.tokIdx >= stat.len) {
                err(
                    self.fName,
                    self.src,
                    stat[self.tokIdx - 1].idx,
                    "Early end of statement: expected ')'",
                    .{},
                );
            } else if (stat[self.tokIdx].kind == .Comma) {
                self.tokIdx += 1;
            } else if (stat[self.tokIdx].kind != .ParenClose) {
                err(
                    self.fName,
                    self.src,
                    stat[self.tokIdx].idx,
                    "Expected ')', found '{s}'",
                    .{stat[self.tokIdx].toStr(self.alloc)},
                );
            }
        }
        if (self.tokIdx >= stat.len) {
            err(
                self.fName,
                self.src,
                stat[self.tokIdx - 1].idx,
                "Early end of statement: expected ')'",
                .{},
            );
        }
        self.tokIdx += 1;

        if (self.tokIdx != stat.len) {
            err(
                self.fName,
                self.src,
                stat[self.tokIdx].idx,
                "Expected ')', found '{s}'",
                .{stat[self.tokIdx].toStr(self.alloc)},
            );
        }
        self.statIdx += 1;
        try mod.functions.append(self.alloc, defDecl);
        try self.parseStatements(mod);
    }

    fn pattParse(
        self: *@This(),
        ret: *std.ArrayList(ast.AstNode),
        startIdx: usize,
        prevPrc: u8,
    ) !ast.AstNode {
        if (startIdx >= ret.items.len)
            return error.Invalid;

        var lhs = ret.items[startIdx];
        if (lhs.tok.kind == .ParenOpen) {
            _ = ret.orderedRemove(startIdx);

            lhs = try self.pattParse(ret, startIdx, 0);

            if (startIdx + 1 >= ret.items.len or
                ret.items[startIdx + 1].tok.kind != .ParenClose)
                return error.MissingParenClose;

            _ = ret.orderedRemove(startIdx);
        }
        if (ret.items[startIdx].tok.kind.isUnmodifiedUniOp()) {
            var op = ret.orderedRemove(startIdx);

            op.tok.kind = switch (op.tok.kind) {
                .SubOp => .SignSubOp,
                else => return error.Unknown,
            };

            const operand = try self.pattParse(ret, startIdx, 255);

            try op.children.append(self.alloc, operand);
            lhs = op;
        }
        if (!lhs.tok.kind.isLiteral() and
            lhs.tok.kind != .Identifier and
            !(lhs.tok.kind.isBinOp() and lhs.children.items.len == 2) and
            !(lhs.tok.kind.isUniOp() and lhs.children.items.len == 1))
            return error.InvalidTok;

        var idx = startIdx + 1;

        while (idx < ret.items.len) {
            const op = ret.items[idx];

            if (!op.tok.kind.isBinOp())
                break;

            const prc = op.tok.kind.prec();

            if (prc <= prevPrc)
                break;

            if (idx + 1 >= ret.items.len)
                return error.InvalidTok;

            const rhs = try self.pattParse(ret, idx + 1, prc);

            var node: ast.AstNode = .{
                .tok = op.tok,
                .children = .empty,
            };
            try node.children.append(self.alloc, lhs);
            try node.children.append(self.alloc, rhs);

            ret.items[startIdx] = node;

            _ = ret.orderedRemove(startIdx + 1);
            _ = ret.orderedRemove(startIdx + 1);

            lhs = node;
            idx = startIdx + 1;
        }

        return lhs;
    }

    pub fn parseExpression(self: *@This(), mod: *ast.Module) !ast.AstNode {
        _ = mod;

        var ret: std.ArrayList(ast.AstNode) = .empty;
        defer ret.deinit(self.alloc);

        for (self.statements.items[self.statIdx].items) |tok| {
            try ret.append(self.alloc, .{
                .tok = tok,
                .children = .empty,
            });
        }

        const root = try self.pattParse(&ret, 0, 0);

        if (ret.items.len != 1)
            return error.InvalidExpression;

        return root;
    }

    pub fn parseStatements(self: *@This(), mod: *ast.Module) !void {
        _ = mod;
        while (self.statIdx < self.statements.items.len) {
            if (self.statements.items[self.statIdx].items[0].kind == .BraceClose) {
                self.statIdx += 1;
                return;
            }
            self.statIdx += 1;
        }
    }

    pub fn parseDeclarative(self: *@This(), mod: *ast.Module) !void {
        self.tokIdx += 1;
        const stat = self.statements.items[self.statIdx].items;
        if (self.tokIdx >= stat.len)
            err(
                self.fName,
                self.src,
                stat[self.tokIdx - 1].idx,
                "Early end of statement, expected declarative command",
                .{},
            );

        if (stat[self.tokIdx].kind == .Import) {
            var import: ast.Import = .{ .path = .empty, .alias = "" };
            self.tokIdx += 1;
            if (self.tokIdx >= stat.len)
                err(
                    self.fName,
                    self.src,
                    stat[self.tokIdx - 1].idx,
                    "Early end of statement, expected module name",
                    .{},
                );

            switch (stat[self.tokIdx].kind) {
                .Identifier => |s| try import.path.append(self.alloc, s),
                else => err(
                    self.fName,
                    self.src,
                    stat[self.tokIdx].idx,
                    "Invalid module name: {s}",
                    .{stat[self.tokIdx].toStr(self.alloc)},
                ),
            }
            self.tokIdx += 1;
            while (self.tokIdx < stat.len and stat[self.tokIdx].kind == .MemberOp) {
                self.tokIdx += 1;
                if (self.tokIdx >= stat.len)
                    err(
                        self.fName,
                        self.src,
                        stat[self.tokIdx - 1].idx,
                        "Early end of statement, expected sub-module name",
                        .{},
                    );

                switch (stat[self.tokIdx].kind) {
                    .Identifier => |s| try import.path.append(self.alloc, s),
                    else => err(
                        self.fName,
                        self.src,
                        stat[self.tokIdx].idx,
                        "Invalid module name: {s}",
                        .{stat[self.tokIdx].toStr(self.alloc)},
                    ),
                }
                self.tokIdx += 1;
            }
            if (self.tokIdx >= stat.len and import.path.items.len > 1)
                err(
                    self.fName,
                    self.src,
                    stat[self.tokIdx - 1].idx,
                    "Expected alias for nested module imports",
                    .{},
                );

            if (self.tokIdx < stat.len) {
                switch (stat[self.tokIdx].kind) {
                    .As => {
                        self.tokIdx += 1;
                        if (self.tokIdx >= stat.len) {
                            err(
                                self.fName,
                                self.src,
                                stat[self.tokIdx - 1].idx,
                                "Early end of statement, expected alias identifier",
                                .{},
                            );
                        }
                        switch (stat[self.tokIdx].kind) {
                            .Identifier => |s| {
                                import.alias = s;
                                self.tokIdx += 1;
                            },
                            else => {
                                err(
                                    self.fName,
                                    self.src,
                                    stat[self.tokIdx].idx,
                                    "Invalid alias identifier found: {s}",
                                    .{stat[self.tokIdx].toStr(self.alloc)},
                                );
                            },
                        }
                    },
                    else => {
                        err(
                            self.fName,
                            self.src,
                            stat[self.tokIdx].idx,
                            "Invalid token used: {s}",
                            .{stat[self.tokIdx].toStr(self.alloc)},
                        );
                    },
                }
            } else {
                import.alias = import.path.items[0];
            }
            if (self.tokIdx < stat.len)
                err(
                    self.fName,
                    self.src,
                    stat[self.tokIdx].idx,
                    "Invalid token used: {s}",
                    .{stat[self.tokIdx].toStr(self.alloc)},
                );
            try mod.*.imports.append(self.alloc, import);
        } else {
            err(
                self.fName,
                self.src,
                stat[self.tokIdx].idx,
                "Unknown declarative command used: {s}",
                .{stat[self.tokIdx].toStr(self.alloc)},
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
    // for (mod.imports.items) |imp| {
    //     for (imp.path.items) |pat| {
    //         std.debug.print("{s} ", .{pat});
    //     }
    //     std.debug.print("-> {s}\n", .{imp.alias});
    // }
    // for (mod.functions.items) |defDecl| {
    //     const name = defDecl.name.toStr(testing.allocator);
    //     defer testing.allocator.free(name);
    //     std.debug.print("fnName: {s}\n", .{name});
    //     for (defDecl.parameters.items) |val| {
    //         const id = val.identifier.toStr(testing.allocator);
    //         const typ = val.type.toStr(testing.allocator);
    //         defer testing.allocator.free(id);
    //         defer testing.allocator.free(typ);
    //         std.debug.print("--Para: {s} {s}\n", .{ id, typ });
    //     }
    // }

    mod.deinit(testing.allocator);
}

test "parse expression" {
    var lex = @import("lexer.zig").Lexer.init(testing.allocator, "", "((a + b) * (c - d) / 1) + ---((x % y) / -(m - n));");
    // var lex = @import("lexer.zig").Lexer.init(testing.allocator, "", "---a;");
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

    var mod = try parser.parseExpression(undefined);
    mod.print(0, testing.allocator);
    mod.deinit(testing.allocator);
}
