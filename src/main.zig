const std = @import("std");
const Interpreter = @import("interpreter.zig").Interpreter;
const ArgParser = @import("argParser.zig").ArgParser;
const lexer = @import("lexer.zig");
const Parser = @import("parser.zig").Parser;
const builtin = @import("builtin.zig");
const CodeGen = @import("codegen.zig").CodeGen;

const err = @import("util.zig").err;

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    const args = try ArgParser.init(alloc);

    try builtin.BuiltInFuncs.init(alloc);
    defer builtin.BuiltInFuncs.deinit();
    if (args.compile) {
        var fin = std.fs.cwd().openFile(args.fileName, .{ .mode = .read_only }) catch {
            err(args.fileName, "", 0, "Input source file not found", .{});
            std.process.exit(1);
            return;
        };
        const src = fin.readToEndAlloc(alloc, std.math.maxInt(usize)) catch {
            err(args.fileName, "", 0, "Input source file is too big", .{});

            std.process.exit(1);
        };
        defer fin.close();
        defer alloc.free(src);

        var lex = lexer.Lexer.init(alloc, args.fileName, src);
        try lex.lex();

        var stats = try lex.toStatements(alloc);
        lex.deinit();

        var parser = Parser.init(alloc, src, args.fileName, stats);
        var mod = try parser.parse();
        defer mod.deinit(alloc);
        lexer.Lexer.deinitStatements(&stats, alloc);

        var codeGen = try CodeGen.init(mod, src, alloc);
        defer codeGen.deinit();
        try codeGen.sanityCheck();
        try codeGen.gen();
        if (args.printAsm) {
            try codeGen.moduleIr.print();
            std.debug.print("----\n", .{});
        }
        try codeGen.printToFile(args.fileName, args.output);
    }
    if (args.run) {
        const x = try std.fmt.allocPrint(alloc, "{s}/{s}b", .{
            std.mem.trimRight(u8, args.output, "/"),
            std.mem.trimRight(u8, std.fs.path.basename(args.fileName), "b"),
        });
        defer alloc.free(x);
        // std.debug.print("{s}\n", .{x});
        var int = try Interpreter.init(alloc, x);
        defer int.deinit();
        try int.run();
    }
}

test "main test" {
    _ = @import("lexeme.zig");
    _ = @import("lexer.zig");
    _ = @import("parser.zig");
    _ = @import("codegen.zig");
    _ = @import("interpreter.zig");
}
