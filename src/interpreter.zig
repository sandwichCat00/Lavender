const std = @import("std");
const util = @import("util.zig");
const ModuleIR = @import("codegen.zig").ModuleIR;
const OPCode = @import("codegen.zig").OPCode;
const DataType = @import("codegen.zig").DataType;
const builtin = @import("builtin.zig");

pub const Interpreter = struct {
    alloc: std.mem.Allocator,
    fin: std.fs.File,
    src: []u8,
    moduleIR: ModuleIR,
    mainIdx: usize,
    fn initModuleIR(self: *@This()) !void {
        const src = self.src;
        var idx: usize = 0;

        for (builtin.BuiltInFuncs.defs.items) |_| {
            try self.moduleIR.funcTable.append(self.alloc, .{ 0, "" });
        }

        const funcSize = try util.readU64(src, &idx);
        for (0..funcSize) |_| {
            const funcAddr = try util.readU64(src, &idx);
            try self.moduleIR.funcTable.append(self.alloc, .{ funcAddr, "" });
        }
        const mainIdx = try util.readU64(src, &idx);
        if (mainIdx == 0)
            return error.NoMainFunc;
        self.mainIdx = mainIdx - 1;
        const constPoolSize = try util.readU64(src, &idx);
        try self.moduleIR.constPool.appendSlice(self.alloc, src[idx .. idx + constPoolSize]);
        idx += constPoolSize;
        try self.moduleIR.instructions.appendSlice(self.alloc, src[idx..]);
    }

    pub fn init(
        alloc: std.mem.Allocator,
        path: []const u8,
    ) !@This() {
        var file = try std.fs.cwd().openFile(path, .{});
        errdefer file.close();

        const stat = try file.stat();
        const size = stat.size;

        const buffer = try alloc.alloc(u8, size);
        errdefer alloc.free(buffer);

        _ = try file.readAll(buffer);
        var mod: @This() = .{ .alloc = alloc, .mainIdx = 0, .fin = file, .src = buffer, .moduleIR = .{} };
        try mod.initModuleIR();

        return mod;
    }

    pub fn run(self: *@This()) !void {
        const mod = self.moduleIR;
        var idx: usize = mod.funcTable.items[self.mainIdx].@"0";
        const insts = self.moduleIR.instructions.items;

        var opStack: std.ArrayList(struct { DataType, u64 }) = .empty;
        defer opStack.deinit(self.alloc);
        var idfStack: std.ArrayList(struct { DataType, u64 }) = .empty;
        defer idfStack.deinit(self.alloc);
        var funcStack: std.ArrayList(struct { usize, usize }) = .empty;
        defer funcStack.deinit(self.alloc);

        var currIdfOffset: usize = 0;

        while (idx < insts.len) {
            const opCode: OPCode = @enumFromInt(insts[idx]);
            switch (opCode) {
                // Arithmetic (no operands)
                .Add,
                .Sub,
                .Div,
                .Mul,
                .Mod,
                .Eql,
                .Gtr,
                .Les,
                .GtrEql,
                .LesEql,
                .NotEql,
                => {
                    const op2R = if (opStack.pop()) |p| p //
                        else return error.emptyStack;
                    const op1R = if (opStack.pop()) |p| p //
                        else return error.emptyStack;
                    if (op1R.@"0" == .Float or op2R.@"0" == .Float) {
                        const op1: f64 = if (op1R.@"0" == .Float) @bitCast(op1R.@"1") //
                            else bl: {
                                const int: i64 = @bitCast(op1R.@"1");
                                break :bl @floatFromInt(int);
                            };
                        const op2: f64 = if (op2R.@"0" == .Float) @bitCast(op2R.@"1") //
                            else bl: {
                                const int: i64 = @bitCast(op2R.@"1");
                                break :bl @floatFromInt(int);
                            };
                        const res: f64 = switch (opCode) {
                            .Add => op1 + op2,
                            .Sub => op1 - op2,
                            .Div => op1 / op2,
                            .Mul => op1 * op2,
                            .Mod => @mod(op1, op2),
                            .Eql => @floatFromInt(@intFromBool(op1 == op2)),
                            .Gtr => @floatFromInt(@intFromBool(op1 > op2)),
                            .Les => @floatFromInt(@intFromBool(op1 < op2)),
                            .GtrEql => @floatFromInt(@intFromBool(op1 >= op2)),
                            .LesEql => @floatFromInt(@intFromBool(op1 <= op2)),
                            .NotEql => @floatFromInt(@intFromBool(op1 != op2)),
                            else => 0.0,
                        };
                        try opStack.append(self.alloc, .{ .Float, @bitCast(res) });
                    } else {
                        const op1: i64 = @bitCast(op1R.@"1");
                        const op2: i64 = @bitCast(op2R.@"1");
                        const res = switch (opCode) {
                            .Add => op1 + op2,
                            .Sub => op1 - op2,
                            .Div => @divTrunc(op1, op2),
                            .Mul => op1 * op2,
                            .Mod => @mod(op1, op2),
                            .Eql => @intFromBool(op1 == op2),
                            .Gtr => @intFromBool(op1 > op2),
                            .Les => @intFromBool(op1 < op2),
                            .GtrEql => @intFromBool(op1 >= op2),
                            .LesEql => @intFromBool(op1 <= op2),
                            .NotEql => @intFromBool(op1 != op2),
                            else => 0,
                        };
                        try opStack.append(self.alloc, .{ .Int, @bitCast(res) });
                    }
                    idx += 1;
                },
                .Jmp => {
                    idx += 1;
                    var bytes = insts[idx .. idx + 8];
                    const op: u64 = std.mem.readInt(u64, bytes[0..8], .little);
                    idx += 8;
                    idx = op;
                },
                .JmpIfZero => {
                    idx += 1;
                    var bytes = insts[idx .. idx + 8];
                    const op: u64 = std.mem.readInt(u64, bytes[0..8], .little);
                    idx += 8;
                    if (opStack.pop()) |p| {
                        switch (p.@"0") {
                            .Int => {
                                const x: i64 = @bitCast(p.@"1");
                                if (x == 0)
                                    idx = op;
                            },
                            .Float => {
                                const x: i64 = @bitCast(p.@"1");
                                if (x == 0)
                                    idx = op;
                            },
                            .Str => {
                                if (self.moduleIR.constPool.items[op] == 0)
                                    idx = op;
                            },
                        }
                    } else return error.emptyStack;
                },
                // Push instructions
                .PushInt => {
                    idx += 1;
                    const addressMode = insts[idx];

                    idx += 1;
                    var bytes = insts[idx .. idx + 8];
                    const op: u64 = std.mem.readInt(u64, bytes[0..8], .little);
                    idx += 8;

                    if (addressMode == 0)
                        try opStack.append(self.alloc, .{ .Int, op })
                    else if (addressMode == 2)
                        try opStack.append(self.alloc, .{ .Str, op })
                    else
                        try opStack.append(self.alloc, idfStack.items[currIdfOffset + op]);
                },
                .PushFloat => {
                    idx += 1;
                    const addressMode = insts[idx];

                    idx += 1;
                    const bytes = insts[idx .. idx + 8];
                    const op: u64 = std.mem.readInt(u64, bytes[0..8], .little);
                    idx += 8;

                    if (addressMode == 0)
                        try opStack.append(self.alloc, .{ .Float, op })
                    else
                        try opStack.append(self.alloc, idfStack.items[currIdfOffset + op]);
                },

                // Stack / control
                .Pop => {
                    idx += 1;
                    const bytes = insts[idx .. idx + 8];
                    const op: u64 = std.mem.readInt(u64, bytes[0..8], .little);
                    idx += 8;

                    const popped = if (opStack.pop()) |p| p //
                        else return error.emptyStack;
                    if (idfStack.items[currIdfOffset + op].@"0" == .Float) {
                        if (popped.@"0" == .Float) {
                            idfStack.items[currIdfOffset + op].@"1" = popped.@"1";
                        } else {
                            const fl: f64 = @floatFromInt(popped.@"1");
                            idfStack.items[currIdfOffset + op].@"1" = @bitCast(fl);
                        }
                    } else {
                        if (popped.@"0" == .Int or popped.@"0" == .Str) {
                            idfStack.items[currIdfOffset + op].@"1" = popped.@"1";
                        } else {
                            const fl: f64 = @bitCast(popped.@"1");
                            const int: i64 = @intFromFloat(fl);
                            idfStack.items[currIdfOffset + op].@"1" = @bitCast(int);
                        }
                    }
                },
                .Call => {
                    idx += 1;
                    const bytes = insts[idx .. idx + 8];
                    const op: u64 = std.mem.readInt(u64, bytes[0..8], .little);
                    idx += 7;
                    if (op >= builtin.BuiltInFuncs.defs.items.len) {
                        try funcStack.append(self.alloc, .{ idx, idfStack.items.len });
                        currIdfOffset = idfStack.items.len;
                        idx = mod.funcTable.items[op].@"0";
                    } else {
                        try builtin.BuiltInFuncs.defs.items[op].@"1"(&opStack, &self.moduleIR.constPool, self.alloc);
                        idx += 1;
                    }
                },
                .Ret => {
                    if (funcStack.pop()) |p| {
                        idx = p.@"0";
                        currIdfOffset -= p.@"1";
                    } else return;
                    idx += 1;
                },

                // Definitions
                .DefInt => {
                    try idfStack.append(self.alloc, .{ .Int, 0 });
                    idx += 1;
                },
                .DefStr => {
                    try idfStack.append(self.alloc, .{ .Str, 0 });
                    idx += 1;
                },

                .DefFloat => {
                    try idfStack.append(self.alloc, .{ .Float, 0 });
                    idx += 1;
                },
                .Undef => {
                    _ = idfStack.pop();
                    idx += 1;
                },
            }
        }
    }

    pub fn deinit(self: *Interpreter) void {
        self.fin.close();
        self.alloc.free(self.src);
        self.moduleIR.constPool.deinit(self.alloc);
        self.moduleIR.funcTable.deinit(self.alloc);
        self.moduleIR.instructions.deinit(self.alloc);
    }
};

const testing = std.testing;
test "basic test" {
    std.debug.print("asd\n", .{});
}
