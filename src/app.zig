const std = @import("std");

pub const App = struct {
    //Chip8 chip8

    pub fn init(
        self: *const App,
        allocator: std.mem.Allocator,
        window_width: c_int,
        window_height: c_int,
        texture_width: c_int,
        texture_height: c_int,
        clock_cycle: c_int,
        rom_file: []const u8,
    ) !void {
        _ = self;
        _ = allocator;
        _ = window_width;
        _ = window_height;
        _ = texture_width;
        _ = texture_height;
        _ = clock_cycle;
        _ = rom_file;

        // Initialize SDL

        // Create Main Window

        // Create Main Renderer

        // Create Main Texture

        // Setup chip8 and load rom
    }

    pub fn deinit(self: *const App) void {
        // mainly calls sdl destroy functions
        _ = self;
        return;
    }

    pub fn run() void {
        return;
    }
};
