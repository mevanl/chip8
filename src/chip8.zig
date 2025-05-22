const std = @import("std");
const fs = std.fs;

pub const FONTSET_SIZE = 80;
pub const VIDEO_WIDTH = 64;
pub const VIDEO_HEIGHT = 32;

const FONTSET_START_ADDRESS = 0x50;
const ROM_START_ADDRESS = 0x200;

const Chip8Fn = *const fn (*Chip8) void;

pub const Chip8Error = error{
    RomOpenError,
    RomReadError,
    RomSizeError,
};

pub const Chip8 = struct {

    // public
    clock_cycle: c_int = 0,
    video: [VIDEO_WIDTH * VIDEO_HEIGHT]u32 = [_]u32{0} ** (VIDEO_WIDTH * VIDEO_HEIGHT),
    keypad: [16]u8 = [_]u8{0} ** 16,

    // private
    _registers: [16]u8 = [_]u8{0} ** 16, // General purpose registers
    _index_register: u16 = 0, // Special address storage
    _program_counter: u16 = ROM_START_ADDRESS, // Holds next instruction
    _opcode: u16 = 0, // Stores current opcode
    _stack: [16]u16 = [_]u16{0} ** 16, // Call Stack
    _stack_pointer: u8 = 0, // Stores current stack location
    _delay_timer: u8 = 0, // General purpose timer
    _sound_timer: u8 = 0, // Same as delay_timer but emits a noise
    // Memory Layout:
    // 0x000-0x1FF: For CHIP-8 Interpreter (Mostly unused for emulation)
    // 0x050-0x0A0: Stores characters 0-F for ROMs
    // 0x200-0xFFF: ROM instructions and free space if any
    _memory: [4096]u8 = [_]u8{0} ** 4096, // 4KB of RAM
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

    // Generate random values and store a random byte for game usage
    _random_generator: std.Random.DefaultPrng = undefined,
    _random_byte: u8 = 0,

    _table: [0xF + 1]Chip8Fn,
    _table0: [0xE + 1]Chip8Fn,
    _table8: [0xE + 1]Chip8Fn,
    _tableE: [0xE + 1]Chip8Fn,
    _tableF: [0x65 + 1]Chip8Fn,

    // Function Pointer Tables
    fn Table0(self: *Chip8) void {
        const n = self._opcode & 0x000F;
        self._table0[n](self);
    }

    fn Table8(self: *Chip8) void {
        const n = self._opcode & 0x000F;
        self._table8[n](self);
    }

    fn TableE(self: *Chip8) void {
        const n = self._opcode & 0x000F;
        self._tableE[n](self);
    }

    fn TableF(self: *Chip8) void {
        const nn = self._opcode & 0x00FF;
        self._tableF[nn](self);
    }

    pub fn create() Chip8 {
        return .{
            ._table = undefined,
            ._table0 = undefined,
            ._table8 = undefined,
            ._tableE = undefined,
            ._tableF = undefined,
        };
    }

    pub fn init(self: *Chip8) void {
        const seed = @abs(std.time.milliTimestamp());
        self._random_generator = std.Random.DefaultPrng.init(seed);
        self._random_byte = self._random_generator.random().int(u8);

        // put fontset in mem
        var i: u32 = 0;
        while (i < FONTSET_SIZE) : (i += 1) {
            self._memory[FONTSET_START_ADDRESS + i] = self._fontset[i];
        }

        // Setup table -> opcode
        self._table[0x0] = Chip8.Table0;
        self._table[0x1] = OP_1nnn;
        self._table[0x2] = OP_2nnn;
        self._table[0x3] = OP_3xkk;
        self._table[0x4] = OP_4xkk;
        self._table[0x5] = OP_5xy0;
        self._table[0x6] = OP_6xkk;
        self._table[0x7] = OP_7xkk;
        self._table[0x8] = Chip8.Table8;
        self._table[0x9] = OP_9xy0;
        self._table[0xA] = OP_Annn;
        self._table[0xB] = OP_Bnnn;
        self._table[0xC] = OP_Cxkk;
        self._table[0xD] = OP_Dxyn;
        self._table[0xE] = Chip8.TableE;
        self._table[0xF] = Chip8.TableF;

        // Initialize our Chip8FunctionTable's that point to other tables (0, 8, E, F) to NULL
        var j: usize = 0;
        while (j <= 0x65) : (j += 1) {
            if (j <= 0xE) {
                self._table0[j] = OP_NULL;
                self._table8[j] = OP_NULL;
                self._tableE[j] = OP_NULL;
            }

            self._tableF[j] = OP_NULL;
        }

        // Now for those tables, fill them in with the correct opcode
        self._table0[0x0] = OP_00E0;
        self._table0[0xE] = OP_00EE;

        self._table8[0x0] = OP_8xy0;
        self._table8[0x1] = OP_8xy1;
        self._table8[0x2] = OP_8xy2;
        self._table8[0x3] = OP_8xy3;
        self._table8[0x4] = OP_8xy4;
        self._table8[0x5] = OP_8xy5;
        self._table8[0x6] = OP_8xy6;
        self._table8[0x7] = OP_8xy7;
        self._table8[0xE] = OP_8xyE;

        self._tableE[0x1] = OP_ExA1;
        self._tableE[0xE] = OP_Ex9E;

        self._tableF[0x07] = OP_Fx07;
        self._tableF[0x0A] = OP_Fx0A;
        self._tableF[0x15] = OP_Fx15;
        self._tableF[0x18] = OP_Fx18;
        self._tableF[0x1E] = OP_Fx1E;
        self._tableF[0x29] = OP_Fx29;
        self._tableF[0x33] = OP_Fx33;
        self._tableF[0x55] = OP_Fx55;
        self._tableF[0x65] = OP_Fx65;
    }

    pub fn load_rom(self: *Chip8, rom_file: []const u8) Chip8Error!void {
        var file = fs.cwd().openFile(rom_file, .{ .mode = .read_only }) catch return Chip8Error.RomOpenError;
        defer file.close();

        const rom_size = file.getEndPos() catch return Chip8Error.RomReadError;

        if (rom_size + ROM_START_ADDRESS > self._memory.len) return Chip8Error.RomSizeError;

        // read into memory
        file.seekTo(0) catch return Chip8Error.RomReadError;
        const target = self._memory[ROM_START_ADDRESS..][0..rom_size];
        const bytes_read = file.readAll(target) catch return Chip8Error.RomReadError;

        if (bytes_read != rom_size) return Chip8Error.RomReadError;

        return;
    }

    pub fn cycle(self: *Chip8) void {
        _ = stderr.print("CYCLE: Fetching opcode at PC = {X:0>4}\n", .{self._program_counter}) catch {};
        self._opcode =
            (@as(u16, self._memory[self._program_counter]) << 8) |
            @as(u16, self._memory[self._program_counter + 1]);
        _ = stderr.print("CLCYE: Feteched opcode: {X:0>4}\n", .{self._opcode}) catch {};

        self._program_counter += 2;

        // Decode Instruction and send to table to use correct opcode
        const index = (self._opcode & 0xF000) >> 12;
        const handler = self._table[index];
        handler(self);

        if (self._delay_timer > 0) {
            self._delay_timer -= 1;
        }
        if (self._sound_timer > 0) {
            self._sound_timer -= 1;
        }
    }
};

