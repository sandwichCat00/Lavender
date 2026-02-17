const std = @import("std");
const lexer = @import("lexer.zig");
const lexeme = @import("lexeme.zig");
const ast = @import("ast.zig");
const Parser = @import("parser.zig").Parser;
const builtin = @import("builtin.zig");

pub const OPCode = enum(u8) {
    Add = 0,
    Sub = 1,
    Div = 2,
    Mul = 3,
    Mod = 4,
    Eql = 5,
    Gtr = 6,
    Les = 7,
    GtrEql = 8,
    LesEql = 9,
    NotEql = 10,

    PushInt = 17,
    PushFloat = 18,
    Pop = 19,

    DefInt = 21,
    DefFloat = 22,
    DefStr = 23,
    Undef = 24,

    Jmp = 30,
    JmpIfZero = 31,

    Call = 54,
    Ret = 55,
};
pub const DataType = enum(u8) {
    Int,
    Float,
    Str,
};

pub const ModuleIR = struct {
    funcTable: std.ArrayList(struct { usize, []const u8 }) = .empty,
    mainIdx: usize = 0,
    constPool: std.ArrayList(u8) = .empty,
    instructions: std.ArrayList(u8) = .empty,

    pub fn print(self: @This()) !void {
        std.debug.print("# fn table:\n", .{});
        var funIdx = builtin.BuiltInFuncs.defs.items.len;
        while (funIdx < self.funcTable.items.len) {
            const fun = self.funcTable.items[funIdx];
            std.debug.print("{s} : {x:0>4} -> {d}\n", .{ fun.@"1", fun.@"0", funIdx });
            funIdx += 1;
        }
        std.debug.print("\n# const table:\n", .{});
        std.debug.print("{x:0>4}: ", .{0});
        for (self.constPool.items, 0..) |cIdx, idx| {
            if (cIdx == 0)
                std.debug.print("\n{x:0>4}: ", .{idx + 1});
            std.debug.print("{c}", .{cIdx});
        }
        std.debug.print("\n\n# instructions:\n", .{});
        var idx: usize = 0;
        const insts = self.instructions.items;
        while (idx < insts.len) {
            const opCode: OPCode = @enumFromInt(insts[idx]);
            std.debug.print("{x:0>4}: ", .{idx});
            switch (opCode) {
                // Arithmetic (no operands)
                .Add => std.debug.print("Add\n", .{}),
                .Sub => std.debug.print("Sub\n", .{}),
                .Div => std.debug.print("Div\n", .{}),
                .Mul => std.debug.print("Mul\n", .{}),
                .Mod => std.debug.print("Mod\n", .{}),
                .Eql => std.debug.print("Eql\n", .{}),
                .Gtr => std.debug.print("Gtr\n", .{}),
                .Les => std.debug.print("Les\n", .{}),
                .GtrEql => std.debug.print("GtrEql\n", .{}),
                .LesEql => std.debug.print("LesEql\n", .{}),
                .NotEql => std.debug.print("NotEql\n", .{}),

                // Push instructions
                .PushInt => {
                    idx += 1;
                    const addressMode = insts[idx];

                    idx += 1;
                    var bytes = insts[idx .. idx + 8];
                    const op: u64 = std.mem.readInt(u64, bytes[0..8], .little);
                    idx += 7;

                    if (addressMode == 0)
                        std.debug.print("Pushi64  mode={d} value={d}\n", .{ addressMode, op })
                    else
                        std.debug.print("Pushi64  mode={d} value={x}\n", .{ addressMode, op });
                },
                .PushFloat => {
                    idx += 1;
                    const addressMode = insts[idx];

                    idx += 1;
                    const bytes = insts[idx .. idx + 8];
                    const op: u64 = std.mem.readInt(u64, bytes[0..8], .little);
                    idx += 7;

                    const val: f64 = @bitCast(op);
                    if (addressMode == 0)
                        std.debug.print(
                            "PushFloat mode={d} value={d}\n",
                            .{ addressMode, val },
                        )
                    else
                        std.debug.print(
                            "PushFloat mode={d} value={d}\n",
                            .{ addressMode, op },
                        );
                },

                .JmpIfZero => {
                    idx += 1;
                    const bytes = insts[idx .. idx + 8];
                    const op: u64 = std.mem.readInt(u64, bytes[0..8], .little);
                    idx += 7;

                    std.debug.print("JmpIfZero {x}\n", .{op});
                },

                .Jmp => {
                    idx += 1;
                    const bytes = insts[idx .. idx + 8];
                    const op: u64 = std.mem.readInt(u64, bytes[0..8], .little);
                    idx += 7;

                    std.debug.print("Zmp {x}\n", .{op});
                },
                // Stack / control
                .Pop => {
                    idx += 1;
                    const bytes = insts[idx .. idx + 8];
                    const op: u64 = std.mem.readInt(u64, bytes[0..8], .little);
                    idx += 7;

                    std.debug.print("Pop {d}\n", .{op});
                },
                .Call => {
                    idx += 1;
                    const bytes = insts[idx .. idx + 8];
                    const op: u64 = std.mem.readInt(u64, bytes[0..8], .little);
                    idx += 7;

                    std.debug.print(
                        "Call    addr={d}\n",
                        .{op},
                    );
                },
                .Ret => std.debug.print("Ret\n", .{}),

                // Definitions
                .DefInt => std.debug.print("DefInt\n", .{}),
                .DefFloat => std.debug.print("DefFloat\n", .{}),
                .DefStr => std.debug.print("DefStr\n", .{}),
                .Undef => std.debug.print("Undef\n", .{}),
            }

            idx += 1;
        }
    }
};

