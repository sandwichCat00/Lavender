const std = @import("std");
const lexer = @import("lexer.zig");
const lexeme = @import("lexeme.zig");
const ast = @import("ast.zig");
const Parser = @import("parser.zig").Parser;

const CodeGen = struct {
    mod: ast.Module,
    src: []const u8,
    alloc: std.mem.Allocator,

    pub var builtInFuncs = [_]ast.DefDecl{
        .{
            .name = .{ .kind = .{ .Identifier = "print" }, .idx = 0 },
            .dtype = .VoidType,
            .varLen = true,
            .parameters = .empty,
            .statements = .empty,
        },
        .{
            .name = .{ .kind = .{ .Identifier = "println" }, .idx = 0 },
            .dtype = .VoidType,
            .varLen = true,
            .parameters = .empty,
            .statements = .empty,
        },

        .{
            .name = .{ .kind = .{ .Identifier = "input" }, .idx = 0 },
            .dtype = .StrType,
            .varLen = false,
            .parameters = .empty,
            .statements = .empty,
        },
        .{
            .name = .{ .kind = .{ .Identifier = "toInt" }, .idx = 0 },
            .dtype = .IntType,
            .varLen = true,
            .parameters = .empty,
            .statements = .empty,
        },
    };

    fn initBuiltInFunc(alloc: std.mem.Allocator) !void {
        for (&builtInFuncs) |*def| {
            switch (def.name.kind) {
                .Identifier => |s| {
                    if (std.mem.eql(u8, s, "input")) {
                        try def.parameters.append(
                            alloc,
                            .{ .identifier = .{
                                .idx = 0,
                                .kind = .{
                                    .Identifier = "prompt",
                                },
                            }, .type = .{ .idx = 0, .kind = .StrType } },
                        );
                    }
                },
                else => {},
            }
        }
    }

    fn isInteger(t: lexeme.TokenKind) bool {
        return t == .IntType or t == .CharType or t == .BoolType;
    }

    fn resultType(op: lexeme.TokenKind, l: lexeme.TokenKind, r: lexeme.TokenKind) lexeme.TokenKind {
        const L = promote(l);
        const R = promote(r);

        if (op.isEqlOp())
            return .VoidType;

        return switch (op) {
            .IsEqlOp, .IsGrterOp, .IsLessOp => .BoolType,
            else => if (L == .FloatType or R == .FloatType)
                .FloatType
            else
                .IntType,
        };
    }

    fn isNumeric(t: lexeme.TokenKind) bool {
        return isInteger(t) or t == .FloatType;
    }
    fn promote(t: lexeme.TokenKind) lexeme.TokenKind {
        if (t == .CharType or t == .BoolType) return .IntType;
        return t;
    }

    pub fn init(
        mod: ast.Module,
        src: []const u8,
        alloc: std.mem.Allocator,
    ) !@This() {
        const x: @This() = .{
            .mod = mod,
            .src = src,
            .alloc = alloc,
        };

        return x;
    }

    fn add(c: []const u8) void {
        std.debug.print("{s}", .{c});
    }

    pub fn genExpr(self: *@This()) []const u8 {
        _ = self;
    }

    fn sameType(a: lexeme.TokenKind, b: lexeme.TokenKind) bool {
        return @as(std.meta.Tag(lexeme.TokenKind), a) == @as(std.meta.Tag(lexeme.TokenKind), b);
    }

    fn isValidBinaryOp(op: lexeme.TokenKind, lhs: lexeme.TokenKind, rhs: lexeme.TokenKind) bool {
        const l = promote(lhs);
        const r = promote(rhs);

        return switch (op) {
            .AddOp, .SubOp, .MulOp, .DivOp => isNumeric(l) and isNumeric(r),

            .ModOp => isInteger(l) and isInteger(r),

            .IsEqlOp, .IsGrterOp, .IsLessOp => isNumeric(l) and isNumeric(r),

            .EqlOp, .AddEqlOp, .SubEqlOp, .MulEqlOp, .DivEqlOp, .ModEqlOp => {
                return (isInteger(l) and isInteger(r)) or (l == .StrType and r == .StrType);
            },
            else => false,
        };
    }

    fn checkDefCall(
        node: ast.AstNode,
        funLookupTable: std.ArrayList(ast.DefDecl),
        idfLookupTable: *std.ArrayList(struct { []const u8, lexeme.TokenKind }),
    ) !lexeme.TokenKind {
        for (funLookupTable.items) |fun| {
            switch (node.tok.kind) {
                .DefCall => |s| {
                    switch (fun.name.kind) {
                        .Identifier => |x| if (std.mem.eql(u8, s, x)) {
                            var idx: usize = 0;
                            if (fun.varLen) {
                                for (node.children.items) |args| {
                                    _ = try checkType(args, funLookupTable, idfLookupTable, false);
                                }
                                return fun.dtype;
                            }
                            if (node.children.items.len != fun.parameters.items.len) {
                                std.debug.print("{d} {d} {s}\n", .{ node.children.items.len, fun.parameters.items.len, x });
                                return error.ArgumentCountMismatch;
                            }
                            for (fun.parameters.items) |par| {
                                if (!sameType(promote(par.type.kind), promote(try checkType(
                                    node.children.items[idx],
                                    funLookupTable,
                                    idfLookupTable,
                                    false,
                                )))) {
                                    return error.InvalidArgumentType;
                                }
                                idx += 1;
                            }
                            return fun.dtype;
                        },
                        else => {},
                    }
                },
                else => {},
            }
        }
        std.debug.print("{s}\n", .{node.tok.toStr(std.heap.page_allocator)});
        // return .VoidType;
        return error.UnknownFunc;
    }

    fn checkType(node: ast.AstNode, funLookupTable: std.ArrayList(ast.DefDecl), idfLookupTable: *std.ArrayList(struct { []const u8, lexeme.TokenKind }), isLet: bool) error{
        UnknownIdentifier,
        InvalidExpression,
        ArgumentCountMismatch,
        UnknownFunc,
        InvalidArgumentType,
        InvalidTypedOperation,
        InvalidLValue,
    }!lexeme.TokenKind {
        switch (node.tok.kind) {
            .IntLiteral => return .IntType,
            .FloatLiteral => return .FloatType,
            .CharLiteral => return .CharType,
            .StrLiteral => return .StrType,
            .True, .False => return .BoolType,
            .VoidType => return .VoidType,
            .Identifier => |x| {
                std.debug.print("idf: {s}\n", .{x});
                if (isLet)
                    return .VoidType;
                for (idfLookupTable.items) |idf| {
                    if (std.mem.eql(u8, idf.@"0", x)) {
                        return idf.@"1";
                    }
                }
                std.debug.print("{s}", .{x});
                return error.UnknownIdentifier;
            },
            .DefCall => |x| {
                std.debug.print("def: {s}\n", .{x});
                return try checkDefCall(node, funLookupTable, idfLookupTable);
            },
            else => {},
        }
        if (node.tok.kind.isBinOp()) {
            if (node.tok.kind.isEqlOp()) {
                if (node.children.items[0].tok.kind != .Identifier) {
                    return error.InvalidLValue;
                }
                if (node.tok.kind != .EqlOp) {
                    if (node.tok.kind == .ModEqlOp and !isInteger(node.children.items[0].tok.kind)) {
                        return error.InvalidLValue;
                    } else if (!isNumeric(node.children.items[0].tok.kind)) {
                        return error.InvalidLValue;
                    }
                }
            }
            const l = try checkType(node.children.items[0], funLookupTable, idfLookupTable, isLet and node.tok.kind.isEqlOp());
            const r = try checkType(node.children.items[1], funLookupTable, idfLookupTable, false);

            if (isValidBinaryOp(node.tok.kind, l, r) or (isLet and node.tok.kind.isEqlOp())) {
                return resultType(node.tok.kind, l, r);
            } else {
                std.debug.print("{s} {s} {s}\n", .{ node.tok.toStr(std.heap.page_allocator), l.toStr(std.heap.page_allocator), r.toStr(std.heap.page_allocator) });
                return error.InvalidTypedOperation;
            }
        }
        node.print(0, testing.allocator);
        return error.InvalidExpression;
    }

    pub fn sanityCheck(self: *@This()) !void {
        var funList: std.ArrayList([]const u8) = .empty;
        defer funList.deinit(self.alloc);
        for (self.mod.functions.items) |func| {
            var funcName: []const u8 = "";
            switch (func.name.kind) {
                .Identifier => |s| funcName = s,
                else => {},
            }
            for (funList.items) |x| {
                if (std.mem.eql(u8, x, funcName)) {
                    return error.SameFuncName;
                }
            }
            var idfStack: std.ArrayList(struct { []const u8, lexeme.TokenKind }) = .empty;
            defer idfStack.deinit(self.alloc);
            for (func.parameters.items) |par| {
                var parName: []const u8 = "";
                switch (par.identifier.kind) {
                    .Identifier => |s| parName = s,
                    else => {},
                }
                for (idfStack.items) |p| {
                    if (std.mem.eql(u8, p.@"0", parName)) {
                        return error.SameParName;
                    }
                }
                try idfStack.append(self.alloc, .{ parName, par.type.kind });
            }
            for (func.statements.items) |stat| {
                switch (stat) {
                    .Exp => |node| _ = try checkType(node, self.mod.functions, &idfStack, false),
                    .Ret => |node| {
                        const x = try checkType(node, self.mod.functions, &idfStack, false);
                        if (!sameType(promote(x), promote(func.dtype))) {
                            if (isNumeric(x) and isNumeric(func.dtype))
                                continue;
                            return error.InvalidReturnType;
                        }
                    },
                    .Let => |node| {
                        _ = try checkType(node, self.mod.functions, &idfStack, true);
                        switch (node.children.items[0].tok.kind) {
                            .Identifier => |s| {
                                try idfStack.append(self.alloc, .{ s, try checkType(
                                    node.children.items[1],
                                    self.mod.functions,
                                    &idfStack,
                                    false,
                                ) });
                            },
                            else => return error.InvalidRValue,
                        }
                    },
                    else => {},
                }
            }

            try funList.append(self.alloc, funcName);
        }
    }

    pub fn gen(self: *@This()) void {
        for (self.mod.functions.items) |def| {
            add(".module\n");
            add(".fun ");
            add(def.name);
            add("\n");
        }
    }
};

const testing = std.testing;
test "import code gen" {
    const src =
        \\def add(a:int, b:int) int {
        \\  return b+ a + 1.1; 
        \\}
        \\def main() void {
        \\  let x = toInt(input("Enter No: "));
        \\  let y = toInt(input("Enter No: "));
        \\  println("add: {}", add(x,y));
        \\  return ;
        \\}
    ;

    var lex = lexer.Lexer.init(testing.allocator, "fin", src);
    try lex.lex();
    var stats = try lex.toStatements(testing.allocator);
    lex.deinit();

    var parser = Parser.init(testing.allocator, src, "fin", stats);
    var mod = try parser.parse();
    try CodeGen.initBuiltInFunc(testing.allocator);
    for (CodeGen.builtInFuncs) |def| {
        try mod.functions.append(testing.allocator, def);
    }
    // mod.print(testing.allocator);
    defer mod.deinit(testing.allocator);
    lexer.Lexer.deinitStatements(&stats, testing.allocator);

    var codeGen = try CodeGen.init(mod, src, testing.allocator);
    try codeGen.sanityCheck();
}
