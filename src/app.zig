const std = @import("std");
const SDL = @cImport(@cInclude("SDL3/SDL.h"));

pub const App = struct {
    //Chip8 chip8
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

    pub fn run() void {
        return;
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
};

pub const AppError = error{
    SDLInitFailed,
    CreateWindowFailed,
    CreateRendererFailed,
    CreateTextureFailed,
    UpdateDisplayFailed,
};
