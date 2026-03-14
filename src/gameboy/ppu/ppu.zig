const std = @import("std");
const assert = std.debug.assert;
const InterruptController = @import("../interrupt_controller.zig").InterruptController;
const Cpu = @import("../cpu/cpu.zig").Cpu;
const Bus = @import("../bus.zig").Bus;
const renderScanlineDmg = @import("render_dmg.zig").renderScanlineDmg;
const renderScanlineCgb = @import("render_cgb.zig").renderScanlineCgb;
const types = @import("ppu_types.zig");

pub const Ppu = @This();

vram: types.Vram,
oam: [40]types.ObjectAttribute,
registers: types.Registers,
dmg: types.DmgState,
cgb: types.CgbState,
internal: types.InternalState,
display: types.DisplayState,
interrupt_controller: *InterruptController,
dma: types.Dma,

pub fn init(interrupt_controller: *InterruptController, cgb: bool) Ppu {
    return Ppu{
        .vram = .{},
        .oam = [_]types.ObjectAttribute{.{}} ** 40,
        .registers = .{},
        .cgb = .{ .enabled = cgb },
        .dmg = .{},
        .internal = .{},
        .display = .{},
        .interrupt_controller = interrupt_controller,
        .dma = .{},
    };
}

pub fn read8(self: *Ppu, addr: u16) u8 {
    assert((addr >= 0x8000 and addr <= 0x9FFF) or
        (addr >= 0xFE00 and addr <= 0xFF4F) or
        (addr >= 0xFF68 and addr <= 0xFF6C));
    return switch (addr) {
        0x8000...0x97FF => {
            if (self.vram.bank == 0) {
                return self.vram.tile_data[addr - 0x8000];
            } else {
                return self.vram.tile_data[addr - 0x8000 + 0x1800];
            }
        },
        0x9800...0x9BFF => {
            if (self.vram.bank == 0) {
                return self.vram.tile_map_1[addr - 0x9800];
            } else {
                return self.vram.tile_map_1[addr - 0x9800 + 0x400];
            }
        },
        0x9C00...0x9FFF => {
            if (self.vram.bank == 0) {
                return self.vram.tile_map_2[addr - 0x9C00];
            } else {
                return self.vram.tile_map_2[addr - 0x9C00 + 0x400];
            }
        },
        0xFE00...0xFE9F => std.mem.asBytes(&self.oam)[addr - 0xFE00],
        0xFF40 => @bitCast(self.registers.lcd_control),
        0xFF41 => @bitCast(self.registers.stat),
        0xFF42 => self.registers.scroll_y,
        0xFF43 => self.registers.scroll_x,
        0xFF44 => self.registers.ly,
        0xFF45 => self.registers.lyc,
        0xFF46 => 0xFF, // maybe dma
        0xFF47 => @bitCast(self.dmg.bg_palette_data),
        0xFF48 => @bitCast(self.dmg.object_palette_0_data),
        0xFF49 => @bitCast(self.dmg.object_palette_1_data),
        0xFF4A => self.registers.wy,
        0xFF4B => self.registers.wx,
        0xFF4F => @as(u8, self.vram.bank),
        0xFF68 => @bitCast(self.cgb.bg_palette_idx),
        0xFF69 => self.getCgbBgPaletteData(),
        0xFF6A => @bitCast(self.cgb.object_palette_idx),
        0xFF6B => self.getCgbObjPaletteData(),
        0xFF6C => @intFromEnum(self.cgb.object_priority_mode),
        else => unreachable,
    };
}

