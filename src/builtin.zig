const ast = @import("ast.zig");
const std = @import("std");
const DataType = @import("codegen.zig").DataType;

pub var BuiltInFuncs: struct {
    defs: std.ArrayList(struct { ast.DefDecl, *const fn (
        *std.ArrayList(struct { DataType, u64 }),
        *std.ArrayList(u8),
        std.mem.Allocator,
    ) anyerror!void }) = .empty,
    alloc: std.mem.Allocator = undefined,

    pub fn init(ret: *@This(), alloc: std.mem.Allocator) !void {
        ret.alloc = alloc;
        ret.defs = .empty;
        try ret.defs.append(ret.alloc, .{ initPrint(), &printCall });
        try ret.defs.append(ret.alloc, .{ initPrintln(), &printlnCall });
        try ret.defs.append(ret.alloc, .{ try initInput(ret.alloc), &inputCall });
        try ret.defs.append(ret.alloc, .{ initToInt(), &toIntCall });
    }
    pub fn deinit(self: *@This()) void {
        for (self.defs.items) |*def| {
            def.@"0".parameters.deinit(self.alloc);
        }
        self.defs.deinit(self.alloc);
    }
} = .{};

fn printCall(
    opStack: *std.ArrayList(struct { DataType, u64 }),
    constPool: *std.ArrayList(u8),
    alloc: std.mem.Allocator,
) !void {
    _ = alloc;
    const pp = if (opStack.pop()) |p| p else return error.EmptyStack;
    switch (pp.@"0") {
        .Str => {
            var idx = pp.@"1";

            while (idx < constPool.items.len and constPool.items[idx] != 0) {
                if (constPool.items[idx] == '{') {
                    idx += 1;
                    if (idx < constPool.items.len) {
                        switch (constPool.items[idx]) {
                            '{' => std.debug.print("{{", .{}),
                            '}' => {
                                if (opStack.pop()) |p| {
                                    switch (p.@"0") {
                                        .Int => {
                                            const x: i64 = @bitCast(p.@"1");
                                            std.debug.print("{d}", .{x});
                                        },
                                        .Float => {
                                            const x: f64 = @bitCast(p.@"1");
                                            std.debug.print("{d}", .{x});
                                        },
                                        .Str => {
                                            const cPtr = std.mem.indexOf(u8, constPool.items[p.@"1"..], &[_]u8{0});
                                            if (cPtr) |x| {
                                                std.debug.print("{s}", .{constPool.items[p.@"1" .. p.@"1" + x]});
                                            }
                                        },
                                    }
                                } else return error.EmptyStack;
                            },
                            else => return error.InvalidBrace,
                        }
                    } else return error.InvalidBrace;
                } else std.debug.print("{c}", .{constPool.items[idx]});
                idx += 1;
            }
        },
        else => {
            return error.InvalidArgumentType;
        },
    }
}

const xCount: u8 = 0;

fn inputCall(
    opStack: *std.ArrayList(struct { DataType, u64 }),
    constPool: *std.ArrayList(u8),
    alloc: std.mem.Allocator,
) !void {
    const pp = if (opStack.pop()) |p| p else return error.EmptyStack;
    // var buff: [1024]u8 = undefined;
    // const stdoutWrp = std.fs.File.stdout().writer(&buff);
    // var stdout = stdoutWrp.interface;
    switch (pp.@"0") {
        .Str => {
            const cPtr = std.mem.indexOf(u8, constPool.items[pp.@"1"..], &[_]u8{0});
            if (cPtr) |x| {
                std.debug.print("{s}", .{constPool.items[pp.@"1" .. pp.@"1" + x]});
                // std.debug.print("{s}", .{constPool.items[pp.@"1" .. pp.@"1" + x]});
                // std.debug.flush();
            }
        },
        else => return error.InvalidArgumentType,
    }
    var buff_in: [1024]u8 = undefined;
    var stdin = std.fs.File.stdin().reader(&buff_in);
    const x = try stdin.interface.takeDelimiterExclusive('\n');
    const idx = constPool.items.len;
    try constPool.appendSlice(alloc, x);
    try constPool.append(alloc, 0);
    try opStack.append(alloc, .{ .Str, idx });
}
fn printlnCall(
    opStack: *std.ArrayList(struct { DataType, u64 }),
    constPool: *std.ArrayList(u8),
    alloc: std.mem.Allocator,
) !void {
    try printCall(opStack, constPool, alloc);

    std.debug.print("\n", .{});
}

fn toIntCall(
    opStack: *std.ArrayList(struct { DataType, u64 }),
    constPool: *std.ArrayList(u8),
    alloc: std.mem.Allocator,
) !void {
    if (opStack.pop()) |p| {
        switch (p.@"0") {
            .Int => try opStack.append(alloc, p),
            .Float => {
                const x: f64 = @bitCast(p.@"1");
                const xx: i64 = @intFromFloat(x);
                try opStack.append(alloc, .{ .Int, @bitCast(xx) });
            },
            .Str => {
                const cPtr = std.mem.indexOf(u8, constPool.items[p.@"1"..], &[_]u8{0});
                if (cPtr) |x| {
                    const int: i64 = try std.fmt.parseInt(i64, constPool.items[p.@"1" .. p.@"1" + x], 10);
                    try opStack.append(alloc, .{ .Int, @bitCast(int) });
                } else std.debug.print("rwteret\n", .{});
            },
        }
    } else return error.EmptyStack;
}

fn initPrintln() ast.DefDecl {
    var def: ast.DefDecl = .{};
    def.name = .{ .idx = 0, .kind = .{ .Identifier = "println" } };
    def.isBuiltIn = true;
    def.varLen = true;
    return def;
}
fn initPrint() ast.DefDecl {
    var def: ast.DefDecl = .{};
    def.name = .{ .idx = 0, .kind = .{ .Identifier = "print" } };
    def.isBuiltIn = true;
    def.varLen = true;
    return def;
}

fn initToInt() ast.DefDecl {
    var def: ast.DefDecl = .{};
    def.name = .{ .idx = 0, .kind = .{ .Identifier = "toInt" } };
    def.isBuiltIn = true;
    def.dtype = .IntType;
    def.varLen = true;
    return def;
}
fn initInput(alloc: std.mem.Allocator) !ast.DefDecl {
    var def: ast.DefDecl = .{};
    def.name = .{ .idx = 0, .kind = .{ .Identifier = "input" } };
    def.isBuiltIn = true;
    def.varLen = true;
    def.dtype = .StrType;
    try def.parameters.append(
        alloc,
        .{
            .identifier = .{ .idx = 0, .kind = .{ .Identifier = "prompt" } },
            .type = .{ .idx = 0, .kind = .StrType },
        },
    );
    return def;
}
