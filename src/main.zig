const std = @import("std");
const ArgParser = @import("argParser.zig").ArgParser;
const lexer = @import("lexer.zig");
const err = @import("util.zig").err;

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    const args = try ArgParser.init(alloc);
    var fin = std.fs.cwd().openFile(args.fileName, .{ .mode = .read_only }) catch {
        err(args.fileName, "", 0, "Input source file not found", .{});
        std.process.exit(1);
        return;
    };
    const src = fin.readToEndAlloc(alloc, std.math.maxInt(usize)) catch {
        err(args.fileName, "", 0, "Input source file is too big", .{});

        std.process.exit(1);
    };

    var lex = lexer.Lexer.init(alloc, args.fileName, src);
    defer lex.deinit();

    try lex.lex();
    const stats = try lex.toStatements(alloc);
    for (stats.items) |stat| {
        for (stat.items) |tok| {
            std.debug.print("{s} ", .{tok.toStr(alloc)});
        }
        std.debug.print("\n", .{});
    }
}

test "main test" {
    _ = @import("lexeme.zig");
    _ = @import("lexer.zig");
    _ = @import("parser.zig");
}
