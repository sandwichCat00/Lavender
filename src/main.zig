const std = @import("std");
const ArgParser = @import("argParser.zig").ArgParser;
const lexer = @import("lexer.zig");

const ArgErr = @import("errors.zig").ArgError;
const printArgErr = @import("errors.zig").errArg;

const LexErr = @import("errors.zig").LexError;
const printLexErr = @import("errors.zig").errLex;

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    const args = try ArgParser.init(alloc);
    var fin = std.fs.cwd().openFile(args.fileName, .{ .mode = .read_only }) catch {
        printArgErr(ArgErr.FileNotFound, .{ .fName = args.fileName });
        std.process.exit(1);
        return;
    };
    const src = fin.readToEndAlloc(alloc, std.math.maxInt(usize)) catch {
        printArgErr(ArgErr.FileTooBig, .{ .fName = args.fileName });
        std.process.exit(1);
    };

    var lex = lexer.Lexer.init(alloc, args.fileName, src);
    lex.lex() catch |err| {
        switch (err) {
            LexErr.OutOfMemory => printLexErr(err, .{}),
            else => printLexErr(LexErr.Unknown, .{}),
        }
    };

    for (lex.tokens.items) |t| {
        std.debug.print("{s}\n", .{try t.toStr(alloc)});
    }
}

test "main test" {
    _ = @import("lexeme.zig");
    _ = @import("lexer.zig");
}
