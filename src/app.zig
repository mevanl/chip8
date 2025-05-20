const std = @import("std");
const SDL = @cImport(@cInclude("SDL3/SDL.h"));
const chip8 = @import("chip8.zig");

pub const AppError = error{
    SDLInitFailed,
    CreateWindowFailed,
    CreateRendererFailed,
    CreateTextureFailed,
    UpdateDisplayFailed,
    InvalidKeyPress,
};

pub const App = struct {
    chip8: chip8.Chip8,
    main_window: ?*SDL.SDL_Window,
    main_texture: ?*SDL.SDL_Texture,
    main_renderer: ?*SDL.SDL_Renderer,

    pub fn init(
        self: *App,
        window_width: c_int,
        window_height: c_int,
        texture_width: c_int,
        texture_height: c_int,
        clock_cycle: c_int,
        rom_file: []const u8,
    ) AppError!void {

        // Initialize SDL
        if (!SDL.SDL_Init(SDL.SDL_INIT_VIDEO | SDL.SDL_INIT_AUDIO)) {
            return AppError.SDLInitFailed;
        }

        // initialize
        self.main_window = null;
        self.main_texture = null;
        self.main_renderer = null;

        // Create Main Window
        self.main_window = SDL.SDL_CreateWindow(
            "Chip-8",
            window_width,
            window_height,
            SDL.SDL_WINDOW_RESIZABLE,
        );

        if (self.main_window == null) {
            return AppError.CreateWindowFailed;
        }

        // Create Main Renderer
        self.main_renderer = SDL.SDL_CreateRenderer(self.main_window, null);

        if (self.main_renderer == null) {
            return AppError.CreateRendererFailed;
        }

        // Create Main Texture
        self.main_texture = SDL.SDL_CreateTexture(
            self.main_renderer,
            SDL.SDL_PIXELFORMAT_RGBA8888,
            SDL.SDL_TEXTUREACCESS_STREAMING,
            texture_width,
            texture_height,
        );

        if (self.main_texture == null) {
            return AppError.CreateTextureFailed;
        }

        // TODO: Setup chip8 and load rom
        _ = clock_cycle;
        _ = rom_file;
    }

    pub fn deinit(self: *App) void {
        if (self.main_texture) |texture| {
            SDL.SDL_DestroyTexture(texture);
        }

        if (self.main_renderer) |renderer| {
            SDL.SDL_DestroyRenderer(renderer);
        }

        if (self.main_window) |window| {
            SDL.SDL_DestroyWindow(window);
        }

        SDL.SDL_Quit();
    }

    pub fn update_display(self: *App, texture_buffer: ?*const anyopaque, texture_pitch: c_int) AppError!void {
        if (!SDL.SDL_UpdateTexture(self.main_texture.?, null, texture_buffer, texture_pitch)) {
            return AppError.UpdateDisplayFailed;
        }

        if (!SDL.SDL_RenderClear(self.main_renderer.?)) {
            return AppError.UpdateDisplayFailed;
        }

        if (!SDL.SDL_RenderTexture(self.main_renderer.?, self.main_texture.?, null, null)) {
            return AppError.UpdateDisplayFailed;
        }

        if (!SDL.SDL_RenderPresent(self.main_renderer.?)) {
            return AppError.UpdateDisplayFailed;
        }
    }

    pub fn process_keypress(keys: []u8) AppError!bool {
        var quit: bool = false;
        var current_event: SDL.SDL_Event = undefined;

        while (SDL.SDL_PollEvent(&current_event)) {
            switch (current_event.type) {
                SDL.SDL_EVENT_QUIT => {
                    quit = true;
                    break;
                },

                SDL.SDL_EVENT_KEY_DOWN => {
                    if (current_event.key.key == SDL.SDLK_ESCAPE) {
                        quit = true;
                        break;
                    }

                    // ignore unmapped keys
                    const key_result = get_keycode_value(current_event.key.key) catch break;
                    keys[key_result] = 1;
                    break;
                },

                SDL.SDL_EVENT_KEY_UP => {
                    // ignore unmapped keys
                    const key_result = get_keycode_value(current_event.key.key) catch break;
                    keys[key_result] = 0;
                    break;
                },

                else => continue,
            }
        }

        return quit;
    }

    fn get_keycode_value(SDLK: c_uint) AppError!u8 {
        switch (SDLK) {
            SDL.SDLK_X => return 0x0,
            SDL.SDLK_1 => return 0x1,
            SDL.SDLK_2 => return 0x2,
            SDL.SDLK_3 => return 0x3,
            SDL.SDLK_Q => return 0x4,
            SDL.SDLK_W => return 0x5,
            SDL.SDLK_E => return 0x6,
            SDL.SDLK_A => return 0x7,
            SDL.SDLK_S => return 0x8,
            SDL.SDLK_D => return 0x9,
            SDL.SDLK_Z => return 0xA,
            SDL.SDLK_C => return 0xB,
            SDL.SDLK_4 => return 0xC,
            SDL.SDLK_R => return 0xD,
            SDL.SDLK_F => return 0xE,
            SDL.SDLK_V => return 0xF,
            else => return AppError.InvalidKeyPress,
        }
    }

    pub fn run(self: *App) void {

        // calculate pitch (# of bytes in row)
        const video_pitch: c_int = @sizeOf(@TypeOf(self.chip8.video[0])) * chip8.VIDEO_WIDTH;
        var previous_cycle_time: i128 = std.time.nanoTimestamp(); // use i128 to match return type

        var quit = false;

        while (!quit) {
            quit = self.process_keypress(self.chip8.keypad);

            const current_time = std.time.nanoTimestamp();
            const delta_ns = current_time - previous_cycle_time;
            const delta_time: f32 = @as(f32, @floatFromInt(delta_ns)) / 1_000_000.0;

            if (delta_time > self.chip8.clock_cycle) {
                previous_cycle_time = current_time;
                self.chip8.cycle();
                self.update_display(self, self.chip8.video, video_pitch);
            }
        }
    }
};