// INSTRUCTIONS FOR CHIP 8 BELOW ONLY //
const stderr = std.io.getStdErr().writer();

fn OP_NULL(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
    // _ = self;
}

// 00E0: Clears the display
fn OP_00E0(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
    _ = stderr.write("00E0\n") catch return;

    @memset(self.video[0..], 0);
    // @memset(&self.video, 0);
    _ = stderr.write("00E0\n") catch return;
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
}

// 00EE: return from subroutine
fn OP_00EE(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
    if (self._stack_pointer == 0) {
        @panic("Stack underflow in 00EE");
    }

    self._stack_pointer -= 1;
    const ret_addr = self._stack[self._stack_pointer];

    _ = stderr.print("RET to {X:0>4} (from SP={})\n", .{ ret_addr, self._stack_pointer }) catch {};

    self._program_counter = ret_addr;
}

// 1nnn: jump to address {nnn}
fn OP_1nnn(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};

    // nnn is address to jump to
    // mask off the 1, get nnn
    const address: u16 = self._opcode & 0x0FFF;
    self._program_counter = address;
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
}

// 2nnn: call subroutine at {nnn}
fn OP_2nnn(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
    const address = self._opcode & 0x0FFF;

    if (self._stack_pointer >= self._stack.len) {
        @panic("Stack overflow in 2nnn");
    }

    const ret_addr = self._program_counter;
    self._stack[self._stack_pointer] = ret_addr;
    self._stack_pointer += 1;

    _ = stderr.print("CALL {X:0>4} from {X:0>4} (SP={})\n", .{ address, ret_addr, self._stack_pointer - 1 }) catch {};

    self._program_counter = address;
}