pub fn write8(
    self: *Ppu,
    addr: u16,
    val: u8,
) void {
    assert((addr >= 0x8000 and addr <= 0x9FFF) or
        (addr >= 0xFE00 and addr <= 0xFF4F) or
        (addr >= 0xFF68 and addr <= 0xFF6C));
    switch (addr) {
        0x8000...0x97FF => {
            if (self.vram.bank == 0) {
                self.vram.tile_data[addr - 0x8000] = val;
            } else {
                self.vram.tile_data[addr - 0x8000 + 0x1800] = val;
            }
        },
        0x9800...0x9BFF => {
            if (self.vram.bank == 0) {
                self.vram.tile_map_1[addr - 0x9800] = val;
            } else {
                self.vram.tile_map_1[addr - 0x9800 + 0x400] = val;
            }
        },
        0x9C00...0x9FFF => {
            if (self.vram.bank == 0) {
                self.vram.tile_map_2[addr - 0x9C00] = val;
            } else {
                self.vram.tile_map_2[addr - 0x9C00 + 0x400] = val;
            }
        },
        0xFE00...0xFE9F => std.mem.asBytes(&self.oam)[addr - 0xFE00] = val,
        0xFF40 => self.registers.lcd_control = @bitCast(val),
        0xFF41 => {
            const written: types.LcdStatus = @bitCast(val);
            self.registers.stat.hblank_intr_selected = written.hblank_intr_selected;
            self.registers.stat.vblank_intr_selected = written.vblank_intr_selected;
            self.registers.stat.oam_scan_intr_selected = written.oam_scan_intr_selected;
            self.registers.stat.lyc_equals_ly_intr_selected = written.lyc_equals_ly_intr_selected;
            self.handle_stat_interrupt();
        },
        0xFF42 => self.registers.scroll_y = val,
        0xFF43 => self.registers.scroll_x = val,
        0xFF44 => {},
        0xFF45 => {
            self.registers.lyc = val;
            self.handle_stat_interrupt();
        },
        0xFF46 => unreachable,
        0xFF47 => self.dmg.bg_palette_data = @bitCast(val),
        0xFF48 => self.dmg.object_palette_0_data = @bitCast(val),
        0xFF49 => self.dmg.object_palette_1_data = @bitCast(val),
        0xFF4A => self.registers.wy = val,
        0xFF4B => self.registers.wx = val,
        0xFF4F => self.vram.bank = @truncate(val),
        0xFF68 => self.cgb.bg_palette_idx = @bitCast(val),
        0xFF69 => self.setCgbBgPaletteData_data(val),
        0xFF6A => self.cgb.object_palette_idx = @bitCast(val),
        0xFF6B => self.setCgbObjPaletteData(val),
        0xFF6C => self.cgb.object_priority_mode = @enumFromInt(val),
        else => unreachable,
    }
}

fn getCgbBgPaletteData(self: *Ppu) u8 {
    if (self.registers.stat.ppu_mode == .pixel_transfer) return 0xFF;
    const tgt_address: u6 = self.cgb.bg_palette_idx.palette_address;
    return self.cgb.bg_cram[tgt_address];
}

fn getCgbObjPaletteData(self: *Ppu) u8 {
    if (self.registers.stat.ppu_mode == .pixel_transfer) return 0xFF;
    const tgt_address: u6 = self.cgb.object_palette_idx.palette_address;
    return self.cgb.object_cram[tgt_address];
}

fn setCgbBgPaletteData_data(self: *Ppu, val: u8) void {
    if (self.registers.stat.ppu_mode == .pixel_transfer) return;
    const tgt_address: u6 = self.cgb.bg_palette_idx.palette_address;

    if (self.cgb.bg_palette_idx.auto_increment)
        self.cgb.bg_palette_idx.palette_address +%= 1;

    self.cgb.bg_cram[tgt_address] = val;
}

fn setCgbObjPaletteData(self: *Ppu, val: u8) void {
    if (self.registers.stat.ppu_mode == .pixel_transfer) return;
    const tgt_address: u6 = self.cgb.object_palette_idx.palette_address;

    if (self.cgb.object_palette_idx.auto_increment)
        self.cgb.object_palette_idx.palette_address +%= 1;

    self.cgb.object_cram[tgt_address] = val;
}

pub fn tick(self: *Ppu, bus: *Bus, cycles: u16) void {
    if (!self.registers.lcd_control.lcd_ppu_enabled) {
        self.registers.stat.ppu_mode = .hblank;
        self.registers.ly = 0;
        self.internal.cycles = 0;
        return;
    }

    self.internal.cycles += cycles;
    switch (self.registers.stat.ppu_mode) {
        .hblank => self.handle_hblank(bus),
        .vblank => self.handle_vblank(),
        .oam_scan => self.handle_oam_scan(),
        .pixel_transfer => self.handle_render(),
    }
}

