const std = @import("std");
const ArgParser = @import("argParser.zig").ArgParser;
const lexer = @import("lexer.zig");

const Err = @import("errors.zig").ArgError;
const printErr = @import("errors.zig").errArg;

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    const args = try ArgParser.init(alloc);
    var fin = std.fs.cwd().openFile(args.fileName, .{ .mode = .read_only }) catch {
        printErr(Err.FileNotFound, .{ .fName = args.fileName });
        std.process.exit(1);
        return;
    };
    const src = fin.readToEndAlloc(alloc, std.math.maxInt(usize)) catch {
        printErr(Err.FileTooBig, .{ .fName = args.fileName });
        std.process.exit(1);
    };

    var lex = lexer.Lexer.init(alloc, args.fileName, src);
    try lex.lex();
}
