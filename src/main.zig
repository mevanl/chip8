const std = @import("std");
const app = @import("app.zig");
const chip8 = @import("chip8.zig");

pub fn main() void {
    const allocator = std.heap.c_allocator;
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

    // process args
    const video_scale = std.fmt.parseInt(u8, args[1], 10) catch |err| {
        stderr.print("Failed to get video scale from arguments.\nError: {any}", .{err}) catch return;
    };

    const clock_cycle = std.fmt.parseInt(u8, args[2], 10) catch |err| {
        stderr.print("Failed to get clock cycle from arguments.\nError: {any}", .{err}) catch return;
    };

    const rom_file = args[3];

    if (!std.mem.endsWith(u8, rom_file, ".ch8")) {
        stderr.writeAll("Error: Invalid rom file format, must be .ch8 file.\n") catch return;
        return;
    }

    // setup app
    const chip8_app: app.App = undefined;
    chip8_app.init(
        allocator,
        chip8.VIDEO_WIDTH * video_scale,
        chip8.VIDEO_HEIGHT * video_scale,
        chip8.VIDEO_WIDTH,
        chip8.VIDEO_HEIGHT,
        clock_cycle,
        rom_file,
    );
    defer chip8_app.deinit();

    
}
