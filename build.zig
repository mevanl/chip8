const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // define executable module
    const exe_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // sdl
    const sdl_dep = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
    });
    const sdl_lib = sdl_dep.artifact("SDL3");
    sdl_lib.linkLibC();

    // define our executable
    const exe = b.addExecutable(.{
        .name = "chip8",
        .root_module = exe_module,
    });
    exe.linkLibrary(sdl_lib);

    b.installArtifact(exe);
}