fn handle_hblank(self: *Ppu, bus: *Bus) void {

    // Transfer 1 bytes per 4 T-cycle tick
    if (self.dma.block_active) {
        self.tickHdmaBlock(bus);
    }

    if (self.internal.cycles >= 204) {
        self.registers.ly +%= 1;
        self.internal.cycles -= 204;
        if (self.registers.ly == 144) {
            self.registers.stat.ppu_mode = .vblank;
            self.interrupt_controller.request(InterruptController.VBLANK);
            self.display.frame_ready = true;
        } else self.registers.stat.ppu_mode = .oam_scan;

        self.handle_stat_interrupt();
    }
}

// Transfers 2 Bytes per M cycle / 4 T cycles
fn tickHdmaBlock(self: *Ppu, bus: *Bus) void {
    const byte1 = bus.read8(self.dma.src + self.dma.block_step);
    const byte2 = bus.read8(self.dma.src + self.dma.block_step + 1);
    self.write8(self.dma.dest + self.dma.block_step, byte1);
    self.write8(self.dma.dest + self.dma.block_step + 1, byte2);

    self.dma.block_step += 2;

    if (self.dma.block_step == 0x10) {
        self.dma.block_active = false;
        self.dma.block_step = 0;

        self.dma.src += 0x10;
        self.dma.dest += 0x10;
        self.dma.remaining -= 1;
        self.dma.rVDMA_LEN = @truncate(self.dma.remaining);

        if (self.dma.remaining == 0) {
            self.dma.is_active = false;
            self.dma.rVDMA_LEN = 0xFF;
        }
    }
}

fn handle_vblank(self: *Ppu) void {
    if (self.internal.cycles >= 456) {
        self.registers.ly +%= 1;
        self.internal.cycles -= 456;
        if (self.registers.ly > 153) {
            self.registers.ly = 0;
            self.internal.window_line = 0;
            self.registers.stat.ppu_mode = .oam_scan;
        }

        self.handle_stat_interrupt();
    }
}

fn handle_oam_scan(self: *Ppu) void {
    if (self.internal.cycles >= 80) {
        self.internal.latched.scroll_x = self.registers.scroll_x;
        self.internal.latched.scroll_y = self.registers.scroll_y;
        self.internal.latched.dmg_bg_palette_data = self.dmg.bg_palette_data;
        self.internal.latched.dmg_object_palette_0_data = self.dmg.object_palette_0_data;
        self.internal.latched.dmg_object_palette_1_data = self.dmg.object_palette_1_data;
        self.internal.latched.lcd_control = self.registers.lcd_control;
        self.internal.latched.wx = self.registers.wx;
        self.internal.latched.wy = self.registers.wy;
        self.registers.stat.ppu_mode = .pixel_transfer;
        self.internal.cycles -= 80;

        self.handle_stat_interrupt();
    }
}

fn handle_render(self: *Ppu) void {
    if (self.internal.cycles >= 172) {
        if (self.cgb.enabled)
            renderScanlineCgb(self)
        else
            renderScanlineDmg(self);

        self.registers.stat.ppu_mode = .hblank;
        if (self.dma.is_active) self.dma.block_active = true;

        self.internal.cycles -= 172;

        self.handle_stat_interrupt();
    }
}

fn handle_stat_interrupt(self: *Ppu) void {
    if (self.registers.ly == self.registers.lyc) {
        self.registers.stat.lyc_equals_ly = true;
    } else {
        self.registers.stat.lyc_equals_ly = false;
    }

    self.internal.current_signal = false;

    self.internal.current_signal = if ((self.registers.stat.lyc_equals_ly_intr_selected and self.registers.stat.lyc_equals_ly) or
        switch (self.registers.stat.ppu_mode) {
            .hblank => self.registers.stat.hblank_intr_selected,
            .vblank => self.registers.stat.vblank_intr_selected,
            .oam_scan => self.registers.stat.oam_scan_intr_selected,
            .pixel_transfer => false,
        }) true else false;

    if (self.internal.current_signal and !self.internal.stat_int_signal) { // rising edge
        self.interrupt_controller.request(InterruptController.LCD_STAT);
    }

    self.internal.stat_int_signal = self.internal.current_signal;
}
