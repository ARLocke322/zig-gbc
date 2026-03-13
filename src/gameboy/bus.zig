const std = @import("std");
const Cartridge = @import("../cartridge/cartridge.zig").Cartridge;
const Timer = @import("timer.zig").Timer;
const InterruptController = @import("interrupt_controller.zig").InterruptController;
const Ppu = @import("./ppu/ppu.zig").Ppu;
const Joypad = @import("joypad.zig").Joypad;
const Cpu = @import("./cpu/cpu.zig").Cpu;
const Apu = @import("apu/apu.zig").Apu;
const assert = std.debug.assert;

pub const Bus = struct {
    wram_0: [0x1000]u8 = .{0} ** 0x1000,
    wram_n: [7 * 0x1000]u8 = .{0} ** (7 * 0x1000),
    hram: [0x7F]u8 = .{0} ** 0x7F,

    wbk: u3 = 1,

    cartridge: *Cartridge,
    timer: *Timer,
    interrupts: *InterruptController,
    ppu: *Ppu,
    joypad: *Joypad,
    cpu: *Cpu = undefined,
    apu: *Apu,
    cgb: bool,
    hdma: bool = false,

    dma_active: bool = false,
    dma_source: u16 = 0,
    dma_step: u8 = 0,

    gdma_source: u16 = 0,
    gdma_dest: u16 = 0,
    gdma_num_bytes: u16 = 0,
    gdma_step: u16 = 0,
    gdma_active: bool = false,

    pub fn init(
        cartridge: *Cartridge,
        timer: *Timer,
        interrupts: *InterruptController,
        ppu: *Ppu,
        apu: *Apu,
        joypad: *Joypad,
        cgb: bool,
    ) Bus {
        return Bus{
            .cgb = cgb,
            .cartridge = cartridge,
            .timer = timer,
            .interrupts = interrupts,
            .ppu = ppu,
            .apu = apu,
            .joypad = joypad,
        };
    }
    pub fn read8(self: *Bus, address: u16) u8 {
        return switch (address) {
            0x0000...0x7FFF => self.cartridge.read(address),
            0x8000...0x9FFF => self.ppu.read8(address),
            0xA000...0xBFFF => self.cartridge.read(address),
            0xC000...0xCFFF => self.wram_0[address - 0xC000],
            0xD000...0xDFFF => {
                if (self.cgb) {
                    const ix = (address - 0xD000) + (@as(usize, self.wbk) - 1) * 0x1000;
                    assert(ix < self.wram_n.len);
                    return self.wram_n[ix];
                } else return self.wram_n[address - 0xD000];
            },
            0xE000...0xFDFF => {
                const mirrored = address - 0x2000;
                if (mirrored < 0xD000) {
                    return self.wram_0[mirrored - 0xC000];
                } else {
                    return self.wram_n[mirrored - 0xD000];
                }
            },
            0xFE00...0xFE9F => self.ppu.read8(address),
            0xFEA0...0xFEFF => 0xFF,

            0xFF00 => self.joypad.read(address), // joypad
            0xFF01 => 0xFF, // serial data
            0xFF02 => 0x7C, // serial control

            0xFF03 => 0xFF,
            // Timer registers
            0xFF04...0xFF07 => self.timer.read8(address),

            // Interrupt controller
            0xFF0F => self.interrupts.read8(address),
            0xFF08...0xFF0E => 0xFF,
            0xFF10...0xFF3F => self.apu.read(address),

            0xFF40...0xFF4B => self.ppu.read8(address),
            0xFF4C...0xFF4D => 0xFF, // KEY CGB
            0xFF4F => self.ppu.read8(address),
            0xFF5F => {
                if (self.cgb) {
                    if (self.ppu.hdma_active) {
                        return @as(u8, @truncate(self.ppu.hdma_remaining));
                    } else if (self.gdma_active) {
                        return @as(u8, @truncate(self.gdma_num_bytes - self.gdma_step));
                    }
                }
                return 0xFF;
            },
            0xFF68...0xFF6C => self.ppu.read8(address),
            0xFF70 => @as(u8, self.wbk),

            0xFF80...0xFFFE => self.hram[address - 0xFF80],
            0xFFFF => self.interrupts.read8(address),
            else => 0xFF,
        };
    }

    pub fn write8(self: *Bus, address: u16, value: u8) void {
        switch (address) {
            0x0000...0x7FFF => self.cartridge.write(address, value),
            0x8000...0x9FFF => self.ppu.write8(address, value),
            0xA000...0xBFFF => self.cartridge.write(address, value),
            0xC000...0xCFFF => self.wram_0[address - 0xC000] = value,
            0xD000...0xDFFF => {
                const ix = (address - 0xD000) + (@as(usize, self.wbk) - 1) * 0x1000;
                self.wram_n[ix] = value;
            },
            0xE000...0xFDFF => {},
            0xFE00...0xFE9F => self.ppu.write8(address, value),
            0xFEA0...0xFEFF => {},

            0xFF00 => self.joypad.write(address, value),
            0xFF01 => {},
            0xFF02 => {},
            0xFF03 => {},

            // Timer registers
            0xFF04...0xFF07 => self.timer.write8(address, value),
            0xFF08...0xFF0E => {}, // Unimplemented
            0xFF0F => self.interrupts.write8(address, value),
            0xFF10...0xFF3F => self.apu.write(address, value),
            0xFF40...0xFF45, 0xFF47...0xFF4B => self.ppu.write8(address, value),
            0xFF46 => {
                self.ppu.dma = value; // Store DMA register
                self.dma_active = true;
                self.dma_source = @as(u16, value) << 8;
            },
            0xFF4C...0xFF4D => {}, // KEY1 KEY2
            0xFF4F => self.ppu.write8(address, value),
            0xFF50 => {}, // Boot ROM mapping control
            0xFF51 => {
                if (self.cgb) self.ppu.rVDMA_SRC_HIGH = value;
            },
            0xFF52 => {
                if (self.cgb) self.ppu.rVDMA_SRC_LOW = value;
            },
            0xFF53 => {
                if (self.cgb) self.ppu.rVDMA_DEST_HIGH = value;
            },
            0xFF54 => {
                if (self.cgb) self.ppu.rVDMA_DEST_LOW = value;
            },
            0xFF55 => {
                // initidate rVDMA
                if (self.cgb) {
                    self.ppu.rVDMA_LEN = value;
                    const transfer_mode: u1 = @truncate(value >> 7);

                    if (transfer_mode == 0 and self.ppu.hdma_active) {
                        self.ppu.hdma_active = false;
                        return;
                    }

                    const src_addr: u16 = 0xFFF0 & // bottom 4 bits ignored
                        ((@as(u16, self.ppu.rVDMA_SRC_HIGH) << 8) |
                            (self.ppu.rVDMA_SRC_LOW));
                    const dest_addr: u16 = 0x8000 | (0x1FF0 & // only 12-4 respected
                        ((@as(u16, self.ppu.rVDMA_DEST_HIGH) << 8) |
                            (self.ppu.rVDMA_DEST_LOW)));

                    const num_blocks: u16 = @as(u16, value & 0x7F) + 1;
                    const num_bytes: u16 = num_blocks * 0x10;

                    if (transfer_mode == 0) {
                        self.gdma_source = src_addr;
                        self.gdma_dest = dest_addr;
                        self.gdma_num_bytes = num_bytes;
                        self.gdma_step = 0;
                        self.gdma_active = true;
                    } else {
                        self.ppu.hdma_active = true;
                        self.ppu.hdma_src = src_addr;
                        self.ppu.hdma_dest = dest_addr;
                        self.ppu.hdma_remaining = num_blocks;
                    }
                }
            },
            0xFF56 => {}, // Infrared
            0xFF68...0xFF6C => self.ppu.write8(address, value),
            0xFF70 => {
                const u3_val: u3 = @truncate(value);
                if (u3_val == 0) {
                    self.wbk = 1;
                } else self.wbk = u3_val;
            },
            0xFF80...0xFFFE => self.hram[address - 0xFF80] = value,
            0xFFFF => self.interrupts.write8(address, value),
            else => {},
        }
    }
    pub fn tickDma(self: *Bus) void {
        const byte = self.read8(self.dma_source + self.dma_step);
        self.ppu.oam[self.dma_step] = byte;
        self.dma_step += 1;
        if (self.dma_step == 0xA0) {
            self.dma_active = false;
            self.dma_step = 0;
            self.dma_source = 0;
        }
    }

    pub fn tickGdma(self: *Bus) void {
        const byte1 = self.read8(self.gdma_source + self.gdma_step);
        const byte2 = self.read8(self.gdma_source + self.gdma_step + 1);
        self.ppu.write8(self.gdma_dest + self.gdma_step, byte1);
        self.ppu.write8(self.gdma_dest + self.gdma_step + 1, byte2);
        self.gdma_step += 2;

        if (self.gdma_step == self.gdma_num_bytes) {
            self.gdma_active = false;
            self.gdma_source = 0;
            self.gdma_dest = 0;
            self.gdma_num_bytes = 0;
            self.gdma_step = 0;
        }
    }

    pub fn read16(self: *Bus, address: u16) u16 {
        const low = self.read8(address);
        const high = self.read8(address + 1);
        return (@as(u16, high) << 8) | low;
    }

    pub fn write16(self: *Bus, address: u16, value: u16) void {
        self.write8(address, @truncate(value));
        self.write8(address + 1, @truncate(value >> 8));
    }
};