// 3xkk: skip next instruction if registers[x] == kk
fn OP_3xkk(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};

    // the 'x' in the opcode is the register we need,
    // kk is the value we will set in that register
    const x: u8 = @intCast((self._opcode & 0x0F00) >> 8);
    const kk: u8 = @intCast(self._opcode & 0x00FF);

    if (self._registers[x] == kk) {
        self._program_counter += 2;
    }
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
}

// 4xkk: skip next instruction if registers[x] != kk
fn OP_4xkk(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
    const x: u8 = @intCast((self._opcode & 0x0F00) >> 8);
    const kk: u8 = @intCast(self._opcode & 0x00FF);

    if (self._registers[x] != kk) {
        self._program_counter += 2;
    }
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
}

// 5xy0: skip next instruction if registers[x] == registers[y]
fn OP_5xy0(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
    const x: u8 = @intCast((self._opcode & 0x0F00) >> 8);
    const y: u8 = @intCast((self._opcode & 0x00F0) >> 4);

    if (self._registers[x] == self._registers[y]) {
        self._program_counter += 2;
    }
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
}

// 6xkk: set register[x] = kk
fn OP_6xkk(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
    const x: u8 = @intCast((self._opcode & 0x0F00) >> 8);
    const kk: u8 = @intCast(self._opcode & 0x00FF);

    self._registers[x] = kk;
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
}

// 7xkk: add kk to register[x]
fn OP_7xkk(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
    const x: u8 = @intCast((self._opcode & 0x0F00) >> 8);
    const kk: u8 = @intCast(self._opcode & 0x00FF);

    self._registers[x] = self._registers[x] +% kk;
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
}

// 8xy0: set registers[x] = registers[y]
fn OP_8xy0(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
    const x: u8 = @intCast((self._opcode & 0x0F00) >> 8);
    const y: u8 = @intCast((self._opcode & 0x00F0) >> 4);

    self._registers[x] = self._registers[y];
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
}

// 8xy1: set registers[x] = registers[x] OR registers[y]
fn OP_8xy1(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
    const x: u8 = @intCast((self._opcode & 0x0F00) >> 8);
    const y: u8 = @intCast((self._opcode & 0x00F0) >> 4);

    self._registers[x] |= self._registers[y];
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
}

// 8xy2: set registers[x] = registers[x] AND registers[y]
fn OP_8xy2(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
    const x: u8 = @intCast((self._opcode & 0x0F00) >> 8);
    const y: u8 = @intCast((self._opcode & 0x00F0) >> 4);

    self._registers[x] &= self._registers[y];
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
}

// 8xy3: set registers[x] = registers[x] XOR registers[y]
fn OP_8xy3(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
    const x: u8 = @intCast((self._opcode & 0x0F00) >> 8);
    const y: u8 = @intCast((self._opcode & 0x00F0) >> 4);

    self._registers[x] ^= self._registers[y];
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
}

// 8xy4: set registers[x] = registers[x] + registers[y], register[F] = carry
fn OP_8xy4(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
    const x: u8 = @intCast((self._opcode & 0x0F00) >> 8);
    const y: u8 = @intCast((self._opcode & 0x00F0) >> 4);

    const sum: u16 = @as(u16, @intCast(self._registers[x])) + @as(u16, @intCast(self._registers[y]));

    // check if u8 would overflow
    if (sum > 255) { // 255 is max for 8-bit
        self._registers[0xF] = 1; // overflow true
    } else {
        self._registers[0xF] = 0; // overflow false
    }

    // sum is 16-bits, we can only store 8, mask out left 8-bits
    self._registers[x] = @intCast(sum & 0xFF);

    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
}

// 8xy5: set register[x] = registers[x] - registers[y], registers[F] = NOT borrow
fn OP_8xy5(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
    const x: u8 = @intCast((self._opcode & 0x0F00) >> 8);
    const y: u8 = @intCast((self._opcode & 0x00F0) >> 4);

    // if need to borrow, set registers[0xF] to NOT borrow
    if (self._registers[x] > self._registers[y]) {
        // Do not need to borrow, set to true
        self._registers[0xF] = 1;
    } else {
        // need to borrow, set to false
        self._registers[0xF] = 0;
    }

    self._registers[x] = self._registers[x] -% self._registers[y];
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
}

