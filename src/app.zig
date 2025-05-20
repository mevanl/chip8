const std = @import("std");

pub const App = struct {
    //Chip8 chip8

    pub fn init(
        allocator: std.mem.Allocator,
        window_width: c_int,
        window_height: c_int,
        texture_width: c_int,
        texture_height: c_int,
        clock_cycle: c_int,
        rom_file: []const u8,
    ) void {}

    pub fn deinit() void {
        // mainly calls sdl destroy functions
        return;
    }
};
