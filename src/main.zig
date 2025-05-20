const std = @import("std");

pub fn main() void {
    const allocator = std.heap.page_allocator;
    const stderr = std.io.getStdErr().writer();

    // get cmdline args
    const args = std.process.argsAlloc(allocator) catch {
        stderr.writeAll("Failed to allocate arguments.\n") catch return;
        return;
    };
    defer std.process.argsFree(allocator, args);

    if (args.len != 4) {
        stderr.writeAll("Usage: <video scale> <clock cycle> <*.ch8 file>\n") catch return;
        return;
    }
}
