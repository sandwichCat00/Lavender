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
            .Identifier => defDecl.name = try stat[self.tokIdx].toOwned(self.alloc),
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
            paraName = try stat[self.tokIdx].toOwned(self.alloc);
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
            if (stat[self.tokIdx].kind.isType()) {
                defDecl.dtype = stat[self.tokIdx].kind;
            } else err(
                self.fName,
                self.src,
                stat[self.tokIdx].idx,
                "Expected return type, found '{s}'",
                .{stat[self.tokIdx].toStr(self.alloc)},
            );
        } else {
            err(
                self.fName,
                self.src,
                stat[self.tokIdx - 1].idx + 1,
                "Expected return type, found none",
                .{},
            );
        }
        self.tokIdx += 1;
        if (self.tokIdx != stat.len) {
            err(
                self.fName,
                self.src,
                stat[self.tokIdx - 1].idx,
                "Unexpected token '{s}'",
                .{stat[self.tokIdx].toStr(self.alloc)},
            );
        }
        self.statIdx += 1;
        defDecl.statements = try self.parseStatements();
        try mod.functions.append(self.alloc, defDecl);
        // std.debug.print("{s}\n", .{defDecl.name.toStr(self.alloc)});
    }

    fn pattParse(
        self: *@This(),
        ret: *std.ArrayList(ast.AstNode),
        startIdx: usize,
        prevPrc: u8,
    ) !ast.AstNode {
        if (startIdx >= ret.items.len) {
            err(
                self.fName,
                self.src,
                0,
                "Unknown error occured",
                .{},
            );
        }
        var lhs = ret.items[startIdx];
        if (lhs.tok.kind == .ParenOpen) {
            _ = ret.orderedRemove(startIdx);

            lhs = try self.pattParse(ret, startIdx, 0);

            if (startIdx + 1 >= ret.items.len or
                ret.items[startIdx + 1].tok.kind != .ParenClose)
                err(
                    self.fName,
                    self.src,
                    ret.items[startIdx + 1].tok.idx,
                    "Parenthesis is not closed properly",
                    .{},
                );

            _ = ret.orderedRemove(startIdx);
        }
        if (ret.items[startIdx].tok.kind.isUnmodifiedUniOp()) {
            var op = ret.orderedRemove(startIdx);

            op.tok.kind = switch (op.tok.kind) {
                .SubOp => .SignSubOp,
                else => {
                    err(
                        self.fName,
                        self.src,
                        0,
                        "Unknown error occured",
                        .{},
                    );
                    return error.Unknown;
                },
            };

            const operand = try self.pattParse(ret, startIdx, 255);

            try op.children.append(self.alloc, operand);
            lhs = op;
        }
        if (!lhs.tok.kind.isLiteral() and
            lhs.tok.kind != .DefCall and
            lhs.tok.kind != .Identifier and
            !(lhs.tok.kind.isBinOp() and lhs.children.items.len == 2) and
            !(lhs.tok.kind.isUniOp() and lhs.children.items.len == 1))
        {
            err(
                self.fName,
                self.src,
                0,
                "Invalid token found {s}",
                .{lhs.tok.toStr(self.alloc)},
            );
        }
        var idx = startIdx + 1;

        while (idx < ret.items.len) {
            const op = ret.items[idx];

            if (!op.tok.kind.isBinOp())
                break;

            const prc = op.tok.kind.prec();

            if (prc <= prevPrc)
                break;

            if (idx + 1 >= ret.items.len)
                err(
                    self.fName,
                    self.src,
                    0,
                    "Unexpected end of statement at {s}",
                    .{op.tok.toStr(self.alloc)},
                );

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

    pub fn parseDefCall(self: *@This()) error{ OutOfMemory, Unknown }!ast.AstNode {
        const stat = self.statements.items[self.statIdx].items;
        var defCall: ast.AstNode = .{
            .tok = .{
                .idx = stat[self.tokIdx].idx,
                .kind = .{ .DefCall = "" },
            },
            .children = .empty,
        };
        switch (stat[self.tokIdx].kind) {
            .Identifier => |s| defCall.tok.kind = .{ .DefCall = try self.alloc.dupe(u8, s) },
            else => {
                err(
                    self.fName,
                    self.src,
                    0,
                    "Unknown error occured",
                    .{},
                );
                return error.Unknown;
            },
        }
        self.tokIdx += 2;

        if (self.tokIdx >= stat.len)
            err(
                self.fName,
                self.src,
                stat[self.tokIdx - 2].idx,
                "Early end of statement",
                .{},
            );

        while (self.tokIdx < stat.len) {
            if (stat[self.tokIdx].kind == .ParenClose)
                break;
            const exp = try self.parseExpression(true);
            if (self.tokIdx > stat.len or (self.tokIdx == stat.len and
                stat[self.tokIdx - 1].kind != .ParenClose))
                err(
                    self.fName,
                    self.src,
                    stat[self.tokIdx - 1].idx,
                    "Early end of statement",
                    .{},
                );
            try defCall.children.append(self.alloc, exp);
            if (self.tokIdx < stat.len and stat[self.tokIdx].kind == .Comma) {
                self.tokIdx += 1;
                if (self.tokIdx > stat.len)
                    err(
                        self.fName,
                        self.src,
                        stat[self.tokIdx - 1].idx,
                        "Early end of statement",
                        .{},
                    );
            }
        }
        return defCall;
    }

    pub fn parseExpression(self: *@This(), subExp: bool) error{ OutOfMemory, Unknown }!ast.AstNode {
        var ret: std.ArrayList(ast.AstNode) = .empty;
        defer ret.deinit(self.alloc);
        const stat = self.statements.items[self.statIdx].items;
        const str = stat[self.tokIdx].toStr(self.alloc);
        defer self.alloc.free(str);
        var parenAmount: usize = 0;
        while (self.tokIdx < stat.len) {
            const tok = stat[self.tokIdx];
            if (subExp and tok.kind == .Comma)
                break;
            if (!(tok.kind == .Identifier or //
                tok.kind.isLiteral() or
                tok.kind.isBinOp() or
                tok.kind.isUnmodifiedUniOp() or
                tok.kind == .ParenOpen or
                tok.kind == .ParenClose))
            {
                err(
                    self.fName,
                    self.src,
                    tok.idx,
                    "Invalid token found {s}",
                    .{tok.toStr(self.alloc)},
                );
            }
            if (subExp and tok.kind == .ParenClose and parenAmount == 0) {
                break;
            } else if (subExp and tok.kind == .ParenClose) {
                parenAmount -= 1;
            } else if (subExp and tok.kind == .ParenOpen) {
                parenAmount += 1;
            }

            if (self.tokIdx < stat.len - 1 and stat[self.tokIdx].kind == .Identifier and stat[self.tokIdx + 1].kind == .ParenOpen) {
                const node = try self.parseDefCall();
                try ret.append(self.alloc, node);
            } else try ret.append(self.alloc, .{
                .tok = try tok.toOwned(self.alloc),
                .children = .empty,
            });
            self.tokIdx += 1;
        }

        const root = try self.pattParse(&ret, 0, 0);
        if ((!subExp and ret.items.len > 1) or (subExp and (ret.items.len > 2 or
            (ret.items.len == 2 and ret.items[1].tok.kind != .ParenClose))))
        {
            err(
                self.fName,
                self.src,
                stat[self.tokIdx].idx,
                "Invalid expression token {s}",
                .{stat[self.tokIdx].toStr(self.alloc)},
            );
        }

        return root;
    }

    pub fn parseStatements(self: *@This()) !std.ArrayList(ast.Statement) {
        var stats: std.ArrayList(ast.Statement) = .empty;
        self.statIdx += 1;
        while (self.statIdx < self.statements.items.len) {
            if (self.statements.items[self.statIdx].items[0].kind == .BraceClose) {
                return stats;
            }
            self.tokIdx = 0;
            const stat = self.statements.items[self.statIdx].items;
            const tok = stat[0];
            if (tok.kind == .Return) {
                self.tokIdx += 1;
                if (self.tokIdx >= stat.len) {
                    try stats.append(self.alloc, .{ .Ret = .{ .tok = .{ .idx = tok.idx, .kind = .VoidType }, .children = .empty } });
                } else {
                    try stats.append(self.alloc, .{ .Ret = try self.parseExpression(false) });
                }
            } else if (tok.kind == .Let) {
                self.tokIdx += 1;
                if (self.tokIdx >= stat.len) {
                    err(
                        self.fName,
                        self.src,
                        tok.idx,
                        "Early end of statement, {s}",
                        .{tok.toStr(self.alloc)},
                    );
                }
                const exp = try self.parseExpression(false);
                try stats.append(self.alloc, .{ .Let = exp });
            } else if (tok.kind == .If) {
                self.tokIdx += 1;
                if (self.tokIdx >= stat.len) {
                    err(
                        self.fName,
                        self.src,
                        tok.idx,
                        "Early end of statement, {s}",
                        .{tok.toStr(self.alloc)},
                    );
                }
                try stats.append(
                    self.alloc,
                    .{
                        .If = .{ .condition = try self.parseExpression(false), .stats = ifBreak: {
                            self.statIdx += 1;
                            break :ifBreak try self.parseStatements();
                        }, .els = ifEls: {
                            if (self.statIdx + 1 < self.statements.items.len) {
                                if (self.statements.items[self.statIdx + 1].items[0].kind == .Else) {
                                    self.statIdx += 2;
                                    if (self.statIdx >= self.statements.items.len) {
                                        err(
                                            self.fName,
                                            self.src,
                                            self.statements.items[self.statIdx + 1].items[0].idx,
                                            "Early end of statement, {s}",
                                            .{self.statements.items[self.statIdx + 1].items[0].toStr(self.alloc)},
                                        );
                                    }
                                    break :ifEls try self.parseStatements();
                                }
                            }
                            break :ifEls .empty;
                        } },
                    },
                );
            } else if (tok.kind == .While) {
                self.tokIdx += 1;
                if (self.tokIdx >= stat.len) {
                    err(
                        self.fName,
                        self.src,
                        tok.idx,
                        "Early end of statement, {s}",
                        .{tok.toStr(self.alloc)},
                    );
                }
                try stats.append(
                    self.alloc,
                    .{
                        .While = .{
                            .condition = try self.parseExpression(false), //
                            .stats = whileBreak: {
                                self.statIdx += 1;
                                break :whileBreak try self.parseStatements();
                            },
                            .els = whileEls: {
                                if (self.statIdx + 1 < self.statements.items.len) {
                                    if (self.statements.items[self.statIdx + 1].items[0].kind == .Else) {
                                        self.statIdx += 2;
                                        if (self.statIdx >= self.statements.items.len) {
                                            err(
                                                self.fName,
                                                self.src,
                                                self.statements.items[self.statIdx + 1].items[0].idx,
                                                "Early end of statement, {s}",
                                                .{self.statements.items[self.statIdx + 1].items[0].toStr(self.alloc)},
                                            );
                                        }
                                        break :whileEls try self.parseStatements();
                                    }
                                }
                                break :whileEls .empty;
                            },
                        },
                    },
                );
            } else if (tok.kind == .Break) {
                if (stat.len != 1) {
                    err(
                        self.fName,
                        self.src,
                        stat[1].idx,
                        "Invalid token found, {s}",
                        .{stat[1].toStr(self.alloc)},
                    );
                }
                try stats.append(self.alloc, .{ .Break = tok });
            } else {
                const x = try self.parseExpression(false);
                try stats.append(self.alloc, .{ .Exp = x });
            }
            self.statIdx += 1;
        }
        const stat = self.statements.items[self.statements.items.len - 1].items;
        err(
            self.fName,
            self.src,
            stat[stat.len - 1].idx,
            "Early end of module, {s}",
            .{stat[stat.len - 1].toStr(self.alloc)},
        );

        return error.ExpectedBrace;
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
                .Identifier => |s| try import.path.append(self.alloc, try self.alloc.dupe(u8, s)),
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
                    .Identifier => |s| try import.path.append(self.alloc, try self.alloc.dupe(u8, s)),
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
                                import.alias = try self.alloc.dupe(u8, s);
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
                import.alias = try self.alloc.dupe(u8, import.path.items[0]);
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
const Lexer = @import("lexer.zig").Lexer;

test "parse import statements" {
    var lex = Lexer.init(testing.allocator, "",
        \\@import std;
        \\@import std.math as math;
    );

    try lex.lex();

    var stats = try lex.toStatements(testing.allocator);
    defer Lexer.deinitStatements(&stats, testing.allocator);

    var parser = Parser.init(testing.allocator, lex.src, lex.fName, stats);

    var mod = try parser.parse();
    lex.deinit();

    // mod.print(testing.allocator);
    mod.deinit(testing.allocator);
}

test "parse expression" {
    var lex = @import("lexer.zig").Lexer.init(testing.allocator, "", "((a + b) * (c - d) / 1) + ---((x % y) /    -(m - n))       ;  ");

    try lex.lex();
    var stats = try lex.toStatements(testing.allocator);
    defer Lexer.deinitStatements(&stats, testing.allocator);

    var parser = Parser.init(testing.allocator, lex.src, lex.fName, stats);
    var mod = try parser.parseExpression(false);
    lex.deinit();

    // mod.print(0, testing.allocator);
    mod.deinit(testing.allocator);
}

test "parse function call" {
    var lex = @import("lexer.zig").Lexer.init(
        testing.allocator,
        "",
        "print(30+10,10) + 10 + x()",
    );

    try lex.lex();
    var stats = try lex.toStatements(testing.allocator);
    lex.deinit();

    defer Lexer.deinitStatements(&stats, testing.allocator);

    var parser = Parser.init(testing.allocator, lex.src, lex.fName, stats);
    var mod = try parser.parseExpression(false);

    // mod.print(0, testing.allocator);
    mod.deinit(testing.allocator);
}

test "parse module" {
    var lex = @import("lexer.zig").Lexer.init(testing.allocator, "",
        \\@import std;
        \\@import std.math as math;
        \\def add(a: int, b: int) int {
        \\ return a + b;
        \\}
        \\def main() int {
        \\ print("addition: ",add(5,6));
        \\ if (5 < 3) {
        \\  print(5);
        \\ } 
        \\ else {
        \\ if(5 > 10) {
        \\   println(10);
        \\  }
        \\else {
        \\   println(3);
        \\  }
        \\ }
        \\ let i = 10;
        \\ while (true) {
        \\  println(i);
        \\  if (i == 0) {break;}
        \\  i -= 1;
        \\ }
        \\ return 0;
        \\}
    );

    try lex.lex();

    var stats = try lex.toStatements(testing.allocator);
    lex.deinit();
    // for (stats.items) |stat| {
    //     for (stat.items) |tok| {
    //         std.debug.print("{s} ", .{tok.toStr(std.heap.page_allocator)});
    //     }
    //     std.debug.print("\n", .{});
    // }

    var parser = Parser.init(testing.allocator, lex.src, lex.fName, stats);

    var mod = try parser.parse();
    Lexer.deinitStatements(&stats, testing.allocator);

    mod.deinit(testing.allocator);
}
