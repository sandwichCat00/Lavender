const std = @import("std");
const err = @import("util.zig").errNoExit;

pub const ArgParser = struct {
    fileName: []const u8,
    output: []const u8 = "./lav-out/",
    run: bool = false,
    compile: bool = true,

    fn help() void {
        std.debug.print(
            \\lavender [OPTIONS] <SrcFile|BinFile>
            \\
            \\Options:
            \\  -h, --help        Show this help
            \\  -o <path>         Output dir path 
            \\  --run             Run after compilation
            \\
        , .{});
    }

    pub fn init(alloc: std.mem.Allocator) error{OutOfMemory}!ArgParser {
        var ret: ArgParser = .{
            .fileName = "",
        };

        var args = std.process.args();
        _ = args.next();

        while (args.next()) |arg| {
            if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
                help();
                std.process.exit(0);
            } else if (std.mem.eql(u8, arg, "--run")) {
                ret.run = true;
            } else if (std.mem.eql(u8, arg, "-o")) {
                const out = args.next() orelse {
                    err("", "", 0, "Expected filename after -o", .{});
                    std.process.exit(1);
                };
                ret.output = try alloc.dupe(u8, out);
            } else if (arg.len > 0 and arg[0] == '-') {
                err("", "", 0, "Unknown option: {s}", .{arg});
                help();
                std.process.exit(1);
            } else {
                if (ret.fileName.len != 0) {
                    err("", "", 0, "Multiple input files not supported: {s}", .{arg});
                    help();
                    std.process.exit(1);
                }
                ret.fileName = try alloc.dupe(u8, arg);
            }
        }

        if (ret.fileName.len == 0) {
            err("", "", 0, "Expected source or binary file", .{});
            help();
            std.process.exit(1);
        }

        if (std.mem.eql(u8, std.fs.path.extension(ret.fileName), ".lav")) {
            return ret;
        } else if (std.mem.eql(u8, std.fs.path.extension(ret.fileName), ".lavb")) {
            ret.run = true;
            ret.compile = false;
        } else {
            err("", "", 0, "Invalid file extension, Expected .lav or .lavb", .{});
            help();
            std.process.exit(1);
        }

        return ret;
    }
};
