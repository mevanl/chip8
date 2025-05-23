# Chip8

<p align="center"><br><img src="https://raw.githubusercontent.com/mevanl/chip8/refs/heads/master/chip8.png" height="192"><br><br></b>• Chip 8 - 1977 Assembly Language •<br></p>

> Chip-8 is an interpreted programming language written in 1977. There is no underlying hardware it relies on, it is a spec that must be implemented, similar to a virtual machine.

## Features 
- Simple, Crossplatform Build Step
- No Heap Allocations (Except for arg parse)
- Fully implemented Chip-8 Instruction set
- Easily modifiable video scale and clock speed

## Building from source
#### Requirements
- Zig (version >= 0.14.0)
- [SDL3 Zig Port](https://github.com/castholm/SDL)

#### Step 1: Build
```zig
zig build
```

## Running 
1. Grab a chip8 rom to use: https://github.com/kripod/chip8-roms
2. Place it where your executable file is located at. 
3. Enter prompt to start the emulator
```bash
# Command structure:
./chip8 <video scale> <clock cycle> <*.ch8 file>

# Example 
./chip8 10 3 Tetris.ch8
```
> NOTE: Different ch8 programs/games run better on different clock speeds, so you might have to play with different values to get a speed you are comfortable at! 
