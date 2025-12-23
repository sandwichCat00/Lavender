const std = @import("std");
const ArgParser = @import("argParser.zig").ArgParser;

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    try ArgParser.init(alloc);
}