// 8xy6: Shift registers[x] right by 1 (LSB into registers[F])
fn OP_8xy6(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
    const x: u8 = @intCast((self._opcode & 0x0F00) >> 8);

    // Save LSB into registers[F]
    self._registers[0xF] = (self._registers[x] & 0x1);

    // Right shift (divide by 2) once
    self._registers[x] >>= 1;
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
}

// 8xy7: set registers[x] = registers[y] - registers[x], registers[F] = NOT borrow
fn OP_8xy7(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
    const x: u8 = @intCast((self._opcode & 0x0F00) >> 8);
    const y: u8 = @intCast((self._opcode & 0x00F0) >> 4);

    // if need to borrow, set registers[0xF] to NOT borrow
    if (self._registers[y] > self._registers[x]) {
        // Do not need to borrow, set to true
        self._registers[0xF] = 1;
    } else {
        // need to borrow, set to false
        self._registers[0xF] = 0;
    }

    self._registers[x] = self._registers[y] -% self._registers[x];
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
}

// 8xyE: Shift registers[x] left by 1 (MSB into registers[F])
fn OP_8xyE(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
    const x: u8 = @intCast((self._opcode & 0x0F00) >> 8);

    // Save MSB into registers[F]
    self._registers[0xF] = (self._registers[x] & 0x80) >> 7;

    // Left shift (multiple by 2) once
    self._registers[x] <<= 1;
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
}

// 9xy0: skip next instruction if registers[x] != registers[y]
fn OP_9xy0(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
    const x: u8 = @intCast((self._opcode & 0x0F00) >> 8);
    const y: u8 = @intCast((self._opcode & 0x00F0) >> 4);

    if (self._registers[x] != self._registers[y]) {
        self._program_counter += 2;
    }
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
}

// Annn: Set index_register to nnn
fn OP_Annn(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
    const address: u16 = self._opcode & 0x0FFF;
    self._index_register = address;
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
}

// Bnnn: jump/branch to registers[0] + nnn
fn OP_Bnnn(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
    const address: u16 = self._opcode & 0x0FFF;
    self._program_counter = self._registers[0] + address;
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
}

// Cxkk: Set registers[x] = random_byte AND kk
fn OP_Cxkk(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
    const x: u8 = @intCast((self._opcode & 0x0F00) >> 8);
    const kk: u8 = @intCast(self._opcode & 0x00FF);

    // TODO: make it random per call not just in init?
    self._registers[x] = self._random_byte & kk;
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
}

// Dxyn: Display n-byte sprite starting at (registers[x], registers[y]), set registers[F] = collision
// n is the sprite's height, each sprite byte is of course 8 pixels wide. Wraps if needed
fn OP_Dxyn(self: *Chip8) void {
    const x: u8 = @intCast((self._opcode & 0x0F00) >> 8);
    const y: u8 = @intCast((self._opcode & 0x00F0) >> 4);
    const n: u8 = @intCast(self._opcode & 0x000F);

    const x_position: u8 = self._registers[x] % VIDEO_WIDTH;
    const y_position: u8 = self._registers[y] % VIDEO_HEIGHT;

    self._registers[0xF] = 0;

    var row: u8 = 0;
    while (row < n) : (row += 1) {
        const sprite: u8 = self._memory[self._index_register + row];

        var col: u8 = 0;
        while (col < 8) : (col += 1) {
            const pixel: u8 = sprite & (@as(u8, 0x80) >> @intCast(col));
            if (pixel != 0) {
                const x_coord = (x_position + col) % VIDEO_WIDTH;
                const y_coord = (y_position + row) % VIDEO_HEIGHT;

                const index = @as(usize, y_coord) * VIDEO_WIDTH + x_coord;

                if (index >= self.video.len) continue; // extra safety

                const location = &self.video[index];

                if (location.* == 0xFFFFFFFF) {
                    self._registers[0xF] = 1;
                }

                location.* ^= 0xFFFFFFFF;
            }
        }
    }
}

// Ex9E: Skip next instruction if registers[x] is holding key being pressed
fn OP_Ex9E(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
    const x: u8 = @intCast((self._opcode & 0x0F00) >> 8);
    const key: u8 = self._registers[x];

    if (self.keypad[key] != 0) {
        self._program_counter += 2;
    }
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
}

// ExA1: Skip next instruction if registers[x] is not holding key being pressed
fn OP_ExA1(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
    const x: u8 = @intCast((self._opcode & 0x0F00) >> 8);
    const key: u8 = self._registers[x];

    if (self.keypad[key] == 0) {
        self._program_counter += 2;
    }
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
}

