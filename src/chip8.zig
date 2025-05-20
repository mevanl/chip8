const std = @import("std");

pub const FONTSET_SIZE = 80;
pub const VIDEO_WIDTH = 64;
pub const VIDEO_HEIGHT = 32;

const FONTSET_START_ADDRESS = 0x50;
const ROM_START_ADDRESS = 0x200;

pub const Chip8 = struct {

    // public
    clock_cycle: c_int = 0,
    video: [VIDEO_WIDTH * VIDEO_HEIGHT]u32,
    keypad: [16]u8,

    // private
    _registers: [16]u8 = {}, // General purpose registers
    _index_register: u16 = 0, // Special address storage
    _program_counter: u16 = 0, // Holds next instruction
    _opcode: u16 = 0, // Stores current opcode
    _stack: [16]u16 = {}, // Call Stack
    _stack_pointer: u8 = 0, // Stores current stack location
    _delay_timer: u8 = 0, // General purpose timer
    _sound_timer: u8 = 0, // Same as delay_timer but emits a noise
    // Memory Layout:
    // 0x000-0x1FF: For CHIP-8 Interpreter (Mostly unused for emulation)
    // 0x050-0x0A0: Stores characters 0-F for ROMs
    // 0x200-0xFFF: ROM instructions and free space if any
    _memory: [4096]u8 = {}, // 4KB of RAM
    _fontset: [FONTSET_SIZE]u8 = [_]u8{
        0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
        0x20, 0x60, 0x20, 0x20, 0x70, // 1                  // Example F:
        0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2                  // 0xF0:    11110000
        0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3                  // 0x80:    10000000
        0x90, 0x90, 0xF0, 0x10, 0x10, // 4                  // 0xF0:    11110000
        0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5                  // 0x80:    10000000
        0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6                  // 0x80:    10000000
        0xF0, 0x10, 0x20, 0x40, 0x40, // 7                  // the ones make an F
        0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
        0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
        0xF0, 0x90, 0xF0, 0x90, 0x90, // A
        0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
        0xF0, 0x80, 0x80, 0x80, 0xF0, // C
        0xE0, 0x90, 0x90, 0x90, 0xE0, // D
        0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
        0xF0, 0x80, 0xF0, 0x80, 0x80, // F
    },

    // TODO:
    // Generate random values and store a random byte for game usage
    // std::default_random_engine random_generator;
    // std::uniform_int_distribution<uint8_t> random_byte;

    pub fn init(self: *Chip8) void {}
    pub fn load_rom(self: *Chip8, rom_file: []const u8) void {}
    pub fn cycle(self: *Chip8) void {}

    fn OP_NULL() void {}
    fn OP_00E0(self: *Chip8) void {}
    fn OP_00EE(self: *Chip8) void {}
    fn OP_1nnn(self: *Chip8) void {}
    fn OP_2nnn(self: *Chip8) void {}
    fn OP_3xkk(self: *Chip8) void {}
    fn OP_4xkk(self: *Chip8) void {}
    fn OP_5xy0(self: *Chip8) void {}
    fn OP_6xkk(self: *Chip8) void {}
    fn OP_7xkk(self: *Chip8) void {}
    fn OP_8xy0(self: *Chip8) void {}
    fn OP_8xy1(self: *Chip8) void {}
    fn OP_8xy2(self: *Chip8) void {}
    fn OP_8xy3(self: *Chip8) void {}
    fn OP_8xy4(self: *Chip8) void {}
    fn OP_8xy5(self: *Chip8) void {}
    fn OP_8xy6(self: *Chip8) void {}
    fn OP_8xy7(self: *Chip8) void {}
    fn OP_8xyE(self: *Chip8) void {}
    fn OP_9xy0(self: *Chip8) void {}
    fn OP_Annn(self: *Chip8) void {}
    fn OP_Bnnn(self: *Chip8) void {}
    fn OP_Cxkk(self: *Chip8) void {}
    fn OP_Dxyn(self: *Chip8) void {}
    fn OP_Ex9E(self: *Chip8) void {}
    fn OP_ExA1(self: *Chip8) void {}
    fn OP_Fx07(self: *Chip8) void {}
    fn OP_Fx0A(self: *Chip8) void {}
    fn OP_Fx15(self: *Chip8) void {}
    fn OP_Fx18(self: *Chip8) void {}
    fn OP_Fx1E(self: *Chip8) void {}
    fn OP_Fx29(self: *Chip8) void {}
    fn OP_Fx33(self: *Chip8) void {}
    fn OP_Fx55(self: *Chip8) void {}
    fn OP_Fx65(self: *Chip8) void {}
};
