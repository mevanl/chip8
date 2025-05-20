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

// pub fn build(b: *std.Build) void {
//     const target = b.standardTargetOptions(.{});
//     const optimize = b.standardOptimizeOption(.{});
//     const exe = b.addExecutable(.{
//         .name = "test",
//         .root_source_file = b.path("src/main.zig"),
//         .target = target,
//         .optimize = optimize,
//     });

//     const stb_image_lib = b.addStaticLibrary(.{
//         .name = "stb_image",
//         .target = target,
//         .optimize = optimize,
//     });
//     stb_image_lib.addCSourceFiles(.{
//         .files = &.{"libs/stb_wrapper.c"},
//     });
//     stb_image_lib.addIncludePath(b.path("libs/"));
//     stb_image_lib.linkLibC();
//     stb_image_lib.installHeader(b.path("libs/stb_image.h"), "libs/stb_image.h");
//     stb_image_lib.installHeader(b.path("libs/stb_truetype.h"), "libs/stb_truetype.h");
//     b.installArtifact(stb_image_lib);

//     exe.linkLibrary(stb_image_lib);

//     b.installArtifact(exe);