// Fx07: Set registers[x] to the delay timer value
fn OP_Fx07(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
    const x: u8 = @intCast((self._opcode & 0x0F00) >> 8);
    self._registers[x] = self._delay_timer;
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
}

// Fx0A: Wait for keypress, then set keypress into registers[x]
fn OP_Fx0A(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
    const x: u8 = @intCast((self._opcode & 0x0F00) >> 8);

    // Wait for keypress by decrementing pc continually until
    // a press is registered
    if (self.keypad[0] != 0) {
        self._registers[x] = 0;
    } else if (self.keypad[1] != 0) {
        self._registers[x] = 1;
    } else if (self.keypad[2] != 0) {
        self._registers[x] = 2;
    } else if (self.keypad[3] != 0) {
        self._registers[x] = 3;
    } else if (self.keypad[4] != 0) {
        self._registers[x] = 4;
    } else if (self.keypad[5] != 0) {
        self._registers[x] = 5;
    } else if (self.keypad[6] != 0) {
        self._registers[x] = 6;
    } else if (self.keypad[7] != 0) {
        self._registers[x] = 7;
    } else if (self.keypad[8] != 0) {
        self._registers[x] = 8;
    } else if (self.keypad[9] != 0) {
        self._registers[x] = 9;
    } else if (self.keypad[10] != 0) {
        self._registers[x] = 10;
    } else if (self.keypad[11] != 0) {
        self._registers[x] = 11;
    } else if (self.keypad[12] != 0) {
        self._registers[x] = 12;
    } else if (self.keypad[13] != 0) {
        self._registers[x] = 13;
    } else if (self.keypad[14] != 0) {
        self._registers[x] = 14;
    } else if (self.keypad[15] != 0) {
        self._registers[x] = 15;
    } else {
        self._program_counter -= 2;
    }
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
}

// Fx15: Set delay timer = registers[x]
fn OP_Fx15(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
    const x: u8 = @intCast((self._opcode & 0x0F00) >> 8);
    self._delay_timer = self._registers[x];
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
}

// Fx18: Set sound timer = registers[x]
fn OP_Fx18(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
    const x: u8 = @intCast((self._opcode & 0x0F00) >> 8);
    self._sound_timer = self._registers[x];
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
}

// Fx1E: Set Index register = index register + registers[x]
fn OP_Fx1E(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
    const x: u8 = @intCast((self._opcode & 0x0F00) >> 8);
    self._index_register += self._registers[x];
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
}

// Fx29: Set index register location to digit sprite at registers[x]
fn OP_Fx29(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
    const x: u8 = @intCast((self._opcode & 0x0F00) >> 8);
    const digit_sprite: u8 = self._registers[x];

    // Font characters are 5 bytes, we need the offset to get
    // the correct first byte
    self._index_register = FONTSET_START_ADDRESS + (5 * digit_sprite);
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
}

// Fx33: Store BCD (binary coded decimal) representation of registers[x] at index regiser location,
// memory[index_register] will be hundreds place, memory[index_register]+1 is tens, +2 is ones
fn OP_Fx33(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
    // Isolate the x part of opcode
    // we only want the number itself, shift right 8 bits
    const x: u8 = @intCast((self._opcode & 0x0F00) >> 8);
    var x_value: u8 = self._registers[x];

    // Store ones place digit at index_register + 2
    self._memory[self._index_register + 2] = x_value % 10;
    x_value /= 10;

    // Store tens place digit at index_register + 1
    self._memory[self._index_register + 1] = x_value % 10;
    x_value /= 10;

    // Store hundres place digit at index_register
    self._memory[self._index_register] = x_value % 10;
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
}

// Fx55: Store registers 0 - registers[x] in memory at index register location
fn OP_Fx55(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
    const x: u8 = @intCast((self._opcode & 0x0F00) >> 8);

    var i: u8 = 0;
    while (i <= x) : (i += 1) {
        self._memory[self._index_register + i] = self._registers[i];
    }
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
}

// Fx65: load registers 0 - registers[x] from memory at index register location
fn OP_Fx65(self: *Chip8) void {
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
    const x: u8 = @intCast((self._opcode & 0x0F00) >> 8);

    var i: u8 = 0;
    while (i <= x) : (i += 1) {
        self._registers[i] = self._memory[self._index_register + i];
    }
    _ = stderr.print("Opcode: {X:0>4}\n", .{self._opcode}) catch {};
}
