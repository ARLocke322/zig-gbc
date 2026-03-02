# zig-gameboy

A Game Boy Colour emulator written in Zig.

![Demo](demo.gif) ![Demo](demo2.gif) 
![Demo](demo3.gif) ![Demo](demo4.gif) 

## Features

- Full Sharp LR35902 instruction set
- All memory structures and registers, apart from ALU, CGB and Serial Transfer
- Currently supports 4 GameBoy cartridge types with automatic detection
- Full PPU using scanline rendering with DMG and CGB modes
- Various components such as the Timer, Interrupt Controller, and Joypad
- SDL3 GUI using Zig's C interoperability, implementing rendering and ROM selection
- Working save games
- Toggleable emulation speeds

## Usage

### Build & run

```
zig build run
```
### Controls

| Game Boy | Keyboard    |
|----------|-------------|
| D-Pad    | Arrow Keys  |
| A        | Z           |
| B        | X           |
| Start    | Enter       |
| Select   | Right Shift |

| Emulator      | Keyboard |
|----------------|----------|
| Toggle Speed   | S        |


## Planned features

- Audio Processing Unit
- Save states
- Additional MBCs

## Test Roms
- Passes Blargg cpu instructions and instruction timing tests
