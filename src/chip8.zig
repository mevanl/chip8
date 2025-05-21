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

    // 00E0: Clears the display
    fn OP_00E0(self: *Chip8) void {
        @memset(&self.video, 0);
    }

    // 00EE: return from subroutine
    fn OP_00EE(self: *Chip8) void {
        self._stack_pointer -= 1;
        self._program_counter = self._stack[self._stack_pointer];
    }

    // 1nnn: jump to address {nnn}
    fn OP_1nnn(self: *Chip8) void {
        // nnn is address to jump to
        // mask off the 1, get nnn
        const address: u16 = self._opcode & 0x0FFF;
        self._program_counter = address;
    }

    // 2nnn: call subroutine at {nnn}
    fn OP_2nnn(self: *Chip8) void {
        const address = self._opcode & 0x0FFF;

        // put next instruction to stack to RET from
        self._stack[self._stack_pointer] = self._program_counter;
        self._stack_pointer += 1;
        self._program_counter = address;
    }

    // 3xkk: skip next instruction if registers[x] == kk
    fn OP_3xkk(self: *Chip8) void {
        // the 'x' in the opcode is the register we need,
        // kk is the value we will set in that register
        const x: u8 = (self._opcode & 0x0F00) >> 8;
        const kk: u8 = self._opcode & 0x00FF;

        if (self._registers[x] == kk) {
            self._program_counter += 2;
        }
    }

    // 4xkk: skip next instruction if registers[x] != kk
    fn OP_4xkk(self: *Chip8) void {
        const x: u8 = (self._opcode & 0x0F00) >> 8;
        const kk: u8 = self._opcode & 0x00FF;

        if (self._registers[x] != kk) {
            self._program_counter += 2;
        }
    }

    // 5xy0: skip next instruction if registers[x] == registers[y]
    fn OP_5xy0(self: *Chip8) void {
        const x: u8 = (self._opcode & 0x0F00) >> 8;
        const y: u8 = (self._opcode & 0x00F0) >> 4;

        if (self._registers[x] == self._registers[y]) {
            self._program_counter += 2;
        }
    }

    // 6xkk: set register[x] = kk
    fn OP_6xkk(self: *Chip8) void {
        const x: u8 = (self._opcode & 0x0F00) >> 8;
        const kk: u16 = self._opcode & 0x00FF;

        self._registers[x] = kk;
    }

    // 7xkk: add kk to register[x]
    fn OP_7xkk(self: *Chip8) void {
        const x: u8 = (self._opcode & 0x0F00) >> 8;
        const kk: u16 = self._opcode & 0x00FF;

        self._registers[x] += kk;
    }

    // 8xy0: set registers[x] = registers[y]
    fn OP_8xy0(self: *Chip8) void {
        const x: u8 = (self._opcode & 0x0F00) >> 8;
        const y: u8 = (self._opcode & 0x00F0) >> 4;

        self._registers[x] = self._registers[y];
    }

    // 8xy1: set registers[x] = registers[x] OR registers[y]
    fn OP_8xy1(self: *Chip8) void {
        const x: u8 = (self._opcode & 0x0F00) >> 8;
        const y: u8 = (self._opcode & 0x00F0) >> 4;

        self.registers[x] |= self.registers[y];
    }

    // 8xy2: set registers[x] = registers[x] AND registers[y]
    fn OP_8xy2(self: *Chip8) void {
        const x: u8 = (self._opcode & 0x0F00) >> 8;
        const y: u8 = (self._opcode & 0x00F0) >> 4;

        self.registers[x] &= self.registers[y];
    }

    // 8xy3: set registers[x] = registers[x] XOR registers[y]
    fn OP_8xy3(self: *Chip8) void {
        const x: u8 = (self._opcode & 0x0F00) >> 8;
        const y: u8 = (self._opcode & 0x00F0) >> 4;

        self.registers[x] ^= self.registers[y];
    }

    // 8xy4: set registers[x] = registers[x] + registers[y], register[F] = carry
    fn OP_8xy4(self: *Chip8) void {
        const x: u8 = (self._opcode & 0x0F00) >> 8;
        const y: u8 = (self._opcode & 0x00F0) >> 4;

        const sum: u16 = self._registers[x] + self._registers[y];

        // check if u8 would overflow
        if (sum > 255) { // 255 is max for 8-bit
            self._registers[0xF] = 1; // overflow true
        } else {
            self._registers[0xF] = 0; // overflow false
        }

        // sum is 16-bits, we can only store 8, mask out left 8-bits
        self._registers[x] = sum & 0xFF;
    }

    // 8xy5: set register[x] = registers[x] - registers[y], registers[F] = NOT borrow
    fn OP_8xy5(self: *Chip8) void {
        const x: u8 = (self._opcode & 0x0F00) >> 8;
        const y: u8 = (self._opcode & 0x00F0) >> 4;

        // if need to borrow, set registers[0xF] to NOT borrow
        if (self._registers[x] > self._registers[y]) {
            // Do not need to borrow, set to true
            self._registers[0xF] = 1;
        } else {
            // need to borrow, set to false
            self._registers[0xF] = 0;
        }

        self._registers[x] -= self._registers[y];
    }

    // 8xy6: Shift registers[x] right by 1 (LSB into registers[F])
    fn OP_8xy6(self: *Chip8) void {
        const x: u8 = (self._opcode & 0x0F00) >> 8;

        // Save LSB into registers[F]
        self._registers[0xF] = (self._registers[x] & 0x1);

        // Right shift (divide by 2) once
        self._registers[x] >>= 1;
    }

    // 8xy7: set registers[x] = registers[y] - registers[x], registers[F] = NOT borrow
    fn OP_8xy7(self: *Chip8) void {
        const x: u8 = (self._opcode & 0x0F00) >> 8;
        const y: u8 = (self._opcode & 0x00F0) >> 4;

        // if need to borrow, set registers[0xF] to NOT borrow
        if (self._registers[y] > self._registers[x]) {
            // Do not need to borrow, set to true
            self._registers[0xF] = 1;
        } else {
            // need to borrow, set to false
            self._registers[0xF] = 0;
        }

        self._registers[x] = self._registers[y] - self._registers[x];
    }

    // 8xy6: Shift registers[x] left by 1 (MSB into registers[F])
    fn OP_8xyE(self: *Chip8) void {
        const x: u8 = (self._opcode & 0x0F00) >> 8;

        // Save MSB into registers[F]
        self._registers[0xF] = (self._registers[x] & 0x80) >> 7;

        // Left shift (multiple by 2) once
        self._registers[x] <<= 1;
    }

    // 9xy0: skip next instruction if registers[x] != registers[y]
    fn OP_9xy0(self: *Chip8) void {
        const x: u8 = (self._opcode & 0x0F00) >> 8;
        const y: u8 = (self._opcode & 0x00F0) >> 4;

        if (self._registers[x] != self._registers[y]) {
            self._program_counter += 2;
        }
    }

    // Annn: Set index_register to nnn
    fn OP_Annn(self: *Chip8) void {
        const address: u16 = self._opcode & 0x0FFF;
        self._index_register = address;
    }

    // Bnnn: jump/branch to registers[0] + nnn
    fn OP_Bnnn(self: *Chip8) void {
        const address: u16 = self._opcode & 0x0FFF;
        self._program_counter = self._registers[0] + address;
    }

    // Cxkk: Set registers[x] = random_byte AND kk
    fn OP_Cxkk(self: *Chip8) void {
        const x: u8 = (self._opcode & 0x0F00) >> 8;
        const kk: u16 = self._opcode & 0x00F;

        self._registers[x] = self._random_byte(self._random_generator) & kk;
    }

    // Dxyn: Display n-byte sprite starting at (registers[x], registers[y]), set registers[F] = collision
    // n is the sprite's height, each sprite byte is of course 8 pixels wide. Wraps if needed
    fn OP_Dxyn(self: *Chip8) void {
        const x: u8 = (self._opcode & 0x0F00) >> 8;
        const y: u8 = (self._opcode & 0x00F0) >> 4;
        const n: u8 = self._opcode & 0x000F;

        // Figure out if going based display boundary so can wrap
        const x_position: u8 = self._registers[x] % VIDEO_WIDTH;
        const y_position: u8 = self._registers[y] % VIDEO_HEIGHT;

        // Initialize registers[F] with no collisions (0)
        self._registers[0xF] = 0;

        // Place sprite onto display

        // go through rows of the sprite
        var row = 0;
        while (row < n) : (row += 1) {
            const sprite: u8 = self._memory[self._index_register + row];

            // sprites are 8 pixels wide, each col a pixel in row
            var col = 0;
            while (col < 8) : (col += 1) {
                const pixel = sprite & (0x80 >> col);
                const location = &(self.video[(y_position + row) * VIDEO_WIDTH + (x_position + col)]);

                // if location is valid
                if (pixel) {

                    // is there a pixel there?
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
        const x: u8 = (self._opcode & 0x0F00) >> 8;
        const key: u8 = self._registers[x];

        if (self.keypad[key]) {
            self._program_counter += 2;
        }
    }

    // ExA1: Skip next instruction if registers[x] is not holding key being pressed
    fn OP_ExA1(self: *Chip8) void {
        const x: u8 = (self._opcode & 0x0F00) >> 8;
        const key: u8 = self._registers[x];

        if (!self.keypad[key]) {
            self._program_counter += 2;
        }
    }

    // Fx07: Set registers[x] to the delay timer value
    fn OP_Fx07(self: *Chip8) void {
        const x: u8 = (self._opcode & 0x0F00) >> 8;
        self._registers[x] = self._delay_timer;
    }

    // Fx0A: Wait for keypress, then set keypress into registers[x]
    fn OP_Fx0A(self: *Chip8) void {
        const x: u8 = (self._opcode & 0x0F00) >> 8;

        // Wait for keypress by decrementing pc continually until
        // a press is registered
        if (self._keypad[0]) {
            self._registers[x] = 0;
        } else if (self._keypad[1]) {
            self._registers[x] = 1;
        } else if (self._keypad[2]) {
            self._registers[x] = 2;
        } else if (self._keypad[3]) {
            self._registers[x] = 3;
        } else if (self._keypad[4]) {
            self._registers[x] = 4;
        } else if (self._keypad[5]) {
            self._registers[x] = 5;
        } else if (self._keypad[6]) {
            self._registers[x] = 6;
        } else if (self._keypad[7]) {
            self._registers[x] = 7;
        } else if (self._keypad[8]) {
            self._registers[x] = 8;
        } else if (self._keypad[9]) {
            self._registers[x] = 9;
        } else if (self._keypad[10]) {
            self._registers[x] = 10;
        } else if (self._keypad[11]) {
            self._registers[x] = 11;
        } else if (self._keypad[12]) {
            self._registers[x] = 12;
        } else if (self._keypad[13]) {
            self._registers[x] = 13;
        } else if (self._keypad[14]) {
            self._registers[x] = 14;
        } else if (self._keypad[15]) {
            self._registers[x] = 15;
        } else {
            self._program_counter -= 2;
        }
    }

    // Fx15: Set delay timer = registers[x]
    fn OP_Fx15(self: *Chip8) void {
        const x: u8 = (self._opcode & 0x0F00) >> 8;
        self._delay_timer = self._registers[x];
    }

    // Fx18: Set sound timer = registers[x]
    fn OP_Fx18(self: *Chip8) void {
        const x: u8 = (self._opcode & 0x0F00) >> 8;
        self._sound_timer = self._registers[x];
    }

    // Fx1E: Set Index register = index register + registers[x]
    fn OP_Fx1E(self: *Chip8) void {
        const x: u8 = (self._opcode & 0x0F00) >> 8;
        self._index_register += self._registers[x];
    }

    // Fx29: Set index register location to digit sprite at registers[x]
    fn OP_Fx29(self: *Chip8) void {
        const x: u8 = (self._opcode & 0x0F00) >> 8;
        const digit_sprite: u8 = self._registers[x];

        // Font characters are 5 bytes, we need the offset to get
        // the correct first byte
        self._index_register = FONTSET_START_ADDRESS + (5 * digit_sprite);
    }

    // Fx33: Store BCD (binary coded decimal) representation of registers[x] at index regiser location,
    // memory[index_register] will be hundreds place, memory[index_register]+1 is tens, +2 is ones
    fn OP_Fx33(self: *Chip8) void {
        // Isolate the x part of opcode
        // we only want the number itself, shift right 8 bits
        const x: u8 = (self._opcode & 0x0F00) >> 8;
        const x_value: u8 = self._registers[x];

        // Store ones place digit at index_register + 2
        self._memory[self._index_register + 2] = x_value % 10;
        x_value /= 10;

        // Store tens place digit at index_register + 1
        self._memory[self._index_register + 1] = x_value % 10;
        x_value /= 10;

        // Store hundres place digit at index_register
        self._memory[self._index_register] = x_value % 10;
    }

    // Fx55: Store registers 0 - registers[x] in memory at index register location
    fn OP_Fx55(self: *Chip8) void {
        const x: u8 = (self._opcode & 0x0F00) >> 8;

        var i: u8 = 0;
        while (i <= x) : (i += 1) {
            self._memory[self._index_register + i] = self._registers[i];
        }
    }

    // Fx65: load registers 0 - registers[x] from memory at index register location
    fn OP_Fx65(self: *Chip8) void {
        const x: u8 = (self._opcode & 0x0F00) >> 8;

        var i: u8 = 0;
        while (i <= x) : (i += 1) {
            self._registers[i] = self._memory[self._index_register + i];
        }
    }
};