// WARN:
// 0. immediate, 1. Data Addr, 2. Const Addr
// for lavb files
// 8 bytes -> functionListSize
// x bytes -> [ 8 bytes address ]
// 8 bytes -> main idx (gotta "- 1" as idx 0 = no main)
// 8 bytes -> const poll size
// x bytes -> const poll
// x bytes -> instructions
pub const CodeGen = struct {
    mod: ast.Module,
    src: []const u8,
    alloc: std.mem.Allocator,
    moduleIr: ModuleIR = .{},

    idfLookUpTable: std.ArrayList(struct { []const u8, DataType }) = .empty,
    funcIdfs: usize = 0,
    pub fn printToFile(self: *@This(), fname: []const u8, path: []const u8) !void {
        const cwd = std.fs.cwd();
        try cwd.makePath(path);
        const x = try std.fmt.allocPrint(self.alloc, "{s}/{s}b", .{
            std.mem.trimRight(u8, path, "/"),
            std.fs.path.basename(fname),
        });
        defer self.alloc.free(x);
        const outFile = try cwd.createFile(x, .{});
        defer outFile.close();
        var idx = self.moduleIr.funcTable.items.len - builtin.BuiltInFuncs.defs.items.len;
        try outFile.writeAll(std.mem.asBytes(&idx));

        var mainIdx: usize = 0;
        idx = builtin.BuiltInFuncs.defs.items.len;
        while (idx < self.moduleIr.funcTable.items.len) {
            const fun = self.moduleIr.funcTable.items[idx];
            try outFile.writeAll(std.mem.asBytes(&fun.@"0"));
            if (std.mem.eql(u8, fun.@"1", "main")) {
                mainIdx = idx + 1;
            }
            idx += 1;
        }
        try outFile.writeAll(std.mem.asBytes(&mainIdx));
        try outFile.writeAll(std.mem.asBytes(&self.moduleIr.constPool.items.len));
        try outFile.writeAll(self.moduleIr.constPool.items);
        const insts = self.moduleIr.instructions.items;
        try outFile.writeAll(insts);
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
        var x: @This() = .{
            .mod = mod,
            .src = src,
            .alloc = alloc,
        };
        for (builtin.BuiltInFuncs.defs.items) |def| {
            try x.mod.functions.append(alloc, def.@"0");
            switch (def.@"0".name.kind) {
                .Identifier => |defName| try x.moduleIr.funcTable.append(alloc, .{ 0, defName }),
                else => {},
            }
        }

        return x;
    }

    pub fn deinit(self: *@This()) void {
        self.idfLookUpTable.deinit(self.alloc);
        self.moduleIr.constPool.deinit(self.alloc);
        self.moduleIr.instructions.deinit(self.alloc);
        self.moduleIr.funcTable.deinit(self.alloc);
    }

    fn add(self: *@This(), opCode: OPCode, op: u64, addressMode: u8) !void {
        switch (opCode) {
            .Add, .Sub, .Div, .Mod, .Mul, .Eql, .Gtr, .Les, .GtrEql, .LesEql, .NotEql => {
                try self.moduleIr.instructions.append(self.alloc, @intFromEnum(opCode));
            },
            .JmpIfZero => {
                try self.moduleIr.instructions.append(self.alloc, @intFromEnum(opCode));
                try self.moduleIr.instructions.appendSlice(self.alloc, std.mem.asBytes(&op));
            },
            .Jmp => {
                try self.moduleIr.instructions.append(self.alloc, @intFromEnum(opCode));
                try self.moduleIr.instructions.appendSlice(self.alloc, std.mem.asBytes(&op));
            },

            .PushInt, .PushFloat => {
                try self.moduleIr.instructions.append(self.alloc, @intFromEnum(opCode));
                try self.moduleIr.instructions.append(self.alloc, addressMode);
                try self.moduleIr.instructions.appendSlice(self.alloc, std.mem.asBytes(&op));
            },

            // Stack / control
            .Pop => {
                try self.moduleIr.instructions.append(self.alloc, @intFromEnum(OPCode.Pop));
                try self.moduleIr.instructions.appendSlice(self.alloc, std.mem.asBytes(&op));
            },
            .Call => {
                try self.moduleIr.instructions.append(self.alloc, @intFromEnum(OPCode.Call));
                try self.moduleIr.instructions.appendSlice(self.alloc, std.mem.asBytes(&op));
            },
            .Ret => {
                try self.moduleIr.instructions.append(self.alloc, @intFromEnum(OPCode.Ret));
            },

            // Definitions
            .DefInt, .DefFloat, .DefStr, .Undef => {
                try self.moduleIr.instructions.append(self.alloc, @intFromEnum(opCode));
            },
        }
    }
    fn addConst(self: *@This(), c: []const u8) !u64 {
        const x = self.moduleIr.constPool.items.len;
        try self.moduleIr.constPool.appendSlice(self.alloc, c);
        try self.moduleIr.constPool.append(self.alloc, 0);
        return x;
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
                return (isNumeric(l) and isNumeric(r)) or (l == .StrType and r == .StrType);
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
                                const rhsType = promote(try checkType(
                                    node.children.items[idx],
                                    funLookupTable,
                                    idfLookupTable,
                                    false,
                                ));
                                if (!sameType(promote(par.type.kind), rhsType) and !(isNumeric(par.type.kind) and isNumeric(rhsType))) {
                                    std.debug.print("{s} {s} {s} {s}\n", .{
                                        s,
                                        x,
                                        par.type.toStr(std.heap.page_allocator),
                                        rhsType.toStr(std.heap.page_allocator),
                                    });
                                    for (idfLookupTable.items) |value| {
                                        std.debug.print("{s} {s}\n", .{ value.@"0", value.@"1".toStr(std.heap.page_allocator) });
                                    }

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
        IdentifierRedefined,
    }!lexeme.TokenKind {
        switch (node.tok.kind) {
            .IntLiteral => return .IntType,
            .FloatLiteral => return .FloatType,
            .CharLiteral => return .CharType,
            .StrLiteral => return .StrType,
            .True, .False => return .BoolType,
            .VoidType => return .VoidType,
            .Identifier => |x| {
                if (isLet)
                    return .VoidType;
                for (idfLookupTable.items) |idf| {
                    if (std.mem.eql(u8, idf.@"0", x)) {
                        return idf.@"1";
                    }
                }
                return error.UnknownIdentifier;
            },
            .DefCall => {
                return try checkDefCall(node, funLookupTable, idfLookupTable);
            },
            else => {},
        }
        if (node.tok.kind.isBinOp()) {
            if (node.tok.kind.isEqlOp()) {
                switch (node.children.items[0].tok.kind) {
                    .Identifier => |s| {
                        if (isLet) {
                            for (idfLookupTable.items) |idf| {
                                if (std.mem.eql(u8, idf.@"0", s)) {
                                    return error.IdentifierRedefined;
                                }
                            }
                            for (funLookupTable.items) |fun| {
                                switch (fun.name.kind) {
                                    .Identifier => |x| {
                                        if (std.mem.eql(u8, x, s)) {
                                            return error.IdentifierRedefined;
                                        }
                                    },
                                    else => {},
                                }
                            }
                        }
                    },
                    else => return error.InvalidLValue,
                }
                if (node.tok.kind != .EqlOp) {
                    if (node.tok.kind == .ModEqlOp and !isInteger(node.children.items[1].tok.kind)) {
                        return error.InvalidLValue;
                    }
                    // else if (!isNumeric(node.children.items[0].tok.kind)) {
                    //     return error.InvalidLValue;
                    // }
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
        } else if (node.tok.kind.isUniOp()) {
            const x = try checkType(
                node.children.items[0],
                funLookupTable,
                idfLookupTable,
                false,
            );
            if (!isNumeric(x)) {
                return error.InvalidTypedOperation;
            } else {
                return x;
            }
        }
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

    fn addExp(self: *@This(), node: ast.AstNode, opCode: OPCode) !void {
        switch (node.tok.kind) {
            .Identifier => |s| {
                for (self.idfLookUpTable.items, 0..) |idf, idx| {
                    if (std.mem.eql(u8, s, idf.@"0")) {
                        const opData: OPCode = if (opCode == .PushInt)
                            switch (idf.@"1") {
                                .Int => .PushInt,
                                .Float => .PushFloat,
                                .Str => .PushInt,
                            }
                        else
                            opCode;

                        try self.add(opData, idx, 1);
                    }
                }
            },
            .IntLiteral => |i| {
                try self.add(opCode, i, 0);
            },
            .FloatLiteral => |f| {
                const opData: OPCode = if (opCode == .PushInt)
                    .PushFloat
                else
                    opCode;

                try self.add(opData, @bitCast(f), 0);
            },
            .StrLiteral => |s| {
                const idx = try self.addConst(s);

                try self.add(opCode, idx, 2);
            },
            .DefCall => |d| {
                var x = node.children.items.len;
                while (x > 0) {
                    try self.addExp(node.children.items[x - 1], .PushInt);
                    x -= 1;
                }
                for (self.moduleIr.funcTable.items, 0..) |func, idx| {
                    if (std.mem.eql(u8, d, func.@"1")) {
                        try self.add(.Call, idx, 1);
                    }
                }
            },
            else => {},
        }
        if (node.tok.kind.isBinOp()) {
            if (node.tok.kind.isEqlOp()) {
                if (node.tok.kind == .EqlOp) {
                    try self.addExp(node.children.items[1], .PushInt);
                    try self.addExp(node.children.items[0], .Pop);
                } else {
                    try self.addExp(node.children.items[0], .PushInt);
                    try self.addExp(node.children.items[1], .PushInt);
                    switch (node.tok.kind) {
                        .AddEqlOp => try self.add(.Add, 0, 0),
                        .SubEqlOp => try self.add(.Sub, 0, 0),
                        .MulEqlOp => try self.add(.Mul, 0, 0),
                        .DivEqlOp => try self.add(.Div, 0, 0),
                        .ModEqlOp => try self.add(.Mod, 0, 0),

                        else => {},
                    }
                    try self.addExp(node.children.items[0], .Pop);
                }
            } else {
                try self.addExp(node.children.items[0], .PushInt);
                try self.addExp(node.children.items[1], .PushInt);
                switch (node.tok.kind) {
                    .AddOp => try self.add(.Add, 0, 0),
                    .SubOp => try self.add(.Sub, 0, 0),
                    .MulOp => try self.add(.Mul, 0, 0),
                    .DivOp => try self.add(.Div, 0, 0),
                    .ModOp => try self.add(.Mod, 0, 0),

                    .IsEqlOp => try self.add(.Eql, 0, 0),
                    .IsGrterOp => try self.add(.Gtr, 0, 0),
                    .IsLessOp => try self.add(.Les, 0, 0),
                    .IsGtrEql => try self.add(.GtrEql, 0, 0),
                    .IsLesEql => try self.add(.LesEql, 0, 0),
                    .IsNotEql => try self.add(.NotEql, 0, 0),

                    else => {},
                }
            }
        } else if (node.tok.kind.isUniOp()) {
            switch (node.tok.kind) {
                .SignSubOp => {
                    try self.add(.PushInt, 0, 0);
                    try self.addExp(node.children.items[0], .PushInt);
                    try self.add(.Sub, 0, 0);
                },
                else => {},
            }
        }
    }

    pub fn genStats(self: *@This(), stats: std.ArrayList(ast.Statement), def: ast.DefDecl) !void {
        for (stats.items) |stat| {
            switch (stat) {
                .Exp => |x| {
                    try self.addExp(x, .PushInt);
                },
                .Ret => |x| {
                    try self.addExp(x, .PushInt);
                    for (0..self.funcIdfs) |_| {
                        _ = self.idfLookUpTable.pop();
                        try self.add(.Undef, self.idfLookUpTable.items.len, 1);
                    }
                    self.funcIdfs = 0;

                    try self.add(.Ret, 0, 0);
                },
                .Let => |x| {
                    var idfStack: std.ArrayList(struct { []const u8, lexeme.TokenKind }) = .empty;
                    defer idfStack.deinit(self.alloc);
                    for (def.parameters.items) |par| {
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
                    const typ = try checkType(x.children.items[1], self.mod.functions, &idfStack, false);

                    const dt: DataType = switch (typ) {
                        .FloatType => .Float,
                        .StrType => .Str,
                        else => .Int,
                    };
                    const op: OPCode = switch (typ) {
                        .FloatType => .DefFloat,
                        .StrType => .DefStr,
                        else => .DefInt,
                    };

                    switch (x.children.items[0].tok.kind) {
                        .Identifier => |s| try self.idfLookUpTable.append(self.alloc, .{ s, dt }),
                        else => {},
                    }
                    self.funcIdfs += 1;
                    try self.add(op, self.idfLookUpTable.items.len - 1, 1);
                    try self.addExp(x.children.items[1], .PushInt);
                    try self.addExp(x.children.items[0], .Pop);
                },
                .If => |x| {
                    try self.addExp(x.condition, .PushInt);
                    var initIdx = self.moduleIr.instructions.items.len + 1;
                    try self.add(.JmpIfZero, 0, 0);
                    try self.genStats(x.stats, def);
                    var exitIfIdx = self.moduleIr.instructions.items.len + 1;
                    try self.add(.Jmp, 0, 0);
                    var byte = std.mem.asBytes(&self.moduleIr.instructions.items.len);
                    for (byte) |byt| {
                        self.moduleIr.instructions.items[initIdx] = byt;
                        initIdx += 1;
                    }
                    try self.genStats(x.els, def);

                    byte = std.mem.asBytes(&self.moduleIr.instructions.items.len);
                    for (byte) |byt| {
                        self.moduleIr.instructions.items[exitIfIdx] = byt;
                        exitIfIdx += 1;
                    }
                },
                .While => |x| {
                    var setIfInitIdx: u64 = 0;
                    if (x.els.items.len > 0) {
                        try self.addExp(x.condition, .PushInt);
                        setIfInitIdx = self.moduleIr.instructions.items.len + 1;
                        try self.add(.JmpIfZero, 0, 0);
                    }
                    const gotoStartIdx = self.moduleIr.instructions.items.len;
                    try self.addExp(x.condition, .PushInt);
                    var setInitIdx = self.moduleIr.instructions.items.len + 1;
                    try self.add(.JmpIfZero, 0, 0);
                    try self.genStats(x.stats, def);
                    // var setLoopIdx = self.moduleIr.instructions.items.len + 1;
                    try self.add(.Jmp, gotoStartIdx, 0);

                    var byte = std.mem.asBytes(&self.moduleIr.instructions.items.len);
                    for (byte) |byt| {
                        self.moduleIr.instructions.items[setIfInitIdx] = byt;
                        setIfInitIdx += 1;
                    }

                    try self.genStats(x.els, def);
                    byte = std.mem.asBytes(&(self.moduleIr.instructions.items.len));
                    for (byte) |byt| {
                        self.moduleIr.instructions.items[setInitIdx] = byt;
                        setInitIdx += 1;
                    }
                },

                else => {},
            }
        }
    }

    pub fn gen(self: *@This()) !void {
        // add(".module");

        for (self.mod.functions.items) |def| {
            if (def.isBuiltIn) continue;
            switch (def.name.kind) {
                .Identifier => |s| {
                    try self.moduleIr.funcTable.append(self.alloc, .{ 0, s });
                },
                else => {},
            }
        }

        for (self.mod.functions.items) |def| {
            if (def.isBuiltIn) continue;
            switch (def.name.kind) {
                .Identifier => |s| {
                    for (self.moduleIr.funcTable.items) |*func| {
                        if (std.mem.eql(u8, s, func.@"1")) {
                            func.@"0" = self.moduleIr.instructions.items.len;
                            if (std.mem.eql(u8, "main", func.@"1"))
                                self.moduleIr.mainIdx = self.moduleIr.instructions.items.len;
                        }
                    }
                },
                else => {},
            }
            for (def.parameters.items) |par| {
                const op: OPCode = switch (par.type.kind) {
                    .FloatType => .DefFloat,
                    .StrType => .DefStr,
                    else => .DefInt,
                };
                const dt: DataType = switch (par.type.kind) {
                    .FloatType => .Float,
                    .StrType => .Str,
                    else => .Int,
                };

                switch (par.identifier.kind) {
                    .Identifier => |s| try self.idfLookUpTable.append(self.alloc, .{ s, dt }),
                    else => {},
                }
                try self.add(op, self.idfLookUpTable.items.len - 1, 1);
                self.funcIdfs += 1;
                try self.add(.Pop, self.idfLookUpTable.items.len - 1, 1);
            }
            try self.genStats(def.statements, def);
            const xx: u8 = @intFromEnum(OPCode.Ret);
            if (self.moduleIr.instructions.items[self.moduleIr.instructions.items.len - 1] != xx) {
                if (def.dtype != .VoidType)
                    return error.NoReturn
                else {
                    for (0..self.funcIdfs) |_| {
                        _ = self.idfLookUpTable.pop();
                        try self.add(.Undef, self.idfLookUpTable.items.len, 1);
                    }
                    self.funcIdfs = 0;

                    try self.add(.Ret, 0, 0);
                }
            }
        }
    }
};

const testing = std.testing;
test "import code gen" {
    const src =
        \\def add(a:int, b:float) int {
        \\  return -b+ a + -1.1; 
        \\}
        \\def main() void {
        \\  let x = toInt(input("Enter No: "));
        \\  let y = toInt(input("Enter No: "));
        \\  println("add: {}", add(x,y));
        \\  let x1 = 10;
        \\  x = 10.1;
        \\  x1 += 10;
        \\  return;
        \\}
    ;
    const alloc = testing.allocator;
    var lex = lexer.Lexer.init(alloc, "test.lav", src);
    try lex.lex();

    var stats = try lex.toStatements(alloc);
    lex.deinit();

    var parser = Parser.init(alloc, src, "test.lav", stats);
    var mod = try parser.parse();
    defer mod.deinit(alloc);
    lexer.Lexer.deinitStatements(&stats, alloc);

    try builtin.BuiltInFuncs.init(alloc);
    defer builtin.BuiltInFuncs.deinit();
    var codeGen = try CodeGen.init(mod, src, alloc);
    defer codeGen.deinit();
    try codeGen.sanityCheck();
    try codeGen.gen();
    try codeGen.moduleIr.print();
    std.debug.print("----\n", .{});
    try codeGen.printToFile("test.lav");
}
